// Studio SlashAtlas, onglet « Vidéo » : photos + textes → vidéo publicitaire (animations, musique, voix off facultative).
// Chargé par try.js. Le rendu se fait côté serveur ; ici : formulaire, appel, aperçu, téléchargement, partage.
(function () {
  'use strict';
  var L = document.body.dataset.lang === 'en' ? 'en' : 'fr';
  var T = {
    fr: {
      title: 'Créez une vidéo publicitaire pour votre produit', lead: 'Importez vos photos, écrivez quelques mots : la vidéo est créée pour vous, avec animations, musique et, si vous le souhaitez, une voix off. Votre produit reste identique à votre photo.',
      style: 'Style', styles: { mode: ['Mode', 'Dynamique, coloré, pour vêtements, sacs, chaussures'], beaute: ['Beauté', 'Doux et élégant, pour cosmétiques et soins'], promo: ['Promo flash', 'Énergique, pour annoncer un prix ou une offre'] },
      format: 'Format', formats: { '9:16': ['Vertical', 'TikTok, Reels, Shorts, statuts'], '1:1': ['Carré', 'Facebook, Instagram'], '16:9': ['Paysage', 'YouTube, écran'] },
      photos: 'Vos photos', photosHint: 'De 1 à 3 photos du produit. La première ouvre la vidéo.', add: 'Ajouter une photo', remove: 'Retirer',
      about: 'Décrivez votre produit', aboutPh: 'ex. crème visage hydratante, boutique à Abidjan', ai: 'Écrire mes textes avec l’IA', aiWait: 'Écriture…', aiHint: 'Gratuit. Vous pouvez tout modifier ensuite.',
      texts: 'Vos textes', brand: ['Nom de votre marque', 'ex. Maison Awa'], hook: ['Accroche (obligatoire)', 'ex. Une peau qui rayonne'], l1: ['Atout 1', 'ex. Hydratation 24 h'], l2: ['Atout 2', 'ex. Sans parfum ni alcool'], l3: ['Atout 3', 'facultatif'],
      price: ['Prix', 'ex. 12 500 FCFA'], oldPrice: ['Ancien prix', 'facultatif'], offer: ['Pastille', 'ex. -25 %'], cta: ['Appel à l’action', 'ex. Commander sur WhatsApp'], contact: ['Contact', 'ex. +225 07 00 00 00 00'],
      qr: 'QR code à la fin (facultatif)', qrPh: 'Lien de votre site ou numéro WhatsApp', qrHint: 'Vos clients scannent et arrivent chez vous. Le code n’ouvre que votre lien.',
      voice: 'Voix off', voiceOff: 'Sans voix', voiceF: 'Voix de femme', voiceM: 'Voix d’homme', voiceText: 'Texte lu par la voix (modifiable)', voiceHint: 'Écrit pour vous à partir de vos textes. Vous pouvez le changer.', seg: { hook: 'Accroche', product: 'Présentation', benefits: 'Atouts', offer: 'Prix ou offre', cta: 'Appel à l’action' },
      create: 'Créer la vidéo', credit: 'crédit', credits: 'crédits', needPhoto: 'Ajoutez au moins une photo', needHook: 'Écrivez une accroche', working: 'Création de la vidéo…', workHint: 'Cela prend 30 à 60 secondes. Ne fermez pas la page.',
      steps: ['Montage des images…', 'Ajout de la musique…', 'Enregistrement de la voix…', 'Finalisation de la vidéo…'],
      done: 'Votre vidéo est prête', download: 'Télécharger', share: 'Partager', again: 'Modifier et refaire', shareText: 'Ma vidéo créée avec SlashAtlas', my: 'Mes dernières vidéos', open: 'Voir', sec: 's', refund: 'Les crédits sont remboursés si la création échoue.',
      lost: 'La connexion s’est interrompue. La vidéo est peut-être prête : regardez dans « Mes dernières vidéos » dans une minute.', ex: 'Exemples', exHint: 'Des exemples créés avec ce studio.',
      e: { no_hook: 'Écrivez une accroche d’au moins 3 lettres.', too_long: 'Les textes sont trop longs : raccourcissez-les.', voice_error: 'La voix off n’a pas pu être créée. Réessayez, ou créez la vidéo sans voix.', render_failed: 'La création a échoué. Vos crédits ont été rendus. Réessayez.', no_video: 'Vidéo introuvable.', script_failed: 'L’écriture automatique n’a pas répondu. Réessayez dans un instant.', no_about: 'Décrivez votre produit en quelques mots.', daily_limit: 'Limite du jour atteinte. Revenez demain.', busy: 'Beaucoup de demandes en ce moment. Réessayez dans quelques minutes.', origin: 'Adresse non autorisée.' },
    },
    en: {
      title: 'Create a video ad for your product', lead: 'Upload your photos, write a few words: the video is made for you, with animations, music and, if you wish, a voice-over. Your product stays identical to your photo.',
      style: 'Style', styles: { mode: ['Fashion', 'Dynamic and colorful, for clothes, bags, shoes'], beaute: ['Beauty', 'Soft and elegant, for cosmetics and skincare'], promo: ['Flash sale', 'Energetic, to announce a price or an offer'] },
      format: 'Format', formats: { '9:16': ['Vertical', 'TikTok, Reels, Shorts, statuses'], '1:1': ['Square', 'Facebook, Instagram'], '16:9': ['Landscape', 'YouTube, screens'] },
      photos: 'Your photos', photosHint: '1 to 3 photos of the product. The first one opens the video.', add: 'Add a photo', remove: 'Remove',
      about: 'Describe your product', aboutPh: 'e.g. moisturizing face cream, shop in Abidjan', ai: 'Write my texts with AI', aiWait: 'Writing…', aiHint: 'Free. You can edit everything afterwards.',
      texts: 'Your texts', brand: ['Your brand name', 'e.g. Maison Awa'], hook: ['Hook (required)', 'e.g. Skin that glows'], l1: ['Benefit 1', 'e.g. 24-hour hydration'], l2: ['Benefit 2', 'e.g. No perfume, no alcohol'], l3: ['Benefit 3', 'optional'],
      price: ['Price', 'e.g. 12,500 FCFA'], oldPrice: ['Old price', 'optional'], offer: ['Badge', 'e.g. -25%'], cta: ['Call to action', 'e.g. Order on WhatsApp'], contact: ['Contact', 'e.g. +225 07 00 00 00 00'],
      qr: 'QR code at the end (optional)', qrPh: 'Your website link or WhatsApp number', qrHint: 'Customers scan and land on your page. The code only opens your link.',
      voice: 'Voice-over', voiceOff: 'No voice', voiceF: 'Female voice', voiceM: 'Male voice', voiceText: 'Text read by the voice (editable)', voiceHint: 'Written for you from your texts. You can change it.', seg: { hook: 'Hook', product: 'Introduction', benefits: 'Benefits', offer: 'Price or offer', cta: 'Call to action' },
      create: 'Create the video', credit: 'credit', credits: 'credits', needPhoto: 'Add at least one photo', needHook: 'Write a hook', working: 'Creating the video…', workHint: 'This takes 30 to 60 seconds. Do not close the page.',
      steps: ['Assembling the images…', 'Adding the music…', 'Recording the voice…', 'Finalizing the video…'],
      done: 'Your video is ready', download: 'Download', share: 'Share', again: 'Edit and redo', shareText: 'My video made with SlashAtlas', my: 'My latest videos', open: 'Open', sec: 's', refund: 'Credits are refunded if the creation fails.',
      lost: 'The connection was interrupted. The video may be ready: check “My latest videos” in a minute.', ex: 'Examples', exHint: 'Examples made with this studio.',
      e: { no_hook: 'Write a hook of at least 3 letters.', too_long: 'The texts are too long: shorten them.', voice_error: 'The voice-over could not be created. Try again, or create the video without voice.', render_failed: 'Creation failed. Your credits were returned. Please try again.', no_video: 'Video not found.', script_failed: 'Automatic writing did not respond. Please try again in a moment.', no_about: 'Describe your product in a few words.', daily_limit: 'Daily limit reached. Come back tomorrow.', busy: 'Many requests right now. Try again in a few minutes.', origin: 'Address not allowed.' },
    },
  }[L];
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var st = { style: 'beaute', ratio: '9:16', photos: [], f: { brand: '', hook: '', l1: '', l2: '', l3: '', price: '', oldPrice: '', offer: '', cta: '', contact: '' }, qr: '', voice: false, gender: 'f', vt: {}, about: '', busy: false, ai: false, result: null, list: null, listLoaded: false, step: 0 };
  var api = null, el = null, stepTimer = null;

  function lines() { return [st.f.l1, st.f.l2, st.f.l3].map(function (x) { return x.trim(); }).filter(Boolean); }
  function autoVoice() {
    var f = st.f, ls = lines(), en = L === 'en';
    return {
      hook: f.hook.trim(),
      product: [f.brand.trim() ? (en ? 'Discover ' + f.brand.trim() + '.' : 'Découvrez ' + f.brand.trim() + '.') : '', ls[0] || ''].filter(Boolean).join(' '),
      benefits: ls.join('. '),
      offer: [f.offer.trim(), f.price.trim() ? (en ? 'Only ' + f.price.trim() + '.' : 'Seulement ' + f.price.trim() + '.') : ''].filter(Boolean).join('. '),
      cta: [f.cta.trim(), f.contact.trim()].filter(Boolean).join('. '),
    };
  }
  function voiceSegs() { var a = autoVoice(), o = {}; Object.keys(a).forEach(function (k) { o[k] = st.vt[k] != null ? st.vt[k] : a[k]; }); return o; }
  function cost() { var v = (api.cfg && api.cfg.video) || { base: 3, voice: 1 }; return v.base + (st.voice ? v.voice : 0); }
  function field(k, ph) { return '<label>' + esc(T[k][0]) + '<input type="text" data-f="' + k + '" maxlength="' + (k === 'hook' ? 60 : k === 'price' || k === 'oldPrice' ? 24 : k === 'offer' ? 16 : k === 'cta' ? 30 : k === 'brand' || k === 'contact' ? 40 : 48) + '" placeholder="' + esc(T[k][1]) + '" value="' + esc(st.f[k]) + '" autocomplete="off"></label>'; }
  function seg(attr, cur, items) { return '<div class="vseg" role="group">' + items.map(function (it) { return '<button type="button" data-' + attr + '="' + it[0] + '" aria-pressed="' + (cur === it[0]) + '"><b>' + esc(it[1]) + '</b>' + (it[2] ? '<small>' + esc(it[2]) + '</small>' : '') + '</button>'; }).join('') + '</div>'; }

  function html() {
    var thumbs = st.photos.map(function (p, i) { return '<figure class="ph"><img src="' + p.url + '" alt=""><button type="button" data-rm="' + i + '" aria-label="' + T.remove + '">×</button></figure>'; }).join('');
    var add = st.photos.length < 3 ? '<label class="addph"><input id="v-file" type="file" accept="image/jpeg,image/png,image/webp,image/*" multiple hidden><span>+</span><small>' + T.add + '</small></label>' : '';
    var ls = lines(), segs = voiceSegs(), has = { hook: 1, product: 1, benefits: ls.length >= 2, offer: st.f.price.trim() || st.f.offer.trim(), cta: 1 };
    var enough = api.credits >= cost(); var ready = st.photos.length && st.f.hook.trim().length >= 3 && !st.busy;
    var label = st.busy ? T.working : !st.photos.length ? T.needPhoto : st.f.hook.trim().length < 3 ? T.needHook : T.create + ' · ' + cost() + ' ' + (cost() === 1 ? T.credit : T.credits);
    return '<div class="sbox vbox"><div><h2 class="vh">' + T.title + '</h2><p class="hint">' + T.lead + '</p></div>' +
      '<div class="sf"><b>' + T.style + '</b>' + seg('style', st.style, ['mode', 'beaute', 'promo'].map(function (k) { return [k, T.styles[k][0], T.styles[k][1]]; })) + '</div>' +
      '<div class="sf"><b>' + T.format + '</b>' + seg('ratio', st.ratio, ['9:16', '1:1', '16:9'].map(function (k) { return [k, T.formats[k][0], T.formats[k][1]]; })) + '</div>' +
      '<div class="sf"><b>' + T.photos + '</b><div class="phs">' + thumbs + add + '</div><small class="hint">' + T.photosHint + '</small></div>' +
      '<div class="sf vai"><label>' + T.about + '<textarea id="v-about" rows="2" maxlength="240" placeholder="' + esc(T.aboutPh) + '">' + esc(st.about) + '</textarea></label><button class="btn gl' + (st.ai ? ' loading' : '') + '" type="button" id="v-ai"' + (st.ai ? ' disabled' : '') + '>' + (st.ai ? T.aiWait : '✨ ' + T.ai) + '</button><small class="hint">' + T.aiHint + '</small></div>' +
      '<div class="sf"><b>' + T.texts + '</b><div class="bgrid">' + ['brand', 'hook', 'l1', 'l2', 'l3', 'price', 'oldPrice', 'offer', 'cta', 'contact'].map(field).join('') + '</div></div>' +
      '<div class="sf"><b>' + T.qr + '</b><input type="text" id="v-qr" maxlength="200" placeholder="' + esc(T.qrPh) + '" value="' + esc(st.qr) + '" autocomplete="off"><small class="hint">' + T.qrHint + '</small></div>' +
      '<div class="sf"><b>' + T.voice + '</b>' + seg('voice', st.voice ? st.gender : 'off', [['off', T.voiceOff], ['f', T.voiceF], ['m', T.voiceM]]) +
      (st.voice ? '<details class="brandbox sf"><summary>' + T.voiceText + '</summary><p class="hint">' + T.voiceHint + '</p>' + ['hook', 'product', 'benefits', 'offer', 'cta'].filter(function (k) { return has[k]; }).map(function (k) { return '<label>' + T.seg[k] + '<textarea rows="2" maxlength="240" data-vt="' + k + '">' + esc(segs[k]) + '</textarea></label>'; }).join('') + '</details>' : '') + '</div>' +
      '<button class="btn pri big' + (st.busy ? ' loading' : '') + '" type="button" id="v-go"' + (!ready && enough ? ' disabled' : '') + '>' + (!enough && st.photos.length && st.f.hook.trim().length >= 3 ? api.T.buy : label) + '</button>' +
      '<p class="fmsg" id="v-msg" role="status" aria-live="polite"></p><small class="hint">' + T.refund + '</small>' +
      (st.busy ? '<div class="vwork" role="status"><div class="vbar"><i></i></div><b>' + esc(T.steps[st.step % T.steps.length]) + '</b><small>' + T.workHint + '</small></div>' : '') + '</div>' +
      (st.result ? '<div class="sres vres"><h3>' + T.done + '</h3><video controls playsinline loop src="' + st.result.url + '"></video><div class="acts big"><a class="btn pri big" href="' + st.result.url + '" download="slashatlas-video.mp4">' + T.download + '</a>' + (st.result.canShare ? '<button class="btn gl big" type="button" id="v-share">' + T.share + '</button>' : '') + '<button class="btn gl big" type="button" id="v-again">' + T.again + '</button></div></div>' : '') +
      (st.list && st.list.length ? '<div class="sbox"><b>' + T.my + '</b><div class="vlist">' + st.list.map(function (v) { var sub = (T.styles[v.style] ? T.styles[v.style][0] : '') + ' · ' + v.ratio + ' · ' + Math.round(v.seconds) + T.sec; return '<div class="vrow"><span>' + esc(v.brand || v.hook || '—') + '<small>' + esc(sub) + '</small></span><button class="btn gl sm" type="button" data-open="' + v.id + '">' + T.open + '</button></div>'; }).join('') + '</div></div>' : '');
  }

  function msg(t, ok) { var m = el.querySelector('#v-msg'); if (m) { m.textContent = t || ''; m.className = 'fmsg' + (ok ? ' ok' : ''); } }
  var errText = function (c) { return T.e[c] || api.errText(c); };
  function draw() {
    var keep = document.activeElement && document.activeElement.dataset ? { f: document.activeElement.dataset.f, vt: document.activeElement.dataset.vt, id: document.activeElement.id } : null;
    var pos = keep && document.activeElement.selectionStart;
    el.innerHTML = html(); bind();
    if (keep) { var q = keep.f ? '[data-f="' + keep.f + '"]' : keep.vt ? '[data-vt="' + keep.vt + '"]' : keep.id ? '#' + keep.id : null; var n = q && el.querySelector(q); if (n) { n.focus(); try { n.setSelectionRange(pos, pos); } catch (e) { /* champ sans curseur */ } } }
  }
  function bind() {
    Array.prototype.forEach.call(el.querySelectorAll('[data-style]'), function (b) { b.addEventListener('click', function () { st.style = b.dataset.style; draw(); }); });
    Array.prototype.forEach.call(el.querySelectorAll('[data-ratio]'), function (b) { b.addEventListener('click', function () { st.ratio = b.dataset.ratio; draw(); }); });
    Array.prototype.forEach.call(el.querySelectorAll('[data-voice]'), function (b) { b.addEventListener('click', function () { var v = b.dataset.voice; st.voice = v !== 'off'; if (st.voice) st.gender = v; draw(); }); });
    Array.prototype.forEach.call(el.querySelectorAll('[data-rm]'), function (b) { b.addEventListener('click', function () { var p = st.photos.splice(+b.dataset.rm, 1)[0]; if (p) URL.revokeObjectURL(p.url); draw(); }); });
    var f = el.querySelector('#v-file'); if (f) f.addEventListener('change', function () { addFiles(f.files); });
    Array.prototype.forEach.call(el.querySelectorAll('[data-f]'), function (i) { i.addEventListener('input', function () { st.f[i.dataset.f] = i.value; refreshGo(); }); i.addEventListener('change', function () { draw(); }); });
    Array.prototype.forEach.call(el.querySelectorAll('[data-vt]'), function (i) { i.addEventListener('input', function () { st.vt[i.dataset.vt] = i.value; }); });
    var q = el.querySelector('#v-qr'); if (q) q.addEventListener('input', function () { st.qr = q.value; });
    var a = el.querySelector('#v-about'); if (a) a.addEventListener('input', function () { st.about = a.value; });
    var ai = el.querySelector('#v-ai'); if (ai) ai.addEventListener('click', writeWithAi);
    var go = el.querySelector('#v-go'); if (go) go.addEventListener('click', function () { if (api.credits < cost()) api.openBuy('video'); else create(); });
    var sh = el.querySelector('#v-share'); if (sh) sh.addEventListener('click', share);
    var ag = el.querySelector('#v-again'); if (ag) ag.addEventListener('click', function () { st.result = null; draw(); window.scrollTo({ top: el.offsetTop, behavior: 'smooth' }); });
    Array.prototype.forEach.call(el.querySelectorAll('[data-open]'), function (b) { b.addEventListener('click', function () { openSaved(b.dataset.open, b); }); });
  }
  function refreshGo() { var go = el.querySelector('#v-go'); if (!go || st.busy) return; var ok = st.photos.length && st.f.hook.trim().length >= 3; var enough = api.credits >= cost(); go.disabled = enough && !ok; go.textContent = !enough && ok ? api.T.buy : !st.photos.length ? T.needPhoto : st.f.hook.trim().length < 3 ? T.needHook : T.create + ' · ' + cost() + ' ' + (cost() === 1 ? T.credit : T.credits); }

  function addFiles(list) {
    var files = Array.prototype.slice.call(list).slice(0, 3 - st.photos.length);
    Promise.all(files.map(function (f) { return api.shrink(f).catch(function () { return null; }); })).then(function (r) { r.forEach(function (p) { if (p) st.photos.push(p); }); draw(); if (r.some(function (p) { return !p; })) msg(api.errText('bad_photo')); });
  }
  function writeWithAi() {
    if (st.ai) return; if (st.about.trim().length < 4) return msg(T.e.no_about);
    st.ai = true; draw();
    api.call('video/script', { lang: L, about: st.about, style: st.style, texts: { brand: st.f.brand, price: st.f.price, offer: st.f.offer } }).then(function (r) {
      st.ai = false;
      if (r.status === 200) {
        var d = r.data; if (d.hook) st.f.hook = d.hook; (d.lines || []).forEach(function (x, i) { st.f['l' + (i + 1)] = x; }); if (d.cta && !st.f.cta) st.f.cta = d.cta;
        if (d.voice) st.vt = { hook: d.voice.hook, product: d.voice.product, benefits: d.voice.benefits, offer: d.voice.offer, cta: d.voice.cta };
        draw();
      } else { draw(); msg(errText(r.data && r.data.error)); }
    }).catch(function () { st.ai = false; draw(); msg(api.errText('server')); });
  }

  function create() {
    if (st.busy || !st.photos.length || st.f.hook.trim().length < 3) return;
    st.busy = true; st.result = null; st.step = 0; draw(); msg('');
    stepTimer = setInterval(function () { st.step++; var b = el.querySelector('.vwork b'); if (b) b.textContent = T.steps[Math.min(st.step, T.steps.length - 1)]; }, 9000);
    var body = { lang: L, style: st.style, ratio: st.ratio, qr: st.qr.trim(), voice: st.voice ? { on: true, gender: st.gender, segments: voiceSegs() } : false,
      texts: { brand: st.f.brand, hook: st.f.hook, lines: lines(), price: st.f.price, oldPrice: st.f.oldPrice, offer: st.f.offer, cta: st.f.cta, contact: st.f.contact },
      photos: st.photos.map(function (p) { return { mime: p.mime, data: p.data }; }) };
    var url = api.renderUrl;
    if (!url) { done(); return msg(api.errText('server')); }
    api.post(url, body, 290000).then(function (r) {
      if (r.status === 200) { api.setCredits(r.data.credits); return api.blob('video/file', { id: r.data.id }).then(function (b) { st.result = { id: r.data.id, url: URL.createObjectURL(b), blob: b, canShare: !!(navigator.canShare && navigator.canShare({ files: [new File([b], 'v.mp4', { type: 'video/mp4' })] })) }; done(); loadList(); window.scrollTo({ top: el.querySelector('.vres').offsetTop - 70, behavior: 'smooth' }); }); }
      done(); if (r.data && r.data.error === 'insufficient_credits') { api.openBuy('serveur'); return; } msg(errText(r.data && r.data.error)); api.refreshMe();
    }).catch(function () { done(); msg(T.lost); setTimeout(loadList, 45000); api.refreshMe(); });
  }
  function done() { clearInterval(stepTimer); st.busy = false; draw(); }
  function share() { var b = st.result && st.result.blob; if (!b) return; try { navigator.share({ files: [new File([b], 'slashatlas-video.mp4', { type: 'video/mp4' })], text: T.shareText }).catch(function () {}); } catch (e) { /* partage annulé */ } }
  function openSaved(id, btn) { btn.disabled = true; api.blob('video/file', { id: id }).then(function (b) { st.result = { id: id, url: URL.createObjectURL(b), blob: b, canShare: !!(navigator.canShare && navigator.canShare({ files: [new File([b], 'v.mp4', { type: 'video/mp4' })] })) }; draw(); var r = el.querySelector('.vres'); if (r) window.scrollTo({ top: r.offsetTop - 70, behavior: 'smooth' }); }).catch(function () { btn.disabled = false; msg(T.e.no_video); }); }
  function loadList() { api.call('video/list').then(function (r) { if (r.status === 200) { st.list = r.data.videos; if (!st.busy) draw(); } }).catch(function () {}); }

  window.saVideo = {
    mount: function (node, a) { el = node; api = a; draw(); if (!st.listLoaded) { st.listLoaded = true; loadList(); } },
    refresh: function () { if (el && !st.busy) draw(); },
  };
})();
