// UI behaviour of the test suite page: plugin filter, group chips, collapsible
// panels and "plugin not enabled" badges. It does not talk to the bridge, so
// the page stays usable in a plain browser.
(function () {
  'use strict';

  var panels = [];
  var currentPanel = null;
  var activeGroup = 'All';

  function $(id) { return document.getElementById(id); }

  function init() {
    panels = Array.prototype.slice.call(document.querySelectorAll('.panel[data-plugin]'));
    buildChips();
    bindFilter();
    bindCollapse();
    bindToolbarButtons();
    trackClicks();
    applyFilter();
  }

  // ── Group chips ──────────────────────────────────────

  function buildChips() {
    var host = $('groupChips');
    var groups = ['All'];
    panels.forEach(function (p) {
      var g = p.getAttribute('data-group');
      if (g && groups.indexOf(g) === -1) groups.push(g);
    });
    groups.forEach(function (g) {
      var chip = document.createElement('button');
      chip.type = 'button';
      chip.className = 'chip' + (g === activeGroup ? ' is-active' : '');
      chip.textContent = g;
      chip.addEventListener('click', function () {
        activeGroup = g;
        Array.prototype.forEach.call(host.children, function (c) {
          c.classList.toggle('is-active', c === chip);
        });
        applyFilter();
      });
      host.appendChild(chip);
    });
  }

  // ── Filtering ────────────────────────────────────────

  function bindFilter() {
    $('panelFilter').addEventListener('input', applyFilter);
  }

  function applyFilter() {
    var q = $('panelFilter').value.trim().toLowerCase();
    var visible = 0;
    panels.forEach(function (p) {
      var text = (p.textContent + ' ' + p.getAttribute('data-plugin')).toLowerCase();
      var groupOk = activeGroup === 'All' || p.getAttribute('data-group') === activeGroup;
      var show = groupOk && (!q || text.indexOf(q) !== -1);
      p.hidden = !show;
      if (show) visible++;
    });
    $('emptyState').hidden = visible !== 0;
  }

  // ── Collapsing ───────────────────────────────────────

  function bindCollapse() {
    panels.forEach(function (p) {
      var title = p.querySelector('.panel-title');
      title.setAttribute('role', 'button');
      title.setAttribute('tabindex', '0');
      title.setAttribute('aria-expanded', 'true');
      function toggle() {
        var collapsed = p.classList.toggle('is-collapsed');
        title.setAttribute('aria-expanded', String(!collapsed));
        syncToggleAll();
      }
      title.addEventListener('click', toggle);
      title.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggle(); }
      });
    });
  }

  function syncToggleAll() {
    var allCollapsed = panels.every(function (p) { return p.classList.contains('is-collapsed'); });
    $('btnToggleAll').textContent = allCollapsed ? 'Expand all' : 'Collapse all';
  }

  function bindToolbarButtons() {
    $('btnToggleAll').addEventListener('click', function () {
      var collapse = $('btnToggleAll').textContent === 'Collapse all';
      panels.forEach(function (p) {
        p.classList.toggle('is-collapsed', collapse);
        p.querySelector('.panel-title').setAttribute('aria-expanded', String(!collapse));
      });
      syncToggleAll();
    });
    $('btnJumpResults').addEventListener('click', function () {
      $('results').scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }

  // ── Which panel started a call ───────────────────────

  function trackClicks() {
    document.addEventListener('click', function (e) {
      var panel = e.target.closest ? e.target.closest('.panel[data-plugin]') : null;
      currentPanel = panel;
    }, true);
  }

  function setUnavailable(panel, unavailable) {
    if (!panel) return;
    var badge = panel.querySelector('.badge');
    var body = panel.querySelector('.panel-body');
    var note = body.querySelector('.panel-note');
    panel.classList.toggle('is-unavailable', unavailable);
    badge.hidden = !unavailable;
    badge.textContent = unavailable ? 'not enabled' : '';
    if (unavailable && !note) {
      note = document.createElement('p');
      note.className = 'panel-note';
      note.textContent = 'The "' + panel.getAttribute('data-plugin') +
        '" plugin is not enabled in this build. Set it to enabled in sweetmelon.yaml ' +
        'and run `dart run bin/sweetmelon.dart sync --apply`.';
      body.insertBefore(note, body.firstChild);
    } else if (!unavailable && note) {
      note.remove();
    }
  }

  window.SweetmelonUI = {
    // Panel whose button is being handled right now (valid synchronously
    // inside a click handler).
    currentPanel: function () { return currentPanel; },
    markUnavailable: function (panel) { setUnavailable(panel, true); },
    markAvailable: function (panel) { setUnavailable(panel, false); }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
