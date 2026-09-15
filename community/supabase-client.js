// =========================================================
//  ISI 2 BARIS INI SETELAH BIKIN PROJECT SUPABASE
//  Supabase Dashboard > Project Settings > API
// =========================================================
const SUPABASE_URL = "https://yqvtlbrwhjkyfogokwqd.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_qBvS9QAc9dJVVqTKVdB4dg_MTubzx4N";
// =========================================================

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ---------- helpers dipakai di semua halaman community/* ----------

async function getSessionUser() {
  const { data: { session } } = await sb.auth.getSession();
  return session ? session.user : null;
}

async function getMyProfile() {
  const user = await getSessionUser();
  if (!user) return null;
  const { data, error } = await sb
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .maybeSingle();
  if (error) { console.error(error); return null; }

  if (data && data.banned) {
    /* Banned accounts stay logged in — they're just locked to banned.html.
       No sign-out here on purpose: this way there's no Logout button
       anywhere they can still reach (it only lives on pages like
       Settings/Dashboard, which this redirect never lets them open). */
    const reason = data.ban_reason || "";
    const inCommunityFolder = window.location.pathname.includes("/community/");
    const alreadyOnBannedPage = window.location.pathname.endsWith("/banned.html");
    if (!alreadyOnBannedPage) {
      const target = (inCommunityFolder ? "banned.html" : "community/banned.html") + (reason ? `?reason=${encodeURIComponent(reason)}` : "");
      window.location.href = target;
      return null;
    }
    // Already on banned.html — hand back the profile (username, ban_reason,
    // krunker_username, discord_id, discord_username, etc.) so the page can
    // prefill the Appeal Ban form instead of getting nothing back.
    return data;
  }

  return data;
}

// Redirect kalau belum login sama sekali
async function requireLogin(redirectTo = "login.html") {
  const user = await getSessionUser();
  if (!user) { window.location.href = redirectTo; return null; }
  return user;
}

// Redirect kalau role gak cukup. allowed = ["admin","developer"] misalnya
async function requireRole(allowed, redirectTo = "../index.html") {
  const profile = await getMyProfile();
  if (!profile || !allowed.includes(profile.role)) {
    window.location.href = redirectTo;
    return null;
  }
  return profile;
}

// Returns the number of unread notifications for the given user id (0 on error)
async function getUnreadNotificationCount(userId) {
  if (!userId) return 0;
  try {
    const { count, error } = await sb
      .from("notifications")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("read", false);
    if (error) { console.error(error); return 0; }
    return count || 0;
  } catch (e) { console.error(e); return 0; }
}

// Returns the number of unread DMs sent TO the given user id (0 on error)
async function getUnreadMessageCount(userId) {
  if (!userId) return 0;
  try {
    const { data: convos, error: convError } = await sb
      .from("conversations")
      .select("id")
      .or(`user1_id.eq.${userId},user2_id.eq.${userId}`);
    if (convError || !convos || !convos.length) return 0;
    const ids = convos.map(c => c.id);
    const { count, error } = await sb
      .from("messages")
      .select("id", { count: "exact", head: true })
      .in("conversation_id", ids)
      .eq("read", false)
      .neq("sender_id", userId);
    if (error) { console.error(error); return 0; }
    return count || 0;
  } catch (e) { console.error(e); return 0; }
}

// Returns an inline unread-count badge as an HTML string, or "" if count is 0
function unreadBadgeHtml(count) {
  if (!count) return "";
  return `<span style="display:inline-flex; align-items:center; justify-content:center; min-width:16px; height:16px; padding:0 4px; border-radius:20px; background:var(--blue-glow); color:#05070f; font-size:10px; font-weight:700; margin-left:4px; vertical-align:middle;">${count > 99 ? "99+" : count}</span>`;
}

function roleBadge(role) {
  const map = {
    developer: '<span class="role-badge role-developer">Developer</span>',
    admin: '<span class="role-badge role-admin">Admin</span>',
    user: '<span class="role-badge role-user">User</span>',
  };
  return map[role] || map.user;
}

// Returns an <img> or a fallback initial-letter avatar as an HTML string
function avatarHtml(profile, size = 32) {
  const s = size + "px";
  if (profile?.avatar_url) {
    return `<img src="${escapeHtml(profile.avatar_url)}" alt="avatar" style="width:${s}; height:${s}; border-radius:50%; object-fit:cover; border:1px solid var(--border); vertical-align:middle;">`;
  }
  const letter = (profile?.display_name || profile?.username || "?").trim().charAt(0).toUpperCase();
  return `<span style="display:inline-flex; align-items:center; justify-content:center; width:${s}; height:${s}; border-radius:50%; background:var(--surface-2); border:1px solid var(--border); color:var(--text-1); font-weight:700; font-size:${Math.round(size*0.45)}px; vertical-align:middle;">${letter}</span>`;
}

function escapeHtml(str) {
  const d = document.createElement("div");
  d.textContent = str ?? "";
  return d.innerHTML;
}

function formatDate(iso) {
  const d = new Date(iso);
  return d.toLocaleDateString("en-US", { day: "numeric", month: "short", year: "numeric" });
}

// ---------- Show/Hide password toggle ----------
// Pasang otomatis di semua input dengan class "pw-toggle" yang punya
// data-target = id input password terkait. Cukup bungkus input pakai
// <div class="pw-wrap">...<button class="pw-toggle" data-target="...">
// dan ini jalan sendiri di semua halaman yang load supabase-client.js.
const EYE_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7Z"/><circle cx="12" cy="12" r="3"/></svg>';
const EYE_OFF_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 7 11 7a13.16 13.16 0 0 1-3.19 3.94M6.61 6.61A13.31 13.31 0 0 0 1 11s4 7 11 7a9.28 9.28 0 0 0 5.39-1.61M9.88 9.88a3 3 0 1 0 4.24 4.24"/><path d="M1 1l22 22"/></svg>';

function initPasswordToggles() {
  document.querySelectorAll(".pw-toggle").forEach((btn) => {
    if (btn.dataset.pwInit) return; // hindari double-bind kalau dipanggil ulang
    btn.dataset.pwInit = "1";
    btn.type = "button";
    btn.setAttribute("aria-label", "Show password");
    btn.innerHTML = EYE_ICON;
    btn.addEventListener("click", () => {
      const input = document.getElementById(btn.dataset.target);
      if (!input) return;
      const willShow = input.type === "password";
      input.type = willShow ? "text" : "password";
      btn.setAttribute("aria-label", willShow ? "Hide password" : "Show password");
      btn.innerHTML = willShow ? EYE_OFF_ICON : EYE_ICON;
    });
  });
}

document.addEventListener("DOMContentLoaded", initPasswordToggles);
