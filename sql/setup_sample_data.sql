-- Wangku Sample Data Setup Script for Supabase
-- Run this AFTER 01_schema_and_policies.sql

-- Safety check: ensure required tables already exist
select
  to_regclass('public.categories') as categories_table,
  to_regclass('public.transactions') as transactions_table;

-- 1. Insert/update sample categories for EXPENSE (idempotent)
insert into categories (name, icon, color, type) values
  ('Makanan', '🍔', '#FF6B6B', 'expense'),
  ('Transportasi', '🚗', '#4ECDC4', 'expense'),
  ('Hiburan', '🎬', '#FFE66D', 'expense'),
  ('Belanja', '🛍️', '#95E1D3', 'expense'),
  ('Kesehatan', '⚕️', '#F38181', 'expense'),
  ('Utilitas', '💡', '#95E1D3', 'expense'),
  ('Pendidikan', '📚', '#A8E6CF', 'expense')
on conflict (name, type) do update
set
  icon = excluded.icon,
  color = excluded.color,
  updated_at = now();

-- 2. Insert/update sample categories for INCOME (idempotent)
insert into categories (name, icon, color, type) values
  ('Gaji', '💰', '#6BCB77', 'income'),
  ('Bonus', '🎁', '#4D96FF', 'income'),
  ('Freelance', '💻', '#6BCB77', 'income'),
  ('Investasi', '📈', '#FFD700', 'income')
on conflict (name, type) do update
set
  icon = excluded.icon,
  color = excluded.color,
  updated_at = now();

-- 3. Verify categories were inserted
select * from categories order by type, name;

-- 4. (Optional) Insert sample transactions for a user
-- NOTE: Replace 'USER_ID_HERE' dengan actual user ID dari auth.users table
-- You can get it from: SELECT id, email FROM auth.users;

-- Uncomment and modify below to add sample transactions
/*
INSERT INTO transactions (id, user_id, category_id, amount, note, date, type, created_at) VALUES
  (gen_random_uuid(), 'USER_ID_HERE', (SELECT id FROM categories WHERE name = 'Makanan' LIMIT 1), 50000, 'Makan siang', now() - interval '2 days', 'expense', now()),
  (gen_random_uuid(), 'USER_ID_HERE', (SELECT id FROM categories WHERE name = 'Transportasi' LIMIT 1), 25000, 'Bensin mobil', now() - interval '1 day', 'expense', now()),
  (gen_random_uuid(), 'USER_ID_HERE', (SELECT id FROM categories WHERE name = 'Gaji' LIMIT 1), 5000000, 'Gaji bulanan', now(), 'income', now()),
  (gen_random_uuid(), 'USER_ID_HERE', (SELECT id FROM categories WHERE name = 'Hiburan' LIMIT 1), 150000, 'Bioskop', now() - interval '3 days', 'expense', now());
*/

-- 5. Check table row counts
select
  (select count(*) from categories) as category_count,
  (select count(*) from transactions) as transaction_count,
  (select count(*) from auth.users) as user_count;

-- Notes:
-- - Categories are pre-populated globally (no user_id needed)
-- - Transactions require a valid user_id from auth.users
-- - RLS (Row Level Security) policies should allow users to see only their own transactions
-- - Make sure RLS is properly configured in Supabase Dashboard > Authentication > Policies
