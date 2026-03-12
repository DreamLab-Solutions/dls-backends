-- Pages table RLS policies
-- Purpose: Control access to content pages based on tenant and role

-- Allow authenticated users to view pages in their tenant
CREATE POLICY "pages_select_tenant_member"
ON public.pages
FOR SELECT
TO authenticated
USING (
  tenant_id IN (
    SELECT tenant_id FROM public.tenant_members WHERE user_id = auth.uid()
  )
);

-- Allow tenant members to insert pages in their tenant
CREATE POLICY "pages_insert_tenant_member"
ON public.pages
FOR INSERT
TO authenticated
WITH CHECK (
  tenant_id IN (
    SELECT tenant_id FROM public.tenant_members WHERE user_id = auth.uid()
  )
);

-- Allow page creators and tenant admins to update pages
CREATE POLICY "pages_update_tenant_admin"
ON public.pages
FOR UPDATE
TO authenticated
USING (
  created_by = auth.uid() OR
  tenant_id IN (
    SELECT tenant_id FROM public.tenant_members 
    WHERE user_id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (
  created_by = auth.uid() OR
  tenant_id IN (
    SELECT tenant_id FROM public.tenant_members 
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);
