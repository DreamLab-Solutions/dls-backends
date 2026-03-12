-- Rebaselined migration: 0004_content_and_editor.sql

-- Generated from legacy migrations on 2026-03-09.


-- ============================================================================
-- BEGIN LEGACY: 0004_content.sql
-- ============================================================================

-- Table: content_models
create table if not exists content_models (
  project_id uuid not null references projects(id) on delete cascade,
  uid text not null, -- e.g. 'api::article.article'
  name text not null,
  kind text not null, -- collection/single
  has_draft_and_publish bool not null default true,
  has_i18n bool not null default false,
  fields jsonb not null default '[]'::jsonb, -- Array of DataField
  created_at timestamptz not null default now(),
  primary key (project_id, uid)
);

-- Table: content_entries
create table if not exists content_entries (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  model_uid text not null,
  status text not null default 'draft', -- published/draft/changed
  title text not null,
  author text not null, -- stored as text for now to match mock
  data jsonb not null default '{}'::jsonb, -- Stores the 'locales' object
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (project_id, model_uid) references content_models(project_id, uid) on delete cascade
);

-- Indexes
create index if not exists idx_content_entries_project_model on content_entries(project_id, model_uid);
create index if not exists idx_content_entries_updated_at on content_entries(updated_at desc);

-- Enable RLS
alter table content_models enable row level security;
alter table content_entries enable row level security;

-- Policies

-- Content Models: visible to tenant members
create policy "Models visible to members" 
on content_models for all
using (
  exists (
    select 1 from projects 
    join tenant_members on projects.tenant_id = tenant_members.tenant_id 
    where projects.id = content_models.project_id 
    and tenant_members.user_id = auth.uid()
  )
);

-- Content Entries: visible to tenant members
create policy "Entries visible to members" 
on content_entries for all
using (
  exists (
    select 1 from projects 
    join tenant_members on projects.tenant_id = tenant_members.tenant_id 
    where projects.id = content_entries.project_id 
    and tenant_members.user_id = auth.uid()
  )
);

-- Seed Data (One-time)
do $$
declare
  v_project_id uuid;
  v_exists boolean;
begin
  -- Find the demo project
  select id into v_project_id from projects where slug = 'trademind-demo';
  
  if v_project_id is not null then
    -- Check if models already exist
    select exists(select 1 from content_models where project_id = v_project_id) into v_exists;
    
    if not v_exists then
        -- Insert Models
        
        -- Article
        insert into content_models (project_id, uid, name, kind, has_draft_and_publish, has_i18n, fields)
        values (v_project_id, 'api::article.article', 'Article', 'collection', true, true, 
          '[
            {"key": "title", "label": "Title", "type": "text", "required": true, "translatable": true},
            {"key": "content", "label": "Content", "type": "richtext", "translatable": true},
            {"key": "cover", "label": "Cover Image", "type": "media", "required": false},
            {"key": "category", "label": "Category", "type": "relation", "required": true}
          ]'::jsonb
        );

        -- Product
        insert into content_models (project_id, uid, name, kind, has_draft_and_publish, has_i18n, fields)
        values (v_project_id, 'api::product.product', 'Product', 'collection', true, true, 
          '[
            {"key": "name", "label": "Name", "type": "text", "required": true, "translatable": true},
            {"key": "price", "label": "Price", "type": "number", "required": true},
            {"key": "description", "label": "Description", "type": "richtext", "translatable": true}
          ]'::jsonb
        );

        -- Navigation
        insert into content_models (project_id, uid, name, kind, has_draft_and_publish, has_i18n, fields)
        values (v_project_id, 'api::global.navigation', 'Main Navigation', 'single', false, true, '[]'::jsonb);

        -- Insert Entries

        -- Article 1
        insert into content_entries (project_id, model_uid, status, title, author, updated_at, data)
        values (v_project_id, 'api::article.article', 'published', 'The Future of CMS', 'John Doe', '2023-10-24T10:00:00Z', 
          '{"en": {}, "it": {}}'::jsonb
        );

        -- Article 2
        insert into content_entries (project_id, model_uid, status, title, author, updated_at, data)
        values (v_project_id, 'api::article.article', 'draft', 'Why Feature Flags Matter', 'Jane Smith', '2023-10-25T14:30:00Z', 
          '{"en": {}}'::jsonb
        );

        -- Product 1
        insert into content_entries (project_id, model_uid, status, title, author, updated_at, data)
        values (v_project_id, 'api::product.product', 'published', 'Super Widget 3000', 'Admin', '2023-10-20T09:15:00Z', 
          '{"en": {}, "es": {}, "it": {}}'::jsonb
        );
        
    end if;
  end if;
end $$;


-- END LEGACY: 0004_content.sql

-- ============================================================================
-- BEGIN LEGACY: 0014_core_content_types.sql
-- ============================================================================

-- Core Content Types Migration
-- Defines standard models available to all projects (seeded per project)

-- Globals (Single)
insert into content_models (project_id, uid, name, kind, has_draft_and_publish, has_i18n, fields)
select p.id, 'globals', 'Global Settings', 'single', true, true,
  '[
     {"key":"site_name","label":"Site Name","type":"text","required":true},
     {"key":"favicon","label":"Favicon","type":"media"}
   ]'::jsonb
from projects p
on conflict (project_id, uid) do nothing;

-- Navigation (Collection)
insert into content_models (project_id, uid, name, kind, has_draft_and_publish, has_i18n, fields)
select p.id, 'navigation', 'Navigation Menus', 'collection', true, true,
  '[
     {"key":"title","label":"Menu Title","type":"text","required":true},
     {"key":"items","label":"Items","type":"component"}
   ]'::jsonb
from projects p
on conflict (project_id, uid) do nothing;

-- Hero (Collection - Component-like)
insert into content_models (project_id, uid, name, kind, has_draft_and_publish, has_i18n, fields)
select p.id, 'hero', 'Hero Sections', 'collection', true, true,
  '[
     {"key":"title","label":"Title","type":"text","required":true},
     {"key":"subtitle","label":"Subtitle","type":"text"},
     {"key":"cta_label","label":"CTA Label","type":"text"},
     {"key":"cta_url","label":"CTA URL","type":"text"},
     {"key":"background_image","label":"Background Image","type":"media"}
   ]'::jsonb
from projects p
on conflict (project_id, uid) do nothing;

-- Feature Section (Collection)
insert into content_models (project_id, uid, name, kind, has_draft_and_publish, has_i18n, fields)
select p.id, 'feature_section', 'Feature Sections', 'collection', true, true,
  '[
     {"key":"title","label":"Title","type":"text","required":true},
     {"key":"features","label":"Features","type":"component"}
   ]'::jsonb
from projects p
on conflict (project_id, uid) do nothing;

-- Cards (Collection)
insert into content_models (project_id, uid, name, kind, has_draft_and_publish, has_i18n, fields)
select p.id, 'cards', 'Cards', 'collection', true, true,
  '[
     {"key":"title","label":"Title","type":"text","required":true},
     {"key":"description","label":"Description","type":"richtext"},
     {"key":"icon","label":"Icon","type":"media"},
     {"key":"link","label":"Link","type":"text"}
   ]'::jsonb
from projects p
on conflict (project_id, uid) do nothing;

-- Forms (Collection)
insert into content_models (project_id, uid, name, kind, has_draft_and_publish, has_i18n, fields)
select p.id, 'forms', 'Forms', 'collection', true, true,
  '[
     {"key":"title","label":"Form Title","type":"text","required":true},
     {"key":"submit_label","label":"Submit Button Label","type":"text"},
     {"key":"fields","label":"Form Fields","type":"component"}
   ]'::jsonb
from projects p
on conflict (project_id, uid) do nothing;

-- Tags (Collection)
insert into content_models (project_id, uid, name, kind, has_draft_and_publish, has_i18n, fields)
select p.id, 'tags', 'Tags', 'collection', true, false,
  '[
     {"key":"name","label":"Name","type":"text","required":true},
     {"key":"slug","label":"Slug","type":"text","required":true}
   ]'::jsonb
from projects p
on conflict (project_id, uid) do nothing;

-- SEO (Single - Component usage mostly, but defined as model for reference)
insert into content_models (project_id, uid, name, kind, has_draft_and_publish, has_i18n, fields)
select p.id, 'seo', 'SEO Defaults', 'single', true, true,
  '[
     {"key":"meta_title","label":"Meta Title","type":"text"},
     {"key":"meta_description","label":"Meta Description","type":"text"},
     {"key":"og_image","label":"OG Image","type":"media"}
   ]'::jsonb
from projects p
on conflict (project_id, uid) do nothing;

-- Footer (Single)
insert into content_models (project_id, uid, name, kind, has_draft_and_publish, has_i18n, fields)
select p.id, 'footer', 'Footer', 'single', true, true,
  '[
     {"key":"copyright","label":"Copyright Text","type":"text"},
     {"key":"links","label":"Footer Links","type":"relation"}
   ]'::jsonb
from projects p
on conflict (project_id, uid) do nothing;


-- END LEGACY: 0014_core_content_types.sql

-- ============================================================================
-- BEGIN LEGACY: 0015_editor.sql
-- ============================================================================

create table if not exists editor_collections (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade not null,
  name text not null,
  status text not null check (status in ('synced', 'dirty', 'conflicts', 'external_generated')),
  source_type text not null check (source_type in ('central', 'external_generated', 'figma_imported')),
  tags text[] default '{}',
  mode_ids text[] default '{}',
  root_node_id text,
  adapter_ids text[] default '{}',
  binding_ids text[] default '{}',
  snapshot_ids jsonb default '{}'::jsonb,
  latest_snapshot_id uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists editor_snapshots (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid references editor_collections(id) on delete cascade not null,
  source text not null check (source in ('figma', 'central', 'external')),
  version integer not null default 1,
  payload jsonb not null,
  created_at timestamptz default now()
);

create table if not exists editor_conflict_resolutions (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid references editor_collections(id) on delete cascade not null,
  snapshot_id uuid references editor_snapshots(id) on delete cascade,
  resolution_payload jsonb not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists editor_adapters (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade not null,
  name text not null,
  input_schema jsonb default '{}'::jsonb,
  mapping jsonb default '{}'::jsonb,
  outputs_preview jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists editor_bindings (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade not null,
  figma_file_id text not null,
  mapping jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists editor_history (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid references editor_collections(id) on delete cascade not null,
  action text not null,
  diff jsonb default '{}'::jsonb,
  snapshot_payload jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

create index if not exists idx_editor_collections_project_id on editor_collections(project_id);
create index if not exists idx_editor_snapshots_collection_id on editor_snapshots(collection_id);
create index if not exists idx_editor_snapshots_source on editor_snapshots(source);
create index if not exists idx_editor_adapters_project_id on editor_adapters(project_id);
create index if not exists idx_editor_bindings_project_id on editor_bindings(project_id);
create index if not exists idx_editor_history_collection_id on editor_history(collection_id);

alter table editor_collections enable row level security;
alter table editor_snapshots enable row level security;
alter table editor_conflict_resolutions enable row level security;
alter table editor_adapters enable row level security;
alter table editor_bindings enable row level security;
alter table editor_history enable row level security;

create policy "Project members manage editor collections" on editor_collections
  for all using (
    exists (
      select 1 from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = editor_collections.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Project members manage editor snapshots" on editor_snapshots
  for all using (
    exists (
      select 1 from editor_collections c
      join projects p on p.id = c.project_id
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where c.id = editor_snapshots.collection_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Project members manage editor conflict resolutions" on editor_conflict_resolutions
  for all using (
    exists (
      select 1 from editor_collections c
      join projects p on p.id = c.project_id
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where c.id = editor_conflict_resolutions.collection_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Project members manage editor adapters" on editor_adapters
  for all using (
    exists (
      select 1 from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = editor_adapters.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Project members manage editor bindings" on editor_bindings
  for all using (
    exists (
      select 1 from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = editor_bindings.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Project members manage editor history" on editor_history
  for all using (
    exists (
      select 1 from editor_collections c
      join projects p on p.id = c.project_id
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where c.id = editor_history.collection_id
      and tm.user_id = auth.uid()
    )
  );


-- END LEGACY: 0015_editor.sql

-- ============================================================================
-- BEGIN LEGACY: 0016_editor_alignment.sql
-- ============================================================================

-- Editor alignment: presets + enriched adapter/binding metadata

-- Presets table (project/persona/route scoped)
create table if not exists editor_presets (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references projects(id) on delete cascade,
  persona text not null,
  route_context text,
  name text not null,
  description text,
  allowed_blocks text[] not null default '{}',
  allowed_marks text[] not null default '{}',
  max_length integer,
  paste_policy text not null default 'sanitize_links' check (paste_policy in ('allow_rich', 'plain_text_only', 'sanitize_links')),
  output_format text not null default 'html' check (output_format in ('html', 'markdown', 'delta')),
  toolbar_config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_editor_presets_project_id on editor_presets(project_id);
create index if not exists idx_editor_presets_persona on editor_presets(persona);
create index if not exists idx_editor_presets_route_context on editor_presets(route_context);

alter table editor_presets enable row level security;

create policy "Project members manage editor presets" on editor_presets
  for all using (
    exists (
      select 1 from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = editor_presets.project_id
      and tm.user_id = auth.uid()
    )
  );

-- Align status constraint with domain (source_type handles external-generated)
alter table editor_collections
  drop constraint if exists editor_collections_status_check;

alter table editor_collections
  add constraint editor_collections_status_check
  check (status in ('synced', 'dirty', 'conflicts'));

-- Align bindings with domain shape
alter table editor_bindings
  add column if not exists collection_id uuid references editor_collections(id) on delete cascade,
  add column if not exists figma_file_name text,
  add column if not exists figma_variable_collection_id text,
  add column if not exists mode_bindings jsonb not null default '{}'::jsonb,
  add column if not exists variable_bindings jsonb not null default '{}'::jsonb;

create index if not exists idx_editor_bindings_collection_id on editor_bindings(collection_id);

-- Align adapters with domain shape
alter table editor_adapters
  add column if not exists provider text,
  add column if not exists input_mock_id text,
  add column if not exists root_selector jsonb not null default '{}'::jsonb,
  add column if not exists mappings jsonb not null default '[]'::jsonb,
  add column if not exists output_mock_id text,
  add column if not exists outputs jsonb not null default '[]'::jsonb;

-- Align snapshots with label support
alter table editor_snapshots
  add column if not exists label text;

create index if not exists idx_editor_snapshots_label on editor_snapshots(label);


-- END LEGACY: 0016_editor_alignment.sql

-- ============================================================================
-- BEGIN LEGACY: 0038_docs_access_config.sql
-- ============================================================================

-- Documentation access configuration + audit trail.

create table if not exists public.documentation_access_configs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  project_id uuid null references public.projects(id) on delete cascade,
  doc_path text not null,
  visibility text not null check (visibility in ('public', 'authenticated', 'tenant', 'role_based')),
  allow_indexing boolean not null default false,
  require_login boolean not null default false,
  required_roles text[] not null default '{}',
  policy jsonb not null default '{}'::jsonb,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_documentation_access_scope unique nulls not distinct (tenant_id, project_id, doc_path)
);

create table if not exists public.documentation_access_audit_events (
  id uuid primary key default gen_random_uuid(),
  config_id uuid references public.documentation_access_configs(id) on delete set null,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  action text not null check (action in ('created', 'updated', 'deleted')),
  actor_id uuid,
  before_state jsonb not null default '{}'::jsonb,
  after_state jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_docs_access_configs_tenant
  on public.documentation_access_configs(tenant_id);

create index if not exists idx_docs_access_configs_project
  on public.documentation_access_configs(project_id);

create index if not exists idx_docs_access_configs_path
  on public.documentation_access_configs(doc_path);

create index if not exists idx_docs_access_audit_tenant_created
  on public.documentation_access_audit_events(tenant_id, created_at desc);

create index if not exists idx_docs_access_audit_config
  on public.documentation_access_audit_events(config_id);

alter table public.documentation_access_configs enable row level security;
alter table public.documentation_access_audit_events enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'documentation_access_configs'
      and policyname = 'documentation_access_configs_member_read'
  ) then
    create policy "documentation_access_configs_member_read"
      on public.documentation_access_configs
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.tenant_members tm
          where tm.tenant_id = documentation_access_configs.tenant_id
            and tm.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'documentation_access_configs'
      and policyname = 'documentation_access_configs_admin_write'
  ) then
    create policy "documentation_access_configs_admin_write"
      on public.documentation_access_configs
      for all
      to authenticated
      using (
        exists (
          select 1
          from public.tenant_members tm
          where tm.tenant_id = documentation_access_configs.tenant_id
            and tm.user_id = auth.uid()
            and tm.role in ('platform_owner', 'platform_admin', 'tenant_owner')
        )
      )
      with check (
        exists (
          select 1
          from public.tenant_members tm
          where tm.tenant_id = documentation_access_configs.tenant_id
            and tm.user_id = auth.uid()
            and tm.role in ('platform_owner', 'platform_admin', 'tenant_owner')
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'documentation_access_audit_events'
      and policyname = 'documentation_access_audit_events_member_read'
  ) then
    create policy "documentation_access_audit_events_member_read"
      on public.documentation_access_audit_events
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.tenant_members tm
          where tm.tenant_id = documentation_access_audit_events.tenant_id
            and tm.user_id = auth.uid()
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'documentation_access_configs'
      and policyname = 'supabase_auth_admin_read_documentation_access_configs'
  ) then
    create policy "supabase_auth_admin_read_documentation_access_configs"
      on public.documentation_access_configs
      for select
      to supabase_auth_admin
      using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'documentation_access_audit_events'
      and policyname = 'supabase_auth_admin_read_documentation_access_audit_events'
  ) then
    create policy "supabase_auth_admin_read_documentation_access_audit_events"
      on public.documentation_access_audit_events
      for select
      to supabase_auth_admin
      using (true);
  end if;
end $$;

create or replace function public.audit_documentation_access_config_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid;
begin
  v_actor := auth.uid();

  if tg_op = 'INSERT' then
    insert into public.documentation_access_audit_events (
      config_id,
      tenant_id,
      action,
      actor_id,
      after_state
    ) values (
      new.id,
      new.tenant_id,
      'created',
      v_actor,
      to_jsonb(new)
    );
    return new;
  end if;

  if tg_op = 'UPDATE' then
    insert into public.documentation_access_audit_events (
      config_id,
      tenant_id,
      action,
      actor_id,
      before_state,
      after_state
    ) values (
      new.id,
      new.tenant_id,
      'updated',
      v_actor,
      to_jsonb(old),
      to_jsonb(new)
    );
    return new;
  end if;

  if tg_op = 'DELETE' then
    insert into public.documentation_access_audit_events (
      config_id,
      tenant_id,
      action,
      actor_id,
      before_state
    ) values (
      old.id,
      old.tenant_id,
      'deleted',
      v_actor,
      to_jsonb(old)
    );
    return old;
  end if;

  return null;
end;
$$;

drop trigger if exists trg_documentation_access_configs_audit
  on public.documentation_access_configs;

create trigger trg_documentation_access_configs_audit
after insert or update or delete
on public.documentation_access_configs
for each row
execute function public.audit_documentation_access_config_changes();

create or replace function public.set_documentation_access_configs_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_documentation_access_configs_updated_at
  on public.documentation_access_configs;

create trigger trg_documentation_access_configs_updated_at
before update on public.documentation_access_configs
for each row
execute function public.set_documentation_access_configs_updated_at();


-- END LEGACY: 0038_docs_access_config.sql

-- ============================================================================
-- BEGIN LEGACY: 0039_docs_access_function_search_path_fix.sql
-- ============================================================================

-- Ensure deterministic search_path for docs access trigger helper.

create or replace function public.set_documentation_access_configs_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- END LEGACY: 0039_docs_access_function_search_path_fix.sql

-- ============================================================================
-- BEGIN LEGACY: 0042_centralized_locales.sql
-- ============================================================================

-- Centralized locales with platform mapping
-- Created: 2026-03-03

-- 1. Tabella centrale locale
CREATE TABLE locales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(5) NOT NULL UNIQUE,
  name VARCHAR(50) NOT NULL,
  native_name VARCHAR(50),
  is_rtl BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Locale di default per platform
CREATE TABLE platform_locales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_id UUID REFERENCES platforms(id) ON DELETE CASCADE,
  locale_id UUID REFERENCES locales(id) ON DELETE CASCADE,
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(platform_id, locale_id)
);

-- 3. Aggiungere is_enabled a project_locales
ALTER TABLE project_locales ADD COLUMN IF NOT EXISTS is_enabled BOOLEAN DEFAULT true;

-- Inserire locale iniziali
INSERT INTO locales (code, name, native_name, is_rtl) VALUES
  ('en', 'English', 'English', false),
  ('it', 'Italian', 'Italiano', false),
  ('nl', 'Dutch', 'Nederlands', false),
  ('de', 'German', 'Deutsch', false),
  ('fr', 'French', 'Français', false),
  ('es', 'Spanish', 'Español', false),
  ('pt', 'Portuguese', 'Português', false),
  ('ar', 'Arabic', 'العربية', true),
  ('he', 'Hebrew', 'עברית', true),
  ('zh', 'Chinese', '中文', false),
  ('ja', 'Japanese', '日本語', false),
  ('ru', 'Russian', 'Русский', false)
ON CONFLICT (code) DO NOTHING;

-- Abilitare RLS
ALTER TABLE locales ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_locales ENABLE ROW LEVEL SECURITY;

-- Policy per lettura pubblica
DROP POLICY IF EXISTS "Allow public read access on locales" ON locales;
CREATE POLICY "Allow public read access on locales" ON locales
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow public read access on platform_locales" ON platform_locales;
CREATE POLICY "Allow public read access on platform_locales" ON platform_locales
  FOR SELECT USING (true);


-- END LEGACY: 0042_centralized_locales.sql
