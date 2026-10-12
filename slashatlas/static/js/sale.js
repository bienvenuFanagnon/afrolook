/* Affiche de vente : pose sur une image le rendu final d'une annonce (À VENDRE, prix, réduction, marque, contact, petit QR code).
 * Tout est dessiné ici, avec les vrais textes de la personne : rien n'est écrit par l'IA, donc aucune faute, aucun chiffre déformé.
 * Même code dans le navigateur (Studio « Générer ici ») et dans Node (images d'exemple du site) : saSale.compose(deps, image, options).
 *   deps = { create(w, h) → canvas, qrcode } ; options : voir OPT ci-dessous. */
(function (root, factory) { root.saSale = factory(); })(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  var MODELS = ['band', 'tag', 'badge', 'side', 'ribbon', 'minimal', 'promo'];
  var LABELS = {
    fr: { sale: 'À VENDRE', promo: 'PROMO', new: 'NOUVEAU', rent: 'À LOUER', scan: 'SCANNEZ', cta: 'COMMANDER', off: 'DE RÉDUCTION' },
    en: { sale: 'FOR SALE', promo: 'SALE', new: 'NEW', rent: 'FOR RENT', scan: 'SCAN ME', cta: 'ORDER NOW', off: 'OFF' },
  };
  var CURRENCIES = ['FCFA', '€', '$', '£', '₦', 'GH₵', 'MAD', 'DZD', 'TND', 'GNF', 'CDF', 'RWF', 'KES', 'ZAR'];
  var FONT = 'Manrope, "Helvetica Neue", Arial, system-ui, sans-serif';
  var HEAD = '"Bebas Neue", Manrope, Impact, "Arial Narrow", sans-serif';
  var ACCENTS = ['#ffd23f', '#ff4d4f', '#2fd36b', '#ff9f1a', '#3aa0ff', '#ff5fa2'];

  function rr(ctx, x, y, w, h, r) { r = Math.min(r, w / 2, h / 2); ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r); ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath(); }
  function hash(s) { var h = 2166136261; s = String(s || ''); for (var i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
  /** Plus grande taille (≤ max) pour laquelle le texte tient dans maxW. */
  function fit(ctx, txt, weight, family, max, min, maxW) { var px = max; for (; px > min; px -= 1) { ctx.font = weight + ' ' + px + 'px ' + family; if (ctx.measureText(txt).width <= maxW) break; } ctx.font = weight + ' ' + px + 'px ' + family; return px; }
  function shadowOn(ctx, a, blur, dy) { ctx.shadowColor = 'rgba(0,0,0,' + (a == null ? 0.45 : a) + ')'; ctx.shadowBlur = blur == null ? 14 : blur; ctx.shadowOffsetY = dy == null ? 4 : dy; }
  function shadowOff(ctx) { ctx.shadowColor = 'transparent'; ctx.shadowBlur = 0; ctx.shadowOffsetY = 0; }
  function glass(ctx, x, y, w, h, r, a) { ctx.save(); shadowOn(ctx, 0.35, 22, 6); ctx.fillStyle = 'rgba(12,12,16,' + (a == null ? 0.66 : a) + ')'; rr(ctx, x, y, w, h, r); ctx.fill(); shadowOff(ctx); ctx.lineWidth = 1.5; ctx.strokeStyle = 'rgba(255,255,255,.16)'; rr(ctx, x, y, w, h, r); ctx.stroke(); ctx.restore(); }
  function star(ctx, cx, cy, r, n, k) { ctx.beginPath(); for (var i = 0; i < n * 2; i++) { var a = (i / (n * 2)) * Math.PI * 2 - Math.PI / 2, rad = i % 2 ? r * k : r; ctx.lineTo(cx + Math.cos(a) * rad, cy + Math.sin(a) * rad); } ctx.closePath(); }
  function onColor(c) { var m = /^#([0-9a-f]{6})$/i.exec(c); if (!m) return '#111'; var n = parseInt(m[1], 16), l = 0.299 * (n >> 16) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255); return l > 150 ? '#14110a' : '#ffffff'; }

  /** Prix lisible : « 25000 » → « 25 000 » ; le reste est gardé tel quel. */
  function money(p) { p = String(p || '').trim(); if (/^\d{4,}$/.test(p)) return p.replace(/\B(?=(\d{3})+(?!\d))/g, ' '); return p; }
  function priceParts(o) { var p = money(o.price); if (!p) return null; var cur = String(o.cur || '').trim(); return { num: p, cur: cur, symbolFirst: /^[€$£₦]$/.test(cur) }; }

  function qrBox(ctx, deps, url, x, y, size, pad) {
    if (!url || !deps.qrcode) return false;
    var q; try { q = deps.qrcode(0, 'M'); q.addData(String(url)); q.make(); } catch (e) { return false; }
    var n = q.getModuleCount(), m = size / n;
    ctx.save(); shadowOn(ctx, 0.3, 10, 3); ctx.fillStyle = '#fff'; rr(ctx, x - pad, y - pad, size + 2 * pad, size + 2 * pad, pad * 1.1); ctx.fill(); shadowOff(ctx);
    ctx.fillStyle = '#0d0d0d';
    for (var r = 0; r < n; r++) for (var c = 0; c < n; c++) if (q.isDark(r, c)) ctx.fillRect(x + c * m, y + r * m, Math.ceil(m), Math.ceil(m));
    ctx.restore(); return true;
  }

  /** Prix : chiffres en grand, devise plus petite ; retourne la largeur dessinée. align : 'left' | 'center' | 'right'. */
  function drawPrice(ctx, pp, x, y, px, color, align, head, maxW) {
    var fam = head ? HEAD : FONT, w = head ? '400' : '800';
    if (maxW) { ctx.font = w + ' ' + px + 'px ' + fam; var t0 = ctx.measureText(pp.num).width + (pp.cur ? ctx.measureText(pp.cur).width * 0.5 + px * 0.5 : 0); if (t0 > maxW) px = Math.max(10, Math.floor(px * maxW / t0)); }
    ctx.font = w + ' ' + px + 'px ' + fam; var wn = ctx.measureText(pp.num).width;
    var cpx = Math.round(px * 0.46); ctx.font = '800 ' + cpx + 'px ' + FONT; var wc = pp.cur ? ctx.measureText(pp.cur).width + px * 0.14 : 0;
    var wsym = 0; if (pp.symbolFirst) { ctx.font = '800 ' + Math.round(px * 0.7) + 'px ' + FONT; wsym = ctx.measureText(pp.cur).width + px * 0.06; }
    var total = pp.symbolFirst ? wsym + wn : wn + wc, x0 = align === 'center' ? x - total / 2 : align === 'right' ? x - total : x;
    ctx.textBaseline = 'alphabetic'; ctx.textAlign = 'left'; ctx.fillStyle = color;
    if (pp.symbolFirst) { ctx.font = '800 ' + Math.round(px * 0.7) + 'px ' + FONT; var ws = ctx.measureText(pp.cur).width + px * 0.06; ctx.fillText(pp.cur, x0, y); ctx.font = w + ' ' + px + 'px ' + fam; ctx.fillText(pp.num, x0 + ws, y); return ws + wn; }
    ctx.font = w + ' ' + px + 'px ' + fam; ctx.fillText(pp.num, x0, y);
    if (pp.cur) { ctx.font = '800 ' + cpx + 'px ' + FONT; ctx.fillText(pp.cur, x0 + wn + px * 0.14, y); }
    return total;
  }
  function strike(ctx, txt, x, y, px, color, align) { ctx.font = '700 ' + px + 'px ' + FONT; var w = ctx.measureText(txt).width, x0 = align === 'center' ? x - w / 2 : align === 'right' ? x - w : x; ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic'; ctx.fillStyle = color; ctx.fillText(txt, x0, y); ctx.fillRect(x0 - 3, y - px * 0.32, w + 6, Math.max(2, px * 0.09)); return w; }
  function tagPill(ctx, txt, x, y, px, bg, fg) { ctx.font = '800 ' + px + 'px ' + FONT; var w = ctx.measureText(txt).width + px * 1.5, h = px * 1.85; ctx.save(); shadowOn(ctx, 0.35, 10, 3); ctx.fillStyle = bg; rr(ctx, x, y, w, h, h / 2); ctx.fill(); shadowOff(ctx); ctx.fillStyle = fg; ctx.textAlign = 'left'; ctx.textBaseline = 'middle'; ctx.fillText(txt, x + px * 0.75, y + h / 2 + px * 0.04); ctx.restore(); return { w: w, h: h }; }
  function discStar(ctx, txt, cx, cy, r, bg, fg, rot) { ctx.save(); ctx.translate(cx, cy); ctx.rotate(rot || -0.18); shadowOn(ctx, 0.4, 12, 4); ctx.fillStyle = bg; star(ctx, 0, 0, r, 14, 0.86); ctx.fill(); shadowOff(ctx); ctx.fillStyle = fg; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; var px = fit(ctx, txt, '800', FONT, r * 0.62, 10, r * 1.45); ctx.fillText(txt, 0, px * 0.04); ctx.restore(); }

  /* ───────── les modèles ───────── */
  var DRAW = {
    // bandeau en bas : marque et contact à gauche, prix au centre, QR à droite
    band: function (c, o, S) {
      var W = S.W, H = S.H, u = S.u, hb = Math.max(H * 0.15, 118 * u), y0 = H - hb, pad = 26 * u;
      var g = c.createLinearGradient(0, y0 - 40 * u, 0, H); g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(0.28, 'rgba(8,8,12,.78)'); g.addColorStop(1, 'rgba(8,8,12,.92)'); c.fillStyle = g; c.fillRect(0, y0 - 40 * u, W, hb + 40 * u);
      c.fillStyle = S.accent; c.fillRect(0, y0 + 6 * u, W, 5 * u);
      var qs = o.qr ? S.qrSize(hb * 0.72) : 0, right = W - pad - (qs ? qs + 2 * 10 * u + pad * 0.6 : 0), cy = y0 + hb * 0.55;
      if (qs) qrBox(c, S.deps, o.qr, W - pad - qs - 8 * u, cy - qs / 2, qs, 8 * u);
      var pp = priceParts(o), left = pad, leftW = (W - pad * 2) * (pp ? 0.42 : 0.7);
      if (o.brand) { var bp = fit(c, o.brand, '800', FONT, 40 * u, 16, leftW); c.fillStyle = '#fff'; c.textAlign = 'left'; c.textBaseline = 'alphabetic'; c.fillText(o.brand, left, cy - (o.contact ? 2 * u : -bp * 0.3)); }
      if (o.contact) { var cp = fit(c, o.contact, '700', FONT, 27 * u, 12, leftW); c.fillStyle = 'rgba(255,255,255,.86)'; c.textAlign = 'left'; c.textBaseline = 'alphabetic'; c.fillText(o.contact, left, cy + cp * 1.25 + (o.brand ? 4 * u : -cp * 0.3)); }
      if (pp) { var px = 66 * u; c.save(); if (o.old) strike(c, o.old, right, cy - px * 0.62, 24 * u, 'rgba(255,255,255,.7)', 'right'); drawPrice(c, pp, right, cy + px * 0.38, px, S.accent, 'right', false, (right - left - 20 * u) * 0.75); c.restore(); }
      var ty = y0 - 34 * u; if (S.tag) tagPill(c, S.tag, pad, ty - 28 * u, 25 * u, S.accent, S.onAccent);
      if (o.disc) discStar(c, o.disc, W - pad - 60 * u, y0 - 38 * u, 62 * u, S.accent, S.onAccent);
    },
    // étiquette de prix accrochée en haut à droite, ruban « À VENDRE » en coin, QR en bas à droite
    tag: function (c, o, S) {
      var W = S.W, H = S.H, u = S.u, pad = 30 * u, pp = priceParts(o);
      if (S.tag) { c.save(); c.beginPath(); c.rect(0, 0, W, H); c.clip(); c.translate(0, 0); var rw = 255 * u, rh = 50 * u; c.translate(rw * 0.2, rw * 0.3); c.rotate(-Math.PI / 4); c.fillStyle = S.accent; shadowOn(c, 0.35, 12, 4); c.fillRect(-rw * 0.9, -rh * 0.5 + rw * 0.2, rw * 1.8, rh); shadowOff(c); c.fillStyle = S.onAccent; c.font = '800 ' + 24 * u + 'px ' + FONT; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(S.tag, 0, rw * 0.2 + 1 * u); c.restore(); }
      if (pp) {
        var tw = Math.min(W * 0.4, 330 * u), th = tw * 0.52, tx = W - pad - tw, ty = pad + 14 * u;
        c.save(); c.translate(tx + tw / 2, ty + th / 2); c.rotate(0.07); shadowOn(c, 0.4, 18, 6); c.fillStyle = '#fff'; rr(c, -tw / 2, -th / 2, tw, th, 18 * u); c.fill(); shadowOff(c);
        c.fillStyle = S.accent; rr(c, -tw / 2, -th / 2, tw, 12 * u, 6 * u); c.fill();
        c.fillStyle = '#d9d9de'; c.beginPath(); c.arc(-tw / 2 + 24 * u, 0, 8 * u, 0, 7); c.fill();
        if (o.old) strike(c, o.old, tw * 0.1, -th * 0.2, 22 * u, '#7a7a82', 'center');
        var px = fit(c, pp.num, '800', FONT, 70 * u, 26, tw * 0.58); drawPrice(c, pp, tw * 0.08 + (pp.cur ? 6 * u : 0), th * 0.2, px, '#101014', 'center'); c.restore();
      }
      if (o.disc) discStar(c, o.disc, W - pad - 50 * u, pp ? pad + 14 * u + W * 0.4 * 0.52 + 52 * u : pad + 80 * u, 56 * u, '#ff3b30', '#fff');
      var by = H - pad;
      if (o.brand || o.contact) {
        var bw = Math.min(W * 0.62, 560 * u), bh = (o.brand && o.contact ? 100 : 66) * u; glass(c, pad, by - bh, bw, bh, 22 * u);
        var yy = by - bh + bh * 0.38; if (o.brand) { var bp = fit(c, o.brand, '800', FONT, 36 * u, 15, bw - 36 * u); c.fillStyle = '#fff'; c.textAlign = 'left'; c.textBaseline = 'middle'; c.fillText(o.brand, pad + 18 * u, o.contact ? yy : by - bh / 2); void bp; }
        if (o.contact) { fit(c, o.contact, '700', FONT, 25 * u, 12, bw - 36 * u); c.fillStyle = S.accent; c.textAlign = 'left'; c.textBaseline = 'middle'; c.fillText(o.contact, pad + 18 * u, o.brand ? by - bh + bh * 0.72 : by - bh / 2); }
      }
      if (o.qr) { var qs = S.qrSize(150 * u); qrBox(c, S.deps, o.qr, W - pad - qs - 8 * u, H - pad - qs - 8 * u, qs, 8 * u); }
    },
    // pastille ronde de prix en bas à gauche, marque en haut au centre, contact en bas
    badge: function (c, o, S) {
      var W = S.W, H = S.H, u = S.u, pad = 30 * u, pp = priceParts(o);
      if (o.brand) { var g = c.createLinearGradient(0, 0, 0, 130 * u); g.addColorStop(0, 'rgba(0,0,0,.55)'); g.addColorStop(1, 'rgba(0,0,0,0)'); c.fillStyle = g; c.fillRect(0, 0, W, 130 * u); fit(c, o.brand.toUpperCase(), '800', FONT, 38 * u, 16, W - pad * 2); c.fillStyle = '#fff'; c.textAlign = 'center'; c.textBaseline = 'alphabetic'; shadowOn(c, 0.5, 8, 2); c.fillText(o.brand.toUpperCase(), W / 2, pad + 34 * u); shadowOff(c); }
      if (S.tag) tagPill(c, S.tag, pad, o.brand ? pad + 64 * u : pad, 26 * u, S.accent, S.onAccent);
      if (pp) {
        var r = Math.min(W, H) * 0.19; var cx = pad + r + 4 * u, cy = H - pad - r - (o.contact ? 54 * u : 0);
        c.save(); shadowOn(c, 0.45, 20, 7); c.fillStyle = S.accent; c.beginPath(); c.arc(cx, cy, r, 0, 7); c.fill(); shadowOff(c); c.lineWidth = 4 * u; c.strokeStyle = 'rgba(255,255,255,.75)'; c.beginPath(); c.arc(cx, cy, r - 9 * u, 0, 7); c.stroke();
        if (o.old) strike(c, o.old, cx, cy - r * 0.46, 21 * u, S.onAccent === '#ffffff' ? 'rgba(255,255,255,.8)' : 'rgba(20,17,10,.65)', 'center');
        var px = Math.round(r * 0.62); drawPrice(c, pp, cx, cy + px * 0.34 + (o.old ? 8 * u : 0), px, S.onAccent, 'center', false, r * 1.45); c.restore();
      }
      if (o.disc) discStar(c, o.disc, W - pad - 62 * u, (o.brand ? 150 : 90) * u, 66 * u, '#ff3b30', '#fff');
      if (o.contact) { fit(c, o.contact, '800', FONT, 28 * u, 12, W * 0.62); var w = c.measureText(o.contact).width + 44 * u, h = 52 * u, x = o.qr ? pad : (W - w) / 2, y = H - pad - h; glass(c, x, y, w, h, h / 2, 0.72); c.fillStyle = '#fff'; c.textAlign = 'left'; c.textBaseline = 'middle'; c.fillText(o.contact, x + 22 * u, y + h / 2 + 1 * u); }
      if (o.qr) { var qs = S.qrSize(138 * u); qrBox(c, S.deps, o.qr, W - pad - qs - 8 * u, H - pad - qs - 8 * u, qs, 8 * u); }
    },
    // colonne verre à droite : tout l'essentiel empilé
    side: function (c, o, S) {
      var W = S.W, H = S.H, u = S.u, pad = 24 * u, pw = Math.min(W * 0.3, 330 * u), px0 = W - pad - pw, pp = priceParts(o);
      var qs = o.qr ? S.qrSize(pw * 0.55) : 0; var ph = H - pad * 2; glass(c, px0, pad, pw, ph, 28 * u, 0.62);
      var y = pad + 28 * u, cx = px0 + pw / 2;
      if (S.tag) { c.font = '800 ' + 22 * u + 'px ' + FONT; var tw = c.measureText(S.tag).width + 36 * u; c.fillStyle = S.accent; rr(c, cx - tw / 2, y, tw, 40 * u, 20 * u); c.fill(); c.fillStyle = S.onAccent; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(S.tag, cx, y + 21 * u); y += 70 * u; }
      if (o.brand) { var bp = fit(c, o.brand, '800', FONT, 40 * u, 14, pw - 36 * u); c.fillStyle = '#fff'; c.textAlign = 'center'; c.textBaseline = 'top'; c.fillText(o.brand, cx, y); y += bp * 1.5; }
      c.fillStyle = S.accent; c.fillRect(cx - 28 * u, y, 56 * u, 4 * u); y += 26 * u;
      if (o.disc) { discStar(c, o.disc, cx, y + 54 * u, 58 * u, '#ff3b30', '#fff'); y += 128 * u; }
      if (pp) { if (o.old) { strike(c, o.old, cx, y + 20 * u, 22 * u, 'rgba(255,255,255,.65)', 'center'); y += 34 * u; } var ppx = 62 * u; drawPrice(c, pp, cx, y + ppx * 0.92, ppx, S.accent, 'center', false, pw - 44 * u); y += ppx * 1.3; }
      var bottom = pad + ph - 24 * u;
      if (qs) { qrBox(c, S.deps, o.qr, cx - qs / 2, bottom - qs - 8 * u, qs, 8 * u); bottom -= qs + 40 * u; }
      if (o.contact) { var cp = fit(c, o.contact, '700', FONT, 24 * u, 11, pw - 30 * u); c.fillStyle = 'rgba(255,255,255,.92)'; c.textAlign = 'center'; c.textBaseline = 'alphabetic'; c.fillText(o.contact, cx, bottom - 4 * u); void cp; }
    },
    // ruban en haut (marque + À VENDRE), prix en pilule au centre bas, contact dessous
    ribbon: function (c, o, S) {
      var W = S.W, H = S.H, u = S.u, pad = 28 * u, pp = priceParts(o), hr = 78 * u;
      if (o.brand || S.tag) {
        c.fillStyle = 'rgba(8,8,12,.82)'; c.fillRect(0, 0, W, hr); c.fillStyle = S.accent; c.fillRect(0, hr, W, 5 * u);
        if (o.brand) { fit(c, o.brand.toUpperCase(), '800', FONT, 34 * u, 14, W * (S.tag ? 0.55 : 0.9)); c.fillStyle = '#fff'; c.textAlign = 'left'; c.textBaseline = 'middle'; c.fillText(o.brand.toUpperCase(), pad, hr / 2 + 1 * u); }
        if (S.tag) { c.font = '800 ' + 26 * u + 'px ' + FONT; var tw = c.measureText(S.tag).width + 40 * u; c.fillStyle = S.accent; rr(c, W - pad - tw, hr / 2 - 25 * u, tw, 50 * u, 25 * u); c.fill(); c.fillStyle = S.onAccent; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(S.tag, W - pad - tw / 2, hr / 2 + 1 * u); }
      }
      var by = H - pad - (o.contact ? 56 * u : 0);
      if (pp) { var ppx = 74 * u; c.font = '800 ' + ppx + 'px ' + FONT; var w = c.measureText(pp.num).width + (pp.cur ? ppx * 0.9 : 0) + 70 * u, h = ppx * 1.5, x = (W - w) / 2, y = by - h; c.save(); shadowOn(c, 0.45, 20, 7); c.fillStyle = S.accent; rr(c, x, y, w, h, h / 2); c.fill(); shadowOff(c); if (o.old) strike(c, o.old, x + w / 2, y - 10 * u, 24 * u, '#fff', 'center'); drawPrice(c, pp, x + w / 2, y + h * 0.7, ppx, S.onAccent, 'center', false, w - 50 * u); c.restore(); }
      if (o.disc) discStar(c, o.disc, pad + 64 * u, hr + 96 * u, 62 * u, '#ff3b30', '#fff');
      if (o.contact) { fit(c, o.contact, '800', FONT, 28 * u, 12, W * 0.6); var cw = c.measureText(o.contact).width + 44 * u, ch = 50 * u; glass(c, (W - cw) / 2, H - pad - ch, cw, ch, ch / 2, 0.74); c.fillStyle = '#fff'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(o.contact, W / 2, H - pad - ch / 2 + 1 * u); }
      if (o.qr) { var qs = S.qrSize(132 * u); qrBox(c, S.deps, o.qr, W - pad - qs - 8 * u, H - pad - qs - 8 * u, qs, 8 * u); }
    },
    // sobre : texte posé directement sur l'image, avec ombre, en bas à gauche
    minimal: function (c, o, S) {
      var W = S.W, H = S.H, u = S.u, pad = 34 * u, pp = priceParts(o);
      var g = c.createLinearGradient(0, H * 0.62, 0, H); g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, 'rgba(0,0,0,.66)'); c.fillStyle = g; c.fillRect(0, H * 0.62, W, H * 0.38);
      var y = H - pad;
      c.save(); shadowOn(c, 0.6, 10, 2);
      if (o.contact) { fit(c, o.contact, '700', FONT, 27 * u, 12, W * 0.6); c.fillStyle = 'rgba(255,255,255,.92)'; c.textAlign = 'left'; c.textBaseline = 'alphabetic'; c.fillText(o.contact, pad, y); y -= 46 * u; }
      if (pp) { var ppx = 82 * u; if (o.old) { strike(c, o.old, pad, y - ppx * 0.78, 24 * u, 'rgba(255,255,255,.75)', 'left'); } drawPrice(c, pp, pad, y, ppx, S.accent, 'left', false, W * 0.6); y -= ppx * 1.12; }
      if (o.brand) { fit(c, o.brand, '800', FONT, 38 * u, 14, W * 0.62); c.fillStyle = '#fff'; c.textAlign = 'left'; c.textBaseline = 'alphabetic'; c.fillText(o.brand, pad, y); }
      c.restore();
      if (S.tag) tagPill(c, S.tag, pad, pad, 24 * u, S.accent, S.onAccent);
      if (o.disc) discStar(c, o.disc, W - pad - 54 * u, pad + 58 * u, 58 * u, '#ff3b30', '#fff');
      if (o.qr) { var qs = S.qrSize(128 * u); qrBox(c, S.deps, o.qr, W - pad - qs - 8 * u, H - pad - qs - 8 * u, qs, 8 * u); }
    },
    // promo flash : grosse réduction au centre bas, prix barré, bouton d'action
    promo: function (c, o, S) {
      var W = S.W, H = S.H, u = S.u, pad = 30 * u, pp = priceParts(o), lab = S.L;
      var g = c.createLinearGradient(0, H * 0.55, 0, H); g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, 'rgba(0,0,0,.72)'); c.fillStyle = g; c.fillRect(0, H * 0.55, W, H * 0.45);
      if (S.tag) tagPill(c, S.tag, pad, pad, 26 * u, '#ff3b30', '#fff');
      if (o.brand) { fit(c, o.brand.toUpperCase(), '800', FONT, 32 * u, 14, W * 0.5); c.save(); shadowOn(c, 0.5, 8, 2); c.fillStyle = '#fff'; c.textAlign = 'right'; c.textBaseline = 'alphabetic'; c.fillText(o.brand.toUpperCase(), W - pad, pad + 30 * u); c.restore(); }
      var cy = H - pad - (o.contact || lab.cta ? 150 * u : 70 * u);
      if (o.disc) { var r = 92 * u; discStar(c, o.disc, pad + r + 8 * u, cy - 40 * u, r, '#ff3b30', '#fff', -0.2); }
      if (pp) { var ppx = 92 * u, x = o.disc ? pad + 230 * u : pad; c.save(); shadowOn(c, 0.6, 12, 3); if (o.old) strike(c, o.old, x, cy - ppx * 0.92, 26 * u, 'rgba(255,255,255,.85)', 'left'); drawPrice(c, pp, x, cy - ppx * 0.08, ppx, S.accent, 'left', false, W - x - 170 * u); c.restore(); }
      var by = H - pad - 64 * u, bh = 64 * u, txt = o.contact || lab.cta; fit(c, txt, '800', FONT, 28 * u, 12, W * 0.52); var bw = Math.min(W * 0.6, c.measureText(txt).width + 70 * u);
      c.save(); shadowOn(c, 0.45, 14, 4); c.fillStyle = S.accent; rr(c, pad, by, bw, bh, bh / 2); c.fill(); shadowOff(c); c.fillStyle = S.onAccent; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(txt, pad + bw / 2, by + bh / 2 + 1 * u); c.restore();
      if (o.qr) { var qs = S.qrSize(128 * u); qrBox(c, S.deps, o.qr, W - pad - qs - 8 * u, H - pad - qs - 8 * u, qs, 8 * u); }
    },
  };

  /** Couleur d'accent : celle demandée, sinon une couleur vive qui ressort sur l'image (teinte opposée à la teinte dominante). */
  var PALETTE = [['#ffd23f', 48], ['#ff9f1a', 32], ['#ff4d4f', 358], ['#ff5fa2', 335], ['#2fd36b', 140], ['#3aa0ff', 210], ['#b47cff', 270]];
  function pickAccent(o, img, deps) {
    if (o.accent) return o.accent;
    try {
      var s = deps.create(16, 16), x = s.getContext('2d'); x.drawImage(img, 0, 0, 16, 16); var d = x.getImageData(0, 0, 16, 16).data, r = 0, g = 0, b = 0, n = d.length / 4;
      for (var i = 0; i < d.length; i += 4) { r += d[i]; g += d[i + 1]; b += d[i + 2]; } r /= n; g /= n; b /= n;
      var mx = Math.max(r, g, b), mn = Math.min(r, g, b), h = 0; if (mx - mn > 18) { if (mx === r) h = (60 * ((g - b) / (mx - mn)) + 360) % 360; else if (mx === g) h = 60 * ((b - r) / (mx - mn)) + 120; else h = 60 * ((r - g) / (mx - mn)) + 240; } else return ['#ffd23f', '#ff4d4f', '#2fd36b', '#ff9f1a'][hash(o.brand + o.price + o.model) % 4];
      var ok = PALETTE.filter(function (p) { var dd = Math.abs(p[1] - h); dd = Math.min(dd, 360 - dd); return dd > 55; });
      return (ok.length ? ok : PALETTE)[hash(o.brand + o.price + o.model) % (ok.length || PALETTE.length)][0];
    } catch (e) { return ACCENTS[0]; }
  }

  /**
   * Compose l'affiche. options : { model, lang, tag: 'sale'|'promo'|'new'|'rent'|'', price, cur, old, disc, brand, contact, qr (URL), qrSize: 's'|'m', accent }
   * Retourne le canvas (même taille que l'image, 2200 px au plus).
   */
  function compose(deps, img, o) {
    o = o || {}; var k = Math.min(1, 2200 / Math.max(img.width, img.height)), W = Math.round(img.width * k), H = Math.round(img.height * k);
    var cv = deps.create(W, H), c = cv.getContext('2d'); c.drawImage(img, 0, 0, W, H);
    var model = MODELS.indexOf(o.model) >= 0 ? o.model : MODELS[hash(o.brand + '|' + o.price) % MODELS.length];
    var L = LABELS[o.lang === 'en' ? 'en' : 'fr'], accent = pickAccent(Object.assign({}, o, { model: model }), img, deps);
    var u = Math.min(W, H) / 1000; var sizes = { s: 0.78, m: 1 };
    var S = { W: W, H: H, u: u, deps: deps, accent: accent, onAccent: onColor(accent), L: L, tag: o.tagText || (o.tag ? L[o.tag] || '' : ''), qrSize: function (base) { return Math.min(base * (sizes[o.qrSize] || sizes.s), Math.min(W, H) * 0.19); } };
    var oo = { brand: String(o.brand || '').trim(), contact: String(o.contact || '').trim(), price: o.price, cur: o.cur, old: String(o.old || '').trim(), disc: String(o.disc || '').trim(), qr: o.qr || '' };
    c.save(); DRAW[model](c, oo, S); c.restore();
    return cv;
  }

  return { MODELS: MODELS, CURRENCIES: CURRENCIES, LABELS: LABELS, compose: compose, money: money };
});
