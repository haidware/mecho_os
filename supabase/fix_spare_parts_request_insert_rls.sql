-- Run in the Supabase SQL Editor if publishing a part request fails with
-- SQLSTATE 42501 for spare_part_requests. This replaces the affected
-- authorization policies without changing marketplace data.
BEGIN;

CREATE OR REPLACE FUNCTION public.can_create_spare_part_request(
  p_workshop_id uuid,
  p_mechanic_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT auth.uid() IS NOT NULL
    AND p_mechanic_user_id::text = auth.uid()::text
    AND EXISTS (
      SELECT 1
      FROM public.users AS u
      WHERE u.id::text = auth.uid()::text
        AND u.role IN ('workshop_owner', 'staff')
        AND u.status = 'active'
        AND (
          u.workshop_id::text = p_workshop_id::text
          OR EXISTS (
            SELECT 1
            FROM public.workshops AS w
            WHERE w.id::text = p_workshop_id::text
              AND w.owner_id::text = auth.uid()::text
          )
        )
    )
$function$;

REVOKE ALL ON FUNCTION public.can_create_spare_part_request(uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_create_spare_part_request(uuid, uuid)
  TO authenticated;

DROP POLICY IF EXISTS spare_part_requests_insert
  ON public.spare_part_requests;
CREATE POLICY spare_part_requests_insert
  ON public.spare_part_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    public.can_create_spare_part_request(workshop_id, mechanic_user_id)
    AND status = 'draft'
    AND selected_offer_id IS NULL
  );

DROP POLICY IF EXISTS spare_part_requests_update_draft
  ON public.spare_part_requests;
CREATE POLICY spare_part_requests_update_draft
  ON public.spare_part_requests
  FOR UPDATE TO authenticated
  USING (
    mechanic_user_id::text = auth.uid()::text
    AND status = 'draft'
  )
  WITH CHECK (
    public.can_create_spare_part_request(workshop_id, mechanic_user_id)
    AND status IN ('draft', 'open')
    AND selected_offer_id IS NULL
  );

COMMIT;
