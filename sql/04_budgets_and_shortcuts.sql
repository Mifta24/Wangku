-- Budget per kategori dan shortcuts untuk Wangku.
-- Jalankan setelah 03_notifications.sql

-- ============================================================
-- BUDGETS TABLE
-- ============================================================
create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  budget_year integer not null default extract(year from now())::integer,
  budget_month integer not null default extract(month from now())::integer
    check (budget_month between 1 and 12),
  amount numeric(14, 2) not null check (amount >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, category_id, budget_year, budget_month)
);

alter table public.budgets
  add column if not exists budget_year integer
    not null default extract(year from now())::integer;

alter table public.budgets
  add column if not exists budget_month integer
    not null default extract(month from now())::integer;

alter table public.budgets
  drop constraint if exists budgets_user_id_category_id_key;

alter table public.budgets
  drop constraint if exists budgets_user_category_month_key;

alter table public.budgets
  drop constraint if exists budgets_budget_month_check;

alter table public.budgets
  add constraint budgets_budget_month_check
  check (budget_month between 1 and 12);

alter table public.budgets
  add constraint budgets_user_category_month_key
  unique (user_id, category_id, budget_year, budget_month);

create index if not exists idx_budgets_user
  on public.budgets (user_id);

create index if not exists idx_budgets_user_month
  on public.budgets (user_id, budget_year, budget_month);

alter table public.budgets enable row level security;

drop policy if exists "Users can read own budgets" on public.budgets;
create policy "Users can read own budgets"
on public.budgets for select
using (auth.uid() = user_id);

drop policy if exists "Users can insert own budgets" on public.budgets;
create policy "Users can insert own budgets"
on public.budgets for insert
with check (auth.uid() = user_id);

drop policy if exists "Users can update own budgets" on public.budgets;
create policy "Users can update own budgets"
on public.budgets for update
using (auth.uid() = user_id);

drop policy if exists "Users can delete own budgets" on public.budgets;
create policy "Users can delete own budgets"
on public.budgets for delete
using (auth.uid() = user_id);

-- ============================================================
-- SHORTCUTS TABLE
-- ============================================================
create table if not exists public.shortcuts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  amount numeric(14, 2),
  note text not null default '',
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_shortcuts_user_order
  on public.shortcuts (user_id, sort_order asc);

alter table public.shortcuts enable row level security;

drop policy if exists "Users can read own shortcuts" on public.shortcuts;
create policy "Users can read own shortcuts"
on public.shortcuts for select
using (auth.uid() = user_id);

drop policy if exists "Users can insert own shortcuts" on public.shortcuts;
create policy "Users can insert own shortcuts"
on public.shortcuts for insert
with check (auth.uid() = user_id);

drop policy if exists "Users can update own shortcuts" on public.shortcuts;
create policy "Users can update own shortcuts"
on public.shortcuts for update
using (auth.uid() = user_id);

drop policy if exists "Users can delete own shortcuts" on public.shortcuts;
create policy "Users can delete own shortcuts"
on public.shortcuts for delete
using (auth.uid() = user_id);
