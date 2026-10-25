-- D-62 (online links) and D-63 (Hebrew name and contact): probe for the live database (and the local copy). Changes nothing.
-- Inside its own transaction it adds a sample Eretz Israel Tours member, a sample guide, a sample organisation (limited
-- member) and sample suppliers; then it saves, reads and changes them through the real functions as each of them, and
-- ends by raising an error that carries the results, so everything it did is rolled back. All names, links and numbers
-- are invented samples.
-- Run it as one statement (Supabase SQL editor, or the connector's execute_sql) after
-- supabase/migrations/2026-10-25_online_links_hebrew_names.sql. Before that migration is on production, run_probe.py puts
-- the migration in at the line marked @migration, so the probe proves it there and rolls it back with everything else.
-- DO NOT run it on production without the owner's word.
-- Read the JSON after "PROBE": every check must be true, and "failed" must be an empty list.
do $probe$
declare ta text := 'probe-admin-' || md5(random()::text) || md5(random()::text);
  tg text := 'probe-guide-' || md5(random()::text) || md5(random()::text);
  tl text := 'probe-org-' || md5(random()::text) || md5(random()::text);
  r jsonb := '{}'::jsonb; j jsonb; v jsonb; err text; real0 text; reqs0 text; n0 bigint; k text; fid uuid; rows jsonb; bk jsonb; o jsonb;
  sa text; sb text; sc text;
  lk3 text := E'https://www.instagram.com/sample_place\nhttps://www.tripadvisor.com/Attraction_Review-Sample.html\nhttps://maps.app.goo.gl/SamplePin';
  fails text[] := '{}';
begin
  -- @migration
  select md5(coalesce(string_agg(id || name || coalesce(links,'') || coalesce(name_he,'') || coalesce("contactPerson_he",''), ',' order by id), '')) into real0 from public.vendors;
  select md5(coalesce(string_agg(id::text || status, ',' order by id), '')) into reqs0 from public.change_requests;

  insert into public.members (name, email, token_hash, status, is_admin, role) values ('Sample Admin', 'probe-admin@probe.invalid', public._hash(ta), 'approved', true, '');
  insert into public.members (name, email, token_hash, status, role, license_no, phone) values ('Sample Guide', 'probe-guide@probe.invalid', public._hash(tg), 'approved', 'Licensed tour guide', 'LIC-PROBE-62', '0509999962');
  insert into public.members (name, email, token_hash, status, role, member_type, sections, org) values ('Sample Org', 'probe-org@probe.invalid', public._hash(tl), 'approved', 'Other', 'limited', 'transport,sites,food', 'Sample Organisation');

  -- ===== Eretz Israel Tours adds a supplier with links and the Hebrew fields =====
  begin
    j := public.vendor_save(ta, jsonb_build_object('name', 'Sample Olive Press Probe', 'category', 'Activity', 'active', 'Active', 'currency', 'ILS', 'priceBasis', 'Per person',
    'agentPrice', '45', 'listedPrice', '60', 'contactPerson', 'Sample Host', 'phone', '050-000-0062',
    'name_he', 'בית בד לדוגמה', 'contactPerson_he', 'מארח לדוגמה',
    'links', E'instagram.com/sample_place\nhttps://www.tripadvisor.com/Attraction_Review-Sample.html  https://maps.app.goo.gl/SamplePin\nhttps://www.instagram.com/sample_place'), '')::jsonb;
  exception when others then
    -- a link cleaner that let the messy list through would be stopped here by the table's own check: report it, and go on clean
    r := r || jsonb_build_object('first_save_cleans_links', false, 'first_save_error', sqlerrm);
    j := public.vendor_save(ta, jsonb_build_object('name', 'Sample Olive Press Probe', 'category', 'Activity', 'active', 'Active', 'currency', 'ILS', 'priceBasis', 'Per person',
      'agentPrice', '45', 'listedPrice', '60', 'contactPerson', 'Sample Host', 'phone', '050-000-0062', 'name_he', 'בית בד לדוגמה', 'contactPerson_he', 'מארח לדוגמה'), '')::jsonb;
  end;
  sa := j->'vendor'->>'id'; v := j->'vendor';
  r := r || jsonb_build_object('admin_add_round_trip', v->>'name_he' = 'בית בד לדוגמה' and v->>'contactPerson_he' = 'מארח לדוגמה');
  r := r || jsonb_build_object('links_cleaned_https_added_one_per_line',
    v->>'links' = E'https://instagram.com/sample_place\nhttps://www.tripadvisor.com/Attraction_Review-Sample.html\nhttps://maps.app.goo.gl/SamplePin\nhttps://www.instagram.com/sample_place');
  -- (the two Instagram addresses differ by "www.", so both stay; an exact repeat is dropped, below)
  j := public.vendor_save(ta, (select to_jsonb(x) from public.vendors x where x.id = sa) || jsonb_build_object('links', lk3 || E'\n' || 'https://maps.app.goo.gl/SamplePin'), '')::jsonb;
  r := r || jsonb_build_object('exact_repeat_dropped', j->'vendor'->>'links' = lk3);

  -- ===== bad links refused, whoever saves =====
  foreach k in array array['javascript:alert(1)', 'data:text/html,hello', 'ftp://example.com/file', 'not a link', 'https://exa mple.com', 'https://sample.example/<script>', 'mailto:someone@example.com'] loop
    begin perform public.vendor_save(ta, (select to_jsonb(x) from public.vendors x where x.id = sa) || jsonb_build_object('links', k), '');
      fails := fails || ('bad_link_saved: ' || k);
    exception when others then
      if sqlerrm not like 'Only web links can be saved%' and sqlerrm not like 'That link does not look right%' then fails := fails || ('bad_link_wrong_message: ' || k || ' / ' || sqlerrm); end if;
    end;
  end loop;
  r := r || jsonb_build_object('bad_schemes_refused', not exists (select 1 from unnest(fails) f where f like 'bad_link%'));
  fails := '{}';
  begin perform public.vendor_save(ta, (select to_jsonb(x) from public.vendors x where x.id = sa) || jsonb_build_object('links',
      (select string_agg('https://sample' || i || '.example/', E'\n') from generate_series(1, 11) i)), '');
    r := r || '{"eleven_links_refused":false}'; exception when others then r := r || jsonb_build_object('eleven_links_refused', sqlerrm = 'At most 10 online links.'); end;
  begin perform public.vendor_save(ta, (select to_jsonb(x) from public.vendors x where x.id = sa) || jsonb_build_object('links', 'https://sample.example/' || repeat('a', 520)), '');
    r := r || '{"long_link_refused":false}'; exception when others then r := r || jsonb_build_object('long_link_refused', sqlerrm like 'That link does not look right%'); end;
  r := r || jsonb_build_object('links_unchanged_after_refusals', (select x.links from public.vendors x where x.id = sa) = lk3);
  -- the table itself refuses a link that is not http(s), even written directly
  begin update public.vendors set links = 'javascript:alert(1)' where id = sa; r := r || '{"table_check_refuses":false}';
  exception when check_violation then r := r || '{"table_check_refuses":true}'; end;
  begin update public.vendors set name_he = repeat('א', 201) where id = sa; r := r || '{"hebrew_length_capped":false}';
  exception when check_violation then r := r || '{"hebrew_length_capped":true}'; end;
  r := r || jsonb_build_object('helper_strict_and_loose',
    public._links_clean(E'javascript:x\nhttps://ok.example/a\nwww.ok.example/b', false) = E'https://ok.example/a\nhttps://www.ok.example/b');

  -- ===== an older copy of the page sends none of the new keys: what is stored stays =====
  j := public.vendor_save(ta, (select to_jsonb(x) - 'links' - 'name_he' - 'contactPerson_he' from public.vendors x where x.id = sa) || '{"location":"Sample village"}', '')::jsonb;
  r := r || jsonb_build_object('old_page_keeps_new_fields', j->'vendor'->>'links' = lk3 and j->'vendor'->>'name_he' = 'בית בד לדוגמה' and j->'vendor'->>'contactPerson_he' = 'מארח לדוגמה');

  -- ===== a full member (guide) =====
  v := (select x from json_array_elements(public.vendors_list(tg)) x where x->>'id' = sa);
  r := r || jsonb_build_object('guide_list_has_fields', v->>'links' = lk3 and v->>'name_he' = 'בית בד לדוגמה' and v->>'contactPerson_he' = 'מארח לדוגמה');
  -- links are not locked: a guide's change saves straight away
  j := public.vendor_save(tg, v || jsonb_build_object('links', lk3 || E'\nhttps://www.facebook.com/sampleplace'), '')::jsonb;
  r := r || jsonb_build_object('guide_links_save_direct', (j->>'request')::boolean = false and (select x.links from public.vendors x where x.id = sa) = lk3 || E'\nhttps://www.facebook.com/sampleplace');
  begin perform public.vendor_save(tg, v || jsonb_build_object('links', 'javascript:alert(1)'), ''); r := r || '{"guide_bad_link_refused":false}';
  exception when others then r := r || jsonb_build_object('guide_bad_link_refused', sqlerrm like 'Only web links can be saved%'); end;
  -- the Hebrew name is locked like the English name (E3): no reason, refused; with a reason, a change request; nothing changes yet
  v := (select x from json_array_elements(public.vendors_list(tg)) x where x->>'id' = sa);
  begin perform public.vendor_save(tg, v || jsonb_build_object('name_he', 'בית בד אחר'), ''); r := r || '{"guide_hebrew_name_needs_reason":false}';
  exception when others then r := r || jsonb_build_object('guide_hebrew_name_needs_reason', sqlerrm like 'Say briefly why%'); end;
  j := public.vendor_save(tg, v || jsonb_build_object('name_he', 'בית בד אחר', 'contactPerson_he', 'מארח אחר'), 'Sample reason: the sign says so')::jsonb;
  r := r || jsonb_build_object('guide_hebrew_change_is_request', (j->>'request')::boolean
    and (select x.name_he from public.vendors x where x.id = sa) = 'בית בד לדוגמה' and (select x."contactPerson_he" from public.vendors x where x.id = sa) = 'מארח לדוגמה');
  select id into fid from public.change_requests where vendor_id = sa and status = 'pending' order by created_at desc limit 1;
  j := (select x from json_array_elements(public.requests_list(ta)) x where (x->>'id')::uuid = fid);
  r := r || jsonb_build_object('request_shows_both_hebrew_fields', j->'proposed'->>'name_he' = 'בית בד אחר' and j->'proposed'->>'contactPerson_he' = 'מארח אחר'
    and j->'current'->>'name_he' = 'בית בד לדוגמה' and j->'current'->>'contactPerson_he' = 'מארח לדוגמה' and not (j->'proposed' ? 'links'));
  r := r || jsonb_build_object('guide_sees_own_request', exists (select 1 from json_array_elements(public.vendor_detail(tg, sa)->'requests') x where (x->>'id')::uuid = fid));
  if fid is not null then perform public.request_decide(ta, fid, true); end if;
  r := r || jsonb_build_object('approved_request_applies', (select x.name_he from public.vendors x where x.id = sa) = 'בית בד אחר' and (select x."contactPerson_he" from public.vendors x where x.id = sa) = 'מארח אחר');
  -- a guide adding a new supplier: everything saves (a new entry waits for review anyway)
  j := public.vendor_save(tg, jsonb_build_object('name', 'Sample Tractor Probe', 'category', 'Adventure', 'active', 'Active', 'currency', 'ILS', 'priceBasis', 'Per person',
    'name_he', 'טרקטורונים לדוגמה', 'links', 'https://www.facebook.com/sampletractor'), '')::jsonb;
  sb := j->'vendor'->>'id';
  r := r || jsonb_build_object('guide_new_supplier_round_trip', j->'vendor'->>'name_he' = 'טרקטורונים לדוגמה' and j->'vendor'->>'links' = 'https://www.facebook.com/sampletractor'
    and (select review_status from public.vendors where id = sb) = 'pending');

  -- ===== a limited member (organisation) =====
  v := (select x from json_array_elements(public.vendors_list(tl)) x where x->>'id' = sa);
  r := r || jsonb_build_object('org_sees_links_and_hebrew', v->>'links' like lk3 || '%' and v->>'name_he' = 'בית בד אחר' and v->>'contactPerson_he' = 'מארח אחר');
  r := r || jsonb_build_object('org_still_no_agent_price', coalesce(v->>'agentPrice','') = '' and coalesce(v->>'agent_link','') = '' and v->>'listedPrice' = '60');
  j := public.vendor_save(tl, v || jsonb_build_object('links', 'https://www.tiktok.com/@sample_place'), '')::jsonb;
  r := r || jsonb_build_object('org_links_save_direct', (j->>'request')::boolean = false and (select x.links from public.vendors x where x.id = sa) = 'https://www.tiktok.com/@sample_place'
    and (select x."agentPrice" from public.vendors x where x.id = sa) = '45');
  v := (select x from json_array_elements(public.vendors_list(tl)) x where x->>'id' = sa);
  begin perform public.vendor_save(tl, v || jsonb_build_object('name_he', 'שם אחר'), ''); r := r || '{"org_hebrew_name_locked":false}';
  exception when others then r := r || jsonb_build_object('org_hebrew_name_locked', sqlerrm like 'Say briefly why%'); end;
  -- an organisation's page (vendor_detail) still carries no agent price line
  r := r || jsonb_build_object('org_detail_opens', public.vendor_detail(tl, sa)::jsonb ? 'prices');

  -- ===== search of the Hebrew name in the Cockpit door is NOT added (D-57 unchanged); its reader still compiles =====
  r := r || jsonb_build_object('cockpit_reader_compiles', exists (select 1 from pg_proc where proname = 'cockpit_supplier_prices'));

  -- ===== the supplier details form (D-61): links and the Hebrew contact come in as rows to tick =====
  perform public.set_setting(ta, 'forms_for', coalesce((select value from public.app_settings where key = 'forms_for'), 'admin'));
  j := public.supplier_form_new(ta, sa, '')::jsonb; k := j->>'key';
  set local role anon;
  perform public.supplier_form_answer(k, jsonb_build_object('name', 'Sample Olive Press Probe', 'name_he', 'בית בד לדוגמה', 'contact', 'Sample Host', 'contact_he', 'מארח לדוגמה',
    'phone', '050-000-0062', 'links', E'https://www.instagram.com/sample_place\njavascript:alert(1)\nhttps://www.youtube.com/@sampleplace', 'consent', true));
  reset role;
  j := (select x from json_array_elements(public.supplier_forms_list(ta)->'forms') x where x->>'vendor_id' = sa);
  fid := (j->>'id')::uuid; rows := j->'rows';
  r := r || jsonb_build_object('form_rows_have_hebrew_and_links',
    exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'name_he' and x->>'new' = 'בית בד לדוגמה' and x->>'cur' = 'בית בד אחר' and not (x->>'tick')::boolean)
    and exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'contactPerson_he' and x->>'new' = 'מארח לדוגמה' and (x->>'tick')::boolean)
    and exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'links' and x->>'new' = E'https://www.tiktok.com/@sample_place\nhttps://www.instagram.com/sample_place\nhttps://www.youtube.com/@sampleplace'));
  r := r || jsonb_build_object('form_bad_link_dropped', not exists (select 1 from jsonb_array_elements(rows) x where x->>'new' like '%javascript%'));
  begin perform public.supplier_form_apply(ta, fid, array['links', 'contactPerson_he']); exception when others then r := r || jsonb_build_object('form_apply_ran', false, 'form_apply_error', sqlerrm); end;
  r := r || jsonb_build_object('form_apply_writes_links_and_contact',
    (select x.links from public.vendors x where x.id = sa) = E'https://www.tiktok.com/@sample_place\nhttps://www.instagram.com/sample_place\nhttps://www.youtube.com/@sampleplace'
    and (select x."contactPerson_he" from public.vendors x where x.id = sa) = 'מארח לדוגמה' and (select x.name_he from public.vendors x where x.id = sa) = 'בית בד אחר');
  -- an older supplier page that sent the single "social" box still works
  j := public.supplier_form_new(ta, sa, '')::jsonb; k := j->>'key';
  set local role anon;
  perform public.supplier_form_answer(k, '{"name":"Sample Olive Press Probe","contact":"Sample Host","phone":"050-000-0062","social":"@sample_place on Instagram","consent":true}'::jsonb);
  reset role;
  rows := (select x->'rows' from json_array_elements(public.supplier_forms_list(ta)->'forms') x where x->>'vendor_id' = sa and x->>'id' <> fid::text limit 1);
  r := r || jsonb_build_object('form_social_not_a_link_goes_to_note', exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'details' and x->>'new' like '%Online (not a link): @sample_place on Instagram%')
    and not exists (select 1 from jsonb_array_elements(rows) x where x->>'k' = 'links'));

  -- ===== booking sheets (D-5): the company's Hebrew name on its page and on the guide's sheet =====
  j := public.vendor_save(ta, jsonb_build_object('name', 'Sample Buses Probe', 'name_he', 'אוטובוסים לדוגמה', 'category', 'Transport', 'active', 'Active', 'currency', 'ILS', 'priceBasis', 'Per day'), '')::jsonb;
  sc := j->'vendor'->>'id';
  -- (as Eretz Israel Tours, who always has booking sheets, so the check does not depend on the bookings_for setting)
  bk := public.booking_save(ta, sc, '{"date_from":"2026-11-18","service":"bus","booker_name":"Sample","booker_phone":"050-000-0000","pax":"20","client_ref":"sample ref","private_note":"sample private"}'::jsonb)::jsonb;
  o := public.booking_open(bk->>'key')::jsonb;
  r := r || jsonb_build_object('booking_company_hebrew', o->>'company_he' = 'אוטובוסים לדוגמה' and o->>'company' = 'Sample Buses Probe' and not (o ? 'client_ref') and not (o ? 'private_note'));
  r := r || jsonb_build_object('booking_guide_sheet_hebrew', bk->>'vendor_name_he' = 'אוטובוסים לדוגמה');

  -- ===== helpers closed; nothing granted on the table =====
  begin set local role anon; perform public._links_clean('https://a.example', true); reset role; r := r || '{"anon_cannot_call_helper":false}';
  exception when others then reset role; r := r || jsonb_build_object('anon_cannot_call_helper', sqlerrm like 'permission denied%'); end;
  begin set local role authenticated; perform public._links_clean('https://a.example', true); reset role; r := r || '{"auth_cannot_call_helper":false}';
  exception when others then reset role; r := r || jsonb_build_object('auth_cannot_call_helper', sqlerrm like 'permission denied%'); end;
  begin set local role anon; select count(*) into n0 from public.vendors; reset role; r := r || '{"anon_cannot_read_vendors":false}';
  exception when others then reset role; r := r || jsonb_build_object('anon_cannot_read_vendors', sqlerrm like 'permission denied%'); end;
  r := r || jsonb_build_object('no_table_grants', not exists (select 1 from information_schema.role_table_grants where table_schema = 'public' and grantee in ('anon', 'authenticated')),
    'no_policies', not exists (select 1 from pg_policies where schemaname = 'public'));

  -- ===== real data untouched =====
  r := r || jsonb_build_object('real_suppliers_untouched', real0 = (select md5(coalesce(string_agg(id || name || coalesce(links,'') || coalesce(name_he,'') || coalesce("contactPerson_he",''), ',' order by id), '')) from public.vendors where id not in (sa, sb, sc)),
    'real_requests_untouched', reqs0 = (select md5(coalesce(string_agg(id::text || status, ',' order by id), '')) from public.change_requests where vendor_id not in (sa, sb, sc)));

  for err in select key from jsonb_each(r) where jsonb_typeof(value) <> 'boolean' or value <> 'true'::jsonb loop fails := fails || err; end loop;
  r := r || jsonb_build_object('failed', to_jsonb(fails), 'checks', (select count(*) from jsonb_each(r) where jsonb_typeof(value) = 'boolean'),
    -- the functions as created here; compare with a clean local build of the same files (run.sh prints them)
    'fingerprints', (select string_agg(p.proname || ':' || left(md5(replace(pg_get_functiondef(p.oid), E'\r', '')), 6), ' ' order by p.proname)
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public'
        and p.proname in ('_links_clean','_all_fields','_locked_fields','_vendor_apply','vendor_save','_form_clean','_form_rows','_booking_json','booking_open')));
  raise exception 'PROBE %', r;
end $probe$;
