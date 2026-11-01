-- D-70 (owner, 1 Nov 2026 11:18): "on transport bus all transport add armored / bulletproof with bus size options".
-- Owner, 1 Nov 2026, 11:32, asked whether stone-proof should be its own option too: "yes".
-- Eight new vehicle keys. Bulletproof (ממוגן ירי): arm_bus (36–60 seats), arm_midibus (21–35), arm_van (up to 20), arm_car (up to 4).
-- Stone-proof (ממוגן אבנים): stone_bus, stone_midibus, stone_van, stone_car, the same sizes.
-- Wherever the database lists the transport vehicle keys, the eight are added after 'car'. Nothing else changes.
--
-- The four functions are changed by editing their LIVE definition text (pg_get_functiondef), so this file can never put
-- back an older copy of them. Each edit must change the text exactly as expected, or the whole file stops.
-- Holds one DROP: the check on bookings.service is dropped and added again, wider. No row is changed or removed.

do $mig$
declare
  old_keys text := $k$'van8','car',$k$;
  new_keys text := $k$'van8','car','arm_bus','arm_midibus','arm_van','arm_car','stone_bus','stone_midibus','stone_van','stone_car',$k$;
  old_lab  text := $k$when 'car' then 'Car' $k$;
  new_lab  text := $k$when 'car' then 'Car' when 'arm_bus' then 'Armored bus' when 'arm_midibus' then 'Armored midibus' when 'arm_van' then 'Armored van' when 'arm_car' then 'Armored car' when 'stone_bus' then 'Stone-proof bus' when 'stone_midibus' then 'Stone-proof midibus' when 'stone_van' then 'Stone-proof van' when 'stone_car' then 'Stone-proof car' $k$;
  f text; d text; n text;
begin
  foreach f in array array['_quote_kind','quote_save','booking_save'] loop
    select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace s on s.oid = p.pronamespace
      where s.nspname = 'public' and p.proname = f;
    if d is null then raise exception 'D-70: % not found', f; end if;
    if d like '%arm_bus%' then raise notice 'D-70: % already has the armored keys', f; continue; end if;
    n := replace(d, old_keys, new_keys);
    if n = d or (length(n) - length(d)) <> (length(new_keys) - length(old_keys)) then
      raise exception 'D-70: % did not match exactly once', f; end if;
    execute n;
  end loop;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace s on s.oid = p.pronamespace
    where s.nspname = 'public' and p.proname = '_booking_to_quote';
  if d like '%arm_bus%' then raise notice 'D-70: _booking_to_quote already has the armored labels';
  else
    n := replace(d, old_lab, new_lab);
    if n = d or (length(n) - length(d)) <> (length(new_lab) - length(old_lab)) then
      raise exception 'D-70: _booking_to_quote did not match exactly once'; end if;
    execute n;
  end if;
end $mig$;

alter table public.bookings drop constraint if exists bookings_service_check;
alter table public.bookings add constraint bookings_service_check check (service = any (array[''::text, 'bus'::text, 'midibus'::text,
  'van20'::text, 'van16'::text, 'van10'::text, 'van8'::text, 'car'::text, 'arm_bus'::text, 'arm_midibus'::text, 'arm_van'::text,
  'arm_car'::text, 'stone_bus'::text, 'stone_midibus'::text, 'stone_van'::text, 'stone_car'::text, 'jeep_vehicle'::text, 'transfer'::text]));
