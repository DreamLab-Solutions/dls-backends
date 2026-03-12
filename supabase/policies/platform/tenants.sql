-- Tenants table RLS policies
-- Purpose: Control access to tenant records based on user role and tenant membership

-- Allow authenticated users to view tenants they belong to
CREATE POLICY "tenants_select_authenticated"
ON public.tenants
FOR SELECT
TO authenticated
USING (
  auth.uid() IN (
    SELECT user_id FROM public.tenant_members WHERE tenant_id = tenants.id
  )
);

-- Allow platform admins to manage all tenants
CREATE POLICY "tenants_all_platform_admin"
ON public.tenants
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'platform_admin'
  )
);
