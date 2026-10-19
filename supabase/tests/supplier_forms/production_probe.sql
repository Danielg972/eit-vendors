-- D-61, a supplier details form: probe for the live database (and the local copy). Changes nothing.
-- Inside its own transaction it adds a sample Eretz Israel Tours member, a sample guide, a sample organisation (limited
-- member) and sample suppliers; then it makes form links, answers them as the supplier (the anon role, as the page calls
-- them), and reviews and applies them as each member. It ends by raising an error that carries the results, so
-- everything it did is rolled back. All names, numbers and answers are invented samples.
-- Run it as one statement (Supabase SQL editor, or the connector's execute_sql) after
-- supabase/migrations/2026-10-19_supplier_forms.sql. Before that migration is on production, run_probe.py puts the
-- migration in at the line marked @migration, so the probe proves it there and rolls it back with everything else.
-- Read the JSON after "PROBE": every value must be true, and "failed" must be an empty list.
do $probe$
declare ta text := 'probe-admin-' || md5(random()::text) || md5(random()::text);
  tg text := 'probe-guide-' || md5(random()::text) || md5(random()::text);
  tl text := 'probe-org-' || md5(random()::text) || md5(random()::text);
  r jsonb := '{}'::jsonb; j jsonb; j2 jsonb; rows jsonb; err text; n0 bigint; real0 text; realp text; realn text; fs0 text; set0 text;
  sa text := 'vendor_pfa' || substr(md5(random()::text),1,4); sr text := 'vendor_pfr' || substr(md5(random()::text),1,4);
  sh text := 'vendor_pfh' || substr(md5(random()::text),1,4);
  k1 text; k2 text; k3 text; k4 text; k5 text; f1 uuid; f2 uuid; f3 uuid; f4 uuid; nv text; i int;
  good jsonb := '{"name":"Sample Workshop","contact":"Sample Name","role":"Bookings","phone":"050-000-0000","address":"12 Sample St","city":"Jerusalem",
    "hours":"Sun–Thu 09:00–17:00 · Fri 09:00–13:00 · Sat closed","last_entry":"16:00","shabbat":"closed","p_trade":"₪80 per person","p_adult":"95",
    "p_child":"no number here","vat":"including_vat","duration":"1.5 hours","about":"Sample: pottery for groups","consent":true,
    "secret_field":"dropped","kosher":"maybe","types":"Activity"}';
  fails text[] := '{}';
begin
  -- @migration
  select md5(coalesce(string_agg(id || name || coalesce(location,'') || coalesce(hours,'') || coalesce(tags,'') || coalesce(hours_source,''), ',' order by id), '')) into real0 from public.vendors;
  select md5(coalesce(string_agg(id::text || price || source, ',' order by id), '')) into realp from public.vendor_prices;
  select md5(coalesce(string_agg(id::text || body, ',' order by id), '')) into realn from public.vendor_notes;
  select md5(coalesce(string_agg(id::text || status, ',' order by id), '')) into fs0 from public.supplier_forms;
  select coalesce((select value from public.app_settings where key = 'forms_for'), '(none)') into set0;

  insert into public.members (name, email, token_hash, status, is_admin, role) values ('Sample Admin', 'probe-admin@probe.invalid', public._hash(ta), 'approved', true, '');
  insert into public.members (name, email, token_hash, status, role, license_no, phone) values ('Sample Guide', 'probe-guide@probe.invalid', public._hash(tg), 'approved', 'Licensed tour guide', 'LIC-PROBE-61', '0509999961');
  insert into public.members (name, email, token_hash, status, role, member_type, sections, org) values ('Sample Org', 'probe-org@probe.invalid', public._hash(tl), 'approved', 'Other', 'limited', 'transport,sites,food', 'Sample Organisation');
  perform set_config('app.admin', 'on', true); perform set_config('app.editor', 'probe-admin@probe.invalid', true);
  insert into public.vendors (id, name, category, region, location, phone, "agentPrice", tags) values
    (sa, 'Sample Workshop Probe', 'Attraction / Site', 'Jerusalem', 'Old City, Jerusalem', '050-000-0000', '75', 'Workshop'),
    (sr, 'Sample Grill Probe', 'Restaurant', 'Jerusalem', 'Sample town', '', '', ''),
    (sh, 'Sample Hidden Probe', 'Attraction / Site', 'Jerusalem', '', '', '', '');
  update public.vendors set hidden = true where id = sh;
  perform set_config('app.admin', 'off', true);
  perform public.set_setting(ta, 'forms_for', 'admin');   -- start from the default, Eretz Israel Tours only (rolled back)

  -- who may make a link: Eretz Israel Tours only, until the setting is on
  r := r || jsonb_build_object('whoami_admin_forms', (public.whoami(ta)::jsonb->>'forms')::boolean and public.whoami(ta)::jsonb->>'forms_for' = 'admin');
  r := r || jsonb_build_object('whoami_guide_off_by_default', not (public.whoami(tg)::jsonb->>'forms')::boolean and public.whoami(tg)::jsonb->>'forms_for' = '');
  begin perform public.supplier_form_new(tg, sa, ''); r := r || '{"guide_refused_while_off":false}'; exception when others then r := r || jsonb_build_object('guide_refused_while_off', sqlerrm = 'Only Eretz Israel Tours can do that for now.'); end;
  begin perform public.set_setting(tg, 'forms_for', 'all'); r := r || '{"guide_cannot_switch_on":false}'; exception when others then r := r || jsonb_build_object('guide_cannot_switch_on', sqlerrm = 'Only Eretz Israel Tours can do that.'); end;
  begin perform public.set_setting(ta, 'forms_for', 'everyone'); r := r || '{"bad_value_refused":false}'; exception when others then r := r || jsonb_build_object('bad_value_refused', sqlerrm = 'Unknown setting'); end;
  perform public.set_setting(ta, 'forms_for', 'all');
  perform public.set_setting(ta, 'bookings_for', (select coalesce((select value from public.app_settings where key = 'bookings_for'), 'admin')));
  r := r || jsonb_build_object('other_settings_still_work', true);
  r := r || jsonb_build_object('whoami_guide_on', (public.whoami(tg)::jsonb->>'forms')::boolean);
  r := r || jsonb_build_object('whoami_org_never', not (public.whoami(tl)::jsonb->>'forms')::boolean);
  begin perform public.supplier_form_new(tl, sa, ''); r := r || '{"org_refused":false}'; exception when others then r := r || jsonb_build_object('org_refused', sqlerrm = 'Supplier forms are for guides and agents.'); end;
  begin perform public.supplier_form_new('no-such-link', sa, ''); r := r || '{"bad_link_refused":false}'; exception when others then r := r || jsonb_build_object('bad_link_refused', sqlerrm like 'Your link is not active%'); end;
  begin perform public.supplier_form_new(tg, sh, ''); r := r || '{"hidden_supplier_refused":false}'; exception when others then r := r || jsonb_build_object('hidden_supplier_refused', sqlerrm = 'That supplier is not available.'); end;
  begin perform public.supplier_form_new(tg, '', 'x'); r := r || '{"short_name_refused":false}'; exception when others then r := r || jsonb_build_object('short_name_refused', sqlerrm = 'Write the business name.'); end;

  -- the guide makes a link for a supplier on the list, and one for a new supplier
  j := public.supplier_form_new(tg, sa, 'ignored name')::jsonb; k1 := j->>'key';
  r := r || jsonb_build_object('link_for_entry_takes_its_name', j->>'business_name' = 'Sample Workshop Probe' and length(k1) = 48,
    'link_reply_has_no_email', j::text !~ '@');
  select id into f1 from public.supplier_forms where key_hash = public._hash(k1);
  r := r || jsonb_build_object('only_the_hash_is_kept', f1 is not null and not exists (select 1 from public.supplier_forms f where to_jsonb(f)::text like '%' || k1 || '%'),
    'link_lasts_30_days', (select expires_at between now() + interval '29 days 23 hours' and now() + interval '30 days 1 hour' from public.supplier_forms where id = f1));
  j := public.supplier_form_new(tg, '', '  Sample Winery Probe  ')::jsonb; k2 := j->>'key';
  select id into f2 from public.supplier_forms where key_hash = public._hash(k2);
  r := r || jsonb_build_object('link_for_new_supplier', j->>'business_name' = 'Sample Winery Probe' and (select vendor_id is null from public.supplier_forms where id = f2));
  k3 := public.supplier_form_new(ta, sr, '')::jsonb->>'key'; select id into f3 from public.supplier_forms where key_hash = public._hash(k3);
  k4 := public.supplier_form_new(ta, sa, '')::jsonb->>'key'; select id into f4 from public.supplier_forms where key_hash = public._hash(k4);
  k5 := public.supplier_form_new(ta, sa, '')::jsonb->>'key';

  -- the supplier's side, as the anon role: the name and nothing else
  set local role anon;
  j := public.supplier_form_open(k1)::jsonb;
  reset role;
  r := r || jsonb_build_object('page_gets_only_name_and_expiry', (select array_agg(x order by x) from jsonb_object_keys(j) x) = array['business_name','expires_at'] and j->>'business_name' = 'Sample Workshop Probe');
  begin set local role anon; perform public.supplier_form_open('0123456789abcdef0123456789abcdef0123456789abcdef'); reset role; r := r || '{"unknown_key_refused":false}'; exception when others then reset role; r := r || jsonb_build_object('unknown_key_refused', sqlerrm = 'This link is not active.'); end;
  begin set local role anon; perform public.supplier_form_open('short'); reset role; r := r || '{"short_key_refused":false}'; exception when others then reset role; r := r || jsonb_build_object('short_key_refused', sqlerrm = 'This link is not active.'); end;
  begin set local role anon; select count(*) into n0 from public.supplier_forms; reset role; r := r || '{"anon_cannot_read_table":false}'; exception when others then reset role; r := r || jsonb_build_object('anon_cannot_read_table', sqlerrm like 'permission denied%'); end;
  begin set local role authenticated; select count(*) into n0 from public.supplier_forms; reset role; r := r || '{"auth_cannot_read_table":false}'; exception when others then reset role; r := r || jsonb_build_object('auth_cannot_read_table', sqlerrm like 'permission denied%'); end;
  begin set local role anon; perform public._form_rows('{}'::jsonb, null::public.vendors); reset role; r := r || '{"anon_cannot_call_helpers":false}'; exception when others then reset role; r := r || jsonb_build_object('anon_cannot_call_helpers', sqlerrm like 'permission denied%'); end;
  begin set local role anon; perform public.supplier_form_answer(k1, '{"name":"Sample Workshop"}'); reset role; r := r || '{"contact_required":false}'; exception when others then reset role; r := r || jsonb_build_object('contact_required', sqlerrm = 'Please add a contact name.'); end;
  begin set local role anon; perform public.supplier_form_answer(k1, '{"name":"Sample Workshop","contact":"Sample Name","phone":"12"}'); reset role; r := r || '{"phone_required":false}'; exception when others then reset role; r := r || jsonb_build_object('phone_required', sqlerrm = 'Please add a phone number.'); end;
  set local role anon;
  j := public.supplier_form_answer(k1, good)::jsonb;
  perform public.supplier_form_answer(k2, '{"name":"Sample Winery Probe","contact":"Sample Owner","phone":"050-000-1111","types":"Winery","p_trade":"60","kosher":"cert","kosher_cert":"Sample Rabbanut","consent":false}');
  perform public.supplier_form_answer(k3, '{"name":"Sample Grill Probe","contact":"Sample Chef","phone":"050-000-2222","kosher":"not"}');
  perform public.supplier_form_answer(k4, '{"name":"Sample Workshop Probe","contact":"Sample Name","phone":"050-000-0000","p_trade":"ask us for the sample guide rate","duration":"2 hours"}');
  reset role;
  r := r || jsonb_build_object('answer_accepted', (j->>'ok')::boolean);
  begin set local role anon; perform public.supplier_form_answer(k1, good); reset role; r := r || '{"second_answer_refused":false}'; exception when others then reset role; r := r || jsonb_build_object('second_answer_refused', sqlerrm = 'This form was already sent. Thank you.'); end;
  begin set local role anon; perform public.supplier_form_open(k1); reset role; r := r || '{"link_closes_after_answer":false}'; exception when others then reset role; r := r || jsonb_build_object('link_closes_after_answer', sqlerrm = 'This form was already sent. Thank you.'); end;
  update public.supplier_forms set expires_at = now() - interval '1 minute' where key_hash = public._hash(k5);
  begin set local role anon; perform public.supplier_form_open(k5); reset role; r := r || '{"expired_link_refused":false}'; exception when others then reset role; r := r || jsonb_build_object('expired_link_refused', sqlerrm like 'This link has expired%'); end;
  begin set local role anon; perform public.supplier_form_answer(k5, good); reset role; r := r || '{"expired_answer_refused":false}'; exception when others then reset role; r := r || jsonb_build_object('expired_answer_refused', sqlerrm like 'This link has expired%'); end;
  j := (select answers from public.supplier_forms where id = f1);
  r := r || jsonb_build_object('answers_cleaned', not (j ? 'secret_field') and not (j ? 'kosher') and j->>'shabbat' = 'closed' and (j->>'consent')::boolean and j->>'phone' = '050-000-0000');

  -- the review list: Eretz Israel Tours only
  begin perform public.supplier_forms_list(tg); r := r || '{"guide_cannot_read_list":false}'; exception when others then r := r || jsonb_build_object('guide_cannot_read_list', sqlerrm = 'Only Eretz Israel Tours can do that.'); end;
  begin perform public.supplier_forms_list(tl); r := r || '{"org_cannot_read_list":false}'; exception when others then r := r || jsonb_build_object('org_cannot_read_list', sqlerrm = 'Only Eretz Israel Tours can do that.'); end;
  begin perform public.supplier_form_apply(tg, f1, array['location']); r := r || '{"guide_cannot_apply":false}'; exception when others then r := r || jsonb_build_object('guide_cannot_apply', sqlerrm = 'Only Eretz Israel Tours can do that.'); end;
  begin perform public.supplier_form_discard(tg, f1); r := r || '{"guide_cannot_discard":false}'; exception when others then r := r || jsonb_build_object('guide_cannot_discard', sqlerrm = 'Only Eretz Israel Tours can do that.'); end;
  begin perform public.supplier_form_link(tl, f2, sa); r := r || '{"org_cannot_link":false}'; exception when others then r := r || jsonb_build_object('org_cannot_link', sqlerrm = 'Only Eretz Israel Tours can do that.'); end;
  j := public.supplier_forms_list(ta)::jsonb;
  r := r || jsonb_build_object('list_has_the_answered_forms', (select count(*) from jsonb_array_elements(j->'forms') x where (x->>'id')::uuid in (f1, f2, f3, f4)) = 4,
    'list_leaves_out_unanswered', not exists (select 1 from jsonb_array_elements(j->'forms') x where x->>'business_name' = 'Sample Workshop Probe' and (x->>'id')::uuid not in (f1, f4)));
  select x->'rows' into rows from jsonb_array_elements(j->'forms') x where (x->>'id')::uuid = f1;
  r := r || jsonb_build_object('consent_shown_to_eit', (select bool_and(case (x->>'id')::uuid when f1 then (x->>'consent')::boolean when f2 then not (x->>'consent')::boolean else true end) from jsonb_array_elements(j->'forms') x)
    and exists (select 1 from jsonb_array_elements(j->'forms') x where (x->>'id')::uuid = f2));
  r := r || jsonb_build_object(
    'row_address_beside_the_app', exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'location' and x->>'cur' = 'Old City, Jerusalem' and x->>'new' = '12 Sample St, Jerusalem' and (x->>'tick')::boolean),
    'row_same_phone_not_ticked', exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'phone' and (x->>'same')::boolean and not (x->>'tick')::boolean),
    'row_name_not_ticked', exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'name' and not (x->>'tick')::boolean),
    'row_agent_price_from_supplier', exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'price_agent' and x->>'price' = '80' and x->>'cur' = '₪75' and x->>'new' = E'₪80 · from the supplier\n“₪80 per person”'),
    'row_child_without_number_goes_to_details', not exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'price_child')
      and exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'details' and x->>'new' like '%Child price: no number here%' and x->>'new' like '%Visit length: 1.5 hours%'));

  select x->'rows' into rows from jsonb_array_elements(j->'forms') x where (x->>'id')::uuid = f4;
  r := r || jsonb_build_object('agent_words_never_in_the_note', exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'price_agent' and (x->>'na')::boolean and not (x->>'tick')::boolean)
    and not exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'details' and x->>'new' like '%sample guide rate%'));
  select x->'rows' into rows from jsonb_array_elements(j->'forms') x where (x->>'id')::uuid = f1;

  -- apply, as Eretz Israel Tours
  begin perform public.supplier_form_apply(ta, f1, '{}'); r := r || '{"empty_apply_refused":false}'; exception when others then r := r || jsonb_build_object('empty_apply_refused', sqlerrm = 'Tick at least one line.'); end;
  j := public.supplier_form_apply(ta, f1, array['location','hours','hours_last','shabbat','price_agent','price_adult','details','phone'])::jsonb;
  r := r || jsonb_build_object('applied_count', (j->>'applied')::int = 8 and (j->>'prices')::int = 2,
    'entry_updated', (select location = '12 Sample St, Jerusalem' and hours like 'Sun–Thu 09:00–17:00%' and hours_last = '16:00' from public.vendors where id = sa),
    'hours_unverified_from_form', (select hours_verified_how = '' and hours_source like 'the supplier''s details form, %' from public.vendors where id = sa),
    'shomer_shabbat_tag_added', (select tags = 'Workshop, Shomer Shabbat' from public.vendors where id = sa),
    'untouched_field_kept', (select "agentPrice" = '75' and name = 'Sample Workshop Probe' from public.vendors where id = sa),
    'two_new_price_lines_unconfirmed', (select count(*) = 2 and bool_and(confirmed_at is null and source like 'From the supplier: details form,%') from public.vendor_prices where vendor_id = sa),
    'agent_line_is_agent', (select is_agent and price = '80' and note = 'In their words: ₪80 per person' from public.vendor_prices where vendor_id = sa and audience = 'Adult' and label like 'Rate%'),
    'adult_line_is_public', (select not is_agent and price = '95' and vat = 'including_vat' from public.vendor_prices where vendor_id = sa and label = 'Adult'),
    'details_note_from_eit', (select count(*) = 1 and bool_and(author = 'probe-admin@probe.invalid' and body like 'From the supplier: details form,%' and status = 'approved') from public.vendor_notes where vendor_id = sa),
    'form_marked_applied', (select status = 'applied' and decided_by = 'probe-admin@probe.invalid' and 'price_agent' = any(applied) from public.supplier_forms where id = f1));
  begin perform public.supplier_form_apply(ta, f1, array['location']); r := r || '{"apply_twice_refused":false}'; exception when others then r := r || jsonb_build_object('apply_twice_refused', sqlerrm = 'This form is no longer waiting.'); end;
  -- who sees what was applied: the agent rate never reaches the organisation (C3, D4)
  j := public.vendor_detail(tl, sa)::jsonb; j2 := public.vendor_detail(tg, sa)::jsonb;
  r := r || jsonb_build_object('org_sees_public_line_only', (select count(*) = 1 and bool_and(x->>'label' = 'Adult') from jsonb_array_elements(j->'prices') x)
      and j::text not like '%Rate for licensed%',
    'guide_sees_both_lines', (select count(*) = 2 from jsonb_array_elements(j2->'prices') x),
    'page_shows_no_sender_email', j2::text not like '%probe-guide@%');

  -- the kosher rule holds, and a refusal saves nothing
  begin perform public.supplier_form_apply(ta, f3, array['kosher','phone']); r := r || '{"non_kosher_restaurant_refused":false}'; exception when others then r := r || jsonb_build_object('non_kosher_restaurant_refused', sqlerrm = 'The list does not accept non-kosher restaurants.'); end;
  r := r || jsonb_build_object('refusal_saved_nothing', (select phone = '' and kosher = '' from public.vendors where id = sr) and (select status = 'answered' from public.supplier_forms where id = f3));

  -- a supplier new to the list
  begin perform public.supplier_form_apply(ta, f2, array['price_agent']); r := r || '{"new_supplier_needs_entry":false}'; exception when others then r := r || jsonb_build_object('new_supplier_needs_entry', sqlerrm = 'Create the entry first.'); end;
  select x->'rows' into rows from jsonb_array_elements(public.supplier_forms_list(ta)::jsonb->'forms') x where (x->>'id')::uuid = f2;
  r := r || jsonb_build_object('plain_number_not_repeated', exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'price_agent' and x->>'new' = '₪60 · from the supplier'));
  r := r || jsonb_build_object('new_supplier_rows_against_nothing', exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'kosher' and x->>'cur' = '' and x->>'new' = 'Sample Rabbanut'));
  nv := (public.vendor_save(ta, '{"name":"Sample Winery Probe","category":"Winery","active":"Active","priceBasis":"Per person","currency":"ILS","phone":"050-000-1111"}'::jsonb)::jsonb->'vendor'->>'id');
  perform public.supplier_form_link(ta, f2, nv);
  begin perform public.supplier_form_link(ta, f2, sa); r := r || '{"link_once":false}'; exception when others then r := r || jsonb_build_object('link_once', sqlerrm = 'This form already belongs to an entry.'); end;
  j := public.supplier_form_apply(ta, f2, array['price_agent','kosher'])::jsonb;
  r := r || jsonb_build_object('new_entry_filled', (select kosher = 'Sample Rabbanut' and review_status = 'approved' from public.vendors where id = nv)
      and (select count(*) = 1 and bool_and(is_agent and price = '60') from public.vendor_prices where vendor_id = nv));

  -- an agent rate without a number cannot be applied, even if sent
  begin perform public.supplier_form_apply(ta, f4, array['price_agent']); r := r || '{"agent_words_not_applied":false}'; exception when others then r := r || jsonb_build_object('agent_words_not_applied', sqlerrm = 'Tick at least one line.'); end;
  -- discard
  perform public.supplier_form_discard(ta, f4);
  r := r || jsonb_build_object('discarded_leaves_list', not exists (select 1 from jsonb_array_elements(public.supplier_forms_list(ta)::jsonb->'forms') x where (x->>'id')::uuid = f4)
    and (select status = 'discarded' from public.supplier_forms where id = f4));
  begin perform public.supplier_form_discard(ta, f4); r := r || '{"discard_once":false}'; exception when others then r := r || jsonb_build_object('discard_once', sqlerrm = 'This form is no longer waiting.'); end;

  -- at most 30 links a day per member (the guide has made 2)
  for i in 1..28 loop perform public.supplier_form_new(tg, sa, ''); end loop;
  begin perform public.supplier_form_new(tg, sa, ''); r := r || '{"thirty_a_day":false}'; exception when others then r := r || jsonb_build_object('thirty_a_day', sqlerrm like 'That is 30 forms today%'); end;

  -- the switch goes back off: the guide is refused again
  perform public.set_setting(ta, 'forms_for', 'admin');
  begin perform public.supplier_form_new(tg, sa, ''); r := r || '{"off_again":false}'; exception when others then r := r || jsonb_build_object('off_again', sqlerrm = 'Only Eretz Israel Tours can do that for now.'); end;

  -- the replaced whoami keeps every other field
  j := public.whoami(tl)::jsonb;
  r := r || jsonb_build_object('whoami_unchanged_otherwise', j->>'member_type' = 'limited' and j->>'org' = 'Sample Organisation' and j ? 'bookings' and j ? 'hikes' and j ? 'rentals' and j ? 'wineries' and not (j->>'jobs')::boolean);

  -- real data untouched
  r := r || jsonb_build_object('real_suppliers_untouched', real0 = (select md5(coalesce(string_agg(id || name || coalesce(location,'') || coalesce(hours,'') || coalesce(tags,'') || coalesce(hours_source,''), ',' order by id), '')) from public.vendors where id not in (sa, sr, sh, nv)),
    'real_prices_untouched', realp = (select md5(coalesce(string_agg(id::text || price || source, ',' order by id), '')) from public.vendor_prices where vendor_id not in (sa, sr, sh, nv)),
    'real_notes_untouched', realn = (select md5(coalesce(string_agg(id::text || body, ',' order by id), '')) from public.vendor_notes where vendor_id not in (sa, sr, sh, nv)),
    'real_forms_untouched', fs0 = (select md5(coalesce(string_agg(id::text || status, ',' order by id), '')) from public.supplier_forms where sent_by not like 'probe-%@probe.invalid'));

  for err in select key from jsonb_each(r) where jsonb_typeof(value) <> 'boolean' or value <> 'true'::jsonb loop fails := fails || err; end loop;
  r := r || jsonb_build_object('failed', to_jsonb(fails), 'checks', (select count(*) from jsonb_each(r) where jsonb_typeof(value) = 'boolean'), 'setting_before', set0,
    -- the functions as created here; compare with a clean local build of the same files (supabase/tests/supplier_forms/run.sh prints them)
    'fingerprints', (select string_agg(p.proname || ':' || left(md5(replace(pg_get_functiondef(p.oid), E'\r', '')), 6), ' ' order by p.proname)
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public'
        and p.proname in ('_forms_on','_form_clean','_form_rows','supplier_form_new','supplier_form_open','supplier_form_answer','supplier_forms_list',
          'supplier_form_apply','supplier_form_link','supplier_form_discard','whoami','set_setting')));
  raise exception 'PROBE %', r;
end $probe$;
