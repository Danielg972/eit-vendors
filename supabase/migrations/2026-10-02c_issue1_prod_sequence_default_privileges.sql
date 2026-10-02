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
-- matches the 2 Oct 2026 read-only snapshot, and rolls back unless the post-state is exactly as intended. NOT safe to run
-- twice by design: a second run stops at the precondition and changes nothing.
-- Rollback is deliberately not a migration; it is in the PR description for issue #1.

-- Issue #1 production hardening (sequences + postgres default privileges in public). One transaction.
-- Guards: aborts unless the pre-state is exactly what the 2 Oct 2026 snapshot showed, and aborts (rolls back)
-- unless the post-state is exactly what is intended. Touches nothing else.
begin;

do $pre$
begin
  if not (has_sequence_privilege('anon','public.action_log_id_seq','usage')
      and has_sequence_privilege('authenticated','public.filter_log_id_seq','usage')) then
    raise exception 'PRECONDITION FAILED: sequence grants are not in the expected pre-change state';
  end if;
  if (select count(*) from pg_default_acl d
       where d.defaclrole = 'postgres'::regrole and d.defaclnamespace = 'public'::regnamespace
         and d.defaclacl::text ~ '(^|[{,])(anon|authenticated)=') <> 3 then
    raise exception 'PRECONDITION FAILED: postgres default ACLs in public are not in the expected pre-change state';
  end if;
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
