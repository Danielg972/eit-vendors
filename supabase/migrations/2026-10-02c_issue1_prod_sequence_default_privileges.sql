-- Issue #1 production privilege hardening (2 Oct 2026). Brings live production in line with the already-merged Issue #1
-- schema baseline (PR #4): supabase/schema.sql already contains this end state, so schema.sql is NOT changed by this file.
-- Scope, and nothing else:
--   * revoke anon/authenticated from the two live identity sequences public.action_log_id_seq and public.filter_log_id_seq
--     (service_role and the owner keep rwU; identity-column inserts need no sequence privilege);
--   * revoke the direct anon/authenticated default grants that postgres has in schema public for future tables,
--     sequences and functions. PostgreSQL's built-in PUBLIC EXECUTE on new functions remains, so new RPCs/helpers still
--     need their explicit `revoke ... from public` (and explicit grants for RPCs).
-- Out of scope: supabase_admin default privileges, existing table and function privileges, RLS, function bodies, storage.
-- Run as postgres (the Supabase SQL editor / MCP role). Single transaction: it aborts with no change unless the pre-state
-- matches the 2 Oct 2026 read-only snapshot, and rolls back unless the post-state is exactly as intended.
-- Re-running: safe in that it changes nothing, but NOT idempotent. A second run (or any run after drift) intentionally
-- exits with a PRECONDITION FAILED error instead of succeeding.
-- Rollback is deliberately not a migration; it is in the PR description for issue #1.

-- Issue #1 production hardening (sequences + postgres default privileges in public). One transaction.
-- Guards: aborts unless the pre-state is exactly what the 2 Oct 2026 snapshot showed, and aborts (rolls back)
-- unless the post-state is exactly what is intended. Touches nothing else.
begin;

do $pre$
-- Refuses to run unless production still matches the reviewed 2 Oct 2026 snapshot exactly:
--  (1) anon and authenticated have USAGE, SELECT and UPDATE on both sequences;
--  (2) service_role has USAGE, SELECT and UPDATE on both sequences;
--  (3) postgres's default ACLs in public give anon and authenticated exactly the full privilege set for tables
--      (arwdDxtm on PG17), sequences (rwU) and functions (X), granted by postgres, without grant option.
--      "Full set" is taken from acldefault() for the owner, so it is exact for the running server version.
declare
  seq text; rol text; typ "char"; got text[]; want text[];
begin
  foreach seq in array array['public.action_log_id_seq','public.filter_log_id_seq'] loop
    foreach rol in array array['anon','authenticated','service_role'] loop
      if not (has_sequence_privilege(rol, seq, 'usage') and has_sequence_privilege(rol, seq, 'select')
              and has_sequence_privilege(rol, seq, 'update')) then
        raise exception 'PRECONDITION FAILED: % does not have USAGE, SELECT and UPDATE on %', rol, seq;
      end if;
    end loop;
  end loop;

  foreach typ in array array['r','S','f']::"char"[] loop
    -- pg_default_acl uses 'S' for sequences; acldefault() uses 's' ('S' there means foreign server).
    select array_agg(e.privilege_type order by e.privilege_type) into want
      from aclexplode(acldefault(case typ when 'S' then 's'::"char" else typ end, 'postgres'::regrole)) e
     where e.grantee = 'postgres'::regrole;
    foreach rol in array array['anon','authenticated'] loop
      select array_agg(e.privilege_type order by e.privilege_type) into got
        from pg_default_acl d, aclexplode(d.defaclacl) e
       where d.defaclrole = 'postgres'::regrole and d.defaclnamespace = 'public'::regnamespace
         and d.defaclobjtype = typ and e.grantee = rol::regrole
         and e.grantor = 'postgres'::regrole and not e.is_grantable;
      if got is distinct from want then
        raise exception 'PRECONDITION FAILED: postgres default ACL (%) in public for % is %, expected %', typ, rol, got, want;
      end if;
    end loop;
  end loop;
end $pre$;

-- 1. Existing sequences: remove anon/authenticated (service_role and the owner keep rwU).
revoke all on sequence public.action_log_id_seq, public.filter_log_id_seq from anon, authenticated;

-- 2. Future objects postgres creates in public: drop the direct anon/authenticated default grants.
--    (supabase_admin defaults deliberately untouched. PostgreSQL's built-in PUBLIC EXECUTE on new functions remains.)
alter default privileges for role postgres in schema public revoke all on tables    from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on functions from anon, authenticated;

do $post$
begin
  if exists (select 1 from pg_class c, unnest(array['anon','authenticated']) r
             where c.relnamespace='public'::regnamespace and c.relkind='S'
               and (has_sequence_privilege(r,c.oid,'usage') or has_sequence_privilege(r,c.oid,'select') or has_sequence_privilege(r,c.oid,'update'))) then
    raise exception 'POSTCONDITION FAILED: anon/authenticated still have sequence privileges';
  end if;
  if exists (select 1 from pg_class c
             where c.relnamespace='public'::regnamespace and c.relkind='S'
               and not (has_sequence_privilege('service_role',c.oid,'usage') and has_sequence_privilege('service_role',c.oid,'select') and has_sequence_privilege('service_role',c.oid,'update'))) then
    raise exception 'POSTCONDITION FAILED: service_role lost sequence privileges';
  end if;
  if exists (select 1 from pg_default_acl d
             where d.defaclrole='postgres'::regrole and d.defaclnamespace='public'::regnamespace
               and d.defaclacl::text ~ '(^|[{,])(anon|authenticated)=') then
    raise exception 'POSTCONDITION FAILED: postgres default ACLs in public still grant anon/authenticated';
  end if;
end $post$;

commit;
