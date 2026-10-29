-- Run in the Supabase SQL Editor as an administrator.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_spare_part_request_seller_contacts(
  p_request_id uuid
)
RETURNS TABLE (
  offer_id uuid,
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
    o.id,
    o.seller_name,
    COALESCE(
      NULLIF(btrim(o.phone_number), ''),
      NULLIF(btrim(u.phone_number), '')
    ),
    o.location
  FROM public.spare_part_requests AS r
  JOIN public.spare_part_offers AS o
    ON o.request_id = r.id
  JOIN public.users AS u
    ON u.id = o.seller_user_id
  WHERE r.id = p_request_id
    AND r.mechanic_user_id::text = auth.uid()::text
$function$;

REVOKE ALL ON FUNCTION
  public.get_spare_part_request_seller_contacts(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION
  public.get_spare_part_request_seller_contacts(uuid)
  TO authenticated;

COMMIT;
