#!/bin/bash
# D-62 (online links) and D-63 (Hebrew name and contact): the checks for supabase/migrations/2026-10-25_online_links_hebrew_names.sql.
# Needs a local Postgres 16 you can create databases on (PGHOST, PGPORT, PGUSER set), psql and python3.
# 1. Builds one database from supabase/schema.sql as it was on main before this change (git show f549dd1:supabase/schema.sql)
#    and runs the migration on it twice; builds another from supabase/schema.sql as it is now; the two must be the same in
#    every function, column, constraint and privilege (G3).
# 2. Runs the rolled-back probe (production_probe.sql) on the new build, and the checks in probe.py on the sample data of
#    ../limited_members/seed.sql (as Eretz Israel Tours, a guide and an organisation).
# 3. Prints the function count and checks supabase/tests/production_fingerprints.txt against the new build.
set -e
cd "$(dirname "$0")"; R=../../..; NEW=${1:-eitv_olh_test}; MIG=${NEW}_mig
OLD=$(mktemp); git -C $R show f549dd1:supabase/schema.sql > $OLD
for DB in $NEW $MIG; do psql -q -d postgres -c "drop database if exists $DB" -c "create database $DB" 2>&1 | grep -v NOTICE || true; psql -q -d $DB -f ../limited_members/local_base.sql; done
psql -q -v ON_ERROR_STOP=1 -d $NEW -f $R/supabase/schema.sql 2>&1 | grep -v "^NOTICE\|skipping\|^psql.*NOTICE" | head -5 || true
psql -q -v ON_ERROR_STOP=1 -d $MIG -f $OLD 2>&1 | grep -v "^NOTICE\|skipping\|^psql.*NOTICE" | head -5 || true
for i in 1 2; do psql -q -v ON_ERROR_STOP=1 -d $MIG -f $R/supabase/migrations/2026-10-25_online_links_hebrew_names.sql 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true; done
rm -f $OLD
same=0
for Q in "select string_agg(p.proname||':'||md5(replace(pg_get_functiondef(p.oid), E'\r','')), ' ' order by p.proname, pg_get_function_identity_arguments(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'" \
         "select string_agg(table_name||'.'||column_name||':'||data_type||':'||coalesce(column_default,'')||':'||is_nullable, ' ' order by table_name, column_name) from information_schema.columns where table_schema='public'" \
         "select string_agg(conrelid::regclass||'.'||conname||':'||md5(pg_get_constraintdef(oid)), ' ' order by conrelid::regclass::text, conname) from pg_constraint where connamespace='public'::regnamespace" \
         "select string_agg(p.proname||'('||pg_get_function_identity_arguments(p.oid)||'):'||coalesce(p.proacl::text,'default'), ' ' order by p.proname, pg_get_function_identity_arguments(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'" \
         "select string_agg(c.relname||':'||coalesce(c.relacl::text,'')||':'||c.relrowsecurity, ' ' order by c.relname) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','S')"; do
  [ "$(psql -qAt -d $NEW -c "$Q")" == "$(psql -qAt -d $MIG -c "$Q")" ] && same=$((same+1))
done
echo "schema record = main + migration (twice): $same of 5 the same (functions, columns, constraints, function rights, table rights)"
echo "functions: $(psql -qAt -d $MIG -c "select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'") (main had 197)"
psql -qAt -d $NEW -f production_probe.sql 2>&1 | sed -n 's/.*PROBE //p' | python3 -c "import json,sys; r=json.loads(sys.stdin.read()); print('probe:', r['checks'], 'checks, failed:', r['failed']); print('fingerprints:', r['fingerprints'])"
FP="select string_agg(p.proname||':'||left(md5(replace(pg_get_functiondef(p.oid), E'\r','')),6), ' ' order by p.proname, pg_get_function_identity_arguments(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'"
[ "$(psql -qAt -d $NEW -c "$FP")" == "$(grep -v '^#' ../production_fingerprints.txt | head -1)" ] && echo "production_fingerprints.txt equals this build" || echo "production_fingerprints.txt DIFFERS from this build"
psql -q -d $NEW -f ../limited_members/seed.sql > /dev/null
python3 probe.py $NEW | grep -v "^PASS"
