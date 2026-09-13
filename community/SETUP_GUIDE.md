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

## 6. Set Developer pertama
Developer (role paling atas) **gak bisa** diangkat dari panel web — sengaja,
biar gak ada yang bisa naikin diri sendiri jadi developer lewat exploit.

1. Daftar akun pertama kamu lewat website (`community/signup.html`) seperti biasa.
2. Balik ke Supabase → **SQL Editor**, jalankan:
   ```sql
   update public.profiles set role = 'developer' where username = 'USERNAME_KAMU';
   ```
3. Sekarang akun kamu bisa akses `community/developer.html` buat angkat/turunin Admin.

## 7. Deploy
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

## File yang perlu kamu isi
- `community/supabase-client.js` → URL & anon key Supabase (wajib).

Semua kode lain udah siap pakai, gak perlu diubah lagi.
