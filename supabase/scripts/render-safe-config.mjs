#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const supabaseDir = path.resolve(__dirname, '..');
const repoRoot = path.resolve(supabaseDir, '..', '..');

const SITE_URL_PLACEHOLDER = '"__DREAMLAB_SUPABASE_SITE_URL__"';
const REDIRECTS_PLACEHOLDER = '__DREAMLAB_SUPABASE_ADDITIONAL_REDIRECT_URLS__';

const appSpecs = [
  {
    key: 'HUB',
    localEnv: 'SUPABASE_REDIRECT_HUB_LOCAL_BASE_URLS',
    publicEnv: 'SUPABASE_REDIRECT_HUB_PUBLIC_BASE_URLS',
    tailscaleEnv: 'SUPABASE_REDIRECT_HUB_TAILSCALE_BASE_URLS',
    extraEnv: 'SUPABASE_REDIRECT_HUB_EXACT_URLS',
    defaultLocalBases: (env) => defaultLocalBases(env.ADMIN_UI_PORT, 5173),
    paths: ['', '/auth/login', '/auth/callback'],
    primary: true,
  },
  {
    key: 'WEBSITE',
    localEnv: 'SUPABASE_REDIRECT_WEBSITE_LOCAL_BASE_URLS',
    publicEnv: 'SUPABASE_REDIRECT_WEBSITE_PUBLIC_BASE_URLS',
    tailscaleEnv: 'SUPABASE_REDIRECT_WEBSITE_TAILSCALE_BASE_URLS',
    extraEnv: 'SUPABASE_REDIRECT_WEBSITE_EXACT_URLS',
    defaultLocalBases: (env) => defaultLocalBases(env.WEBSITE_ASTRO_PORT, 4321),
    paths: ['', '/api/auth/callback'],
  },
  {
    key: 'EVIDENCE',
    localEnv: 'SUPABASE_REDIRECT_EVIDENCE_LOCAL_BASE_URLS',
    publicEnv: 'SUPABASE_REDIRECT_EVIDENCE_PUBLIC_BASE_URLS',
    tailscaleEnv: 'SUPABASE_REDIRECT_EVIDENCE_TAILSCALE_BASE_URLS',
    extraEnv: 'SUPABASE_REDIRECT_EVIDENCE_EXACT_URLS',
    defaultLocalBases: (env) => defaultLocalBases(env.EVIDENCE_MGMT_PORT, 5174),
    paths: ['', '/auth/login', '/auth/callback'],
  },
  {
    key: 'UI_REACT_STORYBOOK',
    localEnv: 'SUPABASE_REDIRECT_UI_REACT_STORYBOOK_LOCAL_BASE_URLS',
    publicEnv: 'SUPABASE_REDIRECT_UI_REACT_STORYBOOK_PUBLIC_BASE_URLS',
    tailscaleEnv: 'SUPABASE_REDIRECT_UI_REACT_STORYBOOK_TAILSCALE_BASE_URLS',
    extraEnv: 'SUPABASE_REDIRECT_UI_REACT_STORYBOOK_EXACT_URLS',
    defaultLocalBases: (env) => defaultLocalBases(env.STORYBOOK_UI_REACT_PORT, 46001),
    paths: [''],
  },
  {
    key: 'UI_ASTRO_STORYBOOK',
    localEnv: 'SUPABASE_REDIRECT_UI_ASTRO_STORYBOOK_LOCAL_BASE_URLS',
    publicEnv: 'SUPABASE_REDIRECT_UI_ASTRO_STORYBOOK_PUBLIC_BASE_URLS',
    tailscaleEnv: 'SUPABASE_REDIRECT_UI_ASTRO_STORYBOOK_TAILSCALE_BASE_URLS',
    extraEnv: 'SUPABASE_REDIRECT_UI_ASTRO_STORYBOOK_EXACT_URLS',
    defaultLocalBases: () => [],
    paths: [''],
  },
  {
    key: 'UI_VUE_STORYBOOK',
    localEnv: 'SUPABASE_REDIRECT_UI_VUE_STORYBOOK_LOCAL_BASE_URLS',
    publicEnv: 'SUPABASE_REDIRECT_UI_VUE_STORYBOOK_PUBLIC_BASE_URLS',
    tailscaleEnv: 'SUPABASE_REDIRECT_UI_VUE_STORYBOOK_TAILSCALE_BASE_URLS',
    extraEnv: 'SUPABASE_REDIRECT_UI_VUE_STORYBOOK_EXACT_URLS',
    defaultLocalBases: () => [],
    paths: [''],
  },
];

export function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return {};
  }

  return parse(fs.readFileSync(filePath, 'utf8'));
}

export function defaultLocalBases(portValue, fallbackPort) {
  const port = normalizePort(portValue, fallbackPort);
  return [`http://127.0.0.1:${port}`, `http://localhost:${port}`];
}

function normalizePort(portValue, fallbackPort) {
  const parsed = Number.parseInt(`${portValue ?? fallbackPort}`, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallbackPort;
}

export function parseList(value) {
  if (!value) {
    return [];
  }

  return value
    .split(/[\n,]/u)
    .map((entry) => entry.trim())
    .filter(Boolean);
}

export function normalizeUrl(value) {
  const url = new URL(value);
  url.hash = '';
  const href = url.toString();
  return href.endsWith('/') ? href.slice(0, -1) : href;
}

export function joinUrl(baseUrl, relativePath) {
  if (!relativePath) {
    return normalizeUrl(baseUrl);
  }

  return normalizeUrl(new URL(relativePath, withTrailingSlash(baseUrl)).toString());
}

function withTrailingSlash(url) {
  return url.endsWith('/') ? url : `${url}/`;
}

function toTomlString(value) {
  return JSON.stringify(value);
}

function toTomlArray(values) {
  if (values.length === 0) {
    return '[]';
  }

  return `[\n${values.map((value) => `  ${toTomlString(value)}`).join(',\n')}\n]`;
}

export function resolveSiteUrl(env, redirectUrls) {
  const candidates = [
    env.SUPABASE_SITE_URL,
    env.SUPABASE_PUBLIC_SITE_URL,
    ...redirectUrls,
  ].filter(Boolean);

  if (candidates.length === 0) {
    return 'http://127.0.0.1:5173';
  }

  return normalizeUrl(candidates[0]);
}

export function collectRedirectUrls(env) {
  const urls = [];
  const seen = new Set();

  const pushUrl = (value) => {
    const normalized = normalizeUrl(value);
    if (seen.has(normalized)) {
      return;
    }

    seen.add(normalized);
    urls.push(normalized);
  };

  for (const spec of appSpecs) {
    const localBaseUrls = parseList(env[spec.localEnv]);
    const baseUrls = [
      ...(localBaseUrls.length > 0 ? localBaseUrls : spec.defaultLocalBases(env)),
      ...parseList(env[spec.publicEnv]),
      ...parseList(env[spec.tailscaleEnv]),
    ];

    for (const baseUrl of baseUrls) {
      for (const relativePath of spec.paths) {
        pushUrl(joinUrl(baseUrl, relativePath));
      }
    }

    for (const exactUrl of parseList(env[spec.extraEnv])) {
      pushUrl(exactUrl);
    }
  }

  for (const extraUrl of parseList(env.SUPABASE_REDIRECT_EXTRA_URLS)) {
    pushUrl(extraUrl);
  }

  return urls;
}

export function renderConfig({ sourceFile, destinationFile, envOverrides = {} } = {}) {
  const source = fs.readFileSync(sourceFile, 'utf8');
  const localEnv = loadEnvFile(path.join(repoRoot, '.env.local'));
  const publicEnv = loadEnvFile(path.join(supabaseDir, '.env.public'));
  const mergedEnv = {
    ...publicEnv,
    ...localEnv,
    ...envOverrides,
    ...process.env,
  };

  const redirectUrls = collectRedirectUrls(mergedEnv);
  const siteUrl = resolveSiteUrl(mergedEnv, redirectUrls);

  const rendered = source
    .replace(SITE_URL_PLACEHOLDER, toTomlString(siteUrl))
    .replace(REDIRECTS_PLACEHOLDER, toTomlArray(redirectUrls));

  fs.mkdirSync(path.dirname(destinationFile), { recursive: true });
  fs.writeFileSync(destinationFile, rendered);
}

const sourceFile = process.argv[2] ? path.resolve(process.argv[2]) : path.join(supabaseDir, 'config.toml');
const destinationFile = process.argv[3]
  ? path.resolve(process.argv[3])
  : path.join(supabaseDir, '.temp', 'supabase-safe', 'config.toml');

if (process.argv[1] && path.resolve(process.argv[1]) === __filename) {
  renderConfig({ sourceFile, destinationFile });
}
