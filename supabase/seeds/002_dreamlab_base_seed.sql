-- =============================================================================
-- DreamLab Solutions Canonical Base Seed
-- =============================================================================
-- Seeds the canonical local bootstrap for the DreamLab Solutions tenant:
-- - platform registry + project mappings
-- - project repo/domain/preview metadata
-- - hub + website app composition
-- - routing/config/feature bindings
-- - DB-backed hub + website copy catalogs
--
-- This file is the operational source of truth for local resets of the main
-- DreamLab tenant. Evidence remains isolated in 003_evidence_mgmt_seed.sql.
-- =============================================================================

DO $$
DECLARE
  v_admin_email text := 'info@dreamlab.solutions';
  v_user_id uuid;
  v_tenant_id uuid;
  v_hub_project_id uuid;
  v_website_project_id uuid;
  v_hub_dev_environment_id uuid;
  v_hub_stage_environment_id uuid;
  v_hub_prod_environment_id uuid;
  v_website_dev_environment_id uuid;
  v_website_stage_environment_id uuid;
  v_website_prod_environment_id uuid;
  v_platform_id uuid;
  v_hub_copy_entry_id uuid := '66666666-6666-4666-8666-666666666666'::uuid;
  v_website_copy_entry_id uuid := '77777777-7777-4777-8777-777777777777'::uuid;
  v_website_home_entry_id uuid := '88888888-8888-4888-8888-888888888888'::uuid;
BEGIN
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE lower(email) = lower(v_admin_email)
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Missing admin user (%). Run 001_admin_user.sql first.', v_admin_email;
  END IF;

  SELECT id INTO v_tenant_id
  FROM public.tenants
  WHERE slug = 'dreamlab-solutions'
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Missing tenant dreamlab-solutions. Run 001_admin_user.sql first.';
  END IF;

  SELECT id INTO v_hub_project_id
  FROM public.projects
  WHERE tenant_id = v_tenant_id
    AND slug = 'dls-platform-hub-next'
  LIMIT 1;

  SELECT id INTO v_website_project_id
  FROM public.projects
  WHERE tenant_id = v_tenant_id
    AND slug = 'dls-website-astro'
  LIMIT 1;

  IF v_hub_project_id IS NULL OR v_website_project_id IS NULL THEN
    RAISE EXCEPTION 'Missing DreamLab projects. Run 001_admin_user.sql first.';
  END IF;

  SELECT id INTO v_hub_dev_environment_id
  FROM public.environments
  WHERE project_id = v_hub_project_id
    AND key = 'dev'
  LIMIT 1;

  SELECT id INTO v_website_dev_environment_id
  FROM public.environments
  WHERE project_id = v_website_project_id
    AND key = 'dev'
  LIMIT 1;

  SELECT id INTO v_hub_stage_environment_id
  FROM public.environments
  WHERE project_id = v_hub_project_id
    AND key = 'stage'
  LIMIT 1;

  SELECT id INTO v_hub_prod_environment_id
  FROM public.environments
  WHERE project_id = v_hub_project_id
    AND key = 'prod'
  LIMIT 1;

  SELECT id INTO v_website_stage_environment_id
  FROM public.environments
  WHERE project_id = v_website_project_id
    AND key = 'stage'
  LIMIT 1;

  SELECT id INTO v_website_prod_environment_id
  FROM public.environments
  WHERE project_id = v_website_project_id
    AND key = 'prod'
  LIMIT 1;

  -- ---------------------------------------------------------------------------
  -- 1) Canonical platform and project mappings
  -- ---------------------------------------------------------------------------
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
    'DreamLab Solutions',
    'dreamlab-solutions',
    'Canonical DreamLab platform containing the hub and public website projects.',
    'https://dreamlab.solutions',
    true,
    'active',
    ARRAY['platform-hub', 'public-website', 'cms', 'i18n', 'auth']
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
    WHERE slug = 'dreamlab-solutions'
    LIMIT 1;
  END IF;

  DELETE FROM public.platform_links
  WHERE tenant_id = v_tenant_id
    AND path IN ('/', '/hub');

  INSERT INTO public.platform_links (tenant_id, platform_id, path, target_url, is_visible, clicks)
  VALUES
    (v_tenant_id, v_platform_id, '/', 'https://dreamlab.solutions', true, 0),
    (v_tenant_id, v_platform_id, '/hub', 'https://hub.dreamlab.solutions', true, 0);

  DELETE FROM public.platform_subscriptions
  WHERE tenant_id = v_tenant_id
    AND platform_id = v_platform_id;

  INSERT INTO public.platform_subscriptions (
    tenant_id,
    platform_id,
    plan_id,
    status
  )
  VALUES (
    v_tenant_id,
    v_platform_id,
    'dreamlab-internal',
    'active'
  );

  INSERT INTO public.platform_project_mappings (platform_id, project_id)
  VALUES
    (v_platform_id, v_hub_project_id),
    (v_platform_id, v_website_project_id)
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
    (
      'pkg.dls-api-core',
      '@dreamlab-solutions/dls-api-core',
      'packages/dls-api-core',
      'platform',
      'core',
      'Canonical shared contracts, adapters, and use cases.',
      'dreamlab-solutions/dreamlab',
      '0.1.0',
      'chk_dls_api_core_0_1_0',
      'seed-reset-2026-03-12',
      '{"owner":"core-platform"}'::jsonb
    ),
    (
      'pkg.dls-domain',
      '@dreamlab-solutions/dls-domain',
      'packages/dls-domain',
      'platform',
      'domain',
      'Shared cross-package domain primitives.',
      'dreamlab-solutions/dreamlab',
      '0.1.0',
      'chk_dls_domain_0_1_0',
      'seed-reset-2026-03-12',
      '{"owner":"core-platform"}'::jsonb
    ),
    (
      'pkg.dls-ui-react',
      '@dreamlab-solutions/dls-ui-react',
      'packages/dls-ui-react',
      'design-system',
      'ui',
      'Reusable shared React components.',
      'dreamlab-solutions/dreamlab',
      '0.1.0',
      'chk_dls_ui_react_0_1_0',
      'seed-reset-2026-03-12',
      '{"owner":"design-system"}'::jsonb
    ),
    (
      'pkg.dls-theme',
      '@dreamlab-solutions/dls-theme',
      'packages/dls-theme',
      'design-system',
      'theme',
      'Shared design tokens and CSS contracts.',
      'dreamlab-solutions/dreamlab',
      '0.1.0',
      'chk_dls_theme_0_1_0',
      'seed-reset-2026-03-12',
      '{"owner":"design-system"}'::jsonb
    ),
    (
      'pkg.dls-ui-astro',
      '@dreamlab-solutions/dls-ui-astro',
      'packages/dls-ui-astro',
      'design-system',
      'ui',
      'Reusable Astro components for the public website renderer.',
      'dreamlab-solutions/dreamlab',
      '0.1.0',
      'chk_dls_ui_astro_0_1_0',
      'seed-reset-2026-03-12',
      '{"owner":"design-system"}'::jsonb
    )
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
    (v_hub_project_id, 'pkg.dls-api-core', 'core_dependency', '{"workspace":"apps/dls-platform-hub-next"}'::jsonb),
    (v_hub_project_id, 'pkg.dls-domain', 'core_dependency', '{"workspace":"apps/dls-platform-hub-next"}'::jsonb),
    (v_hub_project_id, 'pkg.dls-ui-react', 'ui_dependency', '{"workspace":"apps/dls-platform-hub-next"}'::jsonb),
    (v_hub_project_id, 'pkg.dls-theme', 'ui_dependency', '{"workspace":"apps/dls-platform-hub-next"}'::jsonb),
    (v_website_project_id, 'pkg.dls-api-core', 'core_dependency', '{"workspace":"apps/dls-webapp-astro"}'::jsonb),
    (v_website_project_id, 'pkg.dls-domain', 'core_dependency', '{"workspace":"apps/dls-webapp-astro"}'::jsonb),
    (v_website_project_id, 'pkg.dls-theme', 'ui_dependency', '{"workspace":"apps/dls-webapp-astro"}'::jsonb),
    (v_website_project_id, 'pkg.dls-ui-astro', 'ui_dependency', '{"workspace":"apps/dls-webapp-astro"}'::jsonb)
  ON CONFLICT (project_id, package_key) DO UPDATE
    SET relationship = EXCLUDED.relationship,
        metadata = EXCLUDED.metadata;

  INSERT INTO public.app_package_bindings (app_id, package_key, role, metadata)
  VALUES
    ('app_platform_hub', 'pkg.dls-api-core', 'core', '{"workspace":"apps/dls-platform-hub-next"}'::jsonb),
    ('app_platform_hub', 'pkg.dls-ui-react', 'ui', '{"workspace":"apps/dls-platform-hub-next"}'::jsonb),
    ('app_platform_hub', 'pkg.dls-theme', 'theme', '{"workspace":"apps/dls-platform-hub-next"}'::jsonb),
    ('app_dreamlab_website', 'pkg.dls-api-core', 'core', '{"workspace":"apps/dls-webapp-astro"}'::jsonb),
    ('app_dreamlab_website', 'pkg.dls-theme', 'theme', '{"workspace":"apps/dls-webapp-astro"}'::jsonb),
    ('app_dreamlab_website', 'pkg.dls-ui-astro', 'ui', '{"workspace":"apps/dls-webapp-astro"}'::jsonb)
  ON CONFLICT (app_id, package_key, role) DO UPDATE
    SET metadata = EXCLUDED.metadata;

  -- ---------------------------------------------------------------------------
  -- 3) Repo, preview, and domain metadata
  -- ---------------------------------------------------------------------------
  INSERT INTO public.project_repos (project_id, provider, owner, repo, default_branch, status, metadata)
  VALUES
    (
      v_hub_project_id,
      'github',
      'dreamlab-solutions',
      'dreamlab',
      'main',
      'connected',
      '{"workspacePath":"apps/dls-platform-hub-next","trackedBranches":{"dev":"develop","stage":"stage","prod":"main"},"artifactPaths":{"routing":"apps/dls-platform-hub-next/.dreamlab/routing.json","composition":"apps/dls-platform-hub-next/.dreamlab/composition.json","appDefinition":"apps/dls-platform-hub-next/.dreamlab/app-definition.json","registry":"apps/dls-platform-hub-next/.dreamlab/registry.json","contentModels":"apps/dls-platform-hub-next/.dreamlab/content-models.json","versionPins":"apps/dls-platform-hub-next/.dreamlab/version-pins.json","packages":"apps/dls-platform-hub-next/.dreamlab/packages.json"}}'::jsonb
    ),
    (
      v_website_project_id,
      'github',
      'dreamlab-solutions',
      'dreamlab',
      'main',
      'connected',
      '{"workspacePath":"apps/dls-webapp-astro","trackedBranches":{"dev":"develop","stage":"stage","prod":"main"},"artifactPaths":{"routing":"apps/dls-webapp-astro/.dreamlab/routing.json","composition":"apps/dls-webapp-astro/.dreamlab/composition.json","appDefinition":"apps/dls-webapp-astro/.dreamlab/app-definition.json","registry":"apps/dls-webapp-astro/.dreamlab/registry.json","contentModels":"apps/dls-webapp-astro/.dreamlab/content-models.json","versionPins":"apps/dls-webapp-astro/.dreamlab/version-pins.json","packages":"apps/dls-webapp-astro/.dreamlab/packages.json"}}'::jsonb
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
  VALUES
    (v_hub_project_id, v_hub_dev_environment_id, 'hub.dreamlab.solutions', 'active', 'vercel', '{}'::jsonb, '{"kind":"primary"}'::jsonb),
    (v_website_project_id, v_website_dev_environment_id, 'dreamlab.solutions', 'active', 'vercel', '{}'::jsonb, '{"kind":"primary"}'::jsonb),
    (v_website_project_id, v_website_dev_environment_id, 'www.dreamlab.solutions', 'active', 'vercel', '{}'::jsonb, '{"kind":"alias"}'::jsonb)
  ON CONFLICT (project_id, domain) DO UPDATE
    SET environment_id = EXCLUDED.environment_id,
        status = EXCLUDED.status,
        provider = EXCLUDED.provider,
        verification = EXCLUDED.verification,
        metadata = EXCLUDED.metadata,
        updated_at = now();

  INSERT INTO public.project_previews (project_id, environment_id, kind, url, is_primary, metadata)
  SELECT v_hub_project_id, v_hub_dev_environment_id, 'vercel', 'https://dls-platform-hub-next.vercel.app', true, '{"channel":"preview"}'::jsonb
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.project_previews
    WHERE project_id = v_hub_project_id
      AND url = 'https://dls-platform-hub-next.vercel.app'
  );

  INSERT INTO public.project_previews (project_id, environment_id, kind, url, is_primary, metadata)
  SELECT v_website_project_id, v_website_dev_environment_id, 'vercel', 'https://dls-website-astro.vercel.app', true, '{"channel":"preview"}'::jsonb
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.project_previews
    WHERE project_id = v_website_project_id
      AND url = 'https://dls-website-astro.vercel.app'
  );

  -- ---------------------------------------------------------------------------
  -- 4) Project plugin and implementation bindings
  -- ---------------------------------------------------------------------------
  INSERT INTO public.project_plugins (project_id, environment_id, plugin_key, status, config)
  VALUES
    (v_hub_project_id, v_hub_dev_environment_id, 'core.auth', 'active', '{"mode":"supabase"}'::jsonb),
    (v_hub_project_id, v_hub_dev_environment_id, 'core.cms', 'active', '{"source":"supabase"}'::jsonb),
    (v_hub_project_id, v_hub_dev_environment_id, 'i18n.runtime', 'active', '{"defaultLocale":"en"}'::jsonb),
    (v_hub_project_id, v_hub_dev_environment_id, 'media.storage', 'active', '{"provider":"supabase-storage"}'::jsonb),
    (v_website_project_id, v_website_dev_environment_id, 'core.cms', 'active', '{"source":"supabase"}'::jsonb),
    (v_website_project_id, v_website_dev_environment_id, 'i18n.runtime', 'active', '{"defaultLocale":"en"}'::jsonb),
    (v_website_project_id, v_website_dev_environment_id, 'media.storage', 'active', '{"provider":"supabase-storage"}'::jsonb)
  ON CONFLICT (project_id, environment_id, plugin_key) DO UPDATE
    SET status = EXCLUDED.status,
        config = EXCLUDED.config,
        updated_at = now();

  INSERT INTO public.project_implementations (project_id, environment_id, implementation_key, status, config)
  VALUES
    (v_hub_project_id, v_hub_dev_environment_id, 'auth.keycloak', 'active', '{"issuer":"https://api.dreamlab.solutions"}'::jsonb)
  ON CONFLICT (project_id, environment_id, implementation_key) DO UPDATE
    SET status = EXCLUDED.status,
        config = EXCLUDED.config,
        updated_at = now();

  -- ---------------------------------------------------------------------------
  -- 5) Config and feature overrides
  -- ---------------------------------------------------------------------------
  INSERT INTO public.config_overrides (key, tenant_id, project_id, environment_id, value, updated_by)
  VALUES
    ('platform.brand.name', v_tenant_id, null, null, '"DreamLab Solutions"'::jsonb, v_user_id),
    ('platform.brand.tagline', v_tenant_id, null, null, '"Systems for ambitious digital products."'::jsonb, v_user_id),
    ('project.app.definitionId', null, v_hub_project_id, null, '"app_platform_hub"'::jsonb, v_user_id),
    ('project.app.definitionId', null, v_website_project_id, null, '"app_dreamlab_website"'::jsonb, v_user_id),
    ('project.site.primaryDomain', null, v_hub_project_id, null, '"hub.dreamlab.solutions"'::jsonb, v_user_id),
    ('project.site.primaryDomain', null, v_website_project_id, null, '"dreamlab.solutions"'::jsonb, v_user_id),
    ('project.i18n.defaultLocale', null, v_hub_project_id, null, '"en"'::jsonb, v_user_id),
    ('project.i18n.defaultLocale', null, v_website_project_id, null, '"en"'::jsonb, v_user_id)
  ON CONFLICT ON CONSTRAINT uq_config_override DO UPDATE
    SET value = EXCLUDED.value,
        updated_by = EXCLUDED.updated_by,
        updated_at = now();

  INSERT INTO public.feature_state_overrides (feature_key, tenant_id, project_id, environment_id, status, updated_by)
  VALUES
    ('platform.hub.workspace', null, v_hub_project_id, null, 'active', v_user_id),
    ('website.public.site', null, v_website_project_id, null, 'active', v_user_id)
  ON CONFLICT ON CONSTRAINT uq_feature_state_override DO UPDATE
    SET status = EXCLUDED.status,
        updated_by = EXCLUDED.updated_by,
        updated_at = now();

  INSERT INTO public.feature_flag_overrides (project_id, environment_id, tenant_id, flag_key, value)
  VALUES
    (v_hub_project_id, v_hub_dev_environment_id, null, 'cms.content', true),
    (v_hub_project_id, v_hub_dev_environment_id, null, 'cms.schemaBuilder', true),
    (v_hub_project_id, v_hub_dev_environment_id, null, 'cms.routing', true),
    (v_hub_project_id, v_hub_dev_environment_id, null, 'cms.i18n', true),
    (v_hub_project_id, v_hub_dev_environment_id, null, 'cms.media', true),
    (v_hub_project_id, v_hub_dev_environment_id, null, 'hub.workspace', true),
    (v_hub_project_id, v_hub_dev_environment_id, null, 'project.sync.materialization', true),
    (v_hub_project_id, v_hub_dev_environment_id, null, 'project.sync.inbound', true),
    (v_website_project_id, v_website_dev_environment_id, null, 'cms.content', true),
    (v_website_project_id, v_website_dev_environment_id, null, 'cms.i18n', true),
    (v_website_project_id, v_website_dev_environment_id, null, 'website.public', true),
    (v_website_project_id, v_website_dev_environment_id, null, 'project.sync.materialization', true),
    (v_website_project_id, v_website_dev_environment_id, null, 'project.sync.inbound', true)
  ON CONFLICT ON CONSTRAINT uq_flag_override DO UPDATE
    SET value = EXCLUDED.value,
        updated_at = now();

  INSERT INTO public.tenant_entitlements (tenant_id, project_id, environment_id, key, value, source)
  VALUES
    (v_tenant_id, v_hub_project_id, null, 'project.app.access', '{"enabled":true,"appId":"app_platform_hub"}'::jsonb, 'system'),
    (v_tenant_id, v_hub_project_id, null, 'project.repo.tracked_branches', '{"dev":"develop","stage":"stage","prod":"main"}'::jsonb, 'system'),
    (v_tenant_id, v_website_project_id, null, 'project.app.access', '{"enabled":true,"appId":"app_dreamlab_website"}'::jsonb, 'system'),
    (v_tenant_id, v_website_project_id, null, 'project.repo.tracked_branches', '{"dev":"develop","stage":"stage","prod":"main"}'::jsonb, 'system')
  ON CONFLICT (tenant_id, project_id, environment_id, key) DO UPDATE
    SET value = EXCLUDED.value,
        source = EXCLUDED.source,
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
    (v_hub_project_id, v_hub_dev_environment_id, 'routing', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next"}'::jsonb),
    (v_hub_project_id, v_hub_dev_environment_id, 'composition', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next"}'::jsonb),
    (v_hub_project_id, v_hub_dev_environment_id, 'app_definition', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next"}'::jsonb),
    (v_hub_project_id, v_hub_dev_environment_id, 'registry', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next","artifactPath":"apps/dls-platform-hub-next/.dreamlab/registry.json"}'::jsonb),
    (v_hub_project_id, v_hub_dev_environment_id, 'package_registry', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next","artifactPath":"apps/dls-platform-hub-next/.dreamlab/packages.json"}'::jsonb),
    (v_hub_project_id, v_hub_dev_environment_id, 'content_models', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next","artifactPath":"apps/dls-platform-hub-next/.dreamlab/content-models.json"}'::jsonb),
    (v_hub_project_id, v_hub_dev_environment_id, 'version_pins', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next","artifactPath":"apps/dls-platform-hub-next/.dreamlab/version-pins.json"}'::jsonb),
    (v_hub_project_id, v_hub_stage_environment_id, 'routing', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next"}'::jsonb),
    (v_hub_project_id, v_hub_stage_environment_id, 'composition', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next"}'::jsonb),
    (v_hub_project_id, v_hub_stage_environment_id, 'app_definition', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next"}'::jsonb),
    (v_hub_project_id, v_hub_stage_environment_id, 'registry', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next","artifactPath":"apps/dls-platform-hub-next/.dreamlab/registry.json"}'::jsonb),
    (v_hub_project_id, v_hub_stage_environment_id, 'package_registry', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next","artifactPath":"apps/dls-platform-hub-next/.dreamlab/packages.json"}'::jsonb),
    (v_hub_project_id, v_hub_stage_environment_id, 'content_models', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next","artifactPath":"apps/dls-platform-hub-next/.dreamlab/content-models.json"}'::jsonb),
    (v_hub_project_id, v_hub_stage_environment_id, 'version_pins', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next","artifactPath":"apps/dls-platform-hub-next/.dreamlab/version-pins.json"}'::jsonb),
    (v_hub_project_id, v_hub_prod_environment_id, 'routing', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next"}'::jsonb),
    (v_hub_project_id, v_hub_prod_environment_id, 'composition', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next"}'::jsonb),
    (v_hub_project_id, v_hub_prod_environment_id, 'app_definition', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next"}'::jsonb),
    (v_hub_project_id, v_hub_prod_environment_id, 'registry', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next","artifactPath":"apps/dls-platform-hub-next/.dreamlab/registry.json"}'::jsonb),
    (v_hub_project_id, v_hub_prod_environment_id, 'package_registry', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next","artifactPath":"apps/dls-platform-hub-next/.dreamlab/packages.json"}'::jsonb),
    (v_hub_project_id, v_hub_prod_environment_id, 'content_models', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next","artifactPath":"apps/dls-platform-hub-next/.dreamlab/content-models.json"}'::jsonb),
    (v_hub_project_id, v_hub_prod_environment_id, 'version_pins', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-platform-hub-next","artifactPath":"apps/dls-platform-hub-next/.dreamlab/version-pins.json"}'::jsonb),
    (v_website_project_id, v_website_dev_environment_id, 'routing', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro"}'::jsonb),
    (v_website_project_id, v_website_dev_environment_id, 'composition', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro"}'::jsonb),
    (v_website_project_id, v_website_dev_environment_id, 'app_definition', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro"}'::jsonb),
    (v_website_project_id, v_website_dev_environment_id, 'registry', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro","artifactPath":"apps/dls-webapp-astro/.dreamlab/registry.json"}'::jsonb),
    (v_website_project_id, v_website_dev_environment_id, 'package_registry', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro","artifactPath":"apps/dls-webapp-astro/.dreamlab/packages.json"}'::jsonb),
    (v_website_project_id, v_website_dev_environment_id, 'content_models', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro","artifactPath":"apps/dls-webapp-astro/.dreamlab/content-models.json"}'::jsonb),
    (v_website_project_id, v_website_dev_environment_id, 'version_pins', 'develop', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro","artifactPath":"apps/dls-webapp-astro/.dreamlab/version-pins.json"}'::jsonb),
    (v_website_project_id, v_website_stage_environment_id, 'routing', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro"}'::jsonb),
    (v_website_project_id, v_website_stage_environment_id, 'composition', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro"}'::jsonb),
    (v_website_project_id, v_website_stage_environment_id, 'app_definition', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro"}'::jsonb),
    (v_website_project_id, v_website_stage_environment_id, 'registry', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro","artifactPath":"apps/dls-webapp-astro/.dreamlab/registry.json"}'::jsonb),
    (v_website_project_id, v_website_stage_environment_id, 'package_registry', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro","artifactPath":"apps/dls-webapp-astro/.dreamlab/packages.json"}'::jsonb),
    (v_website_project_id, v_website_stage_environment_id, 'content_models', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro","artifactPath":"apps/dls-webapp-astro/.dreamlab/content-models.json"}'::jsonb),
    (v_website_project_id, v_website_stage_environment_id, 'version_pins', 'stage', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro","artifactPath":"apps/dls-webapp-astro/.dreamlab/version-pins.json"}'::jsonb),
    (v_website_project_id, v_website_prod_environment_id, 'routing', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro"}'::jsonb),
    (v_website_project_id, v_website_prod_environment_id, 'composition', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro"}'::jsonb),
    (v_website_project_id, v_website_prod_environment_id, 'app_definition', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro"}'::jsonb),
    (v_website_project_id, v_website_prod_environment_id, 'registry', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro","artifactPath":"apps/dls-webapp-astro/.dreamlab/registry.json"}'::jsonb),
    (v_website_project_id, v_website_prod_environment_id, 'package_registry', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro","artifactPath":"apps/dls-webapp-astro/.dreamlab/packages.json"}'::jsonb),
    (v_website_project_id, v_website_prod_environment_id, 'content_models', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro","artifactPath":"apps/dls-webapp-astro/.dreamlab/content-models.json"}'::jsonb),
    (v_website_project_id, v_website_prod_environment_id, 'version_pins', 'main', 'database', 'tracked_branch_only', 'pending', '{"workspacePath":"apps/dls-webapp-astro","artifactPath":"apps/dls-webapp-astro/.dreamlab/version-pins.json"}'::jsonb)
  ON CONFLICT (project_id, environment_id, artifact_kind) DO UPDATE
    SET tracked_branch = EXCLUDED.tracked_branch,
        canonical_source = EXCLUDED.canonical_source,
        inbound_sync_policy = EXCLUDED.inbound_sync_policy,
        drift_status = EXCLUDED.drift_status,
        metadata = EXCLUDED.metadata,
        updated_at = now();

  INSERT INTO public.role_config (
    tenant_id,
    project_id,
    role_key,
    role_name,
    description,
    permissions,
    is_active
  )
  VALUES
    (
      v_tenant_id,
      v_hub_project_id,
      'platform_admin',
      'Platform Admin',
      'Can manage models, routing, locales, feature flags, and platform links in the hub.',
      '["content.read","content.create","content.publish","models.manage","routing.manage","feature-flags.manage","locales.manage","platform.links.manage"]'::jsonb,
      true
    ),
    (
      v_tenant_id,
      v_hub_project_id,
      'content_editor',
      'Content Editor',
      'Can manage content and localized labels for DreamLab projects.',
      '["content.read","content.create","content.publish"]'::jsonb,
      true
    ),
    (
      v_tenant_id,
      v_hub_project_id,
      'author',
      'Author',
      'Can draft content but not publish.',
      '["content.read","content.create"]'::jsonb,
      true
    )
  ON CONFLICT (tenant_id, project_id, role_key) DO UPDATE
    SET role_name = EXCLUDED.role_name,
        description = EXCLUDED.description,
        permissions = EXCLUDED.permissions,
        is_active = EXCLUDED.is_active,
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
  VALUES
    (
      'app_platform_hub',
      'DreamLab Platform Hub',
      'Internal platform management console for routes, models, locales, and governance.',
      'Database',
      '#0ea5e9',
      v_hub_project_id,
      'apps/dls-platform-hub-next',
      '1.0.0',
      'app-platform-hub-v1',
      'workspace',
      '{"materializationPath":"apps/dls-platform-hub-next/.dreamlab/app-definition.json"}'::jsonb
    ),
    (
      'app_dreamlab_website',
      'DreamLab Website',
      'Public DreamLab marketing website rendered from database-authored content.',
      'Globe',
      '#10b981',
      v_website_project_id,
      'apps/dls-webapp-astro',
      '1.0.0',
      'app-dreamlab-website-v1',
      'workspace',
      '{"materializationPath":"apps/dls-webapp-astro/.dreamlab/app-definition.json"}'::jsonb
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

  INSERT INTO public.composition_nodes (
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
  VALUES
    ('app_platform_hub', 'root', null, 'Platform Hub Root', 'layout', 'none', null, 0, '{"path":"/dashboard","workspacePath":"apps/dls-platform-hub-next","materializationPath":"apps/dls-platform-hub-next/.dreamlab/composition.json"}'::jsonb),
    ('app_platform_hub', 'dashboard', 'root', 'Dashboard', 'route', 'none', null, 0, '{"path":"/dashboard","projectSlug":"dls-platform-hub-next"}'::jsonb),
    ('app_platform_hub', 'content', 'root', 'Content', 'route', 'none', null, 1, '{"path":"/dashboard/content","projectSlug":"dls-platform-hub-next"}'::jsonb),
    ('app_platform_hub', 'models', 'root', 'Models', 'route', 'none', null, 2, '{"path":"/dashboard/models","projectSlug":"dls-platform-hub-next"}'::jsonb),
    ('app_platform_hub', 'routing', 'root', 'Routing', 'route', 'none', null, 3, '{"path":"/dashboard/routing","projectSlug":"dls-platform-hub-next"}'::jsonb),
    ('app_platform_hub', 'access', 'root', 'Access', 'route', 'none', null, 4, '{"path":"/dashboard/access","projectSlug":"dls-platform-hub-next"}'::jsonb),
    ('app_platform_hub', 'settings', 'root', 'Settings', 'route', 'none', null, 5, '{"path":"/dashboard/settings","projectSlug":"dls-platform-hub-next"}'::jsonb),
    ('app_dreamlab_website', 'root', null, 'Website Root', 'layout', 'none', null, 0, '{"path":"/","workspacePath":"apps/dls-webapp-astro","materializationPath":"apps/dls-webapp-astro/.dreamlab/composition.json"}'::jsonb),
    ('app_dreamlab_website', 'home', 'root', 'Homepage', 'route', 'none', null, 0, '{"path":"/","projectSlug":"dls-website-astro"}'::jsonb),
    ('app_dreamlab_website', 'about', 'root', 'About', 'route', 'none', null, 1, '{"path":"/about","projectSlug":"dls-website-astro"}'::jsonb),
    ('app_dreamlab_website', 'services', 'root', 'Services', 'route', 'none', null, 2, '{"path":"/services","projectSlug":"dls-website-astro"}'::jsonb),
    ('app_dreamlab_website', 'contact', 'root', 'Contact', 'route', 'none', null, 3, '{"path":"/contact","projectSlug":"dls-website-astro"}'::jsonb)
  ON CONFLICT (app_id, node_id) DO UPDATE
    SET parent_node_id = EXCLUDED.parent_node_id,
        name = EXCLUDED.name,
        type = EXCLUDED.type,
        ref_kind = EXCLUDED.ref_kind,
        ref_key = EXCLUDED.ref_key,
        position = EXCLUDED.position,
        config = EXCLUDED.config;

  INSERT INTO public.project_app_bindings (
    project_id,
    environment_id,
    app_id,
    status,
    pinned_version,
    source_commit_sha,
    metadata
  )
  VALUES
    (v_hub_project_id, null, 'app_platform_hub', 'active', '0.0.1', 'seed-reset-2026-03-12', '{"workspacePath":"apps/dls-platform-hub-next"}'::jsonb),
    (v_website_project_id, null, 'app_dreamlab_website', 'active', '0.0.2', 'seed-reset-2026-03-12', '{"workspacePath":"apps/dls-webapp-astro"}'::jsonb)
  ON CONFLICT (project_id, app_id) DO UPDATE
    SET status = EXCLUDED.status,
        environment_id = EXCLUDED.environment_id,
        pinned_version = EXCLUDED.pinned_version,
        source_commit_sha = EXCLUDED.source_commit_sha,
        metadata = EXCLUDED.metadata,
        updated_at = now();

  -- ---------------------------------------------------------------------------
  -- 6) Routing
  -- ---------------------------------------------------------------------------
  INSERT INTO public.routing_nodes (project_id, node_id, key, kind, segment_key, parent_node_id, position, config)
  VALUES
    (v_hub_project_id, 'root', 'root', 'group', '', null, 0, '{}'::jsonb),
    (v_hub_project_id, 'dashboard', 'hub.dashboard', 'page', 'dashboard', 'root', 0, '{}'::jsonb),
    (v_hub_project_id, 'content', 'hub.content', 'page', 'content', 'root', 1, '{}'::jsonb),
    (v_hub_project_id, 'models', 'hub.models', 'page', 'models', 'root', 2, '{}'::jsonb),
    (v_hub_project_id, 'routing', 'hub.routing', 'page', 'routing', 'root', 3, '{}'::jsonb),
    (v_hub_project_id, 'access', 'hub.access', 'page', 'access', 'root', 4, '{}'::jsonb),
    (v_hub_project_id, 'settings', 'hub.settings', 'page', 'settings', 'root', 5, '{}'::jsonb),
    (v_website_project_id, 'root', 'root', 'group', '', null, 0, '{}'::jsonb),
    (v_website_project_id, 'home', 'website.home', 'page', '', 'root', 0, '{}'::jsonb),
    (v_website_project_id, 'about', 'website.about', 'page', 'about', 'root', 1, '{}'::jsonb),
    (v_website_project_id, 'services', 'website.services', 'page', 'services', 'root', 2, '{}'::jsonb),
    (v_website_project_id, 'contact', 'website.contact', 'page', 'contact', 'root', 3, '{}'::jsonb)
  ON CONFLICT (project_id, node_id) DO UPDATE
    SET key = EXCLUDED.key,
        kind = EXCLUDED.kind,
        segment_key = EXCLUDED.segment_key,
        parent_node_id = EXCLUDED.parent_node_id,
        position = EXCLUDED.position,
        config = EXCLUDED.config;

  INSERT INTO public.routing_locale_mappings (project_id, locale, node_id, translated_segment)
  VALUES
    (v_hub_project_id, 'en', 'root', ''),
    (v_hub_project_id, 'en', 'dashboard', 'dashboard'),
    (v_hub_project_id, 'en', 'content', 'content'),
    (v_hub_project_id, 'en', 'models', 'models'),
    (v_hub_project_id, 'en', 'routing', 'routing'),
    (v_hub_project_id, 'en', 'access', 'access'),
    (v_hub_project_id, 'en', 'settings', 'settings'),
    (v_hub_project_id, 'it', 'root', ''),
    (v_hub_project_id, 'it', 'dashboard', 'dashboard'),
    (v_hub_project_id, 'it', 'content', 'contenuti'),
    (v_hub_project_id, 'it', 'models', 'modelli'),
    (v_hub_project_id, 'it', 'routing', 'percorsi'),
    (v_hub_project_id, 'it', 'access', 'accessi'),
    (v_hub_project_id, 'it', 'settings', 'impostazioni'),
    (v_website_project_id, 'en', 'root', ''),
    (v_website_project_id, 'en', 'home', ''),
    (v_website_project_id, 'en', 'about', 'about'),
    (v_website_project_id, 'en', 'services', 'services'),
    (v_website_project_id, 'en', 'contact', 'contact'),
    (v_website_project_id, 'it', 'root', ''),
    (v_website_project_id, 'it', 'home', ''),
    (v_website_project_id, 'it', 'about', 'chi-siamo'),
    (v_website_project_id, 'it', 'services', 'servizi'),
    (v_website_project_id, 'it', 'contact', 'contatti')
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
    ('platform_hub.dashboard.copy', 'pkg.dls-api-core', 'Platform Hub Dashboard Copy', 'Localized copy catalog for the platform hub.', 'copy', 'single', true, true, '[{"key":"copy","label":"Copy Catalog","type":"json","required":true,"translatable":true},{"key":"meta","label":"Dashboard Meta","type":"json","required":false}]'::jsonb, '1.1.0', 'chk_platform_hub_dashboard_copy_1_1_0', 'seed-reset-2026-03-12', '{"family":"platform-hub","packageKey":"pkg.dls-api-core"}'::jsonb),
    ('website.global.copy', 'pkg.dls-api-core', 'Website Global Copy', 'Localized website shell copy catalog.', 'copy', 'single', true, true, '[{"key":"copy","label":"Copy Catalog","type":"json","required":true,"translatable":true}]'::jsonb, '1.0.0', 'chk_website_global_copy_1_0_0', 'seed-reset-2026-03-12', '{"family":"website","packageKey":"pkg.dls-api-core"}'::jsonb),
    ('website.homepage', 'pkg.dls-api-core', 'Website Homepage', 'Homepage page model.', 'page', 'single', true, true, '[
      {"key":"hero_title","label":"Hero Title","type":"text","required":true,"translatable":true},
      {"key":"hero_subtitle","label":"Hero Subtitle","type":"textarea","required":true,"translatable":true},
      {"key":"primary_cta_label","label":"Primary CTA Label","type":"text","required":true,"translatable":true},
      {"key":"primary_cta_href","label":"Primary CTA URL","type":"text","required":true},
      {"key":"secondary_cta_label","label":"Secondary CTA Label","type":"text","required":false,"translatable":true},
      {"key":"secondary_cta_href","label":"Secondary CTA URL","type":"text","required":false}
    ]'::jsonb, '1.0.0', 'chk_website_homepage_1_0_0', 'seed-reset-2026-03-12', '{"family":"website","packageKey":"pkg.dls-api-core"}'::jsonb),
    ('meta.seo', 'pkg.dls-api-core', 'SEO Meta', 'Search metadata contract.', 'meta', 'single', true, true, '[{"key":"title","label":"Meta Title","type":"text","translatable":true},{"key":"description","label":"Meta Description","type":"text","translatable":true},{"key":"canonical_url","label":"Canonical URL","type":"text"},{"key":"robots","label":"Robots","type":"text"}]'::jsonb, '1.1.0', 'chk_meta_seo_1_1_0', 'seed-reset-2026-03-12', '{"family":"meta","packageKey":"pkg.dls-api-core"}'::jsonb),
    ('meta.aeo', 'pkg.dls-api-core', 'AEO Meta', 'Answer-engine metadata contract.', 'meta', 'single', true, true, '[{"key":"summary","label":"Answer Summary","type":"textarea","translatable":true},{"key":"faq","label":"FAQ Payload","type":"json","translatable":true}]'::jsonb, '1.0.0', 'chk_meta_aeo_1_0_0', 'seed-reset-2026-03-12', '{"family":"meta","packageKey":"pkg.dls-api-core"}'::jsonb),
    ('meta.geo', 'pkg.dls-api-core', 'GEO Meta', 'Geo-targeting metadata contract.', 'meta', 'single', true, true, '[{"key":"region","label":"Region","type":"text","translatable":true},{"key":"coordinates","label":"Coordinates","type":"json"}]'::jsonb, '1.0.0', 'chk_meta_geo_1_0_0', 'seed-reset-2026-03-12', '{"family":"meta","packageKey":"pkg.dls-api-core"}'::jsonb)
  ON CONFLICT (key) DO UPDATE
    SET name = EXCLUDED.name,
        package_key = EXCLUDED.package_key,
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
    ('platform_hub.dashboard.copy', '1.0.0', 'chk_platform_hub_dashboard_copy_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"copy","label":"Copy Catalog","type":"json","required":true,"translatable":true}]'::jsonb, '{"seed":"dreamlab-base"}'::jsonb),
    ('platform_hub.dashboard.copy', '1.1.0', 'chk_platform_hub_dashboard_copy_1_1_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"copy","label":"Copy Catalog","type":"json","required":true,"translatable":true},{"key":"meta","label":"Dashboard Meta","type":"json","required":false}]'::jsonb, '{"seed":"dreamlab-base"}'::jsonb),
    ('website.global.copy', '1.0.0', 'chk_website_global_copy_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"copy","label":"Copy Catalog","type":"json","required":true,"translatable":true}]'::jsonb, '{"seed":"dreamlab-base"}'::jsonb),
    ('website.homepage', '1.0.0', 'chk_website_homepage_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[
      {"key":"hero_title","label":"Hero Title","type":"text","required":true,"translatable":true},
      {"key":"hero_subtitle","label":"Hero Subtitle","type":"textarea","required":true,"translatable":true},
      {"key":"primary_cta_label","label":"Primary CTA Label","type":"text","required":true,"translatable":true},
      {"key":"primary_cta_href","label":"Primary CTA URL","type":"text","required":true},
      {"key":"secondary_cta_label","label":"Secondary CTA Label","type":"text","required":false,"translatable":true},
      {"key":"secondary_cta_href","label":"Secondary CTA URL","type":"text","required":false}
    ]'::jsonb, '{"seed":"dreamlab-base"}'::jsonb),
    ('meta.seo', '1.0.0', 'chk_meta_seo_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"title","label":"Meta Title","type":"text","translatable":true},{"key":"description","label":"Meta Description","type":"text","translatable":true},{"key":"canonical_url","label":"Canonical URL","type":"text"}]'::jsonb, '{"seed":"dreamlab-base"}'::jsonb),
    ('meta.seo', '1.1.0', 'chk_meta_seo_1_1_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"title","label":"Meta Title","type":"text","translatable":true},{"key":"description","label":"Meta Description","type":"text","translatable":true},{"key":"canonical_url","label":"Canonical URL","type":"text"},{"key":"robots","label":"Robots","type":"text"}]'::jsonb, '{"seed":"dreamlab-base"}'::jsonb),
    ('meta.aeo', '1.0.0', 'chk_meta_aeo_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"summary","label":"Answer Summary","type":"textarea","translatable":true},{"key":"faq","label":"FAQ Payload","type":"json","translatable":true}]'::jsonb, '{"seed":"dreamlab-base"}'::jsonb),
    ('meta.geo', '1.0.0', 'chk_meta_geo_1_0_0', 'seed-reset-2026-03-12', 'backward_compatible', '[{"key":"region","label":"Region","type":"text","translatable":true},{"key":"coordinates","label":"Coordinates","type":"json"}]'::jsonb, '{"seed":"dreamlab-base"}'::jsonb)
  ON CONFLICT (definition_key, version) DO UPDATE
    SET schema_checksum = EXCLUDED.schema_checksum,
        source_commit_sha = EXCLUDED.source_commit_sha,
        change_kind = EXCLUDED.change_kind,
        fields = EXCLUDED.fields,
        metadata = EXCLUDED.metadata;

  -- ---------------------------------------------------------------------------
  -- 7) DB-backed content and i18n labels
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
  VALUES
    (
      v_hub_project_id,
      'platform_hub_dashboard.copy',
      'Platform Hub Dashboard Copy',
      'single',
      true,
      true,
      '[{"key":"copy","label":"Copy Catalog","type":"json","required":true,"translatable":true}]'::jsonb,
      'platform_hub.dashboard.copy',
      'platform_hub.dashboard.copy',
      '1.0.0',
      'chk_platform_hub_dashboard_copy_1_0_0',
      'seed-reset-2026-03-12',
      'pkg.dls-api-core',
      'owned',
      'update_available'
    ),
    (
      v_website_project_id,
      'website.global.copy',
      'Website Global Copy',
      'single',
      true,
      true,
      '[{"key":"copy","label":"Copy Catalog","type":"json","required":true,"translatable":true}]'::jsonb,
      'website.global.copy',
      'website.global.copy',
      '1.0.0',
      'chk_website_global_copy_1_0_0',
      'seed-reset-2026-03-12',
      'pkg.dls-api-core',
      'owned',
      'aligned'
    ),
    (
      v_website_project_id,
      'website.homepage',
      'Website Homepage',
      'single',
      true,
      true,
      '[
        {"key":"hero_title","label":"Hero Title","type":"text","required":true,"translatable":true},
        {"key":"hero_subtitle","label":"Hero Subtitle","type":"textarea","required":true,"translatable":true},
        {"key":"primary_cta_label","label":"Primary CTA Label","type":"text","required":true,"translatable":true},
        {"key":"primary_cta_href","label":"Primary CTA URL","type":"text","required":true},
        {"key":"secondary_cta_label","label":"Secondary CTA Label","type":"text","required":false,"translatable":true},
        {"key":"secondary_cta_href","label":"Secondary CTA URL","type":"text","required":false}
      ]'::jsonb,
      'website.homepage',
      'website.homepage',
      '1.0.0',
      'chk_website_homepage_1_0_0',
      'seed-reset-2026-03-12',
      'pkg.dls-api-core',
      'owned',
      'aligned'
    ),
    (
      v_hub_project_id,
      'meta.seo',
      'SEO Meta',
      'single',
      true,
      true,
      '[{"key":"title","label":"Meta Title","type":"text","translatable":true},{"key":"description","label":"Meta Description","type":"text","translatable":true},{"key":"canonical_url","label":"Canonical URL","type":"text"},{"key":"robots","label":"Robots","type":"text"}]'::jsonb,
      'meta.seo',
      'meta.seo',
      '1.0.0',
      'chk_meta_seo_1_0_0',
      'seed-reset-2026-03-12',
      'pkg.dls-api-core',
      'inherited',
      'update_available'
    ),
    (
      v_hub_project_id,
      'meta.aeo',
      'AEO Meta',
      'single',
      true,
      true,
      '[{"key":"summary","label":"Answer Summary","type":"textarea","translatable":true},{"key":"faq","label":"FAQ Payload","type":"json","translatable":true}]'::jsonb,
      'meta.aeo',
      'meta.aeo',
      '1.0.0',
      'chk_meta_aeo_1_0_0',
      'seed-reset-2026-03-12',
      'pkg.dls-api-core',
      'inherited',
      'aligned'
    ),
    (
      v_hub_project_id,
      'meta.geo',
      'GEO Meta',
      'single',
      true,
      true,
      '[{"key":"region","label":"Region","type":"text","translatable":true},{"key":"coordinates","label":"Coordinates","type":"json"}]'::jsonb,
      'meta.geo',
      'meta.geo',
      '1.0.0',
      'chk_meta_geo_1_0_0',
      'seed-reset-2026-03-12',
      'pkg.dls-api-core',
      'inherited',
      'aligned'
    ),
    (
      v_website_project_id,
      'meta.seo',
      'SEO Meta',
      'single',
      true,
      true,
      '[{"key":"title","label":"Meta Title","type":"text","translatable":true},{"key":"description","label":"Meta Description","type":"text","translatable":true},{"key":"canonical_url","label":"Canonical URL","type":"text"},{"key":"robots","label":"Robots","type":"text"}]'::jsonb,
      'meta.seo',
      'meta.seo',
      '1.0.0',
      'chk_meta_seo_1_0_0',
      'seed-reset-2026-03-12',
      'pkg.dls-api-core',
      'inherited',
      'update_available'
    ),
    (
      v_website_project_id,
      'meta.aeo',
      'AEO Meta',
      'single',
      true,
      true,
      '[{"key":"summary","label":"Answer Summary","type":"textarea","translatable":true},{"key":"faq","label":"FAQ Payload","type":"json","translatable":true}]'::jsonb,
      'meta.aeo',
      'meta.aeo',
      '1.0.0',
      'chk_meta_aeo_1_0_0',
      'seed-reset-2026-03-12',
      'pkg.dls-api-core',
      'inherited',
      'aligned'
    ),
    (
      v_website_project_id,
      'meta.geo',
      'GEO Meta',
      'single',
      true,
      true,
      '[{"key":"region","label":"Region","type":"text","translatable":true},{"key":"coordinates","label":"Coordinates","type":"json"}]'::jsonb,
      'meta.geo',
      'meta.geo',
      '1.0.0',
      'chk_meta_geo_1_0_0',
      'seed-reset-2026-03-12',
      'pkg.dls-api-core',
      'inherited',
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

  INSERT INTO public.project_content_model_bindings (
    project_id,
    model_uid,
    definition_uid,
    pinned_version,
    adoption_status,
    materialization_path,
    metadata
  )
  VALUES
    (v_hub_project_id, 'platform_hub_dashboard.copy', 'platform_hub.dashboard.copy', '1.0.0', 'update_available', 'apps/dls-platform-hub-next/.dreamlab/content-models.json', '{"source":"seed","appId":"app_platform_hub","inheritanceMode":"owned","latestVersion":"1.1.0","metaContracts":{"seo":{"definitionUid":"meta.seo","pinnedVersion":"1.0.0","latestVersion":"1.1.0","mode":"inherit"},"aeo":{"definitionUid":"meta.aeo","pinnedVersion":"1.0.0","latestVersion":"1.0.0","mode":"inherit"},"geo":{"definitionUid":"meta.geo","pinnedVersion":"1.0.0","latestVersion":"1.0.0","mode":"inherit"}}}'::jsonb),
    (v_website_project_id, 'website.homepage', 'website.homepage', '1.0.0', 'aligned', 'apps/dls-webapp-astro/.dreamlab/content-models.json', '{"source":"seed","appId":"app_dreamlab_website","inheritanceMode":"owned","latestVersion":"1.0.0","metaContracts":{"seo":{"definitionUid":"meta.seo","pinnedVersion":"1.1.0","latestVersion":"1.1.0","mode":"inherit"},"aeo":{"definitionUid":"meta.aeo","pinnedVersion":"1.0.0","latestVersion":"1.0.0","mode":"inherit"},"geo":{"definitionUid":"meta.geo","pinnedVersion":"1.0.0","latestVersion":"1.0.0","mode":"inherit"}}}'::jsonb)
  ON CONFLICT (project_id, model_uid) DO UPDATE
    SET model_uid = EXCLUDED.model_uid,
        definition_uid = EXCLUDED.definition_uid,
        pinned_version = EXCLUDED.pinned_version,
        adoption_status = EXCLUDED.adoption_status,
        materialization_path = EXCLUDED.materialization_path,
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
  VALUES
    (
      v_hub_copy_entry_id,
      v_hub_project_id,
      'platform_hub_dashboard.copy',
      'published',
      'Platform Hub Canonical Copy',
      'seed:dreamlab-base',
      $hub$
      {
        "en": {
          "copy": {
            "platformHub.pageTitle": "DreamLab Platform Hub",
            "platformHub.pageDescription": "Configure DreamLab projects, routes, models, locales, and operational metadata from one console.",
            "platformHub.welcomeMessage": "Manage the DreamLab platform contract through database-backed configuration.",
            "platformHub.action.create": "Create",
            "platformHub.action.edit": "Edit",
            "platformHub.action.delete": "Delete",
            "platformHub.action.view": "View",
            "platformHub.action.refresh": "Refresh",
            "platformHub.action.close": "Close",
            "platformHub.action.confirm": "Confirm",
            "platformHub.action.cancel": "Cancel",
            "platformHub.action.save": "Save",
            "platformHub.action.back": "Back",
            "platformHub.action.add": "Add",
            "platformHub.action.remove": "Remove",
            "platformHub.action.toggle": "Toggle",
            "platformHub.action.advance": "Advance",
            "platformHub.label.version": "Version",
            "platformHub.label.latestVersion": "Latest",
            "platformHub.label.package": "Package",
            "platformHub.label.state": "State",
            "platformHub.state.aligned": "Aligned",
            "platformHub.state.updateAvailable": "Update Available",
            "platformHub.state.disabled": "Disabled",
            "platformHub.empty.no-entries.title": "No platform links configured",
            "platformHub.empty.no-entries.message": "Add project links to expose DreamLab destinations from the platform registry.",
            "platformHub.empty.no-models.title": "No models registered",
            "platformHub.empty.no-models.message": "Create content models to enable structured configuration and labels.",
            "platformHub.empty.no-flags.title": "No feature flags configured",
            "platformHub.empty.no-flags.message": "Enable feature flags to control platform modules by environment.",
            "platformHub.empty.no-locales.title": "No locales configured",
            "platformHub.empty.no-locales.message": "Add locales to expose multilingual routing and content.",
            "platformHub.empty.no-access.title": "Access denied",
            "platformHub.empty.no-access.message": "Your account cannot access this hub workspace.",
            "platformHub.empty.no-results.title": "No matching results",
            "platformHub.empty.no-results.message": "Try a different filter or search query.",
            "platformHub.error.access-denied.title": "Access denied",
            "platformHub.error.access-denied.message": "You do not have permission to access this resource.",
            "platformHub.error.load-failed.title": "Unable to load dashboard",
            "platformHub.error.load-failed.message": "The platform dashboard could not be loaded from the configured data sources.",
            "platformHub.error.save-failed.title": "Unable to save changes",
            "platformHub.error.save-failed.message": "The requested change could not be persisted.",
            "platformHub.error.network-error.title": "Connection issue",
            "platformHub.error.network-error.message": "The dashboard request failed due to a network or service error.",
            "platformHub.section.overview": "Overview",
            "platformHub.section.entries": "Project Links",
            "platformHub.section.models": "Models",
            "platformHub.section.flags": "Feature Flags",
            "platformHub.section.locales": "Locales",
            "platformHub.section.settings": "Settings",
            "platformHub.stats.overview": "Workspace Overview",
            "platformHub.stats.totalEntries": "Recent Activity",
            "platformHub.stats.entries": "Routes",
            "platformHub.stats.dataModels": "Data Models",
            "platformHub.stats.featureFlags": "Feature Flags",
            "platformHub.stats.locales": "Locales",
            "platformHub.stats.entriesCount": "items",
            "platformHub.stats.modelsCount": "models",
            "platformHub.stats.flagsEnabled": "enabled",
            "platformHub.stats.localesConfigured": "configured"
          }
        },
        "it": {
          "copy": {
            "platformHub.pageTitle": "DreamLab Platform Hub",
            "platformHub.pageDescription": "Configura progetti, routing, modelli, lingue e metadata operativi di DreamLab da un'unica console.",
            "platformHub.welcomeMessage": "Gestisci il contratto della piattaforma DreamLab tramite configurazione database-driven.",
            "platformHub.action.create": "Crea",
            "platformHub.action.edit": "Modifica",
            "platformHub.action.delete": "Elimina",
            "platformHub.action.view": "Apri",
            "platformHub.action.refresh": "Aggiorna",
            "platformHub.action.close": "Chiudi",
            "platformHub.action.confirm": "Conferma",
            "platformHub.action.cancel": "Annulla",
            "platformHub.action.save": "Salva",
            "platformHub.action.back": "Indietro",
            "platformHub.action.add": "Aggiungi",
            "platformHub.action.remove": "Rimuovi",
            "platformHub.action.toggle": "Attiva/disattiva",
            "platformHub.action.advance": "Avanza",
            "platformHub.label.version": "Versione",
            "platformHub.label.latestVersion": "Ultima",
            "platformHub.label.package": "Package",
            "platformHub.label.state": "Stato",
            "platformHub.state.aligned": "Allineato",
            "platformHub.state.updateAvailable": "Aggiornamento disponibile",
            "platformHub.state.disabled": "Disabilitato",
            "platformHub.empty.no-entries.title": "Nessun link di piattaforma configurato",
            "platformHub.empty.no-entries.message": "Aggiungi i link dei progetti per esporre le destinazioni DreamLab dal registry.",
            "platformHub.empty.no-models.title": "Nessun modello registrato",
            "platformHub.empty.no-models.message": "Crea modelli contenuto per abilitare configurazione e labels strutturate.",
            "platformHub.empty.no-flags.title": "Nessun feature flag configurato",
            "platformHub.empty.no-flags.message": "Abilita i feature flag per controllare i moduli per ambiente.",
            "platformHub.empty.no-locales.title": "Nessuna lingua configurata",
            "platformHub.empty.no-locales.message": "Aggiungi lingue per esporre routing e contenuto multilingua.",
            "platformHub.empty.no-access.title": "Accesso negato",
            "platformHub.empty.no-access.message": "Il tuo account non può accedere a questo workspace.",
            "platformHub.empty.no-results.title": "Nessun risultato",
            "platformHub.empty.no-results.message": "Prova un filtro o una ricerca diversa.",
            "platformHub.error.access-denied.title": "Accesso negato",
            "platformHub.error.access-denied.message": "Non hai i permessi per accedere a questa risorsa.",
            "platformHub.error.load-failed.title": "Impossibile caricare la dashboard",
            "platformHub.error.load-failed.message": "La dashboard della piattaforma non può essere caricata dalle sorgenti configurate.",
            "platformHub.error.save-failed.title": "Impossibile salvare",
            "platformHub.error.save-failed.message": "La modifica richiesta non può essere persistita.",
            "platformHub.error.network-error.title": "Problema di connessione",
            "platformHub.error.network-error.message": "La richiesta della dashboard è fallita per un errore di rete o servizio.",
            "platformHub.section.overview": "Panoramica",
            "platformHub.section.entries": "Link progetto",
            "platformHub.section.models": "Modelli",
            "platformHub.section.flags": "Feature Flag",
            "platformHub.section.locales": "Lingue",
            "platformHub.section.settings": "Impostazioni",
            "platformHub.stats.overview": "Panoramica workspace",
            "platformHub.stats.totalEntries": "Attività recenti",
            "platformHub.stats.entries": "Route",
            "platformHub.stats.dataModels": "Modelli dati",
            "platformHub.stats.featureFlags": "Feature Flag",
            "platformHub.stats.locales": "Lingue",
            "platformHub.stats.entriesCount": "elementi",
            "platformHub.stats.modelsCount": "modelli",
            "platformHub.stats.flagsEnabled": "attivi",
            "platformHub.stats.localesConfigured": "configurate"
          }
        }
      }
      $hub$::jsonb
    ),
    (
      v_website_copy_entry_id,
      v_website_project_id,
      'website.global.copy',
      'published',
      'DreamLab Website Global Copy',
      'seed:dreamlab-base',
      $websitecopy$
      {
        "en": {
          "copy": {
            "website.nav.home": "Home",
            "website.nav.about": "About",
            "website.nav.services": "Services",
            "website.nav.contact": "Contact",
            "website.footer.legal": "All rights reserved.",
            "website.footer.cta": "Start a project"
          }
        },
        "it": {
          "copy": {
            "website.nav.home": "Home",
            "website.nav.about": "Chi siamo",
            "website.nav.services": "Servizi",
            "website.nav.contact": "Contatti",
            "website.footer.legal": "Tutti i diritti riservati.",
            "website.footer.cta": "Avvia un progetto"
          }
        }
      }
      $websitecopy$::jsonb
    ),
    (
      v_website_home_entry_id,
      v_website_project_id,
      'website.homepage',
      'published',
      'DreamLab Homepage',
      'seed:dreamlab-base',
      $homepage$
      {
        "en": {
          "hero_title": "DreamLab builds digital systems that stay operable.",
          "hero_subtitle": "Strategy, platforms, and delivery pipelines for products that need structure, speed, and long-term maintainability.",
          "primary_cta_label": "Work with us",
          "primary_cta_href": "/contact",
          "secondary_cta_label": "Explore services",
          "secondary_cta_href": "/services"
        },
        "it": {
          "hero_title": "DreamLab costruisce sistemi digitali che restano operabili.",
          "hero_subtitle": "Strategia, piattaforme e pipeline di delivery per prodotti che richiedono struttura, velocità e manutenzione nel tempo.",
          "primary_cta_label": "Lavora con noi",
          "primary_cta_href": "/contact",
          "secondary_cta_label": "Esplora i servizi",
          "secondary_cta_href": "/services"
        }
      }
      $homepage$::jsonb
    )
  ON CONFLICT (id) DO UPDATE
    SET project_id = EXCLUDED.project_id,
        model_uid = EXCLUDED.model_uid,
        status = EXCLUDED.status,
        title = EXCLUDED.title,
        author = EXCLUDED.author,
        data = EXCLUDED.data,
        updated_at = now();

  RAISE NOTICE 'DreamLab canonical base seed applied for tenant %', v_tenant_id;
END $$;
