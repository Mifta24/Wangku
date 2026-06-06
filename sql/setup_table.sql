-- ================================================================
-- WANGKU — FULL SETUP SCRIPT
-- Jalankan sekali di SQL Editor Supabase project baru.
-- Mencakup: schema, indexes, triggers, RLS, realtime, RPC functions,
--           dan data kategori default.
-- ================================================================


-- ================================================================
-- 0. EXTENSION
-- ================================================================
create extension if not exists pgcrypto;


-- ================================================================
-- 1. TABEL: categories
-- Kategori global (user_id NULL) dan custom per user (user_id = uid)
-- ================================================================
create table if not exists public.categories (
  id         uuid        primary key default gen_random_uuid(),
  user_id    uuid        references auth.users(id) on delete cascade,
  name       text        not null,
  icon       text        not null,
  color      text        not null,
  type       text        not null check (type in ('income', 'expense')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Unique: kategori global tidak boleh duplikat
create unique index if not exists categories_name_type_global_idx
  on public.categories (name, type)
  where user_id is null;

-- Unique: kategori per user tidak boleh duplikat dalam satu user
create unique index if not exists categories_name_type_user_idx
  on public.categories (name, type, user_id)
  where user_id is not null;


-- ================================================================
-- 2. TABEL: transactions
-- ================================================================
create table if not exists public.transactions (
  id          uuid         primary key default gen_random_uuid(),
  user_id     uuid         not null references auth.users(id) on delete cascade,
  category_id uuid         not null references public.categories(id) on delete restrict,
  amount      numeric(14,2) not null check (amount > 0),
  note        text         not null default '',
  date        date         not null default current_date,
  type        text         not null check (type in ('income', 'expense')),
  created_at  timestamptz  not null default now(),
  updated_at  timestamptz  not null default now()
);

create index if not exists idx_transactions_user_date
  on public.transactions (user_id, date desc);

create index if not exists idx_transactions_category
  on public.transactions (category_id);

create index if not exists idx_transactions_type
  on public.transactions (type);


-- ================================================================
-- 3. TABEL: notifications
-- ================================================================
create table if not exists public.notifications (
  id         uuid        primary key,
  user_id    uuid        not null references auth.users(id) on delete cascade,
  title      text        not null,
  body       text        not null,
  type       text        not null default 'system',
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user_created
  on public.notifications (user_id, created_at desc);


-- ================================================================
-- 4. TABEL: budgets
-- ================================================================
create table if not exists public.budgets (
  id           uuid         primary key default gen_random_uuid(),
  user_id      uuid         not null references auth.users(id) on delete cascade,
  category_id  uuid         not null references public.categories(id) on delete cascade,
  amount       numeric(14,2) not null check (amount >= 0),
  created_at   timestamptz  not null default now(),
  updated_at   timestamptz  not null default now(),
  unique (user_id, category_id)
);

create index if not exists idx_budgets_user
  on public.budgets (user_id);


-- ================================================================
-- 5. TABEL: profiles
-- ================================================================
create table if not exists public.profiles (
  id         uuid  primary key references auth.users(id) on delete cascade,
  name       text  not null default '',
  phone      text  not null default '',
  birth_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- ================================================================
-- 7. TRIGGER: auto-update updated_at
-- ================================================================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_categories_updated_at  on public.categories;
create trigger set_categories_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

drop trigger if exists set_transactions_updated_at on public.transactions;
create trigger set_transactions_updated_at
  before update on public.transactions
  for each row execute function public.set_updated_at();

drop trigger if exists set_budgets_updated_at on public.budgets;
create trigger set_budgets_updated_at
  before update on public.budgets
  for each row execute function public.set_updated_at();

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();


-- ================================================================
-- 8. TRIGGER: auto-create profile saat user baru register
-- ================================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql
security definer set search_path = public as $$
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

-- Backfill profiles untuk user yang sudah ada
insert into public.profiles (id, name)
select
  id,
  coalesce(raw_user_meta_data->>'name', raw_user_meta_data->>'full_name', '')
from auth.users
on conflict (id) do nothing;


-- ================================================================
-- 9. ROW LEVEL SECURITY (RLS)
-- ================================================================

-- categories
alter table public.categories enable row level security;

drop policy if exists "Users can read system and own categories" on public.categories;
create policy "Users can read system and own categories"
  on public.categories for select to authenticated
  using (user_id is null or user_id = auth.uid());

drop policy if exists "Users can insert own categories" on public.categories;
create policy "Users can insert own categories"
  on public.categories for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Users can update own categories" on public.categories;
create policy "Users can update own categories"
  on public.categories for update to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users can delete own categories" on public.categories;
create policy "Users can delete own categories"
  on public.categories for delete to authenticated
  using (user_id = auth.uid());

-- transactions
alter table public.transactions enable row level security;

drop policy if exists "Users can read own transactions" on public.transactions;
create policy "Users can read own transactions"
  on public.transactions for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own transactions" on public.transactions;
create policy "Users can insert own transactions"
  on public.transactions for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own transactions" on public.transactions;
create policy "Users can update own transactions"
  on public.transactions for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own transactions" on public.transactions;
create policy "Users can delete own transactions"
  on public.transactions for delete to authenticated
  using (auth.uid() = user_id);

-- notifications
alter table public.notifications enable row level security;

drop policy if exists "Users can read own notifications" on public.notifications;
create policy "Users can read own notifications"
  on public.notifications for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own notifications" on public.notifications;
create policy "Users can insert own notifications"
  on public.notifications for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own notifications" on public.notifications;
create policy "Users can delete own notifications"
  on public.notifications for delete to authenticated
  using (auth.uid() = user_id);

-- budgets
alter table public.budgets enable row level security;

drop policy if exists "Users can read own budgets" on public.budgets;
create policy "Users can read own budgets"
  on public.budgets for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own budgets" on public.budgets;
create policy "Users can insert own budgets"
  on public.budgets for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own budgets" on public.budgets;
create policy "Users can update own budgets"
  on public.budgets for update to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can delete own budgets" on public.budgets;
create policy "Users can delete own budgets"
  on public.budgets for delete to authenticated
  using (auth.uid() = user_id);

-- profiles
alter table public.profiles enable row level security;

drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
  on public.profiles for select to authenticated
  using (auth.uid() = id);

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles for insert to authenticated
  with check (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update to authenticated
  using (auth.uid() = id);


-- ================================================================
-- 10. REALTIME
-- Aktifkan realtime untuk tabel yang disubscribe Flutter
-- ================================================================
alter publication supabase_realtime add table public.transactions;
alter publication supabase_realtime add table public.categories;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.budgets;
alter publication supabase_realtime add table public.profiles;


-- ================================================================
-- 11. RPC FUNCTIONS
-- ================================================================

-- get_monthly_aggregates
-- Return: { total_income, total_expense }
create or replace function public.get_monthly_aggregates(
  p_user_id    uuid,
  p_start_date date,
  p_end_date   date
)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  v_income  numeric := 0;
  v_expense numeric := 0;
begin
  select
    coalesce(sum(case when type = 'income'  then amount else 0 end), 0),
    coalesce(sum(case when type = 'expense' then amount else 0 end), 0)
  into v_income, v_expense
  from public.transactions
  where user_id = p_user_id
    and date >= p_start_date
    and date <  p_end_date;

  return jsonb_build_object(
    'total_income',  v_income,
    'total_expense', v_expense
  );
end;
$$;

grant execute on function public.get_monthly_aggregates(uuid, date, date) to authenticated;


-- get_period_report
-- Return: { current_income, current_expense, prev_income, prev_expense,
--           categories[], trend[] }
-- p_period_type bucket:
--   'week'  → per hari  (bucket = 'YYYY-MM-DD')
--   'month' → per minggu dalam bulan (bucket = '0'..'3')
--   'year'  → per bulan (bucket = '1'..'12')
create or replace function public.get_period_report(
  p_user_id     uuid,
  p_start       date,
  p_end         date,
  p_prev_start  date,
  p_prev_end    date,
  p_period_type text
)
returns json
language plpgsql
security definer set search_path = public
as $$
declare
  v_curr_income  numeric := 0; v_curr_expense numeric := 0;
  v_prev_income  numeric := 0; v_prev_expense numeric := 0;
  v_categories   jsonb;        v_trend        jsonb;
begin
  -- Totals periode sekarang
  select
    coalesce(sum(case when type = 'income'  then amount else 0 end), 0),
    coalesce(sum(case when type = 'expense' then amount else 0 end), 0)
  into v_curr_income, v_curr_expense
  from public.transactions
  where user_id = p_user_id and date >= p_start and date < p_end;

  -- Totals periode sebelumnya
  select
    coalesce(sum(case when type = 'income'  then amount else 0 end), 0),
    coalesce(sum(case when type = 'expense' then amount else 0 end), 0)
  into v_prev_income, v_prev_expense
  from public.transactions
  where user_id = p_user_id and date >= p_prev_start and date < p_prev_end;

  -- Breakdown kategori (pisah per type agar field type terisi)
  select jsonb_agg(d) into v_categories from (
    select jsonb_build_object(
      'category_id', c.id,   'name',  c.name,
      'icon',        c.icon, 'color', c.color,
      'type',        t.type, 'total', sum(t.amount)
    ) d
    from public.transactions t
    join public.categories c on c.id = t.category_id
    where t.user_id = p_user_id and t.date >= p_start and t.date < p_end
    group by c.id, c.name, c.icon, c.color, t.type
  ) sub;

  -- Trend sesuai period_type
  if p_period_type = 'week' then
    select jsonb_agg(d order by d->>'bucket') into v_trend from (
      select jsonb_build_object(
        'bucket',  date::text,
        'income',  coalesce(sum(case when type = 'income'  then amount else 0 end), 0),
        'expense', coalesce(sum(case when type = 'expense' then amount else 0 end), 0)
      ) d
      from public.transactions
      where user_id = p_user_id and date >= p_start and date < p_end
      group by date
    ) sub;

  elsif p_period_type = 'month' then
    select jsonb_agg(d order by (d->>'bucket')::int) into v_trend from (
      select jsonb_build_object(
        'bucket',  ((extract(day from date)::int - 1) / 7)::text,
        'income',  coalesce(sum(case when type = 'income'  then amount else 0 end), 0),
        'expense', coalesce(sum(case when type = 'expense' then amount else 0 end), 0)
      ) d
      from public.transactions
      where user_id = p_user_id and date >= p_start and date < p_end
      group by (extract(day from date)::int - 1) / 7
    ) sub;

  else -- year
    select jsonb_agg(d order by (d->>'bucket')::int) into v_trend from (
      select jsonb_build_object(
        'bucket',  extract(month from date)::int::text,
        'income',  coalesce(sum(case when type = 'income'  then amount else 0 end), 0),
        'expense', coalesce(sum(case when type = 'expense' then amount else 0 end), 0)
      ) d
      from public.transactions
      where user_id = p_user_id and date >= p_start and date < p_end
      group by extract(month from date)::int
    ) sub;
  end if;

  return json_build_object(
    'current_income',  v_curr_income,  'current_expense', v_curr_expense,
    'prev_income',     v_prev_income,  'prev_expense',    v_prev_expense,
    'categories',      coalesce(v_categories, '[]'::jsonb),
    'trend',           coalesce(v_trend,      '[]'::jsonb)
  );
end;
$$;

grant execute on function public.get_period_report(uuid, date, date, date, date, text) to authenticated;


-- check_budget_alerts
-- Return: [{ category_id, category_name, budget, spent, percentage }]
create or replace function public.check_budget_alerts(
  p_user_id uuid,
  p_year    integer,
  p_month   integer
)
returns table (
  category_id   uuid,
  category_name text,
  budget        numeric,
  spent         numeric,
  percentage    numeric
)
language plpgsql
security definer set search_path = public
as $$
declare
  v_start date;
  v_end   date;
begin
  v_start := make_date(p_year, p_month, 1);
  v_end   := (v_start + interval '1 month')::date;

  return query
  select
    b.category_id,
    c.name                                                         as category_name,
    b.amount                                                       as budget,
    coalesce(t.spent, 0)                                          as spent,
    case
      when b.amount > 0
        then round((coalesce(t.spent, 0) / b.amount * 100)::numeric, 2)
      else 0::numeric
    end                                                           as percentage
  from public.budgets b
  join public.categories c on c.id = b.category_id
  left join (
    select tx.category_id, sum(tx.amount) as spent
    from public.transactions tx
    where tx.user_id = p_user_id
      and tx.type    = 'expense'
      and tx.date   >= v_start
      and tx.date   <  v_end
    group by tx.category_id
  ) t on t.category_id = b.category_id
  where b.user_id = p_user_id
  order by percentage desc;
end;
$$;

grant execute on function public.check_budget_alerts(uuid, integer, integer) to authenticated;


-- ================================================================
-- 12. DATA DEFAULT: kategori sistem (global, user_id = NULL)
-- ================================================================
insert into public.categories (name, icon, color, type) values
  ('Makanan',      '🍔', '#FF6B6B', 'expense'),
  ('Transportasi', '🚗', '#4ECDC4', 'expense'),
  ('Hiburan',      '🎬', '#FFE66D', 'expense'),
  ('Belanja',      '🛍️', '#95E1D3', 'expense'),
  ('Kesehatan',    '⚕️', '#F38181', 'expense'),
  ('Utilitas',     '💡', '#95E1D3', 'expense'),
  ('Pendidikan',   '📚', '#A8E6CF', 'expense'),
  ('Gaji',         '💰', '#6BCB77', 'income'),
  ('Bonus',        '🎁', '#4D96FF', 'income'),
  ('Freelance',    '💻', '#6BCB77', 'income'),
  ('Investasi',    '📈', '#FFD700', 'income')
on conflict do nothing;
