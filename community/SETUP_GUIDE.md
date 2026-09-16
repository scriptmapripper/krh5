# Panduan Setup — Sistem Akun & Role

Situs kamu itu **static** (HTML/JS doang, di-host di GitHub Pages). Biar sistem
login/role beneran aman (bukan cuma localStorage yang gampang dibobol lewat
console browser), semuanya jalan lewat **Supabase** — backend gratisan
(database + auth + Discord OAuth udah built-in).

## 1. Bikin project Supabase
1. Buka https://supabase.com → Sign up (bisa pakai GitHub) → **New Project**.
2. Kasih nama bebas, set password database (simpan baik-baik), pilih region
   terdekat (Singapore paling deket ke Indonesia).
3. Tunggu ~2 menit sampai project selesai dibuat.

## 2. Jalankan schema database
1. Di sidebar Supabase, buka **SQL Editor**.
2. Copy semua isi file `sql/schema.sql` (ada di folder ini), paste, klik **Run**.
3. Ini bikin tabel `profiles` (data user) dan `posts` (post), plus aturan
   keamanan (RLS) yang beneran ngunci siapa boleh apa.

## 3. Ambil URL & API Key
1. Sidebar → **Project Settings** → **API**.
2. Copy **Project URL** dan key yang namanya **publishable** (di project baru,
   Supabase udah ganti nama dari "anon public" jadi "publishable" — fungsinya
   sama, aman dipakai di kode publik).
3. Buka `community/supabase-client.js`, isi 2 baris paling atas.

⚠️ **JANGAN PERNAH** pakai key yang namanya **secret** (dulu disebut
"service_role") di file manapun yang masuk ke situs/repo. Key itu bisa akses
seluruh database tanpa batas, bypass semua aturan keamanan (RLS). Situs kamu
statis dan gak butuh key itu sama sekali — simpan aja di tempat aman,
jangan ditaruh di kode.

## 4. Setup Discord OAuth (buat verifikasi identitas saat daftar)
1. Buka https://discord.com/developers/applications → **New Application**.
2. Masuk ke tab **OAuth2** → catat **Client ID** dan **Client Secret**.
3. Di **OAuth2 > Redirects**, tambahin redirect URL dari Supabase
   (formatnya `https://xxxxxxxx.supabase.co/auth/v1/callback` — bisa dicopy
   dari langkah berikutnya).
4. Balik ke Supabase → **Authentication** → **Providers** → cari **Discord**
   → aktifkan → paste Client ID & Client Secret dari Discord → Save.
5. Di Supabase → **Authentication** → **URL Configuration**, tambahin domain
   situs kamu (misal `https://username.github.io`) ke **Redirect URLs**,
   biar abis connect Discord dia balik lagi ke situs kamu.

## 5. Matiin email confirmation (opsional, biar bisa langsung login)
Supabase default-nya minta user klik link konfirmasi di email dulu sebelum
bisa login. Kalau situs kamu belum ada email server sendiri dan mau user
langsung bisa pakai akun:
1. **Authentication** → **Providers** → **Email** → matiin **Confirm email**.

Kalau mau tetep aktif (lebih aman dari akun spam), biarin default nyala aja.

## 6. Aktifin Reset Password (Lupa Password)
Halaman `login.html` sekarang ada link "Forgot your password?" yang ngirim
email reset via Supabase. Biar linknya balik lagi ke situs kamu (bukan
localhost bawaan Supabase):
1. Supabase → **Authentication** → **URL Configuration**.
2. Di **Redirect URLs**, pastiin domain situs kamu udah ada (harusnya udah
   ditambahin di langkah 4.5 di atas) — kalau situs kamu di GitHub Pages,
   ini juga otomatis nge-cover `community/reset-password.html`.
3. Selesai — user tinggal klik "Forgot your password?" di halaman login,
   masukin email, dan ikutin link yang dikirim ke inbox mereka.

## 7. Set Developer pertama
Developer (role paling atas) **gak bisa** diangkat dari panel web — sengaja,
biar gak ada yang bisa naikin diri sendiri jadi developer lewat exploit.

1. Daftar akun pertama kamu lewat website (`community/signup.html`) seperti biasa.
2. Balik ke Supabase → **SQL Editor**, jalankan:
   ```sql
   update public.profiles set role = 'developer' where username = 'USERNAME_KAMU';
   ```
3. Sekarang akun kamu bisa akses `community/developer.html` buat angkat/turunin Admin.

## 8. Deploy
Push semua file (termasuk folder `community/` dan `sql/`) ke GitHub Pages
seperti biasa. `sql/schema.sql` boleh tetep ada di repo (isinya cuma
struktur database, bukan data rahasia) — tapi kalau mau lebih rapi, boleh
juga taruh di luar folder yang di-publish.

## Ringkasan alur user
- **Belum login** → cuma bisa liat post yang published (view only).
- **Daftar** → connect Discord dulu (verifikasi identitas) → isi nama,
  username, email, password, tanggal lahir, gender, username Krunker →
  akun jadi.
- **User biasa** (login) → bisa bikin post, publish/unpublish, edit, hapus
  post **miliknya sendiri**.
- **Admin** → bisa publish/unpublish & hapus **post siapa aja**, gak bisa
  atur role user.
- **Developer** → semua kemampuan Admin + bisa angkat/turunin Admin lewat
  `community/developer.html`.

## Custom Crosshair Maker & tab Crosshairs
- `crosshair-maker.html` (di root, bukan di `community/`) — tool bikin crosshair
  sendiri (warna, ketebalan, panjang, gap, dot, outline, T-style), preview
  langsung di canvas, dan tombol **Copy Code** buat nyalin hasilnya.
- `community/crosshairs.html` — galeri crosshair yang udah dipost orang lain.
  Bisa dilihat semua orang (gak perlu login), tapi cuma yang login yang bisa
  **post crosshair sendiri**. Tombol "Post this Crosshair" di Crosshair Maker
  otomatis bawa code-nya ke sini.
- Ini pakai tabel `posts` yang sama dengan sistem post biasa, cuma dibedain
  lewat kolom `category` (`general` atau `crosshair`). Kalau project Supabase
  kamu **udah pernah dijalankan schema-nya sebelum ini**, jalankan tambahan
  ini di SQL Editor:
  ```sql
  alter table public.posts add column if not exists category text not null default 'general' check (category in ('general','crosshair'));
  ```
  Kalau baru mau setup dari nol, cukup jalankan `sql/schema.sql` versi
  terbaru — kolom ini udah termasuk di situ.

## Section Overlay & Icons (Crosshair)
- **Overlay** sekarang cuma jadi folder — isinya dua subtab:
  `Damage Overlays` dan `Game Overlays`.
- **Icons** punya empat subtab: `Kill`, `Death`, `Ammo`, `Streak Counter`.
- Keenam subtab itu pakai `community/image-section.html` — form post-nya
  **Name**, **upload 1 gambar (PNG)**, dan **Description**. Gambarnya masuk
  bucket `crosshairs`, datanya disimpan di kolom `content` sebagai JSON
  `{ file_url, description }`.
- Sebelum dipakai, jalankan `sql/add_overlay_category.sql` di Supabase SQL
  Editor supaya kategori barunya lolos constraint.

## File yang perlu kamu isi
- `community/supabase-client.js` → URL & anon key Supabase (wajib).

Semua kode lain udah siap pakai, gak perlu diubah lagi.

## History Logs (audit trail aksi staff)
- **Wajib jalankan `sql/add_history_logs.sql`** di Supabase SQL Editor dulu.
  Kalau belum, halaman History Logs bakal nampilin pesan error.
- Halamannya: `community/logs.html`, link-nya otomatis muncul di topnav
  Dashboard / Admin Panel / Developer Panel **khusus admin & developer**.
- Yang dicatat otomatis:
  - Post: publish, unpublish, edit (staff ke post orang lain), delete
  - User: ban, unban, warn
  - Role: kasih / cabut Admin
  - Ban appeal: approve, reject
  - Komentar: hapus komentar orang lain
  Aksi ke milik sendiri (edit/hapus post sendiri) **tidak** dicatat —
  ini log moderasi, bukan log aktivitas pribadi.
- Tabelnya **append-only**: gak ada policy UPDATE/DELETE sama sekali,
  jadi log gak bisa diedit atau dihapus lewat website — termasuk oleh
  developer. Kalau mau bersih-bersih log lama, ada query manualnya di
  bagian bawah `sql/add_history_logs.sql`.
- Log nyimpen **snapshot** username & judul post, jadi entry-nya tetap
  kebaca walaupun post-nya udah dihapus atau akunnya udah hilang.
- **Catatan performa**: halaman logs cuma narik 25 baris per halaman dan
  semua filter/sort/paging dikerjakan di database. Kalau kamu sudah pernah
  jalanin versi lama file SQL-nya, **jalanin ulang** `sql/add_history_logs.sql`
  — index & policy-nya diperbarui, datanya aman.
- Mau nambah jenis aksi baru? Tambahin nama aksinya di `check (action in (...))`
  pada SQL, terus di `LOG_ACTIONS` (supabase-client.js) dan `describe()`
  (logs.html) buat label + kalimatnya.

## Rate Limiting (anti-spam post & komentar)
- **Wajib jalankan `sql/add_rate_limiting.sql`** di Supabase SQL Editor.
- Nahan post <20 detik dan komentar <5 detik dari yang terakhir, per user.
  Ini dicek di **database** (trigger), bukan cuma di JS — jadi tetap
  ngeblok walaupun orang manggil Supabase API langsung lewat script,
  gak lewat website sama sekali.
- Admin & developer dikecualikan dari limit ini.
- Kalau kena limit, pesan errornya otomatis muncul di kotak pesan form
  (post/komentar) — gak perlu ubah kode apa-apa lagi.

## Upload Size Limit (crosshair image, CSS file & preview, other file posts)
- Sudah aktif otomatis, gak perlu setup tambahan.
- Batasnya per **jenis file**, bukan per role: file biasa (gambar, .txt,
  .css, .js, dll) maks **5MB**. Khusus file **.zip** (dipakai di kategori
  Mods — Mods Files) maks **30MB**.
- Ini validasi di sisi client (JS) — cukup buat nahan upload gak sengaja
  kegedean dan mencegah storage boros dari pemakaian normal. Ini BUKAN
  proteksi keamanan (orang yang niat bisa saja upload langsung lewat API),
  jadi kalau storage abuse jadi masalah serius, tambahin juga batas ukuran
  di **Supabase Dashboard > Storage > (bucket) > Settings** per bucket
  (`crosshairs`, `post-files`, `post-previews`) biar dijaga di server juga.
- Mau ubah angkanya? Edit `UPLOAD_MAX_BYTES_DEFAULT` dan
  `UPLOAD_MAX_BYTES_ZIP` di `community/supabase-client.js`.

## CAPTCHA / Anti-Bot di Signup (opsional, tapi disarankan)
Signup udah wajib connect Discord dulu sebagai langkah 1, jadi itu udah
jadi penghalang cukup besar buat bot biasa. Kalau mau nambah lapisan lagi
(misal situs makin dikenal dan mulai kena bot-registration beneran):
1. Buka https://dash.cloudflare.com/?to=/:account/turnstile → bikin widget
   baru (Cloudflare Turnstile, gratis). Domain apa aja boleh buat testing.
2. Copy **Site Key**, paste ke `TURNSTILE_SITE_KEY` di bagian atas script
   `community/signup.html`.
3. Copy **Secret Key**, paste di Supabase Dashboard → **Authentication** →
   **Settings** → **Bot and Abuse Protection** → aktifin **Turnstile** →
   paste secret key-nya di situ → Save.
4. Selesai — Supabase yang verifikasi token-nya di server, situsmu gak
   perlu backend tambahan. Kalau `TURNSTILE_SITE_KEY` dibiarkan kosong,
   signup jalan seperti biasa tanpa captcha (default sekarang).
