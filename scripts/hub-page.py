#!/usr/bin/env python3
"""Deixa o index.html do bundle com cara de player do Recompendium: só o jogo na
tela, escala Ajustar/Inteira/Esticar + filtro num canto que some (como no
gb-recompiled-web). Os controles do upstream continuam no DOM (o bootstrap.js
usa os ids), só escondidos."""
import sys
from pathlib import Path

HEAD = """<style id="hub">
  html, body { height: 100%; }
  body { margin: 0 !important; padding: 0 !important; background: #111 !important; overflow: hidden;
         display: flex; align-items: center; justify-content: center; font: 14px system-ui, sans-serif !important; }
  #assetbar, #bar, #savebar, #metrics, #downloads, .help, #log { display: none !important; }
  #surface { max-width: none !important; resize: none !important; flex: none; }
  canvas { outline: none; }
  #hubstatus { position: fixed; bottom: 8px; left: 0; right: 0; text-align: center; color: #ccc; }
  #view { position: fixed; right: 12px; bottom: 12px; display: flex; gap: 6px; padding: 6px; border-radius: 8px;
          background: rgba(20,20,20,.85); transition: opacity .3s; z-index: 10; }
  body.idle #view:not(:focus-within) { opacity: 0; pointer-events: none; }
  #view select { background: #222; color: #ddd; border: 1px solid #444; border-radius: 6px; padding: 4px 6px; font: inherit; }
</style>
"""

BODY = """<div id="hubstatus">Carregando…</div>
<div id="view">
  <select id="hubscale" aria-label="Escala">
    <option value="fit">Ajustar à tela</option>
    <option value="int">Inteira (pixel perfeito)</option>
    <option value="stretch">Esticar</option>
  </select>
  <select id="hubfilter" aria-label="Filtro">
    <option value="0">Pixelado</option>
    <option value="2">Nítido</option>
    <option value="1">Suave</option>
  </select>
</div>
<script>
(function () {
  var $ = function (id) { return document.getElementById(id); };
  var surface = $('surface'), scale = $('hubscale'), filter = $('hubfilter'), st = $('hubstatus');
  var rule = document.head.appendChild(document.createElement('style'));
  function get(k, d) { try { return localStorage.getItem('gbaweb-' + k) || d; } catch (e) { return d; } }
  function set(k, v) { try { localStorage.setItem('gbaweb-' + k, v); } catch (e) {} }
  scale.value = get('scale', 'fit');
  filter.value = get('filter', '0');
  function apply() {
    var W = innerWidth, H = innerHeight, w, h;
    if (scale.value === 'stretch') { w = W; h = H; }
    else if (scale.value === 'int') { var k = Math.max(1, Math.floor(Math.min(W / 240, H / 160))); w = 240 * k; h = 160 * k; }
    else { var f = Math.min(W / 240, H / 160); w = Math.floor(240 * f); h = Math.floor(160 * f); }
    globalThis.GbrStretch = scale.value === 'stretch';
    rule.textContent = '#surface{width:' + w + 'px!important;height:' + h + 'px!important}';
  }
  var applied = -1;
  function pushFilter() {  // o host só aceita depois que o runtime sobe
    if (!globalThis.GbrHost || !GbrHost.control) return;
    var v = Number(filter.value);
    if (applied !== v) { GbrHost.store('filter', v); applied = v; }
  }
  scale.onchange = function () { set('scale', scale.value); apply(); $('canvas').focus(); };
  filter.onchange = function () { set('filter', filter.value); applied = -1; pushFilter(); $('canvas').focus(); };
  addEventListener('resize', apply);
  apply();
  setInterval(function () {
    pushFilter();
    var s = $('status').textContent;
    st.hidden = s === 'running';
    st.textContent = s === 'loading' || s === 'idle' ? 'Carregando…' : s.indexOf('failed') === 0 ? 'Erro: ' + s.slice(8) : s;
  }, 250);
  // áudio precisa de um gesto dentro do iframe
  function gesture() { if (globalThis.GbrHost) GbrHost.resumeAudio().catch(function () {}); }
  addEventListener('keydown', gesture); addEventListener('pointerdown', gesture);
  var t;
  function wake() { document.body.classList.remove('idle'); clearTimeout(t); t = setTimeout(function () { document.body.classList.add('idle'); }, 2500); }
  addEventListener('mousemove', wake); addEventListener('touchstart', wake);
  wake();
})();
</script>
"""

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")
assert "</head>" in html and "</body>" in html and 'id="surface"' in html, "index.html inesperado"
html = html.replace("<title>gbarecomp web</title>", "<title>GBA Recompiled</title>")
html = html.replace("</head>", HEAD + "</head>", 1)
html = html.replace("</body>", BODY + "</body>", 1)
path.write_text(html, encoding="utf-8")
