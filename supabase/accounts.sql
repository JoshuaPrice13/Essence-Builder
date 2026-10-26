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

-- Private saved builds: only the owner can see, change or delete them. Max 50 per player.
create table if not exists public.saved_builds (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  name        text check (char_length(name) <= 40),
  phase       text check (char_length(phase) <= 20),
  data        jsonb not null check (pg_column_size(data) < 500000),
  updated_at  timestamptz not null default now()
);
create index if not exists saved_builds_user_idx on public.saved_builds (user_id, updated_at desc);
alter table public.saved_builds enable row level security;
create policy "owners manage their saved builds" on public.saved_builds for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
grant select, insert, update, delete on public.saved_builds to authenticated;

create or replace function public.saved_builds_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' and (select count(*) from public.saved_builds where user_id = new.user_id) >= 50 then
    raise exception 'saved build limit reached' using errcode = 'P0001';
  end if;
  new.updated_at := now();
  return new;
end $$;
create trigger saved_builds_guard before insert or update on public.saved_builds for each row execute function public.saved_builds_guard();

-- Thumbs up / down per generated power. Players only see their own votes.
create table if not exists public.power_feedback (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  vote        smallint not null check (vote in (-1, 1)),
  power       jsonb not null check (pg_column_size(power) < 20000),
  source      text check (char_length(source) <= 120),
  model       text check (char_length(model) <= 60),
  created_at  timestamptz not null default now()
);
create index if not exists power_feedback_vote_idx on public.power_feedback (vote, created_at desc);
alter table public.power_feedback enable row level security;
create policy "players manage their own votes" on public.power_feedback for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
grant select, insert, update, delete on public.power_feedback to authenticated;

-- For the site owner (dashboard / SQL editor only): liked and disliked generations.
create or replace view public.good_powers with (security_invoker = true) as
  select created_at, model, source, power->>'name' as name, power->>'type' as type, power->>'description' as description, power->'ranks' as ranks, power
  from public.power_feedback where vote = 1;
create or replace view public.bad_powers with (security_invoker = true) as
  select created_at, model, source, power->>'name' as name, power->>'type' as type, power->>'description' as description, power->'ranks' as ranks, power
  from public.power_feedback where vote = -1;
revoke all on public.good_powers, public.bad_powers from anon, authenticated;

-- Owners can update their own published builds (to fill more slots); user_id and created_at stay fixed.
create policy "owners update their own builds" on public.builds for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
grant update (name, title, essences, confluence, model, data) on public.builds to authenticated;
