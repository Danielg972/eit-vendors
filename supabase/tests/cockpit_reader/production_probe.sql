-- D-57, the confirmed mark and the Cockpit's read-only door: probe for the live database (and the local copy). Changes nothing.
-- Inside its own transaction it adds a sample Eretz Israel Tours member, two sample guides, a sample organisation, sample
-- suppliers and price lines, and mints a SAMPLE reader key; then it calls every function as each of them and ends by
-- raising an error that carries the results, so everything it did is rolled back (the sample key with it).
-- Run it as one statement (Supabase SQL editor, or the connector's execute_sql) after
-- supabase/migrations/2026-10-17_cockpit_reader.sql. Refuses to run if a reader key is already active.
-- Read the JSON after "PROBE": every value must be true, and "failed" must be an empty list.
do $probe$
declare ta text := 'probe-admin-' || md5(random()::text) || md5(random()::text);
  tg text := 'probe-guide-' || md5(random()::text) || md5(random()::text);
  t2 text := 'probe-guide2-' || md5(random()::text) || md5(random()::text);
  tl text := 'probe-org-' || md5(random()::text) || md5(random()::text);
  tr text; r jsonb := '{}'::jsonb; j jsonb; err text; ids jsonb; n0 bigint; n1 bigint; real0 text;
  sa text := 'vendor_prb' || substr(md5(random()::text),1,4); sp text := 'vendor_prc' || substr(md5(random()::text),1,4);
  sx text := 'vendor_prd' || substr(md5(random()::text),1,4);
  l_shared uuid; l_agent uuid; l_eitpriv uuid; l_mempriv uuid; l_mempers uuid; l_org uuid; l_orgpriv uuid; l_pp_eit uuid; l_pp_org uuid; l_x uuid;
  ok boolean; fails text[] := '{}';
begin
  if exists (select 1 from public.cockpit_readers where revoked_at is null) then raise exception 'A reader key is active; this probe would not be able to mint its sample key.'; end if;
  select count(*) into n0 from public.vendor_prices;
  select md5(coalesce(string_agg(id::text || coalesce(archived_at::text,'') || coalesce(confirmed_at::text,''), ',' order by id), '')) into real0 from public.vendor_prices;

  insert into public.members (name, email, token_hash, status, is_admin, role) values ('Sample Admin', 'probe-admin@probe.invalid', public._hash(ta), 'approved', true, '');
  insert into public.members (name, email, token_hash, status, role, license_no, phone) values ('Sample Guide', 'probe-guide@probe.invalid', public._hash(tg), 'approved', 'Licensed tour guide', 'LIC-PROBE-7', '0509999999');
  insert into public.members (name, email, token_hash, status, role, license_no, phone) values ('Sample Guide Two', 'probe-guide2@probe.invalid', public._hash(t2), 'approved', 'Licensed tour guide', '99998', '0509999998');
  insert into public.members (name, email, token_hash, status, role, member_type, sections, org) values ('Sample Org', 'probe-org@probe.invalid', public._hash(tl), 'approved', 'Other', 'limited', 'transport,sites', 'Sample Organisation');

  perform set_config('app.admin', 'on', true); perform set_config('app.editor', 'probe-admin@probe.invalid', true);
  insert into public.vendors (id, name, category, phone, email, region, hours, "cancelPolicy") values
    (sa, 'Sample Bus Company Probe', 'Transport', '0501230000', 'sample-supplier@probe.invalid', 'Jerusalem', 'Sun-Thu 8-17', 'Sample: 48 hours'),
    (sx, 'Sample Never Read Probe', 'Attraction / Site', '', '', 'Jerusalem', '', '');
  insert into public.vendors (id, name, category, prices_private) values (sp, 'Sample Private Prices Probe', 'Attraction / Site', true);
  perform set_config('app.admin', 'off', true);
  -- a mark written directly on insert must not stick
  insert into public.vendor_prices (vendor_id, label, audience, price, is_agent, created_by, confirmed_at, confirmed_by, confirmed_how, kind)
    values (sa, 'Sample shared', 'Vehicle', '1000', false, 'import from sample (17 Oct 2026)', now(), 'Eretz Israel Tours', 'official_list', 'tariff') returning id into l_shared;
  insert into public.vendor_prices (vendor_id, label, audience, price, is_agent) values (sa, 'Sample agent', 'Vehicle', '800', true) returning id into l_agent;
  insert into public.vendor_prices (vendor_id, label, audience, price, private) values (sa, 'Sample EIT private', 'Vehicle', '700', true) returning id into l_eitpriv;
  insert into public.vendor_prices (vendor_id, label, audience, price, private, owner) values (sa, 'Sample member private', 'Vehicle', '650', true, 'probe-guide@probe.invalid') returning id into l_mempriv;
  insert into public.vendor_prices (vendor_id, label, audience, price, private, owner) values (sa, 'Sample member personal', 'Vehicle', '640', false, 'probe-guide@probe.invalid') returning id into l_mempers;
  insert into public.vendor_prices (vendor_id, label, audience, price, is_agent, owner, org) values (sa, 'Sample org rate', 'Vehicle', '900', false, 'probe-org@probe.invalid', true) returning id into l_org;
  insert into public.vendor_prices (vendor_id, label, audience, price, is_agent, owner, org, private) values (sa, 'Sample org private', 'Vehicle', '910', false, 'probe-org@probe.invalid', true, true) returning id into l_orgpriv;
  insert into public.vendor_prices (vendor_id, label, price) values (sp, 'Sample EIT on private supplier', '50') returning id into l_pp_eit;
  insert into public.vendor_prices (vendor_id, label, price, is_agent, owner, org) values (sp, 'Sample org on private supplier', '55', false, 'probe-org@probe.invalid', true) returning id into l_pp_org;
  insert into public.vendor_prices (vendor_id, label, price) values (sx, 'Sample never read', '10') returning id into l_x;

  r := r || jsonb_build_object('insert_mark_ignored', (select confirmed_at is null and confirmed_how = '' and kind = '' from public.vendor_prices where id = l_shared));

  tr := public._cockpit_reader_mint('Sample reader (probe)');
  r := r || jsonb_build_object('key_shape', tr ~ '^icr_[0-9a-f]{64}$', 'key_hashed', not exists (select 1 from public.cockpit_readers where token_hash = tr));
  begin perform public._cockpit_reader_mint('Second'); r := r || '{"one_active_key":false}'; exception when others then r := r || jsonb_build_object('one_active_key', sqlerrm like 'A reader key is already active%'); end;

  -- who can open the door
  begin perform public.cockpit_supplier_prices(tg, sa); r := r || '{"guide_refused":false}'; exception when others then r := r || jsonb_build_object('guide_refused', sqlerrm = 'This reader key is not active.'); end;
  begin perform public.cockpit_supplier_prices(tl, sa); r := r || '{"org_refused":false}'; exception when others then r := r || jsonb_build_object('org_refused', sqlerrm = 'This reader key is not active.'); end;
  begin perform public.cockpit_supplier_prices(ta, sa); r := r || '{"admin_link_refused":false}'; exception when others then r := r || jsonb_build_object('admin_link_refused', sqlerrm = 'This reader key is not active.'); end;
  begin perform public.cockpit_supplier_search(tg, 'Sample'); r := r || '{"guide_search_refused":false}'; exception when others then r := r || jsonb_build_object('guide_search_refused', sqlerrm = 'This reader key is not active.'); end;
  begin perform public.cockpit_supplier_search(tl, 'Sample'); r := r || '{"org_search_refused":false}'; exception when others then r := r || jsonb_build_object('org_search_refused', sqlerrm = 'This reader key is not active.'); end;
  begin perform public.cockpit_supplier_prices('icr_' || repeat('0', 64), sa); r := r || '{"bad_key_refused":false}'; exception when others then r := r || jsonb_build_object('bad_key_refused', sqlerrm = 'This reader key is not active.'); end;
  -- the reader key opens nothing else
  begin perform public.vendors_list(tr); r := r || '{"key_not_a_member_list":false}'; exception when others then r := r || jsonb_build_object('key_not_a_member_list', sqlerrm like 'Your link is not active%'); end;
  begin perform public.vendor_detail(tr, sa); r := r || '{"key_not_a_member_detail":false}'; exception when others then r := r || jsonb_build_object('key_not_a_member_detail', sqlerrm like 'Your link is not active%'); end;
  begin perform public.transport_prices(tr); r := r || '{"key_not_a_member_transport":false}'; exception when others then r := r || jsonb_build_object('key_not_a_member_transport', sqlerrm like 'Your link is not active%'); end;
  begin perform public.price_confirm(tr, l_shared, 'official_list'); r := r || '{"key_cannot_confirm":false}'; exception when others then r := r || jsonb_build_object('key_cannot_confirm', sqlerrm like 'Your link is not active%'); end;
  begin perform public.price_marks(tr, sa); r := r || '{"key_cannot_read_marks":false}'; exception when others then r := r || jsonb_build_object('key_cannot_read_marks', sqlerrm like 'Your link is not active%'); end;
  -- minting and revoking cannot be called from outside
  begin set local role anon; perform public._cockpit_reader_mint('x'); reset role; r := r || '{"anon_cannot_mint":false}'; exception when others then reset role; r := r || jsonb_build_object('anon_cannot_mint', sqlerrm like 'permission denied%'); end;
  begin set local role authenticated; perform public._cockpit_reader_revoke(); reset role; r := r || '{"auth_cannot_revoke":false}'; exception when others then reset role; r := r || jsonb_build_object('auth_cannot_revoke', sqlerrm like 'permission denied%'); end;
  begin set local role service_role; perform public._cockpit_reader_mint('x'); reset role; r := r || '{"service_cannot_mint":false}'; exception when others then reset role; r := r || jsonb_build_object('service_cannot_mint', sqlerrm like 'permission denied%'); end;
  begin set local role anon; perform public._reader_auth(tr); reset role; r := r || '{"anon_cannot_call_reader_auth":false}'; exception when others then reset role; r := r || jsonb_build_object('anon_cannot_call_reader_auth', sqlerrm like 'permission denied%'); end;
  begin set local role anon; select count(*) into n1 from public.cockpit_readers; reset role; r := r || '{"anon_cannot_read_readers":false}'; exception when others then reset role; r := r || jsonb_build_object('anon_cannot_read_readers', sqlerrm like 'permission denied%'); end;
  -- anon (the publishable key, as the Cockpit will call it) reaches the door with the key
  begin set local role anon; j := public.cockpit_supplier_prices(tr, sa)::jsonb; reset role; r := r || '{"anon_with_key_reads":true}'; exception when others then reset role; r := r || jsonb_build_object('anon_with_key_reads', false, 'anon_with_key_error', sqlerrm); end;

  -- what comes back
  j := public.cockpit_supplier_prices(tr, sa)::jsonb;
  select coalesce(jsonb_agg(x->>'id'), '[]'::jsonb) into ids from jsonb_array_elements(j->'lines') x;
  r := r || jsonb_build_object(
    'returns_shared', ids ? l_shared::text, 'returns_agent', ids ? l_agent::text, 'returns_eit_private', ids ? l_eitpriv::text, 'returns_org_rate', ids ? l_org::text,
    'hides_member_private', not ids ? l_mempriv::text, 'hides_member_personal', not ids ? l_mempers::text, 'hides_org_private', not ids ? l_orgpriv::text,
    'no_email_anywhere', position('@' in j::text) = 0, 'no_supplier_phone', position('0501230000' in j::text) = 0,
    'no_member_phone_or_license', position('0509999999' in j::text) = 0 and position('LIC-PROBE' in j::text) = 0,
    'eit_private_marked', (select (x->>'private')::boolean and (x->>'eit_own')::boolean from jsonb_array_elements(j->'lines') x where x->>'id' = l_eitpriv::text),
    'loaded_label', (select x->>'loaded' = 'import from sample (17 Oct 2026)' and not (x->>'confirmed')::boolean from jsonb_array_elements(j->'lines') x where x->>'id' = l_shared::text),
    'per_job_on_transport', (select bool_and((x->>'per_job')::boolean) from jsonb_array_elements(j->'lines') x),
    'hours_and_cancellation', j->'supplier'->>'hours' = 'Sun-Thu 8-17' and j->'supplier'->'cancellation'->>'policy' = 'Sample: 48 hours',
    'behaviour_stated', j->>'behaviour' like 'Read only.%',
    'read_note_left', exists (select 1 from public.cockpit_reads where vendor_id = sa));
  j := public.cockpit_supplier_prices(tr, sp)::jsonb;
  select coalesce(jsonb_agg(x->>'id'), '[]'::jsonb) into ids from jsonb_array_elements(j->'lines') x;
  r := r || jsonb_build_object('private_supplier_eit_line', ids ? l_pp_eit::text, 'private_supplier_hides_org_line', not ids ? l_pp_org::text);
  j := public.cockpit_supplier_prices(tr, 'vendor_nosuch0')::jsonb;
  r := r || jsonb_build_object('gone_supplier', j->>'status' = 'gone' and j->'supplier' = 'null'::jsonb);
  j := public.cockpit_supplier_search(tr, 'sample bus company probe')::jsonb;
  r := r || jsonb_build_object('search_finds', (j->0->>'id') = sa,
    'search_fields_only', (select bool_and((select array_agg(k order by k) from jsonb_object_keys(x) k) = array['category','id','name','region','status']) from jsonb_array_elements(j) x),
    'search_short_text_empty', public.cockpit_supplier_search(tr, 'a')::jsonb = '[]'::jsonb,
    'search_wildcard_literal', public.cockpit_supplier_search(tr, '%%')::jsonb = '[]'::jsonb);

  -- S1: the confirmed mark
  begin perform public.price_confirm(tg, l_agent, 'official_list', 'tariff'); r := r || '{"guide_cannot_confirm":false}'; exception when others then r := r || jsonb_build_object('guide_cannot_confirm', sqlerrm = 'Only Eretz Israel Tours can do that.'); end;
  begin perform public.price_confirm(tl, l_agent, 'official_list', 'tariff'); r := r || '{"org_cannot_confirm":false}'; exception when others then r := r || jsonb_build_object('org_cannot_confirm', sqlerrm = 'Only Eretz Israel Tours can do that.'); end;
  begin perform public.price_confirm(ta, l_agent, 'website', ''); r := r || '{"website_never_counts":false}'; exception when others then r := r || jsonb_build_object('website_never_counts', sqlerrm like 'Say how the price was confirmed%'); end;
  begin perform public.price_confirm(ta, l_agent, 'import', ''); r := r || '{"import_never_counts":false}'; exception when others then r := r || jsonb_build_object('import_never_counts', sqlerrm like 'Say how the price was confirmed%'); end;
  begin perform public.price_marks(tg, sa); r := r || '{"guide_cannot_read_marks":false}'; exception when others then r := r || jsonb_build_object('guide_cannot_read_marks', sqlerrm = 'Only Eretz Israel Tours can do that.'); end;
  j := public.price_confirm(ta, l_agent, 'supplier_document', 'negotiated')::jsonb;
  r := r || jsonb_build_object('admin_confirms', j->>'confirmed_by' = 'Eretz Israel Tours' and j->>'confirmed_how' = 'supplier_document' and j->>'kind' = 'negotiated' and j->>'confirmed_at' is not null,
    'marks_for_admin', (public.price_marks(ta, sa)::jsonb) ? l_agent::text,
    'reader_sees_mark', (select (x->>'confirmed')::boolean and x->>'confirmed_how' = 'supplier_document' from jsonb_array_elements(public.cockpit_supplier_prices(tr, sa)::jsonb->'lines') x where x->>'id' = l_agent::text),
    'members_never_see_mark', position('confirmed' in public.vendor_detail(tg, sa)::text) = 0 and position('negotiated' in public.vendor_detail(tg, sa)::text) = 0,
    'admin_detail_unchanged', position('confirmed' in public.vendor_detail(ta, sa)::text) = 0);
  update public.vendor_prices set confirmed_at = null, confirmed_by = '', confirmed_how = '' where id = l_agent;
  r := r || jsonb_build_object('direct_sql_cannot_unset', (select confirmed_at is not null from public.vendor_prices where id = l_agent));
  update public.vendor_prices set confirmed_at = now(), confirmed_by = 'Eretz Israel Tours', confirmed_how = 'official_list' where id = l_eitpriv;
  r := r || jsonb_build_object('direct_sql_cannot_set', (select confirmed_at is null from public.vendor_prices where id = l_eitpriv));
  update public.vendor_prices set label = 'Sample agent renamed', note = 'Sample note', source = 'Sample source' where id = l_agent;
  r := r || jsonb_build_object('rename_keeps_mark', (select confirmed_at is not null from public.vendor_prices where id = l_agent));
  perform public.price_save(ta, sa, jsonb_build_object('id', l_agent, 'label', 'Sample agent renamed', 'audience', 'Vehicle', 'price', '850', 'is_agent', true, 'source', 'Sample'));
  r := r || jsonb_build_object('price_change_clears_mark', (select confirmed_at is null and confirmed_how = '' and kind = 'negotiated' from public.vendor_prices where id = l_agent));
  perform public.price_confirm(ta, l_agent, 'paid_invoice', 'negotiated'); perform public.price_confirm(ta, l_agent, '', '');
  r := r || jsonb_build_object('admin_can_take_off', (select confirmed_at is null and kind = '' from public.vendor_prices where id = l_agent));

  -- archived, not cascaded
  perform public.price_delete(ta, l_x);
  r := r || jsonb_build_object('unread_supplier_line_deleted', not exists (select 1 from public.vendor_prices where id = l_x));
  perform public.price_delete(ta, l_shared);
  r := r || jsonb_build_object('read_line_archived', (select archived_at is not null from public.vendor_prices where id = l_shared),
    'archived_line_gone_from_app', position(l_shared::text in public.vendor_detail(ta, sa)::text) = 0 and position(l_shared::text in public.transport_prices(ta)::text) = 0,
    'reader_marks_archived_line', (select (x->>'archived')::boolean from jsonb_array_elements(public.cockpit_supplier_prices(tr, sa)::jsonb->'lines') x where x->>'id' = l_shared::text));
  begin perform public.price_confirm(ta, l_shared, 'official_list'); r := r || '{"archived_line_cannot_confirm":false}'; exception when others then r := r || jsonb_build_object('archived_line_cannot_confirm', sqlerrm = 'That price no longer exists.'); end;
  perform public.price_delete(tg, l_mempriv);
  r := r || jsonb_build_object('member_delete_on_read_supplier_archives', (select archived_at is not null from public.vendor_prices where id = l_mempriv),
    'archived_member_line_still_hidden_from_reader', position(l_mempriv::text in public.cockpit_supplier_prices(tr, sa)::text) = 0);
  select count(*) into n1 from public.vendor_prices where vendor_id = sa;
  perform public.vendor_delete(ta, sa);
  r := r || jsonb_build_object('read_supplier_archived', (select archived_at is not null and hidden from public.vendors where id = sa),
    'lines_not_cascaded', (select count(*) from public.vendor_prices where vendor_id = sa) = n1,
    'archived_supplier_off_list', position(sa in public.vendors_list(ta)::text) = 0,
    'reader_says_archived', public.cockpit_supplier_prices(tr, sa)::jsonb->>'status' = 'archived',
    'search_says_archived', public.cockpit_supplier_search(tr, sa)::jsonb->0->>'status' = 'archived');
  perform public.vendor_delete(ta, sx);
  r := r || jsonb_build_object('unread_supplier_deleted', not exists (select 1 from public.vendors where id = sx));

  -- revoking shuts the door
  r := r || jsonb_build_object('revoke_count', public._cockpit_reader_revoke() = 1);
  begin perform public.cockpit_supplier_prices(tr, sp); r := r || '{"revoked_key_refused":false}'; exception when others then r := r || jsonb_build_object('revoked_key_refused', sqlerrm = 'This reader key is not active.'); end;

  -- real data untouched
  r := r || jsonb_build_object('real_lines_untouched', real0 = (select md5(coalesce(string_agg(id::text || coalesce(archived_at::text,'') || coalesce(confirmed_at::text,''), ',' order by id), ''))
      from public.vendor_prices where vendor_id not in (sa, sp, sx)));

  for err in select key from jsonb_each(r) where jsonb_typeof(value) <> 'boolean' or value <> 'true'::jsonb loop
    if err <> 'anon_with_key_error' then fails := fails || err; end if;
  end loop;
  r := r || jsonb_build_object('failed', to_jsonb(fails), 'checks', (select count(*) from jsonb_each(r) where jsonb_typeof(value) = 'boolean'));
  raise exception 'PROBE %', r;
end $probe$;
