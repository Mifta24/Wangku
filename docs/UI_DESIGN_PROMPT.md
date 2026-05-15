# UI Design Brief - Wangku

## Ringkasan Aplikasi

Wangku adalah aplikasi mobile personal finance untuk mencatat pemasukan, pengeluaran, melihat analisis, mengatur anggaran kategori, dan mengelola profil. Karakter UI harus terasa bersih, ringan, modern, mudah dipindai, dan cocok untuk penggunaan harian.

Target utama desain:

- Membantu pengguna memahami kondisi keuangan secara cepat.
- Membuat input transaksi terasa cepat dan tidak melelahkan.
- Menonjolkan status penting seperti saldo, pengeluaran, anggaran mendekati limit, dan kategori aktif.
- Menjaga tampilan tetap tenang, bukan terlalu dekoratif.

## Tema Visual

Tema utama memakai nuansa hijau finansial yang lembut dengan latar terang.

- Primary: hijau `#16A34A`
- Primary dark: `#15803D`
- Primary light: `#86EFAC`
- Background: hijau sangat muda `#F6FBF7`
- Surface/card: putih `#FFFFFF`
- Border: hijau pucat `#D1E7D6`
- Text utama: slate gelap `#0F172A`
- Text sekunder: `#475569`
- Hint: `#94A3B8`
- Income/success: hijau `#22C55E`
- Expense/error: merah `#EF4444`
- Warning: amber `#F59E0B`
- Info: biru `#0EA5E9`

Font utama adalah Inter. Gunakan Material 3, card putih dengan border halus, radius sedang, shadow ringan, dan spacing yang lega namun tetap efisien.

## Gaya Komponen

- App bar sederhana dengan judul `Wangku`, center aligned.
- Bottom navigation memiliki 5 tab: Home, Transaksi, Analisis, Anggaran, Profil.
- Card digunakan untuk ringkasan, metrik, transaksi terbaru, pengaturan, dan status anggaran.
- Input field berbentuk rounded rectangle, filled putih, border hijau pucat, focus border hijau.
- Tombol utama berwarna hijau dengan teks putih.
- Bottom sheet dipakai untuk form cepat seperti tambah transaksi, atur anggaran, kelola kategori, export, dan pengaturan profil.
- Ikon digunakan untuk memperjelas kategori, aksi, status pemasukan/pengeluaran, filter, kalender, dan profil.

## Halaman Aplikasi

### 1. Login

Halaman masuk memakai background gradient hijau muda ke putih. Konten berada di tengah dengan ilustrasi, headline `Selamat Datang di Wangku`, subtitle, field email, field password, tombol masuk, link lupa password, dan link daftar.

Mood halaman: ramah, aman, sederhana.

### 2. Register

Halaman daftar memiliki gaya yang konsisten dengan login. Ada tombol kembali, ilustrasi, judul `Buat Akun Baru`, subtitle, field nama lengkap, email, password, tombol daftar, dan link masuk. Terdapat cooldown saat mencoba daftar ulang.

Mood halaman: onboarding ringan dan meyakinkan.

### 3. Lupa Password

Halaman reset password memakai gradient auth yang sama. Konten terdiri dari tombol kembali, ilustrasi, judul `Lupa Password?`, penjelasan singkat, field email, dan tombol kirim link reset.

Mood halaman: membantu dan tidak membuat panik.

### 4. Dashboard / Home

Home adalah pusat ringkasan keuangan. Halaman ini menampilkan kartu metrik, saldo, transaksi terbaru, shortcut transaksi, dan tombol floating `Quick Add`. Quick Add membuka bottom sheet untuk memilih tipe transaksi, kategori, jumlah, catatan, tanggal, dan menyimpan transaksi.

Prioritas desain:

- Saldo dan arus kas harus mudah terbaca.
- Shortcut sering digunakan harus terasa cepat.
- Transaksi terbaru harus ringkas namun jelas.

### 5. Transaksi

Halaman transaksi berisi pemilih bulan, tombol filter, ringkasan pemasukan dan pengeluaran, saldo bulan ini, search bar, jumlah transaksi ditemukan, daftar transaksi, pull-to-refresh, load more, edit transaksi, dan hapus transaksi dengan swipe.

Prioritas desain:

- Filter dan search harus mudah dijangkau.
- Perbedaan pemasukan dan pengeluaran harus jelas lewat warna.
- List transaksi harus mudah dipindai berdasarkan kategori, catatan, tanggal, dan nominal.

### 6. Analisis / Reports

Halaman analisis menampilkan laporan harian, bulanan, dan tahunan. Ada tab periode, navigasi tanggal, ringkasan cashflow, surplus/defisit, chart tren, bar pemasukan/pengeluaran, breakdown kategori, dan informasi performa periode.

Prioritas desain:

- Data visual harus bersih dan tidak ramai.
- Angka utama seperti surplus/defisit harus menjadi fokus.
- Grafik dan breakdown kategori harus mudah dibandingkan.

### 7. Anggaran

Halaman anggaran menampilkan `Anggaran & Pengingat`, ringkasan total anggaran bulan ini, progress penggunaan anggaran, sisa anggaran, warning jika mendekati limit, daftar anggaran per kategori, sorting, tombol tambah, empty state, dan bottom sheet untuk menyimpan anggaran kategori.

Prioritas desain:

- Progress bar harus langsung menunjukkan kondisi aman atau warning.
- Kategori yang mendekati limit harus lebih menonjol.
- Empty state harus menjelaskan langkah berikutnya dengan singkat.

### 8. Profil

Halaman profil menampilkan email pengguna, section pengaturan, dan daftar menu: manajemen kategori, akun dan profil, manajemen shortcut, export transaksi, manajemen notifikasi, serta tombol logout.

Prioritas desain:

- Pengaturan harus terlihat seperti daftar aksi yang rapi.
- Tiap item perlu ikon, judul, deskripsi singkat, dan tombol aksi.
- Logout memakai warna error agar jelas sebagai aksi penting.

## Prompt UI Design

Gunakan prompt ini untuk meminta AI membuat konsep UI/UX atau desain Figma untuk Wangku:

```text
Buat desain UI mobile app bernama Wangku, aplikasi personal finance untuk mencatat pemasukan, pengeluaran, analisis laporan, anggaran kategori, dan profil pengguna.

Gunakan gaya modern, clean, light, dan financial-friendly. Tema utama hijau dengan background hijau sangat muda dan card putih. Gunakan font Inter, Material 3 style, rounded cards, border halus, shadow ringan, spacing rapi, dan ikon yang jelas.

Palet warna:
- Primary #16A34A
- Primary dark #15803D
- Primary light #86EFAC
- Background #F6FBF7
- Surface #FFFFFF
- Border #D1E7D6
- Text primary #0F172A
- Text secondary #475569
- Hint #94A3B8
- Income #22C55E
- Expense #EF4444
- Warning #F59E0B
- Info #0EA5E9

Buat seluruh screen berikut:
1. Login: gradient hijau muda ke putih, ilustrasi, headline "Selamat Datang di Wangku", field email/password, lupa password, tombol masuk, link daftar.
2. Register: tombol kembali, ilustrasi, headline "Buat Akun Baru", field nama/email/password, tombol daftar, link masuk.
3. Forgot Password: tombol kembali, ilustrasi, field email, tombol kirim link reset.
4. Home Dashboard: app bar "Wangku", kartu saldo/ringkasan keuangan, shortcut transaksi, transaksi terbaru, floating action button "Quick Add".
5. Quick Add Bottom Sheet: pilihan pengeluaran/pemasukan, kategori, jumlah, catatan, tanggal, tombol simpan.
6. Transaksi: month picker, tombol filter, kartu pemasukan/pengeluaran, saldo bulan ini, search bar, daftar transaksi, load more, empty state.
7. Analisis: tab harian/bulanan/tahunan, navigasi periode, ringkasan surplus/defisit, chart tren, bar pemasukan vs pengeluaran, breakdown kategori.
8. Anggaran: total anggaran bulan ini, progress bar, sisa anggaran, warning limit, daftar anggaran per kategori, tombol tambah, empty state, bottom sheet atur anggaran.
9. Profil: email pengguna, menu manajemen kategori, akun profil, shortcut, export transaksi, notifikasi, dan tombol logout.

Pastikan desain mobile-first, mudah dipindai, nyaman untuk penggunaan harian, tidak terlalu ramai, dan semua angka Rupiah terlihat jelas. Bedakan pemasukan dengan hijau, pengeluaran dengan merah, dan warning anggaran dengan amber.
```

## Catatan Implementasi Desain

- Jaga konsistensi radius card dan input di kisaran 12-16 px.
- Gunakan progress indicator untuk anggaran dan cashflow.
- Pakai bottom sheet untuk form agar pengguna tidak berpindah konteks.
- Hindari halaman yang terlalu dekoratif; Wangku lebih cocok sebagai tool finansial yang tenang dan praktis.
- Pastikan setiap empty state memiliki pesan singkat dan aksi berikutnya.
