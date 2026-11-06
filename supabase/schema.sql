-- Run this once in Supabase Dashboard > SQL Editor.
-- Creates one private wedding workspace and a token-based public RSVP endpoint.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.wedding_settings (
  id uuid primary key default gen_random_uuid(),
  couple_names text not null default 'Alba & Mateo',
  wedding_date text not null default 'Sábado, 19 de junio de 2027',
  wedding_time text not null default '17:00 h',
  venue text not null default 'Finca Laurel, Tenerife',
  invitation_message text not null default 'Nos haría mucha ilusión compartir este día tan especial contigo. Confírmanos si podrás acompañarnos.',
  rsvp_deadline text not null default '1 de mayo de 2027',
  ask_allergies boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.wedding_members (
  wedding_id uuid not null references public.wedding_settings(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin')),
  created_at timestamptz not null default now(),
  primary key (wedding_id, user_id)
);

create table if not exists public.wedding_tables (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.wedding_settings(id) on delete cascade,
  name text not null,
  shape text not null default 'round' check (shape in ('round', 'square')),
  capacity integer not null default 8 check (capacity > 0),
  created_at timestamptz not null default now()
);

create table if not exists public.wedding_guests (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references public.wedding_settings(id) on delete cascade,
  table_id uuid references public.wedding_tables(id) on delete set null,
  name text not null,
  status text not null default 'pending' check (status in ('yes', 'pending', 'no')),
  plus_ones integer not null default 0 check (plus_ones >= 0),
  allergy_notes text not null default '',
  invite_token uuid not null unique default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create index if not exists wedding_guests_wedding_idx on public.wedding_guests(wedding_id);
create index if not exists wedding_guests_table_idx on public.wedding_guests(table_id);

-- Protect the owner's role from being changed or deleted through the app.
create or replace function public.keep_wedding_owner()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.role = 'owner' and (tg_op = 'DELETE' or new.role <> 'owner' or new.user_id <> old.user_id) then
    raise exception 'The wedding owner cannot be removed or changed';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
drop trigger if exists wedding_owner_protected on public.wedding_members;
create trigger wedding_owner_protected before update or delete on public.wedding_members
for each row execute function public.keep_wedding_owner();

-- The first wedding is created during setup. This is safe to re-run.
insert into public.wedding_settings (id) values ('11111111-1111-4111-8111-111111111111') on conflict (id) do nothing;

alter table public.wedding_settings enable row level security;
alter table public.wedding_members enable row level security;
alter table public.wedding_tables enable row level security;
alter table public.wedding_guests enable row level security;

-- Security-definer helpers avoid recursive membership-table policies.
create or replace function public.is_wedding_member(target_wedding uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.wedding_members m where m.wedding_id = target_wedding and m.user_id = (select auth.uid()))
$$;
create or replace function public.is_wedding_owner(target_wedding uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.wedding_members m where m.wedding_id = target_wedding and m.user_id = (select auth.uid()) and m.role = 'owner')
$$;
revoke all on function public.is_wedding_member(uuid) from public;
revoke all on function public.is_wedding_owner(uuid) from public;
grant execute on function public.is_wedding_member(uuid), public.is_wedding_owner(uuid) to authenticated;

drop policy if exists "members can read own membership" on public.wedding_members;
create policy "members can read own membership" on public.wedding_members
for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "owners manage membership" on public.wedding_members;
create policy "owners manage membership" on public.wedding_members
for all to authenticated
using (public.is_wedding_owner(wedding_id))
with check (public.is_wedding_owner(wedding_id));

drop policy if exists "members read wedding settings" on public.wedding_settings;
create policy "members read wedding settings" on public.wedding_settings
for select to authenticated using (public.is_wedding_member(id));
drop policy if exists "members update wedding settings" on public.wedding_settings;
create policy "members update wedding settings" on public.wedding_settings
for update to authenticated using (public.is_wedding_member(id))
with check (public.is_wedding_member(id));

drop policy if exists "members manage wedding tables" on public.wedding_tables;
create policy "members manage wedding tables" on public.wedding_tables
for all to authenticated using (public.is_wedding_member(wedding_id))
with check (public.is_wedding_member(wedding_id));

drop policy if exists "members manage wedding guests" on public.wedding_guests;
drop policy if exists "members read wedding guests" on public.wedding_guests;
create policy "members read wedding guests" on public.wedding_guests
for select to authenticated using (public.is_wedding_member(wedding_id));
drop policy if exists "owners manage wedding guests" on public.wedding_guests;
create policy "owners manage wedding guests" on public.wedding_guests
for all to authenticated using (public.is_wedding_owner(wedding_id))
with check (public.is_wedding_owner(wedding_id));

-- Guests can only submit an RSVP for the random invite token they possess.
-- This function reveals no guest data and grants no table access to anonymous visitors.
create or replace function public.submit_wedding_rsvp(p_token uuid, p_status text, p_plus_ones integer default 0, p_allergy_notes text default '')
returns boolean language plpgsql security definer set search_path = '' as $$
declare changed integer;
begin
  if p_status not in ('yes', 'no') or p_plus_ones < 0 then return false; end if;
  update public.wedding_guests
    set status = p_status,
        plus_ones = case when p_status = 'yes' then p_plus_ones else 0 end,
        allergy_notes = case when p_status = 'yes' then left(coalesce(p_allergy_notes, ''), 1000) else '' end
    where invite_token = p_token;
  get diagnostics changed = row_count;
  return changed = 1;
end;
$$;
revoke all on function public.submit_wedding_rsvp(uuid, text, integer, text) from public;
grant execute on function public.submit_wedding_rsvp(uuid, text, integer, text) to anon, authenticated;

-- Organizers may change seating assignments without changing guest personal data.
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

-- Create the owner auth account first in Authentication > Users, then run:
-- insert into public.wedding_members (wedding_id, user_id, role)
-- select '11111111-1111-4111-8111-111111111111', id, 'owner'
-- from auth.users where email = 'TU_CORREO';
-- Create later organizers in Authentication > Users and add them as role 'admin'.

-- Seed tables for the demo layout; remove these lines if you prefer an empty plan.
insert into public.wedding_tables (wedding_id, name, shape, capacity)
select '11111111-1111-4111-8111-111111111111', seed.name, seed.shape, seed.capacity
from (values ('Mesa 1','round',8), ('Mesa 2','round',8), ('Mesa 3','square',8)) as seed(name,shape,capacity)
where not exists (select 1 from public.wedding_tables t where t.wedding_id = '11111111-1111-4111-8111-111111111111');
