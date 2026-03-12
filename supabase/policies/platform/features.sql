-- Features table RLS policies
-- Purpose: Control feature visibility and management

-- Allow all authenticated users to view features
CREATE POLICY "features_select_authenticated"
ON public.features
FOR SELECT
TO authenticated
USING (true);

-- Only platform admins can modify features
CREATE POLICY "features_modify_platform_admin"
ON public.features
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'platform_admin'
  )
);
