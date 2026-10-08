#!/bin/bash
# Hikes (D-31): the checks for supabase/migrations/2026-10-08_hikes.sql.
# Needs a local Postgres 16 (PGHOST, PGPORT, PGUSER set), psql and python3. Run after ../limited_members/run.sh has passed.
# Builds two databases: one from supabase/schema.sql, and one from the schema as it was before D-31 (pass that file
# as $1, e.g. from `git show main:supabase/schema.sql` taken before the change) with the migration run on top, twice.
# Compares every function and the three new tables between the two, then runs the checks as Eretz Israel Tours,
# two guides and an organisation. Prints only the failures and the total.
set -e
cd "$(dirname "$0")"; R=../../..; OLD=${1:?give the schema.sql from before D-31}
for DB in eitv_hk_new eitv_hk_mig; do psql -q -d postgres -c "drop database if exists $DB" -c "create database $DB" 2>/dev/null; psql -q -d $DB -f ../limited_members/local_base.sql; done
psql -q -v ON_ERROR_STOP=1 -d eitv_hk_new -f $R/supabase/schema.sql 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true
psql -q -v ON_ERROR_STOP=1 -d eitv_hk_mig -f "$OLD" 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true
for DB in eitv_hk_new eitv_hk_mig; do psql -q -d $DB -f ../limited_members/seed.sql > /dev/null; done
for i in 1 2; do psql -q -v ON_ERROR_STOP=1 -d eitv_hk_mig -f $R/supabase/migrations/2026-10-08_hikes.sql 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true; done
python3 probe.py | grep -v "^PASS"
