// ==UserScript==
// @name         Fodder — SBC tools for FC 26
// @namespace    https://fodder.gg
// @version      0.1.0
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
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  // The SPA boots asynchronously after document-idle — wait for its globals so the client's hooks
  // bind against a ready app. Give up quietly after ~60s (login page, error page, …).
  let ready = false;
  for (let i = 0; i < 120; i++) {
    if (window.services && window.repositories) { ready = true; break; }
    await sleep(500);
  }
  if (!ready) return;

  try {
    const src = await (await fetch(BACKEND + "/client.js", { cache: "no-store" })).text();
    (0, eval)(src);
    console.log("[fodder-gg] userscript injected from " + BACKEND);
  } catch (e) {
    console.warn("[fodder-gg] userscript load failed — " + BACKEND + " unreachable?", e);
  }
})();
