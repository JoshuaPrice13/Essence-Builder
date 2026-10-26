-- Run once after schema.sql. Adds player accounts (username or Discord) and attributes builds to them.
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  username    text not null check (username ~ '^[A-Za-z0-9_]{3,20}$'),
  created_at  timestamptz not null default now()
);
create unique index if not exists profiles_username_lower_idx on public.profiles (lower(username));
alter table public.profiles enable row level security;
create policy "profiles are public to read" on public.profiles for select to anon, authenticated using (true);
grant select on public.profiles to anon, authenticated;

-- Every new sign-in user gets a profile; Discord names are cleaned and made unique.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare base text; u text; n int := 0;
begin
  base := regexp_replace(coalesce(new.raw_user_meta_data->>'username', new.raw_user_meta_data->>'name',
            new.raw_user_meta_data->>'user_name', new.raw_user_meta_data->>'full_name', 'player'), '[^A-Za-z0-9_]', '', 'g');
  base := left(base, 16);
  if length(base) < 3 then base := 'player'; end if;
  u := base;
  while exists (select 1 from public.profiles where lower(username) = lower(u)) loop
    n := n + 1; u := base || n;
  end loop;
  insert into public.profiles (id, username) values (new.id, u);
  return new;
end $$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Only signed-in players publish, always as themselves, and they may delete their own builds.
alter table public.builds add column if not exists user_id uuid references public.profiles(id) on delete cascade default auth.uid();
create index if not exists builds_user_id_idx on public.builds (user_id);
drop policy if exists "anyone can add a build" on public.builds;
create policy "signed-in players add their own builds" on public.builds for insert to authenticated with check (user_id = (select auth.uid()));
create policy "owners delete their own builds" on public.builds for delete to authenticated using (user_id = (select auth.uid()));
revoke insert on public.builds from anon;
grant delete on public.builds to authenticated;
