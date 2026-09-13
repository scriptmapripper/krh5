-- =========================================================
--  Set akun knlvx_aura jadi Developer (role tertinggi)
--  Jalankan di Supabase Dashboard > SQL Editor SETELAH akun
--  ini sudah daftar lewat community/signup.html.
--
--  Aman dijalankan berkali-kali (idempotent) — kalau sudah
--  developer, query ini gak ngubah apa-apa lagi.
--
--  Catatan: role 'developer' sengaja gak bisa diangkat lewat
--  panel web (community/developer.html), makanya harus lewat
--  SQL manual kayak gini.
--
--  PENTING: yang dicocokkan adalah kolom "username" (dari
--  Account Settings > Username), BUKAN "krunker_username".
--  Cek dulu username yang bener di community/settings.html
--  kalau ternyata berbeda dari yang ada di sini.
-- =========================================================

update public.profiles
set role = 'developer'
where username = 'knlvx_aura'
  and role <> 'developer';

-- Cek hasilnya:
select id, username, display_name, role
from public.profiles
where username = 'knlvx_aura';
