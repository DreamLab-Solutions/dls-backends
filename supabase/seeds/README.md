# Supabase local seeds

## Seed order

`config.toml` runs these in order during `supabase db reset`:

1. `seeds/001_admin_user.sql`
2. `seeds/002_dreamlab_base_seed.sql`
3. `seeds/003_evidence_mgmt_seed.sql`

## Bootstrap policy

- Global catalogs and inheritance live in the database baseline:
  - tenant bootstrap via DB trigger
  - project bootstrap via DB trigger
  - global registry/config catalogs via migrations
- Seed files only bind the canonical local tenants/projects to that baseline.

## DreamLab base dataset (`002_dreamlab_base_seed.sql`)

- Tenant: `dreamlab-solutions`
- Projects:
  - `dls-platform-hub-next`
  - `dls-website-astro`
- Canonical platform mapping for `DreamLab Solutions`
- Repo/domain/preview metadata for hub and website
- DreamLab project bindings for plugins, routing, config overrides, role config
- DB-backed hub dashboard copy catalog
- DB-backed website global copy + homepage entry

## Evidence seed dataset (`003_evidence_mgmt_seed.sql`)

- Tenant: `evidence-mgmt` (`Evidence Management Test Org`)
- Project: `evidence-mgmt-next` (`apps/evidence-mgmt-next`)
- Canonical platform mapping for `Evidence Management`
- Repo/domain/preview metadata for the Evidence app
- Evidence plugin + feature bindings
- Initial CASE: one `evidence_timelines` record (`CASE-001 | Onboarding access discrepancy`)
- Initial EVENT: one `evidence_events` record linked to CASE
- Initial ARTIFACT: one `evidence_messages` record linked to EVENT
- Initial EVIDENCE: one `evidence_excerpts` record linked to ARTIFACT + EVENT

The seed is idempotent for local reruns: tenant/project are slug-based upserts and domain rows use deterministic UUIDs with `ON CONFLICT` updates.
