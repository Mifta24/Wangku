-- Tabel profiles untuk menyimpan biodata user.
-- Jalankan setelah 04_budgets_and_shortcuts.sql

-- ============================================================
-- PROFILES TABLE
-- ============================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  phone text not null default '',
  bio text not null default '',
  job text not null default '',
  city text not null default '',
  gender text check (gender in ('Laki-laki', 'Perempuan', '')),
  birth_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
on public.profiles for select
using (auth.uid() = id);

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
on public.profiles for insert
with check (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles for update
using (auth.uid() = id);

-- ============================================================
-- TRIGGER: Auto-create profile saat user baru daftar
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', new.raw_user_meta_data->>'full_name', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- BACKFILL: Isi profiles untuk user yang sudah ada
-- ============================================================
insert into public.profiles (id, name)
select
  id,
  coalesce(raw_user_meta_data->>'name', raw_user_meta_data->>'full_name', '')
from auth.users
on conflict (id) do nothing;
