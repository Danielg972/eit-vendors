#!/bin/bash
# D-61, the supplier details form: build a local database from supplier_forms' migration on top of supabase/schema.sql,
# run the rolled-back probe there, then the limited-member checks with the migration in.
# Needs a local Postgres 16 you can create databases on (PGHOST, PGPORT, PGUSER set), psql and python3.
set -e
cd "$(dirname "$0")"; R=../../..; DB=${1:-eitv_forms_test}
psql -q -d postgres -c "drop database if exists $DB" -c "create database $DB" 2>&1 | grep -v NOTICE || true
psql -q -d $DB -f ../limited_members/local_base.sql
psql -q -v ON_ERROR_STOP=1 -d $DB -f $R/supabase/schema.sql 2>&1 | grep -v "^NOTICE\|skipping\|^psql.*NOTICE" | head -5 || true
psql -q -v ON_ERROR_STOP=1 -d $DB -f $R/supabase/migrations/2026-10-19_supplier_forms.sql
psql -qAt -d $DB -f production_probe.sql 2>&1 | sed -n 's/.*PROBE //p' | python3 -c "import json,sys; r=json.loads(sys.stdin.read()); print('probe:', r['checks'], 'checks, failed:', r['failed']); print('fingerprints:', r['fingerprints'])"
psql -q -d $DB -f ../limited_members/seed.sql > /dev/null
(cd ../limited_members && python3 probe.py $DB | grep -v "^PASS")
