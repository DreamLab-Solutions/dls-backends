import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFile } from "node:child_process";
import express from "express";
import { ImapFlow } from "imapflow";
import { simpleParser } from "mailparser";
import {
  PaperlessDesiredStateSchema,
  PAPERLESS_ALLOWED_ENV_KEYS,
} from "@dreamlab-solutions/dls-domain";

const app = express();
const port = Number(process.env.PORT || 5055);
const composeFile = process.env.COMPOSE_FILE || "/workspace/dev/compose/local-infra.compose.yml";
const hubApiUrl = process.env.HUB_API_URL || "http://hub-api:4000";

const SERVICE_GROUPS = {
  core: ["traefik", "redis", "minio", "ops-daemon"],
  apps: ["hub-api", "hub-console", "payload"],
  paperless: ["paperless"],
};
const ALL_SERVICES = Array.from(new Set(Object.values(SERVICE_GROUPS).flat()));

const ALLOWED_SERVICES = new Set(ALL_SERVICES);

const ENV_TARGETS: Record<string, { path: string; keys: Set<string> }> = {
  paperless: {
    path: "/workspace/.env",
    keys: new Set(PAPERLESS_ALLOWED_ENV_KEYS),
  },
};

const MAX_BODY_BYTES = 20000;

app.use(express.json({ limit: "1mb" }));

const runCompose = (args: string[]) =>
  new Promise<{ stdout: string; stderr: string }>((resolve, reject) => {
    execFile("docker", ["compose", "-f", composeFile, ...args], (err, stdout, stderr) => {
      if (err) {
        reject({ error: err.message, stdout, stderr });
        return;
      }
      resolve({ stdout, stderr });
    });
  });

const writeEnvFile = (targetPath: string, updates: Record<string, string>) => {
  const content = fs.existsSync(targetPath) ? fs.readFileSync(targetPath, "utf8") : "";
  const lines = content.split(/\n/);
  const seen = new Set<string>();

  const nextLines = lines.map((line) => {
    const match = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (!match) {
      return line;
    }
    const key = match[1];
    if (Object.prototype.hasOwnProperty.call(updates, key)) {
      seen.add(key);
      return `${key}=${updates[key]}`;
    }
    return line;
  });

  for (const [key, value] of Object.entries(updates)) {
    if (!seen.has(key)) {
      nextLines.push(`${key}=${value}`);
    }
  }

  fs.writeFileSync(targetPath, `${nextLines.join("\n")}\n`, "utf8");
};

const syncPaperlessEnv = () =>
  new Promise<{ stdout: string; stderr: string }>((resolve, reject) => {
    execFile("node", ["/workspace/infra/scripts/sync-paperless-env.js"], (err, stdout, stderr) => {
      if (err) {
        reject({ error: err.message, stdout, stderr });
        return;
      }
      resolve({ stdout, stderr });
    });
  });

const emitAudit = async (event: unknown) => {
  try {
    await fetch(`${hubApiUrl}/v1/audit`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(event),
    });
  } catch {
    // Best-effort audit only.
  }
};

const ensureImapEnv = () => {
  const host = process.env.IMAP_HOST || "";
  const portEnv = process.env.IMAP_PORT || "";
  const user = process.env.IMAP_USER || "";
  const password = process.env.IMAP_PASSWORD || "";
  if (!host || !portEnv || !user || !password) {
    throw new Error("IMAP credentials missing (IMAP_HOST/IMAP_PORT/IMAP_USER/IMAP_PASSWORD)");
  }
  return {
    host,
    port: Number(portEnv),
    secure: process.env.IMAP_TLS === "true",
    auth: { user, pass: password },
  };
};

const resolveVault = async (pluginInstanceId: string, keys?: string[]) => {
  const response = await fetch(`${hubApiUrl}/v1/vault/resolve`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-internal-call": "ops-daemon",
    },
    body: JSON.stringify({ pluginInstanceId, keys }),
  });
  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    throw new Error(payload?.error || "Failed to resolve vault secrets");
  }
  return response.json();
};

const loadEnvFile = (targetPath: string) => {
  if (!fs.existsSync(targetPath)) {
    return {};
  }
  const content = fs.readFileSync(targetPath, "utf8");
  const lines = content.split(/\n/);
  const env: Record<string, string> = {};
  for (const line of lines) {
    const match = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (!match) {
      continue;
    }
    env[match[1]] = match[2];
  }
  return env;
};

const withRetry = async <T,>(fn: () => Promise<T>, retries = 1) => {
  try {
    return await fn();
  } catch (err) {
    if (retries <= 0) throw err;
    await new Promise((resolve) => setTimeout(resolve, 1000));
    return withRetry(fn, retries - 1);
  }
};

const withTimeout = async <T,>(promise: Promise<T>, ms: number) => {
  let timer: NodeJS.Timeout | undefined;
  return Promise.race([
    promise,
    new Promise<T>((_, reject) => {
      timer = setTimeout(() => reject(new Error(`Timeout after ${ms}ms`)), ms);
    }),
  ]).finally(() => {
    if (timer) clearTimeout(timer);
  });
};

const sanitizeRepoPath = (repoPath: string) => {
  const resolved = path.resolve(repoPath);
  const workspaceRoot = "/workspace";
  if (!resolved.startsWith(workspaceRoot)) {
    throw new Error("repoPath must be within /workspace");
  }
  return resolved;
};

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "ops-daemon" });
});

app.post("/compose/up", async (req, res) => {
  const group = req.body?.serviceGroup || req.body?.group;
  if (!group || !SERVICE_GROUPS[group as keyof typeof SERVICE_GROUPS]) {
    res.status(400).json({ error: "Invalid group" });
    return;
  }
  try {
    const result = await runCompose(["up", "-d", ...SERVICE_GROUPS[group as keyof typeof SERVICE_GROUPS]]);
    res.json({ ok: true, ...result });
  } catch (err: any) {
    const message = err?.error || err?.message || "Unknown error";
    res.status(500).json({ ok: false, error: message });
  }
});

app.post("/compose/restart", async (req, res) => {
  const service = req.body?.service;
  if (!service || !ALLOWED_SERVICES.has(service)) {
    res.status(400).json({ error: "Invalid service" });
    return;
  }
  try {
    const result = await runCompose(["restart", service]);
    res.json({ ok: true, ...result });
  } catch (err: any) {
    const message = err?.error || err?.message || "Unknown error";
    res.status(500).json({ ok: false, error: message });
  }
});

app.post("/env/write", async (req, res) => {
  const { service, key, value } = req.body || {};
  const target = ENV_TARGETS[service];
  if (!target) {
    res.status(400).json({ error: "Invalid service" });
    return;
  }
  if (!target.keys.has(key)) {
    res.status(400).json({ error: "Invalid key" });
    return;
  }
  try {
    writeEnvFile(target.path, { [key]: value });
    if (service === "paperless") {
      await syncPaperlessEnv();
    }
    res.json({ ok: true, updated: true });
  } catch (err: any) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post("/v1/ops/paperless/restart", async (_req, res) => {
  try {
    const result = await runCompose(["restart", "paperless"]);
    await emitAudit({
      id: crypto.randomUUID(),
      occurredAt: new Date().toISOString(),
      actor: "system",
      action: "paperless.restart",
      targetRef: "paperless",
      result: "ok",
      details: result,
    });
    res.json({ ok: true });
  } catch (err: any) {
    await emitAudit({
      id: crypto.randomUUID(),
      occurredAt: new Date().toISOString(),
      actor: "system",
      action: "paperless.restart",
      targetRef: "paperless",
      result: "error",
      details: err,
    });
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post("/v1/ops/paperless/write-env", async (req, res) => {
  const { key, value } = req.body || {};
  if (!key || typeof key !== "string") {
    res.status(400).json({ error: "Invalid key" });
    return;
  }
  if (!ENV_TARGETS.paperless.keys.has(key)) {
    res.status(400).json({ error: "Invalid key" });
    return;
  }
  try {
    writeEnvFile(ENV_TARGETS.paperless.path, { [key]: value });
    await syncPaperlessEnv();
    await emitAudit({
      id: crypto.randomUUID(),
      occurredAt: new Date().toISOString(),
      actor: "system",
      action: "paperless.env.write",
      targetRef: "paperless",
      result: "ok",
      details: { key },
    });
    res.json({ ok: true });
  } catch (err: any) {
    await emitAudit({
      id: crypto.randomUUID(),
      occurredAt: new Date().toISOString(),
      actor: "system",
      action: "paperless.env.write",
      targetRef: "paperless",
      result: "error",
      details: err,
    });
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post("/v1/ops/paperless/reconcile", async (_req, res) => {
  try {
    const desired = loadEnvFile("/workspace/.env");
    const current = loadEnvFile("/workspace/dev/paperless/docker-compose.env");
    const changes = PAPERLESS_ALLOWED_ENV_KEYS.filter((key) => key in desired).map((key) => ({
      key,
      current: current[key] ?? null,
      desired: desired[key],
      action: current[key] === desired[key] ? "noop" : "update",
    }));
    const plan = changes.filter((item) => item.action !== "noop");
    await emitAudit({
      id: crypto.randomUUID(),
      occurredAt: new Date().toISOString(),
      actor: "system",
      action: "paperless.reconcile.plan",
      targetRef: "paperless",
      result: "ok",
      details: { changes: plan.length },
    });
    res.json({ ok: true, plan, total: plan.length });
  } catch (err: any) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post("/v1/ops/paperless/reconcile/apply", async (_req, res) => {
  try {
    await syncPaperlessEnv();
    await runCompose(["restart", "paperless"]);
    await emitAudit({
      id: crypto.randomUUID(),
      occurredAt: new Date().toISOString(),
      actor: "system",
      action: "paperless.reconcile.apply",
      targetRef: "paperless",
      result: "ok",
    });
    res.json({ ok: true, applied: true });
  } catch (err: any) {
    await emitAudit({
      id: crypto.randomUUID(),
      occurredAt: new Date().toISOString(),
      actor: "system",
      action: "paperless.reconcile.apply",
      targetRef: "paperless",
      result: "error",
      details: { error: err.message },
    });
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post("/v1/ops/run-plugin", async (req, res) => {
  const pluginId = req.body?.pluginId || "email";
  await emitAudit({
    id: crypto.randomUUID(),
    occurredAt: new Date().toISOString(),
    actor: "system",
    action: "plugin.run",
    targetRef: pluginId,
    result: "ok",
    details: { note: "Plugin runner stub" },
  });
  res.json({ ok: true, pluginId });
});

app.post("/v1/ops/email/test", async (req, res) => {
  const pluginInstanceId = req.body?.pluginInstanceId as string | undefined;
  if (!pluginInstanceId) {
    res.status(400).json({ ok: false, error: "pluginInstanceId required" });
    return;
  }
  try {
    const resolved = await resolveVault(pluginInstanceId, ["user", "password"]);
    const host = resolved.config?.host;
    const port = Number(resolved.config?.port || 993);
    const secure = resolved.config?.secure !== false;
    const user = resolved.secrets?.user;
    const pass = resolved.secrets?.password;
    if (!host || !user || !pass) {
      res.json({ ok: false, error: "IMAP config incomplete for plugin instance" });
      return;
    }
    const client = new ImapFlow({
      host,
      port,
      secure,
      auth: { user, pass },
      greetingTimeout: 5000,
      socketTimeout: 5000,
      logger: false,
    });
    await withTimeout(withRetry(() => client.connect(), 1), 6000);
    await client.logout();
    res.json({ ok: true });
  } catch (err: any) {
    res.json({ ok: false, error: err.message });
  }
});

app.post("/v1/ops/email/ingest", async (req, res) => {
  const pluginInstanceId = req.body?.pluginInstanceId as string | undefined;
  const mailbox = req.body?.mailbox || process.env.IMAP_MAILBOX || "INBOX";
  const limit = Math.min(Number(req.body?.limit) || 10, 25);
  const since = req.body?.since ? new Date(req.body.since) : null;

  try {
    let config;
    if (pluginInstanceId) {
      const resolved = await resolveVault(pluginInstanceId, ["user", "password"]);
      const host = resolved.config?.host;
      const port = Number(resolved.config?.port || 993);
      const secure = resolved.config?.secure !== false;
      const user = resolved.secrets?.user;
      const pass = resolved.secrets?.password;
      if (!host || !user || !pass) {
        res.status(400).json({ ok: false, error: "IMAP config incomplete for plugin instance" });
        return;
      }
      config = { host, port, secure, auth: { user, pass } };
    } else {
      config = ensureImapEnv();
    }
    const client = new ImapFlow(config);
    await withRetry(() => client.connect(), 1);

    const lock = await client.getMailboxLock(mailbox);
    try {
      const ids = since
        ? await client.search({ since })
        : null;
      const range = ids && ids.length ? ids.slice(-limit) : null;
      const messages: any[] = [];

      if (range && range.length) {
        for await (const msg of client.fetch(range, { envelope: true, source: true, internalDate: true })) {
          if (!msg.source) {
            continue;
          }
          const parsed = (await simpleParser(msg.source as any)) as any;
          const bodyText = (parsed.text || parsed.html || "").toString();
          messages.push({
            messageId: parsed.messageId || `${msg.uid}`,
            subject: parsed.subject || "",
            from: parsed.from?.text || "",
            date: (parsed.date || msg.internalDate || new Date()).toISOString(),
            body: bodyText.slice(0, MAX_BODY_BYTES),
          });
        }
      }

      res.json({ ok: true, messages });
    } finally {
      lock.release();
      await client.logout();
    }
  } catch (err: any) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post("/v1/ops/git/commits", async (req, res) => {
  const limit = Math.min(Number(req.body?.limit) || 50, 200);
  const pluginInstanceId = req.body?.pluginInstanceId as string | undefined;
  let repoPath = req.body?.repoPath || "/workspace";
  let provider = "local";
  let owner = "dreamlab";
  let name = "workspace";
  const since = req.body?.since as string | undefined;
  const until = req.body?.until as string | undefined;
  if (pluginInstanceId) {
    try {
      const resolved = await resolveVault(pluginInstanceId);
      repoPath = resolved.config?.repoPath || repoPath;
      provider = resolved.config?.provider || provider;
      owner = resolved.config?.owner || owner;
      name = resolved.config?.name || name;
    } catch (err: any) {
      res.status(400).json({ ok: false, error: err.message });
      return;
    }
  }
  repoPath = sanitizeRepoPath(repoPath);
  try {
    const dateArgs: string[] = [];
    if (since) dateArgs.push(`--since=${since}`);
    if (until) dateArgs.push(`--until=${until}`);
    execFile(
      "git",
      [
        "-C",
        repoPath,
        "log",
        "-n",
        String(limit),
        ...dateArgs,
        "--pretty=format:%H|%an|%ad|%s",
        "--date=iso",
      ],
      (err, stdout, stderr) => {
        if (err) {
          res.status(500).json({ ok: false, error: err.message, stderr });
          return;
        }
        const commits = stdout
          .split(/\n/)
          .filter(Boolean)
          .map((line) => {
            const [sha, author, committedAt, ...rest] = line.split("|");
            return {
              sha,
              author,
              committedAt,
              message: rest.join("|").trim(),
              provider,
              owner,
              name,
            };
          });
        res.json({ ok: true, commits });
      }
    );
  } catch (err: any) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post("/v1/paperless/apply-desired-state", async (req, res) => {
  const parsed = PaperlessDesiredStateSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ ok: false, error: parsed.error.format() });
    return;
  }

  const { serviceId, env } = parsed.data;
  if (serviceId !== "paperless") {
    res.status(400).json({ ok: false, error: "serviceId must be paperless" });
    return;
  }

  for (const key of Object.keys(env)) {
    if (!PAPERLESS_ALLOWED_ENV_KEYS.includes(key)) {
      res.status(400).json({ ok: false, error: `Key not allowlisted: ${key}` });
      return;
    }
  }

  try {
    writeEnvFile(ENV_TARGETS.paperless.path, env);
    await syncPaperlessEnv();
    await runCompose(["restart", "paperless"]);
    res.json({ ok: true, applied: Object.keys(env).length });
  } catch (err: any) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post("/paperless/reconcile", (_req, res) => {
  res.status(501).json({ error: "Reconcile is a Phase 2 feature." });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`ops-daemon listening on ${port}`);
});
