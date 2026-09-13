-- =========================================================
--  Migration: Post Reactions (Like/Dislike) & Saved Posts
--  Run this ONCE in Supabase Dashboard > SQL Editor.
--  Versi RERUNNABLE — aman dijalankan berkali-kali.
-- =========================================================

-- ---------- Likes / Dislikes ----------
create table if not exists public.post_reactions (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.posts(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  type        text not null check (type in ('like','dislike')),
  created_at  timestamptz not null default now(),
  unique (post_id, user_id)
);

alter table public.post_reactions enable row level security;

-- Reaction counts are public (like Facebook/YouTube like counts) — anyone
-- can read them, including logged-out visitors.
drop policy if exists "reactions_public_read" on public.post_reactions;
create policy "reactions_public_read"
on public.post_reactions for select
using (true);

-- Only as yourself
drop policy if exists "reactions_insert_own" on public.post_reactions;
create policy "reactions_insert_own"
on public.post_reactions for insert
with check (auth.uid() = user_id);

drop policy if exists "reactions_update_own" on public.post_reactions;
create policy "reactions_update_own"
on public.post_reactions for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "reactions_delete_own" on public.post_reactions;
create policy "reactions_delete_own"
on public.post_reactions for delete
using (auth.uid() = user_id);

create index if not exists post_reactions_post_id_idx on public.post_reactions (post_id);

-- ---------- Saved / Favorited posts ----------
create table if not exists public.post_saves (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.posts(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (post_id, user_id)
);

alter table public.post_saves enable row level security;

-- Your saved list is private — only you can see what you've saved.
drop policy if exists "saves_read_own" on public.post_saves;
create policy "saves_read_own"
on public.post_saves for select
using (auth.uid() = user_id);

drop policy if exists "saves_insert_own" on public.post_saves;
create policy "saves_insert_own"
on public.post_saves for insert
with check (auth.uid() = user_id);

drop policy if exists "saves_delete_own" on public.post_saves;
create policy "saves_delete_own"
on public.post_saves for delete
using (auth.uid() = user_id);

create index if not exists post_saves_user_id_idx on public.post_saves (user_id);
create index if not exists post_saves_post_id_idx on public.post_saves (post_id);
