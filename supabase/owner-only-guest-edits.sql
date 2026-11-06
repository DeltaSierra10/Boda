-- Existing organizers can view the guest list, but only the wedding owner can add,
-- change, or remove guest records. Run once in Supabase SQL Editor.
drop policy if exists "members manage wedding guests" on public.wedding_guests;
drop policy if exists "members read wedding guests" on public.wedding_guests;
create policy "members read wedding guests" on public.wedding_guests
for select to authenticated
using (public.is_wedding_member(wedding_id));

drop policy if exists "owners manage wedding guests" on public.wedding_guests;
create policy "owners manage wedding guests" on public.wedding_guests
for all to authenticated
using (public.is_wedding_owner(wedding_id))
with check (public.is_wedding_owner(wedding_id));

-- Organizers may still assign a guest to a table without editing their personal data.
create or replace function public.assign_wedding_guest_table(p_guest_id uuid, p_table_id uuid default null)
returns boolean language plpgsql security definer set search_path = '' as $$
declare target_wedding uuid;
begin
  select wedding_id into target_wedding from public.wedding_guests where id = p_guest_id;
  if target_wedding is null or not public.is_wedding_member(target_wedding) then return false; end if;
  if p_table_id is not null and not exists (
    select 1 from public.wedding_tables t where t.id = p_table_id and t.wedding_id = target_wedding
  ) then return false; end if;
  update public.wedding_guests set table_id = p_table_id where id = p_guest_id;
  return found;
end;
$$;
revoke all on function public.assign_wedding_guest_table(uuid, uuid) from public;
grant execute on function public.assign_wedding_guest_table(uuid, uuid) to authenticated;
