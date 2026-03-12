-- Rebaselined migration: 0002_registry_and_composition.sql

-- Generated from legacy migrations on 2026-03-09.


-- ============================================================================
-- BEGIN LEGACY: 0006_registry.sql
-- ============================================================================

-- 0006_registry.sql

-- =============================================================================
-- A) INTERFACES
-- =============================================================================

create table if not exists interface_definitions (
  key text primary key,
  name text not null,
  description text not null,
  category text not null,
  created_at timestamptz not null default now()
);

create table if not exists interface_methods (
  id uuid primary key default gen_random_uuid(),
  interface_key text not null references interface_definitions(key) on delete cascade,
  name text not null,
  type text not null, -- 'command' | 'query'
  description text not null,
  inputs jsonb not null default '[]'::jsonb,
  output text not null,
  created_at timestamptz not null default now()
);

create table if not exists interface_events (
  id uuid primary key default gen_random_uuid(),
  interface_key text not null references interface_definitions(key) on delete cascade,
  name text not null,
  description text not null,
  payload text not null,
  created_at timestamptz not null default now()
);

-- =============================================================================
-- B) FEATURES + ATTACHMENTS
-- =============================================================================

create table if not exists feature_definitions (
  key text primary key,
  name text not null,
  description text not null,
  category text not null,
  type text not null, -- 'boolean' | 'config' | 'multivariant'
  policy text not null, -- 'always_on' | 'optional' | 'experimental' | 'admin_only'
  visibility text not null, -- 'admin_only' | 'tenant_visible' | 'hidden'
  scope text not null, -- 'system' | 'app'
  implements jsonb not null default '[]'::jsonb,
  consumes jsonb not null default '[]'::jsonb,
  config_schema jsonb null,
  icon_key text null,
  created_at timestamptz not null default now()
);

create table if not exists feature_attachments (
  id uuid primary key default gen_random_uuid(),
  feature_key text not null references feature_definitions(key) on delete cascade,
  language text not null, -- 'kotlin' | 'python' | 'typescript' | 'sql' | 'yaml' | 'json'
  entrypoint text not null,
  content text null,
  packages jsonb not null default '[]'::jsonb,
  scope text not null, -- 'system' | 'app'
  hooks jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- =============================================================================
-- C) APPS + COMPOSITION
-- =============================================================================

create table if not exists app_definitions (
  id text primary key,
  name text not null,
  description text not null,
  icon_key text null,
  color text not null,
  created_at timestamptz not null default now()
);

create table if not exists composition_nodes (
  app_id text not null references app_definitions(id) on delete cascade,
  node_id text not null,
  parent_node_id text null,
  name text not null,
  type text not null, -- 'route' | 'feature' | 'layout'
  feature_key text null references feature_definitions(key) on delete set null,
  position int not null default 0,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (app_id, node_id),
  foreign key (app_id, parent_node_id) references composition_nodes(app_id, node_id) on delete cascade
);

-- =============================================================================
-- INDEXES & RLS
-- =============================================================================

create index if not exists idx_iface_methods_key on interface_methods(interface_key);
create index if not exists idx_iface_events_key on interface_events(interface_key);
create index if not exists idx_feat_attachments_key on feature_attachments(feature_key);
create index if not exists idx_comp_nodes_parent on composition_nodes(app_id, parent_node_id);

alter table interface_definitions enable row level security;
alter table interface_methods enable row level security;
alter table interface_events enable row level security;
alter table feature_definitions enable row level security;
alter table feature_attachments enable row level security;
alter table app_definitions enable row level security;
alter table composition_nodes enable row level security;

-- Read-only policy for authenticated users
create policy "Registry visible to authenticated" on interface_definitions for select to authenticated using (true);
create policy "Registry visible to authenticated" on interface_methods for select to authenticated using (true);
create policy "Registry visible to authenticated" on interface_events for select to authenticated using (true);
create policy "Registry visible to authenticated" on feature_definitions for select to authenticated using (true);
create policy "Registry visible to authenticated" on feature_attachments for select to authenticated using (true);
create policy "Registry visible to authenticated" on app_definitions for select to authenticated using (true);
create policy "Registry visible to authenticated" on composition_nodes for select to authenticated using (true);

-- =============================================================================
-- SEED DATA
-- =============================================================================

-- 1. Interfaces
insert into interface_definitions (key, name, description, category) values
('auth.provider', 'Authentication Provider', 'Contract for identity verification and session management.', 'Security'),
('storage.blob', 'Blob Storage', 'Abstract file storage operations for media and documents.', 'Infrastructure'),
('ai.generation', 'AI Generation', 'Generative AI capabilities for text and suggestions.', 'AI'),
('telemetry.ingest', 'Telemetry Ingest', 'High-frequency data ingestion contract.', 'Data'),
('commerce.payment', 'Payment Processor', 'Payment gateway abstraction.', 'Commerce')
on conflict (key) do nothing;

insert into interface_methods (interface_key, name, type, description, inputs, output) values
('auth.provider', 'authenticate', 'command', 'Exchange credentials for token', '[{"name": "payload", "type": "AuthRequest", "required": true}]', 'AuthToken'),
('auth.provider', 'verify', 'query', 'Validate session token', '[{"name": "token", "type": "string", "required": true}]', 'Session'),
('storage.blob', 'upload', 'command', 'Upload file stream', '[{"name": "file", "type": "Stream", "required": true}]', 'FileUrl'),
('ai.generation', 'complete', 'command', 'Text completion', '[{"name": "prompt", "type": "string", "required": true}]', 'CompletionResult'),
('telemetry.ingest', 'ingestBatch', 'command', 'Ingest sensor data', '[{"name": "batch", "type": "DataPoint[]", "required": true}]', 'void');

insert into interface_events (interface_key, name, description, payload) values
('auth.provider', 'auth.login.success', 'User successfully logged in', 'UserSession'),
('telemetry.ingest', 'telemetry.alert', 'Threshold breached', 'AlertPayload');

-- 2. Features
insert into feature_definitions (key, name, description, category, type, policy, visibility, scope, implements, consumes, config_schema, icon_key) values
('core.auth', 'Identity Core', 'Base authentication system.', 'Core', 'boolean', 'always_on', 'tenant_visible', 'system', '[]', '[]', null, 'Shield'),
('core.storage', 'File System', 'Local and S3 compatible storage.', 'Core', 'config', 'always_on', 'hidden', 'system', '[]', '[]', null, 'Archive'),
('core.networking', 'API Gateway', 'REST and GraphQL endpoints.', 'Core', 'boolean', 'always_on', 'hidden', 'system', '[]', '[]', null, 'Globe'),
('trademind.journal', 'Trade Journal', 'Core trading journal with PnL tracking.', 'TradeMind', 'config', 'always_on', 'tenant_visible', 'app', '[]', '[]', '{"type": "object", "properties": {"allowShorts": {"type": "boolean"}}}', 'Database'),
('trademind.import', 'Broker Import', 'Import trades from CSV/API.', 'TradeMind', 'boolean', 'optional', 'tenant_visible', 'app', '[]', '["storage.blob"]', null, 'Share2'),
('trademind.analytics', 'PnL Analytics', 'Advanced charting for performance.', 'TradeMind', 'boolean', 'optional', 'tenant_visible', 'app', '[]', '[]', null, 'BarChart'),
('sim.telemetry', 'Telemetry Analysis', 'Real-time telemetry ingestion and visualization.', 'MotorHome', 'config', 'always_on', 'tenant_visible', 'app', '["telemetry.ingest"]', '[]', null, 'Activity'),
('sim.strategy', 'Race Strategy', 'Pit stop and fuel strategy calculator.', 'MotorHome', 'boolean', 'optional', 'tenant_visible', 'app', '[]', '[]', null, 'Zap'),
('sim.setup', 'Setup Sync', 'Share car setups with teammates.', 'MotorHome', 'boolean', 'optional', 'tenant_visible', 'app', '[]', '[]', null, 'Settings'),
('career.jobfeed', 'Job Aggregator', 'Connects to LinkedIn/Indeed APIs.', 'CareerPilot', 'config', 'always_on', 'tenant_visible', 'app', '[]', '[]', null, 'Briefcase'),
('career.cv', 'CV Builder', 'AI-assisted resume generator.', 'CareerPilot', 'boolean', 'always_on', 'tenant_visible', 'app', '[]', '[]', null, 'FileText'),
('venue.reservations', 'Table Reservations', 'Booking system with floor plan management.', 'Venue', 'multivariant', 'always_on', 'tenant_visible', 'app', '[]', '[]', null, 'Calendar'),
('venue.loyalty', 'Loyalty Program', 'Points and rewards system.', 'Venue', 'boolean', 'optional', 'tenant_visible', 'app', '[]', '[]', null, 'Star'),
('puzzle.transcription', 'Audio Transcription', 'Convert voice notes to puzzle clues.', 'StoryPuzzle', 'boolean', 'experimental', 'tenant_visible', 'app', '[]', '["ai.generation"]', null, 'Mic'),
('puzzle.solver', 'AI Hint System', 'Context-aware puzzle hints.', 'StoryPuzzle', 'boolean', 'optional', 'tenant_visible', 'app', '[]', '[]', null, 'Lightbulb'),
('mail.smartattach', 'Smart Attachments', 'AI analysis of email attachments.', 'MailPilot', 'boolean', 'optional', 'tenant_visible', 'app', '[]', '["ai.generation", "storage.blob"]', null, 'Paperclip'),
('mail.todos', 'Todo Sync', 'Extract tasks from email content.', 'MailPilot', 'boolean', 'always_on', 'tenant_visible', 'app', '[]', '[]', null, 'CheckSquare')
on conflict (key) do nothing;

insert into feature_attachments (feature_key, language, entrypoint, packages, scope, hooks, content) values
('core.auth', 'kotlin', 'src/main/kotlin/auth/AuthModule.kt', '["jwt"]', 'system', '{"generate": true}', $$package com.make.core

import com.make.api.*

class DefaultImplementation : Interface {
    override fun execute(ctx: Context): Result {
        return Result.Success
    }
}$$),
('core.networking', 'yaml', 'infra/k8s/gateway.yaml', '[]', 'system', '{"postGenerate": true}', 'apiVersion: v1\nkind: Service\nmetadata:\n  name: gateway'),
('trademind.journal', 'kotlin', 'src/main/kotlin/com/trademind/JournalModule.kt', '["exposed-sql"]', 'app', '{"generate": true}', 'fun createEntry(trade: Trade) { ... }'),
('trademind.journal', 'sql', 'src/main/resources/db/migration/V1__journal.sql', '[]', 'app', '{"preGenerate": true}', 'CREATE TABLE trades (id UUID PRIMARY KEY, ...);'),
('sim.telemetry', 'python', 'pipelines/telemetry_processor.py', '["pandas", "numpy"]', 'app', '{"postGenerate": true}', $$def process_lap(data):
    df = pd.DataFrame(data)
    return df.mean()$$);


-- 3. Apps & Composition
insert into app_definitions (id, name, description, icon_key, color) values
('app_trademind', 'TradeMind', 'Trading journal and analytics platform.', 'Database', '#0ea5e9'),
('app_motorhome', 'MotorHome Sim-Garage', 'Sim racing telemetry and setup manager.', 'Cpu', '#ef4444'),
('app_career', 'CareerPilot', 'Job application tracking and CV optimization.', 'Globe', '#10b981'),
('app_venue', 'Venue Manager', 'Hospitality management suite.', 'Smartphone', '#8b5cf6'),
('app_puzzle', 'Story Puzzle Solver', 'Companion app for mystery games.', 'FileText', '#f59e0b'),
('app_mail', 'MailPilot', 'Intelligent email client extension.', 'Layers', '#6366f1')
on conflict (id) do nothing;

insert into composition_nodes (app_id, node_id, parent_node_id, name, type, feature_key, position) values
-- TradeMind
('app_trademind', 'root', null, 'Root Layout', 'layout', null, 0),
('app_trademind', 'auth', 'root', 'Authentication', 'feature', 'core.auth', 0),
('app_trademind', 'dash', 'root', 'Dashboard', 'route', null, 1),
('app_trademind', 'journal', 'dash', 'Journal', 'feature', 'trademind.journal', 0),
('app_trademind', 'import', 'dash', 'Import Wizard', 'feature', 'trademind.import', 1),
('app_trademind', 'analytics', 'dash', 'Performance', 'feature', 'trademind.analytics', 2),

-- MotorHome
('app_motorhome', 'root', null, 'App Shell', 'layout', null, 0),
('app_motorhome', 'telemetry', 'root', 'Live Telemetry', 'feature', 'sim.telemetry', 0),
('app_motorhome', 'strategy', 'root', 'Strategy Pit', 'feature', 'sim.strategy', 1),
('app_motorhome', 'setups', 'root', 'Setup Manager', 'feature', 'sim.setup', 2),

-- CareerPilot
('app_career', 'root', null, 'Main', 'layout', null, 0),
('app_career', 'feed', 'root', 'Job Feed', 'feature', 'career.jobfeed', 0),
('app_career', 'cv', 'root', 'CV Editor', 'feature', 'career.cv', 1),

-- Venue
('app_venue', 'root', null, 'Admin Panel', 'layout', null, 0),
('app_venue', 'res', 'root', 'Reservations', 'feature', 'venue.reservations', 0),
('app_venue', 'loyalty', 'root', 'Loyalty', 'feature', 'venue.loyalty', 1),

-- Puzzle
('app_puzzle', 'root', null, 'Solver UI', 'layout', null, 0),
('app_puzzle', 'transcribe', 'root', 'Voice Clues', 'feature', 'puzzle.transcription', 0),
('app_puzzle', 'hints', 'root', 'AI Hints', 'feature', 'puzzle.solver', 1),

-- Mail
('app_mail', 'root', null, 'Extension Overlay', 'layout', null, 0),
('app_mail', 'att', 'root', 'Smart Attach', 'feature', 'mail.smartattach', 0),
('app_mail', 'tasks', 'root', 'Task Extraction', 'feature', 'mail.todos', 1)
on conflict (app_id, node_id) do nothing;


-- END LEGACY: 0006_registry.sql

-- ============================================================================
-- BEGIN LEGACY: 0007_registry_composition_refs.sql
-- ============================================================================

-- 1. Add columns
ALTER TABLE composition_nodes 
ADD COLUMN ref_kind text NOT NULL DEFAULT 'feature' CHECK (ref_kind IN ('feature', 'interface', 'implementation', 'none')),
ADD COLUMN ref_key text;

-- 2. Backfill data
-- If feature_key was present, map it to feature ref
UPDATE composition_nodes
SET ref_kind = 'feature', ref_key = feature_key
WHERE feature_key IS NOT NULL;

-- If it was a container node (layout/route) without feature, it's 'none'
UPDATE composition_nodes
SET ref_kind = 'none', ref_key = NULL
WHERE feature_key IS NULL AND type IN ('layout', 'route');

-- 3. Remove constraints and old column
ALTER TABLE composition_nodes DROP CONSTRAINT IF EXISTS composition_nodes_feature_key_fkey;
ALTER TABLE composition_nodes DROP COLUMN IF EXISTS feature_key;

insert into feature_definitions (key, name, description, category, type, policy, visibility, scope, implements, consumes, config_schema, icon_key) values
(
  'platform.hub.workspace',
  'Platform Hub Workspace',
  'Administrative workspace for models, routes, locales, feature flags, and project composition.',
  'DreamLab',
  'config',
  'always_on',
  'tenant_visible',
  'app',
  '[]'::jsonb,
  '[]'::jsonb,
  '{"type":"object","properties":{"defaultSection":{"type":"string","default":"overview"}}}'::jsonb,
  'LayoutDashboard'
),
(
  'website.public.site',
  'DreamLab Public Website',
  'Public marketing and publishing experience for DreamLab Solutions.',
  'DreamLab',
  'config',
  'always_on',
  'tenant_visible',
  'app',
  '[]'::jsonb,
  '[]'::jsonb,
  '{"type":"object","properties":{"defaultLocale":{"type":"string","default":"en"}}}'::jsonb,
  'Globe'
)
on conflict (key) do update
set
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

insert into app_definitions (id, name, description, icon_key, color) values
('app_platform_hub', 'DreamLab Platform Hub', 'Configuration console for DreamLab projects, routes, locales, and content.', 'LayoutDashboard', '#0f766e'),
('app_dreamlab_website', 'DreamLab Website', 'Public DreamLab Solutions marketing website and publishing surface.', 'Globe', '#1d4ed8')
on conflict (id) do update
set
  name = excluded.name,
  description = excluded.description,
  icon_key = excluded.icon_key,
  color = excluded.color;

insert into composition_nodes (app_id, node_id, parent_node_id, name, type, ref_kind, ref_key, position, config) values
('app_platform_hub', 'root', null, 'Hub Shell', 'layout', 'none', null, 0, '{"layout":"dashboard"}'::jsonb),
('app_platform_hub', 'dashboard', 'root', 'Dashboard', 'route', 'none', null, 0, '{"path":"/dashboard"}'::jsonb),
('app_platform_hub', 'workspace', 'dashboard', 'Platform Workspace', 'feature', 'feature', 'platform.hub.workspace', 0, '{}'::jsonb),
('app_platform_hub', 'content', 'root', 'Content', 'route', 'none', null, 1, '{"path":"/content"}'::jsonb),
('app_platform_hub', 'routing', 'root', 'Routing', 'route', 'none', null, 2, '{"path":"/routing"}'::jsonb),
('app_platform_hub', 'access', 'root', 'Access', 'route', 'none', null, 3, '{"path":"/access"}'::jsonb),
('app_dreamlab_website', 'root', null, 'Website Shell', 'layout', 'none', null, 0, '{"layout":"website"}'::jsonb),
('app_dreamlab_website', 'home', 'root', 'Homepage', 'route', 'none', null, 0, '{"path":"/"}'::jsonb),
('app_dreamlab_website', 'public-site', 'home', 'Public Site Runtime', 'feature', 'feature', 'website.public.site', 0, '{}'::jsonb),
('app_dreamlab_website', 'about', 'root', 'About', 'route', 'none', null, 1, '{"path":"/about"}'::jsonb),
('app_dreamlab_website', 'contact', 'root', 'Contact', 'route', 'none', null, 2, '{"path":"/contact"}'::jsonb)
on conflict (app_id, node_id) do update
set
  parent_node_id = excluded.parent_node_id,
  name = excluded.name,
  type = excluded.type,
  ref_kind = excluded.ref_kind,
  ref_key = excluded.ref_key,
  position = excluded.position,
  config = excluded.config;


-- END LEGACY: 0007_registry_composition_refs.sql

-- ============================================================================
-- BEGIN LEGACY: 0010_integrations.sql
-- ============================================================================

create table if not exists project_repos (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade not null,
  provider text not null check (provider in ('github', 'gitlab', 'bitbucket', 'azure')),
  owner text not null,
  repo text not null,
  default_branch text default 'main',
  status text default 'connected' check (status in ('connected', 'disconnected', 'error')),
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(project_id) -- Assumption: one repo per project for now
);

create table if not exists project_previews (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade not null,
  environment_id uuid references environments(id) on delete cascade,
  kind text not null check (kind in ('figma_make', 'vercel', 'netlify', 'external')),
  url text not null,
  is_primary boolean default false,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists project_domains (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade not null,
  environment_id uuid references environments(id) on delete cascade,
  domain text not null,
  status text default 'pending' check (status in ('pending', 'verified', 'active', 'error')),
  provider text default 'manual' check (provider in ('vercel', 'cloudflare', 'manual')),
  verification jsonb default '{}'::jsonb, -- DNS records needed
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(project_id, domain)
);

create table if not exists integration_sync_jobs (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade not null,
  environment_id uuid references environments(id) on delete cascade,
  kind text not null,
  status text default 'queued' check (status in ('queued', 'in_progress', 'completed', 'failed')),
  detail jsonb default '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz default now()
);

create table if not exists project_repo_reconciliations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade not null,
  environment_id uuid references environments(id) on delete cascade not null,
  artifact_kind text not null check (artifact_kind in ('routing', 'composition', 'app_definition')),
  tracked_branch text not null,
  canonical_source text not null default 'database' check (canonical_source in ('database', 'repository')),
  inbound_sync_policy text not null default 'tracked_branch_only' check (inbound_sync_policy in ('tracked_branch_only', 'disabled')),
  last_materialized_commit_sha text,
  last_observed_commit_sha text,
  last_db_change_ref text,
  last_repo_change_ref text,
  last_materialized_by text,
  last_observed_source text not null default 'none' check (last_observed_source in ('none', 'database', 'repository', 'webhook')),
  drift_status text not null default 'pending' check (drift_status in ('pending', 'in_sync', 'drifted', 'materializing', 'error')),
  drift_detail jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  last_materialized_at timestamptz,
  last_observed_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(project_id, environment_id, artifact_kind)
);

-- RLS

alter table project_repos enable row level security;
alter table project_previews enable row level security;
alter table project_domains enable row level security;
alter table integration_sync_jobs enable row level security;
alter table project_repo_reconciliations enable row level security;

-- Policies (Project Members via Tenant Members)

create policy "Project members manage repos" on project_repos
  for all using (
    exists (
      select 1 from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = project_repos.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Project members manage previews" on project_previews
  for all using (
    exists (
      select 1 from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = project_previews.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Project members manage domains" on project_domains
  for all using (
    exists (
      select 1 from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = project_domains.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Project members manage sync jobs" on integration_sync_jobs
  for all using (
    exists (
      select 1 from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = integration_sync_jobs.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Project members manage reconciliations" on project_repo_reconciliations
  for all using (
    exists (
      select 1 from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = project_repo_reconciliations.project_id
      and tm.user_id = auth.uid()
    )
  );


-- END LEGACY: 0010_integrations.sql

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
-- REGISTRY GOVERNANCE EXTENSIONS
-- ============================================================================

alter table interface_definitions
  add column if not exists owner_kind text not null default 'system'
    check (owner_kind in ('system', 'platform', 'app', 'package')),
  add column if not exists owner_key text,
  add column if not exists version text not null default '1.0.0',
  add column if not exists schema_checksum text,
  add column if not exists source_commit_sha text,
  add column if not exists extends_interface_key text references interface_definitions(key) on delete set null,
  add column if not exists compatibility jsonb not null default '{}'::jsonb;

alter table app_definitions
  add column if not exists project_id uuid references projects(id) on delete set null,
  add column if not exists project_slug text,
  add column if not exists workspace_path text,
  add column if not exists version text not null default '0.0.1',
  add column if not exists schema_checksum text,
  add column if not exists source_commit_sha text,
  add column if not exists metadata jsonb not null default '{}'::jsonb;

alter table composition_nodes
  add column if not exists version text not null default '1.0.0',
  add column if not exists schema_checksum text,
  add column if not exists source_commit_sha text;

alter table project_repos
  add column if not exists materialization_metadata jsonb not null default '{}'::jsonb;

alter table project_repo_reconciliations
  drop constraint if exists project_repo_reconciliations_artifact_kind_check;

alter table project_repo_reconciliations
  add constraint project_repo_reconciliations_artifact_kind_check
  check (
    artifact_kind in (
      'routing',
      'composition',
      'app_definition',
      'registry',
      'content_models',
      'version_pins',
      'package_registry'
    )
  );

alter table platforms
  add column if not exists version text not null default '1.0.0',
  add column if not exists schema_checksum text,
  add column if not exists source_commit_sha text,
  add column if not exists metadata jsonb not null default '{}'::jsonb;

create table if not exists package_definitions (
  key text primary key,
  package_name text not null,
  workspace_path text not null,
  category text not null,
  kind text,
  description text,
  repository text,
  version text not null,
  schema_checksum text,
  source_commit_sha text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table package_definitions
  alter column category set default 'core';

create table if not exists package_dependency_edges (
  from_package_key text not null references package_definitions(key) on delete cascade,
  to_package_key text not null references package_definitions(key) on delete cascade,
  dependency_kind text not null default 'runtime'
    check (dependency_kind in ('runtime', 'peer', 'dev', 'optional')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (from_package_key, to_package_key, dependency_kind)
);

create table if not exists project_app_bindings (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  environment_id uuid references environments(id) on delete cascade,
  app_id text not null references app_definitions(id) on delete cascade,
  status text not null default 'active'
    check (status in ('active', 'inactive', 'deprecated')),
  pinned_version text not null default '0.0.1',
  source_commit_sha text,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique (project_id, app_id)
);

create table if not exists project_package_bindings (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  package_key text not null references package_definitions(key) on delete cascade,
  role text not null default 'dependency'
    check (role in ('dependency', 'ui', 'domain', 'integration', 'theme', 'engine')),
  pinned_version text not null,
  source_commit_sha text,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique (project_id, package_key, role)
);

alter table project_package_bindings
  add column if not exists relationship text,
  alter column pinned_version set default 'workspace:*',
  alter column role set default 'dependency';

create unique index if not exists uq_project_package_bindings_project_package
  on project_package_bindings(project_id, package_key);

create table if not exists app_package_bindings (
  app_id text not null references app_definitions(id) on delete cascade,
  package_key text not null references package_definitions(key) on delete cascade,
  role text not null check (role in ('renderer', 'ui', 'bff', 'core', 'theme', 'service')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (app_id, package_key, role)
);

create index if not exists idx_package_definitions_category
  on package_definitions(category);
create index if not exists idx_project_app_bindings_project
  on project_app_bindings(project_id);
create index if not exists idx_project_app_bindings_environment
  on project_app_bindings(environment_id);
create index if not exists idx_project_package_bindings_project
  on project_package_bindings(project_id);

alter table package_definitions enable row level security;
alter table package_dependency_edges enable row level security;
alter table project_app_bindings enable row level security;
alter table project_package_bindings enable row level security;
alter table app_package_bindings enable row level security;

create policy "Registry packages visible to authenticated"
  on package_definitions for select to authenticated using (true);

create policy "Registry package edges visible to authenticated"
  on package_dependency_edges for select to authenticated using (true);

create policy "Project members manage app bindings" on project_app_bindings
  for all using (
    exists (
      select 1 from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = project_app_bindings.project_id
        and tm.user_id = auth.uid()
    )
  );

create policy "Project members manage package bindings" on project_package_bindings
  for all using (
    exists (
      select 1 from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = project_package_bindings.project_id
        and tm.user_id = auth.uid()
    )
  );

create policy "App package bindings visible to authenticated"
  on app_package_bindings for select to authenticated using (true);

insert into package_definitions (
  key,
  package_name,
  workspace_path,
  category,
  description,
  version,
  schema_checksum,
  source_commit_sha,
  metadata
)
values
  (
    'pkg.dls-api-core',
    '@dreamlab-solutions/dls-api-core',
    'packages/dls-api-core',
    'core',
    'Shared contracts, adapters, and use cases.',
    '0.1.0',
    md5('packages/dls-api-core@0.1.0'),
    null,
    '{"kind":"library"}'::jsonb
  ),
  (
    'pkg.dls-domain',
    '@dreamlab-solutions/dls-domain',
    'packages/dls-domain',
    'domain',
    'Cross-app domain schemas and primitives.',
    '0.1.0',
    md5('packages/dls-domain@0.1.0'),
    null,
    '{"kind":"library"}'::jsonb
  ),
  (
    'pkg.dls-evidence-bff',
    '@dreamlab-solutions/dls-evidence-bff',
    'packages/dls-evidence-bff',
    'bff',
    'Evidence use cases and adapters for server-side consumers.',
    '0.1.0',
    md5('packages/dls-evidence-bff@0.1.0'),
    null,
    '{"kind":"bff"}'::jsonb
  ),
  (
    'pkg.dls-evidence-ui-react',
    '@dreamlab-solutions/dls-evidence-ui-react',
    'packages/dls-evidence-ui-react',
    'ui',
    'Evidence-specific React presentation components.',
    '0.1.0',
    md5('packages/dls-evidence-ui-react@0.1.0'),
    null,
    '{"kind":"ui"}'::jsonb
  ),
  (
    'pkg.dls-google-mail',
    '@dreamlab-solutions/dls-google-mail',
    'packages/dls-google-mail',
    'integration',
    'Google Mail integration helpers.',
    '0.1.0',
    md5('packages/dls-google-mail@0.1.0'),
    null,
    '{"kind":"integration"}'::jsonb
  ),
  (
    'pkg.dls-storage',
    '@dreamlab-solutions/dls-storage',
    'packages/dls-storage',
    'storage',
    'Storage abstractions and helpers.',
    '0.1.0',
    md5('packages/dls-storage@0.1.0'),
    null,
    '{"kind":"library"}'::jsonb
  ),
  (
    'pkg.dls-theme',
    '@dreamlab-solutions/dls-theme',
    'packages/dls-theme',
    'theme',
    'Shared design tokens and theme primitives.',
    '0.0.1',
    md5('packages/dls-theme@0.0.1'),
    null,
    '{"kind":"theme"}'::jsonb
  ),
  (
    'pkg.dls-ui-astro',
    '@dreamlab-solutions/dls-ui-astro',
    'packages/dls-ui-astro',
    'ui',
    'Shared Astro UI layer.',
    '0.0.1',
    md5('packages/dls-ui-astro@0.0.1'),
    null,
    '{"kind":"ui"}'::jsonb
  ),
  (
    'pkg.dls-ui-react',
    '@dreamlab-solutions/dls-ui-react',
    'packages/dls-ui-react',
    'ui',
    'Shared React UI primitives and components.',
    '0.2.3',
    md5('packages/dls-ui-react@0.2.3'),
    null,
    '{"kind":"ui"}'::jsonb
  ),
  (
    'pkg.dls-ui-vue',
    '@dreamlab-solutions/dls-ui-vue',
    'packages/dls-ui-vue',
    'ui',
    'Shared Vue UI layer.',
    '0.0.1',
    md5('packages/dls-ui-vue@0.0.1'),
    null,
    '{"kind":"ui"}'::jsonb
  ),
  (
    'pkg.dls-webpage-engine-core',
    '@dreamlab-solutions/dls-webpage-engine-core',
    'packages/dls-webpage-engine-core',
    'engine',
    'Shared webpage composition and rendering engine.',
    '0.1.3',
    md5('packages/dls-webpage-engine-core@0.1.3'),
    null,
    '{"kind":"engine"}'::jsonb
  )
on conflict (key) do update
  set package_name = excluded.package_name,
      workspace_path = excluded.workspace_path,
      category = excluded.category,
      description = excluded.description,
      version = excluded.version,
      schema_checksum = excluded.schema_checksum,
      source_commit_sha = excluded.source_commit_sha,
      metadata = excluded.metadata,
      updated_at = now();

insert into package_dependency_edges (from_package_key, to_package_key, dependency_kind)
values
  ('pkg.dls-api-core', 'pkg.dls-domain', 'runtime'),
  ('pkg.dls-evidence-bff', 'pkg.dls-api-core', 'runtime'),
  ('pkg.dls-evidence-ui-react', 'pkg.dls-evidence-bff', 'runtime'),
  ('pkg.dls-evidence-ui-react', 'pkg.dls-ui-react', 'runtime'),
  ('pkg.dls-storage', 'pkg.dls-domain', 'runtime'),
  ('pkg.dls-ui-astro', 'pkg.dls-domain', 'runtime'),
  ('pkg.dls-ui-react', 'pkg.dls-api-core', 'runtime'),
  ('pkg.dls-ui-react', 'pkg.dls-domain', 'runtime'),
  ('pkg.dls-ui-react', 'pkg.dls-theme', 'runtime'),
  ('pkg.dls-ui-react', 'pkg.dls-webpage-engine-core', 'runtime'),
  ('pkg.dls-ui-vue', 'pkg.dls-domain', 'runtime'),
  ('pkg.dls-webpage-engine-core', 'pkg.dls-domain', 'runtime')
on conflict (from_package_key, to_package_key, dependency_kind) do nothing;

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
values
  (
    'app_platform_hub',
    'DreamLab Platform Hub',
    'Administrative console for routing, composition, registry, and content governance.',
    'LayoutDashboard',
    '#2563eb',
    'dls-platform-hub-next',
    'apps/dls-platform-hub-next',
    '0.0.1',
    md5('app_platform_hub:apps/dls-platform-hub-next'),
    null,
    '{"platformSlug":"dreamlab-solutions","materializationScope":["routing","composition","app_definition","registry","content_models","version_pins","package_registry"]}'::jsonb
  ),
  (
    'app_dreamlab_website',
    'DreamLab Website',
    'Public-facing website and content delivery app.',
    'Globe',
    '#0f766e',
    'dls-website-astro',
    'apps/dls-webapp-astro',
    '0.0.2',
    md5('app_dreamlab_website:apps/dls-webapp-astro'),
    null,
    '{"platformSlug":"dreamlab-solutions","materializationScope":["routing","composition","app_definition","registry","content_models","version_pins","package_registry"]}'::jsonb
  )
on conflict (id) do update
  set name = excluded.name,
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
  config,
  version,
  schema_checksum,
  source_commit_sha
)
values
  ('app_platform_hub', 'root', null, 'Hub Shell', 'layout', 'none', null, 0, '{"layout":"dashboard"}'::jsonb, '1.0.0', md5('app_platform_hub:root'), null),
  ('app_platform_hub', 'dashboard', 'root', 'Dashboard', 'route', 'none', null, 0, '{"path":"/dashboard"}'::jsonb, '1.0.0', md5('app_platform_hub:dashboard'), null),
  ('app_platform_hub', 'content', 'dashboard', 'Content', 'route', 'none', null, 0, '{"path":"/dashboard/content"}'::jsonb, '1.0.0', md5('app_platform_hub:content'), null),
  ('app_platform_hub', 'models', 'dashboard', 'Models', 'route', 'none', null, 1, '{"path":"/dashboard/models"}'::jsonb, '1.0.0', md5('app_platform_hub:models'), null),
  ('app_platform_hub', 'routing', 'dashboard', 'Routing', 'route', 'none', null, 2, '{"path":"/dashboard/routing"}'::jsonb, '1.0.0', md5('app_platform_hub:routing'), null),
  ('app_platform_hub', 'access', 'dashboard', 'Access', 'route', 'none', null, 3, '{"path":"/dashboard/access"}'::jsonb, '1.0.0', md5('app_platform_hub:access'), null),
  ('app_platform_hub', 'settings', 'dashboard', 'Settings', 'route', 'none', null, 4, '{"path":"/dashboard/settings"}'::jsonb, '1.0.0', md5('app_platform_hub:settings'), null),
  ('app_dreamlab_website', 'root', null, 'Website Shell', 'layout', 'none', null, 0, '{"layout":"site"}'::jsonb, '1.0.0', md5('app_dreamlab_website:root'), null),
  ('app_dreamlab_website', 'home', 'root', 'Home', 'route', 'none', null, 0, '{"path":"/"}'::jsonb, '1.0.0', md5('app_dreamlab_website:home'), null),
  ('app_dreamlab_website', 'about', 'root', 'About', 'route', 'none', null, 1, '{"path":"/about"}'::jsonb, '1.0.0', md5('app_dreamlab_website:about'), null),
  ('app_dreamlab_website', 'services', 'root', 'Services', 'route', 'none', null, 2, '{"path":"/services"}'::jsonb, '1.0.0', md5('app_dreamlab_website:services'), null),
  ('app_dreamlab_website', 'contact', 'root', 'Contact', 'route', 'none', null, 3, '{"path":"/contact"}'::jsonb, '1.0.0', md5('app_dreamlab_website:contact'), null)
on conflict (app_id, node_id) do update
  set parent_node_id = excluded.parent_node_id,
      name = excluded.name,
      type = excluded.type,
      ref_kind = excluded.ref_kind,
      ref_key = excluded.ref_key,
      position = excluded.position,
      config = excluded.config,
      version = excluded.version,
      schema_checksum = excluded.schema_checksum,
      source_commit_sha = excluded.source_commit_sha;
