#!/usr/bin/env node

/**
 * Local bootstrap wrapper for the minimal Supabase admin seed.
 *
 * The SQL seed file remains the runtime bootstrap source consumed by
 * `supabase db reset`. This script only regenerates that file from the
 * current local environment so reset and seed follow the same path.
 */

import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const generatorPath = resolve(scriptDir, 'generate-admin-seed.sh');

const result = spawnSync('bash', [generatorPath], {
  cwd: resolve(scriptDir, '..'),
  env: process.env,
  stdio: 'inherit',
});

if (result.status !== 0) {
  process.exit(result.status ?? 1);
}
