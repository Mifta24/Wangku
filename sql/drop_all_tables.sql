-- ================================================================
-- WANGKU — DROP ALL TABLES & FUNCTIONS
-- Jalankan SEBELUM setup_table.sql untuk reset total.
-- ================================================================

-- Drop trigger auth.users (tidak ikut terhapus saat drop table)
drop trigger if exists on_auth_user_created on auth.users;

-- Drop tables (CASCADE otomatis hapus trigger, policy, index, FK)
drop table if exists public.shortcuts    cascade;
drop table if exists public.budgets      cascade;
drop table if exists public.transactions cascade;
drop table if exists public.notifications cascade;
drop table if exists public.categories   cascade;
drop table if exists public.profiles     cascade;

-- Drop RPC functions
drop function if exists public.check_budget_alerts(uuid, integer, integer);
drop function if exists public.get_period_report(uuid, date, date, date, date, text);
drop function if exists public.get_monthly_aggregates(uuid, date, date);

-- Drop helper functions
drop function if exists public.handle_new_user();
drop function if exists public.set_updated_at();
