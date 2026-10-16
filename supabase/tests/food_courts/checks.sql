-- D-55 checks on a local copy (after ../limited_members seed.sql and the migration). Prints FAIL lines and a total.
\set ON_ERROR_STOP 0
\set A 'ADMINTOKEN0000000000000000'
\set F 'FULLTOKEN00000000000000000'
\set G 'GUIDETWO000000000000000000'
\set O 'ORGTOKEN000000000000000000'
insert into public.members (name,email,token_hash,status,role) values ('Gal Second','gal@test.il', public._hash(:'G'),'approved','Licensed tour guide') on conflict do nothing;
insert into public.members (name,email,token_hash,status,role,member_type,sections,org) values ('Sample Yeshiva','org@test.il', public._hash(:'O'),'approved','Other','limited','transport,sites','Sample Yeshiva') on conflict do nothing;
create temp table res (n serial, ok boolean, what text);
create or replace function pg_temp.t(ok boolean, what text) returns void language sql as $$ insert into res(ok,what) values (coalesce(ok,false), what) $$;
create or replace function pg_temp.err(q text) returns text language plpgsql as $$ begin execute q; return ''; exception when others then return sqlerrm; end $$;

-- a food court supplier added by Fay, then her tip on the reserve pointing at it
select public.vendor_save(:'F', '{"name":"Sample Junction Food Court","category":"Restaurant","tags":"Food court","active":"Active","currency":"ILS","priceBasis":"Per person","maps_link":"https://www.google.com/maps?q=31.5,35.3"}'::jsonb)->'vendor'->>'id' as court \gset
select public.food_add2(:'F', public.__id('S'), 'Sample Junction Food Court', '', 'Covered seating', '31.4999999,35.3000001', :'court') as tip \gset
select pg_temp.t(:'tip' <> '', 'Fay adds a food court tip');
select pg_temp.t((select ll from public.vendor_food where id = :'tip') = '31.500000,35.300000', 'the pin is kept, rounded to 6 places');
select pg_temp.t(pg_temp.err($$select public.place_add('FULLTOKEN00000000000000000', '$$||:'court'||$$', 'Sample Shawarma', 'Rabbanut', 'Meat')$$) = '', 'a place is added');
select pg_temp.t(pg_temp.err($$select public.place_add('GUIDETWO000000000000000000', '$$||:'court'||$$', 'Sample Burger', 'Kosher, certificate not checked', '')$$) = '', 'another colleague adds a place, kosher certificate not checked');
select pg_temp.t(pg_temp.err($$select public.place_add('GUIDETWO000000000000000000', '$$||:'court'||$$', 'sample shawarma', 'Rabbanut', '')$$) like '%already listed%', 'the same place twice is refused');
select pg_temp.t(pg_temp.err($$select public.place_add('GUIDETWO000000000000000000', '$$||:'court'||$$', 'Sample Treif', 'Not kosher', '')$$) like '%Kosher places only%', 'a not kosher place is refused');
select pg_temp.t(pg_temp.err($$select public.place_add('GUIDETWO000000000000000000', '$$||:'court'||$$', 'Sample Nocert', 'Kosher, no certificate', '')$$) like '%only by Eretz Israel Tours%', 'kosher no certificate is refused from a colleague');
select pg_temp.t(pg_temp.err($$select public.place_add('ADMINTOKEN0000000000000000', '$$||:'court'||$$', 'Sample Nocert', 'Kosher, no certificate', '')$$) = '', 'kosher no certificate is accepted from Eretz Israel Tours');
select pg_temp.t(pg_temp.err($$select public.food_add2('GUIDETWO000000000000000000', '$$||public.__id('S')||$$', 'Sample Kiosk', 'Kosher-style (not certified)', '', '', null)$$) like '%Kosher places only%', 'a kosher-style tip is refused');
select pg_temp.t(pg_temp.err($$select public.food_add2('GUIDETWO000000000000000000', '$$||public.__id('S')||$$', 'Sample Cafe', 'Kosher, certificate not checked', '', 'garbage', null)$$) = '', 'a tip with a bad pin is saved without a pin');
select pg_temp.t((select ll from public.vendor_food where name='Sample Cafe') = '', '... and its pin is empty');

-- what each person gets back
select public.food_list(:'G', public.__id('S'))::text as gl \gset
select pg_temp.t(:'gl' like '%"court_id" : "'||:'court'||'"%' and :'gl' like '%Sample Burger%' and :'gl' like '%"ll" : "31.500000,35.300000"%', 'a colleague sees the pin, the food court and its places');
select pg_temp.t(:'gl' not like '%@test.il%', 'no email in the food list');
-- the organisation sees the reserve (sites) but not restaurants (no food section)
select public.food_list(:'O', public.__id('S'))::text as ol \gset
select pg_temp.t(:'ol' like '%Sample Junction Food Court%' and :'ol' not like '%Sample Burger%' and :'ol' like '%"court_id" : null%', 'an organisation without food sees the tip but not the food court or its places');
select pg_temp.t(pg_temp.err($$select public.places_list('ORGTOKEN000000000000000000', '$$||:'court'||$$')$$) like '%not available%', 'an organisation without food cannot list the places');
select pg_temp.t(pg_temp.err($$select public.place_add('ORGTOKEN000000000000000000', '$$||:'court'||$$', 'Sample Org', 'Rabbanut', '')$$) like '%not available%', 'an organisation without food cannot add a place');
select pg_temp.t(pg_temp.err($$select public.food_add2('ORGTOKEN000000000000000000', '$$||public.__id('S')||$$', 'Sample Org tip', 'Rabbanut', '', '', '$$||:'court'||$$')$$) like '%not available%', 'an organisation cannot point a tip at a food court it cannot see');
-- a hidden food court is not offered
update public.vendors set hidden = true where id = :'court';
select pg_temp.t(public.food_list(:'G', public.__id('S'))::text not like '%Sample Burger%', 'a hidden food court shows no places to a colleague');
select pg_temp.t(public.food_list(:'A', public.__id('S'))::text like '%Sample Burger%', '... Eretz Israel Tours still sees them');
update public.vendors set hidden = false where id = :'court';

-- the pin is moved only by the author or Eretz Israel Tours
select pg_temp.t(pg_temp.err($$select public.food_set_ll('GUIDETWO000000000000000000', '$$||:'tip'||$$', '31.6,35.4')$$) like '%Only the person%', 'another colleague cannot move the pin');
select pg_temp.t(pg_temp.err($$select public.food_set_ll('FULLTOKEN00000000000000000', '$$||:'tip'||$$', '31.6,35.4')$$) = '', 'the author moves the pin');

-- Problem? on the tip, by Gal: Eretz Israel Tours gets a report, Fay an alert with no name
select public.flag_problem(:'G', public.__id('S'), :'tip'::uuid, 'Not kosher', 'Burger place lost its certificate');
select pg_temp.t((select count(*) from public.vendor_reports where food_id = :'tip'::uuid and kind='Other' and message like 'Food tip "Sample Junction Food Court": Not kosher.%') = 1, 'the report reaches Supplier updates');
select pg_temp.t(public.vendor_reports_list(:'A')::text like '%"food_id" : "'||:'tip'||'"%', 'the reports list says which tip');
select public.my_alerts(:'F')::text as fa \gset
select pg_temp.t(:'fa' like '%A colleague flagged your food tip%' and :'fa' not like '%Gal%' and :'fa' not like '%gal@%', 'Fay gets an alert that names no one');
select pg_temp.t(public.my_alerts(:'G')::text = '[]', 'the reporter gets no alert');
select pg_temp.t(pg_temp.err($$select public.vendor_reports_list('FULLTOKEN00000000000000000')$$) like '%Only Eretz Israel Tours%', 'a colleague cannot read the reports');
select public.alerts_read(:'F');
select pg_temp.t(public.my_alerts(:'F')::text = '[]', 'read alerts go away');
-- Problem? on the food court's own page: the person who added it is alerted
select public.flag_problem(:'G', :'court', null, 'Closed', '');
select pg_temp.t(public.my_alerts(:'F')::text like '%flagged the food court you added%', 'the food court''s author is alerted');
-- Fay flagging her own tip makes no alert for herself
select public.flag_problem(:'F', public.__id('S'), :'tip'::uuid, 'Wrong place', '');
select pg_temp.t((select count(*) from public.member_alerts where to_email='fay@test.il' and message like '%Wrong place%') = 0, 'no alert to yourself');
select pg_temp.t((select kind from public.vendor_reports where message like '%Wrong place%' limit 1) = 'Moved', 'wrong place is filed as moved');
-- an organisation cannot flag a tip on a supplier it cannot see
select pg_temp.t(pg_temp.err($$select public.flag_problem('ORGTOKEN000000000000000000', '$$||:'court'||$$', null, 'Closed', '')$$) like '%not available%', 'an organisation cannot flag a food court it cannot see');
-- deletes: author or Eretz Israel Tours only
select id as pid from public.vendor_places where name = 'Sample Shawarma' \gset
select public.place_delete(:'G', :'pid'::uuid);
select pg_temp.t(exists(select 1 from public.vendor_places where id = :'pid'), 'another colleague cannot remove a place');
select public.place_delete(:'F', :'pid'::uuid);
select pg_temp.t(not exists(select 1 from public.vendor_places where id = :'pid'), 'the author removes his place');
-- the old food_add still works (copies of the app from before D-55)
select pg_temp.t(pg_temp.err($$select public.food_add('FULLTOKEN00000000000000000', '$$||public.__id('S')||$$', 'Sample Old', 'Rabbanut', '')$$) = '', 'the old food_add still works');
-- a deleted food court leaves the tip with no court
delete from public.vendors where id = :'court';
select pg_temp.t((select court_id from public.vendor_food where id = :'tip') is null, 'a food court taken off the list leaves the tip without it');
-- nobody reaches the new tables directly
select pg_temp.t(not has_table_privilege('anon','public.vendor_places','select') and not has_table_privilege('authenticated','public.member_alerts','select'), 'no direct access to the new tables');
select pg_temp.t(not has_function_privilege('anon','public._places_json(text, public.members)','execute') and not has_function_privilege('anon','public._court_ok(public.members, text)','execute'), 'inner functions cannot be called from outside');
select pg_temp.t(has_function_privilege('anon','public.flag_problem(text,text,uuid,text,text)','execute'), 'the app can call flag_problem');
select 'FAIL '||n||': '||what from res where not ok;
select count(*) filter (where ok)||' passed, '||count(*) filter (where not ok)||' failed' from res;
