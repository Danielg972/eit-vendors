#!/bin/bash
# Booking sheets, each day's own times (D-24): the checks for supabase/migrations/2026-10-05b_booking_day_times.sql.
# Needs a local Postgres 16 (PGHOST, PGPORT, PGUSER set), psql and python3. Builds two databases: one from
# supabase/schema.sql, one from the schema as it was before D-24 (pass that file as $1, e.g. from
# `git show fa6ab22:supabase/schema.sql`) with the migration run on top, twice.
set -e
cd "$(dirname "$0")"; R=../../..; OLD=${1:?give the schema.sql from before D-24}
for DB in eitv_bt_new eitv_bt_mig; do psql -q -d postgres -c "drop database if exists $DB" -c "create database $DB" 2>/dev/null; psql -q -d $DB -f ../limited_members/local_base.sql; done
psql -q -v ON_ERROR_STOP=1 -d eitv_bt_new -f $R/supabase/schema.sql 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true
psql -q -v ON_ERROR_STOP=1 -d eitv_bt_mig -f "$OLD" 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true
psql -q -d eitv_bt_mig -f ../limited_members/seed.sql > /dev/null
# sheets made before the change (one plain period, one with separate days) have to come through untouched
psql -q -v ON_ERROR_STOP=1 -d eitv_bt_mig -c "select public.booking_save('FULLTOKEN00000000000000000', (select id from public.__ids where k='T'), '{\"date_from\":\"2026-11-18\",\"date_to\":\"2026-11-27\",\"service\":\"bus\",\"booker_name\":\"Old\",\"booker_phone\":\"050\",\"pickup_time\":\"08:00\",\"dropoff_time\":\"18:00\"}'::jsonb)" -c "select public.booking_save('FULLTOKEN00000000000000000', (select id from public.__ids where k='T'), '{\"date_from\":\"2026-11-18\",\"date_to\":\"2026-11-27\",\"days\":\"2026-11-18,2026-11-20,2026-11-27\",\"service\":\"bus\",\"booker_name\":\"Old2\",\"booker_phone\":\"050\"}'::jsonb)" > /dev/null
psql -qAt -d eitv_bt_mig -c "select string_agg(md5(public._booking_content(b)::text), ',' order by booker_name) from public.bookings b" > /tmp/bt_before.txt
for i in 1 2; do psql -q -v ON_ERROR_STOP=1 -d eitv_bt_mig -f $R/supabase/migrations/2026-10-05b_booking_day_times.sql 2>&1 | grep -v "NOTICE\|skipping" | head -5 || true; done
python3 probe.py | grep -v "^PASS"
