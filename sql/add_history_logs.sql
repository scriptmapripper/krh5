-- =========================================================
--  Migration: History Logs (Audit Trail)
--  Jalankan SEKALI di Supabase Dashboard > SQL Editor.
--  Versi RERUNNABLE — aman dijalankan berkali-kali.
--
--  Tabel ini mencatat semua aksi staff (admin/developer):
--  publish/unpublish/hapus/edit post, ban/unban user, kasih/cabut
--  role admin, approve/reject ban appeal, warn user, hapus komentar.
--
--  PENTING: tabel ini sengaja dibuat APPEND-ONLY.
--  Tidak ada policy UPDATE maupun DELETE, jadi log tidak bisa
--  diubah atau dihapus lewat website — termasuk oleh developer.
--  Kalau memang perlu bersih-bersih log lama, lihat bagian
--  "PEMBERSIHAN LOG" di paling bawah file ini.
-- =========================================================

-- ---------- 1. Table: activity_logs ----------
create table if not exists public.activity_logs (
  id                 uuid primary key default gen_random_uuid(),

  -- Siapa yang melakukan aksi. Di-snapshot (username/display_name/role
  -- disimpan sebagai text) supaya log tetap kebaca walaupun akunnya
  -- dihapus atau rolenya berubah di kemudian hari.
  actor_id           uuid references public.profiles(id) on delete set null,
  actor_username     text,
  actor_display_name text,
  actor_role         text,

  action             text not null check (action in (
    'post_publish','post_unpublish','post_delete','post_edit',
    'user_ban','user_unban','user_warn',
    'role_grant_admin','role_revoke_admin',
    'appeal_approve','appeal_reject',
    'comment_delete'
  )),

  -- Objek yang kena aksi. target_id sengaja TEXT (bukan FK) supaya
  -- log post yang sudah dihapus tetap nyimpen id aslinya.
  target_type        text check (target_type in ('post','user','appeal','comment')),
  target_id          text,
  target_label       text,   -- snapshot: judul post / username user
  target_user_id     uuid references public.profiles(id) on delete set null,

  reason             text,   -- alasan ban / catatan reject / pesan warning
  meta               jsonb not null default '{}'::jsonb,
  created_at         timestamptz not null default now()
);

alter table public.activity_logs enable row level security;

-- ---------- 2. Index ----------
create index if not exists activity_logs_created_at_idx     on public.activity_logs (created_at desc);
create index if not exists activity_logs_action_idx         on public.activity_logs (action);
create index if not exists activity_logs_actor_id_idx       on public.activity_logs (actor_id);
create index if not exists activity_logs_target_user_id_idx on public.activity_logs (target_user_id);

-- ---------- 3. RLS: siapa yang boleh BACA ----------
-- Hanya admin & developer. User biasa tidak bisa melihat log sama sekali.
drop policy if exists "activity_logs_staff_read" on public.activity_logs;
create policy "activity_logs_staff_read"
on public.activity_logs for select
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','developer'))
);

-- (OPSIONAL) Kalau nanti mau user bisa lihat riwayat moderasi terhadap
-- dirinya sendiri, hapus komentar blok di bawah ini:
--
-- drop policy if exists "activity_logs_read_own_target" on public.activity_logs;
-- create policy "activity_logs_read_own_target"
-- on public.activity_logs for select
-- using (target_user_id = auth.uid());

-- ---------- 4. RLS: siapa yang boleh TULIS ----------
-- Hanya staff, dan actor_id WAJIB dirinya sendiri, jadi tidak ada
-- yang bisa menulis log atas nama orang lain. Akun banned diblok juga.
drop policy if exists "activity_logs_staff_insert" on public.activity_logs;
create policy "activity_logs_staff_insert"
on public.activity_logs for insert
with check (
  auth.uid() = actor_id
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('admin','developer')
      and not coalesce(p.banned, false)
  )
);

-- Sengaja TIDAK ada policy untuk update & delete.
-- Tanpa policy, RLS otomatis menolak semua UPDATE/DELETE dari client.

-- =========================================================
--  PEMBERSIHAN LOG (jalankan manual di SQL Editor kalau perlu)
-- =========================================================
-- Hapus log yang lebih tua dari 1 tahun:
--   delete from public.activity_logs where created_at < now() - interval '1 year';
--
-- Kosongkan semua log:
--   truncate table public.activity_logs;
