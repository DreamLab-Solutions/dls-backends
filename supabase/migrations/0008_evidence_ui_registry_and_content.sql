-- Evidence UI registry, persisted content models, and composition metadata

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
values (
  'evidence.ui',
  'Evidence UI Configuration',
  'Legal',
  'config',
  'Persisted UI configuration and page copy for evidence pages, materialized from database-authored models.',
  '["evidence.workspace"]'::jsonb,
  '[]'::jsonb,
  '["evidence.ui.page","evidence.ui.section","evidence.ui.panel"]'::jsonb,
  '1.0.0',
  '{
    "sourceOfTruth":"database",
    "materialization":{"artifactKinds":["composition","app_definition","registry","package_registry","content_models","version_pins"]},
    "models":[
      "evidence.ui.dashboard.page",
      "evidence.ui.case.page",
      "evidence.ui.timeline.page",
      "evidence.ui.event.page",
      "evidence.ui.artifact.page",
      "evidence.ui.evidence.page",
      "evidence.ui.consideration.page",
      "evidence.ui.claim.page"
    ]
  }'::jsonb
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

update plugin_definitions
set dependencies = '["core.auth", "mail.ingestion", "ai.generation", "evidence.ui"]'::jsonb
where key = 'evidence.workspace';

insert into interface_definitions (key, name, description, category)
values
  (
    'evidence.ui.page',
    'Evidence UI Page',
    'Page-level persisted UI contract resolved from content models and composition metadata.',
    'Evidence UI'
  ),
  (
    'evidence.ui.section',
    'Evidence UI Section',
    'Section-level persisted UI contract for evidence page composition.',
    'Evidence UI'
  ),
  (
    'evidence.ui.panel',
    'Evidence UI Panel',
    'Panel-level persisted UI contract for evidence widgets and detail surfaces.',
    'Evidence UI'
  )
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category;

create or replace function public.seed_evidence_ui_content(project_uuid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.content_models (
    project_id,
    uid,
    name,
    kind,
    has_draft_and_publish,
    has_i18n,
    fields
  )
  values
    (
      project_uuid,
      'evidence.ui.dashboard.page',
      'Evidence Dashboard Page',
      'single',
      true,
      true,
      '[
        {"key":"page","label":"Page","type":"component","required":true},
        {"key":"states","label":"States","type":"component"},
        {"key":"sections","label":"Sections","type":"component"}
      ]'::jsonb
    ),
    (
      project_uuid,
      'evidence.ui.case.page',
      'Evidence Case Page',
      'single',
      true,
      true,
      '[
        {"key":"page","label":"Page","type":"component","required":true},
        {"key":"states","label":"States","type":"component"},
        {"key":"labels","label":"Labels","type":"component"}
      ]'::jsonb
    ),
    (
      project_uuid,
      'evidence.ui.timeline.page',
      'Evidence Timeline Page',
      'single',
      true,
      true,
      '[
        {"key":"page","label":"Page","type":"component","required":true},
        {"key":"states","label":"States","type":"component"},
        {"key":"labels","label":"Labels","type":"component"}
      ]'::jsonb
    ),
    (
      project_uuid,
      'evidence.ui.event.page',
      'Evidence Event Page',
      'single',
      true,
      true,
      '[
        {"key":"page","label":"Page","type":"component","required":true},
        {"key":"states","label":"States","type":"component"},
        {"key":"labels","label":"Labels","type":"component"}
      ]'::jsonb
    ),
    (
      project_uuid,
      'evidence.ui.artifact.page',
      'Evidence Artifact Page',
      'single',
      true,
      true,
      '[
        {"key":"page","label":"Page","type":"component","required":true},
        {"key":"states","label":"States","type":"component"},
        {"key":"labels","label":"Labels","type":"component"},
        {"key":"types","label":"Artifact Types","type":"component"}
      ]'::jsonb
    ),
    (
      project_uuid,
      'evidence.ui.evidence.page',
      'Evidence Detail Page',
      'single',
      true,
      true,
      '[
        {"key":"page","label":"Page","type":"component","required":true},
        {"key":"states","label":"States","type":"component"},
        {"key":"labels","label":"Labels","type":"component"}
      ]'::jsonb
    ),
    (
      project_uuid,
      'evidence.ui.consideration.page',
      'Evidence Consideration Page',
      'single',
      true,
      true,
      '[
        {"key":"page","label":"Page","type":"component","required":true},
        {"key":"states","label":"States","type":"component"},
        {"key":"labels","label":"Labels","type":"component"},
        {"key":"status","label":"Status","type":"component"}
      ]'::jsonb
    ),
    (
      project_uuid,
      'evidence.ui.claim.page',
      'Evidence Claim Page',
      'single',
      true,
      true,
      '[
        {"key":"page","label":"Page","type":"component","required":true},
        {"key":"states","label":"States","type":"component"},
        {"key":"labels","label":"Labels","type":"component"},
        {"key":"status","label":"Status","type":"component"},
        {"key":"relations","label":"Relations","type":"component"}
      ]'::jsonb
    )
  on conflict (project_id, uid) do update
    set name = excluded.name,
        kind = excluded.kind,
        has_draft_and_publish = excluded.has_draft_and_publish,
        has_i18n = excluded.has_i18n,
        fields = excluded.fields;

  insert into public.content_entries (
    project_id,
    model_uid,
    status,
    title,
    author,
    data
  )
  select
    project_uuid,
    seeded.model_uid,
    'published',
    seeded.title,
    'system:evidence.ui',
    seeded.data
  from (
    values
      (
        'evidence.ui.dashboard.page',
        'Evidence Dashboard Page',
        '{
          "en": {
            "page": {
              "title": "Evidence Management",
              "description": "Review evidence timelines, imports, and analysis."
            },
            "states": {
              "empty": {
                "title": "No Evidence Yet",
                "message": "Start by importing messages or creating an event."
              }
            },
            "sections": {
              "activity": "Recent Activity",
              "import": "Import Messages"
            }
          }
        }'::jsonb
      ),
      (
        'evidence.ui.case.page',
        'Evidence Case Page',
        '{
          "en": {
            "page": {
              "title": "Case",
              "description": "Review case context and linked evidence."
            },
            "states": {
              "notFound": {
                "title": "Case Not Found",
                "message": "The requested case could not be found."
              }
            },
            "labels": {
              "eventCount": "events",
              "summaryFallback": "No summary available"
            }
          }
        }'::jsonb
      ),
      (
        'evidence.ui.timeline.page',
        'Evidence Timeline Page',
        '{
          "en": {
            "page": {
              "title": "Timeline",
              "description": "Chronological view of case activity."
            },
            "states": {
              "notFound": {
                "title": "Timeline Not Found",
                "message": "The requested timeline could not be found."
              }
            },
            "labels": {
              "emptyState": "No events yet",
              "factual": "Factual",
              "interpretation": "Interpretation",
              "mixed": "Mixed"
            }
          }
        }'::jsonb
      ),
      (
        'evidence.ui.event.page',
        'Evidence Event Page',
        '{
          "en": {
            "page": {
              "title": "Event Details",
              "description": "Inspect the event and its linked evidence."
            },
            "states": {
              "notFound": {
                "title": "Event Not Found",
                "message": "The requested event could not be found."
              }
            },
            "labels": {
              "eventId": "Event ID",
              "eventDetails": "Event Details",
              "type": "Type",
              "occurredAt": "Occurred At",
              "timelinePosition": "Timeline Position",
              "sourceRef": "Source Reference",
              "associatedEvidence": "Associated Evidence",
              "noEvidence": "No evidence linked",
              "backToTimeline": "Back to Timeline"
            }
          }
        }'::jsonb
      ),
      (
        'evidence.ui.artifact.page',
        'Evidence Artifact Page',
        '{
          "en": {
            "page": {
              "title": "Artifact",
              "description": "Inspect the original artifact content."
            },
            "states": {
              "notFound": {
                "title": "Artifact Not Found",
                "message": "The requested artifact could not be found."
              }
            },
            "labels": {
              "title": "Artifact",
              "artifactType": "Type",
              "provider": "Provider",
              "subject": "Subject",
              "sentAt": "Sent",
              "sender": "From",
              "recipients": "To",
              "sourceRef": "External ID",
              "rawContent": "Content",
              "fallback": "N/A",
              "untitled": "Untitled Artifact"
            },
            "types": {
              "email": "Email",
              "document": "Document",
              "chat": "Chat"
            }
          }
        }'::jsonb
      ),
      (
        'evidence.ui.evidence.page',
        'Evidence Detail Page',
        '{
          "en": {
            "page": {
              "title": "Evidence Details",
              "description": "Inspect the selected evidence record."
            },
            "states": {
              "notFound": {
                "title": "Evidence Not Found",
                "message": "The requested evidence could not be found."
              }
            },
            "labels": {
              "details": "Evidence Details",
              "id": "Evidence ID",
              "type": "Type",
              "sender": "Sender",
              "sentAt": "Sent At",
              "excerptText": "Excerpt Text",
              "message": "Message",
              "excerpt": "Excerpt",
              "untitledMessage": "Untitled Message"
            }
          }
        }'::jsonb
      ),
      (
        'evidence.ui.consideration.page',
        'Evidence Consideration Page',
        '{
          "en": {
            "page": {
              "title": "Consideration",
              "description": "Review interpretive considerations linked to evidence."
            },
            "states": {
              "notFound": {
                "title": "Consideration Not Found",
                "message": "The requested consideration could not be found."
              }
            },
            "labels": {
              "title": "Consideration",
              "interpretationText": "Interpretation",
              "perspective": "Perspective",
              "confidence": "Confidence",
              "status": "Status",
              "fallback": "N/A"
            },
            "status": {
              "draft": "Draft",
              "under_review": "Under Review",
              "accepted": "Accepted",
              "rejected": "Rejected"
            }
          }
        }'::jsonb
      ),
      (
        'evidence.ui.claim.page',
        'Evidence Claim Page',
        '{
          "en": {
            "page": {
              "title": "Claim",
              "description": "Review a claim and the evidence supporting it."
            },
            "states": {
              "notFound": {
                "title": "Claim Not Found",
                "message": "The requested claim could not be found."
              }
            },
            "labels": {
              "title": "Claim",
              "claimText": "Claim Text",
              "legalBasis": "Legal Basis",
              "jurisdiction": "Jurisdiction",
              "confidence": "Confidence",
              "evidenceSupport": "Evidence Support",
              "status": "Status",
              "changeStatus": "Change Status",
              "noEvidence": "No evidence linked",
              "fallback": "N/A",
              "untitled": "Untitled Claim"
            },
            "status": {
              "draft": "Draft",
              "under_review": "Under Review",
              "accepted": "Accepted",
              "rejected": "Rejected"
            },
            "relations": {
              "supports": "Supports",
              "contradicts": "Contradicts",
              "context": "Context"
            }
          }
        }'::jsonb
      )
  ) as seeded(model_uid, title, data)
  where not exists (
    select 1
    from public.content_entries existing
    where existing.project_id = project_uuid
      and existing.model_uid = seeded.model_uid
  );
end;
$$;

create or replace function public.bootstrap_project_evidence_ui_content()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.seed_evidence_ui_content(new.id);
  return new;
end;
$$;

drop trigger if exists bootstrap_project_evidence_ui_content on public.projects;
create trigger bootstrap_project_evidence_ui_content
  after insert on public.projects
  for each row
  execute function public.bootstrap_project_evidence_ui_content();

do $$
declare
  project_row record;
begin
  for project_row in select id from public.projects loop
    perform public.seed_evidence_ui_content(project_row.id);
  end loop;
end $$;

update composition_nodes
set config = jsonb_build_object(
  'path', '/evidence',
  'interfaceKey', 'evidence.ui.page',
  'pageModelUid', 'evidence.ui.dashboard.page'
)
where app_id = 'app_evidence'
  and node_id = 'workspace';

update composition_nodes
set config = jsonb_build_object(
  'path', '/evidence/timeline',
  'interfaceKey', 'evidence.ui.page',
  'pageModelUid', 'evidence.ui.timeline.page'
)
where app_id = 'app_evidence'
  and node_id = 'timeline';

update composition_nodes
set config = jsonb_build_object(
  'path', '/evidence/analysis',
  'interfaceKey', 'evidence.ui.page',
  'pageModelUid', 'evidence.ui.dashboard.page'
)
where app_id = 'app_evidence'
  and node_id = 'analysis';
