-- Rebaselined migration: 0005_access_and_roles.sql

-- Generated from legacy migrations on 2026-03-09.


-- ============================================================================
-- BEGIN LEGACY: 0003_routing.sql
-- ============================================================================

-- Table: routing_nodes
create table if not exists routing_nodes (
  project_id uuid not null references projects(id) on delete cascade,
  node_id text not null,
  key text not null,
  kind text not null, -- page/collection/dynamic/redirect/group
  segment_key text not null,
  parent_node_id text null,
  position int not null default 0,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (project_id, node_id),
  foreign key (project_id, parent_node_id) references routing_nodes(project_id, node_id) on delete cascade
);

-- Table: routing_locale_mappings
create table if not exists routing_locale_mappings (
  project_id uuid not null references projects(id) on delete cascade,
  locale text not null,
  node_id text not null,
  translated_segment text not null default '',
  primary key (project_id, locale, node_id),
  foreign key (project_id, node_id) references routing_nodes(project_id, node_id) on delete cascade
);

-- Indexes
create index if not exists idx_routing_nodes_parent on routing_nodes(project_id, parent_node_id);
create index if not exists idx_routing_locale_mappings_locale on routing_locale_mappings(project_id, locale);

-- Enable RLS
alter table routing_nodes enable row level security;
alter table routing_locale_mappings enable row level security;

-- Policies

-- Routing Nodes: visible to tenant members
create policy "Routing visible to members" 
on routing_nodes for all
using (
  exists (
    select 1 from projects 
    join tenant_members on projects.tenant_id = tenant_members.tenant_id 
    where projects.id = routing_nodes.project_id 
    and tenant_members.user_id = auth.uid()
  )
);

-- Locale Mappings: visible to tenant members
create policy "Mappings visible to members" 
on routing_locale_mappings for all
using (
  exists (
    select 1 from projects 
    join tenant_members on projects.tenant_id = tenant_members.tenant_id 
    where projects.id = routing_locale_mappings.project_id 
    and tenant_members.user_id = auth.uid()
  )
);

-- Seed Data (One-time)
do $$
begin
  -- Canonical routing is seeded per real project by the operational seeds.
  -- Keep this legacy demo routing block as a no-op.
  null;
end $$;


-- END LEGACY: 0003_routing.sql

-- ============================================================================
-- BEGIN LEGACY: 0005_feature_flags.sql
-- ============================================================================

-- Table: feature_flags
create table if not exists feature_flags (
  key text primary key,
  name text not null,
  description text not null,
  category text not null,
  default_value boolean not null default false,
  requires_restart boolean not null default false,
  dependencies jsonb default '[]'::jsonb,
  affects_routes jsonb default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- Table: feature_flag_overrides
create table if not exists feature_flag_overrides (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  environment_id uuid references environments(id) on delete cascade,
  tenant_id uuid references tenants(id) on delete cascade,
  flag_key text not null references feature_flags(key) on delete cascade,
  value boolean not null,
  updated_at timestamptz not null default now(),
  constraint uq_flag_override unique nulls not distinct (project_id, environment_id, tenant_id, flag_key)
);

-- Indexes
create index if not exists idx_ff_overrides_project on feature_flag_overrides(project_id);
create index if not exists idx_ff_overrides_tenant on feature_flag_overrides(tenant_id);

-- Enable RLS
alter table feature_flags enable row level security;
alter table feature_flag_overrides enable row level security;

-- Policies

-- Feature Flags (Catalog): Readable by all authenticated users
create policy "Feature flags visible to authenticated" 
on feature_flags for select 
to authenticated 
using (true);

-- Overrides: Visible to tenant members
-- Complex check: users can see overrides if they belong to the tenant
-- linked directly, or via project, or via environment.

create policy "Overrides visible to members" 
on feature_flag_overrides for all
using (
  -- Direct tenant match
  (tenant_id is not null and exists (
    select 1 from tenant_members where tenant_id = feature_flag_overrides.tenant_id and user_id = auth.uid()
  ))
  or
  -- Project match
  (project_id is not null and exists (
    select 1 from projects 
    join tenant_members on projects.tenant_id = tenant_members.tenant_id 
    where projects.id = feature_flag_overrides.project_id 
    and tenant_members.user_id = auth.uid()
  ))
  or
  -- Environment match
  (environment_id is not null and exists (
    select 1 from environments
    join projects on environments.project_id = projects.id
    join tenant_members on projects.tenant_id = tenant_members.tenant_id 
    where environments.id = feature_flag_overrides.environment_id 
    and tenant_members.user_id = auth.uid()
  ))
);

-- Seed Data (Idempotent)
insert into feature_flags (key, name, description, category, default_value, affects_routes, dependencies)
values 
  ('cms.content', 'Content Management', 'Enable the core content entry management module.', 'Content', true, '["/content"]', '[]'),
  ('cms.schemaBuilder', 'Schema Builder', 'Allow defining new Content Types and Components dynamically.', 'Builder', true, '["/models"]', '[]'),
  ('cms.components', 'Component Builder', 'Enable the modular component block system.', 'Builder', true, '[]', '["cms.schemaBuilder"]'),
  ('cms.routing', 'Routing Editor', 'Enable the Virtual Tree Routing editor.', 'Routing', true, '["/routing"]', '[]'),
  ('cms.i18n', 'Internationalization', 'Enable multi-language support across content and routing.', 'i18n', true, '[]', '[]'),
  ('cms.a11y', 'Accessibility Guard', 'Enable a11y checks and warnings in the editorial flow.', 'a11y', true, '[]', '[]'),
  ('cms.media', 'Media Library', 'Enable the centralized media asset manager.', 'Core', true, '["/media"]', '[]'),
  ('cms.ops', 'Operations & Audit', 'Enable import/export and audit logs.', 'Ops', false, '["/ops"]', '[]'),
  ('hub.workspace', 'Platform Hub Workspace', 'Enable the DreamLab platform hub workspace.', 'Platform Hub', true, '["/dashboard"]', '[]'),
  ('hub.models', 'Platform Hub Models', 'Enable model registry and content model management in the hub.', 'Platform Hub', true, '["/models"]', '["cms.schemaBuilder"]'),
  ('hub.routing', 'Platform Hub Routing', 'Enable routing management workflows in the hub.', 'Platform Hub', true, '["/routing"]', '["cms.routing"]'),
  ('hub.access', 'Platform Hub Access', 'Enable access and role management in the hub.', 'Platform Hub', true, '["/access"]', '[]'),
  ('hub.environments', 'Platform Hub Environments', 'Enable environment and release-state management in the hub.', 'Platform Hub', true, '["/environments"]', '[]'),
  ('hub.integrations', 'Platform Hub Integrations', 'Enable repo, domains, previews, and implementation integration controls.', 'Platform Hub', true, '["/integrations"]', '[]'),
  ('website.public', 'Public Website Runtime', 'Enable the DreamLab public website publishing/runtime surface.', 'Marketing', true, '["/"]', '[]'),
  ('website.navigation', 'Website Navigation', 'Enable website navigation, SEO, and publishing controls.', 'Marketing', true, '["/content","/routing"]', '["website.public","cms.routing","cms.i18n"]'),
  ('evidence.workspace', 'Evidence Workspace', 'Enable the evidence management workspace.', 'Product', true, '["/evidence"]', '[]'),
  ('evidence.analysis', 'Evidence Analysis', 'Enable AI-assisted evidence analysis and inconsistency workflows.', 'Product', true, '["/evidence/analysis"]', '[]'),
  ('evidence.mail-import', 'Evidence Mail Import', 'Enable evidence inbox and mail-ingestion workflows.', 'Product', true, '["/evidence/import"]', '["evidence.workspace"]'),
  ('project.sync.materialization', 'DB to Repo Materialization', 'Allow the backend to materialize DB-authored routing/composition files into tracked branches.', 'Platform', true, '[]', '[]'),
  ('project.sync.inbound', 'Tracked Branch Inbound Sync', 'Allow tracked branch commits to update canonical DB reconciliation state.', 'Platform', true, '[]', '["project.sync.materialization"]'),
  ('project.sync.webhook', 'Tracked Branch Webhook Reconciliation', 'Allow tracked branch webhooks to observe and reconcile repository commits back into DB state.', 'Platform', true, '[]', '["project.sync.materialization"]')
on conflict (key) do update 
set 
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  default_value = excluded.default_value,
  affects_routes = excluded.affects_routes,
  dependencies = excluded.dependencies;


-- END LEGACY: 0005_feature_flags.sql

-- ============================================================================
-- BEGIN LEGACY: 0013_project_collaborators.sql
-- ============================================================================

create table if not exists project_collaborators (
  project_id uuid not null references projects(id) on delete cascade,
  tenant_id uuid not null references tenants(id) on delete cascade,
  role text not null,
  notes text,
  created_at timestamptz default now(),
  primary key (project_id, tenant_id)
);

alter table project_collaborators enable row level security;

-- Local dev policy: allow read for anon (dev only)
create policy "dev_read_project_collaborators"
  on project_collaborators for select
  using (true);


-- END LEGACY: 0013_project_collaborators.sql

-- ============================================================================
-- BEGIN LEGACY: 0018_platform_config.sql
-- ============================================================================

-- Platform configuration definitions + overrides

create table if not exists config_definitions (
  key text primary key,
  name text not null,
  description text not null,
  category text not null,
  value_type text not null check (value_type in ('string', 'number', 'boolean', 'json', 'secret')),
  scope text not null check (scope in ('system', 'tenant', 'project', 'environment')),
  default_value jsonb,
  schema jsonb,
  is_required boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists config_overrides (
  id uuid primary key default gen_random_uuid(),
  key text not null references config_definitions(key) on delete cascade,
  tenant_id uuid references tenants(id) on delete cascade,
  project_id uuid references projects(id) on delete cascade,
  environment_id uuid references environments(id) on delete cascade,
  value jsonb,
  vault_secret_id uuid,
  updated_by uuid,
  updated_at timestamptz not null default now(),
  constraint uq_config_override unique nulls not distinct (key, tenant_id, project_id, environment_id)
);

create table if not exists config_audit_events (
  id uuid primary key default gen_random_uuid(),
  override_id uuid references config_overrides(id) on delete cascade,
  action text not null check (action in ('created', 'updated', 'deleted', 'rotated')),
  actor_id uuid,
  diff jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_config_definitions_category on config_definitions(category);
create index if not exists idx_config_definitions_scope on config_definitions(scope);
create index if not exists idx_config_overrides_key on config_overrides(key);
create index if not exists idx_config_overrides_tenant on config_overrides(tenant_id);
create index if not exists idx_config_overrides_project on config_overrides(project_id);
create index if not exists idx_config_overrides_environment on config_overrides(environment_id);
create index if not exists idx_config_audit_override on config_audit_events(override_id);

alter table config_definitions enable row level security;
alter table config_overrides enable row level security;
alter table config_audit_events enable row level security;

create policy "Config definitions readable" on config_definitions
  for select using (true);

create policy "Config overrides visible to tenant members" on config_overrides
  for all using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where (
        (config_overrides.project_id is not null and p.id = config_overrides.project_id)
        or (config_overrides.environment_id is not null and p.id = (select e.project_id from environments e where e.id = config_overrides.environment_id))
        or (config_overrides.tenant_id is not null and p.tenant_id = config_overrides.tenant_id)
      )
      and tm.user_id = auth.uid()
    )
  );

create policy "Config audit visible to tenant members" on config_audit_events
  for select using (
    exists (
      select 1
      from config_overrides co
      join projects p on p.id = co.project_id
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where co.id = config_audit_events.override_id
      and tm.user_id = auth.uid()
    )
  );

insert into public.config_definitions (
  key,
  name,
  description,
  category,
  value_type,
  scope,
  default_value,
  schema,
  is_required
)
values
  ('platform.brand.name', 'Brand Name', 'Human-readable brand name for the tenant.', 'branding', 'string', 'tenant', '"DreamLab Solutions"'::jsonb, null, true),
  ('platform.brand.tagline', 'Brand Tagline', 'Primary tagline shown in admin and public experiences.', 'branding', 'string', 'tenant', '"Systems for ambitious digital products."'::jsonb, null, false),
  ('project.app.definitionId', 'App Definition', 'Registry app definition bound to the project.', 'composition', 'string', 'project', null, null, true),
  ('project.site.primaryDomain', 'Primary Domain', 'Primary public domain for the project.', 'domains', 'string', 'project', null, null, true),
  ('project.i18n.defaultLocale', 'Default Locale', 'Default locale for project content and routing.', 'i18n', 'string', 'project', '"en"'::jsonb, '{"type":"string"}'::jsonb, true),
  ('project.repo.materializationMode', 'Materialization Mode', 'Determines how DB state materializes into tracked repository branches.', 'sync', 'string', 'project', '"database_canonical"'::jsonb, '{"type":"string","enum":["database_canonical","disabled"]}'::jsonb, true)
on conflict (key) do update
  set name = excluded.name,
      description = excluded.description,
      category = excluded.category,
      value_type = excluded.value_type,
      scope = excluded.scope,
      default_value = excluded.default_value,
      schema = excluded.schema,
      is_required = excluded.is_required;

create or replace function public.bootstrap_project_config_defaults()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.config_overrides (key, tenant_id, project_id, environment_id, value)
  values ('project.i18n.defaultLocale', null, new.id, null, '"en"'::jsonb)
  on conflict on constraint uq_config_override do update
    set value = excluded.value,
        updated_at = now();

  insert into public.config_overrides (key, tenant_id, project_id, environment_id, value)
  values ('project.repo.materializationMode', null, new.id, null, '"database_canonical"'::jsonb)
  on conflict on constraint uq_config_override do update
    set value = excluded.value,
        updated_at = now();

  insert into public.tenant_entitlements (tenant_id, project_id, environment_id, key, value, source, updated_at)
  values
    ((select tenant_id from public.projects where id = new.id), new.id, null, 'project.routing.manage', '{"enabled":true,"origin":"project-bootstrap"}'::jsonb, 'system', now()),
    ((select tenant_id from public.projects where id = new.id), new.id, null, 'project.content.manage', '{"enabled":true,"origin":"project-bootstrap"}'::jsonb, 'system', now()),
    ((select tenant_id from public.projects where id = new.id), new.id, null, 'project.composition.manage', '{"enabled":true,"origin":"project-bootstrap"}'::jsonb, 'system', now()),
    ((select tenant_id from public.projects where id = new.id), new.id, null, 'project.repo.observe', '{"enabled":true,"origin":"project-bootstrap"}'::jsonb, 'system', now())
  on conflict (tenant_id, project_id, environment_id, key) do update
    set value = excluded.value,
        source = excluded.source,
        updated_at = excluded.updated_at;

  insert into public.project_sync_materializations (
    project_id,
    environment_id,
    artifact_kind,
    source_of_truth,
    tracked_branch,
    materialization_status,
    drift_status,
    metadata,
    updated_at
  )
  select
    new.id,
    e.id,
    artifact_kind.kind,
    'database',
    case e.key
      when 'dev' then 'dev'
      when 'stage' then 'stage'
      else 'main'
    end,
    'pending',
    'unknown',
    jsonb_build_object('bootstrapped', true, 'environmentKey', e.key),
    now()
  from public.environments e
  cross join (
    values
      ('routing'),
      ('composition'),
      ('app_definition'),
      ('registry'),
      ('content_models'),
      ('version_pins'),
      ('package_registry')
  ) as artifact_kind(kind)
  where e.project_id = new.id
  on conflict (project_id, environment_id, artifact_kind) do update
    set source_of_truth = excluded.source_of_truth,
        tracked_branch = excluded.tracked_branch,
        metadata = project_sync_materializations.metadata || excluded.metadata,
        updated_at = excluded.updated_at;

  return new;
end;
$$;

drop trigger if exists bootstrap_project_config_defaults on public.projects;
create trigger bootstrap_project_config_defaults
  after insert on public.projects
  for each row
  execute function public.bootstrap_project_config_defaults();

create or replace function public.bootstrap_environment_sync_defaults()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.project_sync_materializations (
    project_id,
    environment_id,
    artifact_kind,
    source_of_truth,
    tracked_branch,
    materialization_status,
    drift_status,
    metadata,
    updated_at
  )
  select
    new.project_id,
    new.id,
    artifact_kind.kind,
    'database',
    case new.key
      when 'dev' then 'dev'
      when 'stage' then 'stage'
      else 'main'
    end,
    'pending',
    'unknown',
    jsonb_build_object('bootstrapped', true, 'environmentKey', new.key),
    now()
  from (
    values
      ('routing'),
      ('composition'),
      ('app_definition'),
      ('registry'),
      ('content_models'),
      ('version_pins'),
      ('package_registry')
  ) as artifact_kind(kind)
  on conflict (project_id, environment_id, artifact_kind) do update
    set source_of_truth = excluded.source_of_truth,
        tracked_branch = excluded.tracked_branch,
        metadata = project_sync_materializations.metadata || excluded.metadata,
        updated_at = excluded.updated_at;

  return new;
end;
$$;

drop trigger if exists bootstrap_environment_sync_defaults on public.environments;
create trigger bootstrap_environment_sync_defaults
  after insert on public.environments
  for each row
  execute function public.bootstrap_environment_sync_defaults();

insert into public.config_overrides (key, tenant_id, project_id, environment_id, value)
select 'project.i18n.defaultLocale', null, p.id, null, '"en"'::jsonb
from public.projects p
on conflict on constraint uq_config_override do update
  set value = excluded.value,
      updated_at = now();

insert into public.config_overrides (key, tenant_id, project_id, environment_id, value)
select 'project.repo.materializationMode', null, p.id, null, '"database_canonical"'::jsonb
from public.projects p
on conflict on constraint uq_config_override do update
  set value = excluded.value,
      updated_at = now();

insert into public.tenant_entitlements (tenant_id, project_id, environment_id, key, value, source, updated_at)
select
  p.tenant_id,
  p.id,
  null,
  entitlement.key,
  entitlement.value,
  'system',
  now()
from public.projects p
cross join (
  values
    ('project.routing.manage', '{"enabled":true,"origin":"project-backfill"}'::jsonb),
    ('project.content.manage', '{"enabled":true,"origin":"project-backfill"}'::jsonb),
    ('project.composition.manage', '{"enabled":true,"origin":"project-backfill"}'::jsonb),
    ('project.repo.observe', '{"enabled":true,"origin":"project-backfill"}'::jsonb)
) as entitlement(key, value)
on conflict (tenant_id, project_id, environment_id, key) do update
  set value = excluded.value,
      source = excluded.source,
      updated_at = excluded.updated_at;

insert into public.project_sync_materializations (
  project_id,
  environment_id,
  artifact_kind,
  source_of_truth,
  tracked_branch,
  materialization_status,
  drift_status,
  metadata,
  updated_at
)
select
  p.id,
  e.id,
  artifact_kind.kind,
  'database',
  case e.key
    when 'dev' then 'dev'
    when 'stage' then 'stage'
    else 'main'
  end,
  'pending',
  'unknown',
  jsonb_build_object('bootstrapped', true, 'environmentKey', e.key),
  now()
from public.projects p
join public.environments e on e.project_id = p.id
cross join (
  values
    ('routing'),
    ('composition'),
    ('app_definition'),
    ('registry'),
    ('content_models'),
    ('version_pins'),
    ('package_registry')
) as artifact_kind(kind)
on conflict (project_id, environment_id, artifact_kind) do update
  set source_of_truth = excluded.source_of_truth,
      tracked_branch = excluded.tracked_branch,
      metadata = project_sync_materializations.metadata || excluded.metadata,
      updated_at = excluded.updated_at;

insert into public.project_sync_materializations (
  project_id,
  environment_id,
  artifact_kind,
  source_of_truth,
  tracked_branch,
  materialization_status,
  drift_status,
  metadata,
  updated_at
)
select
  e.project_id,
  e.id,
  artifact_kind.kind,
  'database',
  case e.key
    when 'dev' then 'dev'
    when 'stage' then 'stage'
    else 'main'
  end,
  'pending',
  'unknown',
  jsonb_build_object('bootstrapped', true, 'environmentKey', e.key),
  now()
from public.environments e
cross join (
  values
    ('routing'),
    ('composition'),
    ('app_definition'),
    ('registry'),
    ('content_models'),
    ('version_pins'),
    ('package_registry')
) as artifact_kind(kind)
on conflict (project_id, environment_id, artifact_kind) do update
  set source_of_truth = excluded.source_of_truth,
      tracked_branch = excluded.tracked_branch,
      metadata = project_sync_materializations.metadata || excluded.metadata,
      updated_at = excluded.updated_at;


-- END LEGACY: 0018_platform_config.sql

-- ============================================================================
-- BEGIN LEGACY: 0019_platform_config_effective.sql
-- ============================================================================

-- Effective configuration resolution helpers

create or replace function config_effective_for_environment(env_id uuid)
returns table (
  key text,
  value jsonb,
  source_scope text,
  is_secret boolean
)
language sql
stable
as $$
  with env as (
    select e.id as env_id, p.id as project_id, p.tenant_id
    from environments e
    join projects p on p.id = e.project_id
    where e.id = env_id
  ),
  scoped_overrides as (
    select
      o.*,
      case
        when o.environment_id is not null then 4
        when o.project_id is not null then 3
        when o.tenant_id is not null then 2
        else 1
      end as specificity
    from config_overrides o
    join env on (
      (o.environment_id = env.env_id)
      or (o.project_id = env.project_id and o.environment_id is null)
      or (o.tenant_id = env.tenant_id and o.project_id is null and o.environment_id is null)
      or (o.environment_id is null and o.project_id is null and o.tenant_id is null)
    )
  ),
  ranked as (
    select distinct on (key)
      key,
      value,
      case
        when environment_id is not null then 'environment'
        when project_id is not null then 'project'
        when tenant_id is not null then 'tenant'
        else 'system'
      end as source_scope,
      vault_secret_id is not null as is_secret
    from scoped_overrides
    order by key, specificity desc, updated_at desc
  )
  select
    d.key,
    case
      when d.value_type = 'secret' then null
      else coalesce(r.value, d.default_value)
    end as value,
    coalesce(r.source_scope, 'system') as source_scope,
    d.value_type = 'secret' as is_secret
  from config_definitions d
  left join ranked r on r.key = d.key;
$$;

create or replace function config_effective_kv(env_id uuid)
returns jsonb
language sql
stable
as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  from config_effective_for_environment(env_id);
$$;

create or replace view config_effective_public as
select
  e.id as environment_id,
  cfg.key,
  cfg.value,
  cfg.source_scope,
  cfg.is_secret
from environments e
cross join lateral config_effective_for_environment(e.id) as cfg;


-- END LEGACY: 0019_platform_config_effective.sql

-- ============================================================================
-- BEGIN LEGACY: 0020_feature_states.sql
-- ============================================================================

-- Feature state overrides (module enablement)

create table if not exists feature_state_overrides (
  id uuid primary key default gen_random_uuid(),
  feature_key text not null references feature_definitions(key) on delete cascade,
  tenant_id uuid references tenants(id) on delete cascade,
  project_id uuid references projects(id) on delete cascade,
  environment_id uuid references environments(id) on delete cascade,
  status text not null check (status in ('active', 'disabled', 'inherited', 'enforced', 'blocked')),
  updated_by uuid,
  updated_at timestamptz not null default now(),
  constraint uq_feature_state_override unique nulls not distinct (feature_key, tenant_id, project_id, environment_id)
);

create index if not exists idx_feature_state_overrides_feature on feature_state_overrides(feature_key);
create index if not exists idx_feature_state_overrides_project on feature_state_overrides(project_id);
create index if not exists idx_feature_state_overrides_environment on feature_state_overrides(environment_id);

alter table feature_state_overrides enable row level security;

create policy "Feature state overrides visible to tenant members" on feature_state_overrides
  for all using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where (
        (feature_state_overrides.project_id is not null and p.id = feature_state_overrides.project_id)
        or (feature_state_overrides.environment_id is not null and p.id = (select e.project_id from environments e where e.id = feature_state_overrides.environment_id))
        or (feature_state_overrides.tenant_id is not null and p.tenant_id = feature_state_overrides.tenant_id)
      )
      and tm.user_id = auth.uid()
    )
  );

create or replace function feature_effective_for_environment(env_id uuid)
returns table (
  feature_key text,
  status text,
  source_scope text
)
language sql
stable
as $$
  with env as (
    select e.id as env_id, p.id as project_id, p.tenant_id
    from environments e
    join projects p on p.id = e.project_id
    where e.id = env_id
  ),
  scoped_overrides as (
    select
      o.*,
      case
        when o.environment_id is not null then 4
        when o.project_id is not null then 3
        when o.tenant_id is not null then 2
        else 1
      end as specificity
    from feature_state_overrides o
    join env on (
      (o.environment_id = env.env_id)
      or (o.project_id = env.project_id and o.environment_id is null)
      or (o.tenant_id = env.tenant_id and o.project_id is null and o.environment_id is null)
      or (o.environment_id is null and o.project_id is null and o.tenant_id is null)
    )
  ),
  ranked as (
    select distinct on (feature_key)
      feature_key,
      status,
      case
        when environment_id is not null then 'environment'
        when project_id is not null then 'project'
        when tenant_id is not null then 'tenant'
        else 'system'
      end as source_scope
    from scoped_overrides
    order by feature_key, specificity desc, updated_at desc
  )
  select
    fd.key as feature_key,
    coalesce(r.status, 'disabled') as status,
    coalesce(r.source_scope, 'system') as source_scope
  from feature_definitions fd
  left join ranked r on r.feature_key = fd.key;
$$;

create or replace view feature_effective_public as
select
  e.id as environment_id,
  fe.feature_key,
  fe.status,
  fe.source_scope
from environments e
cross join lateral feature_effective_for_environment(e.id) as fe;


-- END LEGACY: 0020_feature_states.sql

-- ============================================================================
-- BEGIN LEGACY: 0025_platforms_rls.sql
-- ============================================================================

-- Enable RLS for platforms + tenant scoped associations

alter table platforms enable row level security;
alter table platform_subscriptions enable row level security;
alter table platform_links enable row level security;

-- Platforms: readable by authenticated users (registry)
create policy "Platforms readable by authenticated"
  on platforms for select
  to authenticated
  using (true);

-- Subscriptions: tenant members can read/write their own tenant rows
create policy "Platform subscriptions readable by tenant members"
  on platform_subscriptions for select
  using (
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = platform_subscriptions.tenant_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Platform subscriptions writable by tenant members"
  on platform_subscriptions for all
  using (
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = platform_subscriptions.tenant_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = platform_subscriptions.tenant_id
      and tm.user_id = auth.uid()
    )
  );

-- Links: tenant members can read/write their own tenant rows
create policy "Platform links readable by tenant members"
  on platform_links for select
  using (
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = platform_links.tenant_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Platform links writable by tenant members"
  on platform_links for all
  using (
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = platform_links.tenant_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from tenant_members tm
      where tm.tenant_id = platform_links.tenant_id
      and tm.user_id = auth.uid()
    )
  );


-- END LEGACY: 0025_platforms_rls.sql

-- ============================================================================
-- BEGIN LEGACY: 0037_auth_provider_flags.sql
-- ============================================================================

insert into feature_flags (key, name, description, category, default_value, affects_routes, dependencies)
values
  ('auth.provider.google', 'Google Login', 'Enable Google OAuth for this tenant/platform.', 'Auth', false, '[]', '[]'),
  ('auth.provider.discord', 'Discord Login', 'Enable Discord OAuth for this tenant/platform.', 'Auth', false, '[]', '[]'),
  ('auth.provider.github', 'GitHub Login', 'Enable GitHub OAuth for this tenant/platform.', 'Auth', false, '[]', '[]'),
  ('auth.provider.microsoft', 'Microsoft Login', 'Enable Microsoft OAuth for this tenant/platform.', 'Auth', false, '[]', '[]')
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  default_value = excluded.default_value,
  affects_routes = excluded.affects_routes,
  dependencies = excluded.dependencies;


-- END LEGACY: 0037_auth_provider_flags.sql

-- ============================================================================
-- BEGIN LEGACY: 0046_role_config.sql
-- ============================================================================

-- Role configuration table for database-driven roles
-- Allows tenants to customize roles with specific permissions

create table if not exists role_config (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references tenants(id) on delete cascade,
  project_id uuid references projects(id) on delete cascade,
  role_key varchar(100) not null,
  role_name varchar(255) not null,
  description text,
  permissions jsonb default '[]'::jsonb,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(tenant_id, project_id, role_key)
);

-- Index for efficient lookups
create index if not exists idx_role_config_tenant_project
  on role_config(tenant_id, project_id, role_key);

create index if not exists idx_role_config_active
  on role_config(role_key, is_active) where is_active = true;

-- Enable RLS
alter table role_config enable row level security;

-- RLS Policies
do $$
begin
  -- Policy: any tenant member can read role configs
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'role_config'
      and policyname = 'role_config_member_read'
  ) then
    create policy "role_config_member_read"
      on role_config
      for select
      to authenticated
      using (
        tenant_id is null
        or exists (
          select 1
          from tenant_members tm
          where tm.tenant_id = role_config.tenant_id
            and tm.user_id = auth.uid()
        )
      );
  end if;

  -- Policy: admins/owners can manage role configs
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'role_config'
      and policyname = 'role_config_admin_manage'
  ) then
    create policy "role_config_admin_manage"
      on role_config
      for all
      to authenticated
      using (
        exists (
          select 1
          from tenant_members tm
          where tm.tenant_id = role_config.tenant_id
            and tm.user_id = auth.uid()
            and tm.role in ('owner', 'admin')
        )
      )
      with check (
        exists (
          select 1
          from tenant_members tm
          where tm.tenant_id = role_config.tenant_id
            and tm.user_id = auth.uid()
            and tm.role in ('owner', 'admin')
        )
      );
  end if;
end $$;

-- Add updated_at trigger
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger update_role_config_updated_at
  before update on role_config
  for each row
  execute function update_updated_at_column();


-- END LEGACY: 0046_role_config.sql


-- ============================================================================
-- APPENDED LEGACY: 0024_security_lint_fixes.sql
-- ============================================================================

-- Security lint fixes: enforce security invoker for public views

drop view if exists config_effective_public;
create view config_effective_public
with (security_invoker = true)
as
select
  e.id as environment_id,
  cfg.key,
  cfg.value,
  cfg.source_scope,
  cfg.is_secret
from environments e
cross join lateral config_effective_for_environment(e.id) as cfg;

drop view if exists feature_effective_public;
create view feature_effective_public
with (security_invoker = true)
as
select
  e.id as environment_id,
  fe.feature_key,
  fe.status,
  fe.source_scope
from environments e
cross join lateral feature_effective_for_environment(e.id) as fe;


-- END APPENDED LEGACY: 0024_security_lint_fixes.sql


-- ============================================================================
-- APPENDED LEGACY: 0032_access_role_capability_model.sql
-- ============================================================================

-- Access control model for tenant-scoped role -> capability mapping.

create table if not exists public.access_capabilities_catalog (
  capability_key text primary key,
  module_key text not null,
  label text not null,
  feature_flag_key text null references public.feature_flags(key) on delete set null,
  is_system boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.access_role_capability_overrides (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  role text not null,
  capability_key text not null references public.access_capabilities_catalog(capability_key) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (tenant_id, role, capability_key)
);

alter table public.access_capabilities_catalog enable row level security;
alter table public.access_role_capability_overrides enable row level security;

-- Catalog is visible to authenticated users.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'access_capabilities_catalog'
      and policyname = 'access_capabilities_catalog_read_authenticated'
  ) then
    create policy "access_capabilities_catalog_read_authenticated"
      on public.access_capabilities_catalog
      for select
      to authenticated
      using (true);
  end if;
end $$;

-- Tenant-scoped overrides visible/editable by tenant members.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'access_role_capability_overrides'
      and policyname = 'access_role_capability_overrides_member_read'
  ) then
    create policy "access_role_capability_overrides_member_read"
      on public.access_role_capability_overrides
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.tenant_members tm
          where tm.tenant_id = access_role_capability_overrides.tenant_id
            and tm.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'access_role_capability_overrides'
      and policyname = 'access_role_capability_overrides_member_write'
  ) then
    create policy "access_role_capability_overrides_member_write"
      on public.access_role_capability_overrides
      for all
      to authenticated
      using (
        exists (
          select 1
          from public.tenant_members tm
          where tm.tenant_id = access_role_capability_overrides.tenant_id
            and tm.user_id = auth.uid()
        )
      )
      with check (
        exists (
          select 1
          from public.tenant_members tm
          where tm.tenant_id = access_role_capability_overrides.tenant_id
            and tm.user_id = auth.uid()
        )
      );
  end if;
end $$;

-- Seed baseline capabilities used by /access UI.
insert into public.access_capabilities_catalog (capability_key, module_key, label, feature_flag_key)
values
  ('content.read', 'content', 'Read Content', 'cms.content'),
  ('content.create', 'content', 'Create Entries', 'cms.content'),
  ('content.publish', 'content', 'Publish Entries', 'cms.content'),
  ('models.manage', 'models', 'Manage Content Models', 'cms.schemaBuilder'),
  ('routing.manage', 'routing', 'Manage Routing', 'cms.routing'),
  ('feature-flags.manage', 'feature_flags', 'Manage Feature Flags', null),
  ('locales.manage', 'locales', 'Manage Locales', 'cms.i18n'),
  ('platform.links.manage', 'platform', 'Manage Platform Links', 'hub.integrations'),
  ('hub.workspace.manage', 'hub', 'Access Hub Workspace', 'hub.workspace'),
  ('hub.integrations.manage', 'integrations', 'Manage Repo, Domains, and Previews', 'hub.integrations'),
  ('website.publish', 'website', 'Publish Website Runtime', 'website.public'),
  ('evidence.workspace.manage', 'evidence', 'Access Evidence Workspace', 'evidence.workspace'),
  ('evidence.analysis.run', 'evidence', 'Run Evidence Analysis', 'evidence.analysis'),
  ('sync.repo.materialize', 'sync', 'Materialize DB State To Repo', 'project.sync.materialization'),
  ('sync.repo.reconcile', 'sync', 'Observe And Reconcile Tracked Branch Commits', 'project.sync.inbound'),
  ('shop.products', 'shop', 'Manage Products', null),
  ('shop.orders', 'shop', 'View Orders', null),
  ('platform.identity.simulation', 'identity', 'Identity Simulation Tools', null)
on conflict (capability_key) do update
  set module_key = excluded.module_key,
      label = excluded.label,
      feature_flag_key = excluded.feature_flag_key;


-- END APPENDED LEGACY: 0032_access_role_capability_model.sql


-- ============================================================================
-- APPENDED LEGACY: 0033_tenant_role_catalog.sql
-- ============================================================================

-- Tenant role catalog used by /access and hub user lifecycle APIs.

create table if not exists public.tenant_role_catalog (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  role_key text not null,
  label text not null,
  description text,
  is_system boolean not null default true,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (tenant_id, role_key)
);

create index if not exists idx_tenant_role_catalog_tenant_sort
  on public.tenant_role_catalog(tenant_id, sort_order, role_key);

alter table public.tenant_role_catalog enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'tenant_role_catalog'
      and policyname = 'tenant_role_catalog_member_read'
  ) then
    create policy "tenant_role_catalog_member_read"
      on public.tenant_role_catalog
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.tenant_members tm
          where tm.tenant_id = tenant_role_catalog.tenant_id
            and tm.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'tenant_role_catalog'
      and policyname = 'tenant_role_catalog_member_write'
  ) then
    create policy "tenant_role_catalog_member_write"
      on public.tenant_role_catalog
      for all
      to authenticated
      using (
        exists (
          select 1
          from public.tenant_members tm
          where tm.tenant_id = tenant_role_catalog.tenant_id
            and tm.user_id = auth.uid()
        )
      )
      with check (
        exists (
          select 1
          from public.tenant_members tm
          where tm.tenant_id = tenant_role_catalog.tenant_id
            and tm.user_id = auth.uid()
        )
      );
  end if;
end $$;

with role_seed(role_key, label, description, sort_order) as (
  values
    ('platform_admin', 'Platform Admin', 'Global platform administration role', 5),
    ('tenant_owner', 'Tenant Admin', 'Full access to all tenant resources', 10),
    ('content_editor', 'Content Editor', 'Can create and publish content', 20),
    ('author', 'Author', 'Can create drafts but cannot publish', 30)
),
tenant_seed as (
  select t.id as tenant_id, rs.role_key, rs.label, rs.description, rs.sort_order
  from public.tenants t
  cross join role_seed rs
)
insert into public.tenant_role_catalog (
  tenant_id,
  role_key,
  label,
  description,
  is_system,
  sort_order
)
select tenant_id, role_key, label, description, true, sort_order
from tenant_seed
on conflict (tenant_id, role_key) do update
  set label = excluded.label,
      description = excluded.description,
      is_system = excluded.is_system,
      sort_order = excluded.sort_order,
      updated_at = now();

create or replace function public.bootstrap_tenant_catalogs()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.tenant_role_catalog (
    tenant_id,
    role_key,
    label,
    description,
    is_system,
    sort_order
  )
  values
    (new.id, 'platform_admin', 'Platform Admin', 'Global platform administration role', true, 5),
    (new.id, 'tenant_owner', 'Tenant Admin', 'Full access to all tenant resources', true, 10),
    (new.id, 'content_editor', 'Content Editor', 'Can create and publish content', true, 20),
    (new.id, 'author', 'Author', 'Can create drafts but cannot publish', true, 30)
  on conflict (tenant_id, role_key) do update
    set label = excluded.label,
        description = excluded.description,
        is_system = excluded.is_system,
        sort_order = excluded.sort_order,
        updated_at = now();

  insert into public.config_overrides (key, tenant_id, value)
  values ('platform.brand.name', new.id, to_jsonb(new.name))
  on conflict on constraint uq_config_override do update
    set value = excluded.value,
        updated_at = now();

  insert into public.tenant_entitlements (tenant_id, project_id, environment_id, key, value, source)
  values
    (new.id, null, null, 'platform.core.catalog', '{"enabled":true,"source":"bootstrap"}'::jsonb, 'system'),
    (new.id, null, null, 'platform.hub.access', '{"enabled":true,"source":"bootstrap"}'::jsonb, 'system'),
    (new.id, null, null, 'billing.catalog.read', '{"enabled":true,"source":"bootstrap"}'::jsonb, 'system'),
    (new.id, null, null, 'platform.repo.materialization', '{"enabled":true,"mode":"db_canonical","inbound":"tracked_branch_only"}'::jsonb, 'system')
  on conflict (tenant_id, project_id, environment_id, key) do update
    set value = excluded.value,
        source = excluded.source,
        updated_at = now();

  return new;
end;
$$;

drop trigger if exists bootstrap_tenant_catalogs on public.tenants;
create trigger bootstrap_tenant_catalogs
  after insert on public.tenants
  for each row
  execute function public.bootstrap_tenant_catalogs();

insert into public.config_overrides (key, tenant_id, value)
select 'platform.brand.name', t.id, to_jsonb(t.name)
from public.tenants t
on conflict on constraint uq_config_override do update
  set value = excluded.value,
      updated_at = now();

insert into public.tenant_entitlements (tenant_id, project_id, environment_id, key, value, source)
select t.id, null, null, e.key, e.value, 'system'
from public.tenants t
cross join (
  values
    ('platform.core.catalog', '{"enabled":true,"source":"bootstrap"}'::jsonb),
    ('platform.hub.access', '{"enabled":true,"source":"bootstrap"}'::jsonb),
    ('billing.catalog.read', '{"enabled":true,"source":"bootstrap"}'::jsonb),
    ('platform.repo.materialization', '{"enabled":true,"mode":"db_canonical","inbound":"tracked_branch_only"}'::jsonb)
) as e(key, value)
on conflict (tenant_id, project_id, environment_id, key) do update
  set value = excluded.value,
      source = excluded.source,
      updated_at = now();


-- END APPENDED LEGACY: 0033_tenant_role_catalog.sql


-- ============================================================================
-- APPENDED LEGACY: 0034_user_special_subscription_metadata.sql
-- ============================================================================

-- User-scoped "special subscription" model lives in project_user_profiles.metadata.

create or replace function public.is_valid_special_subscription(value jsonb)
returns boolean
language plpgsql
immutable
as $$
begin
  if value is null then
    return true;
  end if;

  if jsonb_typeof(value) <> 'object' then
    return false;
  end if;

  if (value ? 'code') and jsonb_typeof(value->'code') <> 'string' then
    return false;
  end if;

  if (value ? 'status') and jsonb_typeof(value->'status') <> 'string' then
    return false;
  end if;

  if (value ? 'tenant_id') and jsonb_typeof(value->'tenant_id') <> 'string' then
    return false;
  end if;

  if (value ? 'platform_ids') and jsonb_typeof(value->'platform_ids') <> 'array' then
    return false;
  end if;

  return true;
end;
$$;

alter table if exists public.project_user_profiles
  drop constraint if exists project_user_profiles_special_subscription_json_check;

alter table if exists public.project_user_profiles
  add constraint project_user_profiles_special_subscription_json_check
  check (
    public.is_valid_special_subscription(metadata->'special_subscription')
  );

do $$
begin
  -- Legacy MyTradingWiki support bootstrap removed from the canonical DreamLab
  -- reset path. Keep this block as a no-op to avoid recreating extra tenants.
  null;
end $$;


-- END APPENDED LEGACY: 0034_user_special_subscription_metadata.sql
