-- Israel Suppliers Master List: database schema (public schema; storage buckets listed at the end).
-- Exported from Supabase project wjuqtjlrtcywjaspjpwu on 2026-10-01; quote tracker, driver reviews and booking sheets, then opening hours, verified hours (hours_verify) and the kosher rule in vendor_save, added 2026-10-02 (supabase/migrations/); jobs between colleagues and My days (jobs, job_offers, member_days) added 2026-10-03. Limited members (organisations: member_type, sections, organisation rates and reviews) added 2026-10-03 (supabase/migrations/2026-10-03b_limited_members.sql). Guide pages for clients, claimed pages, review approval and private notes, guide rules (D-12, D-14, D-16; supabase/migrations/2026-10-03c_guides_claims_reviews.sql) added 3 Oct 2026.
-- To rebuild on an empty Supabase project: run this file, create the three PRIVATE storage buckets,
-- then deploy supabase/functions/files/index.ts (verify_jwt = false). Data is not included.
-- KEEP CURRENT: re-export after every schema, function or security change (README > Change rules).

create extension if not exists pgcrypto;

-- (gen_vendor_id is needed by a table default)
CREATE OR REPLACE FUNCTION public.gen_vendor_id()
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare chars text := '0123456789abcdefghijklmnopqrstuvwxyz'; s text := 'vendor_'; i int;
begin
  for i in 1..7 loop s := s || substr(chars, 1 + floor(random()*36)::int, 1); end loop;
  return s;
end $function$
;


-- ===== Tables =====

create table public.action_log (
  id bigint generated always as identity not null,
  vendor_id text,
  member text not null,
  member_name text default ''::text not null,
  action text not null,
  created_at timestamp with time zone default now() not null,
  constraint action_log_pkey PRIMARY KEY (id),
  constraint action_log_action_check CHECK ((action = ANY (ARRAY['call'::text, 'whatsapp'::text, 'email'::text, 'website'::text, 'waze'::text, 'maps'::text, 'booking'::text, 'deal'::text, 'file'::text, 'open'::text, 'agent'::text, 'agent_ask'::text])))
);
alter table public.action_log enable row level security;
CREATE INDEX action_log_vendor_idx ON public.action_log USING btree (vendor_id, created_at DESC);
CREATE INDEX action_log_time_idx ON public.action_log USING btree (created_at DESC);

create table public.app_settings (
  key text not null,
  value text default ''::text not null,
  constraint app_settings_pkey PRIMARY KEY (key)
);
alter table public.app_settings enable row level security;

create table public.bookings (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  owner text not null,
  owner_name text default ''::text not null,
  link_key text not null,
  status text default 'waiting'::text not null,
  client_ref text default ''::text not null,
  booker_name text default ''::text not null,
  booker_phone text default ''::text not null,
  date_from text default ''::text not null,
  date_to text default ''::text not null,
  pax text default ''::text not null,
  service text default ''::text not null,
  seats text default ''::text not null,
  tourists boolean default true not null,
  pickup_time text default ''::text not null,
  pickup_place text default ''::text not null,
  route text default ''::text not null,
  dropoff_time text default ''::text not null,
  dropoff_place text default ''::text not null,
  note text default ''::text not null,
  private_note text default ''::text not null,
  proposed jsonb default '{}'::jsonb not null,
  terms jsonb default '{}'::jsonb not null,
  terms_by text default ''::text not null,
  answered_by text default ''::text not null,
  answered_at timestamp with time zone,
  answers integer default 0 not null,
  shared boolean default true not null,
  quote_id uuid,
  confirmed_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  guide_ok_at timestamp with time zone,
  company_ok_at timestamp with time zone,
  company_ok_via text default ''::text not null,
  seen_guide jsonb,
  seen_company jsonb,
  days text default ''::text not null,
  day_plan jsonb default '{}'::jsonb not null,
  constraint bookings_pkey primary key (id),
  constraint bookings_company_ok_via_check check (company_ok_via = any (array[''::text, 'link'::text, 'guide'::text])),
  constraint bookings_link_key_key unique (link_key),
  constraint bookings_status_check check (status = any (array['waiting'::text, 'answered'::text, 'confirmed'::text, 'cancelled'::text])),
  constraint bookings_terms_by_check check (terms_by = any (array[''::text, 'company'::text, 'guide'::text])),
  constraint bookings_date_from_check check (date_from = ''::text or date_from ~ '^\d{4}-\d{2}-\d{2}$'::text),
  constraint bookings_date_to_check check (date_to = ''::text or date_to ~ '^\d{4}-\d{2}-\d{2}$'::text),
  constraint bookings_days_check check (days = ''::text or (length(days) <= 700 and days ~ '^\d{4}-\d{2}-\d{2}(,\d{4}-\d{2}-\d{2})+$'::text)),
  constraint bookings_day_plan_check check (jsonb_typeof(day_plan) = 'object'::text and length(day_plan::text) <= 30000),
  constraint bookings_seats_check check (seats = ''::text or seats ~ '^\d{1,3}$'::text),
  constraint bookings_service_check check (service = any (array[''::text, 'bus'::text, 'midibus'::text, 'van20'::text, 'van16'::text, 'van10'::text, 'van8'::text, 'car'::text, 'jeep_vehicle'::text, 'transfer'::text])),
  constraint bookings_lengths_check check (length(client_ref) <= 160 and length(booker_name) <= 80 and length(booker_phone) <= 40 and length(pax) <= 20
    and length(pickup_time) <= 20 and length(dropoff_time) <= 20 and length(pickup_place) <= 160 and length(dropoff_place) <= 160
    and length(route) <= 1500 and length(note) <= 1500 and length(private_note) <= 3000 and length(answered_by) <= 80 and length(link_key) >= 32)
);
alter table public.bookings enable row level security;
CREATE INDEX bookings_vendor_idx ON public.bookings USING btree (vendor_id);
CREATE INDEX bookings_owner_idx ON public.bookings USING btree (owner);

create table public.change_requests (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  kind text not null,
  target_id uuid,
  proposed jsonb default '{}'::jsonb not null,
  current jsonb default '{}'::jsonb not null,
  reason text default ''::text not null,
  requested_by text not null,
  requested_name text default ''::text not null,
  status text default 'pending'::text not null,
  decided_by text,
  decided_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  constraint change_requests_pkey PRIMARY KEY (id),
  constraint change_requests_kind_check CHECK ((kind = ANY (ARRAY['vendor_fields'::text, 'price_add'::text, 'price_edit'::text, 'price_delete'::text]))),
  constraint change_requests_reason_check CHECK ((length(reason) <= 1000)),
  constraint change_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);
alter table public.change_requests enable row level security;
CREATE INDEX change_requests_status_idx ON public.change_requests USING btree (status);

create table public.contributors (
  email text not null,
  display_name text,
  is_admin boolean default false not null,
  added_at timestamp with time zone default now() not null,
  constraint contributors_pkey PRIMARY KEY (email),
  constraint contributors_email_check CHECK ((email = lower(email)))
);
alter table public.contributors enable row level security;

create table public.driver_reviews (
  id uuid default gen_random_uuid() not null,
  driver_id uuid not null,
  vendor_id text,
  rating text not null,
  tags text default ''::text not null,
  body text default ''::text not null,
  trip_month text default ''::text not null,
  author text not null,
  author_name text default ''::text not null,
  created_at timestamp with time zone default now() not null,
  org boolean default false not null,
  private boolean default false not null,
  constraint driver_reviews_pkey PRIMARY KEY (id),
  constraint driver_reviews_body_check CHECK ((length(body) <= 1500)),
  constraint driver_reviews_rating_check CHECK ((rating = ANY (ARRAY['1'::text, '2'::text, '3'::text, '4'::text, '5'::text]))),
  constraint driver_reviews_tags_check CHECK ((length(tags) <= 300)),
  constraint driver_reviews_trip_month_check CHECK (((trip_month = ''::text) OR (trip_month ~ '^\d{4}-\d{2}$'::text)))
);
alter table public.driver_reviews enable row level security;
CREATE INDEX driver_reviews_driver_idx ON public.driver_reviews USING btree (driver_id);

create table public.driver_vendors (
  driver_id uuid not null,
  vendor_id text not null,
  added_by text not null,
  created_at timestamp with time zone default now() not null,
  constraint driver_vendors_pkey PRIMARY KEY (driver_id, vendor_id)
);
alter table public.driver_vendors enable row level security;
CREATE INDEX driver_vendors_vendor_idx ON public.driver_vendors USING btree (vendor_id);

create table public.drivers (
  id uuid default gen_random_uuid() not null,
  name text not null,
  phone text not null,
  phone_norm text not null,
  drives text default ''::text not null,
  created_by text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint drivers_pkey PRIMARY KEY (id),
  constraint drivers_phone_norm_key UNIQUE (phone_norm),
  constraint drivers_drives_check CHECK ((length(drives) <= 120)),
  constraint drivers_name_check CHECK (((length(TRIM(BOTH FROM name)) >= 1) AND (length(TRIM(BOTH FROM name)) <= 80))),
  constraint drivers_phone_check CHECK ((length(phone) <= 40)),
  constraint drivers_phone_norm_check CHECK ((phone_norm ~ '^\d{7,15}$'::text))
);
alter table public.drivers enable row level security;

create table public.feedback (
  id uuid default gen_random_uuid() not null,
  kind text default 'Suggestion'::text not null,
  message text not null,
  context text default ''::text not null,
  device text default ''::text not null,
  file_path text,
  status text default 'New'::text not null,
  reply text default ''::text not null,
  author text not null,
  author_name text default ''::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint feedback_pkey PRIMARY KEY (id),
  constraint feedback_context_check CHECK ((length(context) <= 300)),
  constraint feedback_device_check CHECK ((length(device) <= 300)),
  constraint feedback_kind_check CHECK ((kind = ANY (ARRAY['Suggestion'::text, 'Bug'::text, 'Question'::text, 'Other'::text]))),
  constraint feedback_message_check CHECK (((length(TRIM(BOTH FROM message)) >= 1) AND (length(TRIM(BOTH FROM message)) <= 4000))),
  constraint feedback_reply_check CHECK ((length(reply) <= 2000)),
  constraint feedback_status_check CHECK ((status = ANY (ARRAY['New'::text, 'Planned'::text, 'Done'::text, 'Won''t do'::text])))
);
alter table public.feedback enable row level security;

create table public.filter_log (
  id bigint generated always as identity not null,
  member text not null,
  kind text not null,
  value text not null,
  created_at timestamp with time zone default now() not null,
  constraint filter_log_pkey PRIMARY KEY (id),
  constraint filter_log_kind_check CHECK ((kind = ANY (ARRAY['category'::text, 'region'::text]))),
  constraint filter_log_value_check CHECK (((length(value) >= 1) AND (length(value) <= 80)))
);
alter table public.filter_log enable row level security;
CREATE INDEX filter_log_member_idx ON public.filter_log USING btree (member);

-- One row per colleague a job was sent to (picked) or who answered it.
create table public.job_offers (
  job_id uuid not null,
  member text not null,
  picked boolean default false not null,
  answer text default ''::text not null,
  answered_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  constraint job_offers_pkey primary key (job_id, member),
  constraint job_offers_answer_check check (answer = any (array[''::text, 'yes'::text, 'no'::text]))
);
alter table public.job_offers enable row level security;
CREATE INDEX job_offers_member_idx on public.job_offers using btree (member);

create table public.jobs (
  id uuid default gen_random_uuid() not null,
  owner text not null,
  owner_name text default ''::text not null,
  anon boolean default true not null,
  kind text default 'guide'::text not null,
  title text default ''::text not null,
  date_from text default ''::text not null,
  date_to text default ''::text not null,
  hours text default ''::text not null,
  start_place text default ''::text not null,
  region text default ''::text not null,
  pax text default ''::text not null,
  langs text default ''::text not null,
  needs text default ''::text not null,
  price text default ''::text not null,
  currency text default 'ILS'::text not null,
  per text default 'day'::text not null,
  vat text default ''::text not null,
  payment text default ''::text not null,
  note text default ''::text not null,
  reply_by text default ''::text not null,
  audience text default 'all'::text not null,
  status text default 'open'::text not null,
  taken_by text default ''::text not null,
  filled_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint jobs_pkey primary key (id),
  constraint jobs_kind_check check (kind = any (array['guide'::text, 'guide_vehicle'::text, 'van_driver'::text, 'jeep_driver'::text, 'other'::text])),
  constraint jobs_status_check check (status = any (array['open'::text, 'filled'::text, 'closed'::text])),
  constraint jobs_audience_check check (audience = any (array['all'::text, 'picked'::text])),
  constraint jobs_per_check check (per = any (array['day'::text, 'job'::text, 'hour'::text, 'vehicle'::text])),
  constraint jobs_vat_check check (vat = any (array[''::text, 'including_vat'::text, 'plus_vat'::text, 'not_applicable'::text])),
  constraint jobs_currency_check check (currency = any (array['ILS'::text, 'USD'::text, 'EUR'::text])),
  constraint jobs_dates_check check ((date_from = ''::text or date_from ~ '^\d{4}-\d{2}-\d{2}$'::text) and (date_to = ''::text or date_to ~ '^\d{4}-\d{2}-\d{2}$'::text) and (reply_by = ''::text or reply_by ~ '^\d{4}-\d{2}-\d{2}$'::text)),
  constraint jobs_price_check check (price = ''::text or price ~ '^\d{1,7}(\.\d{1,2})?$'::text),
  constraint jobs_lengths_check check (length(title) <= 120 and length(hours) <= 40 and length(start_place) <= 160 and length(region) <= 60 and length(pax) <= 80
    and length(langs) <= 120 and length(needs) <= 80 and length(payment) <= 200 and length(note) <= 1500)
);
alter table public.jobs enable row level security;
CREATE INDEX jobs_owner_idx on public.jobs using btree (owner);
CREATE INDEX jobs_status_idx on public.jobs using btree (status, date_from);
CREATE INDEX jobs_taken_idx on public.jobs using btree (taken_by);

-- A member's busy days. source 'tap' = he marked it; 'job' = filled in when he was given a job here.
create table public.member_days (
  member text not null,
  day date not null,
  source text default 'tap'::text not null,
  job_id uuid,
  created_at timestamp with time zone default now() not null,
  constraint member_days_pkey primary key (member, day),
  constraint member_days_source_check check (source = any (array['tap'::text, 'job'::text]))
);
alter table public.member_days enable row level security;
CREATE INDEX member_days_job_idx on public.member_days using btree (job_id);

create table public.members (
  id uuid default gen_random_uuid() not null,
  name text not null,
  email text not null,
  phone text default ''::text not null,
  note text default ''::text not null,
  token_hash text not null,
  status text default 'pending'::text not null,
  is_admin boolean default false not null,
  created_at timestamp with time zone default now() not null,
  decided_at timestamp with time zone,
  last_seen_at timestamp with time zone,
  role text default ''::text not null,
  license_no text default ''::text not null,
  proof_path text,
  proof_mime text,
  terms_version text default ''::text not null,
  terms_accepted_at timestamp with time zone,
  reminder_seen_at timestamp with time zone,
  bcc_opt_out boolean default false not null,
  bcc_ack boolean default false not null,
  job_kinds text default ''::text not null,
  job_tags text default ''::text not null,
  job_langs text default ''::text not null,
  days_weekly text default ''::text not null,
  days_shared boolean default true not null,
  days_updated_at timestamp with time zone,
  member_type text default 'full'::text not null,
  sections text default ''::text not null,
  see_quotes boolean default true not null,
  see_guide_rates boolean default false not null,
  see_transport_reviews boolean default true not null,
  see_reviews boolean default false not null,
  org text default ''::text not null,
  credentials text default ''::text not null,
  constraint members_token_hash_key UNIQUE (token_hash),
  constraint members_pkey PRIMARY KEY (id),
  constraint members_email_check CHECK (((email = lower(email)) AND (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'::text))),
  constraint members_name_check CHECK (((length(TRIM(BOTH FROM name)) >= 1) AND (length(TRIM(BOTH FROM name)) <= 80))),
  constraint members_role_check CHECK ((role = ANY (ARRAY[''::text, 'Licensed tour guide'::text, 'Travel agent'::text, 'Tour operator'::text, 'Other'::text]))),
  constraint members_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'revoked'::text]))),
  constraint members_jobs_check check (length(job_kinds) <= 80 and length(job_tags) <= 80 and length(job_langs) <= 200 and days_weekly ~ '^([0-6](,[0-6]){0,6})?$'::text),
  constraint members_access_check CHECK (((member_type = ANY (ARRAY['full'::text, 'limited'::text])) AND (sections ~ '^((transport|guides|hotels|sites|food|other)(,(transport|guides|hotels|sites|food|other))*)?$'::text) AND (length(org) <= 120) AND (length(credentials) <= 1000)))
);
alter table public.members enable row level security;

create table public.quote_lines (
  id uuid default gen_random_uuid() not null,
  option_id uuid not null,
  label text default ''::text not null,
  kind text default 'Base'::text not null,
  price text default ''::text not null,
  unit text default 'per person'::text not null,
  qty text default '1'::text not null,
  times text default '1'::text not null,
  note text default ''::text not null,
  sort integer default 0 not null,
  constraint quote_lines_pkey PRIMARY KEY (id),
  constraint quote_lines_kind_check CHECK ((kind = ANY (ARRAY['Base'::text, 'Supplement'::text, 'Meal'::text, 'Extra'::text, 'Discount'::text]))),
  constraint quote_lines_label_check CHECK ((length(label) <= 160)),
  constraint quote_lines_note_check CHECK ((length(note) <= 300)),
  constraint quote_lines_price_check CHECK (((price = ''::text) OR (price ~ '^\d+(\.\d+)?$'::text))),
  constraint quote_lines_qty_check CHECK (((qty = ''::text) OR (qty ~ '^\d+(\.\d+)?$'::text))),
  constraint quote_lines_times_check CHECK (((times = ''::text) OR (times ~ '^\d+(\.\d+)?$'::text))),
  constraint quote_lines_unit_check CHECK ((unit = ANY (ARRAY['per room per night'::text, 'per person'::text, 'per person per night'::text, 'per vehicle per day'::text, 'per day'::text, 'per hour'::text, 'per group'::text, 'flat'::text, '% of subtotal'::text])))
);
alter table public.quote_lines enable row level security;

create table public.quote_options (
  id uuid default gen_random_uuid() not null,
  quote_id uuid not null,
  name text default 'Option A'::text not null,
  note text default ''::text not null,
  sort integer default 0 not null,
  service text default ''::text not null,
  seats text default ''::text not null,
  hours_incl text default ''::text not null,
  km_incl text default ''::text not null,
  fees jsonb default '{}'::jsonb not null,
  constraint quote_options_pkey PRIMARY KEY (id),
  constraint quote_options_hours_incl_check CHECK (((hours_incl = ''::text) OR (hours_incl ~ '^\d{1,2}(\.\d)?$'::text))),
  constraint quote_options_km_incl_check CHECK (((km_incl = ''::text) OR (km_incl ~ '^\d{1,4}$'::text))),
  constraint quote_options_name_check CHECK ((length(name) <= 120)),
  constraint quote_options_note_check CHECK ((length(note) <= 1000)),
  constraint quote_options_seats_check CHECK (((seats = ''::text) OR (seats ~ '^\d{1,3}$'::text))),
  constraint quote_options_service_check CHECK ((length(service) <= 40))
);
alter table public.quote_options enable row level security;

create table public.quotes (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  title text default ''::text not null,
  date_from text default ''::text not null,
  date_to text default ''::text not null,
  pax text default ''::text not null,
  units text default ''::text not null,
  received_on text default ''::text not null,
  valid_until text default ''::text not null,
  ref text default ''::text not null,
  status text default 'Received'::text not null,
  currency text default 'ILS'::text not null,
  vat text default ''::text not null,
  conditions text default ''::text not null,
  private_note text default ''::text not null,
  shared boolean default true not null,
  owner text not null,
  owner_name text default ''::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  org boolean default false not null,
  constraint quotes_pkey PRIMARY KEY (id),
  constraint quotes_conditions_check CHECK ((length(conditions) <= 3000)),
  constraint quotes_currency_check CHECK ((currency = ANY (ARRAY['ILS'::text, 'USD'::text, 'EUR'::text]))),
  constraint quotes_date_from_check CHECK (((date_from = ''::text) OR (date_from ~ '^\d{4}-\d{2}-\d{2}$'::text))),
  constraint quotes_date_to_check CHECK (((date_to = ''::text) OR (date_to ~ '^\d{4}-\d{2}-\d{2}$'::text))),
  constraint quotes_pax_check CHECK ((length(pax) <= 20)),
  constraint quotes_private_note_check CHECK ((length(private_note) <= 3000)),
  constraint quotes_received_on_check CHECK (((received_on = ''::text) OR (received_on ~ '^\d{4}-\d{2}-\d{2}$'::text))),
  constraint quotes_ref_check CHECK ((length(ref) <= 80)),
  constraint quotes_status_check CHECK ((status = ANY (ARRAY['Requested'::text, 'Received'::text, 'Booked'::text, 'Expired'::text, 'Declined'::text]))),
  constraint quotes_title_check CHECK ((length(title) <= 160)),
  constraint quotes_units_check CHECK ((length(units) <= 60)),
  constraint quotes_valid_until_check CHECK (((valid_until = ''::text) OR (valid_until ~ '^\d{4}-\d{2}-\d{2}$'::text))),
  constraint quotes_vat_check CHECK ((vat = ANY (ARRAY[''::text, 'including_vat'::text, 'plus_vat'::text, 'not_applicable'::text])))
);
alter table public.quotes enable row level security;
CREATE INDEX quotes_vendor_idx ON public.quotes USING btree (vendor_id);

create table public.reservation_reports (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  member text not null,
  member_name text default ''::text not null,
  checked text not null,
  visit_date text default ''::text not null,
  note text default ''::text not null,
  created_at timestamp with time zone default now() not null,
  constraint reservation_reports_pkey PRIMARY KEY (id),
  constraint reservation_reports_checked_check CHECK ((checked = ANY (ARRAY['yes'::text, 'no'::text, 'unsure'::text]))),
  constraint reservation_reports_note_check CHECK ((length(note) <= 300)),
  constraint reservation_reports_visit_date_check CHECK (((visit_date = ''::text) OR (visit_date ~ '^\d{4}-\d{2}-\d{2}$'::text)))
);
alter table public.reservation_reports enable row level security;
CREATE INDEX reservation_reports_vendor_idx ON public.reservation_reports USING btree (vendor_id, created_at DESC);

create table public.vendor_admin_notes (
  vendor_id text not null,
  body text default ''::text not null,
  updated_at timestamp with time zone default now() not null,
  constraint vendor_admin_notes_pkey PRIMARY KEY (vendor_id)
);
alter table public.vendor_admin_notes enable row level security;

create table public.vendor_claims (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  member text not null,
  member_name text default ''::text not null,
  note text default ''::text not null,
  status text default 'pending'::text not null,
  decided_by text,
  decided_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  constraint vendor_claims_pkey PRIMARY KEY (id),
  constraint vendor_claims_note_check CHECK ((length(note) <= 500)),
  constraint vendor_claims_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);
alter table public.vendor_claims enable row level security;
CREATE UNIQUE INDEX vendor_claims_one_pending ON public.vendor_claims USING btree (vendor_id, member) WHERE (status = 'pending'::text);

create table public.vendor_deals (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  kind text default 'Other'::text not null,
  provider text default ''::text not null,
  title text not null,
  details text default ''::text not null,
  code text default ''::text not null,
  link text default ''::text not null,
  valid_to text default ''::text not null,
  reported_by text default ''::text not null,
  created_at timestamp with time zone default now() not null,
  constraint vendor_deals_pkey PRIMARY KEY (id),
  constraint vendor_deals_code_check CHECK ((length(code) <= 80)),
  constraint vendor_deals_details_check CHECK ((length(details) <= 1000)),
  constraint vendor_deals_kind_check CHECK ((kind = ANY (ARRAY['Credit card club'::text, 'Coupon site'::text, 'Coupon code'::text, 'Group trick'::text, 'Other'::text]))),
  constraint vendor_deals_link_check CHECK ((length(link) <= 500)),
  constraint vendor_deals_provider_check CHECK ((length(provider) <= 80)),
  constraint vendor_deals_title_check CHECK (((length(TRIM(BOTH FROM title)) >= 1) AND (length(TRIM(BOTH FROM title)) <= 160))),
  constraint vendor_deals_valid_to_check CHECK (((valid_to = ''::text) OR (valid_to ~ '^\d{4}-\d{2}-\d{2}$'::text)))
);
alter table public.vendor_deals enable row level security;
CREATE INDEX vendor_deals_vendor_idx ON public.vendor_deals USING btree (vendor_id);

create table public.vendor_files (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  path text not null,
  file_name text not null,
  mime_type text default ''::text not null,
  size_bytes bigint default 0 not null,
  kind text default 'Other'::text not null,
  uploaded_by text default lower(COALESCE((auth.jwt() ->> 'email'::text), ''::text)) not null,
  created_at timestamp with time zone default now() not null,
  quote_id uuid,
  private boolean default false not null,
  org boolean default false not null,
  for_clients boolean default false not null,
  constraint vendor_files_path_key UNIQUE (path),
  constraint vendor_files_pkey PRIMARY KEY (id),
  constraint vendor_files_kind_check CHECK ((kind = ANY (ARRAY['Photo'::text, 'Receipt'::text, 'Price list'::text, 'Booking confirmation'::text, 'Contract'::text, 'Quote'::text, 'Kosher certificate'::text, 'Other'::text])))
);
alter table public.vendor_files enable row level security;
CREATE INDEX vendor_files_vendor_idx ON public.vendor_files USING btree (vendor_id);

create table public.vendor_food (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  name text not null,
  kosher text default ''::text not null,
  note text default ''::text not null,
  author text not null,
  author_name text default ''::text not null,
  created_at timestamp with time zone default now() not null,
  constraint vendor_food_pkey PRIMARY KEY (id),
  constraint vendor_food_kosher_check CHECK ((length(kosher) <= 120)),
  constraint vendor_food_name_check CHECK (((length(TRIM(BOTH FROM name)) >= 2) AND (length(TRIM(BOTH FROM name)) <= 120))),
  constraint vendor_food_note_check CHECK ((length(note) <= 500))
);
alter table public.vendor_food enable row level security;
CREATE INDEX vendor_food_vendor_id_idx ON public.vendor_food USING btree (vendor_id);

create table public.vendor_notes (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  body text not null,
  author text default ''::text not null,
  author_name text default ''::text not null,
  created_at timestamp with time zone default now() not null,
  org boolean default false not null,
  rating text default ''::text not null,
  private boolean default false not null,
  status text default 'approved'::text not null,
  decided_by text,
  decided_at timestamp with time zone,
  constraint vendor_notes_pkey PRIMARY KEY (id),
  constraint vendor_notes_body_check CHECK (((length(TRIM(BOTH FROM body)) >= 1) AND (length(TRIM(BOTH FROM body)) <= 2000))),
  constraint vendor_notes_rating_check CHECK ((rating = ANY (ARRAY[''::text, '1'::text, '2'::text, '3'::text, '4'::text, '5'::text]))),
  constraint vendor_notes_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);
alter table public.vendor_notes enable row level security;
CREATE INDEX vendor_notes_vendor_idx ON public.vendor_notes USING btree (vendor_id);

create table public.vendor_prices (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  label text default ''::text not null,
  audience text default 'Adult'::text not null,
  age_from text default ''::text not null,
  age_to text default ''::text not null,
  pax_min text default ''::text not null,
  pax_max text default ''::text not null,
  season text default ''::text not null,
  price text default ''::text not null,
  currency text default 'ILS'::text not null,
  vat text default ''::text not null,
  basis text default 'Per person'::text not null,
  is_agent boolean default true not null,
  source text default ''::text not null,
  checked_on text default ''::text not null,
  note text default ''::text not null,
  sort integer default 0 not null,
  created_by text default ''::text not null,
  created_at timestamp with time zone default now() not null,
  updated_by text default ''::text not null,
  updated_at timestamp with time zone default now() not null,
  private boolean default false not null,
  owner text default ''::text not null,
  org boolean default false not null,
  constraint vendor_prices_pkey PRIMARY KEY (id),
  constraint vendor_prices_audience_check CHECK ((audience = ANY (ARRAY['Adult'::text, 'Child'::text, 'Israeli senior'::text, 'Senior'::text, 'Student'::text, 'Soldier'::text, 'Group'::text, 'Private'::text, 'Vehicle'::text, 'Other'::text]))),
  constraint vendor_prices_basis_check CHECK ((basis = ANY (ARRAY['Per person'::text, 'Per group'::text, 'Per vehicle'::text, 'Per guide'::text, 'Per hour'::text, 'Per day'::text, 'Flat rate'::text, 'Custom'::text]))),
  constraint vendor_prices_checked_on_check CHECK (((checked_on = ''::text) OR (checked_on ~ '^\d{4}-\d{2}-\d{2}$'::text))),
  constraint vendor_prices_currency_check CHECK ((currency = ANY (ARRAY['ILS'::text, 'USD'::text, 'EUR'::text]))),
  constraint vendor_prices_label_check CHECK ((length(label) <= 120)),
  constraint vendor_prices_note_check CHECK ((length(note) <= 500)),
  constraint vendor_prices_price_check CHECK (((price = ''::text) OR (price ~ '^\d+(\.\d+)?$'::text))),
  constraint vendor_prices_season_check CHECK ((length(season) <= 120)),
  constraint vendor_prices_source_check CHECK ((length(source) <= 300)),
  constraint vendor_prices_vat_check CHECK ((vat = ANY (ARRAY[''::text, 'including_vat'::text, 'plus_vat'::text, 'not_applicable'::text])))
);
alter table public.vendor_prices enable row level security;
CREATE INDEX vendor_prices_vendor_idx ON public.vendor_prices USING btree (vendor_id);

create table public.vendor_reports (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  kind text not null,
  message text default ''::text not null,
  anonymous boolean default false not null,
  author text not null,
  author_name text default ''::text not null,
  status text default 'New'::text not null,
  created_at timestamp with time zone default now() not null,
  by_owner boolean default false not null,
  constraint vendor_reports_pkey PRIMARY KEY (id),
  constraint vendor_reports_kind_check CHECK ((kind = ANY (ARRAY['Closed'::text, 'Moved'::text, 'Contact changed'::text, 'Prices changed'::text, 'Mistake'::text, 'Other'::text]))),
  constraint vendor_reports_message_check CHECK ((length(message) <= 2000)),
  constraint vendor_reports_status_check CHECK ((status = ANY (ARRAY['New'::text, 'Fixed'::text, 'Dismissed'::text])))
);
alter table public.vendor_reports enable row level security;

create table public.vendors (
  id text default gen_vendor_id() not null,
  name text not null,
  category text default 'Other'::text not null,
  active text default 'Active'::text not null,
  "contactPerson" text default ''::text not null,
  phone text default ''::text not null,
  whatsapp text default ''::text not null,
  email text default ''::text not null,
  website text default ''::text not null,
  location text default ''::text not null,
  languages text default ''::text not null,
  kosher text default ''::text not null,
  "maxCap" text default ''::text not null,
  "listedPrice" text default ''::text not null,
  "listedPriceVatTreatment" text default ''::text not null,
  "agentPrice" text default ''::text not null,
  "agentPriceVatTreatment" text default ''::text not null,
  "maxPax" text default ''::text not null,
  "priceBasis" text default 'Per person'::text not null,
  currency text default 'ILS'::text not null,
  "payTerms" text default ''::text not null,
  "cancelPolicy" text default ''::text not null,
  "cancelNoticeAmount" text default ''::text not null,
  "cancelNoticeUnit" text default ''::text not null,
  "cancelDayType" text default ''::text not null,
  "cancelPenalty" text default ''::text not null,
  "cancelPolicyVerifiedDate" text default ''::text not null,
  "npResLink" text default ''::text not null,
  "rateReliability" text default ''::text not null,
  "rateService" text default ''::text not null,
  "rateValue" text default ''::text not null,
  strengths text default ''::text not null,
  weaknesses text default ''::text not null,
  notes text default ''::text not null,
  review_status text default 'pending'::text not null,
  name_norm text generated always as (TRIM(BOTH FROM regexp_replace(regexp_replace(lower(name), '\s+'::text, ' '::text, 'g'::text), '[.,;:!?]'::text, ''::text, 'g'::text))) stored,
  created_by text default lower(COALESCE((auth.jwt() ->> 'email'::text), ''::text)) not null,
  created_at timestamp with time zone default now() not null,
  updated_by text default lower(COALESCE((auth.jwt() ->> 'email'::text), ''::text)) not null,
  updated_at timestamp with time zone default now() not null,
  hidden boolean default false not null,
  prices_private boolean default false not null,
  parent_id text,
  reservation text default ''::text not null,
  region text default ''::text not null,
  tags text default ''::text not null,
  experience_years text default ''::text not null,
  agent_link text default ''::text not null,
  agent_howto text default ''::text not null,
  also_categories text default ''::text not null,
  maps_link text default ''::text not null,
  hours text default ''::text not null,
  hours_last text default ''::text not null,
  hours_source text default ''::text not null,
  hours_verified_at timestamp with time zone,
  hours_verified_by text default ''::text not null,
  hours_verified_how text default ''::text not null,
  client_bio text default ''::text not null,
  retail_price text default ''::text not null,
  claimed_by text default ''::text not null,
  claimed_at timestamp with time zone,
  constraint vendors_pkey PRIMARY KEY (id),
  constraint vendors_active_check CHECK ((active = ANY (ARRAY['Active'::text, 'Inactive'::text]))),
  constraint "vendors_agentPriceVatTreatment_check" CHECK (("agentPriceVatTreatment" = ANY (ARRAY[''::text, 'including_vat'::text, 'plus_vat'::text, 'not_applicable'::text]))),
  constraint vendors_agent_link_check CHECK (((agent_link = ''::text) OR (agent_link ~* '^https?://'::text))),
  constraint vendors_also_categories_check CHECK ((length(also_categories) <= 300)),
  constraint "vendors_cancelDayType_check" CHECK (("cancelDayType" = ANY (ARRAY[''::text, 'Calendar days'::text, 'Business days'::text]))),
  constraint "vendors_cancelNoticeUnit_check" CHECK (("cancelNoticeUnit" = ANY (ARRAY[''::text, 'Hours'::text, 'Days'::text]))),
  constraint "vendors_cancelPolicyVerifiedDate_check" CHECK ((("cancelPolicyVerifiedDate" = ''::text) OR ("cancelPolicyVerifiedDate" ~ '^\d{4}-\d{2}-\d{2}$'::text))),
  constraint vendors_category_check CHECK ((category = ANY (ARRAY['Hotel'::text, 'Guide'::text, 'Transport'::text, 'Restaurant'::text, 'Winery'::text, 'Attraction / Site'::text, 'Activity'::text, 'Adventure'::text, 'National Parks'::text, 'Travel Agent'::text, 'Itinerary Planner'::text, 'Flight'::text, 'Other'::text]))),
  constraint vendors_client_check CHECK (((length(client_bio) <= 1500) AND (length(retail_price) <= 200))),
  constraint vendors_currency_check CHECK ((currency = ANY (ARRAY['USD'::text, 'ILS'::text, 'EUR'::text]))),
  constraint vendors_experience_years_check CHECK (((experience_years = ''::text) OR (experience_years ~ '^\d{1,2}$'::text))),
  constraint vendors_hours_check CHECK ((length(hours) <= 600)),
  constraint vendors_hours_last_check CHECK ((length(hours_last) <= 600)),
  constraint vendors_hours_source_check CHECK ((length(hours_source) <= 200)),
  constraint vendors_hours_verified_how_check CHECK ((hours_verified_how = ANY (ARRAY[''::text, 'spoke'::text, 'visited'::text]))),
  constraint "vendors_listedPriceVatTreatment_check" CHECK (("listedPriceVatTreatment" = ANY (ARRAY[''::text, 'including_vat'::text, 'plus_vat'::text, 'not_applicable'::text]))),
  constraint vendors_maps_link_check CHECK (((maps_link = ''::text) OR (maps_link ~* '^https?://'::text))),
  constraint vendors_name_check CHECK ((length(TRIM(BOTH FROM name)) > 0)),
  constraint "vendors_priceBasis_check" CHECK (("priceBasis" = ANY (ARRAY['Per person'::text, 'Per group'::text, 'Per vehicle'::text, 'Per guide'::text, 'Per hour'::text, 'Per day'::text, 'Flat rate'::text, 'Custom'::text]))),
  constraint "vendors_rateReliability_check" CHECK (("rateReliability" = ANY (ARRAY[''::text, '1'::text, '2'::text, '3'::text, '4'::text, '5'::text]))),
  constraint "vendors_rateService_check" CHECK (("rateService" = ANY (ARRAY[''::text, '1'::text, '2'::text, '3'::text, '4'::text, '5'::text]))),
  constraint "vendors_rateValue_check" CHECK (("rateValue" = ANY (ARRAY[''::text, '1'::text, '2'::text, '3'::text, '4'::text, '5'::text]))),
  constraint vendors_region_check CHECK ((length(region) <= 60)),
  constraint vendors_reservation_check CHECK ((reservation = ANY (ARRAY[''::text, 'required'::text, 'recommended'::text, 'not_needed'::text]))),
  constraint vendors_review_status_check CHECK ((review_status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]))),
  constraint vendors_tags_check CHECK ((length(tags) <= 300))
);
alter table public.vendors enable row level security;
CREATE INDEX vendors_claimed_by_idx ON public.vendors USING btree (claimed_by) WHERE (claimed_by <> ''::text);
CREATE INDEX vendors_name_norm_idx ON public.vendors USING btree (name_norm);
CREATE INDEX vendors_category_idx ON public.vendors USING btree (category);


-- ===== Foreign keys =====
alter table public.driver_reviews add constraint driver_reviews_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE CASCADE;
alter table public.driver_reviews add constraint driver_reviews_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE SET NULL;
alter table public.driver_vendors add constraint driver_vendors_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE CASCADE;
alter table public.driver_vendors add constraint driver_vendors_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;

alter table public.bookings add constraint bookings_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;
alter table public.bookings add constraint bookings_quote_id_fkey FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE SET NULL;
alter table public.action_log add constraint action_log_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;

alter table public.change_requests add constraint change_requests_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;

alter table public.quote_lines add constraint quote_lines_option_id_fkey FOREIGN KEY (option_id) REFERENCES quote_options(id) ON DELETE CASCADE;

alter table public.quote_options add constraint quote_options_quote_id_fkey FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE CASCADE;

alter table public.quotes add constraint quotes_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;

alter table public.reservation_reports add constraint reservation_reports_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;

alter table public.vendor_admin_notes add constraint vendor_admin_notes_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;

alter table public.vendor_deals add constraint vendor_deals_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;

alter table public.vendor_files add constraint vendor_files_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;
alter table public.vendor_files add constraint vendor_files_quote_id_fkey FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE SET NULL;

alter table public.vendor_food add constraint vendor_food_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;

alter table public.vendor_notes add constraint vendor_notes_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;

alter table public.vendor_prices add constraint vendor_prices_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;

alter table public.vendor_reports add constraint vendor_reports_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;

alter table public.vendors add constraint vendors_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES vendors(id) ON DELETE SET NULL;

alter table public.job_offers add constraint job_offers_job_id_fkey FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE;
alter table public.member_days add constraint member_days_job_id_fkey FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE;
alter table public.vendor_claims add constraint vendor_claims_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;


-- ===== Functions (RPCs; all data access goes through these) =====

-- (_phone_norm sits here because _is_own, below, calls it)
CREATE OR REPLACE FUNCTION public._phone_norm(p text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select case when d like '00972%' then '0' || substr(d, 6) when d like '972%' and length(d) >= 11 then '0' || substr(d, 4) else d end
  from (select regexp_replace(coalesce(p,''), '\D', '', 'g') d) x
$function$
;

-- Claimed pages and guide rules (D-12, D-14, D-16): internal helpers, not RPCs.
-- Is this supplier a guide? Main category Guide, or Guide under "also offers".
create or replace function public._is_guide(v public.vendors)
 returns boolean language sql immutable set search_path to ''
as $function$
  select v.category = 'Guide' or coalesce(v.also_categories,'') ~* '(^|,)\s*Guide\s*(,|$)'
$function$
;

-- Is this supplier page the member's own? He claimed it, or his own phone number or email is on it.
create or replace function public._is_own(v public.vendors, m public.members)
 returns boolean language sql immutable set search_path to ''
as $function$
  select coalesce(m.id is not null and not m.is_admin and (
       (v.claimed_by <> '' and v.claimed_by = m.email)
    or (length(public._phone_norm(m.phone)) >= 9 and (
            position(right(public._phone_norm(m.phone), 9) in regexp_replace(coalesce(v.phone,''), '\D', '', 'g')) > 0
         or position(right(public._phone_norm(m.phone), 9) in regexp_replace(coalesce(v.whatsapp,''), '\D', '', 'g')) > 0))
    or (m.email <> '' and position(m.email in lower(coalesce(v.email,''))) > 0)), false)
$function$
;

-- Is this driver the member himself (same phone number), or a driver of a company page that is the member's own?
create or replace function public._driver_own(d public.drivers, m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select coalesce(m.id is not null and not m.is_admin and (
       (length(public._phone_norm(m.phone)) >= 9 and right(public._phone_norm(m.phone), 9) = right(d.phone_norm, 9))
    or exists (select 1 from public.driver_vendors dv join public.vendors v on v.id = dv.vendor_id where dv.driver_id = d.id and public._is_own(v, m))), false)
$function$
;

-- Is this member a guide? His role says so, or he has claimed a guide's page.
create or replace function public._is_guide_member(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select coalesce(m.id is not null and not m.is_admin and (m.role = 'Licensed tour guide'
    or exists (select 1 from public.vendors v where v.claimed_by = m.email and public._is_guide(v))), false)
$function$
;

-- Limited members (organisations that are not in tourism, D-15, 3 Oct 2026): who may see what. Internal helpers, not RPCs.
-- The member behind this call, as _auth saw him. Null before _auth has run.
create or replace function public._me()
 returns public.members language sql stable security definer set search_path to ''
as $function$
  select m from public.members m where m.id = nullif(current_setting('app.member', true), '')::uuid
$function$;

-- Which section of the list a category belongs to.
create or replace function public._section_of(p_category text)
 returns text language sql immutable set search_path to ''
as $function$
  select case p_category when 'Transport' then 'transport' when 'Guide' then 'guides' when 'Hotel' then 'hotels'
    when 'Restaurant' then 'food' when 'Winery' then 'food'
    when 'Attraction / Site' then 'sites' when 'Activity' then 'sites' when 'Adventure' then 'sites' when 'National Parks' then 'sites'
    else 'other' end
$function$;

-- A limited member: an organisation that is not in tourism. Eretz Israel Tours is never limited.
create or replace function public._limited(m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select coalesce(m.member_type = 'limited' and not m.is_admin, false)
$function$;

-- May this member see a supplier of this category (main, or one of its "also offers")?
create or replace function public._can_see(m public.members, p_category text, p_also text)
 returns boolean language sql stable set search_path to ''
as $function$
  select case when not public._limited(m) then true
    else exists (select 1 from unnest(array[coalesce(p_category,'')] || string_to_array(coalesce(p_also,''), ',')) c
                 where trim(c) <> '' and public._section_of(trim(c)) = any (string_to_array(m.sections, ','))) end
$function$;

-- Does this member read guides' and agents' reviews on a supplier of this category?
-- Transport has its own switch (drivers, bus companies, van drivers); everything else follows see_reviews.
create or replace function public._reviews_open(m public.members, p_category text, p_also text)
 returns boolean language sql stable set search_path to ''
as $function$
  select case when not public._limited(m) then true
    when p_category = 'Transport' or coalesce(p_also,'') ~* '(^|,)\s*Transport\s*(,|$)' then m.see_transport_reviews
    else m.see_reviews end
$function$;

-- One price line, for one member.
--   Own lines always. Private lines and private-price suppliers: owner and Eretz Israel Tours only.
--   Organisation rates (org): everyone. Another member's personal line: nobody else.
--   A limited member: no agent rates, and no prices at all on a guide unless see_guide_rates.
create or replace function public._price_visible(p public.vendor_prices, v public.vendors, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select case when coalesce(m.is_admin, false) then true
    when p.owner <> '' and p.owner = m.email then true
    when v.prices_private or p.private then false
    when p.org then true
    when p.owner <> '' then false
    when public._limited(m) then (not p.is_agent) and not (v.category = 'Guide' and not m.see_guide_rates)
    else true end
$function$;

-- One note, for one member. A limited member reads notes written by organisations, his own, what was copied from the
-- supplier's website, and everything else only where his switches open guides' and agents' reviews.
create or replace function public._note_visible(n public.vendor_notes, v public.vendors, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select coalesce(m.is_admin, false) or (
        not public._is_own(v, m)
    and (n.author = m.email or (n.status = 'approved' and not n.private))
    and (not public._limited(m) or n.org or n.author = m.email or n.author like 'import from websites%'
         or public._reviews_open(m, v.category, v.also_categories)))
$function$;

-- A file on a supplier, for a limited member: his own, another organisation's, or a photo or kosher certificate.
-- Price lists, receipts, contracts, booking confirmations and quotes from guides and agents can carry agent rates.
create or replace function public._file_visible(f public.vendor_files, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select case when coalesce(m.is_admin, false) or f.uploaded_by = m.email then true
    when f.private then false
    when public._limited(m) then f.org or f.kind in ('Photo','Kosher certificate')
    else true end
$function$;

-- For the files edge function (service key): may this member open this supplier's files, and is he limited?
create or replace function public._file_scope(p_member uuid, p_vendor text)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('can_see', m.is_admin or (not v.hidden and public._can_see(m, v.category, v.also_categories)),
    'limited', public._limited(m))
  from public.members m, public.vendors v where m.id = p_member and v.id = p_vendor
$function$;

-- Is a quote a transport quote, a guide quote, or something else?
create or replace function public._quote_kind(q public.quotes, v public.vendors)
 returns text language sql stable security definer set search_path to ''
as $function$
  select case
    when v.category = 'Guide' or exists (select 1 from public.quote_options o where o.quote_id = q.id and o.service in ('guide','guide_vehicle')) then 'guide'
    when v.category = 'Transport' or (exists (select 1 from public.quote_options o where o.quote_id = q.id)
      and not exists (select 1 from public.quote_options o where o.quote_id = q.id
        and o.service <> all (array['bus','midibus','van20','van16','van10','van8','car','jeep_vehicle','transfer']))) then 'transport'
    else 'other' end
$function$;

-- One quote, for one member (the supplier itself must already be visible to him, and not hidden).
--   Owner and Eretz Israel Tours: always. Not shared, or a private-price supplier: nobody else.
--   Full members: every shared quote. Limited members: quotes from organisations, bus and van quotes with see_quotes,
--   guide quotes with see_guide_rates. Never another guide's or agent's quote for a hotel, a site or an activity.
create or replace function public._quote_visible(q public.quotes, v public.vendors, m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select case when coalesce(m.is_admin, false) then true
    when public._limited(m) and not public._can_see(m, v.category, v.also_categories) then false
    when q.owner = m.email then true
    when not q.shared or v.prices_private then false
    when not public._limited(m) then true
    when q.org then true
    when public._quote_kind(q, v) = 'transport' then m.see_quotes and 'transport' = any (string_to_array(m.sections, ','))
    else false end   -- D-18: an organisation never sees what a guide or an agent was quoted, except for transport
$function$;

CREATE OR REPLACE FUNCTION public._all_fields()
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select array['name','category','active','contactPerson','phone','whatsapp','email','website','location','languages','kosher','maxCap','listedPrice','listedPriceVatTreatment','agentPrice','agentPriceVatTreatment','maxPax','priceBasis','currency','payTerms','cancelPolicy','cancelNoticeAmount','cancelNoticeUnit','cancelDayType','cancelPenalty','cancelPolicyVerifiedDate','npResLink','rateReliability','rateService','rateValue','strengths','weaknesses','notes','region','tags','experience_years','agent_link','agent_howto','also_categories','maps_link','hours','hours_last']::text[]
$function$
;

-- _auth also remembers WHICH member is calling (app.member), so the helpers below can apply that member's access.
CREATE OR REPLACE FUNCTION public._auth(p_token text, p_admin boolean DEFAULT false)
 RETURNS members
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  select * into m from public.members where token_hash = public._hash(p_token) and status = 'approved';
  if m.id is null then raise exception 'Your link is not active. Ask Eretz Israel Tours for a new one.' using errcode = '28000'; end if;
  if p_admin and not m.is_admin then raise exception 'Only Eretz Israel Tours can do that.' using errcode = '42501'; end if;
  perform set_config('app.editor', m.email, true);
  perform set_config('app.admin', case when m.is_admin then 'on' else 'off' end, true);
  perform set_config('app.member', m.id::text, true);
  update public.members set last_seen_at = now() where id = m.id and (last_seen_at is null or last_seen_at < now() - interval '10 minutes');
  return m;
end $function$;

CREATE OR REPLACE FUNCTION public._hash(p text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$ select encode(extensions.digest(coalesce(p,''),'sha256'),'hex') $function$
;

CREATE OR REPLACE FUNCTION public._locked_fields()
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select array['name','category','active','contactPerson','phone','whatsapp','email','website','npResLink','listedPrice','listedPriceVatTreatment','agentPrice','agentPriceVatTreatment','maxPax','priceBasis','currency','payTerms','cancelPolicy','cancelNoticeAmount','cancelNoticeUnit','cancelDayType','cancelPenalty','cancelPolicyVerifiedDate']::text[]
$function$
;

CREATE OR REPLACE FUNCTION public._name(p_email text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case when p_email is null or p_email = '' then ''
    when p_email in ('import','system') or p_email like 'import from%' then 'Eretz Israel Tours'
    else coalesce((select case when m.is_admin then 'Eretz Israel Tours' else m.name end from public.members m where m.email = split_part(p_email,' (',1) order by m.created_at limit 1), 'A colleague') end
$function$
;

CREATE OR REPLACE FUNCTION public._new_token()
 RETURNS text
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select encode(extensions.gen_random_bytes(24),'hex') $function$
;

CREATE OR REPLACE FUNCTION public._price_clean(p jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'label', left(coalesce(p->>'label',''),120), 'audience', coalesce(nullif(p->>'audience',''),'Adult'),
    'age_from', left(coalesce(p->>'age_from',''),10), 'age_to', left(coalesce(p->>'age_to',''),10),
    'pax_min', left(coalesce(p->>'pax_min',''),10), 'pax_max', left(coalesce(p->>'pax_max',''),10),
    'season', left(coalesce(p->>'season',''),120), 'price', coalesce(p->>'price',''),
    'currency', coalesce(nullif(p->>'currency',''),'ILS'), 'vat', coalesce(p->>'vat',''),
    'basis', coalesce(nullif(p->>'basis',''),'Per person'), 'is_agent', coalesce((p->>'is_agent')::boolean, true),
    'source', left(coalesce(p->>'source',''),300), 'checked_on', coalesce(p->>'checked_on',''), 'note', left(coalesce(p->>'note',''),500),
    'private', coalesce((p->>'private')::boolean, false))
$function$
;

CREATE OR REPLACE FUNCTION public._price_write(p_vendor text, p_id uuid, c jsonb, p_editor text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare nid uuid;
begin
  if p_id is null then
    insert into public.vendor_prices (vendor_id,label,audience,age_from,age_to,pax_min,pax_max,season,price,currency,vat,basis,is_agent,source,checked_on,note,private,created_by,updated_by)
    values (p_vendor, c->>'label', c->>'audience', c->>'age_from', c->>'age_to', c->>'pax_min', c->>'pax_max', c->>'season', c->>'price', c->>'currency', c->>'vat', c->>'basis', (c->>'is_agent')::boolean, c->>'source', c->>'checked_on', c->>'note', coalesce((c->>'private')::boolean,false), p_editor, p_editor)
    returning id into nid;
    return nid;
  end if;
  update public.vendor_prices set label=c->>'label', audience=c->>'audience', age_from=c->>'age_from', age_to=c->>'age_to', pax_min=c->>'pax_min', pax_max=c->>'pax_max', season=c->>'season', price=c->>'price', currency=c->>'currency', vat=c->>'vat', basis=c->>'basis', is_agent=(c->>'is_agent')::boolean, source=c->>'source', checked_on=c->>'checked_on', note=c->>'note', private=coalesce((c->>'private')::boolean,private), updated_by=p_editor, updated_at=now()
  where id = p_id;
  return p_id;
end $function$
;

CREATE OR REPLACE FUNCTION public._fees_clean(p jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select coalesce(jsonb_object_agg(k, jsonb_strip_nulls(jsonb_build_object(
      's', v->>'s',
      'amt', case when v->>'s' = 'extra' and coalesce(v->>'amt','') ~ '^\d{1,7}(\.\d{1,2})?$' then v->>'amt' end,
      'note', nullif(left(trim(coalesce(v->>'note','')),80),'')))), '{}'::jsonb)
  from jsonb_each(case when jsonb_typeof(p) = 'object' then p else '{}'::jsonb end) e(k, v)
  where k = any (array['overtime','extra_km','tolls','overnight','night','shabbat','parking','fuel','vehicle','meals','cleaning','service','min_charge','equipment','instructor','other'])
    and jsonb_typeof(v) = 'object' and v->>'s' in ('incl','extra')
$function$
;

-- A quote: also says whether an organisation added it.
CREATE OR REPLACE FUNCTION public._quote_json(q quotes, p_full boolean)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select json_build_object('id',q.id,'vendor_id',q.vendor_id,'title',case when p_full then q.title else '' end,
    'date_from',q.date_from,'date_to',q.date_to,'pax',q.pax,'units',q.units,'received_on',q.received_on,'valid_until',q.valid_until,
    'ref',case when p_full then q.ref else '' end,'status',q.status,'currency',q.currency,'vat',q.vat,'conditions',q.conditions,
    'private_note',case when p_full then q.private_note else '' end,'shared',q.shared,'org',q.org,
    'mine', q.owner = coalesce(current_setting('app.editor', true),''),
    'owner',case when p_full then q.owner else '' end,'owner_name',case when p_full then q.owner_name else '' end,
    'owner_role',case when p_full then (select mm.role from public.members mm where mm.email = q.owner limit 1) else '' end,
    'owner_admin',case when p_full then (select mm.is_admin from public.members mm where mm.email = q.owner limit 1) end,
    'can_edit',p_full,'created_at',q.created_at,'updated_at',q.updated_at,
    'files',case when p_full then (select count(*) from public.vendor_files f where f.quote_id = q.id) else 0 end,
    'options',coalesce((select json_agg(json_build_object('id',o.id,'name',o.name,'note',o.note,
        'service',o.service,'seats',o.seats,'hours_incl',o.hours_incl,'km_incl',o.km_incl,'fees',o.fees,
        'lines',coalesce((select json_agg(l order by l.sort) from public.quote_lines l where l.option_id = o.id),'[]'::json)) order by o.sort)
      from public.quote_options o where o.quote_id = q.id),'[]'::json))
$function$;

CREATE OR REPLACE FUNCTION public._vendor_apply(p_id text, p_vals jsonb)
 RETURNS vendors
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.vendors; o public.vendors;
begin
  select * into r from public.vendors where id = p_id;
  if r.id is null then raise exception 'That supplier no longer exists.'; end if;
  o := r;
  r := jsonb_populate_record(r, p_vals);
  -- Changed hours are unverified again, and no longer "from their website".
  if r.hours is distinct from o.hours or r.hours_last is distinct from o.hours_last then
    r.hours_verified_at := null; r.hours_verified_by := ''; r.hours_verified_how := ''; r.hours_source := '';
  end if;
  update public.vendors v set (name,category,active,"contactPerson",phone,whatsapp,email,website,location,languages,kosher,"maxCap","listedPrice","listedPriceVatTreatment","agentPrice","agentPriceVatTreatment","maxPax","priceBasis",currency,"payTerms","cancelPolicy","cancelNoticeAmount","cancelNoticeUnit","cancelDayType","cancelPenalty","cancelPolicyVerifiedDate","npResLink","rateReliability","rateService","rateValue",strengths,weaknesses,notes,region,tags,experience_years,agent_link,agent_howto,also_categories,maps_link,hours,hours_last,hours_source,hours_verified_at,hours_verified_by,hours_verified_how)
    = (r.name,r.category,r.active,r."contactPerson",r.phone,r.whatsapp,r.email,r.website,r.location,r.languages,r.kosher,r."maxCap",r."listedPrice",r."listedPriceVatTreatment",r."agentPrice",r."agentPriceVatTreatment",r."maxPax",r."priceBasis",r.currency,r."payTerms",r."cancelPolicy",r."cancelNoticeAmount",r."cancelNoticeUnit",r."cancelDayType",r."cancelPenalty",r."cancelPolicyVerifiedDate",r."npResLink",r."rateReliability",r."rateService",r."rateValue",r.strengths,r.weaknesses,r.notes,r.region,r.tags,r.experience_years,r.agent_link,r.agent_howto,r.also_categories,r.maps_link,r.hours,r.hours_last,r.hours_source,r.hours_verified_at,r.hours_verified_by,r.hours_verified_how)
  where v.id = p_id returning * into r;
  return r;
end $function$
;

CREATE OR REPLACE FUNCTION public._vendor_json(p_id text)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select row_to_json(x) from (select v.*,
    (select count(*) from public.vendor_files f where f.vendor_id=v.id and f.quote_id is null) as _files,
    (select count(*) from public.vendor_prices p where p.vendor_id=v.id) as _prices,
    (select count(*) from public.vendor_deals d where d.vendor_id=v.id and (d.valid_to='' or d.valid_to >= to_char(now(),'YYYY-MM-DD'))) as _deals,
    (select count(*) from public.vendor_notes n where n.vendor_id=v.id) as _notes,
    (select count(*) from public.change_requests c where c.vendor_id=v.id and c.status='pending') as _requests
    from public.vendors v where v.id = p_id) x
$function$
;

-- A supplier as one member (not Eretz Israel Tours) receives it.
create or replace function public._vendor_for(v public.vendors, m public.members)
 returns json language sql stable security definer set search_path to ''
as $function$
  select (public._vendor_json(v.id)::jsonb
      || case when v.prices_private then jsonb_build_object('agentPrice','','listedPrice','','agentPriceVatTreatment','','listedPriceVatTreatment','','maxPax','','retail_price','') else '{}'::jsonb end
      || case when x.lim then jsonb_build_object('agentPrice','','agentPriceVatTreatment','','agent_link','','agent_howto','') else '{}'::jsonb end
      || case when x.lim and v.category = 'Guide' and not m.see_guide_rates then jsonb_build_object('listedPrice','','listedPriceVatTreatment','','maxPax','','retail_price','') else '{}'::jsonb end
      || case when (x.lim and not x.rev) or x.own then jsonb_build_object('rateReliability','','rateService','','rateValue','','strengths','','weaknesses','','notes','') else '{}'::jsonb end
      || case when x.lim then jsonb_build_object(
           '_files', (select count(*) from public.vendor_files f where f.vendor_id = v.id and f.quote_id is null and public._file_visible(f, m))) else '{}'::jsonb end
      || jsonb_build_object('_prices', (select count(*) from public.vendor_prices p where p.vendor_id = v.id and public._price_visible(p, v, m)),
           '_notes', (select count(*) from public.vendor_notes n where n.vendor_id = v.id and public._note_visible(n, v, m)),
           'created_by', public._name(v.created_by), 'updated_by', public._name(v.updated_by), 'hours_verified_by', public._name(v.hours_verified_by),
           'claimed_by', '', '_claimed', v.claimed_by <> '', 'claimed_name', public._name(v.claimed_by),
           '_mine', coalesce(v.claimed_by <> '' and v.claimed_by = m.email, false), '_own', x.own)
    )::json
  from (select public._limited(m) as lim, public._reviews_open(m, v.category, v.also_categories) as rev, public._is_own(v, m) as own) x
$function$;

CREATE OR REPLACE FUNCTION public._vendor_view(p_id text, p_admin boolean, p_email text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.vendors; m public.members;
begin
  select * into v from public.vendors where id = p_id;
  if v.id is null then return null; end if;
  if p_admin then
    return (public._vendor_json(p_id)::jsonb || jsonb_build_object('_prices',(select count(*) from public.vendor_prices p where p.vendor_id=p_id),
      '_claimed', v.claimed_by <> '', 'claimed_name', public._name(v.claimed_by), '_mine', false, '_own', false))::json;
  end if;
  m := public._me();
  if m.id is null or m.email is distinct from p_email then
    select * into m from public.members mm where mm.email = p_email order by mm.created_at limit 1;
  end if;
  return public._vendor_for(v, m);
end $function$;

-- A hidden supplier is for Eretz Israel Tours only; a limited member also needs the supplier's section.
CREATE OR REPLACE FUNCTION public._visible(p_vendor text, p_admin boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.vendors; m public.members;
begin
  if p_admin then return; end if;
  select * into v from public.vendors where id = p_vendor;
  if v.id is null then return; end if;
  if v.hidden then raise exception 'That supplier is not available.'; end if;
  m := public._me();
  if not public._can_see(m, v.category, v.also_categories) then raise exception 'That supplier is not available.'; end if;
end $function$;

-- Who wrote something: name and role. An organisation shows its own name in place of a role.
CREATE OR REPLACE FUNCTION public._who(p_email text)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case when p_email is null or p_email in ('','import','system') or p_email like 'import from%' then null
    else coalesce((select json_build_object('name',m.name,
          'role',case when m.org <> '' then m.org else m.role end,
          'admin',m.is_admin,'org',public._limited(m))
        from public.members m where m.email = split_part(p_email,' (',1) order by m.created_at limit 1),
                  json_build_object('name','A colleague','role','','admin',false)) end
$function$;

-- A driver with his reviews. A limited member without see_transport_reviews reads only organisations' reviews and his own.
CREATE OR REPLACE FUNCTION public._driver_json(d drivers, p_email text, p_admin boolean)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select json_build_object('id',d.id,'name',d.name,'phone',d.phone,'drives',d.drives,
    'can_edit', p_admin or d.created_by = p_email,
    'n',case when x.hide then 0 else (select count(*) from public.driver_reviews r where r.driver_id = d.id and (x.every or r.org or r.author = p_email) and (p_admin or not r.private or r.author = p_email)) end,
    'avg',case when x.hide then null else (select round(avg(r.rating::int)::numeric, 1) from public.driver_reviews r where r.driver_id = d.id and (x.every or r.org or r.author = p_email) and (p_admin or not r.private or r.author = p_email)) end,
    'some_hidden', not x.every, 'reviews_hidden', x.hide,
    'vendors',coalesce((select json_agg(json_build_object('id',v.id,'name',v.name) order by v.name)
        from public.driver_vendors dv join public.vendors v on v.id = dv.vendor_id
        where dv.driver_id = d.id and (p_admin or (not v.hidden and public._can_see(x.m, v.category, v.also_categories)))),'[]'::json),
    'reviews',case when x.hide then '[]'::json else coalesce((select json_agg(json_build_object('id',r.id,'rating',r.rating,'tags',r.tags,'body',r.body,'trip_month',r.trip_month,
          'vendor_id',case when v.id is not null and (p_admin or (not v.hidden and public._can_see(x.m, v.category, v.also_categories))) then v.id end,
          'vendor_name',case when v.id is not null and (p_admin or (not v.hidden and public._can_see(x.m, v.category, v.also_categories))) then v.name end,
          'by',public._who(r.author),'mine',r.author = p_email,'org',r.org,'private',r.private,'created_at',r.created_at) order by r.created_at desc)
        from public.driver_reviews r left join public.vendors v on v.id = r.vendor_id
        where r.driver_id = d.id and (x.every or r.org or r.author = p_email) and (p_admin or not r.private or r.author = p_email)),'[]'::json) end)
  from (select q.m, (p_admin or not public._limited(q.m) or coalesce((q.m).see_transport_reviews, true)) as every,
               (not p_admin) and public._driver_own(d, q.m) as hide from (select public._me() as m) q) x
$function$;

CREATE OR REPLACE FUNCTION public.accept_terms(p_token text, p_version text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  update public.members set terms_version = left(p_version,20), terms_accepted_at = now()
  where token_hash = public._hash(p_token) and status in ('pending','approved');
end $function$
;

CREATE OR REPLACE FUNCTION public.ack_reminder(p_token text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  update public.members set reminder_seen_at = now() where token_hash = public._hash(p_token) and status = 'approved';
end $function$
;

CREATE OR REPLACE FUNCTION public.activity(p_token text, p_vendor text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  if coalesce(p_vendor,'') <> '' then
    return json_build_object(
      'counts', coalesce((select json_object_agg(action, n) from (select action, count(*) n from public.action_log where vendor_id = p_vendor and action <> 'open' group by action) t), '{}'),
      'views', (select count(*) from public.action_log where vendor_id = p_vendor and action = 'open'),
      'recent', coalesce((select json_agg(json_build_object('member_name',a.member_name,'member',a.member,'action',a.action,'created_at',a.created_at) order by a.created_at desc) from (select * from public.action_log where vendor_id = p_vendor and action <> 'open' order by created_at desc limit 15) a), '[]'));
  end if;
  return json_build_object(
    'recent', coalesce((select json_agg(json_build_object('member_name',a.member_name,'member',a.member,'action',a.action,'created_at',a.created_at,'vendor_id',a.vendor_id,'vendor_name',v.name) order by a.created_at desc)
        from (select * from public.action_log where action <> 'open' order by created_at desc limit 100) a left join public.vendors v on v.id = a.vendor_id), '[]'),
    'top', coalesce((select json_agg(json_build_object('vendor_id',t.vendor_id,'vendor_name',v.name,'n',t.n,'people',t.people) order by t.n desc)
        from (select vendor_id, count(*) n, count(distinct member) people from public.action_log where action <> 'open' and created_at > now() - interval '30 days' and vendor_id is not null group by vendor_id order by n desc limit 15) t join public.vendors v on v.id = t.vendor_id), '[]'),
    'by_person', coalesce((select json_agg(json_build_object('member_name',t.member_name,'n',t.n) order by t.n desc)
        from (select max(member_name) member_name, count(*) n from public.action_log where action <> 'open' and created_at > now() - interval '30 days' group by member order by n desc limit 15) t), '[]'));
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_note_save(p_token text, p_vendor text, p_body text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  insert into public.vendor_admin_notes (vendor_id, body) values (p_vendor, left(coalesce(p_body,''),5000))
  on conflict (vendor_id) do update set body = excluded.body, updated_at = now();
end $function$
;

CREATE OR REPLACE FUNCTION public.deal_add(p_token text, p_vendor text, p_data jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  insert into public.vendor_deals (vendor_id, kind, provider, title, details, code, link, valid_to, reported_by)
  values (p_vendor, coalesce(nullif(p_data->>'kind',''),'Other'), left(coalesce(p_data->>'provider',''),80), left(trim(coalesce(p_data->>'title','')),160),
    left(coalesce(p_data->>'details',''),1000), left(coalesce(p_data->>'code',''),80), left(coalesce(p_data->>'link',''),500), coalesce(p_data->>'valid_to',''), m.email);
end $function$
;

CREATE OR REPLACE FUNCTION public.deal_delete(p_token text, p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  delete from public.vendor_deals where id = p_id and (m.is_admin or reported_by = m.email);
end $function$
;

-- Finding a driver by phone number is part of the transport section.
CREATE OR REPLACE FUNCTION public.driver_find(p_token text, p_phone text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; d public.drivers;
begin
  m := public._auth(p_token);
  if public._limited(m) and not ('transport' = any (string_to_array(m.sections, ','))) then return null; end if;
  select * into d from public.drivers where phone_norm = public._phone_norm(p_phone);
  if d.id is null then return null; end if;
  return public._driver_json(d, m.email, m.is_admin);
end $function$;

CREATE OR REPLACE FUNCTION public.driver_remove(p_token text, p_driver uuid, p_vendor text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  if coalesce(p_vendor,'') = '' then
    if not m.is_admin then raise exception 'Only Eretz Israel Tours can do that.' using errcode = '42501'; end if;
    delete from public.drivers where id = p_driver;
  else
    delete from public.driver_vendors where driver_id = p_driver and vendor_id = p_vendor and (m.is_admin or added_by = m.email);
    if not found then raise exception 'Only Eretz Israel Tours, or the person who added him here, can take a driver off this supplier.'; end if;
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.driver_review_add(p_token text, p_driver uuid, p_vendor text, p_review jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; rid uuid; vid text := nullif(p_vendor,'');
begin
  m := public._auth(p_token);
  if public._limited(m) and not ('transport' = any (string_to_array(m.sections, ','))) then raise exception 'Driver reviews are not part of your access.' using errcode = '42501'; end if;
  if not exists (select 1 from public.drivers where id = p_driver) then raise exception 'That driver is no longer on the list.'; end if;
  if exists (select 1 from public.drivers d where d.id = p_driver and public._driver_own(d, m)) then raise exception 'You cannot review yourself or your own company''s drivers.'; end if;
  if coalesce(p_review->>'rating','') !~ '^[1-5]$' then raise exception 'Give a rating from 1 to 5.'; end if;
  if vid is not null then
    perform public._visible(vid, m.is_admin);
    if not exists (select 1 from public.vendors where id = vid) then raise exception 'That supplier no longer exists.'; end if;
    insert into public.driver_vendors (driver_id, vendor_id, added_by) values (p_driver, vid, m.email) on conflict do nothing;
  end if;
  insert into public.driver_reviews (driver_id, vendor_id, rating, tags, body, trip_month, author, author_name, org, private)
  values (p_driver, vid, p_review->>'rating', left(trim(coalesce(p_review->>'tags','')),300), left(trim(coalesce(p_review->>'body','')),1500),
    case when coalesce(p_review->>'trip_month','') ~ '^\d{4}-\d{2}$' then p_review->>'trip_month' else '' end, m.email, m.name, public._limited(m),
    coalesce(p_review->>'private','') in ('true','t'))
  returning id into rid;
  return rid;
end $function$;

CREATE OR REPLACE FUNCTION public.driver_review_delete(p_token text, p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  delete from public.driver_reviews where id = p_id and (author = m.email or m.is_admin);
end $function$
;

CREATE OR REPLACE FUNCTION public.driver_save(p_token text, p_vendor text, p_driver jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; d public.drivers; did uuid := nullif(p_driver->>'id','')::uuid;
  nm text := trim(left(coalesce(p_driver->>'name',''),80)); ph text := trim(left(coalesce(p_driver->>'phone',''),40));
  pn text := public._phone_norm(p_driver->>'phone'); dr text := trim(left(coalesce(p_driver->>'drives',''),120));
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if not exists (select 1 from public.vendors where id = p_vendor) then raise exception 'That supplier no longer exists.'; end if;
  if pn !~ '^\d{7,15}$' then raise exception 'Enter the driver''s phone number. It is how colleagues know it is the same driver.'; end if;
  if did is not null then
    select * into d from public.drivers where id = did;
    if d.id is null then raise exception 'That driver is no longer on the list.'; end if;
    if not (m.is_admin or d.created_by = m.email) then raise exception 'Only the person who added this driver, or Eretz Israel Tours, can change his details.'; end if;
    if nm = '' then raise exception 'Enter the driver''s name.'; end if;
    if exists (select 1 from public.drivers where phone_norm = pn and id <> did) then raise exception 'That phone number already belongs to another driver on the list.'; end if;
    update public.drivers set name = nm, phone = ph, phone_norm = pn, drives = dr, updated_at = now() where id = did;
  else
    select id into did from public.drivers where phone_norm = pn;
    if did is null then
      if nm = '' then raise exception 'Enter the driver''s name.'; end if;
      insert into public.drivers (name, phone, phone_norm, drives, created_by) values (nm, ph, pn, dr, m.email) returning id into did;
    end if;
  end if;
  insert into public.driver_vendors (driver_id, vendor_id, added_by) values (did, p_vendor, m.email) on conflict do nothing;
  return did;
end $function$
;

CREATE OR REPLACE FUNCTION public.drivers_list(p_token text, p_vendor text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  return coalesce((select json_agg(public._driver_json(d, m.email, m.is_admin) order by d.name)
    from public.drivers d join public.driver_vendors dv on dv.driver_id = d.id where dv.vendor_id = p_vendor), '[]'::json);
end $function$
;

CREATE OR REPLACE FUNCTION public.feedback_add(p_token text, p_kind text, p_message text, p_context text DEFAULT ''::text, p_device text DEFAULT ''::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; nid uuid;
begin
  m := public._auth(p_token);
  insert into public.feedback (kind, message, context, device, author, author_name)
  values (coalesce(nullif(p_kind,''),'Suggestion'), trim(p_message), left(coalesce(p_context,''),300), left(coalesce(p_device,''),300), m.email, m.name)
  returning id into nid;
  return nid;
end $function$
;

CREATE OR REPLACE FUNCTION public.feedback_list(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return coalesce((select json_agg(json_build_object('id',f.id,'kind',f.kind,'message',f.message,'context',f.context,'device',case when m.is_admin then f.device else '' end,
      'has_file',f.file_path is not null,'status',f.status,'reply',f.reply,'author',f.author,'author_name',f.author_name,'created_at',f.created_at,'updated_at',f.updated_at)
    order by (f.status='New') desc, f.created_at desc)
    from public.feedback f where m.is_admin or f.author = m.email), '[]'::json);
end $function$
;

CREATE OR REPLACE FUNCTION public.feedback_update(p_token text, p_id uuid, p_status text, p_reply text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  update public.feedback set status = p_status, reply = left(coalesce(p_reply,''),2000), updated_at = now() where id = p_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.food_add(p_token text, p_vendor text, p_name text, p_kosher text, p_note text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if (select count(*) from public.vendor_food where author = m.email and created_at > now() - interval '1 hour') > 30 then raise exception 'Too many in a short time. Try again later.'; end if;
  insert into public.vendor_food (vendor_id, name, kosher, note, author, author_name) values (p_vendor, trim(p_name), trim(coalesce(p_kosher,'')), trim(coalesce(p_note,'')), m.email, m.name);
end $function$
;

CREATE OR REPLACE FUNCTION public.food_delete(p_token text, p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  delete from public.vendor_food where id = p_id and (author = m.email or m.is_admin);
end $function$
;

CREATE OR REPLACE FUNCTION public.food_list(p_token text, p_vendor text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  return coalesce((select json_agg(json_build_object('id',f.id,'name',f.name,'kosher',f.kosher,'note',f.note,'by',public._who(f.author),'mine',f.author=m.email,'created_at',f.created_at) order by f.created_at desc)
    from public.vendor_food f where f.vendor_id = p_vendor), '[]'::json);
end $function$
;

CREATE OR REPLACE FUNCTION public.hours_verify(p_token text, p_vendor text, p_how text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; v public.vendors;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  select * into v from public.vendors where id = p_vendor;
  if v.id is null then raise exception 'That supplier no longer exists.'; end if;
  if coalesce(p_how,'') = '' then
    -- undo: the person who verified, or Eretz Israel Tours
    if not m.is_admin and v.hours_verified_by <> m.email then raise exception 'Only the person who verified these hours, or Eretz Israel Tours, can undo that.'; end if;
    update public.vendors set hours_verified_at = null, hours_verified_by = '', hours_verified_how = '' where id = p_vendor;
  elsif p_how in ('spoke','visited') then
    if v.hours = '' and v.hours_last = '' then raise exception 'Add the opening hours first.'; end if;
    update public.vendors set hours_verified_at = now(), hours_verified_by = m.email, hours_verified_how = p_how where id = p_vendor;
  else
    raise exception 'Say how you checked: you spoke to them, or you were there.';
  end if;
  return public._vendor_view(p_vendor, m.is_admin, m.email);
end $function$
;

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (select 1 from public.contributors c where c.email = lower(coalesce(auth.jwt()->>'email','')) and c.is_admin);
$function$
;

CREATE OR REPLACE FUNCTION public.is_contributor()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (select 1 from public.contributors c where c.email = lower(coalesce(auth.jwt()->>'email','')));
$function$
;

CREATE OR REPLACE FUNCTION public.log_action(p_token text, p_vendor text, p_action text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  if (select count(*) from public.action_log where member = m.email and created_at > now() - interval '1 minute') > 60 then return; end if;
  insert into public.action_log (vendor_id, member, member_name, action) values (nullif(p_vendor,''), m.email, m.name, p_action);
end $function$
;

CREATE OR REPLACE FUNCTION public.log_filter(p_token text, p_kind text, p_value text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  if (select count(*) from public.filter_log where member = m.email and created_at > now() - interval '1 minute') > 40 then return; end if;
  insert into public.filter_log (member, kind, value) values (m.email, p_kind, left(trim(p_value),80));
end $function$
;

CREATE OR REPLACE FUNCTION public.member_decide(p_token text, p_id uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare prev text; m public.members; u text; s text;
begin
  perform public._auth(p_token, true);
  if p_status not in ('approved','revoked') then raise exception 'Unknown decision'; end if;
  select status into prev from public.members where id = p_id;
  update public.members set status = p_status, decided_at = now() where id = p_id and not is_admin returning * into m;
  if p_status = 'approved' and prev = 'pending' and m.id is not null then
    select value into u from public.app_settings where key = 'welcome_url';
    select value into s from public.app_settings where key = 'welcome_secret';
    if coalesce(u,'') like 'https://script.google.com/%' then
      begin
        perform net.http_post(url := u, body := jsonb_build_object('secret', s, 'to', m.email, 'name', m.name),
          headers := '{"Content-Type":"application/json"}'::jsonb, timeout_milliseconds := 10000);
      exception when others then null; -- a failed email never blocks an approval
      end;
    end if;
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.member_new_link(p_token text, p_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t text := public._new_token();
begin
  perform public._auth(p_token, true);
  update public.members set token_hash = public._hash(t), status = case when status='revoked' then 'approved' else status end, decided_at = coalesce(decided_at, now())
  where id = p_id and not is_admin;
  if not found then raise exception 'Can''t make a link for that person.'; end if;
  return t;
end $function$
;

CREATE OR REPLACE FUNCTION public.members_list(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  return coalesce((select json_agg(json_build_object('id',id,'name',name,'email',email,'phone',phone,'note',note,'role',case when org <> '' then 'Organisation, not in tourism' else role end,'license_no',license_no,'has_proof',proof_path is not null,'status',status,'is_admin',is_admin,'created_at',created_at,'last_seen_at',last_seen_at,'terms_version',terms_version,'terms_accepted_at',terms_accepted_at,
    'member_type',member_type,'sections',sections,'see_quotes',see_quotes,'see_guide_rates',see_guide_rates,'see_transport_reviews',see_transport_reviews,'see_reviews',see_reviews,'org',org,'credentials',credentials) order by (status='pending') desc, created_at desc) from public.members), '[]'::json);
end $function$;

-- Eretz Israel Tours sets what a member sees: full, or limited to chosen sections with four switches.
create or replace function public.member_set_access(p_token text, p_id uuid, p_access jsonb)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare t text := coalesce(nullif(p_access->>'member_type',''), 'full'); s text;
begin
  perform public._auth(p_token, true);
  if t not in ('full','limited') then raise exception 'Choose full or limited.'; end if;
  s := public._csv_keys(p_access->>'sections', array['transport','guides','hotels','sites','food','other']);
  if t = 'limited' and s = '' then raise exception 'Tick at least one section.'; end if;
  update public.members set member_type = t, sections = case when t = 'limited' then s else '' end,
    see_quotes = coalesce((p_access->>'see_quotes')::boolean, true),
    see_guide_rates = coalesce((p_access->>'see_guide_rates')::boolean, false),
    see_transport_reviews = coalesce((p_access->>'see_transport_reviews')::boolean, true),
    see_reviews = coalesce((p_access->>'see_reviews')::boolean, false)
  where id = p_id and not is_admin;
  if not found then raise exception 'Can''t change access for that person.'; end if;
end $function$;

CREATE OR REPLACE FUNCTION public.my_top(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return coalesce((select json_agg(t.vendor_id order by t.score desc) from (
      select a.vendor_id, sum(case when a.action = 'open' then 1 else 3 end * case when a.created_at > now() - interval '30 days' then 2 else 1 end) score
      from public.action_log a join public.vendors v on v.id = a.vendor_id
      where a.member = m.email and a.vendor_id is not null and (m.is_admin or (not v.hidden and public._can_see(m, v.category, v.also_categories)))
      group by a.vendor_id order by score desc limit 8) t), '[]'::json);
end $function$;

CREATE OR REPLACE FUNCTION public.my_usage(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return json_build_object(
    'category', coalesce((select json_object_agg(k, s) from (
        select k, sum(s) s from (
          select v.category k, case when a.action='open' then 1 else 3 end * case when a.created_at > now() - interval '60 days' then 2 else 1 end s
            from public.action_log a join public.vendors v on v.id=a.vendor_id where a.member=m.email
          union all
          select f.value, 2 * case when f.created_at > now() - interval '60 days' then 2 else 1 end from public.filter_log f where f.member=m.email and f.kind='category'
        ) x where coalesce(k,'')<>'' group by k) y), '{}'::json),
    'region', coalesce((select json_object_agg(k, s) from (
        select k, sum(s) s from (
          select v.region k, case when a.action='open' then 1 else 3 end * case when a.created_at > now() - interval '60 days' then 2 else 1 end s
            from public.action_log a join public.vendors v on v.id=a.vendor_id where a.member=m.email
          union all
          select f.value, 2 * case when f.created_at > now() - interval '60 days' then 2 else 1 end from public.filter_log f where f.member=m.email and f.kind='region'
        ) x where coalesce(k,'')<>'' group by k) y), '{}'::json));
end $function$
;

-- A note. From a limited member it is a review, shown to everyone (org = true).
CREATE OR REPLACE FUNCTION public.note_add(p_token text, p_vendor text, p_body text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public.review_post(p_token, p_vendor, p_body, '', false);
end $function$;

-- A note with an optional 1-5 rating: what the app calls a review.
create or replace function public.review_add(p_token text, p_vendor text, p_body text, p_rating text default ''::text)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  perform public.review_post(p_token, p_vendor, p_body, p_rating, false);
end $function$;

CREATE OR REPLACE FUNCTION public.note_delete(p_token text, p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  delete from public.vendor_notes where id = p_id and (m.is_admin or author = m.email);
end $function$
;

CREATE OR REPLACE FUNCTION public.price_delete(p_token text, p_id uuid, p_reason text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; cur public.vendor_prices;
begin
  m := public._auth(p_token);
  select * into cur from public.vendor_prices where id = p_id;
  if cur.id is null then return json_build_object('request', false); end if;
  if m.is_admin or (cur.owner <> '' and cur.owner = m.email) then delete from public.vendor_prices where id = p_id; return json_build_object('request', false); end if;
  if length(trim(coalesce(p_reason,''))) < 3 then raise exception 'Say briefly why this price should be removed.'; end if;
  insert into public.change_requests (vendor_id, kind, target_id, proposed, current, reason, requested_by, requested_name)
  values (cur.vendor_id, 'price_delete', p_id, '{}'::jsonb, to_jsonb(cur), trim(p_reason), m.email, m.name);
  return json_build_object('request', true);
end $function$
;

-- A price line a limited member adds is an ORGANISATION RATE: saved straight away, never an agent rate, shown to
-- everyone without the name (owner = his email, org = true). On a private-price supplier it stays with him and
-- Eretz Israel Tours. Nobody can change or suggest changing a line he cannot see. (Taking a line off the list is
-- price_delete, which is not touched: the owner of a line and Eretz Israel Tours take it off directly, as before.)
CREATE OR REPLACE FUNCTION public.price_save(p_token text, p_vendor text, p_data jsonb, p_reason text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; v public.vendors; c jsonb := public._price_clean(p_data); pid uuid := nullif(p_data->>'id','')::uuid; cur public.vendor_prices; mine boolean := coalesce((p_data->>'mine')::boolean,false); pp boolean; lim boolean;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin); lim := public._limited(m);
  if c->>'price' = '' and c->>'label' = '' then raise exception 'Add what the price is for.'; end if;
  select * into v from public.vendors where id = p_vendor; pp := v.prices_private;
  if pid is not null then select * into cur from public.vendor_prices p where p.id = pid and p.vendor_id = p_vendor;
    if cur.id is null or not public._price_visible(cur, v, m) then raise exception 'That price no longer exists.'; end if; end if;
  if m.is_admin and not (cur.id is not null and cur.owner <> '' and cur.owner <> m.email) then
    perform public._price_write(p_vendor, pid, c, m.email);
    return json_build_object('request', false);
  end if;
  if lim then
    c := c || jsonb_build_object('is_agent', false);
    if cur.id is null or cur.owner = m.email then
      c := c || jsonb_build_object('private', coalesce(pp, false));
      pid := public._price_write(p_vendor, pid, c, m.email);
      update public.vendor_prices set owner = m.email, org = true where id = pid;
      return json_build_object('request', false, 'mine', true, 'org', true);
    end if;
  end if;
  -- personal line: saved straight away, visible only to its owner and the admin
  if mine or pp or (cur.id is not null and cur.owner = m.email) then
    if cur.id is not null and cur.owner <> m.email then raise exception 'You can only change your own prices.'; end if;
    c := c || jsonb_build_object('private', true);
    pid := public._price_write(p_vendor, pid, c, m.email);
    update public.vendor_prices set owner = m.email where id = pid;
    return json_build_object('request', false, 'mine', true);
  end if;
  if cur.id is not null and cur.owner <> '' then raise exception 'You can only change your own prices.'; end if;
  c := c - 'private';
  if length(trim(coalesce(p_reason,''))) < 3 then raise exception 'Say briefly where this price comes from or why it changed.'; end if;
  insert into public.change_requests (vendor_id, kind, target_id, proposed, current, reason, requested_by, requested_name)
  values (p_vendor, case when pid is null then 'price_add' else 'price_edit' end, pid, c, coalesce(to_jsonb(cur),'{}'::jsonb), trim(p_reason), m.email, m.name);
  return json_build_object('request', true);
end $function$;

CREATE OR REPLACE FUNCTION public.quote_delete(p_token text, p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  delete from public.quotes where id = p_id and (owner = m.email or m.is_admin);
end $function$
;

CREATE OR REPLACE FUNCTION public.quote_save(p_token text, p_vendor text, p_quote jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; qid uuid := nullif(p_quote->>'id','')::uuid; o jsonb; l jsonb; oid uuid; oi int := 0; li int;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if qid is not null and not exists (select 1 from public.quotes where id = qid and vendor_id = p_vendor and (owner = m.email or m.is_admin)) then
    raise exception 'Only the person who added this quote, or Eretz Israel Tours, can change it.'; end if;
  if qid is null then
    insert into public.quotes (vendor_id, owner, owner_name) values (p_vendor, m.email, m.name) returning id into qid;
  end if;
  update public.quotes set title=left(coalesce(p_quote->>'title',''),160), date_from=coalesce(p_quote->>'date_from',''), date_to=coalesce(p_quote->>'date_to',''),
    pax=left(coalesce(p_quote->>'pax',''),20), units=left(coalesce(p_quote->>'units',''),60), received_on=coalesce(p_quote->>'received_on',''),
    valid_until=coalesce(p_quote->>'valid_until',''), ref=left(coalesce(p_quote->>'ref',''),80), status=coalesce(nullif(p_quote->>'status',''),'Received'),
    currency=coalesce(nullif(p_quote->>'currency',''),'ILS'), vat=coalesce(p_quote->>'vat',''), conditions=left(coalesce(p_quote->>'conditions',''),3000),
    private_note=left(coalesce(p_quote->>'private_note',''),3000), shared=coalesce((p_quote->>'shared')::boolean,true), updated_at=now()
  where id = qid;
  delete from public.quote_options where quote_id = qid;
  for o in select * from jsonb_array_elements(coalesce(p_quote->'options','[]'::jsonb)) loop
    insert into public.quote_options (quote_id, name, note, sort, service, seats, hours_incl, km_incl, fees)
    values (qid, left(coalesce(nullif(o->>'name',''),'Option'),120), left(coalesce(o->>'note',''),1000), oi,
      case when coalesce(o->>'service','') = any (array['bus','midibus','van20','van16','van10','van8','car','jeep_vehicle','transfer','guide','guide_vehicle','hotel_room','apartment','rappelling','jeep_tour','atv','activity','site','meal','other']) then o->>'service' else '' end,
      case when coalesce(o->>'seats','') ~ '^\d{1,3}$' then o->>'seats' else '' end,
      case when coalesce(o->>'hours_incl','') ~ '^\d{1,2}(\.\d)?$' then o->>'hours_incl' else '' end,
      case when coalesce(o->>'km_incl','') ~ '^\d{1,4}$' then o->>'km_incl' else '' end,
      public._fees_clean(o->'fees'))
    returning id into oid;
    oi := oi + 1; li := 0;
    for l in select * from jsonb_array_elements(coalesce(o->'lines','[]'::jsonb)) loop
      if coalesce(l->>'label','') = '' and coalesce(l->>'price','') = '' then continue; end if;
      insert into public.quote_lines (option_id, label, kind, price, unit, qty, times, note, sort)
      values (oid, left(coalesce(l->>'label',''),160), coalesce(nullif(l->>'kind',''),'Base'), coalesce(l->>'price',''), coalesce(nullif(l->>'unit',''),'per person'),
        coalesce(nullif(l->>'qty',''),'1'), coalesce(nullif(l->>'times',''),'1'), left(coalesce(l->>'note',''),300), li);
      li := li + 1;
    end loop;
  end loop;
  return qid;
end $function$
;

CREATE OR REPLACE FUNCTION public.quotes_list(p_token text, p_vendor text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  return coalesce((select json_agg(public._quote_json(q, m.is_admin or q.owner = m.email)
      order by (q.status in ('Expired','Declined')), coalesce(nullif(q.date_from,''),'9999') desc, q.created_at desc)
    from public.quotes q join public.vendors v on v.id = q.vendor_id
    where q.vendor_id = p_vendor and public._quote_visible(q, v, m)), '[]'::json);
end $function$;

CREATE OR REPLACE FUNCTION public.quotes_tracker(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return coalesce((select json_agg(public._quote_json(q, m.is_admin or q.owner = m.email) order by q.created_at desc)
    from public.quotes q join public.vendors v on v.id = q.vendor_id
    where m.is_admin or (not v.hidden and public._quote_visible(q, v, m))), '[]'::json);
end $function$;

CREATE OR REPLACE FUNCTION public.report_vendor(p_token text, p_vendor text, p_kind text, p_message text, p_anonymous boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if (select count(*) from public.vendor_reports where author = m.email and created_at > now() - interval '1 hour') > 20 then raise exception 'Too many reports in a short time. Try again later.'; end if;
  insert into public.vendor_reports (vendor_id, kind, message, anonymous, author, author_name) values (p_vendor, p_kind, trim(coalesce(p_message,'')), coalesce(p_anonymous,false), m.email, m.name);
end $function$
;

CREATE OR REPLACE FUNCTION public.request_access(p_name text, p_email text, p_role text, p_license text, p_phone text DEFAULT ''::text, p_note text DEFAULT ''::text, p_terms text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t text := public._new_token(); e text := lower(trim(p_email));
begin
  if coalesce(p_terms,'') = '' then raise exception 'Please read and accept the terms to join.'; end if;
  if p_role not in ('Licensed tour guide','Travel agent','Tour operator','Other') then raise exception 'Choose what you do.'; end if;
  if length(regexp_replace(coalesce(p_license,''),'[^0-9A-Za-z]','','g')) >= 3 and exists (select 1 from public.members where status in ('pending','approved')
       and lower(regexp_replace(license_no,'[^0-9A-Za-z]','','g')) = lower(regexp_replace(p_license,'[^0-9A-Za-z]','','g'))) then
    raise exception 'This license number is already registered. If it is yours, contact Eretz Israel Tours.'; end if;
  if (select count(*) from public.members where status = 'pending') >= 300 then raise exception 'Too many open requests right now. Try again later.'; end if;
  if exists (select 1 from public.members where email = e and status in ('pending','approved')) then
    raise exception 'This email already has access or a request waiting. Ask Eretz Israel Tours to send you your personal link.'; end if;
  insert into public.members (name, email, phone, note, role, license_no, token_hash, terms_version, terms_accepted_at)
  values (trim(p_name), e, left(coalesce(trim(p_phone),''),40), left(coalesce(trim(p_note),''),300), p_role, left(trim(coalesce(p_license,'')),40), public._hash(t), left(p_terms,20), now());
  return json_build_object('token', t, 'status', 'pending', 'alert', (select value from public.app_settings where key = 'ntfy_topic'));
end $function$
;

-- An organisation that is not in tourism asks to join: its name and, in free text, the person's credentials
-- (no license, no upload). It starts as a limited member with the standard sections, whoever approves it and from
-- whichever copy of the app. Stored with role 'Other'; members.org is what marks it as an organisation.
create or replace function public.request_access_org(p_name text, p_email text, p_phone text, p_note text, p_terms text, p_org text, p_credentials text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare t text := public._new_token(); e text := lower(trim(p_email));
  cred text := left(trim(coalesce(p_credentials,'')),1000); org_name text := left(trim(coalesce(p_org,'')),120);
begin
  if coalesce(p_terms,'') = '' then raise exception 'Please read and accept the terms to join.'; end if;
  if length(org_name) < 2 then raise exception 'Add the name of your organisation.'; end if;
  if length(cred) < 20 then raise exception 'Write a few lines about your role and how Eretz Israel Tours can check who you are.'; end if;
  if (select count(*) from public.members where status = 'pending') >= 300 then raise exception 'Too many open requests right now. Try again later.'; end if;
  if exists (select 1 from public.members where email = e and status in ('pending','approved')) then
    raise exception 'This email already has access or a request waiting. Ask Eretz Israel Tours to send you your personal link.'; end if;
  insert into public.members (name, email, phone, note, role, token_hash, terms_version, terms_accepted_at, org, credentials, member_type, sections)
  values (trim(p_name), e, left(coalesce(trim(p_phone),''),40), left(coalesce(trim(p_note),''),300), 'Other', public._hash(t), left(p_terms,20), now(),
    org_name, cred, 'limited', 'transport,guides,hotels,sites,food');
  return json_build_object('token', t, 'status', 'pending', 'alert', (select value from public.app_settings where key = 'ntfy_topic'));
end $function$;

CREATE OR REPLACE FUNCTION public.request_decide(p_token text, p_id uuid, p_approve boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; c public.change_requests;
begin
  m := public._auth(p_token, true);
  select * into c from public.change_requests where id = p_id and status = 'pending' for update;
  if c.id is null then raise exception 'That request was already handled.'; end if;
  if p_approve then
    perform set_config('app.editor', c.requested_by || ' (approved by ' || m.email || ')', true);
    if c.kind = 'vendor_fields' then perform public._vendor_apply(c.vendor_id, c.proposed);
    elsif c.kind = 'price_add' then perform public._price_write(c.vendor_id, null, c.proposed, c.requested_by);
    elsif c.kind = 'price_edit' then
      if exists (select 1 from public.vendor_prices where id = c.target_id) then perform public._price_write(c.vendor_id, c.target_id, c.proposed, c.requested_by);
      else perform public._price_write(c.vendor_id, null, c.proposed, c.requested_by); end if;
    elsif c.kind = 'price_delete' then delete from public.vendor_prices where id = c.target_id;
    end if;
  end if;
  update public.change_requests set status = case when p_approve then 'approved' else 'rejected' end, decided_by = m.email, decided_at = now() where id = p_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.requests_list(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  return coalesce((select json_agg(json_build_object('id',c.id,'vendor_id',c.vendor_id,'vendor_name',v.name,'kind',c.kind,'proposed',c.proposed,'current',c.current,'reason',c.reason,'requested_by',c.requested_by,'requested_name',c.requested_name,'created_at',c.created_at) order by c.created_at)
    from public.change_requests c join public.vendors v on v.id = c.vendor_id where c.status = 'pending'), '[]'::json);
end $function$
;

CREATE OR REPLACE FUNCTION public.reservation_report(p_token text, p_vendor text, p_checked text, p_visit text DEFAULT ''::text, p_note text DEFAULT ''::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  insert into public.reservation_reports (vendor_id, member, member_name, checked, visit_date, note)
  values (p_vendor, m.email, m.name, p_checked, coalesce(p_visit,''), left(coalesce(p_note,''),300));
end $function$
;

CREATE OR REPLACE FUNCTION public.set_bcc_pref(p_token text, p_opt_out boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  update public.members set bcc_opt_out = p_opt_out, bcc_ack = true where id = m.id;
end $function$
;

-- set_setting: Eretz Israel Tours can open booking sheets to all colleagues (bookings_for = 'all') or keep them to itself ('admin'),
-- and open jobs (jobs_for = 'admin', 'receive' or 'all').
create or replace function public.set_setting(p_token text, p_key text, p_value text)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  if p_key not in ('bcc_email','bookings_for','jobs_for') then raise exception 'Unknown setting'; end if;
  if p_key = 'bcc_email' and p_value <> '' and p_value !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Enter a full email address.'; end if;
  if p_key = 'bookings_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'jobs_for' and lower(trim(p_value)) not in ('admin','receive','all') then raise exception 'Unknown setting'; end if;
  insert into public.app_settings (key, value) values (p_key, lower(trim(p_value))) on conflict (key) do update set value = excluded.value;
end $function$;

CREATE OR REPLACE FUNCTION public.vendor_delete(p_token text, p_id text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  delete from public.vendors where id = p_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.vendor_detail(p_token text, p_id text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; v public.vendors; pp boolean; lim boolean; own boolean;
begin
  m := public._auth(p_token); lim := public._limited(m);
  select * into v from public.vendors where id = p_id;
  if not m.is_admin and (v.hidden or not public._can_see(m, v.category, v.also_categories)) then raise exception 'That supplier is not available.'; end if;
  pp := v.prices_private; own := public._is_own(v, m);
  return json_build_object(
    'prices', coalesce((select json_agg(json_build_object('id',p.id,'vendor_id',p.vendor_id,'label',p.label,'audience',p.audience,'age_from',p.age_from,'age_to',p.age_to,'pax_min',p.pax_min,'pax_max',p.pax_max,'season',p.season,'price',p.price,'currency',p.currency,'vat',p.vat,'basis',p.basis,'is_agent',p.is_agent,'source',p.source,'checked_on',p.checked_on,'note',p.note,'private',p.private,'sort',p.sort,
          'org',p.org,
          'owner',case when m.is_admin or p.owner = m.email then p.owner else '' end,'mine',(p.owner <> '' and p.owner = m.email),
          'by',case when p.org and not m.is_admin and p.owner <> m.email then json_build_object('name','an organisation','role','','admin',false,'org',true)
                    else public._who(case when p.owner <> '' then p.owner else p.created_by end) end,
          'by_date',p.updated_at)
        order by (p.owner <> '' and not p.org), p.org, p.sort, p.audience, p.created_at)
      from public.vendor_prices p where p.vendor_id = p_id and public._price_visible(p, v, m)), '[]'),
    'prices_private', coalesce(pp,false),
    'deals', coalesce((select json_agg(case when m.is_admin then to_jsonb(d) else to_jsonb(d) || jsonb_build_object('reported_by', public._name(d.reported_by)) end order by (d.valid_to <> '' and d.valid_to < to_char(now(),'YYYY-MM-DD')), d.created_at desc) from public.vendor_deals d where d.vendor_id = p_id), '[]'),
    'notes', coalesce((select json_agg(case when m.is_admin then to_jsonb(n) || jsonb_build_object('mine', n.author = m.email)
          else to_jsonb(n) || jsonb_build_object('author', public._name(n.author), 'decided_by', '', 'mine', n.author = m.email) end order by n.created_at desc)
        from public.vendor_notes n where n.vendor_id = p_id and public._note_visible(n, v, m)), '[]'),
    'reviews_open', public._reviews_open(m, v.category, v.also_categories),
    'requests', coalesce((select json_agg(c order by c.created_at desc) from public.change_requests c where c.vendor_id = p_id and c.status = 'pending' and (m.is_admin or c.requested_by = m.email)), '[]'),
    'admin_note', case when m.is_admin then (select body from public.vendor_admin_notes a where a.vendor_id = p_id) else null end,
    'sites', coalesce((select json_agg(json_build_object('id',s.id,'name',s.name,'location',s.location,'reservation',s.reservation) order by s.name) from public.vendors s
        where s.parent_id = p_id and (m.is_admin or (not s.hidden and public._can_see(m, s.category, s.also_categories)))), '[]'),
    'parent', (select json_build_object('id',pv.id,'name',pv.name) from public.vendors pv
        where pv.id = v.parent_id and (m.is_admin or (not pv.hidden and public._can_see(m, pv.category, pv.also_categories)))),
    'res_reports', coalesce((select json_agg(json_build_object('checked',r.checked,'visit_date',r.visit_date,'note',r.note,'member_name',r.member_name,'created_at',r.created_at,'mine',r.member = m.email) order by r.created_at desc) from (select * from public.reservation_reports where vendor_id = p_id order by created_at desc limit 20) r), '[]'),
    'res_answered', exists (select 1 from public.reservation_reports where vendor_id = p_id and member = m.email),
    'deal_by', coalesce((select json_object_agg(d.id, public._who(d.reported_by)) from public.vendor_deals d where d.vendor_id = p_id), '{}'),
    'note_by', coalesce((select json_object_agg(n.id, public._who(n.author)) from public.vendor_notes n where n.vendor_id = p_id and public._note_visible(n, v, m)), '{}'),
    'own', coalesce(own, false),
    'my_claim', exists (select 1 from public.vendor_claims c where c.vendor_id = p_id and c.member = m.email and c.status = 'pending'),
    'claimer', case when m.is_admin then (select json_build_object('id',mm.id,'name',mm.name,'role',case when mm.org <> '' then mm.org else mm.role end) from public.members mm where mm.email = v.claimed_by and v.claimed_by <> '' order by mm.created_at limit 1) end,
    'matches', case when m.is_admin then coalesce((select json_agg(json_build_object('id',mm.id,'name',mm.name,'role',case when mm.org <> '' then mm.org else mm.role end) order by mm.name)
        from public.members mm where mm.status = 'approved' and v.claimed_by <> mm.email and public._is_own(v, mm)), '[]'::json) end
  );
end $function$;

CREATE OR REPLACE FUNCTION public.vendor_files_stamp()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.uploaded_by := coalesce(nullif(current_setting('app.editor', true),''), new.uploaded_by);
  new.created_at := now();
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.vendor_report_set(p_token text, p_id uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  update public.vendor_reports set status = p_status where id = p_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.vendor_reports_list(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  return coalesce((select json_agg(json_build_object('id',r.id,'vendor_id',r.vendor_id,'vendor_name',v.name,'kind',r.kind,'message',r.message,'anonymous',r.anonymous,
    'author_name',case when r.anonymous then '' else r.author_name end,'author',case when r.anonymous then '' else r.author end,'status',r.status,'by_owner',r.by_owner,'created_at',r.created_at) order by (r.status='New') desc, r.created_at desc)
    from public.vendor_reports r join public.vendors v on v.id = r.vendor_id where r.status = 'New' or r.created_at > now() - interval '30 days'), '[]'::json);
end $function$
;

CREATE OR REPLACE FUNCTION public.vendor_save(p_token text, p_data jsonb, p_reason text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; r public.vendors; cv public.vendors; f text; clean jsonb := '{}'::jsonb; cur jsonb; locked_changes jsonb := '{}'::jsonb; open_vals jsonb := '{}'::jsonb; req boolean := false;
  price_fields text[] := array['agentPrice','listedPrice','agentPriceVatTreatment','listedPriceVatTreatment','maxPax'];
  agent_fields text[] := array['agentPrice','agentPriceVatTreatment','agent_link','agent_howto'];
  skip text[] := array[]::text[];
  is_rest boolean; no_cert boolean; lim boolean; own boolean := false; gog boolean := false;
  review_fields text[] := array['rateReliability','rateService','rateValue','strengths','weaknesses','notes'];
  is_gd boolean; lic boolean; spec boolean; esh boolean; d1 boolean; was_gd boolean := false; was_spec boolean := false; was_esh boolean := false;
begin
  m := public._auth(p_token); lim := public._limited(m);
  foreach f in array public._all_fields() loop
    clean := clean || jsonb_build_object(f, left(coalesce(p_data->>f,''), 2000));
  end loop;
  -- Kosher rule (D-7, D-8): no non-kosher restaurants; a restaurant that is kosher without a certificate is an exception Eretz Israel Tours approves.
  is_rest := (clean->>'category') = 'Restaurant' or (clean->>'also_categories') ~* '(^|,)\s*Restaurant\s*(,|$)';
  if is_rest and (clean->>'kosher') ~* '^\s*(not kosher|non[- ]?kosher|kosher[- ]style)' then raise exception 'The list does not accept non-kosher restaurants.'; end if;
  no_cert := is_rest and (clean->>'kosher') ~* '^\s*kosher\W+(no|without)\s+(certificate|certification|teuda|teudah|hechsher)';
  -- Guides (D-16): only licensed tour guides are listed, except a specialty (shuk tours, graffiti tours and the like),
  -- which Eretz Israel Tours approves as an exception. An Eshkol driver or guide needs a D1 license.
  -- Both are stated with tags, and asked for when an entry is new, becomes a guide, or gains Eshkol.
  is_gd := (clean->>'category') = 'Guide' or (clean->>'also_categories') ~* '(^|,)\s*Guide\s*(,|$)';
  lic := (clean->>'tags') ~* '(^|,)\s*Licensed tour guide\s*(,|$)';
  spec := (clean->>'tags') ~* '(^|,)\s*Specialty guide\s*(,|$)';
  esh := (clean->>'tags') ~* 'eshkol (license|driver|guide)';
  d1 := (clean->>'tags') ~* '(^|,)\s*D1 license\s*(,|$)';
  if coalesce(p_data->>'id','') <> '' then
    select public._is_guide(x), coalesce(x.tags,'') ~* '(^|,)\s*Specialty guide\s*(,|$)', coalesce(x.tags,'') ~* 'eshkol (license|driver|guide)'
      into was_gd, was_spec, was_esh from public.vendors x where x.id = p_data->>'id';
  end if;
  if is_gd and lic and spec then raise exception 'Choose one: licensed tour guide, or specialty guide.'; end if;
  if is_gd and not coalesce(was_gd, false) and not (lic or spec) then
    raise exception 'Say whether this guide is licensed. Only licensed tour guides are listed, except specialties such as shuk tours or graffiti tours.'; end if;
  if esh and not coalesce(was_esh, false) and not d1 then
    raise exception 'Only a driver with a D1 license can be listed as an Eshkol driver or guide. Add the tag "D1 license" to confirm it, or take Eshkol off.'; end if;
  if coalesce(p_data->>'id','') = '' then
    if lim then
      -- A limited member adds suppliers in his own sections, and never an agent price (D-15).
      if not public._can_see(m, clean->>'category', clean->>'also_categories') then raise exception 'You can add suppliers in the sections you have access to.'; end if;
      foreach f in array agent_fields loop clean := clean || jsonb_build_object(f, ''); end loop;
    end if;
    select * into r from jsonb_populate_record(null::public.vendors, clean);
    insert into public.vendors (name,category,active,"contactPerson",phone,whatsapp,email,website,location,languages,kosher,"maxCap","listedPrice","listedPriceVatTreatment","agentPrice","agentPriceVatTreatment","maxPax","priceBasis",currency,"payTerms","cancelPolicy","cancelNoticeAmount","cancelNoticeUnit","cancelDayType","cancelPenalty","cancelPolicyVerifiedDate","npResLink","rateReliability","rateService","rateValue",strengths,weaknesses,notes,region,tags,experience_years,agent_link,agent_howto,also_categories,maps_link,hours,hours_last)
    values (r.name,r.category,r.active,r."contactPerson",r.phone,r.whatsapp,r.email,r.website,r.location,r.languages,r.kosher,r."maxCap",r."listedPrice",r."listedPriceVatTreatment",r."agentPrice",r."agentPriceVatTreatment",r."maxPax",r."priceBasis",r.currency,r."payTerms",r."cancelPolicy",r."cancelNoticeAmount",r."cancelNoticeUnit",r."cancelDayType",r."cancelPenalty",r."cancelPolicyVerifiedDate",r."npResLink",r."rateReliability",r."rateService",r."rateValue",r.strengths,r.weaknesses,r.notes,r.region,r.tags,r.experience_years,r.agent_link,r.agent_howto,r.also_categories,r.maps_link,r.hours,r.hours_last)
    returning * into r;
    -- a member who adds his own business does not rate it (D-14)
    if public._is_own(r, m) then update public.vendors set "rateReliability" = '', "rateService" = '', "rateValue" = '', strengths = '', weaknesses = '' where id = r.id; end if;
    return json_build_object('vendor', public._vendor_view(r.id, m.is_admin, m.email), 'request', false);
  end if;
  select * into cv from public.vendors v where v.id = p_data->>'id';
  if cv.id is null then raise exception 'That supplier no longer exists.'; end if;
  cur := to_jsonb(cv);
  -- An app version from before opening hours existed sends no "hours": keep what is stored.
  if not (p_data ? 'hours') then clean := clean || jsonb_build_object('hours', coalesce(cur->>'hours','')); end if;
  if not (p_data ? 'hours_last') then clean := clean || jsonb_build_object('hours_last', coalesce(cur->>'hours_last','')); end if;
  if m.is_admin then
    r := public._vendor_apply(p_data->>'id', clean);
    return json_build_object('vendor', public._vendor_view(r.id, true), 'request', false);
  end if;
  if cv.hidden or not public._can_see(m, cv.category, cv.also_categories) then raise exception 'That supplier is not available.'; end if;
  if lim then
    -- Fields a limited member never receives come back empty from his form: leave what is stored (D-15).
    skip := agent_fields;
    if cv.category = 'Guide' and not m.see_guide_rates then skip := skip || array['listedPrice','listedPriceVatTreatment','maxPax']; end if;
    if not public._reviews_open(m, cv.category, cv.also_categories) then skip := skip || array['rateReliability','rateService','rateValue','strengths','weaknesses','notes']; end if;
  end if;
  -- D-14: ratings and remarks on a member's own page are hidden from him, so his save leaves them as they are;
  -- a guide's change to another guide's ratings or remarks is a review, and Eretz Israel Tours approves it first.
  own := public._is_own(cv, m);
  if own then skip := skip || review_fields; end if;
  gog := public._is_guide(cv) and public._is_guide_member(m);
  foreach f in array public._all_fields() loop
    if cv.prices_private and f = any(price_fields) then continue; end if;
    if f = any(skip) then continue; end if;
    if (clean->>f) is distinct from coalesce(cur->>f,'') then
      if f = any(public._locked_fields()) or (f = 'kosher' and no_cert) or (gog and f = any(review_fields))
         or (f = 'tags' and is_gd and spec and not coalesce(was_spec, false)) then locked_changes := locked_changes || jsonb_build_object(f, clean->>f);
      else open_vals := open_vals || jsonb_build_object(f, clean->>f); end if;
    end if;
  end loop;
  if open_vals <> '{}'::jsonb then perform public._vendor_apply(p_data->>'id', open_vals); end if;
  if locked_changes <> '{}'::jsonb then
    if length(trim(coalesce(p_reason,''))) < 3 then raise exception 'Say briefly why: this change needs approval by Eretz Israel Tours.'; end if;
    insert into public.change_requests (vendor_id, kind, proposed, current, reason, requested_by, requested_name)
    select p_data->>'id', 'vendor_fields', locked_changes,
      (select jsonb_object_agg(k, coalesce(cur->>k,'')) from jsonb_object_keys(locked_changes) k), trim(p_reason), m.email, m.name;
    req := true;
  end if;
  return json_build_object('vendor', public._vendor_view(p_data->>'id', false, m.email), 'request', req);
end $function$;

-- Agent sign-up details are for guides and agents.
CREATE OR REPLACE FUNCTION public.vendor_set_agent(p_token text, p_vendor text, p_link text, p_howto text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; l text := trim(coalesce(p_link,''));
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if public._limited(m) then raise exception 'Agent sign-up details are for tour guides and agents.' using errcode = '42501'; end if;
  if l <> '' and l !~* '^https?://' then l := 'https://' || l; end if;
  if l <> '' and l !~* '^https?://[^\s/]+\.[^\s]+' then raise exception 'That link does not look right.'; end if;
  update public.vendors set agent_link = left(l,500), agent_howto = left(trim(coalesce(p_howto,'')),1000), updated_by = m.email, updated_at = now() where id = p_vendor;
  return public._vendor_view(p_vendor, m.is_admin, m.email);
end $function$;

CREATE OR REPLACE FUNCTION public.vendor_set_prices_private(p_token text, p_id text, p_private boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  update public.vendors set prices_private = p_private where id = p_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.vendor_set_site(p_token text, p_id text, p_parent text, p_reservation text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  if p_parent = p_id then raise exception 'A supplier can''t be its own parent.'; end if;
  update public.vendors set parent_id = nullif(p_parent,''), reservation = coalesce(p_reservation,'') where id = p_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.vendor_set_status(p_token text, p_id text, p_status text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  update public.vendors set review_status = p_status, hidden = case when p_status = 'approved' then false else hidden end where id = p_id;
  return public._vendor_view(p_id, true);
end $function$
;

CREATE OR REPLACE FUNCTION public.vendors_before_write()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare ed text := coalesce(nullif(current_setting('app.editor', true),''), lower(coalesce(auth.jwt()->>'email','')), 'system');
        adm boolean := coalesce(current_setting('app.admin', true),'') = 'on';
        imp boolean := coalesce(current_setting('app.import', true),'') = 'on';
begin
  new.updated_at := now(); new.updated_by := ed;
  if tg_op = 'INSERT' then
    new.created_by := ed; new.created_at := now();
    new.review_status := case when adm and not imp then 'approved' else 'pending' end;
  else
    new.id := old.id; new.created_by := old.created_by; new.created_at := old.created_at;
    if not adm then new.review_status := old.review_status; end if;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.vendors_list(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return coalesce((select json_agg(case when m.is_admin then public._vendor_view(v.id, true, m.email) else public._vendor_for(v, m) end order by v.name)
    from public.vendors v where m.is_admin or (not v.hidden and public._can_see(m, v.category, v.also_categories))), '[]'::json);
end $function$;

-- Cancellation policy: room for a pasted policy (1,500 characters instead of 200).
create or replace function public._terms_clean(p jsonb)
 returns jsonb language sql immutable set search_path to ''
as $function$
  select jsonb_strip_nulls(jsonb_build_object(
    'price', case when t->>'price' ~ '^\d{1,7}(\.\d{1,2})?$' then t->>'price' end,
    'currency', case when t->>'currency' in ('ILS','USD','EUR') then t->>'currency' end,
    'vat', case when t->>'vat' in ('including_vat','plus_vat','not_applicable') then t->>'vat' end,
    'hours_incl', case when t->>'hours_incl' ~ '^\d{1,2}(\.\d)?$' then t->>'hours_incl' end,
    'km_incl', case when t->>'km_incl' ~ '^\d{1,4}$' then t->>'km_incl' end,
    'hours_from', case when t->>'hours_from' in ('pickup','depot') then t->>'hours_from' end,
    'overtime', case when t->>'overtime' ~ '^\d{1,7}(\.\d{1,2})?$' then t->>'overtime' end,
    'extra_km', case when t->>'extra_km' ~ '^\d{1,7}(\.\d{1,2})?$' then t->>'extra_km' end,
    'tolls', case when t->>'tolls' in ('incl','extra') then t->>'tolls' end,
    'tolls_note', nullif(left(trim(coalesce(t->>'tolls_note','')),80),''),
    'parking', case when t->>'parking' in ('incl','extra') then t->>'parking' end,
    'tip', case when t->>'tip' in ('none','customary') then t->>'tip' end,
    'tip_amt', case when t->>'tip_amt' ~ '^\d{1,7}(\.\d{1,2})?$' then t->>'tip_amt' end,
    'extras', nullif(left(trim(coalesce(t->>'extras','')),300),''),
    'cancel', nullif(left(trim(coalesce(t->>'cancel','')),1500),''),
    'payment', nullif(left(trim(coalesce(t->>'payment','')),200),''),
    'note', nullif(left(trim(coalesce(t->>'note','')),1500),'')))
  from (select case when jsonb_typeof(p) = 'object' then p else '{}'::jsonb end as t) x
$function$;

-- Booking sheets: a limited member needs the transport section and see_quotes.
create or replace function public._bookings_on(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select m.is_admin or (coalesce((select value from public.app_settings where key = 'bookings_for'), '') = 'all'
    and (not public._limited(m) or (m.see_quotes and 'transport' = any (string_to_array(m.sections, ',')))))
$function$;

create or replace function public._booking_json(b public.bookings)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('id',b.id,'vendor_id',b.vendor_id,'vendor_name',(select v.name from public.vendors v where v.id = b.vendor_id),
    'key',b.link_key,'status',b.status,'client_ref',b.client_ref,'booker_name',b.booker_name,'booker_phone',b.booker_phone,
    'date_from',b.date_from,'date_to',b.date_to,'days',b.days,'day_plan',b.day_plan,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'private_note',b.private_note,'proposed',b.proposed,'terms',b.terms,'terms_by',b.terms_by,
    'answered_by',b.answered_by,'answered_at',b.answered_at,'confirmed_at',b.confirmed_at,'shared',b.shared,'in_tracker',b.quote_id is not null,
    'guide_ok_at',b.guide_ok_at,'company_ok_at',b.company_ok_at,'company_ok_via',b.company_ok_via,'seen',b.seen_guide,
    'mine', b.owner = coalesce(current_setting('app.editor', true),''),
    'owner_name',b.owner_name,
    'owner_role',(select mm.role from public.members mm where mm.email = b.owner limit 1),
    'owner_admin',(select mm.is_admin from public.members mm where mm.email = b.owner limit 1),
    'created_at',b.created_at,'updated_at',b.updated_at)
$function$;

create or replace function public._booking_to_quote(b public.bookings)
 returns uuid language plpgsql security definer set search_path to ''
as $function$
declare qid uuid := b.quote_id; t jsonb := b.terms; oid uuid; days int := 1; lab text; fees jsonb := '{}'::jsonb; cond text;
begin
  if coalesce(t->>'price','') = '' then return null; end if;
  if qid is not null and not exists (select 1 from public.quotes where id = qid) then qid := null; end if;
  if qid is null then
    insert into public.quotes (vendor_id, owner, owner_name) values (b.vendor_id, b.owner, b.owner_name) returning id into qid;
  end if;
  begin
    if b.days <> '' then days := array_length(string_to_array(b.days, ','), 1);   -- D-21: separate days inside the period
    elsif b.date_from <> '' and b.date_to <> '' and b.date_to >= b.date_from then days := (b.date_to::date - b.date_from::date) + 1; end if;
  exception when others then days := 1; end;
  lab := case b.service when 'bus' then 'Bus' when 'midibus' then 'Midibus' when 'van20' then 'Van' when 'van16' then 'Van' when 'van10' then 'Van'
    when 'van8' then 'Van' when 'car' then 'Car' when 'jeep_vehicle' then 'Jeep / 4x4' when 'transfer' then 'Transfer' else 'Vehicle' end;
  if t ? 'overtime' then fees := fees || jsonb_build_object('overtime', jsonb_build_object('s','extra','amt',t->>'overtime')); end if;
  if t ? 'extra_km' then fees := fees || jsonb_build_object('extra_km', jsonb_build_object('s','extra','amt',t->>'extra_km')); end if;
  if t ? 'tolls' then fees := fees || jsonb_build_object('tolls', jsonb_strip_nulls(jsonb_build_object('s',t->>'tolls','note',t->>'tolls_note'))); end if;
  if t ? 'parking' then fees := fees || jsonb_build_object('parking', jsonb_build_object('s',t->>'parking')); end if;
  cond := concat_ws(E'\n',
    case t->>'hours_from' when 'pickup' then 'Hours counted from the pick-up.' when 'depot' then 'Hours counted from leaving the depot.' end,
    case t->>'tip' when 'none' then 'Driver tip: not expected.' when 'customary' then 'Driver tip: customary' || coalesce(', about ' || (t->>'tip_amt') || ' a day', '') || '.' end,
    case when t ? 'extras' then 'Other extras: ' || (t->>'extras') end,
    case when t ? 'cancel' then 'Cancellation policy: ' || (t->>'cancel') else 'Cancellation policy: none given.' end,
    case when t ? 'payment' then 'Payment: ' || (t->>'payment') end,
    case when b.days <> '' then days::text || ' separate days between these dates.' end,
    'From a booking sheet accepted by both sides.');
  update public.quotes set title = b.client_ref, date_from = b.date_from, date_to = b.date_to, pax = b.pax, units = '1 vehicle',
    received_on = to_char(coalesce(b.answered_at, now()), 'YYYY-MM-DD'), status = 'Booked', currency = coalesce(t->>'currency','ILS'),
    vat = coalesce(t->>'vat',''), conditions = left(cond, 3000), shared = b.shared, updated_at = now()
  where id = qid;
  delete from public.quote_options where quote_id = qid;
  insert into public.quote_options (quote_id, name, sort, service, seats, hours_incl, km_incl, fees)
  values (qid, case when b.seats <> '' then b.seats || '-seat ' || lower(lab) else lab end, 0, b.service, b.seats,
    coalesce(t->>'hours_incl',''), coalesce(t->>'km_incl',''), public._fees_clean(fees))
  returning id into oid;
  insert into public.quote_lines (option_id, label, kind, price, unit, qty, times, sort)
  values (oid, lab || ' with driver', 'Base', t->>'price', 'per vehicle per day', '1', days::text, 0);
  return qid;
end $function$;

-- D-21 (5 Oct 2026): the days of a booking when the guide chose separate days inside a period.
-- Returns a sorted comma list of real dates inside p_from..p_to, at most 62, or '' when that is every day of the period
-- (or fewer than two days): '' always means "every day from the first date to the last".
create or replace function public._booking_days_clean(p_days text, p_from text, p_to text)
 returns text language plpgsql stable set search_path to ''
as $function$
declare d text; picked text[] := '{}'; last_day text := coalesce(nullif(p_to,''), p_from); n int;
begin
  if coalesce(p_days,'') = '' or coalesce(p_from,'') = '' then return ''; end if;
  for d in select distinct x from unnest(string_to_array(left(p_days, 4000), ',')) x
           where x ~ '^\d{4}-\d{2}-\d{2}$' and x >= p_from and x <= last_day order by 1 limit 62 loop
    begin
      if to_char(d::date, 'YYYY-MM-DD') = d then picked := picked || d; end if;
    exception when others then null; end;
  end loop;
  n := coalesce(array_length(picked, 1), 0);
  if n < 2 then return ''; end if;
  if n = (picked[n]::date - picked[1]::date) + 1 then return ''; end if;
  return array_to_string(picked, ',');
end $function$;

-- D-24 (5 Oct 2026): each day's own pick-up time, estimated finish and where to, on a booking of more than one day.
-- Returns {"2026-10-20": {"start":"08:30","end":"18:00","route":"…"}, …}: only days that are on the sheet (inside the
-- period, and among the chosen days when separate days were chosen), only times written hh:mm, the route cut to 300
-- characters, empty entries dropped, at most 62 days. '{}' = the sheet's one pick-up and drop-off time apply to every day.
create or replace function public._booking_plan_clean(p_plan jsonb, p_from text, p_to text, p_days text)
 returns jsonb language plpgsql stable set search_path to ''
as $function$
declare k text; v jsonb; o jsonb := '{}'::jsonb; s text; e text; r text; n int := 0;
begin
  if p_plan is null or jsonb_typeof(p_plan) <> 'object' then return o; end if;
  if coalesce(p_from,'') = '' or coalesce(p_to,'') = '' or p_to <= p_from then return o; end if;   -- one day: the sheet's own times
  for k, v in select key, value from jsonb_each(p_plan) order by key loop
    continue when k !~ '^\d{4}-\d{2}-\d{2}$' or jsonb_typeof(v) <> 'object' or k < p_from or k > p_to;
    continue when coalesce(p_days,'') <> '' and not (k = any (string_to_array(p_days, ',')));
    s := case when coalesce(v->>'start','') ~ '^([01]\d|2[0-3]):[0-5]\d$' then v->>'start' else '' end;
    e := case when coalesce(v->>'end','') ~ '^([01]\d|2[0-3]):[0-5]\d$' then v->>'end' else '' end;
    r := left(trim(coalesce(v->>'route','')), 300);
    continue when s = '' and e = '' and r = '';
    o := o || jsonb_build_object(k, jsonb_strip_nulls(jsonb_build_object('start', nullif(s,''), 'end', nullif(e,''), 'route', nullif(r,''))));
    n := n + 1; exit when n >= 62;
  end loop;
  return o;
end $function$;

-- The guide saves. Saving a version is accepting it (guide_ok_at). If the sheet's content changed after the company
-- answered, the company's acceptance is cleared and it has to accept again (status back to 'waiting').
-- p_booking "terms": the guide writes the terms himself. With "company_agreed": true he is typing in what the company
-- told him by phone or WhatsApp (its acceptance is recorded as given through the guide); without it he is proposing
-- different terms, which go back to the company for approval.
create or replace function public.booking_save(p_token text, p_vendor text, p_booking jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; bid uuid := nullif(p_booking->>'id','')::uuid; b public.bookings; prev public.bookings; agreed boolean;
begin
  m := public._auth(p_token);
  if not public._bookings_on(m) then raise exception 'Booking sheets are not open yet.' using errcode = '42501'; end if;
  perform public._visible(p_vendor, m.is_admin);
  if not exists (select 1 from public.vendors where id = p_vendor) then raise exception 'That supplier no longer exists.'; end if;
  if bid is not null then
    select * into prev from public.bookings where id = bid and vendor_id = p_vendor and (owner = m.email or m.is_admin);
    if prev.id is null then raise exception 'Only the person who made this booking sheet, or Eretz Israel Tours, can change it.'; end if;
    if prev.status in ('confirmed','cancelled') then raise exception 'This booking sheet is closed. Reopen it to change it.'; end if;
  else
    if (select count(*) from public.bookings where owner = m.email and created_at > now() - interval '1 day') >= 100 then
      raise exception 'Too many booking sheets in one day. Try again tomorrow.'; end if;
    insert into public.bookings (vendor_id, owner, owner_name, link_key, guide_ok_at) values (p_vendor, m.email, m.name, public._new_token(), now()) returning id into bid;
  end if;
  update public.bookings set
    client_ref = left(coalesce(p_booking->>'client_ref',''),160),
    booker_name = left(trim(coalesce(p_booking->>'booker_name','')),80),
    booker_phone = left(trim(coalesce(p_booking->>'booker_phone','')),40),
    date_from = case when coalesce(p_booking->>'date_from','') ~ '^\d{4}-\d{2}-\d{2}$' then p_booking->>'date_from' else '' end,
    date_to = case when coalesce(p_booking->>'date_to','') ~ '^\d{4}-\d{2}-\d{2}$' then p_booking->>'date_to' else '' end,
    pax = left(coalesce(p_booking->>'pax',''),20),
    service = case when coalesce(p_booking->>'service','') = any (array['bus','midibus','van20','van16','van10','van8','car','jeep_vehicle','transfer']) then p_booking->>'service' else '' end,
    seats = case when coalesce(p_booking->>'seats','') ~ '^\d{1,3}$' then p_booking->>'seats' else '' end,
    tourists = coalesce((p_booking->>'tourists')::boolean, true),
    pickup_time = left(coalesce(p_booking->>'pickup_time',''),20), pickup_place = left(coalesce(p_booking->>'pickup_place',''),160),
    route = left(coalesce(p_booking->>'route',''),1500),
    dropoff_time = left(coalesce(p_booking->>'dropoff_time',''),20), dropoff_place = left(coalesce(p_booking->>'dropoff_place',''),160),
    note = left(coalesce(p_booking->>'note',''),1500), private_note = left(coalesce(p_booking->>'private_note',''),3000),
    proposed = public._terms_clean(p_booking->'proposed'),
    shared = coalesce((p_booking->>'shared')::boolean, true), updated_at = now()
  where id = bid returning * into b;
  if b.booker_name = '' then update public.bookings set booker_name = m.name where id = bid returning * into b; end if;
  -- D-21: separate days inside the period. A copy of the app from before D-21 sends no "days": they are kept unless it moved the dates.
  update public.bookings set days = public._booking_days_clean(
      case when p_booking ? 'days' then p_booking->>'days'
           when prev.id is not null and prev.date_from = b.date_from and prev.date_to = b.date_to then prev.days else '' end, b.date_from, b.date_to)
  where id = bid returning * into b;
  if b.days <> '' then   -- the first and the last chosen day are the period
    update public.bookings set date_from = split_part(b.days, ',', 1), date_to = reverse(split_part(reverse(b.days), ',', 1)) where id = bid returning * into b;
  end if;
  -- D-24: each day's own times. A copy of the app from before D-24 sends no "day_plan": it is kept, cut down to the days still on the sheet.
  update public.bookings set day_plan = public._booking_plan_clean(
      case when p_booking ? 'day_plan' then p_booking->'day_plan' when prev.id is not null then prev.day_plan else '{}'::jsonb end,
      b.date_from, b.date_to, b.days)
  where id = bid returning * into b;
  if jsonb_typeof(p_booking->'terms') = 'object' then
    if coalesce(public._terms_clean(p_booking->'terms')->>'price','') = '' then raise exception 'Add the price.'; end if;
    agreed := coalesce((p_booking->>'company_agreed')::boolean, false);
    update public.bookings set terms = public._terms_clean(p_booking->'terms'), terms_by = 'guide',
      answered_by = case when agreed then left(trim(coalesce(p_booking->>'answered_by','')),80) else answered_by end,
      answered_at = case when agreed then now() else answered_at end,
      company_ok_at = case when agreed then now() end, company_ok_via = case when agreed then 'guide' else '' end,
      status = case when agreed then 'answered' else 'waiting' end
    where id = bid returning * into b;
  elsif prev.id is not null and prev.status = 'answered' and public._booking_content(prev) is distinct from public._booking_content(b) then
    -- the job changed after the company accepted: its acceptance no longer stands
    update public.bookings set status = 'waiting', company_ok_at = null, company_ok_via = '' where id = bid returning * into b;
  end if;
  -- what the guide has now seen and stands behind
  update public.bookings set seen_guide = public._booking_content(b), guide_ok_at = case when b.status = 'waiting' then now() else guide_ok_at end
  where id = bid returning * into b;
  return public._booking_json(b);
end $function$;

-- A member's own booking sheets (Eretz Israel Tours: everyone's). p_vendor '' = all suppliers.
create or replace function public.bookings_list(p_token text, p_vendor text default ''::text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  if not public._bookings_on(m) then return '[]'::json; end if;
  return coalesce((select json_agg(public._booking_json(b) order by (b.status in ('cancelled')), coalesce(nullif(b.date_from,''),'9999') desc, b.created_at desc)
    from public.bookings b
    where (m.is_admin or b.owner = m.email) and (coalesce(p_vendor,'') = '' or b.vendor_id = p_vendor)), '[]'::json);
end $function$;

-- confirmed: the guide accepts what the company accepted; the sheet locks and feeds the Quotes tab.
-- cancelled: the link stops taking answers. open: unlock it again.
create or replace function public.booking_set_status(p_token text, p_id uuid, p_status text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; b public.bookings; qid uuid;
begin
  m := public._auth(p_token);
  if not public._bookings_on(m) then raise exception 'Booking sheets are not open yet.' using errcode = '42501'; end if;
  select * into b from public.bookings where id = p_id and (owner = m.email or m.is_admin);
  if b.id is null then raise exception 'Only the person who made this booking sheet, or Eretz Israel Tours, can change it.'; end if;
  if p_status = 'confirmed' then
    if b.status <> 'answered' or coalesce(b.terms->>'price','') = '' or b.company_ok_at is null then raise exception 'The company has not accepted this version yet.'; end if;
    update public.bookings set status = 'confirmed', confirmed_at = now(), guide_ok_at = now(), seen_guide = public._booking_content(b), updated_at = now() where id = p_id returning * into b;
    qid := public._booking_to_quote(b);
    update public.bookings set quote_id = qid where id = p_id returning * into b;
  elsif p_status = 'cancelled' then
    if b.quote_id is not null then update public.quotes set status = 'Received', updated_at = now() where id = b.quote_id and status = 'Booked'; end if;
    update public.bookings set status = 'cancelled', updated_at = now() where id = p_id returning * into b;
  elsif p_status = 'open' then
    if b.quote_id is not null then delete from public.quotes where id = b.quote_id; end if;
    update public.bookings set status = case when coalesce(terms->>'price','') <> '' and company_ok_at is not null then 'answered' else 'waiting' end,
      guide_ok_at = case when coalesce(terms->>'price','') <> '' and company_ok_at is not null then null else now() end,
      confirmed_at = null, quote_id = null, updated_at = now() where id = p_id returning * into b;
  else
    raise exception 'Unknown status.';
  end if;
  return public._booking_json(b);
end $function$;

create or replace function public.booking_delete(p_token text, p_id uuid)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members; b public.bookings;
begin
  m := public._auth(p_token);
  select * into b from public.bookings where id = p_id and (owner = m.email or m.is_admin);
  if b.id is null then return; end if;
  if b.quote_id is not null then delete from public.quotes where id = b.quote_id; end if;
  delete from public.bookings where id = p_id;
end $function$;

-- ===== The company's side (link key only) =====
-- The company's page shows who sent the sheet: an organisation shows its name where a guide shows his role.
create or replace function public.booking_open(p_key text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare b public.bookings;
begin
  if coalesce(length(p_key),0) < 32 then raise exception 'This link is not active.' using errcode = '28000'; end if;
  select * into b from public.bookings where link_key = p_key;
  if b.id is null then raise exception 'This link is not active.' using errcode = '28000'; end if;
  return json_build_object('status',b.status,
    'company',(select v.name from public.vendors v where v.id = b.vendor_id),
    'booker_name',b.booker_name,
    'booker_role',(select case when mm.org <> '' then mm.org else mm.role end from public.members mm where mm.email = b.owner limit 1),
    'booker_phone',b.booker_phone,
    'date_from',b.date_from,'date_to',b.date_to,'days',b.days,'day_plan',b.day_plan,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'proposed',b.proposed,'terms',b.terms,'terms_by',b.terms_by,'answered_by',b.answered_by,
    'answered_at',b.answered_at,'confirmed_at',b.confirmed_at,
    'guide_ok_at',b.guide_ok_at,'company_ok_at',b.company_ok_at,'company_ok_via',b.company_ok_via,'seen',b.seen_company);
end $function$;

-- The company sends its terms. Sending them is accepting them. The guide's acceptance is cleared: he has to accept
-- what the company wrote. Sending back exactly what the guide proposed counts as accepting it.
create or replace function public.booking_answer(p_key text, p_terms jsonb, p_name text default ''::text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare b public.bookings; t jsonb := public._terms_clean(p_terms);
begin
  if coalesce(length(p_key),0) < 32 then raise exception 'This link is not active.' using errcode = '28000'; end if;
  select * into b from public.bookings where link_key = p_key for update;
  if b.id is null then raise exception 'This link is not active.' using errcode = '28000'; end if;
  if b.status = 'confirmed' then raise exception 'This booking is already confirmed. To change it, contact the person who sent it.'; end if;
  if b.status = 'cancelled' then raise exception 'This booking was cancelled.'; end if;
  if b.answers >= 30 then raise exception 'This sheet was changed too many times. Contact the person who sent it.'; end if;
  if coalesce(t->>'price','') = '' then raise exception 'Fill in the price.'; end if;
  if b.status = 'waiting' and b.guide_ok_at is not null and b.terms = t then return public.booking_accept(p_key, p_name); end if;
  -- when the company revises an earlier answer, the guide's page compares against that earlier answer
  update public.bookings set terms = t, terms_by = 'company', answered_by = left(trim(coalesce(p_name,'')),80), answered_at = now(),
    status = 'answered', company_ok_at = now(), company_ok_via = 'link', guide_ok_at = null, answers = answers + 1, updated_at = now(),
    seen_guide = case when coalesce(b.terms->>'price','') <> '' then jsonb_set(coalesce(seen_guide, public._booking_content(b)), '{terms}', b.terms) else seen_guide end
  where id = b.id returning * into b;
  update public.bookings set seen_company = public._booking_content(b) where id = b.id;
  return public.booking_open(p_key);
end $function$;

-- Everything both sides agree on: the job and the terms. Used to tell whether a sheet changed, and kept as "last seen".
create or replace function public._booking_content(b public.bookings)
 returns jsonb language sql stable set search_path to ''
as $function$
  select jsonb_build_object('date_from',b.date_from,'date_to',b.date_to,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'terms',b.terms)
    || case when b.days <> '' then jsonb_build_object('days', b.days) else '{}'::jsonb end   -- D-21; left out when empty, so sheets from before it compare as they did
    || case when b.day_plan <> '{}'::jsonb then jsonb_build_object('day_plan', b.day_plan) else '{}'::jsonb end   -- D-24; the same
$function$;

-- The company accepts the sheet as it stands (after the guide changed the job or proposed other terms).
-- If the guide's acceptance of this same version stands, both sides have now accepted: the sheet locks.
create or replace function public.booking_accept(p_key text, p_name text default ''::text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare b public.bookings; qid uuid;
begin
  if coalesce(length(p_key),0) < 32 then raise exception 'This link is not active.' using errcode = '28000'; end if;
  select * into b from public.bookings where link_key = p_key for update;
  if b.id is null then raise exception 'This link is not active.' using errcode = '28000'; end if;
  if b.status = 'cancelled' then raise exception 'This booking was cancelled.'; end if;
  if b.status in ('confirmed','answered') then return public.booking_open(p_key); end if;
  if coalesce(b.terms->>'price','') = '' then raise exception 'Fill in the price.'; end if;
  update public.bookings set company_ok_at = now(), company_ok_via = 'link', seen_company = public._booking_content(b),
    answered_by = case when trim(coalesce(p_name,'')) <> '' then left(trim(p_name),80) else answered_by end, answered_at = now(),
    status = case when guide_ok_at is not null then 'confirmed' else 'answered' end,
    confirmed_at = case when guide_ok_at is not null then now() end, updated_at = now()
  where id = b.id returning * into b;
  if b.status = 'confirmed' then
    qid := public._booking_to_quote(b);
    update public.bookings set quote_id = qid where id = b.id;
  end if;
  return public.booking_open(p_key);
end $function$;


-- ===== Jobs between colleagues, and My days (3 Oct 2026, D-11) =====
-- Jobs between colleagues are for guides and agents: never for a limited member.
create or replace function public._jobs_on(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select m.is_admin or (not public._limited(m) and coalesce((select value from public.app_settings where key = 'jobs_for'), '') in ('receive','all'))
$function$;

create or replace function public._jobs_post(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select m.is_admin or (not public._limited(m) and coalesce((select value from public.app_settings where key = 'jobs_for'), '') = 'all')
$function$;

-- whoami: also what kind of member this is and what he sees, so the app shows only that.
create or replace function public.whoami(p_token text)
 returns json language sql security definer set search_path to ''
as $function$
  select json_build_object('name',name,'email',email,'status',status,'is_admin',is_admin,'role',case when org <> '' then 'Organisation, not in tourism' else role end,'has_proof',proof_path is not null,'terms_version',terms_version,
    'reminder_due', (not is_admin) and (reminder_seen_at is null or reminder_seen_at < now() - interval '30 days'),
    'bcc_email', case when status = 'approved' then (select value from public.app_settings where key = 'bcc_email') else '' end,
    'bcc_opt_out', bcc_opt_out, 'bcc_ack', bcc_ack,
    'phone', phone,
    'bookings', status = 'approved' and public._bookings_on(m),
    'bookings_for', case when is_admin then coalesce((select value from public.app_settings where key = 'bookings_for'),'admin') else '' end,
    'jobs', status = 'approved' and public._jobs_on(m),
    'jobs_post', status = 'approved' and public._jobs_post(m),
    'jobs_for', case when is_admin then coalesce((select value from public.app_settings where key = 'jobs_for'),'admin') else '' end,
    'member_type', case when public._limited(m) then 'limited' else 'full' end,
    'sections', case when public._limited(m) then sections else '' end,
    'see_quotes', not public._limited(m) or see_quotes,
    'see_guide_rates', not public._limited(m) or see_guide_rates,
    'see_transport_reviews', not public._limited(m) or see_transport_reviews,
    'see_reviews', not public._limited(m) or see_reviews,
    'org', org)
  from public.members m where token_hash = public._hash(p_token);
$function$;

-- A comma list cut down to known keys, in the order of p_allowed.
create or replace function public._csv_keys(p text, p_allowed text[])
 returns text language sql immutable set search_path to ''
as $function$
  select coalesce(string_agg(a, ',' order by i), '')
  from unnest(p_allowed) with ordinality as t(a, i)
  where a in (select lower(trim(x)) from unnest(string_to_array(coalesce(p,''), ',')) as u(x))
$function$;

-- 'yyyy-mm-dd' to a date; null when it is not a real date.
create or replace function public._to_date(p text)
 returns date language plpgsql immutable set search_path to ''
as $function$
begin
  if coalesce(p,'') !~ '^\d{4}-\d{2}-\d{2}$' then return null; end if;
  return p::date;
exception when others then return null;
end $function$;

-- A limited member is never offered a job and never appears in the list of colleagues a job fits.
create or replace function public._job_fits(p_kind text, p_needs text, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select not public._limited(m) and m.job_kinds <> 'none'
    and (m.job_kinds = '' or p_kind = any (string_to_array(m.job_kinds, ',')))
    and (m.job_kinds = '' or coalesce(p_needs,'') = ''
      or string_to_array(p_needs, ',') <@ string_to_array(m.job_tags || case when m.role = 'Licensed tour guide' then ',licensed' else '' end, ','))
$function$;

-- Was this job sent to this member?
create or replace function public._job_offered(j public.jobs, m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select case when j.audience = 'picked'
    then exists (select 1 from public.job_offers f where f.job_id = j.id and f.member = m.email and f.picked)
    else public._job_fits(j.kind, j.needs, m) end
$function$;

-- Free / busy for a range of days. Others get 'hidden' when the member switched sharing off.
-- 'unmarked' = he has never touched My days, so "free" would be a guess.
create or replace function public._day_state(p_email text, p_from text, p_to text, p_self boolean)
 returns text language plpgsql stable security definer set search_path to ''
as $function$
declare m public.members; a date; b date;
begin
  select * into m from public.members where email = p_email order by created_at limit 1;
  if m.id is null then return 'unknown'; end if;
  if not p_self and not m.days_shared then return 'hidden'; end if;
  a := public._to_date(p_from); if a is null then return 'unknown'; end if;
  b := coalesce(public._to_date(p_to), a);
  if b < a then b := a; end if;
  if b > a + 60 then b := a + 60; end if;
  if exists (select 1 from public.member_days d where d.member = m.email and d.day between a and b) then return 'busy'; end if;
  if m.days_weekly <> '' and exists (select 1 from generate_series(a::timestamp, b::timestamp, interval '1 day') g
      where extract(dow from g)::int::text = any (string_to_array(m.days_weekly, ','))) then return 'busy'; end if;
  if m.days_updated_at is null then return 'unmarked'; end if;
  return 'free';
end $function$;

-- What member m sees of a job. The poster's name shows only to the poster, to Eretz Israel Tours, on a job posted
-- with a name, and to the colleague who was given the job. A phone number passes only between the poster and the
-- colleague he gave the job to. Never an email.
create or replace function public._job_json(j public.jobs, m public.members)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('id',j.id,'kind',j.kind,'title',j.title,'date_from',j.date_from,'date_to',j.date_to,'hours',j.hours,
    'start_place',j.start_place,'region',j.region,'pax',j.pax,'langs',j.langs,'needs',j.needs,
    'price',j.price,'currency',j.currency,'per',j.per,'vat',j.vat,'payment',j.payment,'note',j.note,'reply_by',j.reply_by,
    'audience',j.audience,'status',j.status,'anon',j.anon,'mine',j.owner = m.email,
    'by', case when j.owner = m.email or m.is_admin or not j.anon or j.taken_by = m.email
      then (select json_build_object('name', case when o.is_admin then 'Eretz Israel Tours' else o.name end, 'role', o.role, 'admin', o.is_admin)
            from public.members o where o.email = j.owner order by o.created_at limit 1) end,
    'by_phone', case when j.taken_by = m.email and j.status = 'filled'
      then (select o.phone from public.members o where o.email = j.owner order by o.created_at limit 1) end,
    'my_answer', coalesce((select f.answer from public.job_offers f where f.job_id = j.id and f.member = m.email), ''),
    'my_day', public._day_state(m.email, j.date_from, j.date_to, true),
    'taken_me', j.taken_by <> '' and j.taken_by = m.email,
    'n_sent', case when j.owner = m.email or m.is_admin then (select count(*) from public.job_offers f where f.job_id = j.id and f.picked) end,
    'n_yes', case when j.owner = m.email or m.is_admin then (select count(*) from public.job_offers f where f.job_id = j.id and f.answer = 'yes') end,
    'n_no', case when j.owner = m.email or m.is_admin then (select count(*) from public.job_offers f where f.job_id = j.id and f.answer = 'no') end,
    'taker', case when (j.owner = m.email or m.is_admin) and j.taken_by <> ''
      then (select json_build_object('name', case when t.is_admin then 'Eretz Israel Tours' else t.name end, 'role', t.role, 'phone', t.phone)
            from public.members t where t.email = j.taken_by order by t.created_at limit 1) end,
    'filled_at',j.filled_at,'created_at',j.created_at,'updated_at',j.updated_at)
$function$;

-- A member's own days and what jobs he takes.
create or replace function public._my_days_json(m public.members)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object(
    'days', coalesce((select json_agg(json_build_object('d', to_char(d.day, 'YYYY-MM-DD'), 'src', d.source,
        'job', (select jj.title from public.jobs jj where jj.id = d.job_id)) order by d.day)
      from public.member_days d where d.member = m.email and d.day >= current_date - 31), '[]'::json),
    'weekly', m.days_weekly, 'shared', m.days_shared, 'updated_at', m.days_updated_at,
    'kinds', m.job_kinds, 'tags', m.job_tags, 'langs', m.job_langs)
$function$;

-- RPCs (member token)
-- open: jobs sent to me that are still open. mine: jobs I posted. taken: jobs given to me.
-- all: for Eretz Israel Tours only, every colleague's job from the last 90 days, with who posted it.
create or replace function public.jobs_list(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; d0 text := to_char(now() at time zone 'Asia/Jerusalem', 'YYYY-MM-DD');
begin
  m := public._auth(p_token);
  if not public._jobs_on(m) then return json_build_object('open','[]'::json,'mine','[]'::json,'taken','[]'::json,'all','[]'::json,'me',public._my_days_json(m)); end if;
  return json_build_object(
    'open', coalesce((select json_agg(public._job_json(j, m) order by j.date_from, j.created_at) from public.jobs j
      where j.status = 'open' and j.owner <> m.email and coalesce(nullif(j.date_to,''), j.date_from) >= d0 and (j.reply_by = '' or j.reply_by >= d0)
        and (m.is_admin or public._job_offered(j, m))), '[]'::json),
    'mine', coalesce((select json_agg(public._job_json(j, m) order by (j.status <> 'open'), j.date_from desc, j.created_at desc) from public.jobs j
      where j.owner = m.email), '[]'::json),
    'taken', coalesce((select json_agg(public._job_json(j, m) order by j.date_from desc) from public.jobs j
      where j.taken_by = m.email and j.status in ('filled','closed')), '[]'::json),
    'all', case when m.is_admin then coalesce((select json_agg(public._job_json(j, m) order by j.created_at desc) from public.jobs j
      where j.owner <> m.email and j.created_at > now() - interval '90 days'), '[]'::json) else '[]'::json end,
    'me', public._my_days_json(m));
end $function$;

-- Post or change a job. p_to = the member ids it goes to when audience is 'picked'.
create or replace function public.job_save(p_token text, p_job jsonb, p_to jsonb default '[]'::jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; jid uuid := nullif(p_job->>'id','')::uuid; j public.jobs; a date; b date; aud text; ids uuid[];
begin
  m := public._auth(p_token);
  if not public._jobs_post(m) then raise exception 'Posting jobs is not open yet.' using errcode = '42501'; end if;
  if length(trim(coalesce(p_job->>'title',''))) < 3 then raise exception 'Say what the job is, in a few words.'; end if;
  if coalesce(p_job->>'kind','') not in ('guide','guide_vehicle','van_driver','jeep_driver','other') then raise exception 'Choose who you need.'; end if;
  a := public._to_date(p_job->>'date_from');
  if a is null then raise exception 'Add the date of the job.'; end if;
  b := coalesce(public._to_date(p_job->>'date_to'), a);
  if b < a then raise exception 'The last day is before the first day.'; end if;
  if b > a + 60 then raise exception 'A job can run 60 days at most.'; end if;
  if coalesce(p_job->>'price','') !~ '^\d{1,7}(\.\d{1,2})?$' then raise exception 'Add the price you pay, as a number.'; end if;
  aud := case when p_job->>'audience' = 'picked' then 'picked' else 'all' end;
  if aud = 'picked' then
    select array_agg(mm.id) into ids from public.members mm
      where mm.status = 'approved' and mm.email <> m.email
        and mm.id::text in (select jsonb_array_elements_text(case when jsonb_typeof(p_to) = 'array' then p_to else '[]'::jsonb end));
    if ids is null then raise exception 'Choose at least one person.'; end if;
  end if;
  if jid is not null then
    select * into j from public.jobs where id = jid and (owner = m.email or m.is_admin);
    if j.id is null then raise exception 'Only the person who posted this job, or Eretz Israel Tours, can change it.'; end if;
    if j.status <> 'open' then raise exception 'This job is closed. Reopen it to change it.'; end if;
  else
    if (select count(*) from public.jobs where owner = m.email and created_at > now() - interval '1 day') >= 30 then
      raise exception 'Too many jobs in one day. Try again tomorrow.'; end if;
    insert into public.jobs (owner, owner_name) values (m.email, m.name) returning id into jid;
  end if;
  update public.jobs set
    anon = coalesce(p_job->>'anon','true') not in ('false','f'),
    kind = p_job->>'kind',
    title = left(trim(p_job->>'title'),120),
    date_from = to_char(a, 'YYYY-MM-DD'),
    date_to = case when b > a then to_char(b, 'YYYY-MM-DD') else '' end,
    hours = left(trim(coalesce(p_job->>'hours','')),40),
    start_place = left(trim(coalesce(p_job->>'start_place','')),160),
    region = left(trim(coalesce(p_job->>'region','')),60),
    pax = left(trim(coalesce(p_job->>'pax','')),80),
    langs = left(trim(coalesce(p_job->>'langs','')),120),
    needs = public._csv_keys(p_job->>'needs', array['licensed','eshkol','midbari','gun','shabbat']),
    price = p_job->>'price',
    currency = case when p_job->>'currency' in ('USD','EUR') then p_job->>'currency' else 'ILS' end,
    per = case when p_job->>'per' in ('job','hour','vehicle') then p_job->>'per' else 'day' end,
    vat = case when p_job->>'vat' in ('including_vat','plus_vat','not_applicable') then p_job->>'vat' else '' end,
    payment = left(trim(coalesce(p_job->>'payment','')),200),
    note = left(trim(coalesce(p_job->>'note','')),1500),
    reply_by = coalesce(to_char(public._to_date(p_job->>'reply_by'), 'YYYY-MM-DD'), ''),
    audience = aud, updated_at = now()
  where id = jid returning * into j;
  -- who it goes to: rows nobody answered are rebuilt; an answer already given is kept
  delete from public.job_offers where job_id = jid and answer = '';
  update public.job_offers set picked = false where job_id = jid;
  if aud = 'picked' then
    insert into public.job_offers (job_id, member, picked) select jid, mm.email, true from public.members mm where mm.id = any (ids)
      on conflict (job_id, member) do update set picked = true;
  end if;
  return public._job_json(j, m);
end $function$;

-- Before posting: the colleagues this job fits, with Free / Busy / Not marked for its dates. Names and roles only.
create or replace function public.job_candidates(p_token text, p_job jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; k text := coalesce(p_job->>'kind','');
  n text := public._csv_keys(p_job->>'needs', array['licensed','eshkol','midbari','gun','shabbat']);
  df text := coalesce(p_job->>'date_from',''); dt text := coalesce(p_job->>'date_to','');
begin
  m := public._auth(p_token);
  if not public._jobs_post(m) then raise exception 'Posting jobs is not open yet.' using errcode = '42501'; end if;
  return coalesce((select json_agg(json_build_object('id',c.id,'name',case when c.is_admin then 'Eretz Israel Tours' else c.name end,
      'role',c.role,'langs',c.job_langs,'tags',c.job_tags,'profile',c.job_kinds <> '',
      'day',public._day_state(c.email, df, dt, false),
      'days_age',case when c.days_shared and c.days_updated_at is not null then floor(extract(epoch from now() - c.days_updated_at) / 86400)::int end)
    order by array_position(array['free','unmarked','hidden','unknown','busy'], public._day_state(c.email, df, dt, false)), lower(c.name))
    from public.members c where c.status = 'approved' and c.email <> m.email and public._job_fits(k, n, c)), '[]'::json);
end $function$;

-- A colleague answers a job sent to him: 'yes' (I'm available), 'no' (not for me), '' (take it back).
-- p_busy with 'no' also marks the job's days busy in My days.
create or replace function public.job_answer(p_token text, p_id uuid, p_answer text, p_busy boolean default false)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; j public.jobs; a date; b date;
begin
  m := public._auth(p_token);
  if not public._jobs_on(m) then raise exception 'Jobs are not open yet.' using errcode = '42501'; end if;
  if coalesce(p_answer,'') not in ('yes','no','') then raise exception 'Unknown answer.'; end if;
  select * into j from public.jobs where id = p_id for update;
  if j.id is null or j.owner = m.email or not (m.is_admin or public._job_offered(j, m)) then raise exception 'This job was not sent to you.'; end if;
  if j.status <> 'open' then raise exception 'This job is no longer open.'; end if;
  insert into public.job_offers (job_id, member, answer, answered_at)
    values (p_id, m.email, coalesce(p_answer,''), case when coalesce(p_answer,'') = '' then null else now() end)
    on conflict (job_id, member) do update set answer = excluded.answer, answered_at = excluded.answered_at;
  if p_answer = 'no' and coalesce(p_busy, false) then
    a := public._to_date(j.date_from); b := coalesce(public._to_date(j.date_to), a);
    if a is not null then
      insert into public.member_days (member, day) select m.email, g::date from generate_series(a::timestamp, b::timestamp, interval '1 day') g
        on conflict (member, day) do nothing;
      update public.members set days_updated_at = now() where id = m.id returning * into m;
    end if;
  end if;
  return public._job_json(j, m);
end $function$;

-- For the poster (or Eretz Israel Tours): who the job went to and who said he is available. Names and roles only.
create or replace function public.job_replies(p_token text, p_id uuid)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; j public.jobs;
begin
  m := public._auth(p_token);
  select * into j from public.jobs where id = p_id and (owner = m.email or m.is_admin);
  if j.id is null then raise exception 'Only the person who posted this job, or Eretz Israel Tours, can see the answers.'; end if;
  return coalesce((select json_agg(json_build_object('id',c.id,'name',case when c.is_admin then 'Eretz Israel Tours' else c.name end,
      'role',c.role,'langs',c.job_langs,'tags',c.job_tags,'picked',f.picked,'answer',f.answer,'answered_at',f.answered_at,
      'day',public._day_state(c.email, j.date_from, j.date_to, false))
    order by (f.answer = 'yes') desc, f.answered_at nulls last, lower(c.name))
    from public.job_offers f join public.members c on c.email = f.member and c.status = 'approved'
    where f.job_id = j.id and (f.picked or f.answer = 'yes')), '[]'::json);
end $function$;

-- The poster gives the job to one colleague who said he is available. From here the two see each other's name and
-- phone, the job's days go into that colleague's My days, and everyone else sees the job is no longer open.
create or replace function public.job_give(p_token text, p_id uuid, p_member uuid)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; j public.jobs; t public.members; a date; b date;
begin
  m := public._auth(p_token);
  select * into j from public.jobs where id = p_id and (owner = m.email or m.is_admin) for update;
  if j.id is null then raise exception 'Only the person who posted this job, or Eretz Israel Tours, can give it.'; end if;
  if j.status <> 'open' then raise exception 'This job is no longer open.'; end if;
  select * into t from public.members where id = p_member and status = 'approved';
  if t.id is null or not exists (select 1 from public.job_offers f where f.job_id = p_id and f.member = t.email and f.answer = 'yes') then
    raise exception 'That person has not said they are available.'; end if;
  update public.jobs set taken_by = t.email, status = 'filled', filled_at = now(), updated_at = now() where id = p_id returning * into j;
  a := public._to_date(j.date_from); b := coalesce(public._to_date(j.date_to), a);
  if a is not null then
    insert into public.member_days (member, day, source, job_id) select t.email, g::date, 'job', p_id from generate_series(a::timestamp, b::timestamp, interval '1 day') g
      on conflict (member, day) do nothing;
  end if;
  return public._job_json(j, m);
end $function$;

-- closed: the job is withdrawn (a colleague who had it gets his days back). open: reopen it for answers.
create or replace function public.job_set_status(p_token text, p_id uuid, p_status text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; j public.jobs;
begin
  m := public._auth(p_token);
  select * into j from public.jobs where id = p_id and (owner = m.email or m.is_admin);
  if j.id is null then raise exception 'Only the person who posted this job, or Eretz Israel Tours, can change it.'; end if;
  if p_status = 'closed' then
    delete from public.member_days where job_id = p_id and source = 'job';
    update public.jobs set status = 'closed', updated_at = now() where id = p_id returning * into j;
  elsif p_status = 'open' then
    delete from public.member_days where job_id = p_id and source = 'job';
    update public.jobs set status = 'open', taken_by = '', filled_at = null, updated_at = now() where id = p_id returning * into j;
  else
    raise exception 'Unknown status.';
  end if;
  return public._job_json(j, m);
end $function$;

create or replace function public.job_delete(p_token text, p_id uuid)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  delete from public.jobs where id = p_id and (owner = m.email or m.is_admin);
end $function$;

-- My days: read.
create or replace function public.my_days(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return public._my_days_json(m);
end $function$;

-- My days: mark days busy (p_busy) or free again (p_free). Arrays of 'yyyy-mm-dd'.
create or replace function public.my_days_set(p_token text, p_busy jsonb default '[]'::jsonb, p_free jsonb default '[]'::jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  if not public._jobs_on(m) then raise exception 'Jobs are not open yet.' using errcode = '42501'; end if;
  if jsonb_typeof(p_busy) = 'array' then
    if jsonb_array_length(p_busy) > 400 then raise exception 'Too many days at once.'; end if;
    insert into public.member_days (member, day)
      select distinct m.email, public._to_date(x) from jsonb_array_elements_text(p_busy) as u(x)
      where public._to_date(x) between current_date - 31 and current_date + 800
      on conflict (member, day) do nothing;
  end if;
  if jsonb_typeof(p_free) = 'array' then
    if jsonb_array_length(p_free) > 400 then raise exception 'Too many days at once.'; end if;
    delete from public.member_days where member = m.email and day in (select public._to_date(x) from jsonb_array_elements_text(p_free) as u(x));
  end if;
  update public.members set days_updated_at = now() where id = m.id returning * into m;
  return public._my_days_json(m);
end $function$;

-- My days: weekdays that are always busy, whether colleagues see free/busy, the jobs I take, and "still right".
create or replace function public.my_days_prefs(p_token text, p_prefs jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  if not public._jobs_on(m) then raise exception 'Jobs are not open yet.' using errcode = '42501'; end if;
  update public.members set
    days_weekly = case when p_prefs ? 'weekly' then public._csv_keys(p_prefs->>'weekly', array['0','1','2','3','4','5','6']) else days_weekly end,
    days_shared = case when p_prefs ? 'shared' then coalesce(p_prefs->>'shared','true') not in ('false','f') else days_shared end,
    job_kinds = case when p_prefs ? 'kinds' then
        case when lower(trim(coalesce(p_prefs->>'kinds',''))) = 'none' then 'none'
             else public._csv_keys(p_prefs->>'kinds', array['guide','guide_vehicle','van_driver','jeep_driver','other']) end
      else job_kinds end,
    job_tags = case when p_prefs ? 'tags' then public._csv_keys(p_prefs->>'tags', array['licensed','eshkol','midbari','gun','shabbat']) else job_tags end,
    job_langs = case when p_prefs ? 'langs' then left(trim(coalesce(p_prefs->>'langs','')),200) else job_langs end,
    days_updated_at = case when p_prefs ? 'weekly' or coalesce(p_prefs->>'confirm','') = 'true' then now() else days_updated_at end
  where id = m.id returning * into m;
  return public._my_days_json(m);
end $function$;


-- A quote added by a limited member is an organisation's quote. Stamped when the quote is first saved, whichever
-- function saves it (quote_save, or a booking sheet both sides accepted).
create or replace function public.quotes_org_stamp()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
begin
  new.org := coalesce((select public._limited(mm) from public.members mm where mm.email = new.owner order by mm.created_at limit 1), false);
  return new;
end $function$;


-- ===== Guide pages for clients, claimed pages, reviews (3 Oct 2026, D-12, D-14) =====

create or replace function public.review_post(p_token text, p_vendor text, p_body text, p_rating text, p_private boolean)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; v public.vendors; st text := 'approved'; pr boolean;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  select * into v from public.vendors where id = p_vendor;
  if v.id is null then raise exception 'That supplier no longer exists.'; end if;
  if public._is_own(v, m) then raise exception 'You cannot add a note to your own page.'; end if;
  pr := coalesce(p_private, false);   -- an organisation may keep a review private too; otherwise its review is for everyone, at once (D-15)
  if not m.is_admin and not pr and public._is_guide(v) and public._is_guide_member(m) then st := 'pending'; end if;
  insert into public.vendor_notes (vendor_id, body, author, author_name, org, rating, private, status)
  values (p_vendor, trim(p_body), m.email, m.name, public._limited(m), case when coalesce(p_rating,'') ~ '^[1-5]$' then p_rating else '' end, pr, st);
  return json_build_object('status', st, 'private', pr);
end $function$;

create or replace function public.note_decide(p_token text, p_id uuid, p_approve boolean)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token, true);
  update public.vendor_notes set status = case when coalesce(p_approve, false) then 'approved' else 'rejected' end, decided_by = m.email, decided_at = now()
    where id = p_id and status = 'pending';
  if not found then raise exception 'That note was already handled.'; end if;
end $function$;

create or replace function public.notes_pending(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  return coalesce((select json_agg(json_build_object('id',n.id,'vendor_id',n.vendor_id,'vendor_name',v.name,'body',n.body,
      'author_name',n.author_name,'by',public._who(n.author),'created_at',n.created_at) order by n.created_at)
    from public.vendor_notes n join public.vendors v on v.id = n.vendor_id where n.status = 'pending'), '[]'::json);
end $function$;

create or replace function public.vendor_set_client(p_token text, p_vendor text, p_bio text, p_retail text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; v public.vendors; b text := trim(coalesce(p_bio,'')); rt text := trim(coalesce(p_retail,''));
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  select * into v from public.vendors where id = p_vendor;
  if v.id is null then raise exception 'That supplier no longer exists.'; end if;
  if not public._is_guide(v) then raise exception 'Only a guide''s page has a section for clients.'; end if;
  if public._limited(m) then raise exception 'This section is written by guides, agents and Eretz Israel Tours.' using errcode = '42501'; end if;
  -- once a guide has claimed his page, only he and Eretz Israel Tours write what clients see
  if v.claimed_by <> '' and not m.is_admin and v.claimed_by <> m.email then raise exception 'This guide has claimed the page, so only they can change what clients see.'; end if;
  if length(b) > 1500 then raise exception 'Keep the bio under 1,500 characters.'; end if;
  if length(rt) > 200 then raise exception 'Keep the retail price under 200 characters.'; end if;
  -- a colleague neither sees nor changes a price on a supplier whose prices are private
  if v.prices_private and not m.is_admin then rt := v.retail_price; end if;
  update public.vendors set client_bio = b, retail_price = rt where id = p_vendor;
  return public._vendor_view(p_vendor, m.is_admin, m.email);
end $function$;

create or replace function public.file_for_clients(p_token text, p_file uuid, p_on boolean)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; f public.vendor_files; v public.vendors; n int;
begin
  m := public._auth(p_token);
  select * into f from public.vendor_files where id = p_file;
  if f.id is null or (f.private and not m.is_admin and f.uploaded_by <> m.email) then raise exception 'That picture no longer exists.'; end if;
  perform public._visible(f.vendor_id, m.is_admin);
  if public._limited(m) then raise exception 'This section is written by guides, agents and Eretz Israel Tours.' using errcode = '42501'; end if;
  if exists (select 1 from public.vendors x where x.id = f.vendor_id and x.claimed_by <> '' and not m.is_admin and x.claimed_by <> m.email) then
    raise exception 'This guide has claimed the page, so only they can change what clients see.'; end if;
  if coalesce(p_on, false) then
    -- one at a time per guide, so two people adding at once cannot pass four
    select * into v from public.vendors where id = f.vendor_id for update;
    if not public._is_guide(v) then raise exception 'Only a guide''s page has pictures for clients.'; end if;
    if f.quote_id is not null then raise exception 'A file attached to a quote cannot be a picture for clients.'; end if;
    if f.private then raise exception 'A file marked "only me" cannot be a picture for clients.'; end if;
    if f.mime_type !~ '^image/(jpeg|png|webp)$' then raise exception 'Use a JPEG, PNG or WebP picture.'; end if;
    if (select count(*) from public.vendor_files x where x.vendor_id = f.vendor_id and x.for_clients and x.id <> f.id) >= 4 then
      raise exception 'Four pictures at most. Remove one first.'; end if;
  end if;
  update public.vendor_files set for_clients = coalesce(p_on, false) where id = p_file;
  select count(*) into n from public.vendor_files x where x.vendor_id = f.vendor_id and x.for_clients;
  return json_build_object('ok', true, 'for_clients', coalesce(p_on, false), 'n', n);
end $function$;

create or replace function public.vendor_claim(p_token text, p_vendor text, p_note text default ''::text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; v public.vendors;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if m.is_admin then raise exception 'Eretz Israel Tours links a page to a member from the page itself.'; end if;
  -- an organisation is not a supplier on the list (D-15); if a school should own a page, Eretz Israel Tours links it
  if public._limited(m) then raise exception 'Claiming a page is for the guides, agents and suppliers on the list.' using errcode = '42501'; end if;
  select * into v from public.vendors where id = p_vendor;
  if v.id is null then raise exception 'That supplier no longer exists.'; end if;
  if v.claimed_by = m.email then raise exception 'This page is already yours.'; end if;
  if v.claimed_by <> '' then raise exception 'Someone has already claimed this page. If that is wrong, tell Eretz Israel Tours through Feedback.'; end if;
  if (select count(*) from public.vendor_claims c where c.member = m.email and c.status = 'pending' and c.vendor_id <> p_vendor) >= 5 then
    raise exception 'You already have several claims waiting.'; end if;
  insert into public.vendor_claims (vendor_id, member, member_name, note) values (p_vendor, m.email, m.name, left(trim(coalesce(p_note,'')), 500))
    on conflict (vendor_id, member) where (status = 'pending'::text) do update set note = excluded.note;
  return json_build_object('ok', true, 'status', 'pending');
end $function$;

create or replace function public.claims_list(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  return coalesce((select json_agg(json_build_object('id',c.id,'vendor_id',c.vendor_id,'vendor_name',v.name,'category',v.category,
      'member_id',mm.id,'member_name',coalesce(mm.name, c.member_name),'role',case when mm.org <> '' then mm.org else coalesce(mm.role,'') end,'note',c.note,
      'match',coalesce(public._is_own(v, mm), false),'created_at',c.created_at) order by c.created_at)
    from public.vendor_claims c join public.vendors v on v.id = c.vendor_id
      left join public.members mm on mm.email = c.member and mm.status = 'approved'
    where c.status = 'pending'), '[]'::json);
end $function$;

create or replace function public.claim_decide(p_token text, p_id uuid, p_approve boolean)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members; c public.vendor_claims;
begin
  m := public._auth(p_token, true);
  select * into c from public.vendor_claims where id = p_id and status = 'pending' for update;
  if c.id is null then raise exception 'That claim was already handled.'; end if;
  if coalesce(p_approve, false) then
    if not exists (select 1 from public.members where email = c.member and status = 'approved') then raise exception 'That member is no longer active.'; end if;
    update public.vendors set claimed_by = c.member, claimed_at = now() where id = c.vendor_id;
    update public.vendor_claims set status = 'rejected', decided_by = m.email, decided_at = now() where vendor_id = c.vendor_id and status = 'pending' and id <> p_id;
  end if;
  update public.vendor_claims set status = case when coalesce(p_approve, false) then 'approved' else 'rejected' end, decided_by = m.email, decided_at = now() where id = p_id;
end $function$;

create or replace function public.vendor_set_claim(p_token text, p_vendor text, p_member uuid)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; t public.members;
begin
  m := public._auth(p_token, true);
  if not exists (select 1 from public.vendors where id = p_vendor) then raise exception 'That supplier no longer exists.'; end if;
  if p_member is null then
    update public.vendors set claimed_by = '', claimed_at = null where id = p_vendor;
  else
    select * into t from public.members where id = p_member and status = 'approved' and not is_admin;
    if t.id is null then raise exception 'Choose an approved member.'; end if;
    update public.vendors set claimed_by = t.email, claimed_at = now() where id = p_vendor;
    update public.vendor_claims set status = case when member = t.email then 'approved' else 'rejected' end, decided_by = m.email, decided_at = now()
      where vendor_id = p_vendor and status = 'pending';
  end if;
  return public._vendor_view(p_vendor, true);
end $function$;

create or replace function public.vendor_dispute(p_token text, p_vendor text, p_message text)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members; v public.vendors;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  select * into v from public.vendors where id = p_vendor;
  if v.id is null or not public._is_own(v, m) then raise exception 'Only the person whose page this is can dispute it. Use "Update this supplier" instead.'; end if;
  if length(trim(coalesce(p_message,''))) < 5 then raise exception 'Say what is wrong, and what it should be.'; end if;
  if (select count(*) from public.vendor_reports where author = m.email and created_at > now() - interval '1 hour') > 20 then raise exception 'Too many reports in a short time. Try again later.'; end if;
  insert into public.vendor_reports (vendor_id, kind, message, anonymous, author, author_name, by_owner)
    values (p_vendor, 'Mistake', left(trim(p_message), 2000), false, m.email, m.name, true);
end $function$;


-- ===== Triggers =====

CREATE TRIGGER vendors_before_write BEFORE INSERT OR UPDATE ON public.vendors FOR EACH ROW EXECUTE FUNCTION vendors_before_write();
CREATE TRIGGER vendor_files_stamp BEFORE INSERT ON public.vendor_files FOR EACH ROW EXECUTE FUNCTION vendor_files_stamp();
CREATE TRIGGER quotes_org_stamp BEFORE INSERT ON public.quotes FOR EACH ROW EXECUTE FUNCTION quotes_org_stamp();


-- ===== Table and sequence privileges (fail closed) =====
-- Supabase's default privileges give anon and authenticated arwdDxtm on every new public table and rwU on every new
-- sequence. RLS (on, no policies) blocks their SELECT/INSERT/UPDATE/DELETE but NOT TRUNCATE, REFERENCES, TRIGGER or (PG17) MAINTAIN,
-- so without these lines a rebuild lets anon run `truncate public.members cascade`. Strip every table and sequence
-- privilege from PUBLIC, anon and authenticated; all app access goes through the token RPCs below. service_role keeps
-- full access (the files edge function reads and writes members, quotes, vendors, vendor_files and feedback with the
-- service key); the owner keeps everything. Read-only catalog check, 2 Oct 2026 (table-level privileges via relacl and
-- has_table_privilege; column-level grants were not checked): production tables have this same table ACL, but
-- production's two identity sequences (action_log_id_seq, filter_log_id_seq) still grant anon/authenticated rwU. That was reported, not changed here.
revoke all on all tables in schema public from public, anon, authenticated;
revoke all on all sequences in schema public from public, anon, authenticated;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;


-- ===== Execute grants (no table grants to anon/authenticated; RLS on, no policies) =====

revoke all on function member_new_link(text,uuid) from public; grant execute on function member_new_link(text,uuid) to anon, authenticated;
revoke all on function price_save(text,text,jsonb,text) from public; grant execute on function price_save(text,text,jsonb,text) to anon, authenticated;
revoke all on function deal_delete(text,uuid) from public; grant execute on function deal_delete(text,uuid) to anon, authenticated;
revoke all on function note_add(text,text,text) from public; grant execute on function note_add(text,text,text) to anon, authenticated;
revoke all on function note_delete(text,uuid) from public; grant execute on function note_delete(text,uuid) to anon, authenticated;
revoke all on function requests_list(text) from public; grant execute on function requests_list(text) to anon, authenticated;
revoke all on function feedback_add(text,text,text,text,text) from public; grant execute on function feedback_add(text,text,text,text,text) to anon, authenticated;
revoke all on function vendor_set_site(text,text,text,text) from public; grant execute on function vendor_set_site(text,text,text,text) to anon, authenticated;
revoke all on function whoami(text) from public; grant execute on function whoami(text) to anon, authenticated;
revoke all on function report_vendor(text,text,text,text,boolean) from public; grant execute on function report_vendor(text,text,text,text,boolean) to anon, authenticated;
revoke all on function vendor_reports_list(text) from public; grant execute on function vendor_reports_list(text) to anon, authenticated;
revoke all on function vendor_report_set(text,uuid,text) from public; grant execute on function vendor_report_set(text,uuid,text) to anon, authenticated;
revoke all on function feedback_list(text) from public; grant execute on function feedback_list(text) to anon, authenticated;
revoke all on function feedback_update(text,uuid,text,text) from public; grant execute on function feedback_update(text,uuid,text,text) to anon, authenticated;
revoke all on function member_decide(text,uuid,text) from public; grant execute on function member_decide(text,uuid,text) to anon, authenticated;
revoke all on function vendors_list(text) from public; grant execute on function vendors_list(text) to anon, authenticated;
revoke all on function vendor_save(text,jsonb,text) from public; grant execute on function vendor_save(text,jsonb,text) to anon, authenticated;
revoke all on function vendor_delete(text,text) from public; grant execute on function vendor_delete(text,text) to anon, authenticated;
revoke all on function quote_delete(text,uuid) from public; grant execute on function quote_delete(text,uuid) to anon, authenticated;
revoke all on function request_decide(text,uuid,boolean) from public; grant execute on function request_decide(text,uuid,boolean) to anon, authenticated;
revoke all on function admin_note_save(text,text,text) from public; grant execute on function admin_note_save(text,text,text) to anon, authenticated;
revoke all on function deal_add(text,text,jsonb) from public; grant execute on function deal_add(text,text,jsonb) to anon, authenticated;
revoke all on function log_filter(text,text,text) from public; grant execute on function log_filter(text,text,text) to anon, authenticated;
revoke all on function members_list(text) from public; grant execute on function members_list(text) to anon, authenticated;
revoke all on function quote_save(text,text,jsonb) from public; grant execute on function quote_save(text,text,jsonb) to anon, authenticated;
revoke all on function quotes_list(text,text) from public; grant execute on function quotes_list(text,text) to anon, authenticated;
revoke all on function quotes_tracker(text) from public; grant execute on function quotes_tracker(text) to anon, authenticated;
revoke all on function _fees_clean(jsonb) from public, anon, authenticated;
revoke all on function _phone_norm(text) from public, anon, authenticated;
revoke all on function _driver_json(drivers,text,boolean) from public, anon, authenticated;
revoke all on function drivers_list(text,text) from public; grant execute on function drivers_list(text,text) to anon, authenticated;
revoke all on function driver_find(text,text) from public; grant execute on function driver_find(text,text) to anon, authenticated;
revoke all on function driver_save(text,text,jsonb) from public; grant execute on function driver_save(text,text,jsonb) to anon, authenticated;
revoke all on function driver_review_add(text,uuid,text,jsonb) from public; grant execute on function driver_review_add(text,uuid,text,jsonb) to anon, authenticated;
revoke all on function driver_review_delete(text,uuid) from public; grant execute on function driver_review_delete(text,uuid) to anon, authenticated;
revoke all on function driver_remove(text,uuid,text) from public; grant execute on function driver_remove(text,uuid,text) to anon, authenticated;
revoke all on function public._terms_clean(jsonb) from public, anon, authenticated;
revoke all on function public._bookings_on(public.members) from public, anon, authenticated;
revoke all on function public._booking_json(public.bookings) from public, anon, authenticated;
revoke all on function public._booking_to_quote(public.bookings) from public, anon, authenticated;
revoke all on function public.booking_save(text,text,jsonb) from public; grant execute on function public.booking_save(text,text,jsonb) to anon, authenticated;
revoke all on function public.bookings_list(text,text) from public; grant execute on function public.bookings_list(text,text) to anon, authenticated;
revoke all on function public.booking_set_status(text,uuid,text) from public; grant execute on function public.booking_set_status(text,uuid,text) to anon, authenticated;
revoke all on function public.booking_delete(text,uuid) from public; grant execute on function public.booking_delete(text,uuid) to anon, authenticated;
revoke all on function public.booking_open(text) from public; grant execute on function public.booking_open(text) to anon, authenticated;
revoke all on function public.booking_answer(text,jsonb,text) from public; grant execute on function public.booking_answer(text,jsonb,text) to anon, authenticated;
revoke all on function public._booking_content(public.bookings) from public, anon, authenticated;
revoke all on function public._booking_days_clean(text,text,text) from public, anon, authenticated;
revoke all on function public._booking_plan_clean(jsonb,text,text,text) from public, anon, authenticated;
revoke all on function public.booking_accept(text,text) from public; grant execute on function public.booking_accept(text,text) to anon, authenticated;
revoke all on function public._jobs_on(public.members) from public, anon, authenticated;
revoke all on function public._jobs_post(public.members) from public, anon, authenticated;
revoke all on function public._csv_keys(text,text[]) from public, anon, authenticated;
revoke all on function public._to_date(text) from public, anon, authenticated;
revoke all on function public._job_fits(text,text,public.members) from public, anon, authenticated;
revoke all on function public._job_offered(public.jobs,public.members) from public, anon, authenticated;
revoke all on function public._day_state(text,text,text,boolean) from public, anon, authenticated;
revoke all on function public._job_json(public.jobs,public.members) from public, anon, authenticated;
revoke all on function public._my_days_json(public.members) from public, anon, authenticated;
revoke all on function public.jobs_list(text) from public; grant execute on function public.jobs_list(text) to anon, authenticated;
revoke all on function public.job_save(text,jsonb,jsonb) from public; grant execute on function public.job_save(text,jsonb,jsonb) to anon, authenticated;
revoke all on function public.job_candidates(text,jsonb) from public; grant execute on function public.job_candidates(text,jsonb) to anon, authenticated;
revoke all on function public.job_answer(text,uuid,text,boolean) from public; grant execute on function public.job_answer(text,uuid,text,boolean) to anon, authenticated;
revoke all on function public.job_replies(text,uuid) from public; grant execute on function public.job_replies(text,uuid) to anon, authenticated;
revoke all on function public.job_give(text,uuid,uuid) from public; grant execute on function public.job_give(text,uuid,uuid) to anon, authenticated;
revoke all on function public.job_set_status(text,uuid,text) from public; grant execute on function public.job_set_status(text,uuid,text) to anon, authenticated;
revoke all on function public.job_delete(text,uuid) from public; grant execute on function public.job_delete(text,uuid) to anon, authenticated;
revoke all on function public.my_days(text) from public; grant execute on function public.my_days(text) to anon, authenticated;
revoke all on function public.my_days_set(text,jsonb,jsonb) from public; grant execute on function public.my_days_set(text,jsonb,jsonb) to anon, authenticated;
revoke all on function public.my_days_prefs(text,jsonb) from public; grant execute on function public.my_days_prefs(text,jsonb) to anon, authenticated;
revoke all on function vendor_set_status(text,text,text) from public; grant execute on function vendor_set_status(text,text,text) to anon, authenticated;
revoke all on function vendor_set_prices_private(text,text,boolean) from public; grant execute on function vendor_set_prices_private(text,text,boolean) to anon, authenticated;
revoke all on function accept_terms(text,text) from public; grant execute on function accept_terms(text,text) to anon, authenticated;
revoke all on function reservation_report(text,text,text,text,text) from public; grant execute on function reservation_report(text,text,text,text,text) to anon, authenticated;
revoke all on function food_delete(text,uuid) from public; grant execute on function food_delete(text,uuid) to anon, authenticated;
revoke all on function food_list(text,text) from public; grant execute on function food_list(text,text) to anon, authenticated;
revoke all on function food_add(text,text,text,text,text) from public; grant execute on function food_add(text,text,text,text,text) to anon, authenticated;
revoke all on function price_delete(text,uuid,text) from public; grant execute on function price_delete(text,uuid,text) to anon, authenticated;
revoke all on function ack_reminder(text) from public; grant execute on function ack_reminder(text) to anon, authenticated;
revoke all on function log_action(text,text,text) from public; grant execute on function log_action(text,text,text) to anon, authenticated;
revoke all on function activity(text,text) from public; grant execute on function activity(text,text) to anon, authenticated;
revoke all on function my_top(text) from public; grant execute on function my_top(text) to anon, authenticated;
revoke all on function set_bcc_pref(text,boolean) from public; grant execute on function set_bcc_pref(text,boolean) to anon, authenticated;
revoke all on function set_setting(text,text,text) from public; grant execute on function set_setting(text,text,text) to anon, authenticated;
revoke all on function request_access(text,text,text,text,text,text,text) from public; grant execute on function request_access(text,text,text,text,text,text,text) to anon, authenticated;
revoke all on function my_usage(text) from public; grant execute on function my_usage(text) to anon, authenticated;
revoke all on function vendor_set_agent(text,text,text,text) from public; grant execute on function vendor_set_agent(text,text,text,text) to anon, authenticated;
revoke all on function hours_verify(text,text,text) from public; grant execute on function hours_verify(text,text,text) to anon, authenticated;
revoke all on function vendor_detail(text,text) from public; grant execute on function vendor_detail(text,text) to anon, authenticated;
-- Limited members (D-15): the new helpers and the quotes trigger function are not RPCs; member_set_access (Eretz Israel
-- Tours only, checked inside), review_add and request_access_org are. _file_scope is called by the files edge function
-- with the service key.
revoke all on function public._me() from public, anon, authenticated;
revoke all on function public._section_of(text) from public, anon, authenticated;
revoke all on function public._limited(public.members) from public, anon, authenticated;
revoke all on function public._can_see(public.members,text,text) from public, anon, authenticated;
revoke all on function public._reviews_open(public.members,text,text) from public, anon, authenticated;
revoke all on function public._price_visible(public.vendor_prices,public.vendors,public.members) from public, anon, authenticated;
revoke all on function public._note_visible(public.vendor_notes,public.vendors,public.members) from public, anon, authenticated;
revoke all on function public._file_visible(public.vendor_files,public.members) from public, anon, authenticated;
revoke all on function public._file_scope(uuid,text) from public, anon, authenticated;
grant execute on function public._file_scope(uuid,text) to service_role;
revoke all on function public._quote_kind(public.quotes,public.vendors) from public, anon, authenticated;
revoke all on function public._quote_visible(public.quotes,public.vendors,public.members) from public, anon, authenticated;
revoke all on function public._vendor_for(public.vendors,public.members) from public, anon, authenticated;
revoke all on function public.quotes_org_stamp() from public, anon, authenticated;
revoke all on function public.review_add(text,text,text,text) from public; grant execute on function public.review_add(text,text,text,text) to anon, authenticated;
revoke all on function public._is_guide(public.vendors) from public, anon, authenticated;
revoke all on function public._is_own(public.vendors,public.members) from public, anon, authenticated;
revoke all on function public._driver_own(public.drivers,public.members) from public, anon, authenticated;
revoke all on function public._is_guide_member(public.members) from public, anon, authenticated;
revoke all on function public.review_post(text,text,text,text,boolean) from public; grant execute on function public.review_post(text,text,text,text,boolean) to anon, authenticated;
revoke all on function public.note_decide(text,uuid,boolean) from public; grant execute on function public.note_decide(text,uuid,boolean) to anon, authenticated;
revoke all on function public.notes_pending(text) from public; grant execute on function public.notes_pending(text) to anon, authenticated;
revoke all on function public.vendor_set_client(text,text,text,text) from public; grant execute on function public.vendor_set_client(text,text,text,text) to anon, authenticated;
revoke all on function public.file_for_clients(text,uuid,boolean) from public; grant execute on function public.file_for_clients(text,uuid,boolean) to anon, authenticated;
revoke all on function public.vendor_claim(text,text,text) from public; grant execute on function public.vendor_claim(text,text,text) to anon, authenticated;
revoke all on function public.claims_list(text) from public; grant execute on function public.claims_list(text) to anon, authenticated;
revoke all on function public.claim_decide(text,uuid,boolean) from public; grant execute on function public.claim_decide(text,uuid,boolean) to anon, authenticated;
revoke all on function public.vendor_set_claim(text,text,uuid) from public; grant execute on function public.vendor_set_claim(text,text,uuid) to anon, authenticated;
revoke all on function public.vendor_dispute(text,text,text) from public; grant execute on function public.vendor_dispute(text,text,text) to anon, authenticated;
revoke all on function public.request_access_org(text,text,text,text,text,text,text) from public; grant execute on function public.request_access_org(text,text,text,text,text,text,text) to anon, authenticated;
revoke all on function public.member_set_access(text,uuid,jsonb) from public; grant execute on function public.member_set_access(text,uuid,jsonb) to anon, authenticated;

-- Internal helper, not an RPC: given an email it returns that member's display name, so it must not be callable
-- by anon or authenticated (Supabase's default privileges grant both on new public functions). It still runs inside
-- the SECURITY DEFINER RPCs above (_vendor_view, vendor_detail), which call it as the function owner. Production has the same ACL (read-only catalog check, 2 Oct 2026).
revoke all on function public._name(text) from public, anon, authenticated;

-- The other internal helpers, trigger functions and the vendors.id default are not RPCs either. Without these lines a
-- rebuild leaves them executable by PUBLIC, anon and authenticated (e.g. _price_write / _vendor_apply would write prices
-- and supplier fields with no token check). They are only reached from the SECURITY DEFINER RPCs above, the two triggers
-- and the column default, which run as the owner; postgres and service_role (files edge function) keep access. Production has the
-- same ACL on all 19 helpers (read-only catalog check, 2 Oct 2026).
revoke execute on function public._all_fields() from public, anon, authenticated;
revoke execute on function public._auth(text,boolean) from public, anon, authenticated;
revoke execute on function public._hash(text) from public, anon, authenticated;
revoke execute on function public._locked_fields() from public, anon, authenticated;
revoke execute on function public._new_token() from public, anon, authenticated;
revoke execute on function public._price_clean(jsonb) from public, anon, authenticated;
revoke execute on function public._price_write(text,uuid,jsonb,text) from public, anon, authenticated;
revoke execute on function public._quote_json(public.quotes,boolean) from public, anon, authenticated;
revoke execute on function public._vendor_apply(text,jsonb) from public, anon, authenticated;
revoke execute on function public._vendor_json(text) from public, anon, authenticated;
revoke execute on function public._vendor_view(text,boolean,text) from public, anon, authenticated;
revoke execute on function public._visible(text,boolean) from public, anon, authenticated;
revoke execute on function public._who(text) from public, anon, authenticated;
revoke execute on function public.is_admin() from public, anon, authenticated;
revoke execute on function public.is_contributor() from public, anon, authenticated;
revoke execute on function public.gen_vendor_id() from public, anon, authenticated;
revoke execute on function public.vendor_files_stamp() from public, anon, authenticated;
revoke execute on function public.vendors_before_write() from public, anon, authenticated;


-- ===== Storage buckets (create as private) =====

-- storage bucket vendor-files (public=f)
-- storage bucket member-proofs (public=f)
-- storage bucket feedback-files (public=f)

-- ===== Added 2026-10-01 after export: keep-alive ping (used by .github/workflows/keep-alive.yml) =====
CREATE OR REPLACE FUNCTION public.ping() RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$ select 'ok:' || (select count(*) from public.vendors)::text $$;
revoke all on function public.ping() from public; grant execute on function public.ping() to anon, authenticated;

-- ===== Added 2026-10-01: join-request push alert =====
-- request_access (above) returns the ntfy topic so the joining browser can post a push alert to Eretz Israel Tours.
-- Set it once to a random, unguessable value (NOT stored in this public repo):
--   insert into public.app_settings(key, value) values ('ntfy_topic', 'eit-suppliers-<random>') on conflict (key) do update set value = excluded.value;
-- pg_net was enabled during testing (create extension pg_net with schema extensions) but is not used: ntfy.sh rate-limits Supabase's shared IP.

-- ===== Default privileges for objects created later (2 Oct 2026) =====
-- Runs last, so it changes nothing created above. For tables, sequences and functions that postgres creates in public
-- later (migrations, SQL editor), it removes the direct anon/authenticated default grants that Supabase sets up, so a
-- new table or sequence stays closed. service_role and the owner keep their defaults.
-- Functions are NOT closed by this rule alone: PostgreSQL's built-in PUBLIC EXECUTE default on new functions remains
-- (a schema-scoped rule cannot remove it), and anon/authenticated inherit it through PUBLIC. So every newly added
-- function still needs an explicit `revoke ... from public`: helpers and trigger functions as in the helper section
-- above, and RPCs `revoke all ... from public` followed by an explicit `grant execute ... to anon, authenticated`.
-- supabase_admin has the same public-schema defaults, which postgres cannot change (only a member of supabase_admin can;
-- that membership was not checked on production). Those defaults only apply to objects
-- supabase_admin itself creates; everything in this file is created (and owned) by the role running it, normally postgres,
-- and the explicit table/sequence revokes above strip whatever default grants an object got. To catch anything added later
-- (by either role), check pg_class.relacl for every table AND sequence in public and pg_proc.proacl for functions; the
-- role_table_grants query in docs/AUDIT_2026-10-01.md section 9 covers tables only, not sequences or functions.
-- Production's postgres defaults still grant anon/authenticated (read-only check, 2 Oct 2026); these lines are repo-only.
alter default privileges for role postgres in schema public revoke all on tables from public, anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from public, anon, authenticated;
alter default privileges for role postgres in schema public revoke all on functions from public, anon, authenticated;
