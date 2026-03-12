import test from 'node:test';
import assert from 'node:assert/strict';

import { collectRedirectUrls, resolveSiteUrl } from '../scripts/render-safe-config.mjs';

test('resolveSiteUrl falls back to the public API host when no local override exists', () => {
  const siteUrl = resolveSiteUrl(
    {
      SUPABASE_PUBLIC_SITE_URL: 'https://api.dreamlab.solutions',
    },
    [],
  );

  assert.equal(siteUrl, 'https://api.dreamlab.solutions');
});

test('collectRedirectUrls expands website, evidence, vercel, and storybook targets', () => {
  const urls = collectRedirectUrls({
    ADMIN_UI_PORT: '5173',
    WEBSITE_ASTRO_PORT: '4321',
    EVIDENCE_MGMT_PORT: '5174',
    STORYBOOK_UI_REACT_PORT: '46001',
    SUPABASE_REDIRECT_HUB_PUBLIC_BASE_URLS: 'https://hub.dreamlab.solutions,https://dls-platform-hub-next.vercel.app',
    SUPABASE_REDIRECT_WEBSITE_PUBLIC_BASE_URLS: 'https://dreamlab.solutions,https://www.dreamlab.solutions,https://dls-website-astro.vercel.app',
    SUPABASE_REDIRECT_EVIDENCE_PUBLIC_BASE_URLS: 'https://evidence.dreamlab.solutions,https://evidence-gmtm-next.vercel.app',
  });

  assert.ok(urls.includes('https://dreamlab.solutions/api/auth/callback'));
  assert.ok(urls.includes('https://www.dreamlab.solutions/api/auth/callback'));
  assert.ok(urls.includes('https://evidence.dreamlab.solutions/auth/callback'));
  assert.ok(urls.includes('https://evidence-gmtm-next.vercel.app/auth/callback'));
  assert.ok(urls.includes('https://dls-platform-hub-next.vercel.app/auth/callback'));
  assert.ok(urls.includes('http://127.0.0.1:46001'));
  assert.ok(urls.includes('http://localhost:46001'));
});
