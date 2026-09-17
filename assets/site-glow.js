/* ============================================================
   Site-wide "reduce visual effects" toggle — Krunker Resource Hub
   ------------------------------------------------------------
   Pairs with assets/site-glow.css. Lets a visitor turn the sitewide
   glow layer off (persisted in localStorage) by flipping
   [data-glow-effects="off"] on <html>, which zeroes out
   --glow-strength everywhere. Defaults to "off" for visitors whose
   OS already has prefers-reduced-motion set, unless they've made an
   explicit choice here before.

   No page on this site has a real <footer> to dock a toggle into, so
   this mounts a small floating pill in the bottom-right corner
   instead. Safe to include on every page — it no-ops if it's already
   been mounted once.
   ============================================================ */
(function () {
  if (window.__krh5GlowToggleInit) return;
  window.__krh5GlowToggleInit = true;

  var STORAGE_KEY = "krh5:reduceEffects";
  var root = document.documentElement;

  function getStored() {
    try {
      return localStorage.getItem(STORAGE_KEY);
    } catch (e) {
      return null;
    }
  }

  function setStored(value) {
    try {
      localStorage.setItem(STORAGE_KEY, value);
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
    var stored = getStored();
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

  // Apply immediately (before DOMContentLoaded) so there's no flash
  // of glow before this runs.
  apply(isReduced());

  function mountToggle() {
    if (document.querySelector(".krh5-glow-toggle")) return;

    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "krh5-glow-toggle";
    btn.title = "Toggle glow / hover effects for this site";

    function render() {
      var reduced = isReduced();
      btn.setAttribute("aria-pressed", String(reduced));
      btn.textContent = reduced ? "✧ Effects: Off" : "✦ Effects: On";
    }
    render();

    btn.addEventListener("click", function () {
      var next = !isReduced();
      setStored(next ? "1" : "0");
      apply(next);
      render();
    });

    document.body.appendChild(btn);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", mountToggle);
  } else {
    mountToggle();
  }
})();
