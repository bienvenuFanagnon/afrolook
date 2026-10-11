// Studio SlashAtlas : connexion Google, crédits, achat par mobile money, génération avec Gemini.
(function () {
  'use strict';
  var root = document.getElementById('studio');
  if (!root) return;
  var L = document.body.dataset.lang === 'en' ? 'en' : 'fr';
  var T = {
    fr: {
      login: 'Continuer avec Google', loginNote: 'Connexion rapide avec votre compte Google. Si vous avez déjà un compte, vous êtes simplement reconnecté.',
      hello: 'Bonjour', back: 'Content de vous revoir', welcome: 'Compte créé', credits: 'crédits', credit: 'crédit', buy: 'Acheter des crédits', logout: 'Se déconnecter',
      cmd: 'Commande', change: 'Changer', photos: 'Vos photos', photosHint: 'Jusqu’à 3 photos (un ou plusieurs produits). JPG, PNG ou WebP.', add: 'Ajouter une photo', remove: 'Retirer',
      prodLabel: { product: 'Votre produit', dish: 'Votre plat', person: 'Sur la photo', place: 'Votre bien' }, prodPh: 'ex. crème visage, 3 bouteilles de jus', single: 'Un seul', several: 'Plusieurs',
      gen: 'Générer', genCost: 'Générer · 1 crédit', needPhoto: 'Ajoutez une photo pour générer', working: 'Création en cours… environ 20 secondes', done: 'Voici votre visuel', download: 'Télécharger', again: 'Refaire · 1 crédit', ai: 'Généré par IA · Gemini',
      noCredit: 'Il vous faut des crédits pour générer.', balance: 'Solde',
      buyTitle: 'Acheter des crédits', buySub: '1 crédit = 1 génération. Les crédits n’expirent pas.', popular: 'Populaire', perCredit: 'par crédit', pay: 'Payer', country: 'Pays', operator: 'Opérateur', phone: 'Numéro mobile money', otp: 'Code OTP', otpHint: 'Orange Burkina : composez #144*4*6*montant# puis saisissez le code reçu.',
      card: 'Carte bancaire : bientôt', paying: 'Validez le paiement sur votre téléphone…', waitPay: 'En attente de la confirmation de l’opérateur', paid: 'Paiement reçu, crédits ajoutés', payFailed: 'Paiement refusé ou annulé. Réessayez.', openPay: 'Ouvrir la page de paiement', close: 'Fermer',
      e: { insufficient_credits: 'Pas assez de crédits.', daily_limit: 'Limite quotidienne atteinte. Revenez demain.', refused: 'L’image n’a pas pu être créée avec cette photo. Essayez-en une autre. Votre crédit est rendu.', busy: 'Service très sollicité. Réessayez dans un instant. Votre crédit est rendu.', gemini_error: 'La création a échoué. Votre crédit est rendu.', photo_too_big: 'Photo trop lourde.', bad_photo: 'Format de photo non pris en charge.', auth: 'Reconnectez-vous.', payment_refused: 'Le paiement n’a pas pu démarrer. Vérifiez le numéro et l’opérateur.', bad_phone: 'Numéro invalide.', otp_required: 'Code OTP requis.', rate: 'Trop de demandes, patientez un instant.', server: 'Erreur du service, réessayez.' },
    },
    en: {
      login: 'Continue with Google', loginNote: 'Quick sign-in with your Google account. If you already have an account, you are simply signed back in.',
      hello: 'Hello', back: 'Welcome back', welcome: 'Account created', credits: 'credits', credit: 'credit', buy: 'Buy credits', logout: 'Sign out',
      cmd: 'Command', change: 'Change', photos: 'Your photos', photosHint: 'Up to 3 photos (one or several products). JPG, PNG or WebP.', add: 'Add a photo', remove: 'Remove',
      prodLabel: { product: 'Your product', dish: 'Your dish', person: 'In the photo', place: 'Your property' }, prodPh: 'e.g. face cream, 3 juice bottles', single: 'Single', several: 'Several',
      gen: 'Generate', genCost: 'Generate · 1 credit', needPhoto: 'Add a photo to generate', working: 'Creating… about 20 seconds', done: 'Here is your visual', download: 'Download', again: 'Redo · 1 credit', ai: 'AI-generated · Gemini',
      noCredit: 'You need credits to generate.', balance: 'Balance',
      buyTitle: 'Buy credits', buySub: '1 credit = 1 generation. Credits do not expire.', popular: 'Popular', perCredit: 'per credit', pay: 'Pay', country: 'Country', operator: 'Operator', phone: 'Mobile money number', otp: 'OTP code', otpHint: 'Orange Burkina: dial #144*4*6*amount# then enter the code you receive.',
      card: 'Card payment: coming soon', paying: 'Confirm the payment on your phone…', waitPay: 'Waiting for the operator’s confirmation', paid: 'Payment received, credits added', payFailed: 'Payment declined or cancelled. Please try again.', openPay: 'Open the payment page', close: 'Close',
      e: { insufficient_credits: 'Not enough credits.', daily_limit: 'Daily limit reached. Come back tomorrow.', refused: 'The image could not be created from this photo. Try another one. Your credit is refunded.', busy: 'The service is busy. Try again in a moment. Your credit is refunded.', gemini_error: 'Creation failed. Your credit is refunded.', photo_too_big: 'Photo too large.', bad_photo: 'Unsupported photo format.', auth: 'Please sign in again.', payment_refused: 'The payment could not start. Check the number and operator.', bad_phone: 'Invalid number.', otp_required: 'OTP code required.', rate: 'Too many requests, please wait a moment.', server: 'Service error, please try again.' },
    },
  }[L];
  var data = {}; try { data = JSON.parse(root.dataset.map); } catch (e) {}
  var params = new URLSearchParams(location.search);
  var slug = data.commands[params.get('c')] ? params.get('c') : Object.keys(data.commands)[0];
  var state = { user: null, credits: 0, photos: [], multi: false, product: '', busy: false, cfg: null, result: null };

  var $ = function (s, r) { return (r || root).querySelector(s); };
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var fmt = function (n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ' '); };
  var errText = function (code) { return T.e[code] || T.e.server; };

  function cmdBlock() {
    var c = data.commands[slug];
    return '<div class="scmd"><img src="/img/c/' + (c.img ? slug : 'none') + '-t.webp" alt="" ' + (c.img ? '' : 'hidden') + '><div><small>' + T.cmd + '</small><b>' + esc(c.code) + '</b><span>' + esc(c.title) + '</span></div>' +
      '<select id="s-cmd" aria-label="' + T.change + '">' + Object.keys(data.commands).map(function (k) { return '<option value="' + k + '"' + (k === slug ? ' selected' : '') + '>' + esc(data.commands[k].code + ' · ' + data.commands[k].title) + '</option>'; }).join('') + '</select></div>';
  }
  function render() {
    if (!state.user) {
      root.innerHTML = '<div class="sbox">' + cmdBlock() + '<button class="btn pri big" type="button" data-login>' + T.login + '</button><p class="hint">' + T.loginNote + '</p><p class="fmsg" id="auth-msg" role="status" aria-live="polite"></p></div>';
      bind(); return;
    }
    var kind = data.commands[slug].kind, lab = T.prodLabel[kind] || T.prodLabel.product;
    var thumbs = state.photos.map(function (p, i) { return '<figure class="ph"><img src="' + p.url + '" alt=""><button type="button" data-rm="' + i + '" aria-label="' + T.remove + '">×</button></figure>'; }).join('');
    var addBtn = state.photos.length < 3 ? '<label class="addph"><input id="s-file" type="file" accept="image/jpeg,image/png,image/webp,image/*" multiple hidden><span>+</span><small>' + T.add + '</small></label>' : '';
    var canGen = state.photos.length && !state.busy;
    var genLabel = state.credits < 1 ? T.buy : T.genCost;
    root.innerHTML =
      '<div class="sbar"><div><small>' + T.hello + ', ' + esc((state.user.displayName || '').split(' ')[0] || state.user.email) + '</small><b id="s-bal">' + state.credits + ' ' + (state.credits === 1 ? T.credit : T.credits) + '</b></div><div class="acts"><button class="btn pri sm" type="button" id="s-buy">' + T.buy + '</button><button class="btn gl sm" type="button" data-logout>' + T.logout + '</button></div></div>' +
      '<div class="sbox">' + cmdBlock() +
      '<div class="sf"><b>' + T.photos + '</b><div class="phs">' + thumbs + addBtn + '</div><small class="hint">' + T.photosHint + '</small></div>' +
      '<div class="adapt sf"><label>' + lab + '<input id="s-prod" type="text" maxlength="60" placeholder="' + esc(T.prodPh) + '" value="' + esc(state.product) + '" autocomplete="off"></label><div class="seg2" role="group"><button type="button" data-n="1" aria-pressed="' + (!state.multi) + '">' + T.single + '</button><button type="button" data-n="n" aria-pressed="' + state.multi + '">' + T.several + '</button></div></div>' +
      '<button class="btn pri big" type="button" id="s-gen"' + (state.credits >= 1 && !canGen ? ' disabled' : '') + '>' + (state.busy ? T.working : (state.credits >= 1 && !state.photos.length ? T.needPhoto : genLabel)) + '</button>' +
      '<p class="fmsg" id="s-msg" role="status" aria-live="polite"></p></div>' +
      (state.result ? '<div class="sres"><img src="' + state.result.url + '" alt=""><span class="aib">' + T.ai + '</span><div class="acts big"><a class="btn pri big" href="' + state.result.url + '" download="slashatlas-' + slug + '.' + state.result.ext + '">' + T.download + '</a><button class="btn gl big" type="button" id="s-again">' + T.again + '</button></div></div>' : '');
    bind();
  }
  function msg(t, ok) { var m = $('#s-msg') || $('#auth-msg'); if (m) { m.textContent = t || ''; m.className = 'fmsg' + (ok ? ' ok' : ''); } }

  function bind() {
    var sel = $('#s-cmd'); if (sel) sel.addEventListener('change', function () { slug = sel.value; history.replaceState(null, '', '?c=' + slug); state.result = null; render(); });
    var f = $('#s-file'); if (f) f.addEventListener('change', function () { addFiles(f.files); });
    Array.prototype.forEach.call(root.querySelectorAll('[data-rm]'), function (b) { b.addEventListener('click', function () { var p = state.photos.splice(+b.dataset.rm, 1)[0]; if (p) URL.revokeObjectURL(p.url); render(); }); });
    var pr = $('#s-prod'); if (pr) pr.addEventListener('input', function () { state.product = pr.value; });
    Array.prototype.forEach.call(root.querySelectorAll('.seg2 button'), function (b) { b.addEventListener('click', function () { state.multi = b.dataset.n === 'n'; Array.prototype.forEach.call(root.querySelectorAll('.seg2 button'), function (x) { x.setAttribute('aria-pressed', x === b ? 'true' : 'false'); }); }); });
    var g = $('#s-gen'); if (g) g.addEventListener('click', function () { if (state.credits < 1) openBuy(); else generate(); });
    var ag = $('#s-again'); if (ag) ag.addEventListener('click', function () { if (state.credits < 1) openBuy(); else generate(); });
    var by = $('#s-buy'); if (by) by.addEventListener('click', openBuy);
  }

  // ── photos : réduites dans le navigateur (1600 px, JPEG) avant l'envoi ──
  function shrink(file) {
    return new Promise(function (resolve, reject) {
      var url = URL.createObjectURL(file), img = new Image();
      img.onload = function () {
        var max = 1600, w = img.naturalWidth, h = img.naturalHeight, k = Math.min(1, max / Math.max(w, h));
        var c = document.createElement('canvas'); c.width = Math.round(w * k); c.height = Math.round(h * k);
        c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
        c.toBlob(function (b) {
          if (!b) { URL.revokeObjectURL(url); return reject(new Error('bad_photo')); }
          var r = new FileReader(); r.onload = function () { resolve({ url: URL.createObjectURL(b), mime: 'image/jpeg', data: String(r.result).split(',')[1] }); URL.revokeObjectURL(url); }; r.readAsDataURL(b);
        }, 'image/jpeg', 0.86);
      };
      img.onerror = function () { URL.revokeObjectURL(url); reject(new Error('bad_photo')); };
      img.src = url;
    });
  }
  function addFiles(list) {
    var files = Array.prototype.slice.call(list).slice(0, 3 - state.photos.length);
    Promise.all(files.map(function (f) { return shrink(f).catch(function () { return null; }); })).then(function (r) {
      r.forEach(function (p) { if (p) state.photos.push(p); });
      render(); if (r.some(function (p) { return !p; })) msg(T.e.bad_photo);
    });
  }

  // ── génération ──
  function generate() {
    if (state.busy || !state.photos.length) return;
    state.busy = true; state.result = null; render(); msg('');
    var body = { slug: slug, lang: L, product: state.product, multi: state.multi, photos: state.photos.map(function (p) { return { mime: p.mime, data: p.data }; }) };
    window.slashAuth.call('generate', body).then(function (r) {
      state.busy = false;
      if (r.status === 200) {
        var bin = atob(r.data.image), arr = new Uint8Array(bin.length); for (var i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
        var ext = r.data.mime.indexOf('jpeg') >= 0 ? 'jpg' : 'png';
        state.result = { url: URL.createObjectURL(new Blob([arr], { type: r.data.mime })), ext: ext };
        state.credits = r.data.credits; render(); window.scrollTo({ top: $('.sres').offsetTop - 70, behavior: 'smooth' });
      } else {
        if (r.data && r.data.error === 'insufficient_credits') { render(); openBuy(); return; }
        render(); msg(errText(r.data && r.data.error));
      }
    }).catch(function () { state.busy = false; render(); msg(T.e.server); });
  }

  // ── achat de crédits (mobile money) ──
  function openBuy() {
    var cfg = state.cfg; if (!cfg) return;
    var countries = []; cfg.operators.forEach(function (o) { if (countries.indexOf(o.country) < 0) countries.push(o.country); });
    var sel = { pack: cfg.packs[1] ? cfg.packs[1].id : cfg.packs[0].id, country: countries[0], op: null };
    var modal = document.createElement('div'); modal.className = 'smodal'; modal.setAttribute('role', 'dialog'); modal.setAttribute('aria-modal', 'true');
    document.body.appendChild(modal); document.body.style.overflow = 'hidden';
    var timer = null;
    function close() { clearInterval(timer); modal.remove(); document.body.style.overflow = ''; }
    function ops() { return cfg.operators.filter(function (o) { return o.country === sel.country; }); }
    function draw() {
      if (!sel.op || sel.op.country !== sel.country) sel.op = ops()[0];
      var pk = cfg.packs.filter(function (p) { return p.id === sel.pack; })[0];
      modal.innerHTML = '<div class="sheet"><button class="x" type="button" aria-label="' + T.close + '">×</button><h2>' + T.buyTitle + '</h2><p class="hint">' + T.buySub + '</p>' +
        '<div class="packs">' + cfg.packs.map(function (p) { return '<button type="button" class="pack' + (p.id === sel.pack ? ' on' : '') + '" data-p="' + p.id + '">' + (p.tag ? '<i>' + T.popular + '</i>' : '') + '<b>' + p.credits + '</b><span>' + T.credits + '</span><em>' + fmt(p.xof) + ' FCFA</em><small>' + Math.round(p.xof / p.credits) + ' FCFA ' + T.perCredit + '</small></button>'; }).join('') + '</div>' +
        '<label>' + T.country + '<select id="b-country">' + countries.map(function (c) { return '<option' + (c === sel.country ? ' selected' : '') + '>' + esc(c) + '</option>'; }).join('') + '</select></label>' +
        '<label>' + T.operator + '<select id="b-op">' + ops().map(function (o) { return '<option value="' + o.code + '"' + (o.code === sel.op.code ? ' selected' : '') + '>' + esc(o.label) + '</option>'; }).join('') + '</select></label>' +
        '<label>' + T.phone + '<span class="pfx"><i>+' + sel.op.dial + '</i><input id="b-phone" type="tel" inputmode="tel" autocomplete="tel-national" placeholder="XXXXXXXX"></span></label>' +
        (sel.op.otp ? '<label>' + T.otp + '<input id="b-otp" type="text" inputmode="numeric" autocomplete="one-time-code"></label><p class="hint">' + T.otpHint + '</p>' : '') +
        '<button class="btn pri big" type="button" id="b-pay">' + T.pay + ' ' + fmt(pk.xof) + ' FCFA</button><p class="hint soft">' + T.card + '</p><p class="fmsg" id="b-msg" role="status" aria-live="polite"></p></div>';
      $('.x', modal).onclick = close;
      Array.prototype.forEach.call(modal.querySelectorAll('.pack'), function (b) { b.onclick = function () { sel.pack = b.dataset.p; draw(); }; });
      $('#b-country', modal).onchange = function (e) { sel.country = e.target.value; sel.op = null; draw(); };
      $('#b-op', modal).onchange = function (e) { sel.op = ops().filter(function (o) { return o.code === e.target.value; })[0]; draw(); };
      $('#b-pay', modal).onclick = pay;
    }
    function bmsg(t, ok) { var m = $('#b-msg', modal); if (m) { m.textContent = t || ''; m.className = 'fmsg' + (ok ? ' ok' : ''); } }
    function pay() {
      var btn = $('#b-pay', modal), phone = $('#b-phone', modal).value.replace(/\D/g, ''), otp = sel.op.otp ? ($('#b-otp', modal).value || '').trim() : '';
      if (phone.length < 8) return bmsg(T.e.bad_phone);
      if (sel.op.otp && !otp) return bmsg(T.e.otp_required);
      btn.disabled = true; bmsg(T.paying, true);
      window.slashAuth.call('pay/start', { packId: sel.pack, operator: sel.op.code, phone: phone, otp: otp }).then(function (r) {
        if (r.status !== 200) { btn.disabled = false; return bmsg(errText(r.data && r.data.error)); }
        if (r.data.paymentUrl) { var a = document.createElement('a'); a.href = r.data.paymentUrl; a.target = '_blank'; a.rel = 'noopener'; a.textContent = T.openPay; a.className = 'btn gl'; $('#b-msg', modal).after(a); }
        var tries = 0, orderId = r.data.orderId;
        bmsg(T.waitPay, true);
        timer = setInterval(function () {
          tries++;
          window.slashAuth.call('pay/status', { orderId: orderId }).then(function (s) {
            if (s.status !== 200) return;
            if (s.data.status === 'paid') { clearInterval(timer); state.credits = s.data.balance; bmsg(T.paid, true); setTimeout(function () { close(); render(); }, 1200); }
            else if (s.data.status === 'failed') { clearInterval(timer); btn.disabled = false; bmsg(T.payFailed); }
          });
          if (tries > 60) { clearInterval(timer); btn.disabled = false; bmsg(T.payFailed); }
        }, 4000);
      }).catch(function () { btn.disabled = false; bmsg(T.e.server); });
    }
    draw();
  }

  // ── démarrage ──
  import('/js/auth.js');
  fetch('/api/config').then(function (r) { return r.json(); }).then(function (c) { state.cfg = c; }).catch(function () {});
  document.addEventListener('sa:auth', function (e) {
    var u = e.detail.user; state.user = u;
    if (!u) { state.credits = 0; state.result = null; render(); return; }
    window.slashAuth.call('me').then(function (r) {
      if (r.status === 200) { state.credits = r.data.credits; render(); msg(r.data.created ? T.welcome : T.back, true); setTimeout(function () { msg(''); }, 2500); }
      else { render(); msg(errText(r.data && r.data.error)); }
    });
  });
  render();
})();
