-- Run in the Supabase SQL Editor as a database administrator.
-- Public tables without a recognized ownership path are denied client access.
BEGIN;

CREATE OR REPLACE FUNCTION public.current_user_workshop_ids()
RETURNS SETOF text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT u.workshop_id::text
  FROM public.users AS u
  WHERE u.id::text = auth.uid()::text
    AND u.workshop_id IS NOT NULL

  UNION

  SELECT w.id::text
  FROM public.workshops AS w
  WHERE w.owner_id::text = auth.uid()::text
$function$;

REVOKE ALL ON FUNCTION public.current_user_workshop_ids() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_workshop_ids() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.prevent_user_access_level_changes()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL
     AND (
       NEW.role IS DISTINCT FROM OLD.role
       OR NEW.status IS DISTINCT FROM OLD.status
     ) THEN
    RAISE EXCEPTION 'Only a trusted administrator can change user role or status';
  END IF;

  RETURN NEW;
END
$function$;

DO $block$
DECLARE
  target record;
  foreign_key record;
  join_condition text;
  read_condition text;
  write_condition text;
  has_workshop_id boolean;
  has_user_id boolean;
  has_owner_id boolean;
BEGIN
  FOR target IN
    SELECT table_class.relname AS table_name,
           table_class.oid AS table_oid,
           table_class.relrowsecurity AS row_security_enabled,
           COALESCE(bool_or(table_column.column_name = 'workshop_id'), false) AS has_workshop_id,
           COALESCE(bool_or(table_column.column_name = 'user_id'), false) AS has_user_id,
           COALESCE(bool_or(table_column.column_name = 'owner_id'), false) AS has_owner_id
    FROM pg_class AS table_class
    JOIN pg_namespace AS table_schema
      ON table_schema.oid = table_class.relnamespace
    LEFT JOIN information_schema.columns AS table_column
      ON table_column.table_schema = table_schema.nspname
     AND table_column.table_name = table_class.relname
    WHERE table_schema.nspname = 'public'
      AND table_class.relkind IN ('r', 'p')
      AND NOT table_class.relrowsecurity
    GROUP BY table_class.relname, table_class.oid, table_class.relrowsecurity
  LOOP
    has_workshop_id := target.has_workshop_id;
    has_user_id := target.has_user_id;
    has_owner_id := target.has_owner_id;
    read_condition := 'false';
    write_condition := 'false';

    IF target.table_name = 'users' THEN
      read_condition :=
        'id::text = auth.uid()::text OR ' ||
        'workshop_id::text IN (SELECT public.current_user_workshop_ids())';
      write_condition :=
        'id::text = auth.uid()::text AND ' ||
        '(workshop_id IS NULL OR ' ||
        'workshop_id::text IN (SELECT public.current_user_workshop_ids()))';

      EXECUTE
        'DROP TRIGGER IF EXISTS mecho_prevent_user_access_level_changes ' ||
        'ON public.users';
      EXECUTE
        'CREATE TRIGGER mecho_prevent_user_access_level_changes ' ||
        'BEFORE UPDATE ON public.users ' ||
        'FOR EACH ROW EXECUTE FUNCTION public.prevent_user_access_level_changes()';
      EXECUTE format(
        'ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',
        target.table_name
      );
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_guard ON public.%I ' ||
        'AS RESTRICTIVE FOR ALL TO public ' ||
        'USING (%s) WITH CHECK (%s)',
        target.table_name,
        read_condition,
        write_condition
      );
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_delete_guard ON public.%I ' ||
        'AS RESTRICTIVE FOR DELETE TO public USING (false)',
        target.table_name
      );
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_select ON public.%I ' ||
        'FOR SELECT TO authenticated USING (%s)',
        target.table_name,
        read_condition
      );
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_insert ON public.%I ' ||
        'FOR INSERT TO authenticated WITH CHECK (%s)',
        target.table_name,
        write_condition
      );
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_update ON public.%I ' ||
        'FOR UPDATE TO authenticated USING (id::text = auth.uid()::text) ' ||
        'WITH CHECK (%s)',
        target.table_name,
        write_condition
      );
      RAISE NOTICE 'Applied self/workshop policies to public.%', target.table_name;
      CONTINUE;
    END IF;

    IF target.table_name = 'workshops' THEN
      read_condition :=
        'id::text IN (SELECT public.current_user_workshop_ids()) OR ' ||
        'owner_id::text = auth.uid()::text';
      write_condition := 'owner_id::text = auth.uid()::text';

      EXECUTE format(
        'ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',
        target.table_name
      );
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_guard ON public.%I ' ||
        'AS RESTRICTIVE FOR ALL TO public ' ||
        'USING (%s) WITH CHECK (%s)',
        target.table_name,
        read_condition,
        write_condition
      );
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_delete_guard ON public.%I ' ||
        'AS RESTRICTIVE FOR DELETE TO public USING (false)',
        target.table_name
      );
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_select ON public.%I ' ||
        'FOR SELECT TO authenticated USING (%s)',
        target.table_name,
        read_condition
      );
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_insert ON public.%I ' ||
        'FOR INSERT TO authenticated WITH CHECK (%s)',
        target.table_name,
        write_condition
      );
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_update ON public.%I ' ||
        'FOR UPDATE TO authenticated USING (owner_id::text = auth.uid()::text) ' ||
        'WITH CHECK (%s)',
        target.table_name,
        write_condition
      );
      RAISE NOTICE 'Applied owner/workshop policies to public.%', target.table_name;
      CONTINUE;
    END IF;

    IF has_workshop_id THEN
      read_condition := format(
        '%I::text IN (SELECT public.current_user_workshop_ids())',
        'workshop_id'
      );
      write_condition := read_condition;

      IF has_user_id THEN
        write_condition := write_condition || format(
          ' AND %I::text = auth.uid()::text',
          'user_id'
        );
      END IF;
      IF has_owner_id THEN
        write_condition := write_condition || format(
          ' AND %I::text = auth.uid()::text',
          'owner_id'
        );
      END IF;
    ELSIF has_user_id THEN
      read_condition := 'user_id::text = auth.uid()::text';
      write_condition := read_condition;
    ELSIF has_owner_id THEN
      read_condition := 'owner_id::text = auth.uid()::text';
      write_condition := read_condition;
    ELSE
      FOR foreign_key IN
        SELECT constraint_row.oid AS constraint_oid,
               parent_class.relname AS parent_table
        FROM pg_constraint AS constraint_row
        JOIN pg_class AS parent_class
          ON parent_class.oid = constraint_row.confrelid
        JOIN pg_namespace AS parent_schema
          ON parent_schema.oid = parent_class.relnamespace
        WHERE constraint_row.contype = 'f'
          AND constraint_row.conrelid = target.table_oid
          AND parent_schema.nspname = 'public'
          AND EXISTS (
            SELECT 1
            FROM pg_attribute AS parent_column
            WHERE parent_column.attrelid = parent_class.oid
              AND parent_column.attname = 'workshop_id'
              AND NOT parent_column.attisdropped
          )
      LOOP
        SELECT string_agg(
                 format(
                   'parent.%I::text = public.%I.%I::text',
                   parent_column.attname,
                   target.table_name,
                   child_column.attname
                 ),
                 ' AND ' ORDER BY child_key.ordinality
               )
        INTO join_condition
        FROM pg_constraint AS constraint_row
        CROSS JOIN LATERAL unnest(constraint_row.conkey)
          WITH ORDINALITY AS child_key(attribute_number, ordinality)
        JOIN LATERAL unnest(constraint_row.confkey)
          WITH ORDINALITY AS parent_key(attribute_number, ordinality)
          USING (ordinality)
        JOIN pg_attribute AS child_column
          ON child_column.attrelid = constraint_row.conrelid
         AND child_column.attnum = child_key.attribute_number
        JOIN pg_attribute AS parent_column
          ON parent_column.attrelid = constraint_row.confrelid
         AND parent_column.attnum = parent_key.attribute_number
        WHERE constraint_row.oid = foreign_key.constraint_oid;

        IF join_condition IS NOT NULL THEN
          read_condition := concat(
            CASE WHEN read_condition = 'false' THEN '' ELSE read_condition || ' OR ' END,
            format(
              'EXISTS (SELECT 1 FROM public.%I AS parent WHERE %s ' ||
              'AND parent.workshop_id::text IN ' ||
              '(SELECT public.current_user_workshop_ids()))',
              foreign_key.parent_table,
              join_condition
            )
          );
        END IF;
      END LOOP;

      write_condition := read_condition;
    END IF;

    EXECUTE format(
      'ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',
      target.table_name
    );
    EXECUTE format(
      'CREATE POLICY mecho_workshop_scope_guard ON public.%I ' ||
      'AS RESTRICTIVE FOR ALL TO public ' ||
      'USING (%s) WITH CHECK (%s)',
      target.table_name,
      read_condition,
      write_condition
    );
    EXECUTE format(
      'CREATE POLICY mecho_workshop_scope_delete_guard ON public.%I ' ||
      'AS RESTRICTIVE FOR DELETE TO public USING (%s)',
      target.table_name,
      write_condition
    );

    IF read_condition <> 'false' THEN
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_select ON public.%I ' ||
        'FOR SELECT TO authenticated USING (%s)',
        target.table_name,
        read_condition
      );
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_insert ON public.%I ' ||
        'FOR INSERT TO authenticated WITH CHECK (%s)',
        target.table_name,
        write_condition
      );
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_update ON public.%I ' ||
        'FOR UPDATE TO authenticated USING (%s) WITH CHECK (%s)',
        target.table_name,
        read_condition,
        write_condition
      );
      EXECUTE format(
        'CREATE POLICY mecho_workshop_scope_delete ON public.%I ' ||
        'FOR DELETE TO authenticated USING (%s)',
        target.table_name,
        write_condition
      );
    ELSE
      RAISE NOTICE
        'Enabled RLS with no client access policy on public.%; add an explicit ownership policy if this table should be accessible',
        target.table_name;
    END IF;

    IF read_condition <> 'false' THEN
      RAISE NOTICE 'Applied workshop-scoped policies to public.%', target.table_name;
    END IF;
  END LOOP;
END
$block$;

DO $block$
DECLARE
  view_name text;
  view_oid oid;
BEGIN
  FOREACH view_name IN ARRAY ARRAY[
    'active_job_balance',
    'active_job_balances',
    'customer_financial_summary',
    'workshop_daily_accounting',
    'workshop_revenue_breakdown'
  ]
  LOOP
    SELECT table_class.oid
    INTO view_oid
    FROM pg_class AS table_class
    JOIN pg_namespace AS table_schema
      ON table_schema.oid = table_class.relnamespace
    WHERE table_schema.nspname = 'public'
      AND table_class.relname = view_name
      AND table_class.relkind = 'v';

    IF view_oid IS NULL THEN
      RAISE NOTICE 'View public.% does not exist; skipped', view_name;
      CONTINUE;
    END IF;

    EXECUTE format(
      'ALTER VIEW public.%I SET (security_invoker = true)',
      view_name
    );
    EXECUTE format('REVOKE ALL ON public.%I FROM anon', view_name);
    EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC', view_name);
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', view_name);

    RAISE NOTICE
      'Secured view public.% with caller permissions and authenticated-only access',
      view_name;
  END LOOP;
END
$block$;

COMMIT;
