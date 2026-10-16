#!/bin/bash
# D-55 food courts: builds a local copy from supabase/schema.sql (as on production before D-55), the limited-members
# seed, then 2026-10-16b_food_courts.sql twice, and runs checks.sql. Needs a local Postgres 16 (PGHOST, PGPORT, PGUSER).
set -e; cd "$(dirname "$0")"; R=../../..
psql -q -d postgres -c "drop database if exists eitv_fc" -c "create database eitv_fc" 2>/dev/null
psql -q -d eitv_fc -f ../limited_members/local_base.sql >/dev/null 2>&1
psql -q -v ON_ERROR_STOP=1 -d eitv_fc -f $R/supabase/schema.sql 2>&1 | grep -v NOTICE | head -5 || true
psql -q -d eitv_fc -f ../limited_members/seed.sql >/dev/null 2>&1
for i in 1 2; do psql -q -v ON_ERROR_STOP=1 -d eitv_fc -f $R/supabase/migrations/2026-10-16b_food_courts.sql 2>&1 | grep -v NOTICE || true; done
psql -q -t -d eitv_fc -f checks.sql 2>&1 | grep "FAIL\|passed"
