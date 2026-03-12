# Supabase local seeds

## Seed order

`config.toml` runs these in order during `supabase db reset`:

1. `seeds/001_admin_user.sql`
2. `seeds/002_evidence_mgmt_seed.sql`

## Evidence seed dataset (`002_evidence_mgmt_seed.sql`)

- Tenant: `evidence-mgmt` (`Evidence Management Test Org`)
- Project: `evidence-mgmt-next` (`apps/evidence-mgmt-next`)
- Initial CASE: one `evidence_timelines` record (`CASE-001 | Onboarding access discrepancy`)
- Initial EVENT: one `evidence_events` record linked to CASE
- Initial ARTIFACT: one `evidence_messages` record linked to EVENT
- Initial EVIDENCE: one `evidence_excerpts` record linked to ARTIFACT + EVENT

The seed is idempotent for local reruns: tenant/project are slug-based upserts and domain rows use deterministic UUIDs with `ON CONFLICT` updates.
