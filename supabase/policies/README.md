# Supabase RLS Policies

This directory contains the source-of-truth RLS (Row Level Security) policies for all tables.

## Structure

- `auth/` - Authentication and user management policies
- `platform/` - Platform Hub domain policies (tenants, features, entitlements)
- `content/` - Content management policies (pages, blocks)

## Workflow

### 1. Policy Development
When creating a new policy:
1. Write the policy in the appropriate category file (e.g., `platform/tenants.sql`)
2. Include comments explaining the policy purpose and affected roles
3. Test locally using `pnpm supabase:reset`

### 2. Migration Creation
Policies are applied via migrations:
```bash
# Create a new migration
pnpm supabase:migration create add_tenant_policies

# Copy policy from policies/ to the migration
cat policies/platform/tenants.sql > supabase/migrations/YYYYMMDDHHMMSS_add_tenant_policies.sql
```

### 3. Policy Audit
To audit all active policies:
```bash
# List all policies in local DB
pnpm supabase:db psql -c "SELECT schemaname, tablename, policyname FROM pg_policies;"

# Compare with source files
diff <(find policies -name "*.sql" -exec basename {} \;) \
     <(psql -c "SELECT policyname FROM pg_policies;")
```

### 4. Policy Extraction
To extract policies from an existing migration:
```bash
# Extract CREATE POLICY statements
grep -A 10 "CREATE POLICY" supabase/migrations/*.sql > policies/extracted_YYYY-MM-DD.sql
```

## Naming Convention

Policy names should follow: `{table}_{action}_{role}`

Examples:
- `tenants_select_authenticated`
- `features_insert_platform_admin`
- `entitlements_delete_service_role`

## Best Practices

1. **Explicit over implicit**: Always specify roles explicitly
2. **Least privilege**: Grant minimum necessary permissions
3. **Document exceptions**: Comment any non-standard policies
4. **Test isolation**: Ensure policies work independently
5. **Version control**: Keep policies in sync with migrations
