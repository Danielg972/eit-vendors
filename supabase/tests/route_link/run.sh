#!/bin/bash
# "Open in Mapeak" opens the hike's route (D-53): the checks for supabase/migrations/2026-10-16_hike_route_link.sql.
# Needs a local Postgres 16 (PGHOST, PGPORT, PGUSER set), psql and python3. Run after ../limited_members/run.sh has passed.
# Give it one file: $1 = schema.sql as it was before D-53 (git show d9ef8c0:supabase/schema.sql, main on 16 Oct 2026).
# That record lacks activity_feed (D-49), which was run on production on 15 Oct without being written into it, so the
# second database gets 2026-10-15_activity_feed.sql first; with it, its functions equal production's before D-53
# (checked against the line in this folder's production_before.txt).
# Builds two databases:
#   eitv_rl_new   from supabase/schema.sql as it is now
#   eitv_rl_mig   from $1, then 2026-10-15_activity_feed.sql, then 2026-10-16_hike_route_link.sql twice
# probe.py compares every function, every table's columns, constraints and indexes, and every privilege between the
# two, then runs the checks as Eretz Israel Tours, two guides, an organisation and the edge function's service role.
# Prints only the failures and the total.
set -e
cd "$(dirname "$0")"; R=../../..; OLD=${1:?give the schema.sql from before D-53}
for DB in eitv_rl_new eitv_rl_mig; do psql -q -d postgres -c "drop database if exists $DB" -c "create database $DB" 2>/dev/null; psql -q -d $DB -f ../limited_members/local_base.sql; done
psql -q -v ON_ERROR_STOP=1 -d eitv_rl_new -f $R/supabase/schema.sql 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true
psql -q -v ON_ERROR_STOP=1 -d eitv_rl_mig -f "$OLD" 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true
for DB in eitv_rl_new eitv_rl_mig; do psql -q -d $DB -f ../limited_members/seed.sql > /dev/null; done
python3 probe.py | grep -v "^PASS"
