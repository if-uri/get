// Author: Tom Sapletta · https://tom.sapletta.com
// Part of the ifURI solution.

/**
 * ifuri-ecobar — the shared ecosystem top bar.
 *
 * One source of truth for the standard ifURI header so a visitor can move
 * between domains (ifuri.com, connect.ifuri.com, get.ifuri.com, docs) from any
 * page. Rendered inside a Shadow DOM so the host page's CSS (fonts, sizes,
 * spacing) cannot leak in — the bar looks identical on every site.
 *
 * Canonical: ifuri-com/httpdocs/assets/ifuri-ecobar.js (vendored copies synced
 * at deploy time). Include once near the end of <body>:
 *   <script src="/assets/ifuri-ecobar.js" defer></script>
 */
(function () {
  "use strict";
  if (document.getElementById("ifuri-ecobar-host")) return;

  var params = new URLSearchParams(location.search);
  var lang = params.get("lang") === "en" ? "en" : "pl";
  var IFURI = "https://ifuri.com";
  var CONNECT = "https://connect.ifuri.com";
  var GET = "https://get.ifuri.com";
  var DOCS = "https://docs.ifuri.com";
  function view(v) { return IFURI + "/?view=" + v + "&lang=" + lang; }

  // [pl, en, href, key]
  var items = [
    ["Produkt", "Product", view("product"), "product"],
    ["Runtime", "Runtime", view("runtime"), "runtime"],
    ["Dokumentacja", "Docs", DOCS, "docs"],
    ["Connectory", "Connectors", CONNECT, "connect"],
    ["Flows", "Flows", view("flows"), "flows"],
    ["Sieć", "Network", view("network"), "network"],
    ["Pobieranie", "Download", GET, "download"]
  ];

  var host = location.hostname.replace(/^www\./, "");
  var curView = params.get("view") || "";
  function isActive(key) {
    if (host === "connect.ifuri.com") return key === "connect";
    if (host === "get.ifuri.com") return key === "download";
    if (host === "docs.ifuri.com") return key === "docs";
    if (host === "ifuri.com") {
      if (key === "docs") return /urirun|\/docs/.test(location.pathname);
      return key === curView;
    }
    return false;
  }

  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]; }); }

  var navHTML = items.map(function (it) {
    var label = lang === "en" ? it[1] : it[0];
    return '<a href="' + esc(it[2]) + '" rel="noopener"' + (isActive(it[3]) ? ' class="active"' : "") + ">" + esc(label) + "</a>";
  }).join("");

  // Shadow CSS: :host all:initial blocks page inheritance; everything below is
  // declared explicitly so the bar is pixel-identical regardless of host CSS.
  var css =
    ":host{all:initial;display:block}" +
    "*{box-sizing:border-box}" +
    ".bar{display:flex;align-items:stretch;gap:18px;flex-wrap:wrap;padding:0 18px;min-height:48px;" +
    "background:#1E1B4B;border-bottom:1px solid #312E81;" +
    "font-family:system-ui,-apple-system,'Segoe UI',Roboto,Arial,sans-serif;font-size:14px;line-height:1;font-weight:400}" +
    ".brand{display:inline-flex;align-items:center;font-size:15px;font-weight:800;color:#fff;text-decoration:none;letter-spacing:-.01em}" +
    ".brand b{background:linear-gradient(90deg,#818CF8,#34D399);-webkit-background-clip:text;background-clip:text;color:transparent}" +
    "nav{display:flex;align-items:stretch;gap:16px;flex-wrap:wrap;flex:1}" +
    "nav a{display:inline-flex;align-items:center;font-size:14px;font-weight:500;color:#C7D2FE;text-decoration:none;white-space:nowrap}" +
    "nav a:hover{color:#fff}" +
    "nav a.active{color:#fff;font-weight:700;box-shadow:inset 0 -2px 0 #34D399}" +
    ".lang{align-self:center;background:#312E81;color:#fff;border:1px solid #4338CA;border-radius:6px;padding:4px 8px;" +
    "font-family:inherit;font-size:13px;line-height:1.2;cursor:pointer}" +
    "@media(max-width:640px){.bar{gap:10px;padding:8px 12px}nav{gap:12px}}";

  var html =
    "<style>" + css + "</style>" +
    '<div class="bar">' +
    '<a class="brand" href="' + IFURI + "/?lang=" + lang + '">if<b>URI</b></a>' +
    "<nav>" + navHTML + "</nav>" +
    '<select class="lang" aria-label="Language">' +
    '<option value="pl"' + (lang === "pl" ? " selected" : "") + ">PL</option>" +
    '<option value="en"' + (lang === "en" ? " selected" : "") + ">EN</option>" +
    "</select>" +
    "</div>";

  var hostEl = document.createElement("div");
  hostEl.id = "ifuri-ecobar-host";
  hostEl.style.cssText = "position:sticky;top:0;left:0;right:0;z-index:2147483646;display:block";
  var sr = hostEl.attachShadow({ mode: "open" });
  sr.innerHTML = html;
  sr.querySelector(".lang").addEventListener("change", function (e) {
    var p = new URLSearchParams(location.search);
    p.set("lang", e.target.value);
    location.search = p.toString();
  });
  document.body.insertBefore(hostEl, document.body.firstChild);
})();
