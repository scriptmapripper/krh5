-- =========================================================
--  Migration: History Logs (Audit Trail)
--  Jalankan di Supabase Dashboard > SQL Editor.
--  Versi RERUNNABLE — aman dijalankan berkali-kali.
--
--  Kalau kamu SUDAH pernah jalanin versi sebelumnya: jalanin lagi
--  file ini apa adanya. Semua perubahan pakai "if not exists" /
--  "create or replace" / "drop policy if exists", jadi datanya
--  aman dan cuma policy + index-nya yang di-upgrade.
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

-- ---------- 2. Helper: is_staff() ----------
-- PENTING UNTUK PERFORMA. Kalau policy RLS ditulis langsung sebagai
-- "exists (select 1 from profiles ...)", subquery-nya ikut dievaluasi
-- saat nge-scan baris.
--
-- Dibungkus jadi fungsi STABLE, lalu dipanggil sebagai
-- "(select is_staff())" di policy, hasilnya dihitung SEKALI per query
-- (jadi InitPlan) — bukan diulang per baris.
--
-- SECURITY DEFINER dipakai supaya cek role ini gak ikut kena RLS
-- tabel profiles (menghindari evaluasi policy bertingkat).
create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('admin','developer')
  );
$$;

create or replace function public.is_active_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('admin','developer')
      and not coalesce(p.banned, false)
  );
$$;

revoke execute on function public.is_staff()        from public, anon;
revoke execute on function public.is_active_staff() from public, anon;
grant  execute on function public.is_staff()        to authenticated;
grant  execute on function public.is_active_staff() to authenticated;

-- ---------- 3. Index ----------
-- Halaman logs SELALU order by created_at desc, jadi arah index-nya
-- dibikin desc juga supaya bisa dibaca langsung tanpa sort tambahan.
create index if not exists activity_logs_created_at_idx on public.activity_logs (created_at desc);

-- Index COMPOSITE untuk dua filter yang paling sering dipakai.
-- Filter + sort dilayani satu index sekaligus, jauh lebih murah
-- daripada index kolom tunggal yang masih harus sort ulang.
create index if not exists activity_logs_action_created_idx on public.activity_logs (action, created_at desc);
create index if not exists activity_logs_actor_created_idx  on public.activity_logs (actor_id, created_at desc);
create index if not exists activity_logs_target_user_idx    on public.activity_logs (target_user_id);

-- Index single-column versi lama sudah ditutupi composite di atas —
-- dibuang biar tiap INSERT gak perlu maintain index kembar.
drop index if exists public.activity_logs_action_idx;
drop index if exists public.activity_logs_actor_id_idx;
drop index if exists public.activity_logs_target_user_id_idx;

-- Index untuk fitur Search (ILIKE '%kata%').
-- Tanpa ini, tiap search = full table scan. pg_trgm bikin pencarian
-- partial kayak gitu tetap bisa pakai index.
create extension if not exists pg_trgm;
create index if not exists activity_logs_search_idx
  on public.activity_logs using gin (
    (coalesce(target_label,'') || ' ' || coalesce(reason,'')) gin_trgm_ops
  );

-- ---------- 4. RLS: siapa yang boleh BACA ----------
-- Hanya admin & developer. User biasa tidak bisa melihat log sama sekali.
drop policy if exists "activity_logs_staff_read" on public.activity_logs;
create policy "activity_logs_staff_read"
on public.activity_logs for select
using ( (select public.is_staff()) );

-- (OPSIONAL) Kalau nanti mau user bisa lihat riwayat moderasi terhadap
-- dirinya sendiri, hapus komentar blok di bawah ini:
--
-- drop policy if exists "activity_logs_read_own_target" on public.activity_logs;
-- create policy "activity_logs_read_own_target"
-- on public.activity_logs for select
-- using (target_user_id = (select auth.uid()));

-- ---------- 5. RLS: siapa yang boleh TULIS ----------
-- Hanya staff, dan actor_id WAJIB dirinya sendiri, jadi tidak ada
-- yang bisa menulis log atas nama orang lain. Akun banned diblok juga.
drop policy if exists "activity_logs_staff_insert" on public.activity_logs;
create policy "activity_logs_staff_insert"
on public.activity_logs for insert
with check (
  (select auth.uid()) = actor_id
  and (select public.is_active_staff())
);

-- Sengaja TIDAK ada policy untuk update & delete.
-- Tanpa policy, RLS otomatis menolak semua UPDATE/DELETE dari client.

-- ---------- 6. RPC: statistik ringkas ----------
-- Empat angka di kartu atas halaman logs dihitung di database dalam
-- SATU query (satu kali scan), bukan dengan menarik ribuan baris ke
-- browser cuma buat dihitung di JavaScript.
--
-- Sengaja TANPA security definer, jadi RLS tetap berlaku: kalau yang
-- manggil bukan staff, dia gak lihat baris apa pun dan hasilnya 0.
create or replace function public.activity_log_stats()
returns table (total bigint, last_24h bigint, last_7d bigint, staff_active bigint)
language sql
stable
set search_path = public
as $$
  select
    count(*),
    count(*) filter (where created_at > now() - interval '24 hours'),
    count(*) filter (where created_at > now() - interval '7 days'),
    count(distinct actor_id)
  from public.activity_logs;
$$;

revoke execute on function public.activity_log_stats() from public, anon;
grant  execute on function public.activity_log_stats() to authenticated;

-- =========================================================
--  PEMBERSIHAN LOG (jalankan manual di SQL Editor kalau perlu)
-- =========================================================
-- Log makin numpuk = count(*) di kartu statistik makin lambat.
-- Kalau tabelnya udah ratusan ribu baris, pangkas yang lama:
--
--   delete from public.activity_logs where created_at < now() - interval '1 year';
--
-- Kosongkan semua log:
--   truncate table public.activity_logs;
--
-- Setelah delete besar, rapikan tabelnya:
--   vacuum analyze public.activity_logs;
