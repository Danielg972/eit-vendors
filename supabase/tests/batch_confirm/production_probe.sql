-- D-60, batch confirm with a review step, skip and undo: probe for the live database (and the local copy). Changes nothing.
-- Inside its own transaction it adds a sample Eretz Israel Tours member, a sample guide, a sample organisation, two sample
-- suppliers and their price lines; then it calls price_confirm_batch and price_confirm_batch_undo as each of them and ends
-- by raising an error that carries the results, so everything it did is rolled back.
-- Run it as one statement (Supabase SQL editor, or the connector's execute_sql) after
-- supabase/migrations/2026-10-18b_batch_confirm.sql. Before that migration is on production, run_probe.py puts the
-- migration in at the line marked @migration, so the probe proves it on production and rolls it back with everything else.
-- Read the JSON after "PROBE": every value must be true, and "failed" must be an empty list.
do $probe$
declare ta text := 'probe-admin-' || md5(random()::text) || md5(random()::text);
  tg text := 'probe-guide-' || md5(random()::text) || md5(random()::text);
  tl text := 'probe-org-' || md5(random()::text) || md5(random()::text);
  r jsonb := '{}'::jsonb; j jsonb; j2 jsonb; err text; real0 text; b0 bigint; t3 timestamptz;
  sa text := 'vendor_pbb' || substr(md5(random()::text),1,4); so text := 'vendor_pbo' || substr(md5(random()::text),1,4);
  l1 uuid; l2 uuid; l3 uuid; l4 uuid; l5 uuid; l6 uuid; lx uuid; bid uuid;
  fails text[] := '{}';
begin
  -- @migration
  select md5(coalesce(string_agg(id::text || coalesce(confirmed_at::text,'') || confirmed_how || kind || price, ',' order by id), '')) into real0 from public.vendor_prices;
  select count(*) into b0 from public.price_confirm_batches;

  insert into public.members (name, email, token_hash, status, is_admin, role) values ('Sample Admin', 'probe-admin@probe.invalid', public._hash(ta), 'approved', true, '');
  insert into public.members (name, email, token_hash, status, role, license_no, phone) values ('Sample Guide', 'probe-guide@probe.invalid', public._hash(tg), 'approved', 'Licensed tour guide', 'LIC-PROBE-8', '0509999997');
  insert into public.members (name, email, token_hash, status, role, member_type, sections, org) values ('Sample Org', 'probe-org@probe.invalid', public._hash(tl), 'approved', 'Other', 'limited', 'transport,sites', 'Sample Organisation');
  perform set_config('app.admin', 'on', true); perform set_config('app.editor', 'probe-admin@probe.invalid', true);
  insert into public.vendors (id, name, category, region) values (sa, 'Sample Heritage Site Probe', 'Attraction / Site', 'Jerusalem'), (so, 'Sample Other Site Probe', 'Attraction / Site', 'Jerusalem');
  perform set_config('app.admin', 'off', true);
  insert into public.vendor_prices (vendor_id, label, audience, price) values (sa, 'Sample adult', 'Adult', '29') returning id into l1;
  insert into public.vendor_prices (vendor_id, label, audience, price) values (sa, 'Sample child', 'Child', '15') returning id into l2;
  insert into public.vendor_prices (vendor_id, label, audience, price) values (sa, 'Sample senior', 'Senior', '14') returning id into l3;
  insert into public.vendor_prices (vendor_id, label, audience, price) values (sa, 'Sample group', 'Other', '25') returning id into l4;
  insert into public.vendor_prices (vendor_id, label, audience, price, is_agent) values (sa, 'Sample agent adult', 'Adult', '24', true) returning id into l5;
  insert into public.vendor_prices (vendor_id, label, audience, price) values (sa, 'Sample tunnel', 'Adult', '10') returning id into l6;
  insert into public.vendor_prices (vendor_id, label, audience, price) values (so, 'Sample elsewhere', 'Adult', '40') returning id into lx;
  -- before: l2 carries a kind without a mark (a changed price keeps its kind); l3 is already confirmed, a day ago
  perform set_config('app.confirm', 'on', true);
  update public.vendor_prices set kind = 'negotiated' where id in (l2, l6);
  update public.vendor_prices set confirmed_at = now() - interval '1 day', confirmed_by = 'Eretz Israel Tours', confirmed_how = 'paid_invoice', kind = 'negotiated' where id = l3;
  perform set_config('app.confirm', 'off', true);
  select confirmed_at into t3 from public.vendor_prices where id = l3;

  -- who may batch confirm and undo
  begin perform public.price_confirm_batch(tg, sa, array[l1], 'official_list', 'tariff'); r := r || '{"guide_refused":false}'; exception when others then r := r || jsonb_build_object('guide_refused', sqlerrm = 'Only Eretz Israel Tours can do that.'); end;
  begin perform public.price_confirm_batch(tl, sa, array[l1], 'official_list', 'tariff'); r := r || '{"org_refused":false}'; exception when others then r := r || jsonb_build_object('org_refused', sqlerrm = 'Only Eretz Israel Tours can do that.'); end;
  begin perform public.price_confirm_batch('no-such-link', sa, array[l1], 'official_list', 'tariff'); r := r || '{"bad_link_refused":false}'; exception when others then r := r || jsonb_build_object('bad_link_refused', sqlerrm like 'Your link is not active%'); end;
  begin set local role anon; select count(*) into b0 from public.price_confirm_batches; reset role; r := r || '{"anon_cannot_read_batches":false}'; exception when others then reset role; r := r || jsonb_build_object('anon_cannot_read_batches', sqlerrm like 'permission denied%'); end;
  begin set local role authenticated; select count(*) into b0 from public.price_confirm_batches; reset role; r := r || '{"auth_cannot_read_batches":false}'; exception when others then reset role; r := r || jsonb_build_object('auth_cannot_read_batches', sqlerrm like 'permission denied%'); end;
  select count(*) into b0 from public.price_confirm_batches;
  -- what is refused, with nothing saved
  begin perform public.price_confirm_batch(ta, sa, array[l1], '', 'tariff'); r := r || '{"way_required":false}'; exception when others then r := r || jsonb_build_object('way_required', sqlerrm like 'Say how the prices were confirmed%'); end;
  begin perform public.price_confirm_batch(ta, sa, array[l1], 'website', ''); r := r || '{"website_never_counts":false}'; exception when others then r := r || jsonb_build_object('website_never_counts', sqlerrm like 'Say how the prices were confirmed%'); end;
  begin perform public.price_confirm_batch(ta, sa, array[l1], 'official_list', 'cheap'); r := r || '{"kind_checked":false}'; exception when others then r := r || jsonb_build_object('kind_checked', sqlerrm = 'A price is a tariff or negotiated.'); end;
  begin perform public.price_confirm_batch(ta, sa, '{}'::uuid[], 'official_list', ''); r := r || '{"empty_refused":false}'; exception when others then r := r || jsonb_build_object('empty_refused', sqlerrm = 'Tick at least one price.'); end;
  begin perform public.price_confirm_batch(ta, sa, array[l1, l2, lx], 'official_list', 'tariff'); r := r || '{"other_supplier_refused":false}'; exception when others then r := r || jsonb_build_object('other_supplier_refused', sqlerrm like '1 of the ticked prices no longer belong to this supplier. Nothing was confirmed.%'); end;
  r := r || jsonb_build_object('refusal_saved_nothing', (select bool_and(confirmed_at is null) from public.vendor_prices where id in (l1, l2, lx)) and (select count(*) from public.price_confirm_batches) = b0);

  -- the batch: l1, l2, l3 (already confirmed), l4, l5, a duplicate of l1; one way, Tariff
  j := public.price_confirm_batch(ta, sa, array[l1, l2, l3, l4, l5, l1], 'official_list', 'tariff')::jsonb;
  bid := (j->>'batch')::uuid;
  r := r || jsonb_build_object(
    'counts', jsonb_array_length(j->'confirmed') = 4 and jsonb_array_length(j->'skipped') = 1,
    'skipped_is_l3', j->'skipped' = jsonb_build_array(l3),
    'each_line_own_record', (select bool_and(confirmed_at = (j->>'confirmed_at')::timestamptz and confirmed_by = 'Eretz Israel Tours' and confirmed_how = 'official_list' and kind = 'tariff')
       from public.vendor_prices where id in (l1, l2, l4, l5)),
    'already_confirmed_untouched', (select confirmed_at = t3 and confirmed_how = 'paid_invoice' and kind = 'negotiated' from public.vendor_prices where id = l3),
    'unticked_untouched', (select confirmed_at is null and kind = 'negotiated' from public.vendor_prices where id = l6),
    'batch_recorded', (select vendor_id = sa and confirmed_how = 'official_list' and kind = 'tariff' and jsonb_array_length(lines) = 4 and undone_at is null
       and (select kind_before from jsonb_to_recordset(lines) x(id uuid, kind_before text) where x.id = l2) = 'negotiated' from public.price_confirm_batches where id = bid),
    'admin_marks_show_it', (public.price_marks(ta, sa)::jsonb->l1::text->>'confirmed_how') = 'official_list',
    'members_never_see_mark', position('confirmed' in public.vendor_detail(tg, sa)::text) = 0 and position('tariff' in public.vendor_detail(tg, sa)::text) = 0
       and position('confirmed' in public.vendor_detail(tl, sa)::text) = 0);
  -- everything ticked already confirmed: nothing to do, no batch
  j2 := public.price_confirm_batch(ta, sa, array[l1, l3], 'paid_invoice', 'negotiated')::jsonb;
  r := r || jsonb_build_object('all_confirmed_no_batch', j2->'batch' = 'null'::jsonb and jsonb_array_length(j2->'confirmed') = 0 and jsonb_array_length(j2->'skipped') = 2
    and (select confirmed_how = 'official_list' and kind = 'tariff' from public.vendor_prices where id = l1));
  -- no kind chosen: each line keeps the kind it had
  j2 := public.price_confirm_batch(ta, sa, array[l6], 'supplier_conversation', '')::jsonb;
  r := r || jsonb_build_object('no_kind_keeps_kind', (select confirmed_how = 'supplier_conversation' and kind = 'negotiated' from public.vendor_prices where id = l6));

  -- after the batch, l4's price changes (its mark comes off by itself) and l5 is confirmed again on its own
  perform public.price_save(ta, sa, jsonb_build_object('id', l4, 'label', 'Sample group', 'audience', 'Other', 'price', '26', 'source', 'Sample'));
  perform set_config('app.confirm', 'on', true);
  update public.vendor_prices set confirmed_at = now() + interval '1 second', confirmed_how = 'paid_invoice' where id = l5;
  perform set_config('app.confirm', 'off', true);

  -- the undo
  begin perform public.price_confirm_batch_undo(tg, bid); r := r || '{"guide_cannot_undo":false}'; exception when others then r := r || jsonb_build_object('guide_cannot_undo', sqlerrm = 'Only Eretz Israel Tours can do that.'); end;
  begin perform public.price_confirm_batch_undo(ta, gen_random_uuid()); r := r || '{"unknown_batch_refused":false}'; exception when others then r := r || jsonb_build_object('unknown_batch_refused', sqlerrm = 'That batch is not known.'); end;
  j := public.price_confirm_batch_undo(ta, bid)::jsonb;
  r := r || jsonb_build_object(
    'undo_clears_batch_lines', (select bool_and(confirmed_at is null and confirmed_by = '' and confirmed_how = '') from public.vendor_prices where id in (l1, l2)),
    'undo_puts_kind_back', (select kind from public.vendor_prices where id = l1) = '' and (select kind from public.vendor_prices where id = l2) = 'negotiated',
    'undo_names_cleared', j->'cleared' @> jsonb_build_array(l1, l2) and jsonb_array_length(j->'cleared') = 2,
    'undo_leaves_changed_lines', j->'left' @> jsonb_build_array(l4, l5) and jsonb_array_length(j->'left') = 2,
    'undo_keeps_later_confirm', (select confirmed_how = 'paid_invoice' and confirmed_at is not null from public.vendor_prices where id = l5),
    'undo_keeps_skipped', (select confirmed_at = t3 and confirmed_how = 'paid_invoice' from public.vendor_prices where id = l3),
    'undo_keeps_other_batch', (select confirmed_how = 'supplier_conversation' from public.vendor_prices where id = l6),
    'undo_recorded', (select undone_at is not null and undone_by = 'Eretz Israel Tours' and jsonb_array_length(undone_lines) = 2 from public.price_confirm_batches where id = bid));
  begin perform public.price_confirm_batch_undo(ta, bid); r := r || '{"undo_once":false}'; exception when others then r := r || jsonb_build_object('undo_once', sqlerrm = 'That batch was already undone.'); end;

  -- the single confirm and direct writes still behave as before
  perform public.price_confirm(ta, l1, 'paid_invoice', 'negotiated');
  r := r || jsonb_build_object('single_confirm_unchanged', (select confirmed_how = 'paid_invoice' and kind = 'negotiated' from public.vendor_prices where id = l1));
  update public.vendor_prices set confirmed_at = now(), confirmed_by = 'Eretz Israel Tours', confirmed_how = 'official_list' where id = l2;
  r := r || jsonb_build_object('direct_sql_cannot_set', (select confirmed_at is null from public.vendor_prices where id = l2));

  -- real data untouched
  r := r || jsonb_build_object('real_lines_untouched', real0 = (select md5(coalesce(string_agg(id::text || coalesce(confirmed_at::text,'') || confirmed_how || kind || price, ',' order by id), ''))
      from public.vendor_prices where vendor_id not in (sa, so)));

  for err in select key from jsonb_each(r) where jsonb_typeof(value) <> 'boolean' or value <> 'true'::jsonb loop fails := fails || err; end loop;
  r := r || jsonb_build_object('failed', to_jsonb(fails), 'checks', (select count(*) from jsonb_each(r) where jsonb_typeof(value) = 'boolean'));
  raise exception 'PROBE %', r;
end $probe$;
