-- Run in the Supabase SQL Editor if publishing a part request fails with
-- SQLSTATE 42501 for spare_part_requests. This replaces the affected
-- authorization policies without changing marketplace data.
BEGIN;

ALTER TABLE public.spare_part_requests
  ALTER COLUMN workshop_id DROP NOT NULL;

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
        AND u.status = 'active'
        AND (
          p_workshop_id IS NULL
          OR u.workshop_id::text = p_workshop_id::text
          OR EXISTS (
            SELECT 1
            FROM public.workshops AS w
            WHERE w.id::text = p_workshop_id::text
              AND w.owner_id::text = auth.uid()::text
          )
        )
    )
$function$;

CREATE OR REPLACE FUNCTION public.can_view_spare_part_request_row(
  p_mechanic_user_id uuid,
  p_status text,
  p_selected_offer_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT (
      p_mechanic_user_id::text = auth.uid()::text
      AND EXISTS (
        SELECT 1
        FROM public.users AS u
        WHERE u.id::text = auth.uid()::text
          AND u.status = 'active'
      )
    )
    OR (
      public.is_active_spare_part_seller()
      AND (
        p_status = 'open'
        OR EXISTS (
          SELECT 1
          FROM public.spare_part_offers AS o
          WHERE o.id = p_selected_offer_id
            AND o.seller_user_id::text = auth.uid()::text
        )
      )
    )
$function$;

REVOKE ALL ON FUNCTION public.can_create_spare_part_request(uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_create_spare_part_request(uuid, uuid)
  TO authenticated;
REVOKE ALL ON FUNCTION public.can_view_spare_part_request_row(uuid, text, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_view_spare_part_request_row(uuid, text, uuid)
  TO authenticated;

DROP POLICY IF EXISTS spare_part_requests_select
  ON public.spare_part_requests;
CREATE POLICY spare_part_requests_select
  ON public.spare_part_requests
  FOR SELECT TO authenticated
  USING (
    public.can_view_spare_part_request_row(
      mechanic_user_id,
      status,
      selected_offer_id
    )
  );

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

CREATE OR REPLACE FUNCTION public.can_access_spare_part_chat(
  p_request_id uuid,
  p_seller_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.spare_part_requests AS r
    JOIN public.spare_part_offers AS o
      ON o.request_id = r.id
     AND o.seller_user_id = p_seller_user_id
    WHERE r.id = p_request_id
      AND (
        r.status = 'open'
        OR (
          r.status = 'accepted'
          AND r.selected_offer_id = o.id
        )
      )
      AND (
        (
          r.mechanic_user_id::text = auth.uid()::text
          AND EXISTS (
            SELECT 1
            FROM public.users AS u
            WHERE u.id::text = auth.uid()::text
              AND u.status = 'active'
          )
        )
        OR (
          o.seller_user_id::text = auth.uid()::text
          AND public.is_active_spare_part_seller()
        )
      )
  )
$function$;

CREATE OR REPLACE FUNCTION public.can_view_spare_part_request(p_request_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.spare_part_requests AS r
    WHERE r.id = p_request_id
      AND public.can_view_spare_part_request_row(
        r.mechanic_user_id,
        r.status,
        r.selected_offer_id
      )
  )
$function$;

CREATE OR REPLACE FUNCTION public.can_upload_spare_part_request_image(p_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.spare_part_requests AS r
    WHERE r.mechanic_user_id::text = auth.uid()::text
      AND r.status = 'draft'
      AND p_name LIKE (
        COALESCE(r.workshop_id::text || '/', '') || r.id::text || '/%'
      )
      AND public.can_create_spare_part_request(r.workshop_id, auth.uid())
  )
$function$;

CREATE OR REPLACE FUNCTION public.can_access_spare_part_request_image(p_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.spare_part_requests AS r
    WHERE p_name = ANY(r.image_paths)
      AND p_name LIKE (
        COALESCE(r.workshop_id::text || '/', '') || r.id::text || '/%'
      )
      AND (
        (
          r.mechanic_user_id::text = auth.uid()::text
          AND public.can_create_spare_part_request(r.workshop_id, auth.uid())
        )
        OR (
          public.is_active_spare_part_seller()
          AND (
            r.status = 'open'
            OR EXISTS (
              SELECT 1
              FROM public.spare_part_offers AS o
              WHERE o.id = r.selected_offer_id
                AND o.seller_user_id::text = auth.uid()::text
            )
          )
        )
      )
  )
$function$;

CREATE OR REPLACE FUNCTION public.accept_spare_part_offer(
  p_request_id uuid,
  p_offer_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  request_row public.spare_part_requests%ROWTYPE;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.users AS u
    WHERE u.id::text = auth.uid()::text
      AND u.status = 'active'
  ) THEN
    RAISE EXCEPTION 'An active account is required to accept a seller offer';
  END IF;

  SELECT *
  INTO request_row
  FROM public.spare_part_requests
  WHERE id = p_request_id
    AND mechanic_user_id::text = auth.uid()::text
  FOR UPDATE;

  IF NOT FOUND OR request_row.status <> 'open' THEN
    RAISE EXCEPTION 'This part request is not open or does not belong to you';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.spare_part_offers AS o
    WHERE o.id = p_offer_id
      AND o.request_id = p_request_id
  ) THEN
    RAISE EXCEPTION 'The selected offer does not belong to this request';
  END IF;

  UPDATE public.spare_part_requests
  SET selected_offer_id = p_offer_id,
      status = 'accepted',
      updated_at = now()
  WHERE id = p_request_id;
END
$function$;

COMMIT;
