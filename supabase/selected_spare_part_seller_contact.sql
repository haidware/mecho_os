-- Run in the Supabase SQL Editor as an administrator after
-- shared_spare_part_chat_notifications.sql.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_selected_spare_part_seller_contact(
  p_request_id uuid
)
RETURNS TABLE (
  seller_name text,
  phone_number text,
  location text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT
    o.seller_name,
    COALESCE(
      NULLIF(btrim(o.phone_number), ''),
      NULLIF(btrim(u.phone_number), '')
    ),
    o.location
  FROM public.spare_part_requests AS r
  JOIN public.spare_part_offers AS o
    ON o.id = r.selected_offer_id
   AND o.request_id = r.id
  JOIN public.users AS u
    ON u.id = o.seller_user_id
  WHERE r.id = p_request_id
    AND r.mechanic_user_id::text = auth.uid()::text
    AND r.status = 'accepted'
    AND r.selected_offer_id IS NOT NULL
$function$;

REVOKE ALL ON FUNCTION
  public.get_selected_spare_part_seller_contact(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION
  public.get_selected_spare_part_seller_contact(uuid)
  TO authenticated;

COMMIT;
