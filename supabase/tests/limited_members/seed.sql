\set ON_ERROR_STOP 1
\set A 'ADMINTOKEN0000000000000000'
\set F 'FULLTOKEN00000000000000000'
insert into public.members (name,email,token_hash,status,is_admin,role) values ('Eretz Israel Tours','owner@test.il', public._hash(:'A'), 'approved', true, '');
insert into public.members (name,email,token_hash,status,role,license_no,phone) values ('Fay Full','fay@test.il', public._hash(:'F'),'approved','Licensed tour guide','111','0521112233');
insert into public.app_settings(key,value) values ('bookings_for','all'),('jobs_for','all') on conflict (key) do update set value=excluded.value;
create table if not exists public.__ids (k text primary key, id text);
create or replace function public.__v(p jsonb) returns text language sql as $$ select (public.vendor_save('ADMINTOKEN0000000000000000', '{"active":"Active","currency":"ILS","priceBasis":"Per person"}'::jsonb || p))->'vendor'->>'id' $$;
insert into public.__ids values
 ('T', public.__v('{"name":"Test Bus Co","category":"Transport","agentPrice":"2400","priceBasis":"Per day","rateReliability":"4","strengths":"On time","notes":"bus summary","phone":"054-000-1111","agent_link":"https://bus.example/agents","agent_howto":"Register as agent"}')),
 ('G', public.__v('{"name":"Gila Guide","category":"Guide","agentPrice":"1600","listedPrice":"2000","priceBasis":"Per day","rateService":"5","notes":"guide summary"}')),
 ('H', public.__v('{"name":"Test Hotel","category":"Hotel","agentPrice":"1150","listedPrice":"1400","rateValue":"3","weaknesses":"Slow check-in","notes":"Agents get 10% commission","agent_howto":"Ask the group desk for the agent rate"}')),
 ('S', public.__v('{"name":"Test Reserve","category":"National Parks","agentPrice":"29","listedPrice":"33"}')),
 ('R', public.__v('{"name":"Test Grill","category":"Restaurant","kosher":"Rabbanut"}')),
 ('W', public.__v('{"name":"Test Winery","category":"Winery","listedPrice":"90"}')),
 ('A', public.__v('{"name":"Test Travel Agent","category":"Travel Agent","agentPrice":"5"}')),
 ('GA', public.__v('{"name":"Jeep Guide","category":"Adventure","also_categories":"Guide","agentPrice":"900","listedPrice":"1200"}')),
 ('X', public.__v('{"name":"Hidden Site","category":"Attraction / Site","listedPrice":"10"}')),
 ('P', public.__v('{"name":"Private Price Site","category":"Activity","listedPrice":"50","agentPrice":"40"}'));
update public.vendors set hidden = true where id = (select id from public.__ids where k='X');
update public.vendors set prices_private = true where id = (select id from public.__ids where k='P');
create or replace function public.__id(p text) returns text language sql as $$ select id from public.__ids where k = p $$;
-- price lines by admin
select public.price_save(:'A', public.__id('S'), '{"label":"Adult","price":"33","is_agent":false,"basis":"Per person"}');
select public.price_save(:'A', public.__id('S'), '{"label":"Adult agent","price":"29","is_agent":true,"basis":"Per person"}');
select public.price_save(:'A', public.__id('H'), '{"label":"Room agent","price":"1150","is_agent":true,"basis":"Per group"}');
select public.price_save(:'A', public.__id('H'), '{"label":"Room rack","price":"1400","is_agent":false,"basis":"Per group"}');
select public.price_save(:'A', public.__id('G'), '{"label":"Guiding day public","price":"2000","is_agent":false,"basis":"Per day"}');
select public.price_save(:'A', public.__id('P'), '{"label":"Private public","price":"50","is_agent":false}');
-- Fay's personal line on the hotel
select public.price_save(:'F', public.__id('H'), '{"label":"Fay own","price":"1100","is_agent":true,"mine":true}');
-- notes
select public.note_add(:'F', public.__id('H'), 'Fay: breakfast is weak, ask for the agent desk');
insert into public.vendor_notes (vendor_id, body, author, author_name) values (public.__id('S'), 'From their website, 2 Oct 2026 (unverified): 2 hours', 'import from websites (2 Oct 2026)', '');
-- quotes by Fay
select public.quote_save(:'F', public.__id('T'), '{"date_from":"2026-11-10","date_to":"2026-11-11","options":[{"name":"50-seat bus","service":"bus","lines":[{"label":"Bus","kind":"Base","price":"3500","unit":"per vehicle per day"}]}]}');
select public.quote_save(:'F', public.__id('H'), '{"date_from":"2026-11-10","date_to":"2026-11-12","title":"Cohen family","options":[{"name":"Rooms","service":"hotel_room","lines":[{"label":"Double","kind":"Base","price":"900","unit":"per room per night"}]}]}');
select public.quote_save(:'F', public.__id('G'), '{"date_from":"2026-11-10","options":[{"name":"Guide day","service":"guide","lines":[{"label":"Day","kind":"Base","price":"1700","unit":"per day"}]}]}');
select public.quote_save(:'F', public.__id('S'), '{"date_from":"2026-11-10","shared":false,"options":[{"name":"Group","service":"site","lines":[{"label":"Group","kind":"Base","price":"25","unit":"per person"}]}]}');
-- a driver and a review by Fay
select public.driver_save(:'F', public.__id('T'), '{"name":"Dudu Driver","phone":"050-123-4567","drives":"Bus"}') as did \gset
insert into public.__ids values ('D', :'did');
select public.driver_review_add(:'F', :'did'::uuid, public.__id('T'), '{"rating":"4","tags":"On time","body":"Good"}');
-- a file row on the hotel (price list) and a photo on the reserve
insert into public.vendor_files (vendor_id, path, file_name, kind, uploaded_by) values (public.__id('H'),'h/pl.pdf','pl.pdf','Price list','fay@test.il'), (public.__id('S'),'s/ph.jpg','ph.jpg','Photo','fay@test.il');
