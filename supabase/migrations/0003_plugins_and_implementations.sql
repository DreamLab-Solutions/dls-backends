-- Rebaselined migration: 0003_plugins_and_implementations.sql

-- Generated from legacy migrations on 2026-03-09.


-- ============================================================================
-- BEGIN LEGACY: 0002_plugins.sql
-- ============================================================================

-- Table: plugin_definitions
create table if not exists plugin_definitions (
  key text primary key,
  name text not null,
  category text not null,
  type text not null, -- feature/provider/pricing/infra/config
  description text,
  dependencies jsonb not null default '[]'::jsonb,
  consumes_interfaces jsonb not null default '[]'::jsonb,
  provides_interfaces jsonb not null default '[]'::jsonb,
  schema jsonb null,
  version text null,
  created_at timestamptz not null default now()
);

-- Table: project_plugins
create table if not exists project_plugins (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  environment_id uuid null references environments(id) on delete cascade,
  plugin_key text not null references plugin_definitions(key) on delete restrict,
  status text not null, -- active/disabled/blocked/unbound/inherited/enforced
  bound_provider_key text null,
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique(project_id, environment_id, plugin_key)
);

-- Table: plugin_sync_jobs
create table if not exists plugin_sync_jobs (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  environment_id uuid null references environments(id) on delete cascade,
  status text not null, -- queued/running/succeeded/failed
  requested_by uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  started_at timestamptz null,
  finished_at timestamptz null
);

-- Table: plugin_sync_job_steps
create table if not exists plugin_sync_job_steps (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references plugin_sync_jobs(id) on delete cascade,
  step_key text not null,
  status text not null,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Indexes
create index if not exists idx_project_plugins_project_id on project_plugins(project_id);
create index if not exists idx_project_plugins_environment_id on project_plugins(environment_id);
create index if not exists idx_project_plugins_plugin_key on project_plugins(plugin_key);

create index if not exists idx_plugin_sync_jobs_project_id on plugin_sync_jobs(project_id);
create index if not exists idx_plugin_sync_jobs_environment_id on plugin_sync_jobs(environment_id);

create index if not exists idx_plugin_sync_job_steps_job_id on plugin_sync_job_steps(job_id);

-- Enable RLS
alter table plugin_definitions enable row level security;
alter table project_plugins enable row level security;
alter table plugin_sync_jobs enable row level security;
alter table plugin_sync_job_steps enable row level security;

-- Policies

-- Plugin Definitions: visible to any tenant member
create policy "Plugins visible to members" 
on plugin_definitions for select 
using (
  exists (
    select 1 from tenant_members 
    where tenant_members.user_id = auth.uid()
  )
);

-- Project Plugins: access controlled by project ownership via tenant
create policy "Project plugins access for members" 
on project_plugins for all
using (
  exists (
    select 1 from projects 
    join tenant_members on projects.tenant_id = tenant_members.tenant_id 
    where projects.id = project_plugins.project_id 
    and tenant_members.user_id = auth.uid()
  )
);

-- Plugin Sync Jobs: access controlled by project ownership via tenant
create policy "Sync jobs access for members" 
on plugin_sync_jobs for all
using (
  exists (
    select 1 from projects 
    join tenant_members on projects.tenant_id = tenant_members.tenant_id 
    where projects.id = plugin_sync_jobs.project_id 
    and tenant_members.user_id = auth.uid()
  )
);

-- Plugin Sync Job Steps: access controlled by job -> project ownership
create policy "Sync steps access for members" 
on plugin_sync_job_steps for all
using (
  exists (
    select 1 from plugin_sync_jobs
    join projects on plugin_sync_jobs.project_id = projects.id
    join tenant_members on projects.tenant_id = tenant_members.tenant_id 
    where plugin_sync_jobs.id = plugin_sync_job_steps.job_id 
    and tenant_members.user_id = auth.uid()
  )
);

-- Seed Data (from src/lib/plugins/catalog.ts)
insert into plugin_definitions (key, name, category, type, description, dependencies, consumes_interfaces, provides_interfaces)
values
  ('core.auth', 'Authentication Core', 'Core', 'feature', 'User identity, sessions, and access control.', '[]'::jsonb, '["IAuthProvider"]'::jsonb, '["IIdentityService"]'::jsonb),
  ('core.cms', 'Headless CMS', 'Core', 'feature', 'Schema-driven content storage and API generation.', '["media.storage"]'::jsonb, '[]'::jsonb, '["IContentService"]'::jsonb),
  ('media.storage', 'Media Library', 'Core', 'infra', 'File upload, transformation, and serving.', '[]'::jsonb, '["IStorageProvider"]'::jsonb, '["IMediaService"]'::jsonb),
  ('i18n.runtime', 'Translation Runtime', 'Core', 'infra', 'Localized routing and content serving.', '[]'::jsonb, '[]'::jsonb, '["II18nService"]'::jsonb),
  ('commerce.catalog', 'Product Catalog', 'Commerce', 'feature', 'Manage products, variants, and categories.', '["media.storage"]'::jsonb, '["IPricingResolver"]'::jsonb, '["IProductCatalog"]'::jsonb),
  ('commerce.inventory', 'Stock Management', 'Commerce', 'feature', 'Track stock across locations.', '["commerce.catalog"]'::jsonb, '[]'::jsonb, '["IInventoryService"]'::jsonb),
  ('commerce.expiration', 'Batch & Expiration', 'Commerce', 'feature', 'Track lots, batch numbers, and expiration dates (FEFO).', '["commerce.inventory"]'::jsonb, '[]'::jsonb, '["IBatchTracker"]'::jsonb),
  ('commerce.orders', 'Order Management', 'Commerce', 'feature', 'Order lifecycle, checkout, and transaction history.', '["commerce.catalog"]'::jsonb, '["IPaymentProvider"]'::jsonb, '["IOrderService"]'::jsonb),
  ('commerce.events', 'Event Commerce', 'Commerce', 'feature', 'Event-specific storefronts and on-site POS inventory.', '["commerce.orders", "commerce.inventory"]'::jsonb, '["IInventoryAllocator"]'::jsonb, '["IEventService"]'::jsonb),
  ('commerce.shipping', 'Fulfillment', 'Commerce', 'feature', 'Shipping zones, carriers, and tracking.', '["commerce.orders"]'::jsonb, '["IShippingProvider"]'::jsonb, '["IFulfillmentService"]'::jsonb),
  ('tradelog.core', 'Trade Journal', 'Finance', 'feature', 'Record trades, tags, notes, and screenshots.', '["core.auth", "media.storage"]'::jsonb, '[]'::jsonb, '["ITradeService"]'::jsonb),
  ('tradelog.analytics.basic', 'Trade Analytics', 'Finance', 'feature', 'Profit/Loss graphs, win rates, and balance tracking.', '["tradelog.core"]'::jsonb, '[]'::jsonb, '["ITradeAnalytics"]'::jsonb),
  ('career.profile', 'Candidate Profile', 'HR', 'feature', 'Structured resume data, skills, and experience.', '["core.auth"]'::jsonb, '[]'::jsonb, '["ICandidateProfile"]'::jsonb),
  ('career.cv.builder', 'CV Builder', 'HR', 'feature', 'Generate PDF resumes from profile data.', '["career.profile"]'::jsonb, '[]'::jsonb, '[]'::jsonb),
  ('career.application.board', 'Application Tracker', 'HR', 'feature', 'Kanban board for job applications.', '["career.profile"]'::jsonb, '["IJobFeedProvider"]'::jsonb, '[]'::jsonb),
  ('mail.ingestion', 'Email Ingestion', 'Productivity', 'feature', 'IMAP/SMTP processing, attachment parsing.', '["media.storage"]'::jsonb, '[]'::jsonb, '["IMailService"]'::jsonb),
  ('mail.routing.rules', 'Routing Rules', 'Productivity', 'config', 'Rule engine for sorting and tagging emails.', '["mail.ingestion"]'::jsonb, '[]'::jsonb, '[]'::jsonb),
  ('venue.reservations', 'Table Reservations', 'Hospitality', 'feature', 'Booking engine, seating charts, and time slots.', '[]'::jsonb, '[]'::jsonb, '["IReservationService"]'::jsonb),
  ('venue.loyalty', 'Guest Loyalty', 'Hospitality', 'feature', 'Points, tiers, and rewards for returning guests.', '["venue.reservations"]'::jsonb, '[]'::jsonb, '[]'::jsonb),
  ('story.library', 'Case Library', 'Entertainment', 'feature', 'Collection of mysteries and clues.', '["media.storage"]'::jsonb, '[]'::jsonb, '["ICaseDatabase"]'::jsonb),
  ('story.capture.upload', 'Clue Capture', 'Entertainment', 'feature', 'Mobile-first upload for photos of physical clues.', '["story.library"]'::jsonb, '[]'::jsonb, '[]'::jsonb),
  ('story.export.book', 'Book Generator', 'Entertainment', 'feature', 'Compiles solved cases into a PDF storybook.', '["story.library"]'::jsonb, '[]'::jsonb, '[]'::jsonb),
  ('provider.stripe', 'Stripe Payments', 'Providers', 'provider', 'Payment processing via Stripe API.', '[]'::jsonb, '[]'::jsonb, '["IPaymentProvider"]'::jsonb),
  ('pricing.basic', 'Standard Pricing', 'Pricing', 'pricing', 'Simple base price + tax + discount logic.', '[]'::jsonb, '[]'::jsonb, '["IPricingResolver"]'::jsonb),
  ('analytics.core', 'Core Analytics', 'Infrastructure', 'infra', 'Sales reports and KPI tracking.', '[]'::jsonb, '[]'::jsonb, '["IAnalyticsService"]'::jsonb)
on conflict (key) do update set
  name = excluded.name,
  category = excluded.category,
  type = excluded.type,
  description = excluded.description,
  dependencies = excluded.dependencies,
  consumes_interfaces = excluded.consumes_interfaces,
  provides_interfaces = excluded.provides_interfaces;


-- END LEGACY: 0002_plugins.sql

-- ============================================================================
-- BEGIN LEGACY: 0008_implementations.sql
-- ============================================================================

create table if not exists implementation_definitions (
  key text primary key,
  name text not null,
  interface_key text not null references interface_definitions(key) on delete cascade,
  provider_type text not null, 
  description text,
  config_schema jsonb default '{}'::jsonb,
  icon_key text,
  created_at timestamptz default now()
);

create table if not exists project_implementations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade not null,
  environment_id uuid references environments(id) on delete cascade,
  implementation_key text references implementation_definitions(key) on delete cascade not null,
  status text default 'active' check (status in ('active', 'inactive', 'deprecated')),
  config jsonb default '{}'::jsonb,
  updated_at timestamptz default now(),
  unique(project_id, environment_id, implementation_key)
);

alter table implementation_definitions enable row level security;
alter table project_implementations enable row level security;

-- Policies
create policy "Public definitions read" on implementation_definitions for select using (true);

create policy "Project members read implementations" on project_implementations
  for select using (
    exists (
      select 1
      from projects
      join tenant_members on projects.tenant_id = tenant_members.tenant_id
      where projects.id = project_implementations.project_id
        and tenant_members.user_id = auth.uid()
    )
  );

create policy "Project members write implementations" on project_implementations
  for all using (
    exists (
      select 1
      from projects
      join tenant_members on projects.tenant_id = tenant_members.tenant_id
      where projects.id = project_implementations.project_id
        and tenant_members.user_id = auth.uid()
    )
  );

-- Seed Keycloak
insert into implementation_definitions (key, name, interface_key, provider_type, description, config_schema)
values (
  'auth.keycloak',
  'Keycloak Auth Provider',
  'auth.provider', 
  'open_source',
  'Standard Keycloak OIDC integration',
  '{"type": "object", "properties": {"realmUrl": {"type": "string"}, "clientId": {"type": "string"}, "issuer": {"type": "string"}, "jwksUrl": {"type": "string"}, "audience": {"type": "string"}}}'
)
on conflict (key) do nothing;


-- END LEGACY: 0008_implementations.sql
-- BEGIN LEGACY: 0044_evidence_registry.sql
-- ============================================================================

-- Evidence Management registry and composition bootstrap

-- Plugin registry entries
insert into plugin_definitions (
  key,
  name,
  category,
  type,
  description,
  dependencies,
  consumes_interfaces,
  provides_interfaces,
  version,
  schema
)
values
  (
    'ai.generation',
    'AI Generation Engine',
    'Infrastructure',
    'infra',
    'Shared AI text generation and analysis capability for app plugins.',
    '[]'::jsonb,
    '["IAIProvider"]'::jsonb,
    '["IAIService"]'::jsonb,
    '1.0.0',
    '{}'::jsonb
  ),
  (
    'evidence.workspace',
    'Evidence Management Workspace',
    'Legal',
    'feature',
    'Timeline-first evidence analysis workspace with ingestion and AI-assisted inconsistency checks.',
    '["core.auth", "mail.ingestion", "ai.generation"]'::jsonb,
    '["IMailService", "IAIService"]'::jsonb,
    '["IEvidenceWorkspaceService"]'::jsonb,
    '1.0.0',
    '{"providesModels":[{"uid":"evidence.timeline","name":"Evidence Timeline","description":"Timeline aggregate for evidence review.","model":{"entity":"evidence_timeline","version":"1"}}]}'::jsonb
  )
on conflict (key) do update set
  name = excluded.name,
  category = excluded.category,
  type = excluded.type,
  description = excluded.description,
  dependencies = excluded.dependencies,
  consumes_interfaces = excluded.consumes_interfaces,
  provides_interfaces = excluded.provides_interfaces,
  version = excluded.version,
  schema = excluded.schema;

-- Feature registry entries used by app composition
insert into feature_definitions (
  key,
  name,
  description,
  category,
  type,
  policy,
  visibility,
  scope,
  implements,
  consumes,
  config_schema,
  icon_key
)
values
  (
    'sync.repo.materialization',
    'Repository Materialization',
    'Database-authored materialization of routing and composition artifacts into tracked repository branches.',
    'Sync',
    'config',
    'always_on',
    'admin_only',
    'system',
    '[]'::jsonb,
    '["core.networking"]'::jsonb,
    '{"type":"object","properties":{"artifactKinds":{"type":"array","items":{"type":"string"}}}}'::jsonb,
    'GitBranch'
  ),
  (
    'sync.repo.webhook-reconcile',
    'Webhook Reconciliation',
    'Automatic observation and reconciliation of tracked branch commits back into DB state.',
    'Sync',
    'boolean',
    'optional',
    'admin_only',
    'system',
    '[]'::jsonb,
    '["core.networking"]'::jsonb,
    null,
    'Webhook'
  ),
  (
    'evidence.timeline.workspace',
    'Evidence Timeline Workspace',
    'Core timeline workspace for evidence events, excerpts, and legal context tagging.',
    'Evidence',
    'config',
    'always_on',
    'tenant_visible',
    'app',
    '[]'::jsonb,
    '["storage.blob"]'::jsonb,
    '{"type":"object","properties":{"defaultView":{"type":"string","enum":["timeline","board"],"default":"timeline"}}}'::jsonb,
    'FileSearch'
  ),
  (
    'evidence.inconsistency.analysis',
    'Inconsistency Analysis',
    'AI-assisted analysis for contradictions and timeline inconsistency candidates.',
    'Evidence',
    'boolean',
    'optional',
    'tenant_visible',
    'app',
    '[]'::jsonb,
    '["ai.generation"]'::jsonb,
    null,
    'Brain'
  )
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  type = excluded.type,
  policy = excluded.policy,
  visibility = excluded.visibility,
  scope = excluded.scope,
  implements = excluded.implements,
  consumes = excluded.consumes,
  config_schema = excluded.config_schema,
  icon_key = excluded.icon_key;

create table if not exists project_sync_materializations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  environment_id uuid not null references environments(id) on delete cascade,
  artifact_kind text not null check (
    artifact_kind in (
      'routing',
      'composition',
      'app_definition',
      'registry',
      'content_models',
      'version_pins',
      'package_registry'
    )
  ),
  source_of_truth text not null default 'database' check (source_of_truth in ('database', 'repository')),
  tracked_branch text not null,
  file_path text,
  last_materialized_commit_sha text,
  last_observed_commit_sha text,
  last_db_authored_commit_sha text,
  last_materialized_tree_hash text,
  last_observed_tree_hash text,
  materialization_status text not null default 'pending' check (materialization_status in ('pending', 'materialized', 'observed', 'error', 'disabled')),
  drift_status text not null default 'unknown' check (drift_status in ('unknown', 'in_sync', 'db_ahead', 'repo_ahead', 'conflict')),
  metadata jsonb not null default '{}'::jsonb,
  last_materialized_at timestamptz,
  last_observed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (project_id, environment_id, artifact_kind)
);

create index if not exists idx_project_sync_materializations_project
  on project_sync_materializations(project_id);
create index if not exists idx_project_sync_materializations_environment
  on project_sync_materializations(environment_id);
create index if not exists idx_project_sync_materializations_branch
  on project_sync_materializations(tracked_branch);

alter table project_sync_materializations enable row level security;

create policy "Project members read sync materializations" on project_sync_materializations
  for select using (
    exists (
      select 1
      from projects
      join tenant_members on projects.tenant_id = tenant_members.tenant_id
      where projects.id = project_sync_materializations.project_id
        and tenant_members.user_id = auth.uid()
    )
  );

create policy "Project members write sync materializations" on project_sync_materializations
  for all using (
    exists (
      select 1
      from projects
      join tenant_members on projects.tenant_id = tenant_members.tenant_id
      where projects.id = project_sync_materializations.project_id
        and tenant_members.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects
      join tenant_members on projects.tenant_id = tenant_members.tenant_id
      where projects.id = project_sync_materializations.project_id
        and tenant_members.user_id = auth.uid()
    )
  );

-- App + composition records (ref_kind/ref_key model)
insert into app_definitions (
  id,
  name,
  description,
  icon_key,
  color,
  project_slug,
  workspace_path,
  version,
  schema_checksum,
  source_commit_sha,
  metadata
)
values (
  'app_evidence',
  'Evidence Management',
  'Timeline and analysis workspace for legal evidence review.',
  'Scale',
  '#f97316',
  'evidence-mgmt-next',
  'apps/evidence-mgmt-next',
  '0.0.1',
  md5('app_evidence:apps/evidence-mgmt-next'),
  null,
  '{"platformSlug":"evidence-management","materializationScope":["routing","composition","app_definition","registry","content_models","version_pins","package_registry"]}'::jsonb
)
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  icon_key = excluded.icon_key,
  color = excluded.color,
  project_slug = excluded.project_slug,
  workspace_path = excluded.workspace_path,
  version = excluded.version,
  schema_checksum = excluded.schema_checksum,
  source_commit_sha = excluded.source_commit_sha,
  metadata = excluded.metadata;

insert into composition_nodes (
  app_id,
  node_id,
  parent_node_id,
  name,
  type,
  ref_kind,
  ref_key,
  position,
  config
)
values
  (
    'app_evidence',
    'root',
    null,
    'Evidence Shell',
    'layout',
    'none',
    null,
    0,
    '{"layout":"workspace"}'::jsonb
  ),
  (
    'app_evidence',
    'workspace',
    'root',
    'Evidence Workspace',
    'route',
    'none',
    null,
    0,
    '{"path":"/evidence"}'::jsonb
  ),
  (
    'app_evidence',
    'timeline',
    'workspace',
    'Timeline',
    'route',
    'none',
    null,
    0,
    '{"path":"/evidence/timeline"}'::jsonb
  ),
  (
    'app_evidence',
    'timeline-workspace',
    'timeline',
    'Timeline Workspace',
    'feature',
    'feature',
    'evidence.timeline.workspace',
    0,
    '{}'::jsonb
  ),
  (
    'app_evidence',
    'analysis',
    'workspace',
    'Inconsistency Analysis',
    'route',
    'none',
    null,
    1,
    '{"path":"/evidence/analysis"}'::jsonb
  ),
  (
    'app_evidence',
    'analysis-feature',
    'analysis',
    'AI Inconsistency Detection',
    'feature',
    'feature',
    'evidence.inconsistency.analysis',
    0,
    '{}'::jsonb
  )
on conflict (app_id, node_id) do update set
  parent_node_id = excluded.parent_node_id,
  name = excluded.name,
  type = excluded.type,
  ref_kind = excluded.ref_kind,
  ref_key = excluded.ref_key,
  position = excluded.position,
  config = excluded.config;


-- END LEGACY: 0044_evidence_registry.sql
