#!/bin/bash
# Eshkol / Midbari rentals (D-42) and wineries under Restaurant and Attraction / Site (D-43): the checks for
# supabase/migrations/2026-10-12_rentals.sql, 2026-10-12b_wineries_under_sites.sql and 2026-10-12c_vehicle_rental_category.sql.
# Needs a local Postgres 16 (PGHOST, PGPORT, PGUSER set), psql and python3. Run after ../limited_members/run.sh has passed.
# Give it one file: $1 = schema.sql as it was before D-42 (git show 091361e:supabase/schema.sql, main on 12 Oct 2026,
# whose functions equal production's: see ../production_fingerprints.txt).
# Builds three databases:
#   eitv_rt_new   from supabase/schema.sql as it is now
#   eitv_rt_mig   from $1, then files a, b and c, each twice, in that order (c last, as when the owner runs it later)
#   eitv_rt_mig2  from $1, then file c first, then a, then b (the owner runs c before the connector runs a and b)
# probe.py compares every function, every table's columns, constraints and indexes, and every privilege between the
# three, then runs the checks as Eretz Israel Tours, two guides and four organisations. Prints only the failures and the total.
set -e
cd "$(dirname "$0")"; R=../../..; OLD=${1:?give the schema.sql from before D-42}
M=$R/supabase/migrations
for DB in eitv_rt_new eitv_rt_mig eitv_rt_mig2; do psql -q -d postgres -c "drop database if exists $DB" -c "create database $DB" 2>/dev/null; psql -q -d $DB -f ../limited_members/local_base.sql; done
psql -q -v ON_ERROR_STOP=1 -d eitv_rt_new -f $R/supabase/schema.sql 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true
for DB in eitv_rt_mig eitv_rt_mig2; do psql -q -v ON_ERROR_STOP=1 -d $DB -f "$OLD" 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true; done
for DB in eitv_rt_new eitv_rt_mig eitv_rt_mig2; do psql -q -d $DB -f ../limited_members/seed.sql > /dev/null; done
python3 probe.py "$OLD" | grep -v "^PASS"
