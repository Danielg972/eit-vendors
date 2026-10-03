-- Limited members (D-15): probe for the live database. Changes nothing.
-- It adds a temporary organisation and a temporary guide, calls the app's functions as each of them, and ends by
-- raising an error that carries the results, so everything it did is rolled back. Read the JSON after "PROBE".
-- Run it as one statement (Supabase SQL editor, or the connector's execute_sql) after ANY change to the functions
-- listed in docs/HANDOFF_guide-for-clients.md, section 3.
--
-- What must come back:
--   limited_sees = limited_expected (and less than full_sees while a supplier outside the sections exists)
--   limited_with_agent_price = 0          limited_guides_with_price = 0
--   limited_nontransport_with_ratings = 0 limited_emails_in_list = 0
--   details_with_agent_or_owner_or_email_in_prices = 0   limited_tracker_owner_leaks = 0
--   full_with_agent_price > 0             (a guide still gets agent prices)
--   other_section_detail, other_section_price = "That supplier is not available."
--   org_rate_save = {"org":true,"mine":true,"request":false}
--   org_rate_as_full: is_agent false, org true, owner "", by.name "an organisation"
--   org_review_as_full: org true, author = the probe's name; org_review_by.role = the organisation's name
--   set_agent refused; members_list and self_upgrade = "Only Eretz Israel Tours can do that."
--   whoami_limited: member_type limited, jobs false, jobs_post false, role "Organisation, not in tourism"
--   jobs_list_limited: every list empty
do $probe$
declare tl text := 'probe-limited-' || md5(random()::text) || md5(random()::text);
  tf text := 'probe-full-' || md5(random()::text) || md5(random()::text);
  lid uuid; r jsonb := '{}'::jsonb; vl jsonb; vf jsonb; w jsonb; d jsonb; x record; err text; hid text; oid_ text; n int;
begin
  insert into public.members (name,email,role,token_hash,status,member_type,sections,org,credentials)
  values ('Probe Org','probe-limited@invalid.test','Other',public._hash(tl),'approved','limited','transport,guides,hotels,sites,food','Probe Yeshiva','probe probe probe probe probe') returning id into lid;
  insert into public.members (name,email,role,token_hash,status) values ('Probe Guide','probe-full@invalid.test','Licensed tour guide',public._hash(tf),'approved');

  w := public.whoami(tl)::jsonb;
  r := r || jsonb_build_object('whoami_limited', w - 'email' - 'bcc_email');
  vl := public.vendors_list(tl)::jsonb; vf := public.vendors_list(tf)::jsonb;
  r := r || jsonb_build_object('limited_sees', jsonb_array_length(vl), 'full_sees', jsonb_array_length(vf),
    'visible_total', (select count(*) from public.vendors where not hidden),
    'limited_expected', (select count(*) from public.vendors v where not hidden and exists (select 1 from unnest(array[v.category] || string_to_array(coalesce(v.also_categories,''), ',')) c where trim(c) <> '' and public._section_of(trim(c)) in ('transport','guides','hotels','sites','food'))),
    'limited_with_agent_price', (select count(*) from jsonb_array_elements(vl) e where coalesce(e->>'agentPrice','') <> '' or coalesce(e->>'agent_link','') <> '' or coalesce(e->>'agent_howto','') <> '' or coalesce(e->>'agentPriceVatTreatment','') <> ''),
    'full_with_agent_price', (select count(*) from jsonb_array_elements(vf) e where coalesce(e->>'agentPrice','') <> '' or coalesce(e->>'agent_link','') <> ''),
    'limited_guides_with_price', (select count(*) from jsonb_array_elements(vl) e where e->>'category' = 'Guide' and (coalesce(e->>'listedPrice','') <> '' or (e->>'_prices')::int > 0)),
    'limited_nontransport_with_ratings', (select count(*) from jsonb_array_elements(vl) e where e->>'category' <> 'Transport' and coalesce(e->>'also_categories','') !~* 'Transport' and (coalesce(e->>'rateValue','') <> '' or coalesce(e->>'strengths','') <> '' or coalesce(e->>'weaknesses','') <> '' or coalesce(e->>'notes','') <> '')),
    'limited_emails_in_list', (select count(*) from jsonb_array_elements(vl) e where coalesce(e->>'created_by','') like '%@%' or coalesce(e->>'updated_by','') like '%@%'),
    'limited_categories', (select jsonb_agg(distinct e->>'category') from jsonb_array_elements(vl) e));

  -- every supplier a limited member can open: no agent line, no other member's personal line, no email
  n := 0;
  for x in select v.id from public.vendors v where not v.hidden and public._can_see((select m from public.members m where m.id = lid), v.category, v.also_categories) loop
    d := public.vendor_detail(tl, x.id)::jsonb;
    if exists (select 1 from jsonb_array_elements(d->'prices') p where (p->>'is_agent')::boolean or (coalesce(p->>'owner','') <> ''))
       or exists (select 1 from jsonb_array_elements(d->'prices') p where p::text ~ '[a-z0-9._-]+@[a-z0-9.-]+\.[a-z]{2,}') then n := n + 1; end if;
  end loop;
  r := r || jsonb_build_object('details_with_agent_or_owner_or_email_in_prices', n);
  r := r || jsonb_build_object('agent_lines_on_production', (select count(*) from public.vendor_prices where is_agent),
    'limited_tracker_quotes', jsonb_array_length(public.quotes_tracker(tl)::jsonb), 'full_tracker_quotes', jsonb_array_length(public.quotes_tracker(tf)::jsonb),
    'limited_tracker_owner_leaks', (select count(*) from jsonb_array_elements(public.quotes_tracker(tl)::jsonb) q where coalesce(q->>'owner','') <> '' or coalesce(q->>'owner_name','') <> ''));

  -- a supplier outside the sections is refused
  select v.id into oid_ from public.vendors v where not v.hidden and public._section_of(v.category) = 'other' and coalesce(v.also_categories,'') = '' limit 1;
  if oid_ is not null then
    begin perform public.vendor_detail(tl, oid_); r := r || jsonb_build_object('other_section_detail', 'OPENED (WRONG)');
    exception when others then get stacked diagnostics err = message_text; r := r || jsonb_build_object('other_section_detail', err); end;
    begin perform public.price_save(tl, oid_, '{"label":"x","price":"1"}'::jsonb, 'probe'); r := r || jsonb_build_object('other_section_price', 'SAVED (WRONG)');
    exception when others then get stacked diagnostics err = message_text; r := r || jsonb_build_object('other_section_price', err); end;
  end if;
  -- an organisation rate on a hotel: saved, not an agent rate, seen by the guide without the name
  select v.id into hid from public.vendors v where not v.hidden and v.category = 'Hotel' and not v.prices_private limit 1;
  d := public.price_save(tl, hid, '{"label":"Probe group rate","price":"777","is_agent":true}'::jsonb, '')::jsonb;
  r := r || jsonb_build_object('org_rate_save', d,
    'org_rate_as_full', (select jsonb_build_object('is_agent',p->'is_agent','org',p->'org','owner',p->'owner','by',p->'by') from jsonb_array_elements(public.vendor_detail(tf, hid)::jsonb->'prices') p where p->>'label' = 'Probe group rate'));
  perform public.review_add(tl, hid, 'Probe review', '4');
  r := r || jsonb_build_object('org_review_as_full', (select jsonb_build_object('rating',nn->'rating','org',nn->'org','author',nn->'author') from jsonb_array_elements(public.vendor_detail(tf, hid)::jsonb->'notes') nn where nn->>'body' = 'Probe review'),
    'org_review_by', (select public.vendor_detail(tf, hid)::jsonb->'note_by'->(nn->>'id') from jsonb_array_elements(public.vendor_detail(tf, hid)::jsonb->'notes') nn where nn->>'body' = 'Probe review'));
  begin perform public.vendor_set_agent(tl, hid, 'example.com', 'x'); r := r || jsonb_build_object('set_agent', 'SAVED (WRONG)');
  exception when others then get stacked diagnostics err = message_text; r := r || jsonb_build_object('set_agent', err); end;
  begin perform public.members_list(tl); r := r || jsonb_build_object('members_list', 'OPENED (WRONG)');
  exception when others then get stacked diagnostics err = message_text; r := r || jsonb_build_object('members_list', err); end;
  begin perform public.member_set_access(tl, lid, '{"member_type":"full"}'::jsonb); r := r || jsonb_build_object('self_upgrade', 'DONE (WRONG)');
  exception when others then get stacked diagnostics err = message_text; r := r || jsonb_build_object('self_upgrade', err); end;
  r := r || jsonb_build_object('jobs_list_limited', public.jobs_list(tl)::jsonb);
  raise exception 'PROBE %', r::text;
end $probe$;
