-- Run in the Supabase SQL Editor as a database administrator.
-- The Render seller-admin API uses the service-role key to call these functions.
BEGIN;

CREATE TABLE IF NOT EXISTS public.spare_part_seller_signup_ids (
  id_hash text PRIMARY KEY
    CHECK (id_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  used_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  used_at timestamptz
);

ALTER TABLE public.spare_part_seller_signup_ids ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.spare_part_seller_signup_ids FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_spare_part_seller_id(p_id_hash text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Only the trusted seller admin API can create seller IDs';
  END IF;

  INSERT INTO public.spare_part_seller_signup_ids (id_hash)
  VALUES (p_id_hash)
  ON CONFLICT (id_hash) DO NOTHING;

  RETURN FOUND;
END
$function$;

CREATE OR REPLACE FUNCTION public.is_spare_part_seller_id_available(
  p_id_hash text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT auth.role() = 'service_role'
    AND EXISTS (
      SELECT 1
      FROM public.spare_part_seller_signup_ids AS signup_id
      WHERE signup_id.id_hash = p_id_hash
        AND signup_id.used_by IS NULL
        AND signup_id.used_at IS NULL
    )
$function$;

CREATE OR REPLACE FUNCTION public.redeem_spare_part_seller_id(
  p_id_hash text,
  p_user_id uuid,
  p_full_name text,
  p_email text,
  p_phone_number text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Only the trusted seller admin API can redeem seller IDs';
  END IF;

  UPDATE public.spare_part_seller_signup_ids
  SET used_by = p_user_id,
      used_at = now()
  WHERE id_hash = p_id_hash
    AND used_by IS NULL
    AND used_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Seller ID is invalid or has already been used'
      USING ERRCODE = 'unique_violation';
  END IF;

  INSERT INTO public.users (
    id,
    full_name,
    email,
    phone_number,
    role,
    status,
    workshop_id
  )
  VALUES (
    p_user_id,
    p_full_name,
    p_email,
    p_phone_number,
    'spare_part_seller',
    'active',
    NULL
  );
END
$function$;

REVOKE ALL ON FUNCTION public.create_spare_part_seller_id(text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_spare_part_seller_id_available(text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.redeem_spare_part_seller_id(
  text, uuid, text, text, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_spare_part_seller_id(text)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.is_spare_part_seller_id_available(text)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.redeem_spare_part_seller_id(
  text, uuid, text, text, text
) TO service_role;

COMMIT;
