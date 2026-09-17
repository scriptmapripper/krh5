/* ============================================================
   Site-wide "reduce visual effects" toggle — Krunker Resource Hub
   ------------------------------------------------------------
   Pairs with assets/site-glow.css. Mounts a small floating control
   that lets a visitor turn the sitewide glow layer off (persisted in
   localStorage), by flipping [data-glow-effects="off"] on <html>,
   which zeroes out --glow-strength everywhere.

   The very first application of that attribute (so there's no flash
   of glow before this file even loads) happens in a tiny inline
   <script> each page carries right after its site-glow.css <link> —
   see that inline snippet for the canonical isReduced() logic. This
   file duplicates that check (harmless — it's idempotent) and then
   owns everything past that: mounting the toggle button and wiring
   up clicks.

   No page on this site has a real <footer> to dock a toggle into, so
   this mounts a small floating pill in the bottom-right corner
   instead. Safe to include on every page — it no-ops if it's already
   been mounted once.
   ============================================================ */
(function () {
  if (window.__krh5GlowToggleInit) return;
  window.__krh5GlowToggleInit = true;

  var STORAGE_KEY = "krh5:reduceEffects";
  var SEEN_KEY = "krh5:toggleSeen";
  var root = document.documentElement;

  function getStored(key) {
    try {
      return localStorage.getItem(key);
    } catch (e) {
      return null;
    }
  }

  function setStored(key, value) {
    try {
      localStorage.setItem(key, value);
    } catch (e) {
      /* localStorage unavailable (private mode, blocked, etc.) —
         the toggle still works for the current page load, it just
         won't persist across visits. */
    }
  }

  function osPrefersReduced() {
    return (
      window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    );
  }

  function isReduced() {
    var stored = getStored(STORAGE_KEY);
    if (stored === "1") return true;
    if (stored === "0") return false;
    // No explicit choice made on this site yet — default to whatever
    // the visitor's OS already asks for.
    return osPrefersReduced();
  }

  function apply(reduced) {
    if (reduced) root.setAttribute("data-glow-effects", "off");
    else root.removeAttribute("data-glow-effects");
  }

  // Re-assert the initial state (the inline snippet already set it
  // before first paint; this is just a harmless double-check in case
  // this file is ever included without that snippet).
  apply(isReduced());

  function mountToggle() {
    if (document.querySelector(".krh5-glow-toggle")) return;

    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "krh5-glow-toggle";
    btn.title = "Toggle glow / hover effects for this site";
    btn.setAttribute(
      "aria-label",
      "Reduce or restore this site's glow and hover effects"
    );

    function render() {
      var reduced = isReduced();
      btn.setAttribute("aria-pressed", String(reduced));
      btn.textContent = reduced ? "✧ Effects: Off" : "✦ Effects: On";
    }
    render();

    btn.addEventListener("click", function () {
      var next = !isReduced();
      setStored(STORAGE_KEY, next ? "1" : "0");
      apply(next);
      render();
    });

    document.body.appendChild(btn);

    // Show it at full opacity the first time a visitor lands on the
    // site (across any page), then settle to its normal low-key
    // opacity — enough for people to notice it exists once, without
    // it staying in the way on every future visit. Skipped outright
    // for visitors whose OS asks for reduced motion; they get the
    // resting opacity immediately instead of an animated fade.
    var alreadySeen = getStored(SEEN_KEY) === "1";
    if (!alreadySeen && !osPrefersReduced()) {
      btn.classList.add("krh5-glow-toggle--intro");
      setTimeout(function () {
        btn.classList.remove("krh5-glow-toggle--intro");
      }, 2500);
    }
    setStored(SEEN_KEY, "1");
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", mountToggle);
  } else {
    mountToggle();
  }
})();
