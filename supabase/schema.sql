-- Israel Suppliers Master List: database schema (public schema; storage buckets listed at the end).
-- Exported from Supabase project wjuqtjlrtcywjaspjpwu on 2026-10-01.
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
  constraint members_token_hash_key UNIQUE (token_hash),
  constraint members_pkey PRIMARY KEY (id),
  constraint members_email_check CHECK (((email = lower(email)) AND (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'::text))),
  constraint members_name_check CHECK (((length(TRIM(BOTH FROM name)) >= 1) AND (length(TRIM(BOTH FROM name)) <= 80))),
  constraint members_role_check CHECK ((role = ANY (ARRAY[''::text, 'Licensed tour guide'::text, 'Travel agent'::text, 'Tour operator'::text, 'Other'::text]))),
  constraint members_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'revoked'::text])))
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
  constraint quote_options_pkey PRIMARY KEY (id),
  constraint quote_options_name_check CHECK ((length(name) <= 120)),
  constraint quote_options_note_check CHECK ((length(note) <= 1000))
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
  shared boolean default false not null,
  owner text not null,
  owner_name text default ''::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
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
  constraint vendor_notes_pkey PRIMARY KEY (id),
  constraint vendor_notes_body_check CHECK (((length(TRIM(BOTH FROM body)) >= 1) AND (length(TRIM(BOTH FROM body)) <= 2000)))
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
  constraint vendors_pkey PRIMARY KEY (id),
  constraint vendors_active_check CHECK ((active = ANY (ARRAY['Active'::text, 'Inactive'::text]))),
  constraint "vendors_agentPriceVatTreatment_check" CHECK (("agentPriceVatTreatment" = ANY (ARRAY[''::text, 'including_vat'::text, 'plus_vat'::text, 'not_applicable'::text]))),
  constraint vendors_agent_link_check CHECK (((agent_link = ''::text) OR (agent_link ~* '^https?://'::text))),
  constraint vendors_also_categories_check CHECK ((length(also_categories) <= 300)),
  constraint "vendors_cancelDayType_check" CHECK (("cancelDayType" = ANY (ARRAY[''::text, 'Calendar days'::text, 'Business days'::text]))),
  constraint "vendors_cancelNoticeUnit_check" CHECK (("cancelNoticeUnit" = ANY (ARRAY[''::text, 'Hours'::text, 'Days'::text]))),
  constraint "vendors_cancelPolicyVerifiedDate_check" CHECK ((("cancelPolicyVerifiedDate" = ''::text) OR ("cancelPolicyVerifiedDate" ~ '^\d{4}-\d{2}-\d{2}$'::text))),
  constraint vendors_category_check CHECK ((category = ANY (ARRAY['Hotel'::text, 'Guide'::text, 'Transport'::text, 'Restaurant'::text, 'Winery'::text, 'Attraction / Site'::text, 'Activity'::text, 'Adventure'::text, 'National Parks'::text, 'Travel Agent'::text, 'Itinerary Planner'::text, 'Flight'::text, 'Other'::text]))),
  constraint vendors_currency_check CHECK ((currency = ANY (ARRAY['USD'::text, 'ILS'::text, 'EUR'::text]))),
  constraint vendors_experience_years_check CHECK (((experience_years = ''::text) OR (experience_years ~ '^\d{1,2}$'::text))),
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
CREATE INDEX vendors_name_norm_idx ON public.vendors USING btree (name_norm);
CREATE INDEX vendors_category_idx ON public.vendors USING btree (category);


-- ===== Foreign keys =====

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


-- ===== Functions (RPCs; all data access goes through these) =====

CREATE OR REPLACE FUNCTION public._all_fields()
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select array['name','category','active','contactPerson','phone','whatsapp','email','website','location','languages','kosher','maxCap','listedPrice','listedPriceVatTreatment','agentPrice','agentPriceVatTreatment','maxPax','priceBasis','currency','payTerms','cancelPolicy','cancelNoticeAmount','cancelNoticeUnit','cancelDayType','cancelPenalty','cancelPolicyVerifiedDate','npResLink','rateReliability','rateService','rateValue','strengths','weaknesses','notes','region','tags','experience_years','agent_link','agent_howto','also_categories','maps_link']::text[]
$function$
;

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
  update public.members set last_seen_at = now() where id = m.id and (last_seen_at is null or last_seen_at < now() - interval '10 minutes');
  return m;
end $function$
;

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

CREATE OR REPLACE FUNCTION public._quote_json(q quotes, p_full boolean)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select json_build_object('id',q.id,'vendor_id',q.vendor_id,'title',case when p_full then q.title else '' end,
    'date_from',q.date_from,'date_to',q.date_to,'pax',q.pax,'units',q.units,'received_on',q.received_on,'valid_until',q.valid_until,
    'ref',case when p_full then q.ref else '' end,'status',q.status,'currency',q.currency,'vat',q.vat,'conditions',q.conditions,
    'private_note',case when p_full then q.private_note else '' end,'shared',q.shared,'owner',q.owner,'owner_name',q.owner_name,'owner_role',(select mm.role from public.members mm where mm.email = q.owner limit 1),'owner_admin',(select mm.is_admin from public.members mm where mm.email = q.owner limit 1),
    'can_edit',p_full,'created_at',q.created_at,'updated_at',q.updated_at,
    'files',(select count(*) from public.vendor_files f where f.quote_id = q.id),
    'options',coalesce((select json_agg(json_build_object('id',o.id,'name',o.name,'note',o.note,
        'lines',coalesce((select json_agg(l order by l.sort) from public.quote_lines l where l.option_id = o.id),'[]'::json)) order by o.sort)
      from public.quote_options o where o.quote_id = q.id),'[]'::json))
$function$
;

CREATE OR REPLACE FUNCTION public._vendor_apply(p_id text, p_vals jsonb)
 RETURNS vendors
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.vendors;
begin
  select * into r from public.vendors where id = p_id;
  if r.id is null then raise exception 'That supplier no longer exists.'; end if;
  r := jsonb_populate_record(r, p_vals);
  update public.vendors v set (name,category,active,"contactPerson",phone,whatsapp,email,website,location,languages,kosher,"maxCap","listedPrice","listedPriceVatTreatment","agentPrice","agentPriceVatTreatment","maxPax","priceBasis",currency,"payTerms","cancelPolicy","cancelNoticeAmount","cancelNoticeUnit","cancelDayType","cancelPenalty","cancelPolicyVerifiedDate","npResLink","rateReliability","rateService","rateValue",strengths,weaknesses,notes,region,tags,experience_years,agent_link,agent_howto,also_categories,maps_link)
    = (r.name,r.category,r.active,r."contactPerson",r.phone,r.whatsapp,r.email,r.website,r.location,r.languages,r.kosher,r."maxCap",r."listedPrice",r."listedPriceVatTreatment",r."agentPrice",r."agentPriceVatTreatment",r."maxPax",r."priceBasis",r.currency,r."payTerms",r."cancelPolicy",r."cancelNoticeAmount",r."cancelNoticeUnit",r."cancelDayType",r."cancelPenalty",r."cancelPolicyVerifiedDate",r."npResLink",r."rateReliability",r."rateService",r."rateValue",r.strengths,r.weaknesses,r.notes,r.region,r.tags,r.experience_years,r.agent_link,r.agent_howto,r.also_categories,r.maps_link)
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

CREATE OR REPLACE FUNCTION public._vendor_view(p_id text, p_admin boolean, p_email text DEFAULT ''::text)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case when p_admin then (public._vendor_json(p_id)::jsonb || jsonb_build_object('_prices',(select count(*) from public.vendor_prices p where p.vendor_id=p_id)))::json
  else (
    (public._vendor_json(p_id)::jsonb
      || case when v.prices_private then jsonb_build_object('agentPrice','','listedPrice','','agentPriceVatTreatment','','listedPriceVatTreatment','','maxPax','') else '{}'::jsonb end)
      || jsonb_build_object('_prices', (select count(*) from public.vendor_prices p where p.vendor_id=p_id and ((p.owner <> '' and p.owner = p_email) or (p.owner = '' and not v.prices_private and not p.private))),
                            'created_by', public._name(v.created_by), 'updated_by', public._name(v.updated_by))
  )::json end
  from public.vendors v where v.id = p_id
$function$
;

CREATE OR REPLACE FUNCTION public._visible(p_vendor text, p_admin boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not p_admin and exists (select 1 from public.vendors where id = p_vendor and hidden) then raise exception 'That supplier is not available.'; end if;
end $function$
;

CREATE OR REPLACE FUNCTION public._who(p_email text)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case when p_email is null or p_email in ('','import','system') or p_email like 'import from%' then null
    else coalesce((select json_build_object('name',m.name,'role',m.role,'admin',m.is_admin) from public.members m where m.email = split_part(p_email,' (',1) order by m.created_at limit 1),
                  json_build_object('name','A colleague','role','','admin',false)) end
$function$
;

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
begin
  perform public._auth(p_token, true);
  if p_status not in ('approved','revoked') then raise exception 'Unknown decision'; end if;
  update public.members set status = p_status, decided_at = now() where id = p_id and not is_admin;
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
  return coalesce((select json_agg(json_build_object('id',id,'name',name,'email',email,'phone',phone,'note',note,'role',role,'license_no',license_no,'has_proof',proof_path is not null,'status',status,'is_admin',is_admin,'created_at',created_at,'last_seen_at',last_seen_at,'terms_version',terms_version,'terms_accepted_at',terms_accepted_at) order by (status='pending') desc, created_at desc) from public.members), '[]'::json);
end $function$
;

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
      where a.member = m.email and a.vendor_id is not null and (m.is_admin or not v.hidden)
      group by a.vendor_id order by score desc limit 8) t), '[]'::json);
end $function$
;

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

CREATE OR REPLACE FUNCTION public.note_add(p_token text, p_vendor text, p_body text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  insert into public.vendor_notes (vendor_id, body, author, author_name) values (p_vendor, trim(p_body), m.email, m.name);
end $function$
;

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

CREATE OR REPLACE FUNCTION public.price_save(p_token text, p_vendor text, p_data jsonb, p_reason text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; c jsonb := public._price_clean(p_data); pid uuid := nullif(p_data->>'id','')::uuid; cur public.vendor_prices; mine boolean := coalesce((p_data->>'mine')::boolean,false); pp boolean;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if c->>'price' = '' and c->>'label' = '' then raise exception 'Add what the price is for.'; end if;
  select prices_private into pp from public.vendors where id = p_vendor;
  if pid is not null then select * into cur from public.vendor_prices p where p.id = pid and p.vendor_id = p_vendor;
    if cur.id is null then raise exception 'That price no longer exists.'; end if; end if;
  if m.is_admin and not (cur.id is not null and cur.owner <> '' and cur.owner <> m.email) then
    perform public._price_write(p_vendor, pid, c, m.email);
    return json_build_object('request', false);
  end if;
  -- personal line: saved straight away, visible only to its owner and the admin
  if mine or pp or (cur.id is not null and cur.owner = m.email) then
    if cur.id is not null and cur.owner <> m.email then raise exception 'You can only change your own prices.'; end if;
    c := c || jsonb_build_object('private', true);
    pid := public._price_write(p_vendor, pid, c, m.email);
    update public.vendor_prices set owner = m.email where id = pid;
    return json_build_object('request', false, 'mine', true);
  end if;
  c := c - 'private';
  if length(trim(coalesce(p_reason,''))) < 3 then raise exception 'Say briefly where this price comes from or why it changed.'; end if;
  insert into public.change_requests (vendor_id, kind, target_id, proposed, current, reason, requested_by, requested_name)
  values (p_vendor, case when pid is null then 'price_add' else 'price_edit' end, pid, c, coalesce(to_jsonb(cur),'{}'::jsonb), trim(p_reason), m.email, m.name);
  return json_build_object('request', true);
end $function$
;

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
    private_note=left(coalesce(p_quote->>'private_note',''),3000), shared=coalesce((p_quote->>'shared')::boolean,false), updated_at=now()
  where id = qid;
  delete from public.quote_options where quote_id = qid;
  for o in select * from jsonb_array_elements(coalesce(p_quote->'options','[]'::jsonb)) loop
    insert into public.quote_options (quote_id, name, note, sort) values (qid, left(coalesce(nullif(o->>'name',''),'Option'),120), left(coalesce(o->>'note',''),1000), oi) returning id into oid;
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
    from public.quotes q where q.vendor_id = p_vendor and (q.shared or q.owner = m.email or m.is_admin)), '[]'::json);
end $function$
;

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

CREATE OR REPLACE FUNCTION public.set_setting(p_token text, p_key text, p_value text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  if p_key not in ('bcc_email') then raise exception 'Unknown setting'; end if;
  if p_key = 'bcc_email' and p_value <> '' and p_value !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Enter a full email address.'; end if;
  insert into public.app_settings (key, value) values (p_key, lower(trim(p_value))) on conflict (key) do update set value = excluded.value;
end $function$
;

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
declare m public.members; pp boolean;
begin
  m := public._auth(p_token);
  if not m.is_admin and exists (select 1 from public.vendors where id = p_id and hidden) then raise exception 'That supplier is not available.'; end if;
  select prices_private into pp from public.vendors where id = p_id;
  return json_build_object(
    'prices', coalesce((select json_agg(json_build_object('id',p.id,'vendor_id',p.vendor_id,'label',p.label,'audience',p.audience,'age_from',p.age_from,'age_to',p.age_to,'pax_min',p.pax_min,'pax_max',p.pax_max,'season',p.season,'price',p.price,'currency',p.currency,'vat',p.vat,'basis',p.basis,'is_agent',p.is_agent,'source',p.source,'checked_on',p.checked_on,'note',p.note,'private',p.private,'sort',p.sort,
          'owner',p.owner,'mine',(p.owner <> '' and p.owner = m.email),
          'by',public._who(case when p.owner <> '' then p.owner else p.created_by end),'by_date',p.updated_at)
        order by (p.owner <> ''), p.sort, p.audience, p.created_at)
      from public.vendor_prices p where p.vendor_id = p_id
        and (m.is_admin or (p.owner <> '' and p.owner = m.email) or (p.owner = '' and not pp and not p.private))), '[]'),
    'prices_private', coalesce(pp,false),
    'deals', coalesce((select json_agg(case when m.is_admin then to_jsonb(d) else to_jsonb(d) || jsonb_build_object('reported_by', public._name(d.reported_by)) end order by (d.valid_to <> '' and d.valid_to < to_char(now(),'YYYY-MM-DD')), d.created_at desc) from public.vendor_deals d where d.vendor_id = p_id), '[]'),
    'notes', coalesce((select json_agg(case when m.is_admin then to_jsonb(n) else to_jsonb(n) || jsonb_build_object('author', public._name(n.author)) end order by n.created_at desc) from public.vendor_notes n where n.vendor_id = p_id), '[]'),
    'requests', coalesce((select json_agg(c order by c.created_at desc) from public.change_requests c where c.vendor_id = p_id and c.status = 'pending' and (m.is_admin or c.requested_by = m.email)), '[]'),
    'admin_note', case when m.is_admin then (select body from public.vendor_admin_notes a where a.vendor_id = p_id) else null end,
    'sites', coalesce((select json_agg(json_build_object('id',s.id,'name',s.name,'location',s.location,'reservation',s.reservation) order by s.name) from public.vendors s where s.parent_id = p_id and (m.is_admin or not s.hidden)), '[]'),
    'parent', (select json_build_object('id',pv.id,'name',pv.name) from public.vendors v join public.vendors pv on pv.id = v.parent_id where v.id = p_id and (m.is_admin or not pv.hidden)),
    'res_reports', coalesce((select json_agg(json_build_object('checked',r.checked,'visit_date',r.visit_date,'note',r.note,'member_name',r.member_name,'created_at',r.created_at,'mine',r.member = m.email) order by r.created_at desc) from (select * from public.reservation_reports where vendor_id = p_id order by created_at desc limit 20) r), '[]'),
    'res_answered', exists (select 1 from public.reservation_reports where vendor_id = p_id and member = m.email),
    'deal_by', coalesce((select json_object_agg(d.id, public._who(d.reported_by)) from public.vendor_deals d where d.vendor_id = p_id), '{}'),
    'note_by', coalesce((select json_object_agg(n.id, public._who(n.author)) from public.vendor_notes n where n.vendor_id = p_id), '{}')
  );
end $function$
;

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
    'author_name',case when r.anonymous then '' else r.author_name end,'author',case when r.anonymous then '' else r.author end,'status',r.status,'created_at',r.created_at) order by (r.status='New') desc, r.created_at desc)
    from public.vendor_reports r join public.vendors v on v.id = r.vendor_id where r.status = 'New' or r.created_at > now() - interval '30 days'), '[]'::json);
end $function$
;

CREATE OR REPLACE FUNCTION public.vendor_save(p_token text, p_data jsonb, p_reason text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; r public.vendors; f text; clean jsonb := '{}'::jsonb; cur jsonb; locked_changes jsonb := '{}'::jsonb; open_vals jsonb := '{}'::jsonb; req boolean := false;
  price_fields text[] := array['agentPrice','listedPrice','agentPriceVatTreatment','listedPriceVatTreatment','maxPax'];
begin
  m := public._auth(p_token);
  foreach f in array public._all_fields() loop
    clean := clean || jsonb_build_object(f, left(coalesce(p_data->>f,''), 2000));
  end loop;
  if coalesce(p_data->>'id','') = '' then
    select * into r from jsonb_populate_record(null::public.vendors, clean);
    insert into public.vendors (name,category,active,"contactPerson",phone,whatsapp,email,website,location,languages,kosher,"maxCap","listedPrice","listedPriceVatTreatment","agentPrice","agentPriceVatTreatment","maxPax","priceBasis",currency,"payTerms","cancelPolicy","cancelNoticeAmount","cancelNoticeUnit","cancelDayType","cancelPenalty","cancelPolicyVerifiedDate","npResLink","rateReliability","rateService","rateValue",strengths,weaknesses,notes,region,tags,experience_years,agent_link,agent_howto,also_categories,maps_link)
    values (r.name,r.category,r.active,r."contactPerson",r.phone,r.whatsapp,r.email,r.website,r.location,r.languages,r.kosher,r."maxCap",r."listedPrice",r."listedPriceVatTreatment",r."agentPrice",r."agentPriceVatTreatment",r."maxPax",r."priceBasis",r.currency,r."payTerms",r."cancelPolicy",r."cancelNoticeAmount",r."cancelNoticeUnit",r."cancelDayType",r."cancelPenalty",r."cancelPolicyVerifiedDate",r."npResLink",r."rateReliability",r."rateService",r."rateValue",r.strengths,r.weaknesses,r.notes,r.region,r.tags,r.experience_years,r.agent_link,r.agent_howto,r.also_categories,r.maps_link)
    returning * into r;
    return json_build_object('vendor', public._vendor_view(r.id, m.is_admin, m.email), 'request', false);
  end if;
  select to_jsonb(v) into cur from public.vendors v where v.id = p_data->>'id';
  if cur is null then raise exception 'That supplier no longer exists.'; end if;
  if m.is_admin then
    r := public._vendor_apply(p_data->>'id', clean);
    return json_build_object('vendor', public._vendor_view(r.id, true), 'request', false);
  end if;
  if (cur->>'hidden')::boolean then raise exception 'That supplier is not available.'; end if;
  foreach f in array public._all_fields() loop
    if (cur->>'prices_private')::boolean and f = any(price_fields) then continue; end if;
    if (clean->>f) is distinct from coalesce(cur->>f,'') then
      if f = any(public._locked_fields()) then locked_changes := locked_changes || jsonb_build_object(f, clean->>f);
      else open_vals := open_vals || jsonb_build_object(f, clean->>f); end if;
    end if;
  end loop;
  if open_vals <> '{}'::jsonb then perform public._vendor_apply(p_data->>'id', open_vals); end if;
  if locked_changes <> '{}'::jsonb then
    if length(trim(coalesce(p_reason,''))) < 3 then raise exception 'Say briefly why the price or contact details changed.'; end if;
    insert into public.change_requests (vendor_id, kind, proposed, current, reason, requested_by, requested_name)
    select p_data->>'id', 'vendor_fields', locked_changes,
      (select jsonb_object_agg(k, coalesce(cur->>k,'')) from jsonb_object_keys(locked_changes) k), trim(p_reason), m.email, m.name;
    req := true;
  end if;
  return json_build_object('vendor', public._vendor_view(p_data->>'id', false, m.email), 'request', req);
end $function$
;

CREATE OR REPLACE FUNCTION public.vendor_set_agent(p_token text, p_vendor text, p_link text, p_howto text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; l text := trim(coalesce(p_link,''));
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if l <> '' and l !~* '^https?://' then l := 'https://' || l; end if;
  if l <> '' and l !~* '^https?://[^\s/]+\.[^\s]+' then raise exception 'That link does not look right.'; end if;
  update public.vendors set agent_link = left(l,500), agent_howto = left(trim(coalesce(p_howto,'')),1000), updated_by = m.email, updated_at = now() where id = p_vendor;
  return public._vendor_view(p_vendor, m.is_admin, m.email);
end $function$
;

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
  return coalesce((select json_agg(public._vendor_view(v.id, m.is_admin, m.email) order by v.name) from public.vendors v where m.is_admin or not v.hidden), '[]'::json);
end $function$
;

CREATE OR REPLACE FUNCTION public.whoami(p_token text)
 RETURNS json
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select json_build_object('name',name,'email',email,'status',status,'is_admin',is_admin,'role',role,'has_proof',proof_path is not null,'terms_version',terms_version,
    'reminder_due', (not is_admin) and (reminder_seen_at is null or reminder_seen_at < now() - interval '30 days'),
    'bcc_email', case when status = 'approved' then (select value from public.app_settings where key = 'bcc_email') else '' end,
    'bcc_opt_out', bcc_opt_out, 'bcc_ack', bcc_ack)
  from public.members where token_hash = public._hash(p_token);
$function$
;


-- ===== Triggers =====

CREATE TRIGGER vendors_before_write BEFORE INSERT OR UPDATE ON public.vendors FOR EACH ROW EXECUTE FUNCTION vendors_before_write();
CREATE TRIGGER vendor_files_stamp BEFORE INSERT ON public.vendor_files FOR EACH ROW EXECUTE FUNCTION vendor_files_stamp();


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
revoke all on function vendor_detail(text,text) from public; grant execute on function vendor_detail(text,text) to anon, authenticated;

-- Internal helper, not an RPC: given an email it returns that member's display name, so it must not be callable
-- by anon or authenticated (Supabase's default privileges grant both on new public functions). It still runs inside
-- the SECURITY DEFINER RPCs above (_vendor_view, vendor_detail), which call it as the function owner. Matches the live lock.
revoke all on function public._name(text) from public, anon, authenticated;

-- The other internal helpers, trigger functions and the vendors.id default are not RPCs either. Without these lines a
-- rebuild leaves them executable by PUBLIC, anon and authenticated (e.g. _price_write / _vendor_apply would write prices
-- and supplier fields with no token check). They are only reached from the SECURITY DEFINER RPCs above, the two triggers
-- and the column default, which run as the owner; postgres and service_role (files edge function) keep access. Matches live.
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
