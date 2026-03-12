-- Rebaselined migration: 0001_platform_core.sql

-- Generated from legacy migrations on 2026-03-09.


-- ============================================================================
-- BEGIN LEGACY: 0001_core.sql
-- ============================================================================

-- Enable pgcrypto for gen_random_uuid()
create extension if not exists "pgcrypto";

-- Table: tenants
create table if not exists tenants (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  created_at timestamptz not null default now()
);

-- Table: tenant_members
create table if not exists tenant_members (
  tenant_id uuid not null references tenants(id) on delete cascade,
  user_id uuid not null, -- Intentionally loose FK to allow flexible auth
  role text not null,
  created_at timestamptz not null default now(),
  primary key (tenant_id, user_id)
);

-- Table: projects
create table if not exists projects (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  slug text not null,
  name text not null,
  repo_path text null,
  created_at timestamptz not null default now(),
  unique (tenant_id, slug)
);

-- Table: environments
create table if not exists environments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  key text not null,
  name text not null,
  created_at timestamptz not null default now(),
  unique (project_id, key)
);

-- Table: project_locales
create table if not exists project_locales (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  locale text not null,
  is_default bool not null default false,
  created_at timestamptz not null default now(),
  unique (project_id, locale)
);

-- Indexes
create index if not exists idx_tenant_members_user_id on tenant_members(user_id);
create index if not exists idx_projects_tenant_id on projects(tenant_id);
create index if not exists idx_environments_project_id on environments(project_id);
create index if not exists idx_project_locales_project_id on project_locales(project_id);

-- Partial index for unique default locale per project
create unique index if not exists idx_project_locales_one_default 
on project_locales(project_id) 
where is_default = true;

-- Enable RLS
alter table tenants enable row level security;
alter table tenant_members enable row level security;
alter table projects enable row level security;
alter table environments enable row level security;
alter table project_locales enable row level security;

-- Policies

-- Tenants: visible if you are a member
create policy "Tenants visible to members" 
on tenants for select 
using (
  exists (
    select 1 from tenant_members 
    where tenant_members.tenant_id = tenants.id 
    and tenant_members.user_id = auth.uid()
  )
);

-- Tenant Members: visible if you are a member of the same tenant
create policy "Members visible to members" 
on tenant_members for select 
using (
  exists (
    select 1 from tenant_members as my_membership 
    where my_membership.tenant_id = tenant_members.tenant_id 
    and my_membership.user_id = auth.uid()
  )
);

-- Projects: visible if you are a member of the parent tenant
create policy "Projects visible to tenant members" 
on projects for all
using (
  exists (
    select 1 from tenant_members 
    where tenant_members.tenant_id = projects.tenant_id 
    and tenant_members.user_id = auth.uid()
  )
);

-- Environments: visible if you are a member of the project's tenant
create policy "Environments visible to tenant members" 
on environments for all
using (
  exists (
    select 1 from projects 
    join tenant_members on projects.tenant_id = tenant_members.tenant_id 
    where projects.id = environments.project_id 
    and tenant_members.user_id = auth.uid()
  )
);

-- Project Locales: visible if you are a member of the project's tenant
create policy "Locales visible to tenant members" 
on project_locales for all
using (
  exists (
    select 1 from projects 
    join tenant_members on projects.tenant_id = tenant_members.tenant_id 
    where projects.id = project_locales.project_id 
    and tenant_members.user_id = auth.uid()
  )
);

-- Seed Data
do $$
declare
  v_tenant_id uuid;
  v_project_id uuid;
begin
  -- Insert Tenant
  insert into tenants (name, slug)
  values ('DreamLab Solutions', 'dreamlab-solutions')
  on conflict (slug) do update set name = excluded.name
  returning id into v_tenant_id;

  -- If we didn't insert (conflict), get the id
  if v_tenant_id is null then
    select id into v_tenant_id from tenants where slug = 'dreamlab-solutions';
  end if;

  -- Insert Project
  insert into projects (tenant_id, name, slug, repo_path)
  values (v_tenant_id, 'TradeMind Demo', 'trademind-demo', 'github.com/dreamlab/trademind')
  on conflict (tenant_id, slug) do update set name = excluded.name
  returning id into v_project_id;

  if v_project_id is null then
    select id into v_project_id from projects where tenant_id = v_tenant_id and slug = 'trademind-demo';
  end if;

  -- Insert Environments
  insert into environments (project_id, key, name)
  values 
    (v_project_id, 'dev', 'Development'),
    (v_project_id, 'stage', 'Staging'),
    (v_project_id, 'prod', 'Production')
  on conflict (project_id, key) do nothing;

  -- Insert Locales
  insert into project_locales (project_id, locale, is_default)
  values 
    (v_project_id, 'en', true),
    (v_project_id, 'it', false)
  on conflict (project_id, locale) do nothing;

end $$;


-- END LEGACY: 0001_core.sql

-- ============================================================================
-- BEGIN LEGACY: 0012_platforms.sql
-- ============================================================================

create table if not exists platforms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  description text,
  website text,
  logo_url text,
  is_official boolean default false,
  status text default 'active',
  capabilities text[] default '{}',
  created_at timestamptz default now()
);

create table if not exists platform_subscriptions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references tenants(id) on delete cascade,
  platform_id uuid references platforms(id) on delete cascade,
  plan_id text,
  status text default 'active',
  current_period_end timestamptz,
  created_at timestamptz default now()
);

create table if not exists platform_links (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references tenants(id) on delete cascade,
  platform_id uuid references platforms(id) on delete cascade,
  path text not null,
  target_url text not null,
  is_visible boolean default true,
  clicks integer default 0,
  created_at timestamptz default now()
);


-- END LEGACY: 0012_platforms.sql

-- ============================================================================
-- BEGIN LEGACY: 0009_billing.sql
-- ============================================================================

create table if not exists billing_provider_definitions (
  key text primary key,
  name text not null,
  description text,
  logo_url text,
  created_at timestamptz default now()
);

create table if not exists tenant_billing_providers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null, -- assumption: linked to tenants table, but no FK enforced to keep it loose for now or rely on existing tables
  provider_key text references billing_provider_definitions(key) on delete cascade not null,
  status text default 'disconnected' check (status in ('disconnected', 'connected', 'error')),
  config jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(tenant_id, provider_key)
);

create table if not exists billing_products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid, -- if null, system level product
  provider_id text, -- external ID from stripe/etc
  name text not null,
  description text,
  active boolean default true,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

create table if not exists billing_plans (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references billing_products(id) on delete cascade not null,
  provider_plan_id text, -- external ID
  name text,
  interval text check (interval in ('month', 'year', 'one_time')),
  amount integer not null, -- in cents
  currency text default 'usd',
  trial_days integer default 0,
  active boolean default true,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

create table if not exists tenant_subscriptions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  provider_key text references billing_provider_definitions(key),
  plan_id uuid references billing_plans(id),
  status text default 'active' check (status in ('active', 'canceled', 'past_due', 'trialing', 'incomplete')),
  current_period_end timestamptz,
  cancel_at_period_end boolean default false,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists tenant_entitlements (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  project_id uuid references projects(id) on delete cascade,
  environment_id uuid references environments(id) on delete cascade,
  key text not null,
  value jsonb not null,
  source text default 'manual' check (source in ('plan', 'manual', 'system')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(tenant_id, project_id, environment_id, key) -- Ensure unique override per scope
);

-- RLS

alter table billing_provider_definitions enable row level security;
alter table tenant_billing_providers enable row level security;
alter table billing_products enable row level security;
alter table billing_plans enable row level security;
alter table tenant_subscriptions enable row level security;
alter table tenant_entitlements enable row level security;

-- Policies

-- Public definitions
create policy "Public billing definitions read" on billing_provider_definitions for select using (true);

-- Tenant Billing Providers: Access via tenant_members
create policy "Tenant members manage providers" on tenant_billing_providers
  for all using (
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = tenant_billing_providers.tenant_id
      and tm.user_id = auth.uid()
    )
  );

-- Products: Read if system (tenant_id null) OR if member of tenant
create policy "Read products" on billing_products
  for select using (
    tenant_id is null or
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = billing_products.tenant_id
      and tm.user_id = auth.uid()
    )
  );
create policy "Tenant members manage products" on billing_products
  for all using (
    tenant_id is not null and
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = billing_products.tenant_id
      and tm.user_id = auth.uid()
    )
  );

-- Plans: Read public
create policy "Read plans" on billing_plans for select using (true);
-- Write: complicated, simplified to 'if product is manageable'
create policy "Manage plans" on billing_plans
  for all using (
    exists (
      select 1 from billing_products bp
      where bp.id = billing_plans.product_id
      and (
        bp.tenant_id is not null and exists (
          select 1 from tenant_members tm
          where tm.tenant_id = bp.tenant_id
          and tm.user_id = auth.uid()
        )
      )
    )
  );

-- Subscriptions
create policy "Tenant members read subscriptions" on tenant_subscriptions
  for select using (
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = tenant_subscriptions.tenant_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Tenant members manage subscriptions" on tenant_subscriptions
  for all using (
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = tenant_subscriptions.tenant_id
      and tm.user_id = auth.uid()
    )
  );

-- Entitlements
create policy "Tenant members read entitlements" on tenant_entitlements
  for select using (
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = tenant_entitlements.tenant_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Tenant members manage entitlements" on tenant_entitlements
  for all using (
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = tenant_entitlements.tenant_id
      and tm.user_id = auth.uid()
    )
  );

-- Seed
insert into billing_provider_definitions (key, name, description) values
('stripe', 'Stripe', 'Global payment processing'),
('whop', 'Whop', 'Digital marketplace'),
('bunq', 'bunq', 'Modern banking')
on conflict (key) do nothing;


-- END LEGACY: 0009_billing.sql

-- ============================================================================
-- BEGIN LEGACY: 0017_credentials.sql
-- ============================================================================

-- Connector credentials metadata with Vault references

create table if not exists connector_credentials (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  tenant_id uuid references tenants(id) on delete cascade,
  provider_key text not null,
  display_name text not null,
  status text not null default 'active' check (status in ('active', 'rotated', 'revoked')),
  scope text not null default 'project' check (scope in ('project', 'tenant', 'global')),
  vault_secret_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  created_at timestamptz not null default now(),
  rotated_at timestamptz,
  revoked_at timestamptz
);

create table if not exists credential_events (
  id uuid primary key default gen_random_uuid(),
  credential_id uuid not null references connector_credentials(id) on delete cascade,
  event_type text not null check (event_type in ('created', 'rotated', 'revoked', 'accessed')),
  actor_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_connector_credentials_project on connector_credentials(project_id);
create index if not exists idx_connector_credentials_tenant on connector_credentials(tenant_id);
create index if not exists idx_connector_credentials_provider on connector_credentials(provider_key);
create index if not exists idx_credential_events_credential on credential_events(credential_id);

alter table connector_credentials enable row level security;
alter table credential_events enable row level security;

create policy "Credentials visible to tenant members" on connector_credentials
  for all using (
    exists (
      select 1 from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = connector_credentials.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Credential events visible to tenant members" on credential_events
  for all using (
    exists (
      select 1 from connector_credentials c
      join projects p on p.id = c.project_id
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where c.id = credential_events.credential_id
      and tm.user_id = auth.uid()
    )
  );


-- END LEGACY: 0017_credentials.sql

-- ============================================================================
-- BEGIN LEGACY: 0026_project_user_profiles.sql
-- ============================================================================

-- Project user profiles + signup trigger

create table if not exists platform_project_mappings (
  platform_id uuid not null references platforms(id) on delete cascade,
  project_id uuid not null references projects(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (platform_id, project_id)
);

create index if not exists idx_platform_project_mappings_platform_id
  on platform_project_mappings(platform_id);
create index if not exists idx_platform_project_mappings_project_id
  on platform_project_mappings(project_id);

create table if not exists project_user_profiles (
  project_id uuid not null references projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  persona text,
  role text,
  status text not null default 'active',
  last_sign_in_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (project_id, user_id)
);

create index if not exists idx_project_user_profiles_user_id
  on project_user_profiles(user_id);
create index if not exists idx_project_user_profiles_project_id
  on project_user_profiles(project_id);

alter table platform_project_mappings enable row level security;
alter table project_user_profiles enable row level security;

create policy "Platform project mappings visible to tenant members"
  on platform_project_mappings
  for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = platform_project_mappings.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Project user profiles visible to tenant members"
  on project_user_profiles
  for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = project_user_profiles.project_id
      and tm.user_id = auth.uid()
    )
  );

create or replace function public.handle_auth_user_profile_upsert()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_tenant_slug text;
  v_project_slug text;
  v_platform_id uuid;
  v_platform_slug text;
  v_tenant_id uuid;
  v_project_id uuid;
  v_role text;
  v_persona text;
  v_display_name text;
  v_status text;
  v_metadata jsonb;
begin
  v_metadata := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_platform_slug := nullif(btrim(v_metadata->>'platform_slug'), '');
  v_tenant_slug := nullif(btrim(v_metadata->>'tenant_slug'), '');
  v_project_slug := nullif(btrim(v_metadata->>'project_slug'), '');

  if (v_metadata ? 'platform_id') and (v_metadata->>'platform_id') ~* '^[0-9a-f\\-]{36}$' then
    v_platform_id := (v_metadata->>'platform_id')::uuid;
  end if;

  v_role := coalesce(nullif(v_metadata->>'role', ''), 'member');
  v_persona := nullif(v_metadata->>'persona', '');
  v_display_name := nullif(v_metadata->>'display_name', '');
  v_status := coalesce(nullif(v_metadata->>'status', ''), 'active');

  if v_display_name is null then
    v_display_name := nullif(v_metadata->>'name', '');
  end if;

  if v_platform_id is null and v_platform_slug is not null then
    select id into v_platform_id
    from platforms
    where slug = v_platform_slug
    limit 1;
  end if;

  if v_tenant_id is null and v_platform_id is not null then
    select tenant_id into v_tenant_id
    from platform_subscriptions
    where platform_id = v_platform_id
      and (status is null or status = 'active')
    order by created_at desc
    limit 1;
  end if;

  if v_project_id is null and v_platform_id is not null then
    select p.id, p.tenant_id into v_project_id, v_tenant_id
    from platform_project_mappings ppm
    join projects p on p.id = ppm.project_id
    where ppm.platform_id = v_platform_id
      and (v_tenant_id is null or p.tenant_id = v_tenant_id)
    order by ppm.created_at desc
    limit 1;
  end if;

  if v_tenant_id is null and v_tenant_slug is not null then
    select id into v_tenant_id
    from tenants
    where slug = v_tenant_slug
    limit 1;
  end if;

  if v_project_id is null and v_project_slug is not null and v_tenant_id is not null then
    select id into v_project_id
    from projects
    where tenant_id = v_tenant_id
    and slug = v_project_slug
    limit 1;
  end if;

  if v_tenant_id is null and v_project_id is null then
    select id into v_tenant_id
    from tenants
    where slug = 'dreamlab-solutions'
    limit 1;

    if v_tenant_id is not null then
      select id into v_project_id
      from projects
      where tenant_id = v_tenant_id
      and slug = 'dls-platform-manager'
      limit 1;
    end if;
  end if;

  if v_tenant_id is null then
    return new;
  end if;

  insert into tenant_members (tenant_id, user_id, role)
  values (v_tenant_id, new.id, v_role)
  on conflict (tenant_id, user_id)
  do update set role = excluded.role;

  if v_project_id is null then
    return new;
  end if;

  insert into project_user_profiles (
    project_id,
    user_id,
    email,
    display_name,
    persona,
    role,
    status,
    last_sign_in_at,
    metadata,
    created_at,
    updated_at
  )
  values (
    v_project_id,
    new.id,
    new.email,
    v_display_name,
    v_persona,
    v_role,
    v_status,
    new.last_sign_in_at,
    v_metadata,
    now(),
    now()
  )
  on conflict (project_id, user_id)
  do update set
    email = excluded.email,
    display_name = excluded.display_name,
    persona = excluded.persona,
    role = excluded.role,
    status = excluded.status,
    last_sign_in_at = excluded.last_sign_in_at,
    metadata = excluded.metadata,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists trg_auth_user_profile_upsert on auth.users;
create trigger trg_auth_user_profile_upsert
  after insert or update of raw_user_meta_data, email, last_sign_in_at
  on auth.users
  for each row
  execute procedure public.handle_auth_user_profile_upsert();


-- END LEGACY: 0026_project_user_profiles.sql

-- ============================================================================
-- BEGIN LEGACY: 0027_custom_access_token_hook.sql
-- ============================================================================

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims jsonb;
  v_user_id uuid;
  v_tenant_id uuid;
  v_tenant_slug text;
  v_project_id uuid;
  v_project_slug text;
  v_platform_role text;
  v_entitlements jsonb;
  v_client_id text;
begin
  claims := coalesce(event->'claims', '{}'::jsonb);
  v_user_id := nullif(event->>'user_id', '')::uuid;

  if v_user_id is not null then
    select tm.tenant_id, tm.role
      into v_tenant_id, v_platform_role
      from public.tenant_members tm
      where tm.user_id = v_user_id
      order by tm.created_at desc
      limit 1;

    if v_tenant_id is not null then
      select t.slug
        into v_tenant_slug
        from public.tenants t
        where t.id = v_tenant_id;

      select pup.project_id
        into v_project_id
        from public.project_user_profiles pup
        join public.projects p on p.id = pup.project_id
        where pup.user_id = v_user_id
        order by pup.updated_at desc
        limit 1;

      if v_project_id is null then
        select p.id
          into v_project_id
          from public.projects p
          where p.tenant_id = v_tenant_id
          order by p.created_at desc
          limit 1;
      end if;

      if v_project_id is not null then
        select p.slug
          into v_project_slug
          from public.projects p
          where p.id = v_project_id;
      end if;

      select jsonb_object_agg(ent.key, ent.value)
        into v_entitlements
        from (
          select distinct on (te.key)
            te.key,
            te.value
          from public.tenant_entitlements te
          where te.tenant_id = v_tenant_id
            and te.environment_id is null
            and (te.project_id is null or te.project_id = v_project_id)
          order by te.key, (te.project_id is null), te.updated_at desc
        ) ent;
    end if;
  end if;

  if v_platform_role is not null then
    claims := jsonb_set(claims, '{platform_role}', to_jsonb(v_platform_role), true);
  end if;

  if v_tenant_id is not null then
    claims := jsonb_set(claims, '{tenant_id}', to_jsonb(v_tenant_id), true);
  end if;

  if v_tenant_slug is not null then
    claims := jsonb_set(claims, '{tenant_slug}', to_jsonb(v_tenant_slug), true);
  end if;

  if v_project_id is not null then
    claims := jsonb_set(claims, '{project_id}', to_jsonb(v_project_id), true);
  end if;

  if v_project_slug is not null then
    claims := jsonb_set(claims, '{project_slug}', to_jsonb(v_project_slug), true);
  end if;

  if v_entitlements is not null then
    claims := jsonb_set(claims, '{entitlements}', v_entitlements, true);
  end if;

  v_client_id := nullif(claims->>'client_id', '');
  if v_client_id is null then
    v_client_id := nullif(claims#>>'{app_metadata,client_id}', '');
  end if;
  if v_client_id is null then
    v_client_id := nullif(claims#>>'{user_metadata,client_id}', '');
  end if;

  if v_client_id is not null then
    claims := jsonb_set(claims, '{client_id}', to_jsonb(v_client_id), true);
  end if;

  return jsonb_build_object('claims', claims);
end;
$$;

-- Grant access to function to supabase_auth_admin
grant execute
  on function public.custom_access_token_hook(jsonb)
  to supabase_auth_admin;

-- Grant access to schema to supabase_auth_admin
grant usage on schema public to supabase_auth_admin;

-- Revoke function permissions from authenticated, anon and public
revoke execute
  on function public.custom_access_token_hook(jsonb)
  from authenticated, anon, public;


-- END LEGACY: 0027_custom_access_token_hook.sql

-- ============================================================================
-- BEGIN LEGACY: 0028_supabase_auth_admin_rls.sql
-- ============================================================================

-- Allow supabase_auth_admin role to read core tenant/project tables used by auth hooks.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'tenants'
      AND policyname = 'supabase_auth_admin_read_tenants'
  ) THEN
    CREATE POLICY "supabase_auth_admin_read_tenants"
      ON public.tenants
      FOR SELECT
      TO supabase_auth_admin
      USING (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'tenant_members'
      AND policyname = 'supabase_auth_admin_read_tenant_members'
  ) THEN
    CREATE POLICY "supabase_auth_admin_read_tenant_members"
      ON public.tenant_members
      FOR SELECT
      TO supabase_auth_admin
      USING (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'projects'
      AND policyname = 'supabase_auth_admin_read_projects'
  ) THEN
    CREATE POLICY "supabase_auth_admin_read_projects"
      ON public.projects
      FOR SELECT
      TO supabase_auth_admin
      USING (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'project_user_profiles'
      AND policyname = 'supabase_auth_admin_read_project_user_profiles'
  ) THEN
    CREATE POLICY "supabase_auth_admin_read_project_user_profiles"
      ON public.project_user_profiles
      FOR SELECT
      TO supabase_auth_admin
      USING (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'tenant_entitlements'
      AND policyname = 'supabase_auth_admin_read_tenant_entitlements'
  ) THEN
    CREATE POLICY "supabase_auth_admin_read_tenant_entitlements"
      ON public.tenant_entitlements
      FOR SELECT
      TO supabase_auth_admin
      USING (true);
  END IF;
END $$;


-- END LEGACY: 0028_supabase_auth_admin_rls.sql

-- ============================================================================
-- BEGIN LEGACY: 0029_fix_tenant_members_policy.sql
-- ============================================================================

-- Fix recursive RLS policy on tenant_members by simplifying to direct ownership.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'tenant_members'
      AND policyname = 'Members visible to members'
  ) THEN
    EXECUTE 'DROP POLICY "Members visible to members" ON public.tenant_members';
  END IF;
END $$;

CREATE POLICY "Members visible to self"
ON public.tenant_members
FOR SELECT
TO public
USING (user_id = auth.uid());


-- END LEGACY: 0029_fix_tenant_members_policy.sql

-- ============================================================================
-- BEGIN LEGACY: 0030_seed_default_tenant_membership.sql
-- ============================================================================

-- Seed a default tenant + membership for local development.
DO $$
DECLARE
  v_user uuid;
  v_tenant uuid;
BEGIN
  SELECT id
  INTO v_user
  FROM auth.users
  WHERE email = 'info@dreamlab.solutions'
  LIMIT 1;

  IF v_user IS NULL THEN
    RAISE NOTICE 'Seed skipped: auth.users missing info@dreamlab.solutions';
    RETURN;
  END IF;

  INSERT INTO public.tenants (slug, name)
  VALUES ('dreamlab', 'Dreamlab')
  ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO v_tenant;

  IF v_tenant IS NULL THEN
    SELECT id INTO v_tenant FROM public.tenants WHERE slug = 'dreamlab';
  END IF;

  INSERT INTO public.tenant_members (tenant_id, user_id, role)
  VALUES (v_tenant, v_user, 'tenant_owner')
  ON CONFLICT (tenant_id, user_id) DO UPDATE SET role = EXCLUDED.role;
END $$;


-- END LEGACY: 0030_seed_default_tenant_membership.sql

-- ============================================================================
-- BEGIN LEGACY: 0031_supabase_auth_admin_table_grants.sql
-- ============================================================================

-- Grant table-level SELECT required by custom_access_token_hook.
-- RLS policies are not sufficient without base table privileges.

grant select on table public.tenants to supabase_auth_admin;
grant select on table public.tenant_members to supabase_auth_admin;
grant select on table public.projects to supabase_auth_admin;
grant select on table public.project_user_profiles to supabase_auth_admin;
grant select on table public.tenant_entitlements to supabase_auth_admin;


-- END LEGACY: 0031_supabase_auth_admin_table_grants.sql

-- ============================================================================
-- BEGIN LEGACY: 0035_stripe_i18n.sql
-- ============================================================================

-- Stripe i18n + reconciliation scaffolding

alter table billing_products
  add column if not exists locale text,
  add column if not exists stripe_product_id text,
  add column if not exists stripe_account_id text;

alter table billing_plans
  add column if not exists locale text,
  add column if not exists stripe_price_id text,
  add column if not exists stripe_product_id text;

alter table tenant_subscriptions
  add column if not exists stripe_subscription_id text,
  add column if not exists stripe_customer_id text;

create table if not exists billing_customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid,
  user_id uuid,
  provider_key text references billing_provider_definitions(key),
  provider_customer_id text not null,
  status text default 'active' check (status in ('active', 'disabled', 'error')),
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(provider_key, provider_customer_id),
  unique(tenant_id, user_id, provider_key)
);

create table if not exists stripe_events (
  id uuid primary key default gen_random_uuid(),
  event_id text not null,
  event_type text not null,
  payload jsonb not null,
  received_at timestamptz default now(),
  processed_at timestamptz,
  status text default 'pending' check (status in ('pending', 'processed', 'error')),
  last_error text,
  unique(event_id)
);

create unique index if not exists billing_products_stripe_product_id_idx
  on billing_products (stripe_product_id)
  where stripe_product_id is not null;

create unique index if not exists billing_plans_stripe_price_id_idx
  on billing_plans (stripe_price_id)
  where stripe_price_id is not null;

create unique index if not exists tenant_subscriptions_stripe_subscription_id_idx
  on tenant_subscriptions (stripe_subscription_id)
  where stripe_subscription_id is not null;

alter table billing_customers enable row level security;
alter table stripe_events enable row level security;

create policy "Tenant members read billing customers" on billing_customers
  for select using (
    tenant_id is null or
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = billing_customers.tenant_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Tenant members manage billing customers" on billing_customers
  for all using (
    tenant_id is not null and
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = billing_customers.tenant_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Service role manages stripe events" on stripe_events
  for all using (auth.role() = 'service_role');


-- END LEGACY: 0035_stripe_i18n.sql

-- ============================================================================
-- BEGIN LEGACY: 0036_platform_sim_racing_schema.sql
-- ============================================================================

-- Sim Racing platform schema: create tables directly in platform_sim_racing schema
-- Tables are now created here instead of being moved from public schema

create schema if not exists platform_sim_racing;

-- Teams table
create table if not exists platform_sim_racing.sim_teams (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade not null,
  name text not null,
  visibility text default 'private' check (visibility in ('private', 'public', 'unlisted')),
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Team members table
create table if not exists platform_sim_racing.sim_team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid references platform_sim_racing.sim_teams(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  role text not null check (role in ('team_manager', 'data_analyst', 'simdriver', 'crew', 'marketing', 'content_creator')),
  created_at timestamptz default now(),
  unique(team_id, user_id)
);

-- Team policies table
create table if not exists platform_sim_racing.sim_team_policies (
  id uuid primary key default gen_random_uuid(),
  team_id uuid references platform_sim_racing.sim_teams(id) on delete cascade not null,
  policy_key text not null,
  value jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  unique(team_id, policy_key)
);

-- Team sessions table
create table if not exists platform_sim_racing.sim_team_sessions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid references platform_sim_racing.sim_teams(id) on delete cascade not null,
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  server_info jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

-- Telemetry sources table
create table if not exists platform_sim_racing.sim_telemetry_sources (
  id uuid primary key default gen_random_uuid(),
  team_id uuid references platform_sim_racing.sim_teams(id) on delete cascade not null,
  kind text not null check (kind in ('udp', 'motec')),
  config jsonb default '{}'::jsonb,
  status text default 'disconnected' check (status in ('connected', 'disconnected', 'error', 'active')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Telemetry sessions table
create table if not exists platform_sim_racing.sim_telemetry_sessions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid references platform_sim_racing.sim_teams(id) on delete cascade not null,
  session_ref text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

-- Setup assets table
create table if not exists platform_sim_racing.sim_setup_assets (
  id uuid primary key default gen_random_uuid(),
  team_id uuid references platform_sim_racing.sim_teams(id) on delete cascade not null,
  name text not null,
  car text not null,
  track text not null,
  version text default 'v1.0',
  content text,
  share_scope text default 'private' check (share_scope in ('private', 'team', 'public')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Enable RLS
alter table platform_sim_racing.sim_teams enable row level security;
alter table platform_sim_racing.sim_team_members enable row level security;
alter table platform_sim_racing.sim_team_policies enable row level security;
alter table platform_sim_racing.sim_team_sessions enable row level security;
alter table platform_sim_racing.sim_telemetry_sources enable row level security;
alter table platform_sim_racing.sim_telemetry_sessions enable row level security;
alter table platform_sim_racing.sim_setup_assets enable row level security;

-- Drop existing policies if they exist (for idempotency)
drop policy if exists "Tenant members view teams" on platform_sim_racing.sim_teams;
drop policy if exists "Tenant members manage teams" on platform_sim_racing.sim_teams;
drop policy if exists "Team members view subresources" on platform_sim_racing.sim_team_members;
drop policy if exists "Tenant members access team policies" on platform_sim_racing.sim_team_policies;
drop policy if exists "Tenant members access sessions" on platform_sim_racing.sim_team_sessions;
drop policy if exists "Tenant members access telemetry sources" on platform_sim_racing.sim_telemetry_sources;
drop policy if exists "Tenant members access telemetry sessions" on platform_sim_racing.sim_telemetry_sessions;
drop policy if exists "Tenant members access setups" on platform_sim_racing.sim_setup_assets;

-- Create policies
create policy "Tenant members view teams" on platform_sim_racing.sim_teams
  for select using (
    exists (
      select 1 from public.tenant_members tm
      where tm.tenant_id = platform_sim_racing.sim_teams.tenant_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Tenant members manage teams" on platform_sim_racing.sim_teams
  for all using (
    exists (
      select 1 from public.tenant_members tm
      where tm.tenant_id = platform_sim_racing.sim_teams.tenant_id
      and tm.user_id = auth.uid()
      and tm.role in ('owner', 'admin')
    )
  );

create policy "Team members view subresources" on platform_sim_racing.sim_team_members
  for select using (
    exists (
      select 1 from platform_sim_racing.sim_teams t
      join public.tenant_members tm on tm.tenant_id = t.tenant_id
      where t.id = platform_sim_racing.sim_team_members.team_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Tenant members access team policies" on platform_sim_racing.sim_team_policies
  for all using (
    exists (
      select 1 from platform_sim_racing.sim_teams t
      join public.tenant_members tm on tm.tenant_id = t.tenant_id
      where t.id = platform_sim_racing.sim_team_policies.team_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Tenant members access sessions" on platform_sim_racing.sim_team_sessions
  for all using (
    exists (
      select 1 from platform_sim_racing.sim_teams t
      join public.tenant_members tm on tm.tenant_id = t.tenant_id
      where t.id = platform_sim_racing.sim_team_sessions.team_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Tenant members access telemetry sources" on platform_sim_racing.sim_telemetry_sources
  for all using (
    exists (
      select 1 from platform_sim_racing.sim_teams t
      join public.tenant_members tm on tm.tenant_id = t.tenant_id
      where t.id = platform_sim_racing.sim_telemetry_sources.team_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Tenant members access telemetry sessions" on platform_sim_racing.sim_telemetry_sessions
  for all using (
    exists (
      select 1 from platform_sim_racing.sim_teams t
      join public.tenant_members tm on tm.tenant_id = t.tenant_id
      where t.id = platform_sim_racing.sim_telemetry_sessions.team_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Tenant members access setups" on platform_sim_racing.sim_setup_assets
  for all using (
    exists (
      select 1 from platform_sim_racing.sim_teams t
      join public.tenant_members tm on tm.tenant_id = t.tenant_id
      where t.id = platform_sim_racing.sim_setup_assets.team_id
      and tm.user_id = auth.uid()
    )
  );


-- END LEGACY: 0036_platform_sim_racing_schema.sql

-- ============================================================================
-- BEGIN LEGACY: 0040_platform_users.sql
-- ============================================================================

-- Platform Users Domain
-- Issue: #110 - Platform Users domain (separate from tenant collaborators)
-- Purpose: Create a dedicated platform_users table with full lifecycle management
--          (invite → active → suspended/revoked) with audit events

--------------------------------------------------------------------------------
-- SECTION 1: Platform Users Table
--------------------------------------------------------------------------------

-- Table: platform_users
-- Represents platform-level users with independent lifecycle from tenant membership
create table if not exists public.platform_users (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid references auth.users(id) on delete set null,
  email text not null,
  display_name text,
  status text not null default 'pending' check (status in (
    'pending',    -- Invited but hasn't accepted/activated
    'active',     -- Fully active platform user
    'suspended',  -- Temporarily suspended
    'revoked'     -- Permanently revoked access
  )),
  role text not null default 'platform_member' check (role in (
    'platform_owner',    -- Full platform ownership
    'platform_admin',   -- Platform administration
    'platform_member'   -- Standard platform user
  )),
  metadata jsonb not null default '{}'::jsonb,
  invited_at timestamptz,
  activated_at timestamptz,
  suspended_at timestamptz,
  revoked_at timestamptz,
  invited_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Indexes for common queries
create index if not exists idx_platform_users_auth_user_id 
  on public.platform_users(auth_user_id);

create index if not exists idx_platform_users_email 
  on public.platform_users(email);

create index if not exists idx_platform_users_status 
  on public.platform_users(status);

create index if not exists idx_platform_users_created_at 
  on public.platform_users(created_at desc);

--------------------------------------------------------------------------------
-- SECTION 2: Audit Events Table
--------------------------------------------------------------------------------

-- Table: platform_user_audit_events
-- Tracks all state changes for platform users
create table if not exists public.platform_user_audit_events (
  id uuid primary key default gen_random_uuid(),
  platform_user_id uuid not null references public.platform_users(id) on delete cascade,
  action text not null check (action in (
    'invited',     -- User was invited to platform
    'activated',  -- User activated their platform access
    'suspended',  -- User was suspended
    'reactivated',-- User was reactivated after suspension
    'revoked'     -- User access was revoked
  )),
  actor_id uuid,  -- Who triggered the action
  previous_status text,
  new_status text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Indexes for audit queries
create index if not exists idx_platform_user_audit_user_id 
  on public.platform_user_audit_events(platform_user_id);

create index if not exists idx_platform_user_audit_created 
  on public.platform_user_audit_events(created_at desc);

create index if not exists idx_platform_user_audit_user_created 
  on public.platform_user_audit_events(platform_user_id, created_at desc);

--------------------------------------------------------------------------------
-- SECTION 3: Enable RLS
--------------------------------------------------------------------------------

alter table public.platform_users enable row level security;
alter table public.platform_user_audit_events enable row level security;

--------------------------------------------------------------------------------
-- SECTION 4: RLS Policies for platform_users
--------------------------------------------------------------------------------

-- Policy: Platform users can be read by platform admins and the user themselves
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_users'
      and policyname = 'platform_users_select_policy'
  ) then
    create policy "platform_users_select_policy"
      on public.platform_users
      for select
      to authenticated
      using (
        -- User is a platform admin
        exists (
          select 1 from public.platform_users pu
          where pu.auth_user_id = auth.uid()
            and pu.status = 'active'
            and pu.role in ('platform_owner', 'platform_admin')
        )
        -- Or the user is viewing their own record
        or auth.uid() = platform_users.auth_user_id
      );
  end if;
end $$;

-- Policy: Platform admin can manage (invite, update, suspend, revoke) platform users
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_users'
      and policyname = 'platform_users_manage_policy'
  ) then
    create policy "platform_users_manage_policy"
      on public.platform_users
      for all
      to authenticated
      using (
        exists (
          select 1 from public.platform_users pu
          where pu.auth_user_id = auth.uid()
            and pu.status = 'active'
            and pu.role in ('platform_owner', 'platform_admin')
        )
      )
      with check (
        exists (
          select 1 from public.platform_users pu
          where pu.auth_user_id = auth.uid()
            and pu.status = 'active'
            and pu.role in ('platform_owner', 'platform_admin')
        )
      );
  end if;
end $$;

-- Policy: Auth admin can read all platform users for system operations
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_users'
      and policyname = 'platform_users_supabase_auth_admin_read'
  ) then
    create policy "platform_users_supabase_auth_admin_read"
      on public.platform_users
      for select
      to supabase_auth_admin
      using (true);
  end if;
end $$;

--------------------------------------------------------------------------------
-- SECTION 5: RLS Policies for platform_user_audit_events
--------------------------------------------------------------------------------

-- Policy: Audit events readable by platform admins and the user themselves
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_user_audit_events'
      and policyname = 'platform_user_audit_events_select_policy'
  ) then
    create policy "platform_user_audit_events_select_policy"
      on public.platform_user_audit_events
      for select
      to authenticated
      using (
        -- User is a platform admin
        exists (
          select 1 from public.platform_users pu
          where pu.auth_user_id = auth.uid()
            and pu.status = 'active'
            and pu.role in ('platform_owner', 'platform_admin')
        )
        -- Or viewing events for their own user
        or exists (
          select 1 from public.platform_users pu
          where pu.id = platform_user_audit_events.platform_user_id
            and pu.auth_user_id = auth.uid()
        )
      );
  end if;
end $$;

-- Policy: Audit events can only be inserted by the trigger (not directly)
-- No INSERT policy for users - only via trigger function

-- Policy: Auth admin can read all audit events
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_user_audit_events'
      and policyname = 'platform_user_audit_events_supabase_auth_admin_read'
  ) then
    create policy "platform_user_audit_events_supabase_auth_admin_read"
      on public.platform_user_audit_events
      for select
      to supabase_auth_admin
      using (true);
  end if;
end $$;

--------------------------------------------------------------------------------
-- SECTION 6: Audit Trigger Function
--------------------------------------------------------------------------------

-- Function: audit_platform_user_changes
-- Automatically records state changes in audit_events table
create or replace function public.audit_platform_user_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid;
  v_action text;
begin
  v_actor := auth.uid();

  -- Determine the action based on state transition
  if tg_op = 'INSERT' then
    if new.status = 'pending' and new.invited_at is not null then
      v_action := 'invited';
    elsif new.status = 'active' and new.activated_at is not null then
      v_action := 'activated';
    else
      -- Default to invited for new records
      v_action := 'invited';
    end if;

    insert into public.platform_user_audit_events (
      platform_user_id,
      action,
      actor_id,
      new_status,
      metadata
    ) values (
      new.id,
      v_action,
      v_actor,
      new.status,
      to_jsonb(new)
    );
    return new;
  end if;

  if tg_op = 'UPDATE' then
    -- Track status transitions
    if old.status != new.status then
      case new.status
        when 'active' then
          -- Check if reactivating from suspended
          if old.status = 'suspended' then
            v_action := 'reactivated';
          else
            v_action := 'activated';
          end if;
        when 'suspended' then
          v_action := 'suspended';
        when 'revoked' then
          v_action := 'revoked';
        else
          v_action := null;
      end case;

      if v_action is not null then
        insert into public.platform_user_audit_events (
          platform_user_id,
          action,
          actor_id,
          previous_status,
          new_status,
          metadata
        ) values (
          new.id,
          v_action,
          v_actor,
          old.status,
          new.status,
          jsonb_build_object('old', to_jsonb(old), 'new', to_jsonb(new))
        );
      end if;
    end if;

    return new;
  end if;

  -- DELETE - record removal (optional, can be extended)
  if tg_op = 'DELETE' then
    insert into public.platform_user_audit_events (
      platform_user_id,
      action,
      actor_id,
      previous_status,
      metadata
    ) values (
      old.id,
      'revoked',
      v_actor,
      old.status,
      to_jsonb(old)
    );
    return old;
  end if;

  return null;
end;
$$;

-- Trigger: Automatically audit platform user changes
drop trigger if exists trg_platform_users_audit on public.platform_users;

create trigger trg_platform_users_audit
after insert or update or delete
on public.platform_users
for each row
execute function public.audit_platform_user_changes();

--------------------------------------------------------------------------------
-- SECTION 7: UpdatedAt Trigger Function
--------------------------------------------------------------------------------

-- Function: set_platform_users_updated_at
-- Automatically updates the updated_at timestamp
create or replace function public.set_platform_users_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Trigger: Automatically update updated_at on changes
drop trigger if exists trg_platform_users_updated_at on public.platform_users;

create trigger trg_platform_users_updated_at
before update on public.platform_users
for each row
execute function public.set_platform_users_updated_at();

--------------------------------------------------------------------------------
-- SECTION 8: Helper Functions for Platform User Management
--------------------------------------------------------------------------------

-- Function: get_current_user_platform_role
-- Returns the platform role of the current authenticated user
create or replace function public.get_current_user_platform_role()
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  return (
    select role
    from public.platform_users
    where auth_user_id = auth.uid()
      and status = 'active'
    order by created_at desc
    limit 1
  );
end;
$$;

-- Function: is_platform_admin
-- Checks if current user is a platform admin
create or replace function public.is_platform_admin()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return (
    exists (
      select 1
      from public.platform_users
      where auth_user_id = auth.uid()
        and status = 'active'
        and role in ('platform_owner', 'platform_admin')
    )
  );
end;
$$;

-- Function: invite_platform_user
-- Helper to invite a new platform user with proper state management
create or replace function public.invite_platform_user(
  p_email text,
  p_display_name text,
  p_role text default 'platform_member',
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_platform_user_id uuid;
begin
  -- Check if caller is a platform admin
  if not public.is_platform_admin() then
    raise exception 'Only platform admins can invite users' using errcode = 'PGRST116';
  end if;

  -- Check if user already exists
  select id into v_user_id 
  from auth.users 
  where email = p_email;

  -- Create platform user record
  insert into public.platform_users (
    auth_user_id,
    email,
    display_name,
    role,
    status,
    metadata,
    invited_at,
    invited_by
  ) values (
    v_user_id,
    p_email,
    p_display_name,
    p_role,
    'pending',
    p_metadata,
    now(),
    auth.uid()
  )
  returning id into v_platform_user_id;

  return v_platform_user_id;
end;
$$;

-- Function: update_platform_user_status
-- Helper to update platform user status with proper validation
create or replace function public.update_platform_user_status(
  p_platform_user_id uuid,
  p_new_status text,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_status text;
  v_user_role text;
begin
  -- Get current user role
  select role into v_user_role
  from public.platform_users
  where auth_user_id = auth.uid()
    and status = 'active'
  order by created_at desc
  limit 1;

  -- Check permissions
  if v_user_role not in ('platform_owner', 'platform_admin') then
    raise exception 'Only platform admins can update user status' using errcode = 'PGRST116';
  end if;

  -- Get current status
  select status into v_current_status
  from public.platform_users
  where id = p_platform_user_id;

  -- Validate status transition
  if v_current_status = 'revoked' then
    raise exception 'Cannot change status of revoked user' using errcode = 'PGRST116';
  end if;

  if p_new_status = 'active' and v_current_status != 'pending' and v_current_status != 'suspended' then
    raise exception 'Invalid status transition from % to %', v_current_status, p_new_status using errcode = 'PGRST116';
  end if;

  -- Update with appropriate timestamps
  update public.platform_users
  set 
    status = p_new_status,
    metadata = p_metadata || jsonb_build_object('status_changed_by', auth.uid()),
    activated_at = case when p_new_status = 'active' and v_current_status != 'active' then now() else activated_at end,
    suspended_at = case when p_new_status = 'suspended' then now() else suspended_at end,
    revoked_at = case when p_new_status = 'revoked' then now() else revoked_at end
  where id = p_platform_user_id;

  -- Audit is handled by trigger
end;
$$;

--------------------------------------------------------------------------------
-- SECTION 9: Grant Permissions
--------------------------------------------------------------------------------

-- Grant table permissions
grant select on public.platform_users to authenticated, supabase_auth_admin;
grant insert, update, delete on public.platform_users to authenticated;

grant select on public.platform_user_audit_events to authenticated, supabase_auth_admin;

-- Grant function permissions
grant execute on function public.get_current_user_platform_role() to authenticated;
grant execute on function public.is_platform_admin() to authenticated;
grant execute on function public.invite_platform_user(text, text, text, jsonb) to authenticated;
grant execute on function public.update_platform_user_status(uuid, text, jsonb) to authenticated;

--------------------------------------------------------------------------------
-- SECTION 10: Notes for Initial Setup
--------------------------------------------------------------------------------

-- To seed the first platform owner, run this manually after migration:
-- INSERT INTO public.platform_users (auth_user_id, email, display_name, role, status, activated_at)
-- SELECT id, email, coalesce(raw_user_meta_data->>'full_name', email), 'platform_owner', 'active', now()
-- FROM auth.users
-- WHERE email = 'your-admin-email@example.com'
-- ON CONFLICT DO NOTHING;


-- END LEGACY: 0040_platform_users.sql

-- ============================================================================
-- BEGIN LEGACY: 0041_stripe_wrapper_vault.sql
-- ============================================================================

-- Stripe wrapper integration backed by Supabase Vault secrets.
-- This migration keeps business logic in Postgres and avoids edge-function dependencies.

create extension if not exists wrappers with schema extensions;
create extension if not exists supabase_vault with schema vault;
create schema if not exists stripe;

do $$
declare
  stripe_secret_id uuid;
begin
  select ds.id
    into stripe_secret_id
  from vault.decrypted_secrets ds
  where ds.name = 'stripe_secret_key'
  limit 1;

  if stripe_secret_id is null then
    raise exception using
      message = 'Missing Vault secret: stripe_secret_key',
      hint = 'Set [db.vault].stripe_secret_key = "env(STRIPE_SECRET_KEY)" in backends/supabase/config.toml and provide STRIPE_SECRET_KEY in backends/supabase/.env.';
  end if;

  if not exists (
    select 1
    from pg_foreign_data_wrapper
    where fdwname = 'stripe_wrapper'
  ) then
    execute 'create foreign data wrapper stripe_wrapper handler extensions.stripe_fdw_handler validator extensions.stripe_fdw_validator';
  end if;

  if not exists (
    select 1
    from pg_foreign_server
    where srvname = 'stripe_wrapper_server'
  ) then
    execute format(
      'create server stripe_wrapper_server foreign data wrapper stripe_wrapper options (api_key_id %L, api_url %L)',
      stripe_secret_id::text,
      'https://api.stripe.com/v1/'
    );
  else
    execute format(
      'alter server stripe_wrapper_server options (set api_key_id %L, set api_url %L)',
      stripe_secret_id::text,
      'https://api.stripe.com/v1/'
    );
  end if;
end
$$;

create foreign table if not exists stripe.products (
  id text,
  name text,
  active boolean,
  default_price text,
  description text,
  created timestamp without time zone,
  updated timestamp without time zone,
  attrs jsonb
)
server stripe_wrapper_server
options (
  object 'products',
  rowid_column 'id',
  schema 'stripe'
);

create foreign table if not exists stripe.prices (
  id text,
  active boolean,
  currency text,
  product text,
  unit_amount bigint,
  type text,
  created timestamp without time zone,
  attrs jsonb
)
server stripe_wrapper_server
options (
  object 'prices',
  schema 'stripe'
);

create or replace function public.sync_stripe_products(
  p_tenant_id uuid,
  p_provider_key text default 'stripe',
  p_locale text default 'en'
)
returns void
language plpgsql
security definer
set search_path = public, extensions, stripe
as $$
begin
  if p_provider_key <> 'stripe' then
    raise exception 'Unsupported provider key for sync_stripe_products: %', p_provider_key;
  end if;

  insert into billing_products (
    tenant_id,
    provider_id,
    name,
    description,
    active,
    metadata,
    locale,
    stripe_product_id
  )
  select
    p_tenant_id,
    sp.id,
    coalesce(sp.name, sp.attrs ->> 'name', sp.id),
    coalesce(sp.description, sp.attrs ->> 'description'),
    coalesce(sp.active, true),
    coalesce(sp.attrs, '{}'::jsonb),
    p_locale,
    sp.id
  from stripe.products sp
  where sp.id is not null
  on conflict (stripe_product_id) do update
  set
    tenant_id = excluded.tenant_id,
    provider_id = excluded.provider_id,
    name = excluded.name,
    description = excluded.description,
    active = excluded.active,
    metadata = excluded.metadata,
    locale = excluded.locale;

  insert into billing_plans (
    product_id,
    provider_plan_id,
    name,
    interval,
    amount,
    currency,
    active,
    metadata,
    stripe_price_id,
    stripe_product_id,
    locale
  )
  select
    bp.id,
    pr.id,
    coalesce(pr.attrs ->> 'nickname', pr.id),
    case
      when coalesce(pr.attrs #>> '{recurring,interval}', pr.type, 'month') in ('month', 'year', 'one_time')
        then coalesce(pr.attrs #>> '{recurring,interval}', pr.type, 'month')
      else 'month'
    end,
    coalesce(pr.unit_amount, 0)::integer,
    coalesce(pr.currency, 'usd'),
    coalesce(pr.active, true),
    coalesce(pr.attrs, '{}'::jsonb),
    pr.id,
    sp.id,
    p_locale
  from stripe.prices pr
  join stripe.products sp on sp.id = pr.product
  join billing_products bp
    on bp.stripe_product_id = sp.id
   and bp.tenant_id is not distinct from p_tenant_id
  where pr.id is not null
  on conflict (stripe_price_id) do update
  set
    product_id = excluded.product_id,
    provider_plan_id = excluded.provider_plan_id,
    name = excluded.name,
    interval = excluded.interval,
    amount = excluded.amount,
    currency = excluded.currency,
    active = excluded.active,
    metadata = excluded.metadata,
    stripe_product_id = excluded.stripe_product_id,
    locale = excluded.locale;
end;
$$;

revoke all on function public.sync_stripe_products(uuid, text, text) from public;
grant execute on function public.sync_stripe_products(uuid, text, text) to service_role;


-- END LEGACY: 0041_stripe_wrapper_vault.sql
