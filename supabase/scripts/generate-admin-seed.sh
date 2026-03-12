#!/bin/bash
# =============================================================================
# Generate Admin User Seed Script
# =============================================================================
# This script generates the admin user seed SQL file with custom credentials.
#
# Usage:
#   pnpm supabase:seed-admin
#   or
#   ./scripts/generate-admin-seed.sh
#
# Environment Variables:
#   - E2E_PLATFORM_ADMIN_PASSWORD: The admin password (default: Pass123!)
#   - PLATFORM_ADMIN_EMAILS: Admin email (default: info@dreamlab.solutions)
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables from .env.local if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [ -f "$PROJECT_ROOT/.env.local" ]; then
    echo -e "${GREEN}Loading environment from .env.local${NC}"
    set -a
    source "$PROJECT_ROOT/.env.local"
    set +a
fi

# Configuration
ADMIN_EMAIL="${PLATFORM_ADMIN_EMAILS:-info@dreamlab.solutions}"
ADMIN_EMAIL=$(echo "$ADMIN_EMAIL" | cut -d',' -f1 | tr -d ' ') # Take first email
ADMIN_PASSWORD="${E2E_PLATFORM_ADMIN_PASSWORD:-Pass123!}"
SEED_FILE="$SCRIPT_DIR/../seeds/001_admin_user.sql"

echo -e "${GREEN}Generating admin user seed...${NC}"
echo "  Email: $ADMIN_EMAIL"
echo "  Password: [hidden]"
echo "  Seed file: $SEED_FILE"

# Generate the seed SQL file
cat > "$SEED_FILE" << EOF
-- =============================================================================
-- Admin User Seed for Local Development
-- =============================================================================
-- This seed creates the platform admin user automatically when running
-- \`supabase db reset\` or on initial \`supabase start\`.
--
-- Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
-- Admin Email: $ADMIN_EMAIL
--
-- NOTE: Content models and entries are NOT seeded here.
-- They should be created via BFF APIs from the platform app.
-- This ensures the schema adheres to the current design standard.
--
-- WARNING: This file is auto-generated. Do not edit manually.
-- Run: pnpm supabase:seed-admin
-- =============================================================================

DO \$\$
DECLARE
  v_admin_email text := '$ADMIN_EMAIL';
  v_admin_password text := '$ADMIN_PASSWORD';
  v_user_id uuid;
  v_tenant_id uuid;
  v_project_ids uuid[];
BEGIN
  -- -----------------------------------------------------------------------------
  -- 1. Create admin user (if not exists)
  -- -----------------------------------------------------------------------------
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = v_admin_email
  LIMIT 1;

  IF v_user_id IS NULL THEN
    INSERT INTO auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, confirmation_token, recovery_token,
      email_change_token_new, email_change, phone, phone_change,
      phone_change_token, email_change_token_current,
      reauthentication_token, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at
    ) VALUES (
      gen_random_uuid(),
      '00000000-0000-0000-0000-000000000000'::uuid,
      'authenticated',
      'authenticated',
      v_admin_email,
      crypt(v_admin_password, gen_salt('bf', 10)),
      NOW(), '', '', '', '', '', '', '', '', '',
      '{"provider": "email", "providers": ["email"], "platform_role": "platform_owner", "roles": ["platform_owner", "platform_admin"]}'::jsonb,
      '{"full_name": "Platform Administrator", "email_verified": true, "role": "platform_admin", "persona": "enterprise"}'::jsonb,
      NOW(),
      NOW()
    )
    RETURNING id INTO v_user_id;

    RAISE NOTICE 'Created admin user: % (ID: %)', v_admin_email, v_user_id;
  ELSE
    RAISE NOTICE 'Admin user already exists: %', v_admin_email;
  END IF;

  UPDATE auth.users
  SET raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object(
    'provider', 'email',
    'providers', jsonb_build_array('email'),
    'platform_role', 'platform_owner',
    'roles', jsonb_build_array('platform_owner', 'platform_admin')
  )
  WHERE id = v_user_id;

  -- -----------------------------------------------------------------------------
  -- 2. Ensure platform_user record
  -- -----------------------------------------------------------------------------
  UPDATE public.platform_users
  SET role = 'platform_owner', status = 'active', activated_at = NOW(),
      display_name = coalesce(display_name, 'Platform Administrator')
  WHERE auth_user_id = v_user_id OR lower(email) = lower(v_admin_email);

  IF NOT FOUND THEN
    INSERT INTO public.platform_users (auth_user_id, email, display_name, role, status, activated_at)
    VALUES (v_user_id, v_admin_email, 'Platform Administrator', 'platform_owner', 'active', NOW());
  END IF;

  -- -----------------------------------------------------------------------------
  -- 3. Ensure tenant exists
  -- -----------------------------------------------------------------------------
  INSERT INTO public.tenants (slug, name)
  VALUES ('dreamlab-solutions', 'DreamLab Solutions')
  ON CONFLICT (slug) DO NOTHING
  RETURNING id INTO v_tenant_id;

  IF v_tenant_id IS NULL THEN
    SELECT id INTO v_tenant_id
    FROM public.tenants
    WHERE slug = 'dreamlab-solutions'
    LIMIT 1;
  END IF;

  -- -----------------------------------------------------------------------------
  -- 4. Ensure tenant membership
  -- -----------------------------------------------------------------------------
  INSERT INTO public.tenant_members (tenant_id, user_id, role)
  VALUES (v_tenant_id, v_user_id, 'tenant_owner')
  ON CONFLICT (tenant_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  -- -----------------------------------------------------------------------------
  -- 5. Ensure projects exist
  -- -----------------------------------------------------------------------------
  INSERT INTO public.projects (tenant_id, slug, name, repo_path)
  VALUES
    (v_tenant_id, 'dls-platform-hub-next', 'DreamLab Platform Hub (Next.js)', '/home/dreamux/Projects/dreamlab/apps/dls-platform-hub-next'),
    (v_tenant_id, 'dls-website-astro', 'DreamLab Website (Astro)', '/home/dreamux/Projects/dreamlab/apps/dls-webapp-astro')
  ON CONFLICT (tenant_id, slug) DO UPDATE SET name = EXCLUDED.name, repo_path = EXCLUDED.repo_path;

  -- Collect project IDs for bulk operations
  SELECT ARRAY_AGG(id) INTO v_project_ids
  FROM public.projects
  WHERE tenant_id = v_tenant_id AND slug IN ('dls-platform-hub-next', 'dls-website-astro');

  -- -----------------------------------------------------------------------------
  -- 6. Ensure project_user_profiles for all projects (bulk upsert)
  -- -----------------------------------------------------------------------------
  INSERT INTO public.project_user_profiles (project_id, user_id, email, display_name, persona, role, status, metadata)
  SELECT p.id, v_user_id, v_admin_email, 'Platform Administrator', 'platform_admin', 'platform_owner', 'active',
         jsonb_build_object('source', 'admin_seed', 'project_slug', p.slug, 'access_scope', 'owner')
  FROM public.projects p
  WHERE p.id = ANY(v_project_ids)
  ON CONFLICT (project_id, user_id) DO UPDATE SET
    email = EXCLUDED.email, display_name = EXCLUDED.display_name,
    persona = EXCLUDED.persona, role = EXCLUDED.role,
    status = EXCLUDED.status, metadata = EXCLUDED.metadata, updated_at = NOW();

  -- -----------------------------------------------------------------------------
  -- 7. Ensure environments for all projects (bulk upsert)
  -- -----------------------------------------------------------------------------
  INSERT INTO public.environments (project_id, key, name)
  SELECT p.id, e.key, e.name
  FROM unnest(v_project_ids) AS p(id)
  CROSS JOIN (VALUES ('prod', 'Production'), ('stage', 'Staging'), ('dev', 'Development')) AS e(key, name)
  ON CONFLICT (project_id, key) DO UPDATE SET name = EXCLUDED.name;

  -- -----------------------------------------------------------------------------
  -- 8. Ensure locales for all projects (bulk upsert)
  -- -----------------------------------------------------------------------------
  INSERT INTO public.project_locales (project_id, locale, is_default)
  SELECT p.id, l.locale, l.is_default
  FROM unnest(v_project_ids) AS p(id)
  CROSS JOIN (VALUES ('en', true), ('it', false)) AS l(locale, is_default)
  ON CONFLICT (project_id, locale) DO UPDATE SET is_default = EXCLUDED.is_default;

  -- -----------------------------------------------------------------------------
  -- NOTE: Content models and entries are NOT seeded here.
  -- They should be created/managed via BFF APIs from the platform app.
  -- This ensures the schema adheres to the current design standard.
  -- -----------------------------------------------------------------------------

  RAISE NOTICE 'Admin + base provisioning complete: %', v_admin_email;
END \$\$;
EOF

echo -e "${GREEN}✓ Admin seed generated successfully${NC}"
echo ""
echo "Next steps:"
echo "  1. Run: pnpm supabase:reset  (or: cd backends/supabase && supabase db reset)"
echo "  2. Log in with:"
echo "     Email: $ADMIN_EMAIL"
echo "     Password: $ADMIN_PASSWORD"
