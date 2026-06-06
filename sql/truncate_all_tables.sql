-- ================================================================
-- WANGKU — TRUNCATE ALL USER DATA
-- Jalankan di SQL Editor Supabase untuk hapus semua data.
-- Data kategori sistem (global) akan diisi ulang otomatis.
-- ================================================================

truncate table
  public.notifications,
  public.budgets,
  public.transactions,
  public.profiles,
  public.categories
cascade;

-- Re-insert kategori sistem agar app tetap bisa dipakai
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
