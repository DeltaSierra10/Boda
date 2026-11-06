-- Run once in Supabase SQL Editor to let the public RSVP page show the invitation.
-- Only the public event details in this single wedding row are exposed.
grant select on public.wedding_settings to anon;
drop policy if exists "public can read invitation details" on public.wedding_settings;
create policy "public can read invitation details" on public.wedding_settings
for select to anon using (id = '11111111-1111-4111-8111-111111111111');
