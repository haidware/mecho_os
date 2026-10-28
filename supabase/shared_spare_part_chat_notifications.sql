-- Run in the Supabase SQL Editor as an administrator after the marketplace
-- setup. Adds shared request conversations and notification delivery without
-- modifying existing requests, offers, or private chats.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.spare_part_request_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL
    REFERENCES public.spare_part_requests(id) ON DELETE CASCADE,
  sender_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_name text NOT NULL DEFAULT '',
  sender_location text NOT NULL DEFAULT '',
  message_type text NOT NULL DEFAULT 'message'
    CHECK (message_type IN ('message', 'offer')),
  offer_id uuid REFERENCES public.spare_part_offers(id) ON DELETE CASCADE,
  offer_price numeric(12, 2),
  offer_condition text,
  message text NOT NULL
    CHECK (char_length(btrim(message)) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT spare_part_request_messages_offer_shape_check CHECK (
    (message_type = 'message' AND offer_id IS NULL)
    OR (
      message_type = 'offer'
      AND offer_id IS NOT NULL
      AND offer_price > 0
      AND offer_condition IS NOT NULL
    )
  )
);

CREATE INDEX IF NOT EXISTS spare_part_request_messages_feed_idx
  ON public.spare_part_request_messages (request_id, created_at);

CREATE TABLE IF NOT EXISTS public.spare_part_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  request_id uuid REFERENCES public.spare_part_requests(id) ON DELETE CASCADE,
  seller_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  notification_type text NOT NULL
    CHECK (notification_type IN (
      'new_request',
      'request_message',
      'new_offer',
      'offer_accepted',
      'private_message'
    )),
  title text NOT NULL,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz
);

CREATE INDEX IF NOT EXISTS spare_part_notifications_unread_idx
  ON public.spare_part_notifications (user_id, created_at DESC)
  WHERE read_at IS NULL;

CREATE TABLE IF NOT EXISTS public.spare_part_push_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint text NOT NULL UNIQUE,
  p256dh text NOT NULL,
  auth text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.spare_part_request_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spare_part_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spare_part_push_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.can_access_spare_part_request_thread(
  p_request_id uuid
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
    WHERE r.id = p_request_id
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
          r.status = 'open'
          AND public.is_active_spare_part_seller()
        )
      )
  )
$function$;

CREATE OR REPLACE FUNCTION public.prepare_spare_part_request_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  request_row public.spare_part_requests%ROWTYPE;
  sender_profile public.users%ROWTYPE;
BEGIN
  SELECT *
  INTO request_row
  FROM public.spare_part_requests
  WHERE id = NEW.request_id;

  IF NOT FOUND OR request_row.status <> 'open' THEN
    RAISE EXCEPTION 'This request thread is no longer open';
  END IF;

  IF NEW.message_type = 'offer' THEN
    SELECT *
    INTO sender_profile
    FROM public.users AS u
    WHERE u.id = NEW.sender_user_id
      AND u.role = 'spare_part_seller'
      AND u.status = 'active'
      AND EXISTS (
        SELECT 1
        FROM public.spare_part_offers AS o
        WHERE o.id = NEW.offer_id
          AND o.request_id = NEW.request_id
          AND o.seller_user_id = NEW.sender_user_id
          AND o.price = NEW.offer_price
          AND o.condition = NEW.offer_condition
      );
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Offer message must match an active seller offer';
    END IF;
    NEW.sender_name := sender_profile.full_name;
    SELECT o.location
    INTO NEW.sender_location
    FROM public.spare_part_offers AS o
    WHERE o.id = NEW.offer_id;
    RETURN NEW;
  END IF;

  IF NEW.sender_user_id::text <> auth.uid()::text THEN
    RAISE EXCEPTION 'Messages must be sent by the signed-in user';
  END IF;

  IF request_row.mechanic_user_id::text = auth.uid()::text THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.users AS u
      WHERE u.id::text = auth.uid()::text
        AND u.status = 'active'
    ) THEN
      RAISE EXCEPTION 'An active account is required to send a message';
    END IF;
    NEW.sender_name := request_row.mechanic_name;
    NEW.sender_location := request_row.location;
  ELSE
    SELECT *
    INTO sender_profile
    FROM public.users
    WHERE id::text = auth.uid()::text
      AND role = 'spare_part_seller'
      AND status = 'active';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'An active spare-part seller account is required';
    END IF;
    NEW.sender_name := sender_profile.full_name;
    SELECT o.location
    INTO NEW.sender_location
    FROM public.spare_part_offers AS o
    WHERE o.request_id = NEW.request_id
      AND o.seller_user_id::text = auth.uid()::text
    ORDER BY o.updated_at DESC
    LIMIT 1;
    NEW.sender_location := COALESCE(NEW.sender_location, 'Location not provided');
  END IF;

  RETURN NEW;
END
$function$;

CREATE OR REPLACE FUNCTION public.create_spare_part_offer_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  profile_name text;
BEGIN
  SELECT u.full_name
  INTO profile_name
  FROM public.users AS u
  WHERE u.id = NEW.seller_user_id
    AND u.role = 'spare_part_seller'
    AND u.status = 'active';

  IF profile_name IS NULL THEN
    RAISE EXCEPTION 'An active spare-part seller account is required';
  END IF;

  INSERT INTO public.spare_part_request_messages (
    request_id,
    sender_user_id,
    sender_name,
    sender_location,
    message_type,
    offer_id,
    offer_price,
    offer_condition,
    message
  )
  VALUES (
    NEW.request_id,
    NEW.seller_user_id,
    profile_name,
    NEW.location,
    'offer',
    NEW.id,
    NEW.price,
    NEW.condition,
    'Seller submitted an offer'
  );
  RETURN NEW;
END
$function$;

CREATE OR REPLACE FUNCTION public.notify_spare_part_request_opened()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NEW.status = 'open' AND OLD.status = 'draft' THEN
    INSERT INTO public.spare_part_notifications (
      user_id,
      request_id,
      notification_type,
      title,
      body
    )
    SELECT u.id, NEW.id, 'new_request', 'New part request',
      NEW.part_name || ' requested near ' || NEW.location
    FROM public.users AS u
    WHERE u.role = 'spare_part_seller'
      AND u.status = 'active';
  ELSIF NEW.status = 'accepted' AND OLD.status = 'open'
    AND NEW.selected_offer_id IS NOT NULL THEN
    INSERT INTO public.spare_part_notifications (
      user_id,
      request_id,
      seller_user_id,
      notification_type,
      title,
      body
    )
    SELECT o.seller_user_id, NEW.id, o.seller_user_id,
      'offer_accepted', 'Your offer was accepted',
      NEW.part_name || ' — continue the private chat with the mechanic.'
    FROM public.spare_part_offers AS o
    WHERE o.id = NEW.selected_offer_id
      AND o.request_id = NEW.id;
  END IF;
  RETURN NEW;
END
$function$;

CREATE OR REPLACE FUNCTION public.notify_spare_part_request_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  request_owner uuid;
  notification_kind text;
  notification_title text;
  notification_body text;
BEGIN
  SELECT r.mechanic_user_id
  INTO request_owner
  FROM public.spare_part_requests AS r
  WHERE r.id = NEW.request_id;

  IF NEW.message_type = 'offer' THEN
    notification_kind := 'new_offer';
    notification_title := 'New seller offer';
    notification_body := NEW.sender_name || ' offered ' ||
      NEW.offer_condition || ' for ' ||
      to_char(NEW.offer_price, 'FM999,999,999,990.00');
    INSERT INTO public.spare_part_notifications (
      user_id, request_id, seller_user_id, notification_type, title, body
    )
    SELECT u.id, NEW.request_id, NEW.sender_user_id,
      notification_kind, notification_title, notification_body
    FROM public.users AS u
    WHERE u.status = 'active'
      AND (
        u.id = request_owner
        OR u.role = 'spare_part_seller'
      )
      AND u.id <> NEW.sender_user_id;
  ELSE
    notification_kind := 'request_message';
    notification_title := 'New request chat message';
    notification_body := NEW.sender_name || ': ' || NEW.message;
    INSERT INTO public.spare_part_notifications (
      user_id, request_id, seller_user_id, notification_type, title, body
    )
    SELECT u.id, NEW.request_id, NEW.sender_user_id,
      notification_kind, notification_title, notification_body
    FROM public.users AS u
    WHERE u.status = 'active'
      AND (
        u.id = request_owner
        OR u.role = 'spare_part_seller'
      )
      AND u.id <> NEW.sender_user_id;
  END IF;
  RETURN NEW;
END
$function$;

CREATE OR REPLACE FUNCTION public.notify_spare_part_private_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  request_owner uuid;
  recipient_id uuid;
  sender_name text;
BEGIN
  SELECT r.mechanic_user_id
  INTO request_owner
  FROM public.spare_part_requests AS r
  WHERE r.id = NEW.request_id;

  recipient_id := CASE
    WHEN NEW.sender_user_id = request_owner THEN NEW.seller_user_id
    ELSE request_owner
  END;

  SELECT u.full_name INTO sender_name
  FROM public.users AS u
  WHERE u.id = NEW.sender_user_id;

  INSERT INTO public.spare_part_notifications (
    user_id,
    request_id,
    seller_user_id,
    notification_type,
    title,
    body
  )
  VALUES (
    recipient_id,
    NEW.request_id,
    NEW.seller_user_id,
    'private_message',
    'New private message',
    COALESCE(sender_name, 'Marketplace user') || ': ' || NEW.message
  );
  RETURN NEW;
END
$function$;

CREATE OR REPLACE FUNCTION public.send_spare_part_push_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  webhook_secret text;
  http_schema text;
BEGIN
  SELECT decrypted_secret
  INTO webhook_secret
  FROM vault.decrypted_secrets
  WHERE name = 'mecho_push_webhook_secret'
  LIMIT 1;

  IF webhook_secret IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.spare_part_push_subscriptions AS s
    WHERE s.user_id = NEW.user_id
  ) THEN
    SELECT n.nspname
    INTO http_schema
    FROM pg_catalog.pg_proc AS p
    JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
    WHERE p.proname = 'http_post'
      AND n.nspname IN ('net', 'extensions')
    ORDER BY CASE n.nspname WHEN 'net' THEN 0 ELSE 1 END
    LIMIT 1;

    IF http_schema IS NULL THEN
      RAISE EXCEPTION 'pg_net http_post function is unavailable';
    END IF;

    EXECUTE format(
      'SELECT %I.http_post(url := $1, headers := $2, body := $3, timeout_milliseconds := $4)',
      http_schema
    )
    USING
      'https://mecho-os-seller-admin-api.onrender.com/notifications/push',
      jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Mecho-Push-Secret', webhook_secret
      ),
      jsonb_build_object('notificationId', NEW.id),
      5000;
  END IF;
  RETURN NEW;
END
$function$;

DROP TRIGGER IF EXISTS spare_part_request_messages_prepare
  ON public.spare_part_request_messages;
CREATE TRIGGER spare_part_request_messages_prepare
  BEFORE INSERT ON public.spare_part_request_messages
  FOR EACH ROW EXECUTE FUNCTION public.prepare_spare_part_request_message();

DROP TRIGGER IF EXISTS spare_part_offers_publish_message
  ON public.spare_part_offers;
CREATE TRIGGER spare_part_offers_publish_message
  AFTER INSERT
  ON public.spare_part_offers
  FOR EACH ROW EXECUTE FUNCTION public.create_spare_part_offer_message();

DROP TRIGGER IF EXISTS spare_part_offers_update_message
  ON public.spare_part_offers;
CREATE TRIGGER spare_part_offers_update_message
  AFTER UPDATE OF price, condition, location
  ON public.spare_part_offers
  FOR EACH ROW
  WHEN (
    OLD.price IS DISTINCT FROM NEW.price
    OR OLD.condition IS DISTINCT FROM NEW.condition
    OR OLD.location IS DISTINCT FROM NEW.location
  )
  EXECUTE FUNCTION public.create_spare_part_offer_message();

DROP TRIGGER IF EXISTS spare_part_requests_notify_opened
  ON public.spare_part_requests;
CREATE TRIGGER spare_part_requests_notify_opened
  AFTER UPDATE OF status ON public.spare_part_requests
  FOR EACH ROW EXECUTE FUNCTION public.notify_spare_part_request_opened();

DROP TRIGGER IF EXISTS spare_part_request_messages_notify
  ON public.spare_part_request_messages;
CREATE TRIGGER spare_part_request_messages_notify
  AFTER INSERT ON public.spare_part_request_messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_spare_part_request_message();

DROP TRIGGER IF EXISTS spare_part_private_messages_notify
  ON public.spare_part_chat_messages;
CREATE TRIGGER spare_part_private_messages_notify
  AFTER INSERT ON public.spare_part_chat_messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_spare_part_private_message();

DROP TRIGGER IF EXISTS spare_part_notifications_push
  ON public.spare_part_notifications;
CREATE TRIGGER spare_part_notifications_push
  AFTER INSERT ON public.spare_part_notifications
  FOR EACH ROW EXECUTE FUNCTION public.send_spare_part_push_notification();

DROP POLICY IF EXISTS spare_part_offers_select
  ON public.spare_part_offers;
CREATE POLICY spare_part_offers_select
  ON public.spare_part_offers
  FOR SELECT TO authenticated
  USING (
    seller_user_id::text = auth.uid()::text
    OR (
      public.is_active_spare_part_seller()
      AND EXISTS (
        SELECT 1
        FROM public.spare_part_requests AS r
        WHERE r.id = request_id
          AND r.status = 'open'
      )
    )
    OR (
      public.can_view_spare_part_request(request_id)
      AND EXISTS (
        SELECT 1
        FROM public.spare_part_requests AS r
        WHERE r.id = request_id
          AND r.mechanic_user_id::text = auth.uid()::text
      )
    )
  );

REVOKE SELECT ON public.spare_part_offers FROM authenticated;
GRANT SELECT (
  id, request_id, seller_user_id, price, condition, location, seller_name,
  created_at, updated_at
) ON public.spare_part_offers TO authenticated;

DROP POLICY IF EXISTS spare_part_request_messages_select
  ON public.spare_part_request_messages;
CREATE POLICY spare_part_request_messages_select
  ON public.spare_part_request_messages
  FOR SELECT TO authenticated
  USING (public.can_access_spare_part_request_thread(request_id));

DROP POLICY IF EXISTS spare_part_request_messages_insert
  ON public.spare_part_request_messages;
CREATE POLICY spare_part_request_messages_insert
  ON public.spare_part_request_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_user_id::text = auth.uid()::text
    AND message_type = 'message'
    AND public.can_access_spare_part_request_thread(request_id)
  );

DROP POLICY IF EXISTS spare_part_notifications_select
  ON public.spare_part_notifications;
CREATE POLICY spare_part_notifications_select
  ON public.spare_part_notifications
  FOR SELECT TO authenticated
  USING (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS spare_part_notifications_update
  ON public.spare_part_notifications;
CREATE POLICY spare_part_notifications_update
  ON public.spare_part_notifications
  FOR UPDATE TO authenticated
  USING (user_id::text = auth.uid()::text)
  WITH CHECK (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS spare_part_push_subscriptions_select
  ON public.spare_part_push_subscriptions;
CREATE POLICY spare_part_push_subscriptions_select
  ON public.spare_part_push_subscriptions
  FOR SELECT TO authenticated
  USING (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS spare_part_push_subscriptions_insert
  ON public.spare_part_push_subscriptions;
CREATE POLICY spare_part_push_subscriptions_insert
  ON public.spare_part_push_subscriptions
  FOR INSERT TO authenticated
  WITH CHECK (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS spare_part_push_subscriptions_update
  ON public.spare_part_push_subscriptions;
CREATE POLICY spare_part_push_subscriptions_update
  ON public.spare_part_push_subscriptions
  FOR UPDATE TO authenticated
  USING (user_id::text = auth.uid()::text)
  WITH CHECK (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS spare_part_push_subscriptions_delete
  ON public.spare_part_push_subscriptions;
CREATE POLICY spare_part_push_subscriptions_delete
  ON public.spare_part_push_subscriptions
  FOR DELETE TO authenticated
  USING (user_id::text = auth.uid()::text);

REVOKE ALL ON FUNCTION public.can_access_spare_part_request_thread(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_access_spare_part_request_thread(uuid)
  TO authenticated;
GRANT SELECT, INSERT ON public.spare_part_request_messages TO authenticated;
GRANT SELECT, UPDATE ON public.spare_part_notifications TO authenticated;
REVOKE UPDATE ON public.spare_part_notifications FROM authenticated;
GRANT UPDATE (read_at)
  ON public.spare_part_notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.spare_part_push_subscriptions TO authenticated;

DO $block$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'spare_part_request_messages'
    ) THEN
      ALTER PUBLICATION supabase_realtime
        ADD TABLE public.spare_part_request_messages;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'spare_part_notifications'
    ) THEN
      ALTER PUBLICATION supabase_realtime
        ADD TABLE public.spare_part_notifications;
    END IF;
  END IF;
END
$block$;

COMMIT;
