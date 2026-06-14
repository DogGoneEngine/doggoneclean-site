/* Mount Olympus - behavior. Vanilla JS, no build step, reads window.OLYMPUS. */
(function () {
  "use strict";
  var CFG = window.OLYMPUS || { buildings: [], shelf: [], mottos: [] };
  var $ = function (sel, root) { return (root || document).querySelector(sel); };
  var el = function (tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  };

  /* ---------- header: greeting, clock, motto ---------- */
  function easternParts() {
    // Render the clock in Paul's local US Eastern time regardless of device tz.
    var fmt = new Intl.DateTimeFormat("en-US", {
      timeZone: "America/New_York",
      weekday: "long", month: "long", day: "numeric",
      hour: "numeric", minute: "2-digit", hour12: true,
    });
    return fmt.format(new Date());
  }
  function hourEastern() {
    var h = new Intl.DateTimeFormat("en-US", {
      timeZone: "America/New_York", hour: "numeric", hour12: false,
    }).format(new Date());
    return parseInt(h, 10);
  }
  function greet() {
    var h = hourEastern();
    var part = h < 5 ? "Still up" : h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening";
    return part + ", " + (CFG.owner || "friend") + ".";
  }
  function tick() {
    var c = $("#clock"); if (c) c.textContent = easternParts() + " ET";
  }
  function pickMotto() {
    var m = CFG.mottos || [];
    if (!m.length) return "";
    // Stable per calendar day so it does not flicker on refresh.
    var day = Math.floor(Date.now() / 86400000);
    return m[day % m.length];
  }

  /* ---------- buildings ---------- */
  var allDoors = []; // for the command palette

  function buildingCard(b) {
    var card = el("div", "card");
    card.style.setProperty("--accent", b.accent || "#d9b46a");

    var head = el("div", "card-head");
    var headText = el("div");
    headText.appendChild(el("div", "card-name", b.name));
    headText.appendChild(el("p", "card-tag", b.tagline || ""));
    head.appendChild(headText);

    var dot = el("span", "dot");
    dot.title = "Checking reachability...";
    if (b.live) pingDot(b.live, dot, b.name);
    head.appendChild(dot);
    card.appendChild(head);

    (b.doors || []).forEach(function (group) {
      var g = el("div", "group");
      var collapsible = !!group.collapsed;
      if (collapsible) g.classList.add("collapsible", "collapsed");

      var label = el("div", "group-label");
      label.appendChild(el("span", null, group.label || ""));
      if (collapsible) {
        var chev = el("span", "chev", "v");
        label.appendChild(chev);
        label.addEventListener("click", function () { g.classList.toggle("collapsed"); });
      }
      g.appendChild(label);

      var links = el("div", "links");
      (group.links || []).forEach(function (lnk) {
        links.appendChild(doorEl(lnk, b.name));
      });
      g.appendChild(links);
      card.appendChild(g);
    });

    return card;
  }

  function doorEl(lnk, where) {
    if (!lnk.url) {
      var span = el("span", "door empty", lnk.label);
      span.title = "Not built yet";
      return span;
    }
    var a = el("a", "door");
    a.href = lnk.url;
    a.target = "_blank";
    a.rel = "noopener";
    a.appendChild(el("span", null, lnk.label));
    a.appendChild(el("span", "arrow", "↗"));
    allDoors.push({ label: lnk.label, url: lnk.url, where: where });
    return a;
  }

  function addCard() {
    var card = el("div", "card add");
    card.appendChild(el("div", "plus", "+"));
    card.appendChild(el("div", null, "Add a building"));
    card.appendChild(el("div", "how", "Open projects.js, copy the template block at the bottom, fill it in, and redeploy. The new building appears here."));
    card.addEventListener("click", function () {
      alert("To add a project: edit projects.js (the template is at the bottom), then redeploy. Everything on this page is generated from that one file.");
    });
    return card;
  }

  function renderBuildings() {
    var grid = $("#buildings");
    (CFG.buildings || []).forEach(function (b) {
      if (b.template) return;
      grid.appendChild(buildingCard(b));
    });
    grid.appendChild(addCard());
  }

  function renderShelf() {
    var shelf = $("#shelf");
    (CFG.shelf || []).forEach(function (lnk) {
      shelf.appendChild(doorEl(lnk, "Tools"));
    });
  }

  /* ---------- reachability dot (best effort) ---------- */
  function pingDot(url, dot, name) {
    var done = false;
    var settle = function (ok) {
      if (done) return; done = true;
      dot.classList.remove("ok", "bad");
      dot.classList.add(ok ? "ok" : "bad");
      dot.title = name + (ok ? " is reachable" : " did not respond");
    };
    // no-cors: we cannot read the response, but resolve ~= reachable.
    var ctrl = ("AbortController" in window) ? new AbortController() : null;
    var t = setTimeout(function () { if (ctrl) ctrl.abort(); settle(false); }, 6000);
    fetch(url, { mode: "no-cors", cache: "no-store", signal: ctrl ? ctrl.signal : undefined })
      .then(function () { clearTimeout(t); settle(true); })
      .catch(function () { clearTimeout(t); settle(false); });
  }

  /* ---------- command palette ---------- */
  function initCommand() {
    var input = $("#cmd");
    var box = $("#results");
    var active = -1;

    function render(items) {
      box.innerHTML = "";
      active = -1;
      if (!items.length) { box.classList.remove("open"); return; }
      items.slice(0, 8).forEach(function (d) {
        var a = el("a");
        a.href = d.url; a.target = "_blank"; a.rel = "noopener";
        a.appendChild(el("span", null, d.label));
        a.appendChild(el("span", "where", d.where));
        box.appendChild(a);
      });
      box.classList.add("open");
    }
    function filter(q) {
      q = q.trim().toLowerCase();
      if (!q) { box.classList.remove("open"); return; }
      render(allDoors.filter(function (d) {
        return (d.label + " " + d.where).toLowerCase().indexOf(q) !== -1;
      }));
    }
    function move(delta) {
      var links = box.querySelectorAll("a");
      if (!links.length) return;
      if (active >= 0) links[active].classList.remove("active");
      active = (active + delta + links.length) % links.length;
      links[active].classList.add("active");
      links[active].scrollIntoView({ block: "nearest" });
    }

    input.addEventListener("input", function () { filter(input.value); });
    input.addEventListener("keydown", function (e) {
      var links = box.querySelectorAll("a");
      if (e.key === "ArrowDown") { e.preventDefault(); move(1); }
      else if (e.key === "ArrowUp") { e.preventDefault(); move(-1); }
      else if (e.key === "Enter") {
        var target = active >= 0 ? links[active] : links[0];
        if (target) { window.open(target.href, "_blank", "noopener"); }
      } else if (e.key === "Escape") { input.value = ""; box.classList.remove("open"); input.blur(); }
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "/" && document.activeElement !== input) { e.preventDefault(); input.focus(); }
    });
    document.addEventListener("click", function (e) {
      if (!box.contains(e.target) && e.target !== input) box.classList.remove("open");
    });
  }

  /* ---------- scratchpad (localStorage) ---------- */
  function initScratch() {
    var ta = $("#scratch");
    var status = $("#scratch-saved");
    var KEY = "olympus_scratch";
    try { ta.value = localStorage.getItem(KEY) || ""; } catch (e) {}
    var timer;
    ta.addEventListener("input", function () {
      status.textContent = "saving...";
      clearTimeout(timer);
      timer = setTimeout(function () {
        try { localStorage.setItem(KEY, ta.value); status.textContent = "saved on this device"; }
        catch (e) { status.textContent = "could not save"; }
      }, 400);
    });
  }

  /* ---------- install prompt ---------- */
  function initInstall() {
    window.addEventListener("beforeinstallprompt", function (e) {
      e.preventDefault();
      var btn = $("#install");
      if (!btn) return;
      btn.style.display = "inline-flex";
      btn.addEventListener("click", function () { e.prompt(); });
    });
  }

  /* ---------- boot ---------- */
  document.addEventListener("DOMContentLoaded", function () {
    $("#greeting").textContent = greet();
    $("#motto").textContent = pickMotto();
    tick(); setInterval(tick, 1000 * 30);
    renderBuildings();
    renderShelf();
    initCommand();
    initScratch();
    initInstall();
  });
})();
