# Rencana Pengembangan "Wangku" - Aplikasi Keuangan Pribadi

Konsep aplikasi, fitur, dan tech stack yang Anda rancang sudah **sangat terstruktur, modern, dan sangat cocok** untuk aplikasi skala produksi maupun sebagai sebuah skripsi/proyek portofolio. Pemilihan *tech stack* menunjukkan pemahaman yang baik tentang pengembangan aplikasi *mobile* modern.

Berikut adalah sedikit *review* dari saya beserta rencana implementasinya.

## 🌟 Review Tech Stack & Saran

> [!TIP]
> **Saran Tambahan untuk Tech Stack:**
> 1. **Dio vs Supabase Client:** Anda memasukkan `dio` untuk komunikasi API. Perlu diingat bahwa `supabase_flutter` sudah memiliki *client* HTTP bawaan yang kuat untuk komunikasi ke *database* dan *auth* Supabase. Anda mungkin **tidak** membutuhkan `dio` kecuali ingin memanggil API pihak ketiga (misalnya API kurs mata uang atau integrasi lain).
> 2. **Provider:** Penggunaan `provider` sangat bagus dan mudah dipahami. Namun, jika Anda ingin *state management* yang lebih tangguh dan mudah di-tes (serta disukai penguji skripsi karena lebih modern), Anda bisa mempertimbangkan **Riverpod**, karena ia dibuat oleh pembuat yang sama dengan Provider tapi menangani banyak kelemahan Provider. Namun, `provider` pun sudah sangat cukup!
> 3. **Offline-first:** Anda menggunakan `hive` untuk database lokal. Saat mengambil data dari Supabase, kita akan menyimpan (cache) datanya di Hive agar aplikasi tetap bisa dipakai ketika tidak ada internet. Ini adalah arsitektur yang fantastis, sering disebut *Repository Pattern* dengan *Local & Remote Data Source*.

---

## 📋 Rencana Implementasi Bertahap

Untuk membuat aplikasi sebesar ini, kita harus membaginya menjadi beberapa fase (Step-by-step).

### Fase 1: Inisiasi Proyek & Setup Core System
- [ ] Inisialisasi proyek Flutter baru.
- [ ] Konfigurasi `supabase_flutter` (membutuhkan URL dan Anon Key dari proyek Supabase Anda).
- [ ] Pengaturan tema dasar, warna, dan tipografi menggunakan `google_fonts` dan `flutter_screenutil`.
- [ ] Setup `freezed` dan `json_serializable` untuk membuat sistem model data yang *clean* (seperti `Transaction`, `User`, `Category`).
- [ ] Setup *routing* aplikasi (menggunakan `go_router` jika berkenan, atau routing bawaan).

### Fase 2: Sistem Autentikasi & Database
- [ ] Membuat UI Login, Register, dan Lupa Password.
- [ ] Menghubungkan fungsi *Auth* ke Supabase.
- [ ] Setup *database* di Supabase (Tabel: `users`, `transactions`, `categories`).
- [ ] Implementasi Session handling (menyimpan status login dengan `shared_preferences` / supabase builtin session).

### Fase 3: Dashboard & Transaksi (Core Feature)
- [ ] Membuat UI Navbar bawah dan struktur Menu utama.
- [ ] Membuat fitur "Quick Add" input menggunakan Modal Bottom Sheet.
- [ ] Mengatur logika penyimpanan transaksi ke `hive` (lokal) lalu disinkronkan ke `supabase` (remote).
- [ ] Membuat UI daftar transaksi (Home) dengan format uang menggunakan `intl`.

### Fase 4: Analisis dan Visualisasi Data (Fitur Utama)
- [ ] Implementasi `fl_chart` untuk Bar Chart laporan Pemasukan/Pengeluaran bulanan.
- [ ] Implementasi `fl_chart` untuk Pie Chart distribusi kategori pengeluaran terbesar.
- [ ] Membuat filter dinamis menggunakan `table_calendar` untuk membatasi rentang tanggal.

### Fase 5: Notifikasi & Reminder
- [ ] Konfigurasi `flutter_local_notifications` dan `timezone`.
- [ ] Membuat UI bagi user untuk bisa memilih jam notifikasi pengingat pencatatan.
- [ ] Membuat *background task* / trigger pengecekan saat transaksi baru diinput: apakah total pengeluaran sudah mendekati batas *budget*? Jika ya, tampilkan notifikasi.

---

## ⚠️ Pertanyaan Terbuka / Persetujuan

> [!IMPORTANT]
> Sebelum kita mulai menulis kode, ada beberapa hal yang perlu dikonfirmasi kepada Anda:

1. **State Management:** Apakah Anda *fix* ingin menggunakan `provider`, atau terbuka mencoba `riverpod` (keduanya tidak jauh berbeda, namun `riverpod` sedikit lebih modern)?
2. **Setup Supabase:** Apakah Anda sudah membuat *project* di Supabase? Nantinya Anda perlu memberikan `SUPABASE_URL` dan `SUPABASE_ANON_KEY` agar kita bisa mengkoneksikannya di dalam aplikasi.
3. **Mulai dari mana:** Jika Anda setuju dengan rencana ini, apakah Anda ingin saya langsung **membuat (inisialisasi) project Flutter** di folder ini (`c:\Aplikasi-Mobile\Wangku`) sekarang?

Silakan balas dan kita akan mulai *coding* tahap persiapan aplikasinya!
