// Studio SlashAtlas, onglet « Vidéo » : une photo, un bouton, une vidéo pub.
// Tout le reste (détourage du produit, texte, style, musique, effets, voix off, QR code) est choisi automatiquement côté serveur ;
// la personne peut seulement ajouter quelques mots, ou ouvrir « Personnaliser » si elle veut changer quelque chose.
// Chargé par try.js. Le rendu se fait côté serveur ; ici : formulaire, appel, aperçu, téléchargement, partage.
(function () {
  'use strict';
  var L = document.body.dataset.lang === 'en' ? 'en' : 'fr';
  var T = {
    fr: {
      title: 'Créez une vidéo pub pour votre produit', lead: 'Ajoutez une photo et touchez le bouton. Le reste est automatique.',
      photos: 'Votre photo', photosHint: 'De 1 à 3 photos du produit (une suffit).', add: 'Ajouter une photo', remove: 'Retirer',
      moreT: 'Un mot sur votre produit (facultatif)', about: 'Décrivez-le en quelques mots', aboutPh: 'ex. lotion hydratante pour le corps', brand: ['Votre marque', 'ex. Maison Awa'], price: ['Prix', 'ex. 12 500 FCFA'], contact: ['WhatsApp ou site', 'ex. +225 07 00 00 00 00'],
      moreHint: 'Laissez vide : l’IA regarde votre photo et écrit tout. Un numéro WhatsApp ou un site devient un QR code à la fin.',
      auto: 'Ce que fait le site pour vous : il détoure votre produit, écrit les textes, choisit le style, ajoute la musique, les effets sonores et une voix off.',
      create: 'Créer ma vidéo', again: 'Refaire avec mes changements', credit: 'crédit', credits: 'crédits', needPhoto: 'Ajoutez une photo', working: 'Création de votre vidéo…', workHint: 'Cela prend environ une minute. Ne fermez pas la page.',
      steps: ['Analyse de votre photo…', 'Détourage du produit…', 'Mise en scène et animations…', 'Musique, effets et voix…', 'Finalisation…'],
      perso: 'Personnaliser (facultatif)', persoHint: 'Tout est déjà choisi pour vous. Changez seulement ce que vous voulez.',
      model: 'Type de vidéo', models: { auto: ['Automatique', 'Le site choisit pour votre produit'], zoom: ['Gros plan cinéma', 'Zoom sur les détails'], tour360: ['Tour à 360°', 'Le produit tourne sur lui-même'], lancement: ['Lancement', 'Révélation lumineuse, puis détails'], classique: ['Pub complète', 'Accroche, produit, atouts'], promo: ['Promo flash', 'Prix et offre en avant'], catalogue: ['Catalogue', 'Plusieurs photos, une par plan'] },
      style: 'Style', styles: { auto: ['Automatique', 'Choisi d’après votre produit'], mode: ['Mode', 'Dynamique et coloré'], beaute: ['Beauté', 'Doux et élégant'], promo: ['Promo flash', 'Énergique, prix en avant'] },
      format: 'Format', formats: { '9:16': ['Vertical', 'TikTok, Reels, statuts'], '1:1': ['Carré', 'Facebook, Instagram'], '16:9': ['Paysage', 'YouTube'] },
      music: 'Musique', musics: { '': ['Automatique', 'Selon le style'], beat: ['Rythmée', 'Beat dynamique'], ambient: ['Ambiance', 'Nappes calmes'], none: ['Aucune', 'Effets seulement'] }, sfx: 'Effets sonores calés sur les mouvements',
      voice: 'Voix off', voiceF: 'Voix de femme', voiceM: 'Voix d’homme', voiceOff: 'Sans voix', voiceText: 'Texte lu par la voix (modifiable)', seg: { hook: 'Accroche', product: 'Présentation', benefits: 'Atouts', offer: 'Prix ou offre', cta: 'Appel à l’action' },
      texts: 'Textes de la vidéo', hook: ['Accroche', 'ex. Une peau qui rayonne'], l1: ['Atout 1', 'ex. Hydratation 24 h'], l2: ['Atout 2', 'ex. Sans parfum ni alcool'], l3: ['Atout 3', 'facultatif'], oldPrice: ['Ancien prix', 'facultatif'], offer: ['Pastille', 'ex. -25 %'], cta: ['Appel à l’action', 'ex. Commander sur WhatsApp'],
      qr: 'QR code (adresse de votre site ou WhatsApp)', qrPh: 'facultatif', ai: 'Écrire les textes avec l’IA', aiWait: 'Écriture…', cutout: 'Produit', cutouts: { smart: ['Détourage automatique', 'Recommandé'], off: ['Photo entière', 'Sans détourage'] },
      done: 'Votre vidéo est prête', download: 'Télécharger', share: 'Partager', modify: 'Modifier', shareText: 'Ma vidéo créée avec SlashAtlas', my: 'Mes dernières vidéos', open: 'Voir', sec: 's', refund: 'Les crédits sont remboursés si la création échoue.',
      lost: 'La connexion s’est interrompue. La vidéo est peut-être prête : regardez dans « Mes dernières vidéos » dans une minute.',
      e: { too_long: 'Les textes sont trop longs : raccourcissez-les.', voice_error: 'La voix off n’a pas pu être créée. Réessayez, ou choisissez « Sans voix » dans Personnaliser.', render_failed: 'La création a échoué. Vos crédits ont été rendus. Réessayez.', no_video: 'Vidéo introuvable.', script_failed: 'L’écriture automatique n’a pas répondu. Réessayez dans un instant.', no_about: 'Décrivez votre produit en quelques mots.', daily_limit: 'Limite du jour atteinte. Revenez demain.', busy: 'Beaucoup de demandes en ce moment. Réessayez dans quelques minutes.', origin: 'Adresse non autorisée.' },
    },
    en: {
      title: 'Create a video ad for your product', lead: 'Add a photo and tap the button. The rest is automatic.',
      photos: 'Your photo', photosHint: '1 to 3 photos of the product (one is enough).', add: 'Add a photo', remove: 'Remove',
      moreT: 'A word about your product (optional)', about: 'Describe it in a few words', aboutPh: 'e.g. moisturizing body lotion', brand: ['Your brand', 'e.g. Maison Awa'], price: ['Price', 'e.g. $21'], contact: ['WhatsApp or website', 'e.g. +225 07 00 00 00 00'],
      moreHint: 'Leave empty: the AI looks at your photo and writes everything. A WhatsApp number or a website becomes a QR code at the end.',
      auto: 'What the site does for you: it cuts out your product, writes the texts, picks the style, adds the music, sound effects and a voice-over.',
      create: 'Create my video', again: 'Redo with my changes', credit: 'credit', credits: 'credits', needPhoto: 'Add a photo', working: 'Creating your video…', workHint: 'This takes about a minute. Do not close the page.',
      steps: ['Analyzing your photo…', 'Cutting out the product…', 'Staging and animations…', 'Music, effects and voice…', 'Finalizing…'],
      perso: 'Customize (optional)', persoHint: 'Everything is already chosen for you. Only change what you want.',
      model: 'Video type', models: { auto: ['Automatic', 'The site picks for your product'], zoom: ['Cinematic close-up', 'Zoom on the details'], tour360: ['360° spin', 'The product turns around'], lancement: ['Launch', 'Light reveal, then details'], classique: ['Full ad', 'Hook, product, benefits'], promo: ['Flash sale', 'Price and offer first'], catalogue: ['Catalog', 'Several photos, one per shot'] },
      style: 'Style', styles: { auto: ['Automatic', 'Chosen from your product'], mode: ['Fashion', 'Dynamic and colorful'], beaute: ['Beauty', 'Soft and elegant'], promo: ['Flash sale', 'Energetic, price first'] },
      format: 'Format', formats: { '9:16': ['Vertical', 'TikTok, Reels, statuses'], '1:1': ['Square', 'Facebook, Instagram'], '16:9': ['Landscape', 'YouTube'] },
      music: 'Music', musics: { '': ['Automatic', 'Depends on the style'], beat: ['Upbeat', 'Dynamic beat'], ambient: ['Ambient', 'Calm pads'], none: ['None', 'Effects only'] }, sfx: 'Sound effects synced with the movements',
      voice: 'Voice-over', voiceF: 'Female voice', voiceM: 'Male voice', voiceOff: 'No voice', voiceText: 'Text read by the voice (editable)', seg: { hook: 'Hook', product: 'Introduction', benefits: 'Benefits', offer: 'Price or offer', cta: 'Call to action' },
      texts: 'Video texts', hook: ['Hook', 'e.g. Skin that glows'], l1: ['Benefit 1', 'e.g. 24-hour hydration'], l2: ['Benefit 2', 'e.g. No perfume, no alcohol'], l3: ['Benefit 3', 'optional'], oldPrice: ['Old price', 'optional'], offer: ['Badge', 'e.g. -25%'], cta: ['Call to action', 'e.g. Order on WhatsApp'],
      qr: 'QR code (your website or WhatsApp)', qrPh: 'optional', ai: 'Write the texts with AI', aiWait: 'Writing…', cutout: 'Product', cutouts: { smart: ['Automatic cut-out', 'Recommended'], off: ['Whole photo', 'No cut-out'] },
      done: 'Your video is ready', download: 'Download', share: 'Share', modify: 'Edit', shareText: 'My video made with SlashAtlas', my: 'My latest videos', open: 'Open', sec: 's', refund: 'Credits are refunded if the creation fails.',
      lost: 'The connection was interrupted. The video may be ready: check “My latest videos” in a minute.',
      e: { too_long: 'The texts are too long: shorten them.', voice_error: 'The voice-over could not be created. Try again, or pick “No voice” in Customize.', render_failed: 'Creation failed. Your credits were returned. Please try again.', no_video: 'Video not found.', script_failed: 'Automatic writing did not respond. Please try again in a moment.', no_about: 'Describe your product in a few words.', daily_limit: 'Daily limit reached. Come back tomorrow.', busy: 'Many requests right now. Try again in a few minutes.', origin: 'Address not allowed.' },
    },
  }[L];
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var st = { model: 'auto', style: 'auto', ratio: '9:16', photos: [], f: { brand: '', hook: '', l1: '', l2: '', l3: '', price: '', oldPrice: '', offer: '', cta: '', contact: '' }, qr: '', voice: true, gender: 'f', music: '', sfx: true, cutout: 'smart', vt: {}, vtServer: false, about: '', busy: false, ai: false, open: false, edited: false, result: null, list: null, listLoaded: false, step: 0 };
  var api = null, el = null, stepTimer = null;
  var _persoTracked = false; // track ouverture Personnaliser une seule fois

  function lines() { return [st.f.l1, st.f.l2, st.f.l3].map(function (x) { return x.trim(); }).filter(Boolean); }
  function autoVoice() {
    var f = st.f, ls = lines(), en = L === 'en';
    return { hook: f.hook.trim(), product: [f.brand.trim() ? (en ? 'Discover ' + f.brand.trim() + '.' : 'Découvrez ' + f.brand.trim() + '.') : '', ls[0] || ''].filter(Boolean).join(' '), benefits: ls.join('. '),
      offer: [f.offer.trim(), f.price.trim() ? (en ? 'Only ' + f.price.trim() + '.' : 'Seulement ' + f.price.trim() + '.') : ''].filter(Boolean).join('. '), cta: [f.cta.trim(), f.contact.trim()].filter(Boolean).join('. ') };
  }
  function voiceSegs() { var a = autoVoice(), o = {}; Object.keys(a).forEach(function (k) { o[k] = st.vt[k] != null ? st.vt[k] : a[k]; }); return o; }
  function cost() { var v = (api.cfg && api.cfg.video) || { base: 4 }; return v.base || 4; }
  function field(k) { var max = k === 'hook' ? 60 : k === 'price' || k === 'oldPrice' ? 24 : k === 'offer' ? 16 : k === 'cta' ? 30 : k === 'brand' || k === 'contact' ? 40 : 48; return '<label>' + esc(T[k][0]) + '<input type="text" data-f="' + k + '" maxlength="' + max + '" placeholder="' + esc(T[k][1]) + '" value="' + esc(st.f[k]) + '" autocomplete="off"></label>'; }
  function seg(attr, cur, items) { return '<div class="vseg" role="group">' + items.map(function (it) { return '<button type="button" data-' + attr + '="' + it[0] + '" aria-pressed="' + (cur === it[0]) + '"><b>' + esc(it[1]) + '</b>' + (it[2] ? '<small>' + esc(it[2]) + '</small>' : '') + '</button>'; }).join('') + '</div>'; }
  function ready() { return st.photos.length && !st.busy; }
  function buttonLabel() { var enough = api.credits >= cost(); if (st.busy) return T.working; if (!st.photos.length) return T.needPhoto; if (!enough) return api.T.buy; return (st.edited ? T.again : T.create) + ' · ' + cost() + ' ' + (cost() === 1 ? T.credit : T.credits); }

  function perso() {
    var segs = voiceSegs(), has = { hook: 1, product: 1, benefits: lines().length >= 2, offer: st.f.price.trim() || st.f.offer.trim(), cta: 1 };
    return '<details class="brandbox sf vperso"' + (st.open ? ' open' : '') + '><summary>' + T.perso + '</summary><p class="hint">' + T.persoHint + '</p>' +
      '<div class="sf"><b>' + T.model + '</b>' + seg('model', st.model, ['auto', 'zoom', 'tour360', 'lancement', 'classique', 'promo', 'catalogue'].map(function (k) { return [k, T.models[k][0], T.models[k][1]]; })) + '</div>' +
      '<div class="sf"><b>' + T.style + '</b>' + seg('style', st.style, ['auto', 'mode', 'beaute', 'promo'].map(function (k) { return [k, T.styles[k][0], T.styles[k][1]]; })) + '</div>' +
      '<div class="sf"><b>' + T.format + '</b>' + seg('ratio', st.ratio, ['9:16', '1:1', '16:9'].map(function (k) { return [k, T.formats[k][0], T.formats[k][1]]; })) + '</div>' +
      '<div class="sf"><b>' + T.texts + '</b><div class="bgrid">' + ['hook', 'l1', 'l2', 'l3', 'offer', 'oldPrice', 'cta'].map(field).join('') + '</div><button class="btn gl' + (st.ai ? ' loading' : '') + '" type="button" id="v-ai"' + (st.ai ? ' disabled' : '') + '>' + (st.ai ? T.aiWait : '✨ ' + T.ai) + '</button></div>' +
      '<div class="sf"><b>' + T.qr + '</b><input type="text" id="v-qr" maxlength="200" placeholder="' + esc(T.qrPh) + '" value="' + esc(st.qr) + '" autocomplete="off"></div>' +
      '<div class="sf"><b>' + T.music + '</b>' + seg('music', st.music, ['', 'beat', 'ambient', 'none'].map(function (k) { return [k, T.musics[k][0], T.musics[k][1]]; })) + '<label class="vchk"><input type="checkbox" id="v-sfx"' + (st.sfx ? ' checked' : '') + '><span>' + T.sfx + '</span></label></div>' +
      '<div class="sf"><b>' + T.voice + '</b>' + seg('voice', st.voice ? st.gender : 'off', [['f', T.voiceF], ['m', T.voiceM], ['off', T.voiceOff]]) +
      (st.voice ? '<details class="brandbox sf"><summary>' + T.voiceText + '</summary>' + ['hook', 'product', 'benefits', 'offer', 'cta'].filter(function (k) { return has[k]; }).map(function (k) { return '<label>' + T.seg[k] + '<textarea rows="2" maxlength="240" data-vt="' + k + '">' + esc(segs[k]) + '</textarea></label>'; }).join('') + '</details>' : '') + '</div>' +
      '<div class="sf"><b>' + T.cutout + '</b>' + seg('cutout', st.cutout, ['smart', 'off'].map(function (k) { return [k, T.cutouts[k][0], T.cutouts[k][1]]; })) + '</div></details>';
  }

  function html() {
    var thumbs = st.photos.map(function (p, i) { return '<figure class="ph"><img src="' + p.url + '" alt=""><button type="button" data-rm="' + i + '" aria-label="' + T.remove + '">×</button></figure>'; }).join('');
    var add = st.photos.length < 3 ? '<label class="addph"><input id="v-file" type="file" accept="image/jpeg,image/png,image/webp,image/*" multiple hidden><span>+</span><small>' + T.add + '</small></label>' : '';
    var enough = api.credits >= cost();
    return '<div class="sbox vbox"><div><h2 class="vh">' + T.title + '</h2><p class="hint">' + T.lead + '</p></div>' +
      '<div class="sf"><b>' + T.photos + '</b><div class="phs">' + thumbs + add + '</div><small class="hint">' + T.photosHint + '</small></div>' +
      '<div class="sf vmore"><b>' + T.moreT + '</b><label>' + T.about + '<textarea id="v-about" rows="2" maxlength="240" placeholder="' + esc(T.aboutPh) + '">' + esc(st.about) + '</textarea></label><div class="bgrid">' + ['brand', 'price', 'contact'].map(field).join('') + '</div><small class="hint">' + T.moreHint + '</small></div>' +
      '<button class="btn pri big' + (st.busy ? ' loading' : '') + '" type="button" id="v-go"' + (!ready() && enough ? ' disabled' : '') + '>' + buttonLabel() + '</button>' +
      '<p class="fmsg" id="v-msg" role="status" aria-live="polite"></p><small class="hint">' + T.auto + ' ' + T.refund + '</small>' +
      (st.busy ? '<div class="vwork" role="status"><div class="vbar"><i></i></div><b>' + esc(T.steps[Math.min(st.step, T.steps.length - 1)]) + '</b><small>' + T.workHint + '</small></div>' : '') +
      perso() + '</div>' +
      (st.result ? '<div class="sres vres"><h3>' + T.done + '</h3><video controls playsinline loop src="' + st.result.url + '"></video><div class="acts big"><a class="btn pri big" href="' + st.result.url + '" download="slashatlas-video.mp4">' + T.download + '</a>' + (st.result.canShare ? '<button class="btn gl big" type="button" id="v-share">' + T.share + '</button>' : '') + '<button class="btn gl big" type="button" id="v-again">' + T.modify + '</button></div></div>' : '') +
      (st.list && st.list.length ? '<div class="sbox"><b>' + T.my + '</b><div class="vlist">' + st.list.map(function (v) { var sub = (T.styles[v.style] ? T.styles[v.style][0] : '') + ' · ' + v.ratio + ' · ' + Math.round(v.seconds) + T.sec; return '<div class="vrow"><span>' + esc(v.brand || v.hook || '—') + '<small>' + esc(sub) + '</small></span><button class="btn gl sm" type="button" data-open="' + v.id + '">' + T.open + '</button></div>'; }).join('') + '</div></div>' : '');
  }

  function msg(t, ok) { var m = el.querySelector('#v-msg'); if (m) { m.textContent = t || ''; m.className = 'fmsg' + (ok ? ' ok' : ''); } }
  var errText = function (c) { return T.e[c] || api.errText(c); };
  function draw() {
    var a = document.activeElement; var keep = a && a.dataset ? { f: a.dataset.f, vt: a.dataset.vt, id: a.id } : null; var pos = keep && a.selectionStart;
    var det = el.querySelector('.vperso'); if (st.forceOpen) { st.open = true; st.forceOpen = false; } else if (det) st.open = det.open;
    el.innerHTML = html(); bind();
    if (keep) { var q = keep.f ? '[data-f="' + keep.f + '"]' : keep.vt ? '[data-vt="' + keep.vt + '"]' : keep.id ? '#' + keep.id : null; var n = q && el.querySelector(q); if (n) { n.focus(); try { n.setSelectionRange(pos, pos); } catch (e) { /* champ sans curseur */ } } }
  }
  // le texte lu par la voix suit les textes de la vidéo, sans redessiner la page (un redessin ferait perdre un appui sur le bouton)
  function syncVoice() { var segs = voiceSegs(); Array.prototype.forEach.call(el.querySelectorAll('[data-vt]'), function (t) { if (t !== document.activeElement && segs[t.dataset.vt] != null) t.value = segs[t.dataset.vt]; }); }
  function touched() { st.edited = st.edited || !!st.result; if (st.vtServer) { st.vt = {}; st.vtServer = false; } }
  function bind() {
    Array.prototype.forEach.call(el.querySelectorAll('[data-model]'), function (b) { b.addEventListener('click', function () { st.model = b.dataset.model; if (window.saTrack) window.saTrack('video_model', { f: 'video', v: b.dataset.model }); draw(); }); });
    Array.prototype.forEach.call(el.querySelectorAll('[data-style]'), function (b) { b.addEventListener('click', function () { st.style = b.dataset.style; if (window.saTrack) window.saTrack('video_style', { f: 'video', v: b.dataset.style }); draw(); }); });
    Array.prototype.forEach.call(el.querySelectorAll('[data-ratio]'), function (b) { b.addEventListener('click', function () { st.ratio = b.dataset.ratio; if (window.saTrack) window.saTrack('video_ratio', { f: 'video', v: b.dataset.ratio }); draw(); }); });
    Array.prototype.forEach.call(el.querySelectorAll('[data-music]'), function (b) { b.addEventListener('click', function () { st.music = b.dataset.music; draw(); }); });
    Array.prototype.forEach.call(el.querySelectorAll('[data-cutout]'), function (b) { b.addEventListener('click', function () { st.cutout = b.dataset.cutout; draw(); }); });
    Array.prototype.forEach.call(el.querySelectorAll('[data-voice]'), function (b) { b.addEventListener('click', function () { var v = b.dataset.voice; st.voice = v !== 'off'; if (st.voice) st.gender = v; draw(); }); });
    var sx = el.querySelector('#v-sfx'); if (sx) sx.addEventListener('change', function () { st.sfx = sx.checked; });
    Array.prototype.forEach.call(el.querySelectorAll('[data-rm]'), function (b) { b.addEventListener('click', function () { var p = st.photos.splice(+b.dataset.rm, 1)[0]; if (p) URL.revokeObjectURL(p.url); draw(); }); });
    var f = el.querySelector('#v-file'); if (f) f.addEventListener('change', function () { addFiles(f.files); });
    Array.prototype.forEach.call(el.querySelectorAll('[data-f]'), function (i) { i.addEventListener('input', function () { st.f[i.dataset.f] = i.value; if (i.dataset.f !== 'brand' && i.dataset.f !== 'price' && i.dataset.f !== 'contact') touched(); syncVoice(); }); });
    Array.prototype.forEach.call(el.querySelectorAll('[data-vt]'), function (i) { i.addEventListener('input', function () { st.vt[i.dataset.vt] = i.value; st.vtServer = false; }); });
    var q = el.querySelector('#v-qr'); if (q) q.addEventListener('input', function () { st.qr = q.value; });
    var a = el.querySelector('#v-about'); if (a) a.addEventListener('input', function () { st.about = a.value; });
    var ai = el.querySelector('#v-ai'); if (ai) ai.addEventListener('click', writeWithAi);
    var go = el.querySelector('#v-go'); if (go) go.addEventListener('click', function () { if (api.credits < cost()) { if (window.saTrack) window.saTrack('video_nocredit', { f: 'video' }); api.openBuy('video'); } else { if (window.saTrack) window.saTrack('video_start', { f: 'video', model: st.model, style: st.style, ratio: st.ratio }); create(); } });
    var det = el.querySelector('.vperso'); if (det && !_persoTracked) { det.addEventListener('toggle', function () { if (det.open) { _persoTracked = true; if (window.saTrack) window.saTrack('video_perso_open', { f: 'video' }); } }, { once: true }); }
    var sh = el.querySelector('#v-share'); if (sh) sh.addEventListener('click', share);
    var ag = el.querySelector('#v-again'); if (ag) ag.addEventListener('click', modify);
    Array.prototype.forEach.call(el.querySelectorAll('[data-open]'), function (b) { b.addEventListener('click', function () { openSaved(b.dataset.open, b); }); });
  }

  function addFiles(list) {
    var files = Array.prototype.slice.call(list).slice(0, 3 - st.photos.length);
    Promise.all(files.map(function (f) { return api.shrink(f).catch(function () { return null; }); })).then(function (r) { r.forEach(function (p) { if (p) st.photos.push(p); }); draw(); if (r.some(function (p) { return !p; })) msg(api.errText('bad_photo')); });
  }
  function writeWithAi() {
    if (st.ai) return; var about = st.about.trim() || st.f.brand.trim(); if (about.length < 4) { return msg(T.e.no_about); }
    st.ai = true; draw();
    api.call('video/script', { lang: L, about: about, style: st.style === 'auto' ? 'mode' : st.style, texts: { brand: st.f.brand, price: st.f.price, offer: st.f.offer } }).then(function (r) {
      st.ai = false; st.forceOpen = true;
      if (r.status === 200) { var d = r.data; if (d.hook) st.f.hook = d.hook; (d.lines || []).forEach(function (x, i) { st.f['l' + (i + 1)] = x; }); if (d.cta && !st.f.cta) st.f.cta = d.cta; if (d.voice) { st.vt = { hook: d.voice.hook, product: d.voice.product, benefits: d.voice.benefits, offer: d.voice.offer, cta: d.voice.cta }; st.vtServer = true; } draw(); }
      else { draw(); msg(errText(r.data && r.data.error)); }
    }).catch(function () { st.ai = false; draw(); msg(api.errText('server')); });
  }

  function create() {
    if (st.busy || !st.photos.length) return;
    st.busy = true; st.result = null; st.step = 0; draw(); msg('');
    stepTimer = setInterval(function () { st.step++; var b = el.querySelector('.vwork b'); if (b) b.textContent = T.steps[Math.min(st.step, T.steps.length - 1)]; }, 9000);
    var texts = { brand: st.f.brand, hook: st.f.hook, lines: lines(), price: st.f.price, oldPrice: st.f.oldPrice, offer: st.f.offer, cta: st.f.cta, contact: st.f.contact };
    var body = { lang: L, ratio: st.ratio, about: st.about, texts: texts, qr: st.qr.trim(), cutout: st.cutout, sfx: st.sfx,
      voice: st.voice ? { on: true, gender: st.gender, segments: (st.f.hook.trim() || Object.keys(st.vt).length) ? voiceSegs() : undefined } : false,
      photos: st.photos.map(function (p) { return { mime: p.mime, data: p.data }; }) };
    if (st.style !== 'auto') body.style = st.style; if (st.model !== 'auto') body.model = st.model; if (st.music) body.music = st.music;
    var url = api.renderUrl;
    if (!url) { done(); return msg(api.errText('server')); }
    api.post(url, body, 530000).then(function (r) {
      if (r.status === 200) {
        api.setCredits(r.data.credits); var used = r.data.used || {};
        return api.blob('video/file', { id: r.data.id }).then(function (b) {
          st.result = { id: r.data.id, url: URL.createObjectURL(b), blob: b, used: used, canShare: !!(navigator.canShare && navigator.canShare({ files: [new File([b], 'v.mp4', { type: 'video/mp4' })] })) };
          if (window.saTrack) window.saTrack('video_done', { f: 'video', style: used.style || st.style, model: used.model || st.model, ratio: st.ratio });
          done(); loadList(); window.scrollTo({ top: el.querySelector('.vres').offsetTop - 70, behavior: 'smooth' });
        });
      }
      done(); if (r.data && r.data.error === 'insufficient_credits') { api.openBuy('serveur'); return; } msg(errText(r.data && r.data.error)); api.refreshMe();
    }).catch(function () { done(); msg(T.lost); setTimeout(loadList, 45000); api.refreshMe(); });
  }
  function done() { clearInterval(stepTimer); st.busy = false; draw(); }
  // « Modifier » : reprend ce que le site avait choisi, dans « Personnaliser », pour changer ce qu'on veut puis refaire
  function modify() {
    var u = st.result && st.result.used; if (u) {
      var t = u.texts || {}; ['brand', 'hook', 'price', 'oldPrice', 'offer', 'cta', 'contact'].forEach(function (k) { st.f[k] = t[k] || ''; }); var ls = t.lines || []; st.f.l1 = ls[0] || ''; st.f.l2 = ls[1] || ''; st.f.l3 = ls[2] || '';
      if (u.style) st.style = u.style; if (u.model) st.model = u.model; if (u.voice) { st.voice = true; st.gender = u.voice.gender || 'f'; st.vt = u.voice.segments || {}; st.vtServer = true; } else st.voice = false;
    }
    st.edited = true; st.forceOpen = true; st.result = null; draw(); var p = el.querySelector('.vperso'); if (p) window.scrollTo({ top: p.offsetTop - 80, behavior: 'smooth' });
  }
  function share() { if (window.saTrack) window.saTrack('video_share', { f: 'video' }); var b = st.result && st.result.blob; if (!b) return; try { navigator.share({ files: [new File([b], 'slashatlas-video.mp4', { type: 'video/mp4' })], text: T.shareText }).catch(function () {}); } catch (e) { /* partage annulé */ } }
  function openSaved(id, btn) { btn.disabled = true; api.blob('video/file', { id: id }).then(function (b) { st.result = { id: id, url: URL.createObjectURL(b), blob: b, used: null, canShare: !!(navigator.canShare && navigator.canShare({ files: [new File([b], 'v.mp4', { type: 'video/mp4' })] })) }; draw(); var r = el.querySelector('.vres'); if (r) window.scrollTo({ top: r.offsetTop - 70, behavior: 'smooth' }); }).catch(function () { btn.disabled = false; msg(T.e.no_video); }); }
  function loadList() { api.call('video/list').then(function (r) { if (r.status === 200) { st.list = r.data.videos; if (!st.busy) draw(); } }).catch(function () {}); }

  window.saVideo = {
    mount: function (node, a) { el = node; api = a; draw(); if (!st.listLoaded) { st.listLoaded = true; loadList(); } },
    refresh: function () { if (el && !st.busy) draw(); },
  };
})();
