-- =============================================================================
-- Evidence Management Local Seed
-- =============================================================================
-- Seeds a dedicated tenant/project and one CASE+EVENT+ARTIFACT+EVIDENCE chain
-- for manual validation in local Supabase resets.
--
-- Idempotency:
-- - Tenant/project use slug upserts
-- - Domain entities use deterministic UUIDs with ON CONFLICT updates
-- =============================================================================

DO $$
DECLARE
  v_admin_email text := 'info@dreamlab.solutions';
  v_user_id uuid;
  v_tenant_id uuid;
  v_project_id uuid;
  v_timeline_id uuid := '11111111-1111-4111-8111-111111111111'::uuid;
  v_event_id uuid := '22222222-2222-4222-8222-222222222222'::uuid;
  v_message_id uuid := '33333333-3333-4333-8333-333333333333'::uuid;
  v_excerpt_id uuid := '44444444-4444-4444-8444-444444444444'::uuid;
  v_dashboard_copy_entry_id uuid := '55555555-5555-4555-8555-555555555555'::uuid;
BEGIN
  -- ---------------------------------------------------------------------------
  -- 1) Resolve admin user from admin seed
  -- ---------------------------------------------------------------------------
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE lower(email) = lower(v_admin_email)
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Missing admin user (%). Run 001_admin_user.sql first.', v_admin_email;
  END IF;

  -- ---------------------------------------------------------------------------
  -- 2) Ensure evidence tenant and membership
  -- ---------------------------------------------------------------------------
  INSERT INTO public.tenants (slug, name)
  VALUES ('evidence-mgmt', 'Evidence Management Test Org')
  ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO v_tenant_id;

  IF v_tenant_id IS NULL THEN
    SELECT id INTO v_tenant_id
    FROM public.tenants
    WHERE slug = 'evidence-mgmt'
    LIMIT 1;
  END IF;

  INSERT INTO public.tenant_members (tenant_id, user_id, role)
  VALUES (v_tenant_id, v_user_id, 'tenant_owner')
  ON CONFLICT (tenant_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  -- ---------------------------------------------------------------------------
  -- 3) Ensure evidence project + local defaults
  -- ---------------------------------------------------------------------------
  INSERT INTO public.projects (tenant_id, slug, name, repo_path)
  VALUES (
    v_tenant_id,
    'evidence-mgmt-next',
    'Evidence Management (Next.js)',
    '/home/dreamux/Projects/dreamlab/apps/evidence-mgmt-next'
  )
  ON CONFLICT (tenant_id, slug) DO UPDATE
    SET name = EXCLUDED.name,
        repo_path = EXCLUDED.repo_path
  RETURNING id INTO v_project_id;

  IF v_project_id IS NULL THEN
    SELECT id INTO v_project_id
    FROM public.projects
    WHERE tenant_id = v_tenant_id
      AND slug = 'evidence-mgmt-next'
    LIMIT 1;
  END IF;

  INSERT INTO public.environments (project_id, key, name)
  VALUES
    (v_project_id, 'prod', 'Production'),
    (v_project_id, 'stage', 'Staging'),
    (v_project_id, 'dev', 'Development')
  ON CONFLICT (project_id, key) DO UPDATE
    SET name = EXCLUDED.name;

  INSERT INTO public.project_locales (project_id, locale, is_default)
  VALUES
    (v_project_id, 'en', true),
    (v_project_id, 'it', false)
  ON CONFLICT (project_id, locale) DO UPDATE
    SET is_default = EXCLUDED.is_default;

  -- ---------------------------------------------------------------------------
  -- 4) Seed dashboard copy model + entry (DB-backed canonical text)
  -- ---------------------------------------------------------------------------
  INSERT INTO public.content_models (
    project_id,
    uid,
    name,
    kind,
    has_draft_and_publish,
    has_i18n,
    fields
  )
  VALUES (
    v_project_id,
    'evidence_dashboard.copy',
    'Evidence Dashboard Copy',
    'single',
    true,
    true,
    '[
      {"key":"copy","label":"Copy Catalog","type":"json","required":true,"translatable":true}
    ]'::jsonb
  )
  ON CONFLICT (project_id, uid) DO UPDATE
    SET name = EXCLUDED.name,
        kind = EXCLUDED.kind,
        has_draft_and_publish = EXCLUDED.has_draft_and_publish,
        has_i18n = EXCLUDED.has_i18n,
        fields = EXCLUDED.fields;

  INSERT INTO public.content_entries (
    id,
    project_id,
    model_uid,
    status,
    title,
    author,
    data
  )
  VALUES (
    v_dashboard_copy_entry_id,
    v_project_id,
    'evidence_dashboard.copy',
    'published',
    'Evidence Dashboard Canonical Copy',
    'seed:evidence-mgmt',
    $$
    {
      "en": {
        "copy": {
          "dashboard.pageTitle": "Evidence Management",
          "dashboard.pageDescription": "Review evidence activity, import email records, and monitor project timelines.",
          "dashboard.welcomeMessage": "Track evidence activity and imports from one protected workspace.",
          "dashboard.action.create": "Create",
          "dashboard.action.import": "Import",
          "dashboard.action.export": "Export",
          "dashboard.action.edit": "Edit",
          "dashboard.action.delete": "Delete",
          "dashboard.action.view": "View",
          "dashboard.action.filter": "Filter",
          "dashboard.action.search": "Search",
          "dashboard.action.sort": "Sort",
          "dashboard.action.refresh": "Refresh",
          "dashboard.action.close": "Close",
          "dashboard.action.confirm": "Confirm",
          "dashboard.action.cancel": "Cancel",
          "dashboard.action.save": "Save",
          "dashboard.action.back": "Back",
          "dashboard.action.dismiss": "Dismiss",
          "dashboard.entity.case": "Case",
          "dashboard.entity.event": "Event",
          "dashboard.entity.artifact": "Artifact",
          "dashboard.entity.evidence": "Evidence",
          "dashboard.entity.consideration": "Consideration",
          "dashboard.entity.claim": "Claim",
          "dashboard.stats.quickOverview": "Quick Overview",
          "dashboard.stats.overviewDescription": "Monitor evidence volume, timelines, and imported communication at a glance.",
          "dashboard.stats.evidenceRecords": "Evidence Records",
          "dashboard.stats.timelines": "Timelines",
          "dashboard.stats.messages": "Messages",
          "dashboard.stats.events": "Events",
          "dashboard.stats.items": "items",
          "dashboard.stats.timelinesCount": "timelines",
          "dashboard.stats.imported": "imported",
          "dashboard.stats.recorded": "recorded",
          "dashboard.empty.no-evidence.title": "No evidence available",
          "dashboard.empty.no-evidence.message": "Import email records or add evidence activity to populate this workspace.",
          "dashboard.empty.no-timelines.title": "No timelines available",
          "dashboard.empty.no-timelines.message": "Create a timeline to organize evidence chronologically.",
          "dashboard.empty.no-access.title": "Access unavailable",
          "dashboard.empty.no-access.message": "This workspace is not available for the current account.",
          "dashboard.empty.no-results.title": "No matching messages",
          "dashboard.empty.no-results.message": "Try a different topic or contact to locate Gmail messages.",
          "dashboard.empty.noActivity.title": "No recent activity",
          "dashboard.empty.noActivity.message": "Recent evidence updates will appear here after activity is recorded.",
          "dashboard.error.access-denied.title": "Access denied",
          "dashboard.error.access-denied.message": "Your account is not authorized to open this dashboard.",
          "dashboard.error.load-failed.title": "Dashboard unavailable",
          "dashboard.error.load-failed.message": "The dashboard context is not ready for this account or tenant.",
          "dashboard.error.activity-access-denied.title": "Activity access denied",
          "dashboard.error.activity-access-denied.message": "Your account cannot review recent evidence activity for this dashboard.",
          "dashboard.error.activity-load-failed.title": "Activity unavailable",
          "dashboard.error.activity-load-failed.message": "Recent evidence activity could not be loaded for this dashboard.",
          "dashboard.error.save-failed.title": "Save unavailable",
          "dashboard.error.save-failed.message": "The requested dashboard update could not be saved.",
          "dashboard.error.import-failed.title": "Import unavailable",
          "dashboard.error.import-failed.message": "The email import request could not be completed.",
          "dashboard.error.network-error.title": "Connection issue",
          "dashboard.error.network-error.message": "The dashboard could not complete the request. Try again.",
          "dashboard.gmail.gmail-query-incomplete.title": "More matching messages available",
          "dashboard.gmail.gmail-query-incomplete.message": "The current query matched more Gmail messages than this response returned.",
          "dashboard.gmail.access-denied.title": "Gmail access denied",
          "dashboard.gmail.access-denied.message": "The current account cannot retrieve Gmail messages for this dashboard.",
          "dashboard.gmail.gmail-configuration-invalid.title": "Gmail configuration unavailable",
          "dashboard.gmail.gmail-configuration-invalid.message": "The Gmail integration is not configured correctly for this workspace.",
          "dashboard.gmail.gmail-credential-missing.title": "Gmail credential missing",
          "dashboard.gmail.gmail-credential-missing.message": "Connect a Gmail credential for this account before retrieving messages.",
          "dashboard.gmail.gmail-credential-invalid.title": "Gmail credential needs attention",
          "dashboard.gmail.gmail-credential-invalid.message": "Reconnect the Gmail credential used for this dashboard before retrying.",
          "dashboard.gmail.gmail-provider-rejected.title": "Gmail request rejected",
          "dashboard.gmail.gmail-provider-rejected.message": "Gmail rejected the retrieval request for the current selection.",
          "dashboard.gmail.gmail-provider-retryable.title": "Gmail temporarily unavailable",
          "dashboard.gmail.gmail-provider-retryable.message": "Gmail could not complete the request right now. Retry in a moment.",
          "dashboard.section.timeline": "Timeline",
          "dashboard.section.evidence": "Evidence",
          "dashboard.section.stats": "Overview",
          "dashboard.section.activity": "Recent Activity",
          "dashboard.section.import": "Email Import"
        }
      },
      "it": {
        "copy": {
          "dashboard.pageTitle": "Evidence Management",
          "dashboard.pageDescription": "Review evidence activity, import email records, and monitor project timelines.",
          "dashboard.welcomeMessage": "Track evidence activity and imports from one protected workspace.",
          "dashboard.action.create": "Create",
          "dashboard.action.import": "Import",
          "dashboard.action.export": "Export",
          "dashboard.action.edit": "Edit",
          "dashboard.action.delete": "Delete",
          "dashboard.action.view": "View",
          "dashboard.action.filter": "Filter",
          "dashboard.action.search": "Search",
          "dashboard.action.sort": "Sort",
          "dashboard.action.refresh": "Refresh",
          "dashboard.action.close": "Close",
          "dashboard.action.confirm": "Confirm",
          "dashboard.action.cancel": "Cancel",
          "dashboard.action.save": "Save",
          "dashboard.action.back": "Back",
          "dashboard.action.dismiss": "Dismiss",
          "dashboard.entity.case": "Case",
          "dashboard.entity.event": "Event",
          "dashboard.entity.artifact": "Artifact",
          "dashboard.entity.evidence": "Evidence",
          "dashboard.entity.consideration": "Consideration",
          "dashboard.entity.claim": "Claim",
          "dashboard.stats.quickOverview": "Quick Overview",
          "dashboard.stats.overviewDescription": "Monitor evidence volume, timelines, and imported communication at a glance.",
          "dashboard.stats.evidenceRecords": "Evidence Records",
          "dashboard.stats.timelines": "Timelines",
          "dashboard.stats.messages": "Messages",
          "dashboard.stats.events": "Events",
          "dashboard.stats.items": "items",
          "dashboard.stats.timelinesCount": "timelines",
          "dashboard.stats.imported": "imported",
          "dashboard.stats.recorded": "recorded",
          "dashboard.empty.no-evidence.title": "No evidence available",
          "dashboard.empty.no-evidence.message": "Import email records or add evidence activity to populate this workspace.",
          "dashboard.empty.no-timelines.title": "No timelines available",
          "dashboard.empty.no-timelines.message": "Create a timeline to organize evidence chronologically.",
          "dashboard.empty.no-access.title": "Access unavailable",
          "dashboard.empty.no-access.message": "This workspace is not available for the current account.",
          "dashboard.empty.no-results.title": "No matching messages",
          "dashboard.empty.no-results.message": "Try a different topic or contact to locate Gmail messages.",
          "dashboard.empty.noActivity.title": "No recent activity",
          "dashboard.empty.noActivity.message": "Recent evidence updates will appear here after activity is recorded.",
          "dashboard.error.access-denied.title": "Access denied",
          "dashboard.error.access-denied.message": "Your account is not authorized to open this dashboard.",
          "dashboard.error.load-failed.title": "Dashboard unavailable",
          "dashboard.error.load-failed.message": "The dashboard context is not ready for this account or tenant.",
          "dashboard.error.activity-access-denied.title": "Activity access denied",
          "dashboard.error.activity-access-denied.message": "Your account cannot review recent evidence activity for this dashboard.",
          "dashboard.error.activity-load-failed.title": "Activity unavailable",
          "dashboard.error.activity-load-failed.message": "Recent evidence activity could not be loaded for this dashboard.",
          "dashboard.error.save-failed.title": "Save unavailable",
          "dashboard.error.save-failed.message": "The requested dashboard update could not be saved.",
          "dashboard.error.import-failed.title": "Import unavailable",
          "dashboard.error.import-failed.message": "The email import request could not be completed.",
          "dashboard.error.network-error.title": "Connection issue",
          "dashboard.error.network-error.message": "The dashboard could not complete the request. Try again.",
          "dashboard.gmail.gmail-query-incomplete.title": "More matching messages available",
          "dashboard.gmail.gmail-query-incomplete.message": "The current query matched more Gmail messages than this response returned.",
          "dashboard.gmail.access-denied.title": "Gmail access denied",
          "dashboard.gmail.access-denied.message": "The current account cannot retrieve Gmail messages for this dashboard.",
          "dashboard.gmail.gmail-configuration-invalid.title": "Gmail configuration unavailable",
          "dashboard.gmail.gmail-configuration-invalid.message": "The Gmail integration is not configured correctly for this workspace.",
          "dashboard.gmail.gmail-credential-missing.title": "Gmail credential missing",
          "dashboard.gmail.gmail-credential-missing.message": "Connect a Gmail credential for this account before retrieving messages.",
          "dashboard.gmail.gmail-credential-invalid.title": "Gmail credential needs attention",
          "dashboard.gmail.gmail-credential-invalid.message": "Reconnect the Gmail credential used for this dashboard before retrying.",
          "dashboard.gmail.gmail-provider-rejected.title": "Gmail request rejected",
          "dashboard.gmail.gmail-provider-rejected.message": "Gmail rejected the retrieval request for the current selection.",
          "dashboard.gmail.gmail-provider-retryable.title": "Gmail temporarily unavailable",
          "dashboard.gmail.gmail-provider-retryable.message": "Gmail could not complete the request right now. Retry in a moment.",
          "dashboard.section.timeline": "Timeline",
          "dashboard.section.evidence": "Evidence",
          "dashboard.section.stats": "Overview",
          "dashboard.section.activity": "Recent Activity",
          "dashboard.section.import": "Email Import"
        }
      }
    }
    $$::jsonb
  )
  ON CONFLICT (id) DO UPDATE
    SET project_id = EXCLUDED.project_id,
        model_uid = EXCLUDED.model_uid,
        status = EXCLUDED.status,
        title = EXCLUDED.title,
        author = EXCLUDED.author,
        data = EXCLUDED.data,
        updated_at = now();

  -- ---------------------------------------------------------------------------
  -- 5) Seed initial CASE (timeline)
  -- ---------------------------------------------------------------------------
  INSERT INTO public.evidence_timelines (
    id, project_id, title, summary, created_by
  )
  VALUES (
    v_timeline_id,
    v_project_id,
    'CASE-001 | Onboarding access discrepancy',
    'Initial case timeline for end-to-end local manual testing.',
    v_user_id
  )
  ON CONFLICT (id) DO UPDATE
    SET project_id = EXCLUDED.project_id,
        title = EXCLUDED.title,
        summary = EXCLUDED.summary,
        created_by = EXCLUDED.created_by,
        updated_at = now();

  -- ---------------------------------------------------------------------------
  -- 6) Seed sample EVENT in timeline
  -- ---------------------------------------------------------------------------
  INSERT INTO public.evidence_events (
    id,
    project_id,
    timeline_id,
    event_kind,
    title,
    description,
    occurred_at,
    timeline_position,
    source_ref,
    is_observed_fact,
    is_claim_or_allegation,
    observed_fact_details,
    claim_or_allegation_details,
    created_by
  )
  VALUES (
    v_event_id,
    v_project_id,
    v_timeline_id,
    'event',
    'HR confirms role mismatch in onboarding request',
    'The onboarding request included analyst permissions that do not match approved role.',
    '2026-02-05T09:30:00Z'::timestamptz,
    10,
    'seed:event:case-001:hr-review',
    true,
    false,
    'Requester role was approved as reviewer-only in HR ticket #HR-741.',
    null,
    v_user_id
  )
  ON CONFLICT (id) DO UPDATE
    SET project_id = EXCLUDED.project_id,
        timeline_id = EXCLUDED.timeline_id,
        event_kind = EXCLUDED.event_kind,
        title = EXCLUDED.title,
        description = EXCLUDED.description,
        occurred_at = EXCLUDED.occurred_at,
        timeline_position = EXCLUDED.timeline_position,
        source_ref = EXCLUDED.source_ref,
        is_observed_fact = EXCLUDED.is_observed_fact,
        is_claim_or_allegation = EXCLUDED.is_claim_or_allegation,
        observed_fact_details = EXCLUDED.observed_fact_details,
        claim_or_allegation_details = EXCLUDED.claim_or_allegation_details,
        created_by = EXCLUDED.created_by,
        updated_at = now();

  -- ---------------------------------------------------------------------------
  -- 7) Seed sample ARTIFACT (message) linked to event
  -- ---------------------------------------------------------------------------
  INSERT INTO public.evidence_messages (
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
    body_html,
    is_observed_fact,
    is_claim_or_allegation,
    observed_fact_details,
    claim_or_allegation_details
  )
  VALUES (
    v_message_id,
    v_project_id,
    v_timeline_id,
    v_event_id,
    'gmail',
    'seed-msg-case-001-hr-1',
    'Role access mismatch on onboarding packet',
    'hr-ops@example.com',
    '["security.lead@example.com", "ops.manager@example.com"]'::jsonb,
    '2026-02-05T09:12:00Z'::timestamptz,
    'The submitted onboarding packet requests analyst permissions, but the approved role is reviewer-only.',
    null,
    true,
    false,
    'Email content confirms requested permissions differ from approved role.',
    null
  )
  ON CONFLICT (id) DO UPDATE
    SET project_id = EXCLUDED.project_id,
        timeline_id = EXCLUDED.timeline_id,
        event_id = EXCLUDED.event_id,
        provider = EXCLUDED.provider,
        external_message_id = EXCLUDED.external_message_id,
        subject = EXCLUDED.subject,
        sender = EXCLUDED.sender,
        recipients = EXCLUDED.recipients,
        sent_at = EXCLUDED.sent_at,
        body_text = EXCLUDED.body_text,
        body_html = EXCLUDED.body_html,
        is_observed_fact = EXCLUDED.is_observed_fact,
        is_claim_or_allegation = EXCLUDED.is_claim_or_allegation,
        observed_fact_details = EXCLUDED.observed_fact_details,
        claim_or_allegation_details = EXCLUDED.claim_or_allegation_details,
        updated_at = now();

  -- ---------------------------------------------------------------------------
  -- 8) Seed sample EVIDENCE (excerpt) linked to artifact
  -- ---------------------------------------------------------------------------
  INSERT INTO public.evidence_excerpts (
    id,
    project_id,
    timeline_id,
    message_id,
    event_id,
    excerpt_text,
    start_offset,
    end_offset,
    is_observed_fact,
    is_claim_or_allegation,
    observed_fact_details,
    claim_or_allegation_details,
    created_by
  )
  VALUES (
    v_excerpt_id,
    v_project_id,
    v_timeline_id,
    v_message_id,
    v_event_id,
    'The submitted onboarding packet requests analyst permissions, but the approved role is reviewer-only.',
    0,
    102,
    true,
    false,
    'Direct excerpt from HR operations email documenting role mismatch.',
    null,
    v_user_id
  )
  ON CONFLICT (id) DO UPDATE
    SET project_id = EXCLUDED.project_id,
        timeline_id = EXCLUDED.timeline_id,
        message_id = EXCLUDED.message_id,
        event_id = EXCLUDED.event_id,
        excerpt_text = EXCLUDED.excerpt_text,
        start_offset = EXCLUDED.start_offset,
        end_offset = EXCLUDED.end_offset,
        is_observed_fact = EXCLUDED.is_observed_fact,
        is_claim_or_allegation = EXCLUDED.is_claim_or_allegation,
        observed_fact_details = EXCLUDED.observed_fact_details,
        claim_or_allegation_details = EXCLUDED.claim_or_allegation_details,
        created_by = EXCLUDED.created_by,
        updated_at = now();

  RAISE NOTICE 'Evidence seed ready: tenant=% project=% timeline=%', v_tenant_id, v_project_id, v_timeline_id;
END $$;
