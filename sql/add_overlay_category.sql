-- =========================================================
--  Migration: Crosshair > Overlay (Damage / Game) + Icons
--  (Kill, Death, Ammo, Streak Counter)
--
--  Run this ONCE in Supabase Dashboard > SQL Editor.
--  Versi RERUNNABLE — aman dijalankan berkali-kali.
--
--  Semua section ini pakai upload 1 gambar per post lewat
--  community/image-section.html, jadi gambarnya masuk bucket
--  `crosshairs` yang udah ada. Kalau bucket itu belum pernah
--  dibuat, jalankan juga sql/add_crosshair_storage.sql.
-- =========================================================

-- Widen the allowed category list so the new sections pass the check.
alter table public.posts drop constraint if exists posts_category_check;

alter table public.posts
  add constraint posts_category_check check (category in (
    'crosshair','crosshair-scope','crosshair-hitmarker',
    'crosshair-overlay-damage','crosshair-overlay-game',
    'crosshair-icons-kill','crosshair-icons-death','crosshair-icons-ammo','crosshair-icons-streak',
    'settings-ready','css-ready',
    'maps-official-infected','maps-official-tdm','maps-custom-parkour',
    'mods-files','scripts-userscript-legal','scripts-userscript-hack','scripts-krunkscript-usable'
  ));

-- Make sure the image bucket used by these sections exists and is public.
insert into storage.buckets (id, name, public)
values ('crosshairs', 'crosshairs', true)
on conflict (id) do update
set public = true;
