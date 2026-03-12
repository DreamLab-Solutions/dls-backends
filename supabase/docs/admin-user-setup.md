# Admin User Setup

This document describes how the platform admin user is configured and seeded in the local Supabase development environment.

## Overview

The admin user is automatically created when running `supabase db reset` or on the initial `supabase start`. This ensures a consistent development environment with a pre-configured administrator account.

## Default Admin Credentials

| Field | Value | Environment Variable |
|-------|-------|---------------------|
| **Email** | `info@dreamlab.solutions` | `PLATFORM_ADMIN_EMAILS` |
| **Password** | `Pass123!` | `E2E_PLATFORM_ADMIN_PASSWORD` |

## Configuration

### Environment Variables

Add these to your `.env.local` file (root of the monorepo):

```bash
# Admin Configuration
PLATFORM_ADMIN_EMAILS=info@dreamlab.solutions
E2E_PLATFORM_ADMIN_PASSWORD=Pass123!
```

### Supabase Config

The seed configuration in `backends/supabase/config.toml`:

```toml
[db.seed]
enabled = true
sql_paths = ["./seeds/*.sql"]
```

## Admin User Seed File

The admin user is created by the seed file: `backends/supabase/seeds/001_admin_user.sql`

This seed:
1. Creates the admin user in `auth.users` with a bcrypt-hashed password
2. Adds the user to `platform_users` with `platform_owner` role
3. Creates/updates the `dreamlab` tenant
4. Adds the admin as `tenant_owner` of the dreamlab tenant

## Usage

### Automatic (On Database Reset)

```bash
# This will run migrations and seeds
cd backends/supabase
supabase db reset
```

### Manual Admin Seed Generation

If you need to regenerate the seed with a different password:

```bash
# From the project root
pnpm supabase:seed-admin

# Or directly
./backends/supabase/scripts/generate-admin-seed.sh
```

### Verify Admin User

```bash
# Connect to the database
supabase db psql

# Query the admin user
SELECT id, email, created_at FROM auth.users WHERE email = 'info@dreamlab.solutions';

# Check platform user role
SELECT * FROM public.platform_users WHERE email = 'info@dreamlab.solutions';
```

## Changing the Admin Password

### Option 1: Regenerate Seed (Recommended for Development)

1. Update `E2E_PLATFORM_ADMIN_PASSWORD` in `.env.local`
2. Run `pnpm supabase:seed-admin`
3. Run `supabase db reset`

### Option 2: Update via Supabase Studio

1. Open Supabase Studio: http://127.0.0.1:54323
2. Go to Table Editor → `auth.users`
3. Find the admin user and update the password
4. Or use the Auth UI to send a password reset

### Option 3: SQL Update

```sql
-- Update password via SQL (requires bcrypt hash)
UPDATE auth.users 
SET encrypted_password = crypt('new-password', gen_salt('bf', 10))
WHERE email = 'info@dreamlab.solutions';
```

## Security Notes

⚠️ **IMPORTANT**: 

- The default password `Pass123!` is **ONLY for local development**
- Never commit real passwords to git
- The seed file uses a pre-computed bcrypt hash for the default password
- For production, always use strong, unique passwords
- Consider using environment-specific seed files for different environments

## Troubleshooting

### Admin user not created

Check the seed file was executed:
```bash
supabase db reset --debug
```

Look for the log message: `Admin user setup complete`

### Password doesn't work

1. Regenerate the seed: `pnpm supabase:seed-admin`
2. Reset the database: `supabase db reset`

### Duplicate user errors

The seed uses `ON CONFLICT` clauses to handle re-runs gracefully. If you see errors, check:
- The user ID in `auth.users` matches `platform_users.auth_user_id`
- The tenant membership exists in `tenant_members`

## Related Files

- `backends/supabase/config.toml` - Seed configuration
- `backends/supabase/seeds/001_admin_user.sql` - Admin user seed
- `backends/supabase/scripts/generate-admin-seed.sh` - Seed generation script
- `backends/supabase/migrations/0040_platform_users.sql` - Platform users schema
- `.env.local` - Environment variables (root of monorepo)

## E2E Testing

The E2E tests use the same credentials:

```typescript
// e2e/auth.spec.ts
const ADMIN_EMAIL = process.env.PLATFORM_ADMIN_EMAILS?.split(',')[0] || 'info@dreamlab.solutions';
const ADMIN_PASSWORD = process.env.E2E_PLATFORM_ADMIN_PASSWORD || 'Pass123!';
```

This ensures tests can log in with the pre-seeded admin user.
