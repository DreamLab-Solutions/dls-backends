# DreamLab Backends

## Structure

- `supabase/` - Supabase backend configuration
  - `migrations/` - Database schema migrations
  - `seed/` - Seed data for local development
  - `policies/` - RLS policies source-of-truth (see policies/README.md)
  - `functions/` - Edge functions
  - `config.toml` - Supabase CLI configuration

## Policy Management

See `supabase/policies/README.md` for policy workflow and best practices.

Quick reference:
- Policies source: `backends/supabase/policies/`
- Policies applied via: `backends/supabase/migrations/`
- Local testing: `pnpm supabase:reset`
