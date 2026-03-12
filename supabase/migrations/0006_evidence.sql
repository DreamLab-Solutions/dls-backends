-- Rebaselined migration: 0006_evidence.sql

-- Generated from legacy migrations on 2026-03-09.


-- ============================================================================
-- BEGIN LEGACY: 0043_evidence_core.sql
-- ============================================================================

-- Evidence management core schema (public only)

create table if not exists evidence_timelines (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  title text not null,
  summary text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id, id)
);

create table if not exists evidence_events (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  timeline_id uuid not null,
  event_kind text not null default 'event' check (event_kind in ('event', 'email', 'message', 'document', 'meeting', 'note', 'other')),
  title text not null,
  description text,
  occurred_at timestamptz not null,
  timeline_position integer not null default 0 check (timeline_position >= 0),
  source_ref text,
  is_observed_fact boolean not null,
  is_claim_or_allegation boolean not null,
  observed_fact_details text,
  claim_or_allegation_details text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (project_id, timeline_id) references evidence_timelines(project_id, id) on delete cascade,
  unique (project_id, id),
  constraint evidence_events_legal_distinction_check
    check (
      is_observed_fact or is_claim_or_allegation
    )
);

create table if not exists evidence_messages (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  timeline_id uuid not null,
  event_id uuid,
  provider text not null default 'unknown',
  external_message_id text,
  subject text,
  sender text,
  recipients jsonb not null default '[]'::jsonb,
  sent_at timestamptz not null,
  body_text text,
  body_html text,
  is_observed_fact boolean not null,
  is_claim_or_allegation boolean not null,
  observed_fact_details text,
  claim_or_allegation_details text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (project_id, timeline_id) references evidence_timelines(project_id, id) on delete cascade,
  foreign key (project_id, event_id) references evidence_events(project_id, id) on delete set null,
  unique (project_id, id),
  constraint evidence_messages_content_check
    check (
      subject is not null or body_text is not null or body_html is not null
    ),
  constraint evidence_messages_legal_distinction_check
    check (
      is_observed_fact or is_claim_or_allegation
    )
);

create table if not exists evidence_excerpts (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  timeline_id uuid not null,
  message_id uuid not null,
  event_id uuid,
  excerpt_text text not null,
  start_offset integer,
  end_offset integer,
  is_observed_fact boolean not null,
  is_claim_or_allegation boolean not null,
  observed_fact_details text,
  claim_or_allegation_details text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (project_id, timeline_id) references evidence_timelines(project_id, id) on delete cascade,
  foreign key (project_id, message_id) references evidence_messages(project_id, id) on delete cascade,
  foreign key (project_id, event_id) references evidence_events(project_id, id) on delete set null,
  unique (project_id, id),
  constraint evidence_excerpts_offsets_check
    check (
      start_offset is null
      or end_offset is null
      or end_offset >= start_offset
    ),
  constraint evidence_excerpts_legal_distinction_check
    check (
      is_observed_fact or is_claim_or_allegation
    )
);

create table if not exists evidence_comments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  timeline_id uuid not null,
  event_id uuid,
  message_id uuid,
  excerpt_id uuid,
  parent_comment_id uuid,
  body text not null,
  is_observed_fact boolean not null,
  is_claim_or_allegation boolean not null,
  observed_fact_details text,
  claim_or_allegation_details text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (project_id, timeline_id) references evidence_timelines(project_id, id) on delete cascade,
  foreign key (project_id, event_id) references evidence_events(project_id, id) on delete set null,
  foreign key (project_id, message_id) references evidence_messages(project_id, id) on delete set null,
  foreign key (project_id, excerpt_id) references evidence_excerpts(project_id, id) on delete set null,
  foreign key (project_id, parent_comment_id) references evidence_comments(project_id, id) on delete cascade,
  unique (project_id, id),
  constraint evidence_comments_target_check
    check (
      num_nonnulls(event_id, message_id, excerpt_id, parent_comment_id) >= 1
    ),
  constraint evidence_comments_legal_distinction_check
    check (
      is_observed_fact or is_claim_or_allegation
    )
);

create table if not exists evidence_tags (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  key text not null,
  label text not null,
  created_at timestamptz not null default now(),
  unique (project_id, id)
);

create table if not exists evidence_emotions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  key text not null,
  label text not null,
  valence smallint check (valence between -5 and 5),
  created_at timestamptz not null default now(),
  unique (project_id, id)
);

create table if not exists evidence_tag_links (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  tag_id uuid not null,
  event_id uuid,
  message_id uuid,
  excerpt_id uuid,
  comment_id uuid,
  created_at timestamptz not null default now(),
  foreign key (project_id, tag_id) references evidence_tags(project_id, id) on delete cascade,
  foreign key (project_id, event_id) references evidence_events(project_id, id) on delete cascade,
  foreign key (project_id, message_id) references evidence_messages(project_id, id) on delete cascade,
  foreign key (project_id, excerpt_id) references evidence_excerpts(project_id, id) on delete cascade,
  foreign key (project_id, comment_id) references evidence_comments(project_id, id) on delete cascade,
  constraint evidence_tag_links_target_check
    check (
      num_nonnulls(event_id, message_id, excerpt_id, comment_id) = 1
    )
);

create table if not exists evidence_emotion_links (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  emotion_id uuid not null,
  event_id uuid,
  message_id uuid,
  excerpt_id uuid,
  comment_id uuid,
  intensity smallint not null default 3 check (intensity between 1 and 5),
  created_at timestamptz not null default now(),
  foreign key (project_id, emotion_id) references evidence_emotions(project_id, id) on delete cascade,
  foreign key (project_id, event_id) references evidence_events(project_id, id) on delete cascade,
  foreign key (project_id, message_id) references evidence_messages(project_id, id) on delete cascade,
  foreign key (project_id, excerpt_id) references evidence_excerpts(project_id, id) on delete cascade,
  foreign key (project_id, comment_id) references evidence_comments(project_id, id) on delete cascade,
  constraint evidence_emotion_links_target_check
    check (
      num_nonnulls(event_id, message_id, excerpt_id, comment_id) = 1
    )
);

create unique index if not exists idx_evidence_tags_project_key_unique
  on evidence_tags(project_id, lower(key));
create unique index if not exists idx_evidence_emotions_project_key_unique
  on evidence_emotions(project_id, lower(key));
create unique index if not exists idx_evidence_messages_project_provider_external_unique
  on evidence_messages(project_id, provider, external_message_id)
  where external_message_id is not null;

create unique index if not exists idx_evidence_tag_links_unique_event
  on evidence_tag_links(project_id, tag_id, event_id)
  where event_id is not null;
create unique index if not exists idx_evidence_tag_links_unique_message
  on evidence_tag_links(project_id, tag_id, message_id)
  where message_id is not null;
create unique index if not exists idx_evidence_tag_links_unique_excerpt
  on evidence_tag_links(project_id, tag_id, excerpt_id)
  where excerpt_id is not null;
create unique index if not exists idx_evidence_tag_links_unique_comment
  on evidence_tag_links(project_id, tag_id, comment_id)
  where comment_id is not null;

create unique index if not exists idx_evidence_emotion_links_unique_event
  on evidence_emotion_links(project_id, emotion_id, event_id)
  where event_id is not null;
create unique index if not exists idx_evidence_emotion_links_unique_message
  on evidence_emotion_links(project_id, emotion_id, message_id)
  where message_id is not null;
create unique index if not exists idx_evidence_emotion_links_unique_excerpt
  on evidence_emotion_links(project_id, emotion_id, excerpt_id)
  where excerpt_id is not null;
create unique index if not exists idx_evidence_emotion_links_unique_comment
  on evidence_emotion_links(project_id, emotion_id, comment_id)
  where comment_id is not null;

create index if not exists idx_evidence_timelines_project_id
  on evidence_timelines(project_id);
create index if not exists idx_evidence_events_project_timeline_order
  on evidence_events(project_id, timeline_id, occurred_at, timeline_position, id);
create index if not exists idx_evidence_messages_project_timeline_sent
  on evidence_messages(project_id, timeline_id, sent_at, id);
create index if not exists idx_evidence_excerpts_project_message
  on evidence_excerpts(project_id, message_id, id);
create index if not exists idx_evidence_comments_project_timeline_created
  on evidence_comments(project_id, timeline_id, created_at, id);
create index if not exists idx_evidence_comments_project_parent
  on evidence_comments(project_id, parent_comment_id);
create index if not exists idx_evidence_tag_links_project_tag
  on evidence_tag_links(project_id, tag_id);
create index if not exists idx_evidence_emotion_links_project_emotion
  on evidence_emotion_links(project_id, emotion_id);

alter table evidence_timelines enable row level security;
alter table evidence_events enable row level security;
alter table evidence_messages enable row level security;
alter table evidence_excerpts enable row level security;
alter table evidence_comments enable row level security;
alter table evidence_tags enable row level security;
alter table evidence_emotions enable row level security;
alter table evidence_tag_links enable row level security;
alter table evidence_emotion_links enable row level security;

create policy "Evidence timelines access for members"
  on evidence_timelines for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_timelines.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_timelines.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence events access for members"
  on evidence_events for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_events.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_events.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence messages access for members"
  on evidence_messages for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_messages.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_messages.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence excerpts access for members"
  on evidence_excerpts for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_excerpts.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_excerpts.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence comments access for members"
  on evidence_comments for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_comments.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_comments.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence tags access for members"
  on evidence_tags for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_tags.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_tags.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence emotions access for members"
  on evidence_emotions for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_emotions.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_emotions.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence tag links access for members"
  on evidence_tag_links for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_tag_links.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_tag_links.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence emotion links access for members"
  on evidence_emotion_links for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_emotion_links.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_emotion_links.project_id
      and tm.user_id = auth.uid()
    )
  );


-- END LEGACY: 0043_evidence_core.sql

-- ============================================================================
-- BEGIN LEGACY: 0045_evidence_ai_rag.sql
-- ============================================================================

-- Evidence mini-RAG and AI findings persistence schema (public only)

create extension if not exists vector with schema public;

create table if not exists evidence_rag_documents (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  project_id uuid not null references projects(id) on delete cascade,
  timeline_id uuid,
  event_id uuid,
  message_id uuid,
  excerpt_id uuid,
  comment_id uuid,
  source_kind text not null check (source_kind in ('timeline', 'event', 'message', 'excerpt', 'comment', 'mixed')),
  source_external_ref text,
  title text,
  body_text text not null,
  content_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (project_id, timeline_id) references evidence_timelines(project_id, id) on delete set null,
  foreign key (project_id, event_id) references evidence_events(project_id, id) on delete set null,
  foreign key (project_id, message_id) references evidence_messages(project_id, id) on delete set null,
  foreign key (project_id, excerpt_id) references evidence_excerpts(project_id, id) on delete set null,
  foreign key (project_id, comment_id) references evidence_comments(project_id, id) on delete set null,
  unique (project_id, id),
  constraint evidence_rag_documents_source_target_check check (
    (
      source_kind = 'timeline'
      and num_nonnulls(timeline_id, event_id, message_id, excerpt_id, comment_id) >= 1
    )
    or (
      source_kind = 'event'
      and event_id is not null
    )
    or (
      source_kind = 'message'
      and message_id is not null
    )
    or (
      source_kind = 'excerpt'
      and excerpt_id is not null
    )
    or (
      source_kind = 'comment'
      and comment_id is not null
    )
    or (
      source_kind = 'mixed'
      and num_nonnulls(timeline_id, event_id, message_id, excerpt_id, comment_id) >= 1
    )
  )
);

create table if not exists evidence_rag_chunks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  project_id uuid not null references projects(id) on delete cascade,
  document_id uuid not null,
  chunk_index integer not null check (chunk_index >= 0),
  chunk_text text not null,
  token_count integer,
  embedding vector(1536),
  embedding_model text,
  content_lexemes tsvector generated always as (to_tsvector('simple', coalesce(chunk_text, ''))) stored,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (project_id, document_id) references evidence_rag_documents(project_id, id) on delete cascade,
  unique (project_id, id),
  unique (project_id, document_id, chunk_index)
);

create table if not exists evidence_ai_runs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  project_id uuid not null references projects(id) on delete cascade,
  timeline_id uuid,
  requested_by uuid,
  provider text not null,
  model text not null,
  retrieval_query text,
  retrieval_filter jsonb not null default '{}'::jsonb,
  retrieval_top_k integer not null default 20 check (retrieval_top_k between 1 and 200),
  prompt text,
  input_tokens integer,
  output_tokens integer,
  status text not null default 'completed' check (status in ('queued', 'running', 'completed', 'failed')),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  foreign key (project_id, timeline_id) references evidence_timelines(project_id, id) on delete set null,
  unique (project_id, id)
);

create table if not exists evidence_ai_findings (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  project_id uuid not null references projects(id) on delete cascade,
  run_id uuid not null,
  finding_kind text not null check (finding_kind in ('inconsistency', 'risk', 'timeline_gap', 'recommendation', 'summary', 'other')),
  severity text not null default 'medium' check (severity in ('low', 'medium', 'high', 'critical')),
  title text not null,
  output_text text not null,
  confidence numeric(4,3) check (confidence is null or (confidence >= 0 and confidence <= 1)),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  foreign key (project_id, run_id) references evidence_ai_runs(project_id, id) on delete cascade,
  unique (project_id, id)
);

create table if not exists evidence_ai_statements (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  project_id uuid not null references projects(id) on delete cascade,
  finding_id uuid not null,
  statement_type text not null check (statement_type in ('observed_fact', 'claim', 'inference', 'recommendation')),
  statement_text text not null,
  confidence numeric(4,3) check (confidence is null or (confidence >= 0 and confidence <= 1)),
  ordinal integer not null default 0 check (ordinal >= 0),
  created_at timestamptz not null default now(),
  foreign key (project_id, finding_id) references evidence_ai_findings(project_id, id) on delete cascade,
  unique (project_id, id)
);

create table if not exists evidence_ai_statement_evidence_links (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  project_id uuid not null references projects(id) on delete cascade,
  statement_id uuid not null,
  chunk_id uuid,
  event_id uuid,
  message_id uuid,
  excerpt_id uuid,
  comment_id uuid,
  relation_kind text not null check (relation_kind in ('supports', 'contradicts', 'context')),
  evidence_kind text not null check (evidence_kind in ('observed_fact', 'claim_or_allegation', 'mixed', 'unknown')),
  rationale text,
  created_at timestamptz not null default now(),
  foreign key (project_id, statement_id) references evidence_ai_statements(project_id, id) on delete cascade,
  foreign key (project_id, chunk_id) references evidence_rag_chunks(project_id, id) on delete set null,
  foreign key (project_id, event_id) references evidence_events(project_id, id) on delete set null,
  foreign key (project_id, message_id) references evidence_messages(project_id, id) on delete set null,
  foreign key (project_id, excerpt_id) references evidence_excerpts(project_id, id) on delete set null,
  foreign key (project_id, comment_id) references evidence_comments(project_id, id) on delete set null,
  unique (project_id, id),
  constraint evidence_ai_statement_links_target_check check (
    num_nonnulls(chunk_id, event_id, message_id, excerpt_id, comment_id) >= 1
  )
);

create or replace function public.sync_evidence_tenant_id_from_project()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id
  into v_tenant_id
  from projects
  where id = new.project_id;

  if v_tenant_id is null then
    raise exception 'Project % not found for evidence tenant sync', new.project_id;
  end if;

  new.tenant_id = v_tenant_id;
  return new;
end;
$$;

create trigger trg_evidence_rag_documents_tenant_sync
before insert or update on evidence_rag_documents
for each row
execute function public.sync_evidence_tenant_id_from_project();

create trigger trg_evidence_rag_chunks_tenant_sync
before insert or update on evidence_rag_chunks
for each row
execute function public.sync_evidence_tenant_id_from_project();

create trigger trg_evidence_ai_runs_tenant_sync
before insert or update on evidence_ai_runs
for each row
execute function public.sync_evidence_tenant_id_from_project();

create trigger trg_evidence_ai_findings_tenant_sync
before insert or update on evidence_ai_findings
for each row
execute function public.sync_evidence_tenant_id_from_project();

create trigger trg_evidence_ai_statements_tenant_sync
before insert or update on evidence_ai_statements
for each row
execute function public.sync_evidence_tenant_id_from_project();

create trigger trg_evidence_ai_statement_evidence_links_tenant_sync
before insert or update on evidence_ai_statement_evidence_links
for each row
execute function public.sync_evidence_tenant_id_from_project();

create or replace function public.search_evidence_rag_chunks(
  p_tenant_id uuid,
  p_project_id uuid,
  p_query text,
  p_limit integer default 20
)
returns table (
  chunk_id uuid,
  document_id uuid,
  chunk_index integer,
  chunk_text text,
  lexical_score real
)
language sql
stable
set search_path = public
as $$
  with query_input as (
    select nullif(trim(coalesce(p_query, '')), '') as cleaned_query
  )
  select
    c.id as chunk_id,
    c.document_id,
    c.chunk_index,
    c.chunk_text,
    ts_rank(c.content_lexemes, websearch_to_tsquery('simple', qi.cleaned_query)) as lexical_score
  from evidence_rag_chunks c
  cross join query_input qi
  where c.tenant_id = p_tenant_id
    and c.project_id = p_project_id
    and qi.cleaned_query is not null
    and c.content_lexemes @@ websearch_to_tsquery('simple', qi.cleaned_query)
  order by lexical_score desc, c.document_id, c.chunk_index
  limit greatest(coalesce(p_limit, 20), 1);
$$;

create or replace function public.match_evidence_rag_chunks(
  p_tenant_id uuid,
  p_project_id uuid,
  p_query_embedding vector(1536),
  p_limit integer default 20
)
returns table (
  chunk_id uuid,
  document_id uuid,
  chunk_index integer,
  chunk_text text,
  distance double precision
)
language sql
stable
set search_path = public
as $$
  select
    c.id as chunk_id,
    c.document_id,
    c.chunk_index,
    c.chunk_text,
    (c.embedding <=> p_query_embedding) as distance
  from evidence_rag_chunks c
  where c.tenant_id = p_tenant_id
    and c.project_id = p_project_id
    and c.embedding is not null
  order by c.embedding <=> p_query_embedding
  limit greatest(coalesce(p_limit, 20), 1);
$$;

create index if not exists idx_evidence_rag_documents_tenant_project
  on evidence_rag_documents(tenant_id, project_id);
create index if not exists idx_evidence_rag_documents_source_links
  on evidence_rag_documents(project_id, source_kind, timeline_id, event_id, message_id, excerpt_id, comment_id);
create index if not exists idx_evidence_rag_documents_content_hash
  on evidence_rag_documents(project_id, content_hash)
  where content_hash is not null;

create index if not exists idx_evidence_rag_chunks_tenant_project
  on evidence_rag_chunks(tenant_id, project_id, document_id, chunk_index);
create index if not exists idx_evidence_rag_chunks_project_document
  on evidence_rag_chunks(project_id, document_id, chunk_index);
create index if not exists idx_evidence_rag_chunks_lexemes
  on evidence_rag_chunks using gin (content_lexemes);
create index if not exists idx_evidence_rag_chunks_embedding_ivfflat
  on evidence_rag_chunks using ivfflat (embedding vector_cosine_ops)
  with (lists = 100)
  where embedding is not null;

create index if not exists idx_evidence_ai_runs_tenant_project_created
  on evidence_ai_runs(tenant_id, project_id, created_at desc);
create index if not exists idx_evidence_ai_findings_project_run
  on evidence_ai_findings(project_id, run_id, severity);
create index if not exists idx_evidence_ai_statements_project_finding
  on evidence_ai_statements(project_id, finding_id, statement_type, ordinal);
create index if not exists idx_evidence_ai_statement_links_project_statement
  on evidence_ai_statement_evidence_links(project_id, statement_id);
create index if not exists idx_evidence_ai_statement_links_project_chunk
  on evidence_ai_statement_evidence_links(project_id, chunk_id)
  where chunk_id is not null;
create index if not exists idx_evidence_ai_statement_links_project_evidence_kind
  on evidence_ai_statement_evidence_links(project_id, relation_kind, evidence_kind);

alter table evidence_rag_documents enable row level security;
alter table evidence_rag_chunks enable row level security;
alter table evidence_ai_runs enable row level security;
alter table evidence_ai_findings enable row level security;
alter table evidence_ai_statements enable row level security;
alter table evidence_ai_statement_evidence_links enable row level security;

create policy "Evidence RAG documents access for members"
  on evidence_rag_documents for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_rag_documents.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_rag_documents.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence RAG chunks access for members"
  on evidence_rag_chunks for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_rag_chunks.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_rag_chunks.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence AI runs access for members"
  on evidence_ai_runs for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_ai_runs.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_ai_runs.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence AI findings access for members"
  on evidence_ai_findings for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_ai_findings.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_ai_findings.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence AI statements access for members"
  on evidence_ai_statements for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_ai_statements.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_ai_statements.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence AI statement evidence links access for members"
  on evidence_ai_statement_evidence_links for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_ai_statement_evidence_links.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_ai_statement_evidence_links.project_id
      and tm.user_id = auth.uid()
    )
  );


-- END LEGACY: 0045_evidence_ai_rag.sql
