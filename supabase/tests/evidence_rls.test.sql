begin;

set local search_path = public;

do $$
begin
  if to_regclass('public.evidence_timelines') is null
    or to_regclass('public.evidence_messages') is null
    or to_regclass('public.evidence_ai_runs') is null
    or to_regclass('public.evidence_ai_findings') is null then
    raise exception 'Evidence schema is incomplete. Run evidence migrations before this test.';
  end if;
end;
$$;

insert into tenants (id, slug, name)
values
  ('00000000-0000-0000-0000-0000000000a1', 'evidence-rls-tenant-a', 'Evidence RLS Tenant A'),
  ('00000000-0000-0000-0000-0000000000b2', 'evidence-rls-tenant-b', 'Evidence RLS Tenant B')
on conflict (id) do nothing;

insert into projects (id, tenant_id, slug, name)
values
  ('10000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', 'evidence-rls-project-a', 'Evidence RLS Project A'),
  ('20000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000b2', 'evidence-rls-project-b', 'Evidence RLS Project B')
on conflict (id) do nothing;

insert into tenant_members (tenant_id, user_id, role)
values
  ('00000000-0000-0000-0000-0000000000a1', '30000000-0000-0000-0000-0000000000a1', 'tenant_owner'),
  ('00000000-0000-0000-0000-0000000000b2', '30000000-0000-0000-0000-0000000000b2', 'tenant_owner')
on conflict (tenant_id, user_id) do nothing;

insert into evidence_timelines (id, project_id, title)
values
  ('40000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-0000000000a1', 'Tenant A Timeline'),
  ('40000000-0000-0000-0000-0000000000b2', '20000000-0000-0000-0000-0000000000b2', 'Tenant B Timeline')
on conflict (id) do nothing;

insert into evidence_events (
  id,
  project_id,
  timeline_id,
  event_kind,
  title,
  occurred_at,
  is_observed_fact,
  is_claim_or_allegation
)
values
  ('50000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-0000000000a1', '40000000-0000-0000-0000-0000000000a1', 'email', 'Tenant A Event', now(), true, false),
  ('50000000-0000-0000-0000-0000000000b2', '20000000-0000-0000-0000-0000000000b2', '40000000-0000-0000-0000-0000000000b2', 'email', 'Tenant B Event', now(), true, false)
on conflict (id) do nothing;

insert into evidence_messages (
  id,
  project_id,
  timeline_id,
  event_id,
  provider,
  external_message_id,
  subject,
  sender,
  recipients,
  sent_at,
  body_text,
  is_observed_fact,
  is_claim_or_allegation
)
values
  (
    '60000000-0000-0000-0000-0000000000a1',
    '10000000-0000-0000-0000-0000000000a1',
    '40000000-0000-0000-0000-0000000000a1',
    '50000000-0000-0000-0000-0000000000a1',
    'gmail',
    'gmail-a-001',
    'Tenant A Gmail import',
    'manager-a@example.org',
    '["employee-a@example.org"]'::jsonb,
    now(),
    'A imported gmail message body',
    true,
    false
  ),
  (
    '60000000-0000-0000-0000-0000000000b2',
    '20000000-0000-0000-0000-0000000000b2',
    '40000000-0000-0000-0000-0000000000b2',
    '50000000-0000-0000-0000-0000000000b2',
    'gmail',
    'gmail-b-001',
    'Tenant B Gmail import',
    'manager-b@example.org',
    '["employee-b@example.org"]'::jsonb,
    now(),
    'B imported gmail message body',
    true,
    false
  )
on conflict (id) do nothing;

insert into evidence_ai_runs (
  id,
  tenant_id,
  project_id,
  timeline_id,
  provider,
  model,
  status
)
values
  (
    '70000000-0000-0000-0000-0000000000a1',
    '00000000-0000-0000-0000-0000000000a1',
    '10000000-0000-0000-0000-0000000000a1',
    '40000000-0000-0000-0000-0000000000a1',
    'openai',
    'gpt-5.3-mini',
    'completed'
  ),
  (
    '70000000-0000-0000-0000-0000000000b2',
    '00000000-0000-0000-0000-0000000000b2',
    '20000000-0000-0000-0000-0000000000b2',
    '40000000-0000-0000-0000-0000000000b2',
    'openai',
    'gpt-5.3-mini',
    'completed'
  )
on conflict (id) do nothing;

insert into evidence_ai_findings (
  id,
  tenant_id,
  project_id,
  run_id,
  finding_kind,
  severity,
  title,
  output_text,
  confidence
)
values
  (
    '80000000-0000-0000-0000-0000000000a1',
    '00000000-0000-0000-0000-0000000000a1',
    '10000000-0000-0000-0000-0000000000a1',
    '70000000-0000-0000-0000-0000000000a1',
    'inconsistency',
    'medium',
    'Tenant A finding',
    'Timeline mismatch detected for tenant A.',
    0.77
  ),
  (
    '80000000-0000-0000-0000-0000000000b2',
    '00000000-0000-0000-0000-0000000000b2',
    '20000000-0000-0000-0000-0000000000b2',
    '70000000-0000-0000-0000-0000000000b2',
    'inconsistency',
    'medium',
    'Tenant B finding',
    'Timeline mismatch detected for tenant B.',
    0.74
  )
on conflict (id) do nothing;

set local role authenticated;

select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-0000000000a1', true);

do $$
declare
  gmail_count integer;
  finding_count integer;
begin
  select count(*)
  into gmail_count
  from evidence_messages
  where provider = 'gmail';

  if gmail_count <> 1 then
    raise exception 'Tenant A should see exactly 1 gmail evidence row, got %', gmail_count;
  end if;

  select count(*)
  into finding_count
  from evidence_ai_findings;

  if finding_count <> 1 then
    raise exception 'Tenant A should see exactly 1 AI finding row, got %', finding_count;
  end if;
end;
$$;

do $$
begin
  begin
    insert into evidence_messages (
      project_id,
      timeline_id,
      event_id,
      provider,
      subject,
      sender,
      recipients,
      sent_at,
      body_text,
      is_observed_fact,
      is_claim_or_allegation
    )
    values (
      '20000000-0000-0000-0000-0000000000b2',
      '40000000-0000-0000-0000-0000000000b2',
      '50000000-0000-0000-0000-0000000000b2',
      'gmail',
      'Cross tenant write attempt',
      'attacker@example.org',
      '["target@example.org"]'::jsonb,
      now(),
      'Should fail due to RLS',
      true,
      false
    );

    raise exception 'Expected cross-tenant insert to be denied by RLS, but it succeeded.';
  exception
    when insufficient_privilege then
      null;
    when others then
      if sqlstate = '42501' then
        null;
      else
        raise;
      end if;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-0000000000b2', true);

do $$
declare
  gmail_count integer;
  finding_count integer;
begin
  select count(*)
  into gmail_count
  from evidence_messages
  where provider = 'gmail';

  if gmail_count <> 1 then
    raise exception 'Tenant B should see exactly 1 gmail evidence row, got %', gmail_count;
  end if;

  select count(*)
  into finding_count
  from evidence_ai_findings;

  if finding_count <> 1 then
    raise exception 'Tenant B should see exactly 1 AI finding row, got %', finding_count;
  end if;
end;
$$;

do $$
begin
  begin
    insert into evidence_events (
      project_id,
      timeline_id,
      event_kind,
      title,
      occurred_at,
      is_observed_fact,
      is_claim_or_allegation
    ) values (
      '20000000-0000-0000-0000-0000000000b2',
      '40000000-0000-0000-0000-0000000000b2',
      'event',
      'Invalid legal classification row',
      now(),
      false,
      false
    );

    raise exception 'Expected legal classification check violation, but insert succeeded.';
  exception
    when check_violation then
      null;
  end;
end;
$$;

reset role;

rollback;
