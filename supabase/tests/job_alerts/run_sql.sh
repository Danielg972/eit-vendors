#!/bin/bash
# D-69 job alerts: build a local database from supabase/schema.sql, add 2026-10-31b_job_alerts.sql (twice, to show it is
# safe to run again), then run the recipient probe. Needs a local Postgres 16 (PGHOST, PGPORT, PGUSER set) and psql.
set -e
cd "$(dirname "$0")"; R=../../..; DB=${1:-eitv_alerts_test}
psql -q -d postgres -c "drop database if exists $DB" -c "create database $DB"
psql -q -d $DB -f ../limited_members/local_base.sql
psql -q -v ON_ERROR_STOP=1 -d $DB -f $R/supabase/schema.sql 2>&1 | grep -v "NOTICE" | head -5 || true
psql -q -v ON_ERROR_STOP=1 -d $DB -f $R/supabase/migrations/2026-10-31b_job_alerts.sql 2>&1 | grep -v "NOTICE" | head -5 || true
psql -q -v ON_ERROR_STOP=1 -d $DB -f $R/supabase/migrations/2026-10-31b_job_alerts.sql 2>&1 | grep -v "NOTICE" | head -5 || true
psql -q -d $DB -f recipients_probe.sql 2>&1 | grep -o 'PROBE .*' || true
psql -q -d $DB -f sender_probe.sql 2>&1 | grep -o "PROBE .*" || true
