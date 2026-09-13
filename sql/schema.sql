-- =========================================================
--  Krunker Resource Hub — Account / Role / Post system
--  Jalankan seluruh file ini di Supabase Dashboard > SQL Editor
--  Versi RERUNNABLE — aman dijalankan berkali-kali, gak akan
--  error "already exists" walaupun tabel/policy udah ada.
-- =========================================================

-- ---------- 1. Table: profiles ----------
-- Satu baris per user, dibuat manual saat signup (bukan trigger),
-- supaya semua field tambahan (nama, tgl lahir, dll) langsung terisi.
create table if not exists public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  username        text unique not null,
  display_name    text not null,
  birthdate       date not null,
  gender          text not null check (gender in ('male','female','other','prefer_not_to_say')),
  krunker_username text,
  discord_id      text,
  discord_username text,
  role            text not null default 'user' check (role in ('user','admin','developer')),
  created_at      timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Semua orang (termasuk yang belum login) boleh lihat profil dasar
-- (dibutuhkan supaya nama penulis post bisa ditampilkan di feed publik)
drop policy if exists "profiles_public_read" on public.profiles;
create policy "profiles_public_read"
on public.profiles for select
using (true);

-- User cuma boleh bikin profil untuk dirinya sendiri, role wajib 'user'
drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self"
on public.profiles for insert
with check (auth.uid() = id and role = 'user');

-- User boleh update profil sendiri, TAPI TIDAK BOLEH ganti role-nya sendiri
drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self"
on public.profiles for update
using (auth.uid() = id)
with check (
  auth.uid() = id
  and role = (select role from public.profiles where id = auth.uid())
);

-- Developer boleh update profil siapa saja (termasuk ganti role -> admin/dev)
drop policy if exists "profiles_update_by_developer" on public.profiles;
create policy "profiles_update_by_developer"
on public.profiles for update
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'developer')
)
with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'developer')
);


-- ---------- 2. Table: posts ----------
create table if not exists public.posts (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid not null references public.profiles(id) on delete cascade,
  title       text not null,
  content     text not null,
  status      text not null default 'draft' check (status in ('draft','published')),
  category    text not null default 'crosshair' check (category in (
    'crosshair','crosshair-scope','crosshair-hitmarker','settings-ready','css-ready',
    'maps-official-infected','maps-official-tdm','maps-custom-parkour',
    'mods-files','scripts-userscript-legal','scripts-userscript-hack','scripts-krunkscript-usable'
  )),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Kalau tabel posts sudah pernah dibuat SEBELUM kolom category ada,
-- jalankan ini aja (aman dijalankan berkali-kali):
-- alter table public.posts add column if not exists category text not null default 'crosshair' check (category in (
--   'crosshair','crosshair-scope','crosshair-hitmarker','settings-ready','css-ready',
--   'maps-official-infected','maps-official-tdm','maps-custom-parkour',
--   'mods-files','scripts-userscript-legal','scripts-userscript-hack','scripts-krunkscript-usable'
-- ));

alter table public.posts enable row level security;

-- Post published boleh dibaca siapa saja (termasuk yang belum login)
drop policy if exists "posts_public_read_published" on public.posts;
create policy "posts_public_read_published"
on public.posts for select
using (status = 'published');

-- Penulis boleh baca post draft miliknya sendiri
drop policy if exists "posts_owner_read_own" on public.posts;
create policy "posts_owner_read_own"
on public.posts for select
using (auth.uid() = author_id);

-- Admin & developer boleh baca SEMUA post (termasuk draft orang lain)
drop policy if exists "posts_staff_read_all" on public.posts;
create policy "posts_staff_read_all"
on public.posts for select
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','developer'))
);

-- Cuma user yang sudah login & sudah punya profil yang boleh bikin post,
-- dan author_id wajib dirinya sendiri
drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own"
on public.posts for insert
with check (auth.uid() = author_id);

-- Penulis boleh edit post-nya sendiri
drop policy if exists "posts_update_own" on public.posts;
create policy "posts_update_own"
on public.posts for update
using (auth.uid() = author_id)
with check (auth.uid() = author_id);

-- Admin & developer boleh edit (mis. publish/unpublish) post siapa saja
drop policy if exists "posts_update_staff" on public.posts;
create policy "posts_update_staff"
on public.posts for update
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','developer'))
);

-- Penulis boleh hapus post-nya sendiri
drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_delete_own"
on public.posts for delete
using (auth.uid() = author_id);

-- Admin & developer boleh hapus post siapa saja
drop policy if exists "posts_delete_staff" on public.posts;
create policy "posts_delete_staff"
on public.posts for delete
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','developer'))
);

-- auto-update updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_posts_updated_at on public.posts;
create trigger trg_posts_updated_at
before update on public.posts
for each row execute function public.set_updated_at();

-- =========================================================
-- CATATAN PENTING
-- =========================================================
-- 1. Developer PERTAMA harus di-set manual lewat SQL Editor, contoh:
--      update public.profiles set role = 'developer' where username = 'USERNAME_KAMU';
--    Jalankan ini SETELAH kamu daftar akun pertama kali lewat website.
--    (Lihat juga sql/set_developer.sql — sudah disiapkan untuk akun knlvx_aura.)
--
-- 2. Setelah itu, Developer bisa angkat/turunin Admin lewat halaman
--    /community/developer.html (tidak perlu SQL lagi).
--
-- 3. Role 'developer' TIDAK BISA diangkat dari panel web (sengaja),
--    biar gak ada admin yang bisa naikin diri sendiri jadi developer.
--    Kalau mau nambah developer baru, jalankan SQL update di atas manual.
