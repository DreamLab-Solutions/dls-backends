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
  v_dev_environment_id uuid;
  v_stage_environment_id uuid;
  v_prod_environment_id uuid;
  v_platform_id uuid;
  v_dashboard_copy_entry_id uuid := '99999999-9999-4999-8999-999999999999'::uuid;
  v_timeline_id uuid := '11111111-1111-4111-8111-111111111111'::uuid;
  v_event_id uuid := '22222222-2222-4222-8222-222222222222'::uuid;
  v_message_id uuid := '33333333-3333-4333-8333-333333333333'::uuid;
  v_excerpt_id uuid := '44444444-4444-4444-8444-444444444444'::uuid;
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

  SELECT id INTO v_dev_environment_id
  FROM public.environments
  WHERE project_id = v_project_id
    AND key = 'dev'
  LIMIT 1;

  SELECT id INTO v_stage_environment_id
  FROM public.environments
  WHERE project_id = v_project_id
    AND key = 'stage'
  LIMIT 1;

  SELECT id INTO v_prod_environment_id
  FROM public.environments
  WHERE project_id = v_project_id
    AND key = 'prod'
  LIMIT 1;

  INSERT INTO public.platforms (
    name,
    slug,
    description,
    website,
    is_official,
    status,
    capabilities
  )
  VALUES (
    'Evidence Management',
    'evidence-management',
    'Dedicated evidence review workspace for timeline analysis and document-backed findings.',
    'https://evidence.dreamlab.solutions',
    true,
    'active',
    ARRAY['evidence-workspace', 'mail-ingestion', 'ai-analysis']
  )
  ON CONFLICT (slug) DO UPDATE
    SET name = EXCLUDED.name,
        description = EXCLUDED.description,
        website = EXCLUDED.website,
        is_official = EXCLUDED.is_official,
        status = EXCLUDED.status,
        capabilities = EXCLUDED.capabilities
  RETURNING id INTO v_platform_id;

  IF v_platform_id IS NULL THEN
    SELECT id INTO v_platform_id
    FROM public.platforms
    WHERE slug = 'evidence-management'
    LIMIT 1;
  END IF;

  DELETE FROM public.platform_links
  WHERE tenant_id = v_tenant_id
    AND path = '/evidence';

  INSERT INTO public.platform_links (tenant_id, platform_id, path, target_url, is_visible, clicks)
  VALUES (v_tenant_id, v_platform_id, '/evidence', 'https://evidence.dreamlab.solutions', true, 0);

  DELETE FROM public.platform_subscriptions
  WHERE tenant_id = v_tenant_id
    AND platform_id = v_platform_id;

  INSERT INTO public.platform_subscriptions (tenant_id, platform_id, plan_id, status)
  VALUES (v_tenant_id, v_platform_id, 'evidence-internal', 'active');

  INSERT INTO public.platform_project_mappings (platform_id, project_id)
  VALUES (v_platform_id, v_project_id)
  ON CONFLICT (platform_id, project_id) DO NOTHING;

  INSERT INTO public.package_definitions (
    key,
    package_name,
    workspace_path,
    category,
    kind,
    description,
    repository,
    version,
    schema_checksum,
    source_commit_sha,
    metadata
  )
  VALUES
    ('pkg.dls-api-core', '@dreamlab-solutions/dls-api-core', 'packages/dls-api-core', 'platform', 'core', 'Canonical shared contracts, adapters, and use cases.', 'dreamlab-solutions/dreamlab', '0.1.0', 'chk_dls_api_core_0_1_0', 'seed-reset-2026-03-12', '{"owner":"core-platform"}'::jsonb),
    ('pkg.dls-domain', '@dreamlab-solutions/dls-domain', 'packages/dls-domain', 'platform', 'domain', 'Shared cross-package domain primitives.', 'dreamlab-solutions/dreamlab', '0.1.0', 'chk_dls_domain_0_1_0', 'seed-reset-2026-03-12', '{"owner":"core-platform"}'::jsonb),
    ('pkg.dls-ui-react', '@dreamlab-solutions/dls-ui-react', 'packages/dls-ui-react', 'design-system', 'ui', 'Reusable shared React components.', 'dreamlab-solutions/dreamlab', '0.1.0', 'chk_dls_ui_react_0_1_0', 'seed-reset-2026-03-12', '{"owner":"design-system"}'::jsonb),
    ('pkg.dls-theme', '@dreamlab-solutions/dls-theme', 'packages/dls-theme', 'design-system', 'theme', 'Shared design tokens and CSS contracts.', 'dreamlab-solutions/dreamlab', '0.1.0', 'chk_dls_theme_0_1_0', 'seed-reset-2026-03-12', '{"owner":"design-system"}'::jsonb),
    ('pkg.dls-evidence-bff', '@dreamlab-solutions/dls-evidence-bff', 'packages/dls-evidence-bff', 'evidence', 'bff', 'Evidence-specific server facade and orchestration.', 'dreamlab-solutions/dreamlab', '0.1.0', 'chk_dls_evidence_bff_0_1_0', 'seed-reset-2026-03-12', '{"owner":"evidence"}'::jsonb),
    ('pkg.dls-evidence-ui-react', '@dreamlab-solutions/dls-evidence-ui-react', 'packages/dls-evidence-ui-react', 'evidence', 'ui', 'Evidence-specific presentational components.', 'dreamlab-solutions/dreamlab', '0.1.0', 'chk_dls_evidence_ui_react_0_1_0', 'seed-reset-2026-03-12', '{"owner":"evidence"}'::jsonb)
  ON CONFLICT (key) DO UPDATE
    SET package_name = EXCLUDED.package_name,
        workspace_path = EXCLUDED.workspace_path,
        kind = EXCLUDED.kind,
        description = EXCLUDED.description,
        repository = EXCLUDED.repository,
        version = EXCLUDED.version,
        schema_checksum = EXCLUDED.schema_checksum,
        source_commit_sha = EXCLUDED.source_commit_sha,
        metadata = EXCLUDED.metadata;

  INSERT INTO public.project_package_bindings (project_id, package_key, relationship, metadata)
  VALUES
    (v_project_id, 'pkg.dls-api-core', 'core_dependency', '{"workspace":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, 'pkg.dls-domain', 'core_dependency', '{"workspace":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, 'pkg.dls-ui-react', 'ui_dependency', '{"workspace":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, 'pkg.dls-theme', 'ui_dependency', '{"workspace":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, 'pkg.dls-evidence-bff', 'bff_dependency', '{"workspace":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, 'pkg.dls-evidence-ui-react', 'ui_dependency', '{"workspace":"apps/evidence-mgmt-next"}'::jsonb)
  ON CONFLICT (project_id, package_key) DO UPDATE
    SET relationship = EXCLUDED.relationship,
        metadata = EXCLUDED.metadata;

  INSERT INTO public.app_package_bindings (app_id, package_key, role, metadata)
  VALUES
    ('app_evidence', 'pkg.dls-api-core', 'core', '{"workspace":"apps/evidence-mgmt-next"}'::jsonb),
    ('app_evidence', 'pkg.dls-evidence-bff', 'bff', '{"workspace":"apps/evidence-mgmt-next"}'::jsonb),
    ('app_evidence', 'pkg.dls-evidence-ui-react', 'ui', '{"workspace":"apps/evidence-mgmt-next"}'::jsonb),
    ('app_evidence', 'pkg.dls-ui-react', 'ui', '{"workspace":"apps/evidence-mgmt-next"}'::jsonb),
    ('app_evidence', 'pkg.dls-theme', 'theme', '{"workspace":"apps/evidence-mgmt-next"}'::jsonb)
  ON CONFLICT (app_id, package_key, role) DO UPDATE
    SET metadata = EXCLUDED.metadata;

  INSERT INTO public.project_repos (project_id, provider, owner, repo, default_branch, status, metadata)
  VALUES (
    v_project_id,
    'github',
    'dreamlab-solutions',
    'dreamlab',
    'main',
    'connected',
    '{"workspacePath":"apps/evidence-mgmt-next","trackedBranches":{"dev":"develop","stage":"stage","prod":"main"},"artifactPaths":{"routing":"apps/evidence-mgmt-next/.dreamlab/routing.json","composition":"apps/evidence-mgmt-next/.dreamlab/composition.json","appDefinition":"apps/evidence-mgmt-next/.dreamlab/app-definition.json","registry":"apps/evidence-mgmt-next/.dreamlab/registry.json","contentModels":"apps/evidence-mgmt-next/.dreamlab/content-models.json","versionPins":"apps/evidence-mgmt-next/.dreamlab/version-pins.json","packages":"apps/evidence-mgmt-next/.dreamlab/packages.json"}}'::jsonb
  )
  ON CONFLICT (project_id) DO UPDATE
    SET provider = EXCLUDED.provider,
        owner = EXCLUDED.owner,
        repo = EXCLUDED.repo,
        default_branch = EXCLUDED.default_branch,
        status = EXCLUDED.status,
        metadata = EXCLUDED.metadata,
        updated_at = now();

  INSERT INTO public.project_domains (project_id, environment_id, domain, status, provider, verification, metadata)
  VALUES (
    v_project_id,
    v_dev_environment_id,
    'evidence.dreamlab.solutions',
    'active',
    'vercel',
    '{}'::jsonb,
    '{"kind":"primary"}'::jsonb
  )
  ON CONFLICT (project_id, domain) DO UPDATE
    SET environment_id = EXCLUDED.environment_id,
        status = EXCLUDED.status,
        provider = EXCLUDED.provider,
        verification = EXCLUDED.verification,
        metadata = EXCLUDED.metadata,
        updated_at = now();

  INSERT INTO public.project_previews (project_id, environment_id, kind, url, is_primary, metadata)
  SELECT v_project_id, v_dev_environment_id, 'vercel', 'https://evidence-gmtm-next.vercel.app', true, '{"channel":"preview"}'::jsonb
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.project_previews
    WHERE project_id = v_project_id
      AND url = 'https://evidence-gmtm-next.vercel.app'
  );

  INSERT INTO public.project_plugins (project_id, environment_id, plugin_key, status, config)
  VALUES
    (v_project_id, v_dev_environment_id, 'core.auth', 'active', '{"mode":"supabase"}'::jsonb),
    (v_project_id, v_dev_environment_id, 'media.storage', 'active', '{"provider":"supabase-storage"}'::jsonb),
    (v_project_id, v_dev_environment_id, 'mail.ingestion', 'active', '{"provider":"gmail"}'::jsonb),
    (v_project_id, v_dev_environment_id, 'ai.generation', 'active', '{"provider":"openai"}'::jsonb),
    (v_project_id, v_dev_environment_id, 'evidence.ui', 'active', '{"source":"database"}'::jsonb)
  ON CONFLICT (project_id, environment_id, plugin_key) DO UPDATE
    SET status = EXCLUDED.status,
        config = EXCLUDED.config,
        updated_at = now();

  INSERT INTO public.feature_state_overrides (feature_key, tenant_id, project_id, environment_id, status, updated_by)
  VALUES
    ('evidence.timeline.workspace', null, v_project_id, null, 'active', v_user_id),
    ('evidence.inconsistency.analysis', null, v_project_id, null, 'active', v_user_id)
  ON CONFLICT ON CONSTRAINT uq_feature_state_override DO UPDATE
    SET status = EXCLUDED.status,
        updated_by = EXCLUDED.updated_by,
        updated_at = now();

  INSERT INTO public.config_overrides (key, tenant_id, project_id, environment_id, value, updated_by)
  VALUES
    ('project.app.definitionId', null, v_project_id, null, '"app_evidence"'::jsonb, v_user_id),
    ('project.site.primaryDomain', null, v_project_id, null, '"evidence.dreamlab.solutions"'::jsonb, v_user_id),
    ('project.i18n.defaultLocale', null, v_project_id, null, '"en"'::jsonb, v_user_id)
  ON CONFLICT ON CONSTRAINT uq_config_override DO UPDATE
    SET value = EXCLUDED.value,
        updated_by = EXCLUDED.updated_by,
        updated_at = now();

  INSERT INTO public.feature_flag_overrides (project_id, environment_id, tenant_id, flag_key, value)
  VALUES
    (v_project_id, v_dev_environment_id, null, 'evidence.workspace', true),
    (v_project_id, v_dev_environment_id, null, 'evidence.analysis', true),
    (v_project_id, v_dev_environment_id, null, 'project.sync.materialization', true),
    (v_project_id, v_dev_environment_id, null, 'project.sync.inbound', true)
  ON CONFLICT ON CONSTRAINT uq_flag_override DO UPDATE
    SET value = EXCLUDED.value,
        updated_at = now();

  INSERT INTO public.tenant_entitlements (tenant_id, project_id, environment_id, key, value, source)
  VALUES
    (v_tenant_id, v_project_id, null, 'project.app.access', '{"enabled":true,"appId":"app_evidence"}'::jsonb, 'system'),
    (v_tenant_id, v_project_id, null, 'project.repo.tracked_branches', '{"dev":"develop","stage":"stage","prod":"main"}'::jsonb, 'system')
  ON CONFLICT (tenant_id, project_id, environment_id, key) DO UPDATE
    SET value = EXCLUDED.value,
        source = EXCLUDED.source,
        updated_at = now();

  INSERT INTO public.app_definitions (
    id,
    name,
    description,
    icon_key,
    color,
    project_id,
    workspace_path,
    version,
    schema_checksum,
    source_commit_sha,
    metadata
  )
  VALUES (
    'app_evidence',
    'Evidence Management',
    'Timeline and analysis workspace for legal evidence review.',
    'Scale',
    '#f97316',
    v_project_id,
    'apps/evidence-mgmt-next',
    '1.0.0',
    'app-evidence-v1',
    'workspace',
    '{"materializationPath":"apps/evidence-mgmt-next/.dreamlab/app-definition.json"}'::jsonb
  )
  ON CONFLICT (id) DO UPDATE
    SET name = EXCLUDED.name,
        description = EXCLUDED.description,
        icon_key = EXCLUDED.icon_key,
        color = EXCLUDED.color,
        project_id = EXCLUDED.project_id,
        workspace_path = EXCLUDED.workspace_path,
        version = EXCLUDED.version,
        schema_checksum = EXCLUDED.schema_checksum,
        source_commit_sha = EXCLUDED.source_commit_sha,
        metadata = EXCLUDED.metadata;

  INSERT INTO public.project_app_bindings (
    project_id,
    environment_id,
    app_id,
    status,
    pinned_version,
    source_commit_sha,
    metadata
  )
  VALUES (
    v_project_id,
    null,
    'app_evidence',
    'active',
    '1.0.0',
    'seed-reset-2026-03-12',
    '{"workspacePath":"apps/evidence-mgmt-next"}'::jsonb
  )
  ON CONFLICT (project_id, app_id) DO UPDATE
    SET status = EXCLUDED.status,
        environment_id = EXCLUDED.environment_id,
        pinned_version = EXCLUDED.pinned_version,
        source_commit_sha = EXCLUDED.source_commit_sha,
        metadata = EXCLUDED.metadata,
        updated_at = now();

  INSERT INTO public.project_repo_reconciliations (
    project_id,
    environment_id,
    artifact_kind,
    tracked_branch,
    canonical_source,
    inbound_sync_policy,
    drift_status,
    metadata
  )
  VALUES
    (v_project_id, v_dev_environment_id, 'routing', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, v_dev_environment_id, 'composition', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, v_dev_environment_id, 'app_definition', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, v_dev_environment_id, 'registry', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next","artifactPath":"apps/evidence-mgmt-next/.dreamlab/registry.json"}'::jsonb),
    (v_project_id, v_dev_environment_id, 'package_registry', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next","artifactPath":"apps/evidence-mgmt-next/.dreamlab/packages.json"}'::jsonb),
    (v_project_id, v_dev_environment_id, 'content_models', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next","artifactPath":"apps/evidence-mgmt-next/.dreamlab/content-models.json"}'::jsonb),
    (v_project_id, v_dev_environment_id, 'version_pins', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next","artifactPath":"apps/evidence-mgmt-next/.dreamlab/version-pins.json"}'::jsonb),
    (v_project_id, v_stage_environment_id, 'routing', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, v_stage_environment_id, 'composition', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, v_stage_environment_id, 'app_definition', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, v_stage_environment_id, 'registry', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next","artifactPath":"apps/evidence-mgmt-next/.dreamlab/registry.json"}'::jsonb),
    (v_project_id, v_stage_environment_id, 'package_registry', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next","artifactPath":"apps/evidence-mgmt-next/.dreamlab/packages.json"}'::jsonb),
    (v_project_id, v_stage_environment_id, 'content_models', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next","artifactPath":"apps/evidence-mgmt-next/.dreamlab/content-models.json"}'::jsonb),
    (v_project_id, v_stage_environment_id, 'version_pins', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next","artifactPath":"apps/evidence-mgmt-next/.dreamlab/version-pins.json"}'::jsonb),
    (v_project_id, v_prod_environment_id, 'routing', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, v_prod_environment_id, 'composition', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, v_prod_environment_id, 'app_definition', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next"}'::jsonb),
    (v_project_id, v_prod_environment_id, 'registry', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next","artifactPath":"apps/evidence-mgmt-next/.dreamlab/registry.json"}'::jsonb),
    (v_project_id, v_prod_environment_id, 'package_registry', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next","artifactPath":"apps/evidence-mgmt-next/.dreamlab/packages.json"}'::jsonb),
    (v_project_id, v_prod_environment_id, 'content_models', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next","artifactPath":"apps/evidence-mgmt-next/.dreamlab/content-models.json"}'::jsonb),
    (v_project_id, v_prod_environment_id, 'version_pins', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/evidence-mgmt-next","artifactPath":"apps/evidence-mgmt-next/.dreamlab/version-pins.json"}'::jsonb)
  ON CONFLICT (project_id, environment_id, artifact_kind) DO UPDATE
    SET tracked_branch = EXCLUDED.tracked_branch,
        canonical_source = EXCLUDED.canonical_source,
        inbound_sync_policy = EXCLUDED.inbound_sync_policy,
        drift_status = EXCLUDED.drift_status,
        metadata = EXCLUDED.metadata,
        updated_at = now();

  INSERT INTO public.routing_nodes (project_id, node_id, key, kind, segment_key, parent_node_id, position, config)
  VALUES
    (v_project_id, 'root', 'root', 'group', '', null, 0, '{}'::jsonb),
    (v_project_id, 'workspace', 'evidence.workspace', 'page', 'evidence', 'root', 0, '{}'::jsonb),
    (v_project_id, 'timeline', 'evidence.timeline', 'page', 'timeline', 'workspace', 0, '{}'::jsonb),
    (v_project_id, 'analysis', 'evidence.analysis', 'page', 'analysis', 'workspace', 1, '{}'::jsonb),
    (v_project_id, 'import', 'evidence.import', 'page', 'import', 'workspace', 2, '{}'::jsonb)
  ON CONFLICT (project_id, node_id) DO UPDATE
    SET key = EXCLUDED.key,
        kind = EXCLUDED.kind,
        segment_key = EXCLUDED.segment_key,
        parent_node_id = EXCLUDED.parent_node_id,
        position = EXCLUDED.position,
        config = EXCLUDED.config;

  INSERT INTO public.routing_locale_mappings (project_id, locale, node_id, translated_segment)
  VALUES
    (v_project_id, 'en', 'root', ''),
    (v_project_id, 'en', 'workspace', 'evidence'),
    (v_project_id, 'en', 'timeline', 'timeline'),
    (v_project_id, 'en', 'analysis', 'analysis'),
    (v_project_id, 'en', 'import', 'import'),
    (v_project_id, 'it', 'root', ''),
    (v_project_id, 'it', 'workspace', 'evidence'),
    (v_project_id, 'it', 'timeline', 'timeline'),
    (v_project_id, 'it', 'analysis', 'analisi'),
    (v_project_id, 'it', 'import', 'importa')
  ON CONFLICT (project_id, locale, node_id) DO UPDATE
    SET translated_segment = EXCLUDED.translated_segment;

  INSERT INTO public.content_model_definitions (
    key,
    package_key,
    name,
    description,
    category,
    kind,
    has_draft_and_publish,
    has_i18n,
    fields,
    latest_version,
    latest_schema_checksum,
    latest_source_commit_sha,
    metadata
  )
  VALUES
    ('evidence.dashboard.copy', 'pkg.dls-evidence-bff', 'Evidence Dashboard Copy', 'Localized copy catalog for the evidence workspace dashboard.', 'copy', 'single', true, true, '[{"key":"copy","label":"Copy Catalog","type":"json","required":true,"translatable":true}]'::jsonb, '1.0.0', 'chk_evidence_dashboard_copy_1_0_0', 'seed-reset-2026-03-12', '{"family":"evidence"}'::jsonb),
    ('evidence.ui.case.page', 'pkg.dls-evidence-bff', 'Evidence Case Page', 'Case detail page contract.', 'page', 'single', true, true, '[{"key":"page","label":"Page","type":"component","required":true},{"key":"states","label":"States","type":"component"},{"key":"labels","label":"Labels","type":"component"}]'::jsonb, '1.0.0', 'chk_evidence_ui_case_page_1_0_0', 'seed-reset-2026-03-12', '{"family":"evidence-ui"}'::jsonb),
    ('evidence.ui.timeline.page', 'pkg.dls-evidence-bff', 'Evidence Timeline Page', 'Timeline page contract.', 'page', 'single', true, true, '[{"key":"page","label":"Page","type":"component","required":true},{"key":"states","label":"States","type":"component"},{"key":"labels","label":"Labels","type":"component"}]'::jsonb, '1.0.0', 'chk_evidence_ui_timeline_page_1_0_0', 'seed-reset-2026-03-12', '{"family":"evidence-ui"}'::jsonb),
    ('evidence.ui.event.page', 'pkg.dls-evidence-bff', 'Evidence Event Page', 'Event detail page contract.', 'page', 'single', true, true, '[{"key":"page","label":"Page","type":"component","required":true},{"key":"states","label":"States","type":"component"},{"key":"labels","label":"Labels","type":"component"}]'::jsonb, '1.0.0', 'chk_evidence_ui_event_page_1_0_0', 'seed-reset-2026-03-12', '{"family":"evidence-ui"}'::jsonb),
    ('evidence.ui.artifact.page', 'pkg.dls-evidence-bff', 'Evidence Artifact Page', 'Artifact page contract.', 'page', 'single', true, true, '[{"key":"page","label":"Page","type":"component","required":true},{"key":"states","label":"States","type":"component"},{"key":"labels","label":"Labels","type":"component"},{"key":"types","label":"Artifact Types","type":"component"}]'::jsonb, '1.0.0', 'chk_evidence_ui_artifact_page_1_0_0', 'seed-reset-2026-03-12', '{"family":"evidence-ui"}'::jsonb),
    ('evidence.ui.evidence.page', 'pkg.dls-evidence-bff', 'Evidence Detail Page', 'Evidence detail page contract.', 'page', 'single', true, true, '[{"key":"page","label":"Page","type":"component","required":true},{"key":"states","label":"States","type":"component"},{"key":"labels","label":"Labels","type":"component"}]'::jsonb, '1.0.0', 'chk_evidence_ui_evidence_page_1_0_0', 'seed-reset-2026-03-12', '{"family":"evidence-ui"}'::jsonb),
    ('evidence.ui.claim.page', 'pkg.dls-evidence-bff', 'Evidence Claim Page', 'Claim page contract.', 'page', 'single', true, true, '[{"key":"page","label":"Page","type":"component","required":true},{"key":"states","label":"States","type":"component"},{"key":"labels","label":"Labels","type":"component"},{"key":"status","label":"Status","type":"component"},{"key":"relations","label":"Relations","type":"component"}]'::jsonb, '1.0.0', 'chk_evidence_ui_claim_page_1_0_0', 'seed-reset-2026-03-12', '{"family":"evidence-ui"}'::jsonb),
    ('meta.seo', 'pkg.dls-api-core', 'SEO Meta', 'Search metadata contract.', 'meta', 'single', true, true, '[{"key":"title","label":"Meta Title","type":"text","translatable":true},{"key":"description","label":"Meta Description","type":"text","translatable":true},{"key":"canonical_url","label":"Canonical URL","type":"text"},{"key":"robots","label":"Robots","type":"text"}]'::jsonb, '1.1.0', 'chk_meta_seo_1_1_0', 'seed-reset-2026-03-12', '{"family":"meta"}'::jsonb),
    ('meta.aeo', 'pkg.dls-api-core', 'AEO Meta', 'Answer-engine metadata contract.', 'meta', 'single', true, true, '[{"key":"summary","label":"Answer Summary","type":"textarea","translatable":true},{"key":"faq","label":"FAQ Payload","type":"json","translatable":true}]'::jsonb, '1.0.0', 'chk_meta_aeo_1_0_0', 'seed-reset-2026-03-12', '{"family":"meta"}'::jsonb),
    ('meta.geo', 'pkg.dls-api-core', 'GEO Meta', 'Geo-targeting metadata contract.', 'meta', 'single', true, true, '[{"key":"region","label":"Region","type":"text","translatable":true},{"key":"coordinates","label":"Coordinates","type":"json"}]'::jsonb, '1.0.0', 'chk_meta_geo_1_0_0', 'seed-reset-2026-03-12', '{"family":"meta"}'::jsonb)
  ON CONFLICT (key) DO UPDATE
    SET package_key = EXCLUDED.package_key,
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        category = EXCLUDED.category,
        kind = EXCLUDED.kind,
        has_draft_and_publish = EXCLUDED.has_draft_and_publish,
        has_i18n = EXCLUDED.has_i18n,
        fields = EXCLUDED.fields,
        latest_version = EXCLUDED.latest_version,
        latest_schema_checksum = EXCLUDED.latest_schema_checksum,
        latest_source_commit_sha = EXCLUDED.latest_source_commit_sha,
        metadata = EXCLUDED.metadata;

  INSERT INTO public.content_model_versions (
    definition_key,
    version,
    schema_checksum,
    source_commit_sha,
    change_kind,
    fields,
    metadata
  )
  VALUES
    ('evidence.dashboard.copy', '1.0.0', 'chk_evidence_dashboard_copy_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"copy","label":"Copy Catalog","type":"json","required":true,"translatable":true}]'::jsonb, '{"seed":"evidence-mgmt"}'::jsonb),
    ('evidence.ui.case.page', '1.0.0', 'chk_evidence_ui_case_page_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"page","label":"Page","type":"component","required":true},{"key":"states","label":"States","type":"component"},{"key":"labels","label":"Labels","type":"component"}]'::jsonb, '{"seed":"evidence-mgmt"}'::jsonb),
    ('evidence.ui.timeline.page', '1.0.0', 'chk_evidence_ui_timeline_page_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"page","label":"Page","type":"component","required":true},{"key":"states","label":"States","type":"component"},{"key":"labels","label":"Labels","type":"component"}]'::jsonb, '{"seed":"evidence-mgmt"}'::jsonb),
    ('evidence.ui.event.page', '1.0.0', 'chk_evidence_ui_event_page_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"page","label":"Page","type":"component","required":true},{"key":"states","label":"States","type":"component"},{"key":"labels","label":"Labels","type":"component"}]'::jsonb, '{"seed":"evidence-mgmt"}'::jsonb),
    ('evidence.ui.artifact.page', '1.0.0', 'chk_evidence_ui_artifact_page_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"page","label":"Page","type":"component","required":true},{"key":"states","label":"States","type":"component"},{"key":"labels","label":"Labels","type":"component"},{"key":"types","label":"Artifact Types","type":"component"}]'::jsonb, '{"seed":"evidence-mgmt"}'::jsonb),
    ('evidence.ui.evidence.page', '1.0.0', 'chk_evidence_ui_evidence_page_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"page","label":"Page","type":"component","required":true},{"key":"states","label":"States","type":"component"},{"key":"labels","label":"Labels","type":"component"}]'::jsonb, '{"seed":"evidence-mgmt"}'::jsonb),
    ('evidence.ui.claim.page', '1.0.0', 'chk_evidence_ui_claim_page_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"page","label":"Page","type":"component","required":true},{"key":"states","label":"States","type":"component"},{"key":"labels","label":"Labels","type":"component"},{"key":"status","label":"Status","type":"component"},{"key":"relations","label":"Relations","type":"component"}]'::jsonb, '{"seed":"evidence-mgmt"}'::jsonb),
    ('meta.seo', '1.0.0', 'chk_meta_seo_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"title","label":"Meta Title","type":"text","translatable":true},{"key":"description","label":"Meta Description","type":"text","translatable":true},{"key":"canonical_url","label":"Canonical URL","type":"text"}]'::jsonb, '{"seed":"evidence-mgmt"}'::jsonb),
    ('meta.seo', '1.1.0', 'chk_meta_seo_1_1_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"title","label":"Meta Title","type":"text","translatable":true},{"key":"description","label":"Meta Description","type":"text","translatable":true},{"key":"canonical_url","label":"Canonical URL","type":"text"},{"key":"robots","label":"Robots","type":"text"}]'::jsonb, '{"seed":"evidence-mgmt"}'::jsonb),
    ('meta.aeo', '1.0.0', 'chk_meta_aeo_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"summary","label":"Answer Summary","type":"textarea","translatable":true},{"key":"faq","label":"FAQ Payload","type":"json","translatable":true}]'::jsonb, '{"seed":"evidence-mgmt"}'::jsonb),
    ('meta.geo', '1.0.0', 'chk_meta_geo_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"region","label":"Region","type":"text","translatable":true},{"key":"coordinates","label":"Coordinates","type":"json"}]'::jsonb, '{"seed":"evidence-mgmt"}'::jsonb)
  ON CONFLICT (definition_key, version) DO UPDATE
    SET schema_checksum = EXCLUDED.schema_checksum,
        source_commit_sha = EXCLUDED.source_commit_sha,
        change_kind = EXCLUDED.change_kind,
        fields = EXCLUDED.fields,
        metadata = EXCLUDED.metadata;

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
    fields,
    definition_key,
    canonical_key,
    pinned_version,
    schema_checksum,
    source_commit_sha,
    source_package_key,
    inheritance_mode,
    adoption_status
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
    ]'::jsonb,
    'evidence.dashboard.copy',
    'evidence.dashboard.copy',
    '1.0.0',
    'chk_evidence_dashboard_copy_1_0_0',
    'seed-reset-2026-03-12',
    'pkg.dls-evidence-bff',
    'owned',
    'aligned'
  )
  ON CONFLICT (project_id, uid) DO UPDATE
    SET name = EXCLUDED.name,
        kind = EXCLUDED.kind,
        has_draft_and_publish = EXCLUDED.has_draft_and_publish,
        has_i18n = EXCLUDED.has_i18n,
        fields = EXCLUDED.fields,
        definition_key = EXCLUDED.definition_key,
        canonical_key = EXCLUDED.canonical_key,
        pinned_version = EXCLUDED.pinned_version,
        schema_checksum = EXCLUDED.schema_checksum,
        source_commit_sha = EXCLUDED.source_commit_sha,
        source_package_key = EXCLUDED.source_package_key,
        inheritance_mode = EXCLUDED.inheritance_mode,
        adoption_status = EXCLUDED.adoption_status;

  INSERT INTO public.content_models (
    project_id,
    uid,
    name,
    kind,
    has_draft_and_publish,
    has_i18n,
    fields,
    definition_key,
    canonical_key,
    pinned_version,
    schema_checksum,
    source_commit_sha,
    source_package_key,
    inheritance_mode,
    adoption_status
  )
  VALUES
    (v_project_id, 'meta.seo', 'SEO Meta', 'single', true, true, '[{"key":"title","label":"Meta Title","type":"text","translatable":true},{"key":"description","label":"Meta Description","type":"text","translatable":true},{"key":"canonical_url","label":"Canonical URL","type":"text"},{"key":"robots","label":"Robots","type":"text"}]'::jsonb, 'meta.seo', 'meta.seo', '1.0.0', 'chk_meta_seo_1_0_0', 'seed-reset-2026-03-12', 'pkg.dls-api-core', 'inherited', 'update_available'),
    (v_project_id, 'meta.aeo', 'AEO Meta', 'single', true, true, '[{"key":"summary","label":"Answer Summary","type":"textarea","translatable":true},{"key":"faq","label":"FAQ Payload","type":"json","translatable":true}]'::jsonb, 'meta.aeo', 'meta.aeo', '1.0.0', 'chk_meta_aeo_1_0_0', 'seed-reset-2026-03-12', 'pkg.dls-api-core', 'inherited', 'aligned'),
    (v_project_id, 'meta.geo', 'GEO Meta', 'single', true, true, '[{"key":"region","label":"Region","type":"text","translatable":true},{"key":"coordinates","label":"Coordinates","type":"json"}]'::jsonb, 'meta.geo', 'meta.geo', '1.0.0', 'chk_meta_geo_1_0_0', 'seed-reset-2026-03-12', 'pkg.dls-api-core', 'disabled', 'disabled')
  ON CONFLICT (project_id, uid) DO UPDATE
    SET name = EXCLUDED.name,
        kind = EXCLUDED.kind,
        has_draft_and_publish = EXCLUDED.has_draft_and_publish,
        has_i18n = EXCLUDED.has_i18n,
        fields = EXCLUDED.fields,
        definition_key = EXCLUDED.definition_key,
        canonical_key = EXCLUDED.canonical_key,
        pinned_version = EXCLUDED.pinned_version,
        schema_checksum = EXCLUDED.schema_checksum,
        source_commit_sha = EXCLUDED.source_commit_sha,
        source_package_key = EXCLUDED.source_package_key,
        inheritance_mode = EXCLUDED.inheritance_mode,
        adoption_status = EXCLUDED.adoption_status;

  UPDATE public.content_models
  SET definition_key = mapping.definition_key,
      canonical_key = mapping.definition_key,
      pinned_version = '1.0.0',
      schema_checksum = mapping.schema_checksum,
      source_commit_sha = 'seed-reset-2026-03-12',
      source_package_key = 'pkg.dls-evidence-bff',
      inheritance_mode = 'owned',
      adoption_status = 'aligned'
  FROM (
    VALUES
      ('evidence.ui.case.page', 'chk_evidence_ui_case_page_1_0_0'),
      ('evidence.ui.timeline.page', 'chk_evidence_ui_timeline_page_1_0_0'),
      ('evidence.ui.event.page', 'chk_evidence_ui_event_page_1_0_0'),
      ('evidence.ui.artifact.page', 'chk_evidence_ui_artifact_page_1_0_0'),
      ('evidence.ui.evidence.page', 'chk_evidence_ui_evidence_page_1_0_0'),
      ('evidence.ui.claim.page', 'chk_evidence_ui_claim_page_1_0_0')
  ) as mapping(definition_key, schema_checksum)
  WHERE public.content_models.project_id = v_project_id
    AND public.content_models.uid = mapping.definition_key;

  INSERT INTO public.project_model_contracts (
    project_id,
    consumer_model_uid,
    contract_role,
    contract_definition_key,
    provider_model_uid,
    provider_package_key,
    inheritance_mode,
    pinned_version,
    inherited_version,
    is_enabled,
    schema_checksum,
    source_commit_sha,
    metadata
  )
  VALUES
    (v_project_id, 'evidence.ui.case.page', 'seo', 'meta.seo', 'meta.seo', 'pkg.dls-api-core', 'inherited', '1.0.0', '1.1.0', true, 'chk_meta_seo_1_1_0', 'seed-reset-2026-03-12', '{"source":"seed"}'::jsonb),
    (v_project_id, 'evidence.ui.case.page', 'aeo', 'meta.aeo', 'meta.aeo', 'pkg.dls-api-core', 'inherited', '1.0.0', '1.0.0', true, 'chk_meta_aeo_1_0_0', 'seed-reset-2026-03-12', '{"source":"seed"}'::jsonb),
    (v_project_id, 'evidence.ui.case.page', 'geo', 'meta.geo', null, 'pkg.dls-api-core', 'disabled', null, '1.0.0', false, 'chk_meta_geo_1_0_0', 'seed-reset-2026-03-12', '{"source":"seed","reason":"not_applicable"}'::jsonb),
    (v_project_id, 'evidence.ui.timeline.page', 'seo', 'meta.seo', 'meta.seo', 'pkg.dls-api-core', 'inherited', '1.0.0', '1.1.0', true, 'chk_meta_seo_1_1_0', 'seed-reset-2026-03-12', '{"source":"seed"}'::jsonb),
    (v_project_id, 'evidence.ui.timeline.page', 'aeo', 'meta.aeo', 'meta.aeo', 'pkg.dls-api-core', 'inherited', '1.0.0', '1.0.0', true, 'chk_meta_aeo_1_0_0', 'seed-reset-2026-03-12', '{"source":"seed"}'::jsonb),
    (v_project_id, 'evidence.ui.timeline.page', 'geo', 'meta.geo', null, 'pkg.dls-api-core', 'disabled', null, '1.0.0', false, 'chk_meta_geo_1_0_0', 'seed-reset-2026-03-12', '{"source":"seed","reason":"not_applicable"}'::jsonb),
    (v_project_id, 'evidence.ui.event.page', 'seo', 'meta.seo', 'meta.seo', 'pkg.dls-api-core', 'inherited', '1.0.0', '1.1.0', true, 'chk_meta_seo_1_1_0', 'seed-reset-2026-03-12', '{"source":"seed"}'::jsonb),
    (v_project_id, 'evidence.ui.event.page', 'aeo', 'meta.aeo', 'meta.aeo', 'pkg.dls-api-core', 'inherited', '1.0.0', '1.0.0', true, 'chk_meta_aeo_1_0_0', 'seed-reset-2026-03-12', '{"source":"seed"}'::jsonb),
    (v_project_id, 'evidence.ui.event.page', 'geo', 'meta.geo', null, 'pkg.dls-api-core', 'disabled', null, '1.0.0', false, 'chk_meta_geo_1_0_0', 'seed-reset-2026-03-12', '{"source":"seed","reason":"not_applicable"}'::jsonb),
    (v_project_id, 'evidence.ui.artifact.page', 'seo', 'meta.seo', 'meta.seo', 'pkg.dls-api-core', 'inherited', '1.0.0', '1.1.0', true, 'chk_meta_seo_1_1_0', 'seed-reset-2026-03-12', '{"source":"seed"}'::jsonb),
    (v_project_id, 'evidence.ui.artifact.page', 'aeo', 'meta.aeo', 'meta.aeo', 'pkg.dls-api-core', 'inherited', '1.0.0', '1.0.0', true, 'chk_meta_aeo_1_0_0', 'seed-reset-2026-03-12', '{"source":"seed"}'::jsonb),
    (v_project_id, 'evidence.ui.artifact.page', 'geo', 'meta.geo', null, 'pkg.dls-api-core', 'disabled', null, '1.0.0', false, 'chk_meta_geo_1_0_0', 'seed-reset-2026-03-12', '{"source":"seed","reason":"not_applicable"}'::jsonb),
    (v_project_id, 'evidence.ui.evidence.page', 'seo', 'meta.seo', 'meta.seo', 'pkg.dls-api-core', 'inherited', '1.0.0', '1.1.0', true, 'chk_meta_seo_1_1_0', 'seed-reset-2026-03-12', '{"source":"seed"}'::jsonb),
    (v_project_id, 'evidence.ui.evidence.page', 'aeo', 'meta.aeo', 'meta.aeo', 'pkg.dls-api-core', 'inherited', '1.0.0', '1.0.0', true, 'chk_meta_aeo_1_0_0', 'seed-reset-2026-03-12', '{"source":"seed"}'::jsonb),
    (v_project_id, 'evidence.ui.evidence.page', 'geo', 'meta.geo', null, 'pkg.dls-api-core', 'disabled', null, '1.0.0', false, 'chk_meta_geo_1_0_0', 'seed-reset-2026-03-12', '{"source":"seed","reason":"not_applicable"}'::jsonb),
    (v_project_id, 'evidence.ui.claim.page', 'seo', 'meta.seo', 'meta.seo', 'pkg.dls-api-core', 'inherited', '1.0.0', '1.1.0', true, 'chk_meta_seo_1_1_0', 'seed-reset-2026-03-12', '{"source":"seed"}'::jsonb),
    (v_project_id, 'evidence.ui.claim.page', 'aeo', 'meta.aeo', 'meta.aeo', 'pkg.dls-api-core', 'inherited', '1.0.0', '1.0.0', true, 'chk_meta_aeo_1_0_0', 'seed-reset-2026-03-12', '{"source":"seed"}'::jsonb),
    (v_project_id, 'evidence.ui.claim.page', 'geo', 'meta.geo', null, 'pkg.dls-api-core', 'disabled', null, '1.0.0', false, 'chk_meta_geo_1_0_0', 'seed-reset-2026-03-12', '{"source":"seed","reason":"not_applicable"}'::jsonb)
  ON CONFLICT (project_id, consumer_model_uid, contract_role) DO UPDATE
    SET contract_definition_key = EXCLUDED.contract_definition_key,
        provider_model_uid = EXCLUDED.provider_model_uid,
        provider_package_key = EXCLUDED.provider_package_key,
        inheritance_mode = EXCLUDED.inheritance_mode,
        pinned_version = EXCLUDED.pinned_version,
        inherited_version = EXCLUDED.inherited_version,
        is_enabled = EXCLUDED.is_enabled,
        schema_checksum = EXCLUDED.schema_checksum,
        source_commit_sha = EXCLUDED.source_commit_sha,
        metadata = EXCLUDED.metadata;

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
    $dashboard_copy$
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
    }$dashboard_copy$::jsonb
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
