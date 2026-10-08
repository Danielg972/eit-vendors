#!/bin/bash
# Hikes (D-31) and hikes with parks (D-32): the checks for supabase/migrations/2026-10-08_hikes.sql,
# 2026-10-08b_hikes_parks.sql and 2026-10-08c_brochure_kind.sql.
# Needs a local Postgres 16 (PGHOST, PGPORT, PGUSER set), psql and python3. Run after ../limited_members/run.sh has passed.
# Give it two files:
#   $1 = schema.sql as it was before D-31    (git show 6d9d5e9^:supabase/schema.sql)
#   $2 = schema.sql as it was before D-32    (git show 2727df7:supabase/schema.sql, the main branch of 8 Oct 2026)
# Builds three databases:
#   eitv_hk_new    from supabase/schema.sql as it is now
#   eitv_hk_mig    from $1, then the hikes file twice, then files b and c, each twice, b first
#   eitv_hk_main   from $2 and nothing else. probe.py first checks what is true before D-32 on it (a Brochure is
#                  refused), then runs file c twice and file b twice on it, in the go-live order, and compares.
# probe.py compares every function, every table's columns, constraints and indexes, and every privilege between the
# three, then runs the checks as Eretz Israel Tours, two guides and two organisations. Prints only the failures and the total.
set -e
cd "$(dirname "$0")"; R=../../..; OLD=${1:?give the schema.sql from before D-31}; MAIN=${2:?give the schema.sql from before D-32}
M=$R/supabase/migrations
for DB in eitv_hk_new eitv_hk_mig eitv_hk_main; do psql -q -d postgres -c "drop database if exists $DB" -c "create database $DB" 2>/dev/null; psql -q -d $DB -f ../limited_members/local_base.sql; done
psql -q -v ON_ERROR_STOP=1 -d eitv_hk_new -f $R/supabase/schema.sql 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true
psql -q -v ON_ERROR_STOP=1 -d eitv_hk_mig -f "$OLD" 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true
psql -q -v ON_ERROR_STOP=1 -d eitv_hk_main -f "$MAIN" 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true
for DB in eitv_hk_new eitv_hk_mig eitv_hk_main; do psql -q -d $DB -f ../limited_members/seed.sql > /dev/null; done
for i in 1 2; do psql -q -v ON_ERROR_STOP=1 -d eitv_hk_mig -f $M/2026-10-08_hikes.sql 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true; done
for i in 1 2; do for F in 2026-10-08b_hikes_parks.sql 2026-10-08c_brochure_kind.sql; do psql -q -v ON_ERROR_STOP=1 -d eitv_hk_mig -f $M/$F 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true; done; done
python3 probe.py | grep -v "^PASS"
