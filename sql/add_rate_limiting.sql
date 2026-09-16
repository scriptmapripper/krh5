-- =========================================================
--  Migration: Rate limiting for posts & comments
--  Run this ONCE in Supabase Dashboard > SQL Editor.
--  Versi RERUNNABLE — aman dijalankan berkali-kali.
--
--  Kenapa ini penting: validasi cooldown di JS (client) gampang
--  dilewatin — orang tinggal manggil Supabase API langsung dari
--  console/script, gak lewat website sama sekali. Makanya
--  penahannya ditaruh di database lewat trigger, bukan di JS.
--  Admin & developer dikecualikan (gak kena limit), soalnya
--  mereka kadang perlu publish/moderasi cepat berkali-kali.
-- =========================================================

-- ---------- Posts: minimal 20 detik antar post per user ----------
create or replace function public.enforce_post_rate_limit()
returns trigger language plpgsql security definer as $$
declare
  v_role text;
  v_last timestamptz;
begin
  select role into v_role from public.profiles where id = new.author_id;

  -- Staff (admin/developer) dikecualikan dari rate limit
  if v_role in ('admin','developer') then
    return new;
  end if;

  select max(created_at) into v_last
  from public.posts
  where author_id = new.author_id;

  if v_last is not null and now() - v_last < interval '20 seconds' then
    raise exception 'You are posting too fast. Please wait a few seconds and try again.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_posts_rate_limit on public.posts;
create trigger trg_posts_rate_limit
before insert on public.posts
for each row execute function public.enforce_post_rate_limit();


-- ---------- Comments: minimal 5 detik antar komentar per user ----------
create or replace function public.enforce_comment_rate_limit()
returns trigger language plpgsql security definer as $$
declare
  v_role text;
  v_last timestamptz;
begin
  select role into v_role from public.profiles where id = new.author_id;

  if v_role in ('admin','developer') then
    return new;
  end if;

  select max(created_at) into v_last
  from public.comments
  where author_id = new.author_id;

  if v_last is not null and now() - v_last < interval '5 seconds' then
    raise exception 'You are commenting too fast. Please slow down a bit.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_comments_rate_limit on public.comments;
create trigger trg_comments_rate_limit
before insert on public.comments
for each row execute function public.enforce_comment_rate_limit();

-- =========================================================
-- CATATAN
-- =========================================================
-- Cooldown-nya sengaja pendek (20 detik post, 5 detik komentar) —
-- cukup buat mentahin script spam-klik, tapi gak ganggu orang yang
-- lagi pakai situs normal. Kalau mau diubah, ganti angka di
-- "interval '20 seconds'" / "interval '5 seconds'" di atas terus
-- jalankan ulang file ini (aman, gak bakal error duplicate).
