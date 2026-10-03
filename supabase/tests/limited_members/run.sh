#!/bin/bash
# Limited members (D-15): the checks any database change has to pass before it goes to production.
# Needs a local Postgres 16 you can create databases on (PGHOST, PGPORT, PGUSER set), psql and python3.
# Builds a database from supabase/schema.sql, loads sample suppliers and members, and runs 74 checks as an
# organisation (limited member), a guide (full member) and Eretz Israel Tours. Prints only the failures and the total.
set -e
cd "$(dirname "$0")"; R=../../..; DB=${1:-eitv_limited_test}
psql -q -d postgres -c "drop database if exists $DB" -c "create database $DB"
psql -q -d $DB -f local_base.sql
psql -q -v ON_ERROR_STOP=1 -d $DB -f $R/supabase/schema.sql 2>&1 | grep -v "^NOTICE\|skipping\|^psql.*NOTICE" | head -5 || true
psql -q -d $DB -f seed.sql > /dev/null
python3 probe.py $DB | grep -v "^PASS"
