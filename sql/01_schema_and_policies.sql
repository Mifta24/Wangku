-- Wangku Schema + RLS Setup for Supabase
-- Run this FIRST in Supabase SQL Editor

-- 1) Extension for UUID generation
create extension if not exists pgcrypto;

-- 2) Categories table (global master data)
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  icon text not null,
  color text not null,
  type text not null check (type in ('income', 'expense')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint categories_name_type_unique unique (name, type)
);

-- 3) Transactions table (per user)
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete restrict,
  amount numeric(14, 2) not null check (amount > 0),
  note text not null default '',
  date date not null default current_date,
  type text not null check (type in ('income', 'expense')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4) Helpful indexes
create index if not exists idx_transactions_user_date
  on public.transactions (user_id, date desc);

create index if not exists idx_transactions_category
  on public.transactions (category_id);

create index if not exists idx_transactions_type
  on public.transactions (type);

-- 5) Auto-update updated_at
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_categories_updated_at on public.categories;
create trigger set_categories_updated_at
before update on public.categories
for each row
execute function public.set_updated_at();

drop trigger if exists set_transactions_updated_at on public.transactions;
create trigger set_transactions_updated_at
before update on public.transactions
for each row
execute function public.set_updated_at();

-- 6) Enable RLS
alter table public.categories enable row level security;
alter table public.transactions enable row level security;

-- 7) Categories policies (read-only for authenticated users)
drop policy if exists "Authenticated can read categories" on public.categories;
create policy "Authenticated can read categories"
on public.categories
for select
to authenticated
using (true);

-- 8) Transactions policies (owner-only access)
drop policy if exists "Users can read own transactions" on public.transactions;
create policy "Users can read own transactions"
on public.transactions
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can insert own transactions" on public.transactions;
create policy "Users can insert own transactions"
on public.transactions
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can update own transactions" on public.transactions;
create policy "Users can update own transactions"
on public.transactions
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can delete own transactions" on public.transactions;
create policy "Users can delete own transactions"
on public.transactions
for delete
to authenticated
using (auth.uid() = user_id);

-- 9) Quick verification
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('categories', 'transactions')
order by table_name;
