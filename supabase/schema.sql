-- Run once in the Supabase SQL editor.
create table if not exists public.builds (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  name        text   not null check (char_length(name) between 1 and 40),
  title       text   check (char_length(title) <= 80),
  essences    text[] not null check (array_length(essences, 1) = 3),
  confluence  text   not null check (char_length(confluence) between 1 and 40),
  model       text   check (char_length(model) <= 60),
  data        jsonb  not null check (pg_column_size(data) < 150000)
);

create index if not exists builds_created_at_idx on public.builds (created_at desc);

alter table public.builds enable row level security;

-- Anyone may read and add builds. Nobody may edit or delete through the public key.
create policy "builds are public to read" on public.builds for select to anon, authenticated using (true);
create policy "anyone can add a build"    on public.builds for insert to anon, authenticated with check (true);

grant select, insert on public.builds to anon, authenticated;
