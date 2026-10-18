-- D-60 (18 Oct 2026): batch confirm with a review step, already-confirmed lines skipped, and one undo for the whole batch.
-- The owner, 17 Oct 2026: "I need a faster way of approving prices. It's one by one. Like city of David. I just put all of
-- those prices in. I should be able to batch confirm them." Builds on D-57 (the confirmed mark) and D-58 (the batch sheet,
-- which called price_confirm once per price). Rules: D-1, F1, D1-D7, E1, E2, G1-G12.
--
-- Adds only. No DELETE, no DROP, no table grant, no policy. Safe to run twice. Nothing in the Cockpit's door changes.
--
-- price_confirm_batch(token, supplier, line ids, how, kind): Eretz Israel Tours only. All or nothing, in one transaction:
--   every id must be a line of that supplier that still exists, or nothing is saved. Lines that are already confirmed are
--   skipped and left exactly as they are. Every other line gets its own confirmed_at / confirmed_by / confirmed_how, the
--   same as a single confirm, all with the same moment. The kind is set when one is chosen; with none chosen each line
--   keeps the kind it had. One row in price_confirm_batches remembers which lines were confirmed and the kind each had
--   before, for the undo.
-- price_confirm_batch_undo(token, batch): Eretz Israel Tours only. Takes the mark off every line of that batch that still
--   carries the batch's own mark and puts its kind back. A line that changed since (its price was edited, which already
--   took the mark off, or it was confirmed again on its own) is left as it is and named. A batch is undone once.

create table if not exists public.price_confirm_batches (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  confirmed_at timestamp with time zone not null,
  confirmed_by text not null,
  confirmed_how text not null,
  kind text not null default '',
  lines jsonb not null default '[]'::jsonb,
  skipped jsonb not null default '[]'::jsonb,
  undone_at timestamp with time zone,
  undone_by text not null default '',
  undone_lines jsonb not null default '[]'::jsonb,
  constraint price_confirm_batches_pkey primary key (id),
  constraint price_confirm_batches_how_check check (confirmed_how = any (array['official_list'::text, 'supplier_document'::text, 'paid_invoice'::text, 'supplier_conversation'::text])
    and kind = any (array[''::text, 'tariff'::text, 'negotiated'::text]))
);
create index if not exists price_confirm_batches_vendor_idx on public.price_confirm_batches (vendor_id, confirmed_at desc);
alter table public.price_confirm_batches enable row level security;
revoke all on table public.price_confirm_batches from public, anon, authenticated;
grant all on table public.price_confirm_batches to service_role;

create or replace function public.price_confirm_batch(p_token text, p_vendor text, p_ids uuid[], p_how text, p_kind text default '')
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; ids uuid[]; n_found int; b uuid; conf jsonb; skip jsonb;
begin
  m := public._auth(p_token, true);
  if coalesce(p_how,'') not in ('official_list', 'supplier_document', 'paid_invoice', 'supplier_conversation') then
    raise exception 'Say how the prices were confirmed: official list, the supplier''s own document or email, a paid invoice, or a conversation with the supplier.';
  end if;
  if coalesce(p_kind,'') not in ('', 'tariff', 'negotiated') then raise exception 'A price is a tariff or negotiated.'; end if;
  select coalesce(array_agg(distinct x), '{}') into ids from unnest(coalesce(p_ids, '{}'::uuid[])) x where x is not null;
  if cardinality(ids) = 0 then raise exception 'Tick at least one price.'; end if;
  if cardinality(ids) > 500 then raise exception 'At most 500 prices at once.'; end if;
  -- every ticked line must be this supplier's and still there; lock them so nothing changes them meanwhile
  select count(*) into n_found from (select p.id from public.vendor_prices p
    where p.id = any (ids) and p.vendor_id = p_vendor and p.archived_at is null for update) x;
  if n_found <> cardinality(ids) then
    raise exception '% of the ticked prices no longer belong to this supplier. Nothing was confirmed. Close the list and open it again.', cardinality(ids) - n_found;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'kind_before', p.kind) order by p.id) filter (where p.confirmed_at is null), '[]'::jsonb),
         coalesce(jsonb_agg(p.id order by p.id) filter (where p.confirmed_at is not null), '[]'::jsonb)
    into conf, skip from public.vendor_prices p where p.id = any (ids);
  if jsonb_array_length(conf) = 0 then
    return json_build_object('batch', null, 'confirmed', '[]'::json, 'skipped', skip, 'confirmed_at', null);
  end if;
  insert into public.price_confirm_batches (vendor_id, confirmed_at, confirmed_by, confirmed_how, kind, lines, skipped)
    values (p_vendor, now(), 'Eretz Israel Tours', p_how, coalesce(p_kind,''), conf, skip) returning id into b;
  perform set_config('app.confirm', 'on', true);
  update public.vendor_prices p set confirmed_at = now(), confirmed_by = 'Eretz Israel Tours', confirmed_how = p_how,
      kind = case when coalesce(p_kind,'') = '' then p.kind else p_kind end
    where p.id in (select (e->>'id')::uuid from jsonb_array_elements(conf) e);
  perform set_config('app.confirm', 'off', true);
  return json_build_object('batch', b, 'confirmed', (select json_agg(e->>'id') from jsonb_array_elements(conf) e), 'skipped', skip, 'confirmed_at', now());
end $function$;

create or replace function public.price_confirm_batch_undo(p_token text, p_batch uuid)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; bt public.price_confirm_batches; cleared jsonb; left_ jsonb;
begin
  m := public._auth(p_token, true);
  select * into bt from public.price_confirm_batches where id = p_batch for update;
  if bt.id is null then raise exception 'That batch is not known.'; end if;
  if bt.undone_at is not null then raise exception 'That batch was already undone.'; end if;
  -- a line is still the batch's own when it carries exactly the batch's mark (same moment, same way, same person)
  select coalesce(jsonb_agg(p.id order by p.id) filter (where p.confirmed_at = bt.confirmed_at and p.confirmed_how = bt.confirmed_how and p.confirmed_by = bt.confirmed_by and p.archived_at is null), '[]'::jsonb),
         coalesce(jsonb_agg(e->>'id' order by e->>'id') filter (where p.id is null or not (p.confirmed_at = bt.confirmed_at and p.confirmed_how = bt.confirmed_how and p.confirmed_by = bt.confirmed_by and p.archived_at is null)), '[]'::jsonb)
    into cleared, left_
    from jsonb_array_elements(bt.lines) e left join public.vendor_prices p on p.id = (e->>'id')::uuid;
  perform set_config('app.confirm', 'on', true);
  update public.vendor_prices p set confirmed_at = null, confirmed_by = '', confirmed_how = '', kind = e->>'kind_before'
    from jsonb_array_elements(bt.lines) e
    where p.id = (e->>'id')::uuid and p.id in (select (c #>> '{}')::uuid from jsonb_array_elements(cleared) c);
  perform set_config('app.confirm', 'off', true);
  update public.price_confirm_batches set undone_at = now(), undone_by = 'Eretz Israel Tours', undone_lines = cleared where id = bt.id;
  return json_build_object('batch', bt.id, 'cleared', cleared, 'left', left_);
end $function$;

revoke all on function public.price_confirm_batch(text, text, uuid[], text, text) from public; grant execute on function public.price_confirm_batch(text, text, uuid[], text, text) to anon, authenticated;
revoke all on function public.price_confirm_batch_undo(text, uuid) from public; grant execute on function public.price_confirm_batch_undo(text, uuid) to anon, authenticated;
