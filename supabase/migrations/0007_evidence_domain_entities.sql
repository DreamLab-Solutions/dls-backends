-- Evidence domain entities: people, claims, considerations, packs

create table if not exists evidence_people (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  full_name text not null,
  email text,
  role text not null check (role in ('sender', 'recipient', 'case_officer', 'witness')),
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id, id)
);

create table if not exists evidence_claims (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  timeline_id uuid,
  title text not null,
  claim_text text not null,
  legal_basis text,
  jurisdiction text,
  status text not null default 'draft' check (status in ('draft', 'under_review', 'accepted', 'rejected')),
  confidence numeric(4,3) check (confidence is null or (confidence >= 0 and confidence <= 1)),
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (project_id, timeline_id) references evidence_timelines(project_id, id) on delete set null,
  unique (project_id, id)
);

create table if not exists evidence_claim_evidence_links (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  claim_id uuid not null,
  event_id uuid,
  message_id uuid,
  excerpt_id uuid,
  comment_id uuid,
  relation_kind text not null default 'supports' check (relation_kind in ('supports', 'contradicts', 'context')),
  rationale text,
  created_at timestamptz not null default now(),
  foreign key (project_id, claim_id) references evidence_claims(project_id, id) on delete cascade,
  foreign key (project_id, event_id) references evidence_events(project_id, id) on delete set null,
  foreign key (project_id, message_id) references evidence_messages(project_id, id) on delete set null,
  foreign key (project_id, excerpt_id) references evidence_excerpts(project_id, id) on delete set null,
  foreign key (project_id, comment_id) references evidence_comments(project_id, id) on delete set null,
  unique (project_id, id),
  constraint evidence_claim_links_target_check
    check (num_nonnulls(event_id, message_id, excerpt_id, comment_id) = 1)
);

create table if not exists evidence_considerations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  timeline_id uuid,
  claim_id uuid,
  title text not null,
  interpretation_text text not null,
  perspective text,
  confidence numeric(4,3) check (confidence is null or (confidence >= 0 and confidence <= 1)),
  status text not null default 'draft' check (status in ('draft', 'under_review', 'accepted', 'rejected')),
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (project_id, timeline_id) references evidence_timelines(project_id, id) on delete set null,
  foreign key (project_id, claim_id) references evidence_claims(project_id, id) on delete set null,
  unique (project_id, id)
);

create table if not exists evidence_consideration_evidence_links (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  consideration_id uuid not null,
  event_id uuid,
  message_id uuid,
  excerpt_id uuid,
  comment_id uuid,
  relation_kind text not null default 'context' check (relation_kind in ('supports', 'contradicts', 'context')),
  rationale text,
  created_at timestamptz not null default now(),
  foreign key (project_id, consideration_id) references evidence_considerations(project_id, id) on delete cascade,
  foreign key (project_id, event_id) references evidence_events(project_id, id) on delete set null,
  foreign key (project_id, message_id) references evidence_messages(project_id, id) on delete set null,
  foreign key (project_id, excerpt_id) references evidence_excerpts(project_id, id) on delete set null,
  foreign key (project_id, comment_id) references evidence_comments(project_id, id) on delete set null,
  unique (project_id, id),
  constraint evidence_consideration_links_target_check
    check (num_nonnulls(event_id, message_id, excerpt_id, comment_id) = 1)
);

create table if not exists evidence_packs (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  slug text not null,
  title text not null,
  description text,
  visibility text not null default 'private' check (visibility in ('private', 'project')),
  owner_user_id uuid not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id, id),
  unique (project_id, slug)
);

create table if not exists evidence_pack_members (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  pack_id uuid not null,
  user_id uuid not null,
  access_role text not null default 'viewer' check (access_role in ('owner', 'editor', 'viewer')),
  created_at timestamptz not null default now(),
  foreign key (project_id, pack_id) references evidence_packs(project_id, id) on delete cascade,
  unique (project_id, id),
  unique (project_id, pack_id, user_id)
);

create table if not exists evidence_pack_items (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  pack_id uuid not null,
  event_id uuid,
  message_id uuid,
  excerpt_id uuid,
  comment_id uuid,
  claim_id uuid,
  consideration_id uuid,
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  foreign key (project_id, pack_id) references evidence_packs(project_id, id) on delete cascade,
  foreign key (project_id, event_id) references evidence_events(project_id, id) on delete cascade,
  foreign key (project_id, message_id) references evidence_messages(project_id, id) on delete cascade,
  foreign key (project_id, excerpt_id) references evidence_excerpts(project_id, id) on delete cascade,
  foreign key (project_id, comment_id) references evidence_comments(project_id, id) on delete cascade,
  foreign key (project_id, claim_id) references evidence_claims(project_id, id) on delete cascade,
  foreign key (project_id, consideration_id) references evidence_considerations(project_id, id) on delete cascade,
  unique (project_id, id),
  constraint evidence_pack_items_target_check
    check (num_nonnulls(event_id, message_id, excerpt_id, comment_id, claim_id, consideration_id) = 1)
);

create index if not exists idx_evidence_people_project_role
  on evidence_people(project_id, role, id);

create index if not exists idx_evidence_claims_project_timeline_status
  on evidence_claims(project_id, timeline_id, status, created_at desc);
create index if not exists idx_evidence_claim_links_project_claim
  on evidence_claim_evidence_links(project_id, claim_id);

create index if not exists idx_evidence_considerations_project_claim_status
  on evidence_considerations(project_id, claim_id, status, created_at desc);
create index if not exists idx_evidence_consideration_links_project_consideration
  on evidence_consideration_evidence_links(project_id, consideration_id);

create index if not exists idx_evidence_packs_project_slug
  on evidence_packs(project_id, slug);
create index if not exists idx_evidence_pack_members_project_pack_user
  on evidence_pack_members(project_id, pack_id, user_id);
create index if not exists idx_evidence_pack_items_project_pack_order
  on evidence_pack_items(project_id, pack_id, sort_order, id);

alter table evidence_people enable row level security;
alter table evidence_claims enable row level security;
alter table evidence_claim_evidence_links enable row level security;
alter table evidence_considerations enable row level security;
alter table evidence_consideration_evidence_links enable row level security;
alter table evidence_packs enable row level security;
alter table evidence_pack_members enable row level security;
alter table evidence_pack_items enable row level security;

create policy "Evidence people access for members"
  on evidence_people for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_people.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_people.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence claims access for members"
  on evidence_claims for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_claims.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_claims.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence claim links access for members"
  on evidence_claim_evidence_links for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_claim_evidence_links.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_claim_evidence_links.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence considerations access for members"
  on evidence_considerations for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_considerations.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_considerations.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence consideration links access for members"
  on evidence_consideration_evidence_links for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_consideration_evidence_links.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_consideration_evidence_links.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence packs access for members"
  on evidence_packs for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_packs.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_packs.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence pack members access for members"
  on evidence_pack_members for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_pack_members.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_pack_members.project_id
      and tm.user_id = auth.uid()
    )
  );

create policy "Evidence pack items access for members"
  on evidence_pack_items for all
  using (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_pack_items.project_id
      and tm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from projects p
      join tenant_members tm on tm.tenant_id = p.tenant_id
      where p.id = evidence_pack_items.project_id
      and tm.user_id = auth.uid()
    )
  );
