// ==UserScript==
// @name         Fodder — SBC tools for FC 26
// @namespace    https://fodder.gg
// @version      0.3.0
// @description  Solve SBCs from your live club, inside the FC 26 web app. fodder.gg
// @match        https://www.ea.com/*
// @run-at       document-idle
// @noframes
// @updateURL    https://fodder.gg/fodder.user.js
// @downloadURL  https://fodder.gg/fodder.user.js
// @icon         data:image/png;base64,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
// @grant        none
// ==/UserScript==

// Thin loader: waits for the FC web app to boot, then fetches the ALWAYS-LATEST client bundle
// from fodder.gg and evals it (same pattern as the extension loader — client fixes ship to every
// user on their next page load, no userscript update needed). EA's CSP allows both the cross-origin
// fetch (default-src *) and the eval (script-src 'unsafe-eval').
(async () => {
  const BACKEND = window.FODDER_GG_BACKEND || "https://fodder.gg";

  // Sign-in hand-off. Runs BEFORE the wait for EA's app below, deliberately: the token arrives in the fragment
  // of a tab our client opened, and it must be captured even when EA serves something the app never boots on
  // (a login wall, an error page). The tab that opened this one shares our origin, so writing localStorage IS
  // the delivery — it reads the value and finishes signing in.
  //
  // The fragment is stripped immediately so the token does not sit in the address bar, the back/forward history
  // or anything that later reads location.hash. It is never sent to a server: browsers do not transmit fragments.
  try {
    const h = String(location.hash || "");
    const m = h.match(/(?:^#|&)token=([^&]+)/);
    if (m) {
      // Must match AUTH_TOKEN_KEY in client/src/core.js — the whole point is that the client reads it back.
      localStorage.setItem("fodder_gg_token", decodeURIComponent(m[1]));
      history.replaceState(null, "", location.pathname + location.search);
    }
  } catch (_e) { /* a blocked localStorage just means the pairing fallback handles it */ }
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  // Locales with a dictionary on the CDN. Baked in so an unknown UT_LOCALE costs no 404 round trip.
  const LANGS = ["fr", "es", "pt", "ko", "zh"];

  // The SPA boots asynchronously after document-idle — wait for its globals so the client's hooks
  // bind against a ready app. Give up quietly after ~60s (login page, error page, …).
  let ready = false;
  for (let i = 0; i < 120; i++) {
    if (window.services && window.repositories) { ready = true; break; }
    await sleep(500);
  }
  if (!ready) return;

  // /client.core.js ships English only; the user's own language is a separate ~5KB JSON. Both fetches
  // run CONCURRENTLY and the overlay is assigned BEFORE the eval, so the client reads a populated
  // window.__fodderI18n and its fgT() stays synchronous — no async init, no string briefly rendering
  // in English, nothing re-rendered afterwards. A failed overlay simply leaves the user on English.
  const localeOverlay = async () => {
    try {
      const raw = (localStorage.getItem("UT_LOCALE") || "").toLowerCase().split(/[-_]/)[0];
      if (!LANGS.includes(raw)) return null;
      const res = await fetch(BACKEND + "/i18n/" + raw + ".json", { cache: "no-store" });
      if (!res.ok) return null;
      return { lang: raw, dict: await res.json() };
    } catch (_e) { return null; }
  };

  try {
    const [src, overlay] = await Promise.all([
      fetch(BACKEND + "/client.core.js", { cache: "no-store" }).then((r) => r.text()),
      localeOverlay(),
    ]);
    if (overlay) window.__fodderI18n = Object.assign(window.__fodderI18n || {}, { [overlay.lang]: overlay.dict });
    (0, eval)(src);
    console.log("[fodder-gg] userscript injected from " + BACKEND + (overlay ? " (+" + overlay.lang + ")" : ""));
  } catch (e) {
    console.warn("[fodder-gg] userscript load failed — " + BACKEND + " unreachable?", e);
  }
})();
