-- RPC Functions for Wangku
-- Jalankan setelah 05_profiles.sql

-- ============================================================
-- FUNCTION: get_monthly_aggregates
-- Dipanggil oleh: TransactionService.getMonthlyAggregates
-- Return: { total_income, total_expense }
-- ============================================================
create or replace function public.get_monthly_aggregates(
  p_user_id   uuid,
  p_start_date date,
  p_end_date  date
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

  return jsonb_build_object(∏
    'total_income',  v_income,
    'total_expense', v_expense
  );
end;
$$;

grant execute on function public.get_monthly_aggregates(uuid, date, date) to authenticated;

-- ============================================================
-- FUNCTION: get_period_report
-- Dipanggil oleh: ReportService.getPeriodReport
-- Return: {
--   current_income, current_expense,
--   prev_income, prev_expense,
--   categories: [{ category_id, name, icon, color, type, total }],
--   trend:      [{ bucket, income, expense }]
-- }
-- p_period_type bucket:
--   'week'  → per hari  (bucket = 'YYYY-MM-DD')
--   'month' → per minggu dalam bulan (bucket = '0'..'3')
--   'year'  → per bulan (bucket = '1'..'12')
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_period_report(
  p_user_id     UUID,
  p_start       DATE,
  p_end         DATE,
  p_prev_start  DATE,
  p_prev_end    DATE,
  p_period_type TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_curr_income  NUMERIC := 0; v_curr_expense NUMERIC := 0;
  v_prev_income  NUMERIC := 0; v_prev_expense NUMERIC := 0;
  v_categories   JSONB;        v_trend        JSONB;
BEGIN
  -- Agregat periode sekarang
  SELECT COALESCE(SUM(CASE WHEN type='income'  THEN amount ELSE 0 END), 0),
         COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0)
  INTO v_curr_income, v_curr_expense
  FROM public.transactions
  WHERE user_id = p_user_id AND date >= p_start AND date < p_end;

  -- Agregat periode sebelumnya
  SELECT COALESCE(SUM(CASE WHEN type='income'  THEN amount ELSE 0 END), 0),
         COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0)
  INTO v_prev_income, v_prev_expense
  FROM public.transactions
  WHERE user_id = p_user_id AND date >= p_prev_start AND date < p_prev_end;

  -- Distribusi kategori (pisah per type agar field type terisi)
  SELECT jsonb_agg(d) INTO v_categories FROM (
    SELECT jsonb_build_object(
      'category_id', c.id,   'name', c.name,
      'icon',        c.icon, 'color', c.color,
      'type',        t.type, 'total', SUM(t.amount)
    ) d
    FROM public.transactions t
    JOIN public.categories c ON c.id = t.category_id
    WHERE t.user_id = p_user_id AND t.date >= p_start AND t.date < p_end
    GROUP BY c.id, c.name, c.icon, c.color, t.type
  ) sub;

  -- Trend sesuai period_type
  IF p_period_type = 'week' THEN
    -- bucket = tanggal harian 'YYYY-MM-DD'
    SELECT jsonb_agg(d ORDER BY d->>'bucket') INTO v_trend FROM (
      SELECT jsonb_build_object(
        'bucket',  date::TEXT,
        'income',  COALESCE(SUM(CASE WHEN type='income'  THEN amount ELSE 0 END), 0),
        'expense', COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0)
      ) d
      FROM public.transactions
      WHERE user_id = p_user_id AND date >= p_start AND date < p_end
      GROUP BY date
    ) sub;

  ELSIF p_period_type = 'month' THEN
    -- bucket = minggu ke-0..3 dalam bulan
    SELECT jsonb_agg(d ORDER BY (d->>'bucket')::INT) INTO v_trend FROM (
      SELECT jsonb_build_object(
        'bucket',  ((EXTRACT(DAY FROM date)::INT - 1) / 7)::TEXT,
        'income',  COALESCE(SUM(CASE WHEN type='income'  THEN amount ELSE 0 END), 0),
        'expense', COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0)
      ) d
      FROM public.transactions
      WHERE user_id = p_user_id AND date >= p_start AND date < p_end
      GROUP BY (EXTRACT(DAY FROM date)::INT - 1) / 7
    ) sub;

  ELSE -- year
    -- bucket = nomor bulan 1..12
    SELECT jsonb_agg(d ORDER BY (d->>'bucket')::INT) INTO v_trend FROM (
      SELECT jsonb_build_object(
        'bucket',  EXTRACT(MONTH FROM date)::INT::TEXT,
        'income',  COALESCE(SUM(CASE WHEN type='income'  THEN amount ELSE 0 END), 0),
        'expense', COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0)
      ) d
      FROM public.transactions
      WHERE user_id = p_user_id AND date >= p_start AND date < p_end
      GROUP BY EXTRACT(MONTH FROM date)::INT
    ) sub;
  END IF;

  RETURN json_build_object(
    'current_income',  v_curr_income,  'current_expense', v_curr_expense,
    'prev_income',     v_prev_income,  'prev_expense',    v_prev_expense,
    'categories',      COALESCE(v_categories, '[]'::jsonb),
    'trend',           COALESCE(v_trend,      '[]'::jsonb)
  );
END;
$$;

grant execute on function public.get_period_report(uuid, date, date, date, date, text) to authenticated;

-- ============================================================
-- FUNCTION: check_budget_alerts
-- Dipanggil oleh: ReportService.checkBudgetAlerts
-- Return: [{ category_id, category_name, budget, spent, percentage }]
-- ============================================================
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
    c.name                                                            as category_name,
    b.amount                                                          as budget,
    coalesce(t.spent, 0)                                              as spent,
    case
      when b.amount > 0
        then round((coalesce(t.spent, 0) / b.amount * 100)::numeric, 2)
      else 0::numeric
    end                                                               as percentage
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
  where b.user_id      = p_user_id
    and b.budget_year  = p_year
    and b.budget_month = p_month
  order by percentage desc;
end;
$$;

grant execute on function public.check_budget_alerts(uuid, integer, integer) to authenticated;
