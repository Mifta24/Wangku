-- Wangku Schema Migration: Custom Categories
-- Jalankan script ini di Supabase SQL Editor Anda

-- 1) Tambahkan kolom user_id ke tabel categories (nullable)
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- 2) Hapus policy lama (yang read-only)
DROP POLICY IF EXISTS "Authenticated can read categories" ON public.categories;

-- 3) Tambahkan policy baru untuk membaca kategori
-- User bisa membaca kategori bawaan sistem (user_id IS NULL) ATAU kategori milik user itu sendiri
CREATE POLICY "Users can read system and own categories"
ON public.categories
FOR SELECT
TO authenticated
USING (user_id IS NULL OR user_id = auth.uid());

-- 4) Tambahkan policy untuk membuat (insert) kategori
-- User HANYA bisa membuat kategori jika user_id sesuai dengan id mereka
CREATE POLICY "Users can insert own categories"
ON public.categories
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- 5) Tambahkan policy untuk menghapus (delete) kategori (opsional, jika ingin mendukung fitur hapus kategori custom)
CREATE POLICY "Users can delete own categories"
ON public.categories
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- 6) Update constraint UNIQUE pada categories
-- Sebelumnya constraint adalah: unique (name, type)
-- Sekarang kita harus menambahkan user_id, agar dua user berbeda bisa membuat kategori dengan nama sama,
-- tetapi sistem tidak boleh ada kategori kembar untuk satu user,
-- DAN kita perlu menangani nilai null pada user_id.

-- Drop constraint unik lama
ALTER TABLE public.categories DROP CONSTRAINT IF EXISTS categories_name_type_unique;

-- Buat index unik bersyarat untuk kategori global (sistem)
CREATE UNIQUE INDEX IF NOT EXISTS categories_name_type_global_idx 
ON public.categories (name, type) 
WHERE user_id IS NULL;

-- Buat index unik bersyarat untuk kategori per user
CREATE UNIQUE INDEX IF NOT EXISTS categories_name_type_user_idx 
ON public.categories (name, type, user_id) 
WHERE user_id IS NOT NULL;
