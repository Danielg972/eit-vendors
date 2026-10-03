-- Guide pages for clients, claimed pages, reviews, guide rules (D-12, D-14, D-16): probe for the live database.
-- Changes nothing. It adds four temporary members and two temporary guide pages, calls the app's functions as each
-- member, and ends by raising an error that carries the results, so everything it did is rolled back.
-- Run it as one statement (Supabase SQL editor, or the connector's execute_sql) after ANY change to the functions that
-- send or accept supplier data, together with supabase/tests/limited_members/production_probe.sql.
--
-- What must come back (the text after "PROBE"):
--    1 own=true rate=[] weak=[]                    a member on a page that carries his phone gets no ratings or remarks
--    2 own=false rate=4 weak=PROBE-WEAK agent=1500 another full member still gets them, and the agent price
--    3 refused                                     nobody adds a note to his own page
--    4 bio=Probe bio retail=$600 a day             unclaimed: a full member writes the client section
--    5 refused   5b refused                        an organisation does not write it, and does not claim a page
--    6 agent=[] listed=[] retail=[] rate=[] bio=Probe bio     an organisation, guide rates off: no price of any kind
--    7 pending   8 approved/true   8b approved/true           guide about guide waits; private notes do not
--    9 PROBE agent private;PROBE org review        an agent reads his own private note and the organisation's review
--   10 PROBE org private;PROBE org review          the organisation reads its own two, nothing from guides or agents
--   11 1   12 3                                    one note waits for Eretz Israel Tours; approved, the agent reads three
--   13 pending, 1, match=false, email=false        a claim waits; the list for Eretz Israel Tours carries no email
--   14 refused   15 Owner bio mine=true            claimed: only the claimer writes the client section
--   16 1                                           his dispute arrives marked as the owner's
--   17 refused   18 refused   19 pending           a new guide needs "licensed" or "specialty"; Eshkol needs D1
do $probe$
declare r text := ''; x jsonb; y jsonb; s text := md5(random()::text) || md5(random()::text);
  ta text := 'probe-a-' || s; tg text := 'probe-g-' || s; tc text := 'probe-c-' || s; tl text := 'probe-l-' || s;
  cid uuid; nid uuid;
begin
  insert into public.members (name,email,phone,token_hash,status,is_admin,role,member_type,sections,org) values
   ('Probe Admin','probe-admin@invalid.test','050-0000001',public._hash(ta),'approved',true,'','full','',''),
   ('Probe Guide','probe-guide@invalid.test','059-8765432',public._hash(tg),'approved',false,'Licensed tour guide','full','',''),
   ('Probe Agent','probe-agent@invalid.test','050-0000003',public._hash(tc),'approved',false,'Travel agent','full','',''),
   ('Probe Org','probe-org@invalid.test','050-0000004',public._hash(tl),'approved',false,'Other','limited','transport,guides,hotels','Probe Yeshiva');
  perform set_config('app.admin','on',true); perform set_config('app.editor','probe-admin@invalid.test',true);
  insert into public.vendors (id,name,category,phone,"agentPrice","listedPrice","rateReliability",weaknesses,currency,"priceBasis",active) values
   ('vendor_probe01','Probe Guide Page','Guide','+972 59 876 5432','1500','1800','4','PROBE-WEAK','ILS','Per day','Active'),
   ('vendor_probe02','Probe Other Guide','Guide','02-000-0000','1400','1700','5','PROBE-WEAK2','ILS','Per day','Active');
  x := (select v from jsonb_array_elements(public.vendors_list(tg)::jsonb) v where v->>'id'='vendor_probe01');
  r := r || ' | 1 own=' || (x->>'_own') || ' rate=[' || (x->>'rateReliability') || '] weak=[' || (x->>'weaknesses') || ']';
  x := (select v from jsonb_array_elements(public.vendors_list(tc)::jsonb) v where v->>'id'='vendor_probe01');
  r := r || ' | 2 own=' || (x->>'_own') || ' rate=' || (x->>'rateReliability') || ' weak=' || (x->>'weaknesses') || ' agent=' || (x->>'agentPrice');
  begin perform public.review_post(tg,'vendor_probe01','self praise','',false); r := r || ' | 3 ALLOWED (WRONG)'; exception when others then r := r || ' | 3 refused'; end;
  x := public.vendor_set_client(tc,'vendor_probe02','Probe bio','$600 a day')::jsonb; r := r || ' | 4 bio=' || (x->>'client_bio') || ' retail=' || (x->>'retail_price');
  begin perform public.vendor_set_client(tl,'vendor_probe02','x','y'); r := r || ' | 5 ALLOWED (WRONG)'; exception when others then r := r || ' | 5 refused'; end;
  begin perform public.vendor_claim(tl,'vendor_probe02','ours'); r := r || ' | 5b ALLOWED (WRONG)'; exception when others then r := r || ' | 5b refused'; end;
  x := (select v from jsonb_array_elements(public.vendors_list(tl)::jsonb) v where v->>'id'='vendor_probe02');
  r := r || ' | 6 agent=[' || (x->>'agentPrice') || '] listed=[' || (x->>'listedPrice') || '] retail=[' || (x->>'retail_price') || '] rate=[' || (x->>'rateReliability') || '] bio=' || (x->>'client_bio');
  x := public.review_post(tg,'vendor_probe02','PROBE guide about guide','',false)::jsonb; r := r || ' | 7 ' || (x->>'status');
  x := public.review_post(tc,'vendor_probe02','PROBE agent private','',true)::jsonb; r := r || ' | 8 ' || (x->>'status') || '/' || (x->>'private');
  x := public.review_post(tl,'vendor_probe02','PROBE org private','',true)::jsonb; r := r || ' | 8b ' || (x->>'status') || '/' || (x->>'private');
  perform public.review_add(tl,'vendor_probe02','PROBE org review','5');
  y := public.vendor_detail(tc,'vendor_probe02')::jsonb; r := r || ' | 9 ' || (select string_agg(n->>'body', ';' order by n->>'body') from jsonb_array_elements(y->'notes') n);
  y := public.vendor_detail(tl,'vendor_probe02')::jsonb; r := r || ' | 10 ' || coalesce((select string_agg(n->>'body', ';' order by n->>'body') from jsonb_array_elements(y->'notes') n),'nothing');
  y := public.notes_pending(ta)::jsonb; r := r || ' | 11 ' || (select count(*) from jsonb_array_elements(y) n where n->>'vendor_id'='vendor_probe02')::text;
  select id into nid from public.vendor_notes where body='PROBE guide about guide';
  perform public.note_decide(ta, nid, true);
  y := public.vendor_detail(tc,'vendor_probe02')::jsonb; r := r || ' | 12 ' || jsonb_array_length(y->'notes')::text;
  x := public.vendor_claim(tg,'vendor_probe02','mine too')::jsonb; y := public.claims_list(ta)::jsonb;
  r := r || ' | 13 ' || (x->>'status') || ', ' || (select count(*) from jsonb_array_elements(y) c where c->>'vendor_id'='vendor_probe02')::text || ', match=' || (select c->>'match' from jsonb_array_elements(y) c where c->>'vendor_id'='vendor_probe02') || ', email=' || (y::text ~ 'probe-guide@')::text;
  select id into cid from public.vendor_claims where vendor_id='vendor_probe02';
  perform public.claim_decide(ta, cid, true);
  begin perform public.vendor_set_client(tc,'vendor_probe02','agent again','$1'); r := r || ' | 14 ALLOWED (WRONG)'; exception when others then r := r || ' | 14 refused'; end;
  x := public.vendor_set_client(tg,'vendor_probe02','Owner bio','$700 a day')::jsonb; r := r || ' | 15 ' || (x->>'client_bio') || ' mine=' || (x->>'_mine');
  perform public.vendor_dispute(tg,'vendor_probe02','The listed price is out of date.');
  r := r || ' | 16 ' || (select count(*) from public.vendor_reports where vendor_id='vendor_probe02' and by_owner)::text;
  begin perform public.vendor_save(tc,'{"name":"Probe New Guide","category":"Guide","active":"Active","currency":"ILS","priceBasis":"Per day","tags":"English"}'::jsonb); r := r || ' | 17 ALLOWED (WRONG)'; exception when others then r := r || ' | 17 refused'; end;
  begin perform public.vendor_save(tc,'{"name":"Probe New Guide","category":"Guide","active":"Active","currency":"ILS","priceBasis":"Per day","tags":"Licensed tour guide, Eshkol license"}'::jsonb); r := r || ' | 18 ALLOWED (WRONG)'; exception when others then r := r || ' | 18 refused'; end;
  x := public.vendor_save(tc,'{"name":"Probe New Guide","category":"Guide","active":"Active","currency":"ILS","priceBasis":"Per day","tags":"Licensed tour guide, Eshkol license, D1 license"}'::jsonb)::jsonb; r := r || ' | 19 ' || (x->'vendor'->>'review_status');
  raise exception 'PROBE %', r;
end $probe$;
