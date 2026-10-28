-- Run in the Supabase SQL Editor as a database administrator.
-- Seller accounts must be created or invited by a trusted administrator.
BEGIN;

CREATE TABLE IF NOT EXISTS public.spare_part_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workshop_id uuid REFERENCES public.workshops(id) ON DELETE CASCADE,
  mechanic_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  part_name text NOT NULL,
  condition_requested text NOT NULL CHECK (condition_requested IN ('New', 'Used')),
  barcode text,
  vehicle text,
  position text,
  description text,
  mechanic_name text NOT NULL,
  phone_number text NOT NULL,
  location text NOT NULL,
  image_paths text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'open', 'accepted', 'closed')),
  selected_offer_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.spare_part_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.spare_part_requests(id) ON DELETE CASCADE,
  seller_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  price numeric(12, 2) NOT NULL CHECK (price > 0),
  condition text NOT NULL,
  location text NOT NULL,
  seller_name text NOT NULL,
  phone_number text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT spare_part_offers_one_per_seller UNIQUE (request_id, seller_user_id)
);

CREATE TABLE IF NOT EXISTS public.spare_part_chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.spare_part_requests(id) ON DELETE CASCADE,
  seller_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message text NOT NULL CHECK (char_length(btrim(message)) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);

DO $block$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'spare_part_requests_selected_offer_fk'
      AND conrelid = 'public.spare_part_requests'::regclass
  ) THEN
    ALTER TABLE public.spare_part_requests
      ADD CONSTRAINT spare_part_requests_selected_offer_fk
      FOREIGN KEY (selected_offer_id)
      REFERENCES public.spare_part_offers(id)
      DEFERRABLE INITIALLY DEFERRED;
  END IF;
END
$block$;

CREATE INDEX IF NOT EXISTS spare_part_requests_open_created_idx
  ON public.spare_part_requests (created_at DESC)
  WHERE status = 'open';
CREATE INDEX IF NOT EXISTS spare_part_requests_mechanic_created_idx
  ON public.spare_part_requests (mechanic_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS spare_part_offers_request_price_idx
  ON public.spare_part_offers (request_id, price);
CREATE INDEX IF NOT EXISTS spare_part_chat_request_seller_created_idx
  ON public.spare_part_chat_messages (request_id, seller_user_id, created_at);

ALTER TABLE public.spare_part_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spare_part_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spare_part_chat_messages ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_active_spare_part_seller()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.users AS u
    WHERE u.id::text = auth.uid()::text
      AND u.role = 'spare_part_seller'
      AND u.status = 'active'
  )
$function$;

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

REVOKE ALL ON FUNCTION public.is_active_spare_part_seller() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_access_spare_part_chat(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_view_spare_part_request(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_view_spare_part_request_row(uuid, text, uuid)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_create_spare_part_request(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_upload_spare_part_request_image(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_access_spare_part_request_image(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_active_spare_part_seller() TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_spare_part_chat(uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_view_spare_part_request(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_view_spare_part_request_row(uuid, text, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_create_spare_part_request(uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_upload_spare_part_request_image(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_spare_part_request_image(text) TO authenticated;

DROP POLICY IF EXISTS spare_part_requests_select ON public.spare_part_requests;
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

DROP POLICY IF EXISTS spare_part_requests_insert ON public.spare_part_requests;
CREATE POLICY spare_part_requests_insert
  ON public.spare_part_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    public.can_create_spare_part_request(workshop_id, mechanic_user_id)
    AND status = 'draft'
    AND selected_offer_id IS NULL
  );

DROP POLICY IF EXISTS spare_part_requests_update_draft ON public.spare_part_requests;
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

DROP POLICY IF EXISTS spare_part_requests_delete_draft ON public.spare_part_requests;
CREATE POLICY spare_part_requests_delete_draft
  ON public.spare_part_requests
  FOR DELETE TO authenticated
  USING (
    mechanic_user_id::text = auth.uid()::text
    AND status = 'draft'
  );

DROP POLICY IF EXISTS spare_part_offers_select ON public.spare_part_offers;
CREATE POLICY spare_part_offers_select
  ON public.spare_part_offers
  FOR SELECT TO authenticated
  USING (
    seller_user_id::text = auth.uid()::text
    OR public.can_view_spare_part_request(request_id)
      AND EXISTS (
        SELECT 1
        FROM public.spare_part_requests AS r
        WHERE r.id = request_id
          AND r.mechanic_user_id::text = auth.uid()::text
      )
  );

DROP POLICY IF EXISTS spare_part_offers_insert ON public.spare_part_offers;
CREATE POLICY spare_part_offers_insert
  ON public.spare_part_offers
  FOR INSERT TO authenticated
  WITH CHECK (
    seller_user_id::text = auth.uid()::text
    AND public.is_active_spare_part_seller()
    AND EXISTS (
      SELECT 1 FROM public.spare_part_requests AS r
      WHERE r.id = request_id AND r.status = 'open'
    )
  );

DROP POLICY IF EXISTS spare_part_offers_update ON public.spare_part_offers;
CREATE POLICY spare_part_offers_update
  ON public.spare_part_offers
  FOR UPDATE TO authenticated
  USING (
    seller_user_id::text = auth.uid()::text
    AND public.is_active_spare_part_seller()
    AND EXISTS (
      SELECT 1 FROM public.spare_part_requests AS r
      WHERE r.id = request_id AND r.status = 'open'
    )
  )
  WITH CHECK (
    seller_user_id::text = auth.uid()::text
    AND public.is_active_spare_part_seller()
    AND EXISTS (
      SELECT 1 FROM public.spare_part_requests AS r
      WHERE r.id = request_id AND r.status = 'open'
    )
  );

DROP POLICY IF EXISTS spare_part_chat_messages_select
  ON public.spare_part_chat_messages;
CREATE POLICY spare_part_chat_messages_select
  ON public.spare_part_chat_messages
  FOR SELECT TO authenticated
  USING (
    public.can_access_spare_part_chat(request_id, seller_user_id)
  );

DROP POLICY IF EXISTS spare_part_chat_messages_insert
  ON public.spare_part_chat_messages;
CREATE POLICY spare_part_chat_messages_insert
  ON public.spare_part_chat_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_user_id::text = auth.uid()::text
    AND public.can_access_spare_part_chat(request_id, seller_user_id)
  );

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

REVOKE ALL ON FUNCTION public.accept_spare_part_offer(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_spare_part_offer(uuid, uuid)
  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.spare_part_requests, public.spare_part_offers
  TO authenticated;
GRANT SELECT, INSERT
  ON public.spare_part_chat_messages
  TO authenticated;

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'spare-part-requests',
  'spare-part-requests',
  false,
  8388608,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/gif']
)
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS spare_part_request_images_upload
  ON storage.objects;
CREATE POLICY spare_part_request_images_upload
  ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'spare-part-requests'
    AND public.can_upload_spare_part_request_image(name)
  );

DROP POLICY IF EXISTS spare_part_request_images_delete_draft
  ON storage.objects;
CREATE POLICY spare_part_request_images_delete_draft
  ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'spare-part-requests'
    AND public.can_upload_spare_part_request_image(name)
  );

DROP POLICY IF EXISTS spare_part_request_images_read
  ON storage.objects;
CREATE POLICY spare_part_request_images_read
  ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'spare-part-requests'
    AND public.can_access_spare_part_request_image(name)
  );

DO $block$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'spare_part_requests'
    ) THEN
      ALTER PUBLICATION supabase_realtime
        ADD TABLE public.spare_part_requests;
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'spare_part_chat_messages'
    ) THEN
      ALTER PUBLICATION supabase_realtime
        ADD TABLE public.spare_part_chat_messages;
    END IF;
  END IF;
END
$block$;

COMMIT;
