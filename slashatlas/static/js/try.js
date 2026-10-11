// Studio SlashAtlas : connexion Google, crédits, achat par mobile money, génération avec Gemini.
(function () {
  'use strict';
  var root = document.getElementById('studio');
  if (!root) return;
  var CONTACT = (document.getElementById('studio') || {dataset: {}}).dataset.contact || '';
  var L = document.body.dataset.lang === 'en' ? 'en' : 'fr';
  var T = {
    fr: {
      login: 'Continuer avec Google', loginNote: 'Connexion rapide avec votre compte Google. Si vous avez déjà un compte, vous êtes simplement reconnecté.',
      hello: 'Bonjour', back: 'Content de vous revoir', welcome: 'Compte créé', credits: 'crédits', credit: 'crédit', buy: 'Acheter des crédits', logout: 'Se déconnecter',
      cmd: 'Commande', change: 'Changer', photos: 'Vos photos', photosHint: 'Jusqu’à 3 photos (un ou plusieurs produits). JPG, PNG ou WebP.', add: 'Ajouter une photo', remove: 'Retirer',
      prodLabel: { product: 'Votre produit', dish: 'Votre plat', person: 'Sur la photo', place: 'Votre bien' }, prodPh: 'ex. crème visage, 3 bouteilles de jus', single: 'Un seul', several: 'Plusieurs',
      gen: 'Générer', genCost: 'Générer · 1 crédit', needPhoto: 'Ajoutez une photo pour générer', working: 'Création en cours… environ 20 secondes', done: 'Voici votre visuel', download: 'Télécharger', again: 'Refaire · 1 crédit', editTitle: 'Un défaut ? Corrigez ou modifiez', editPh: 'ex. enlève le reflet à gauche, fond plus clair, logo plus net', editBtn: 'Appliquer · 1 crédit', editing: 'Modification en cours… environ 20 secondes', version: 'Version', editHint: 'Décrivez ce qu’il faut changer. Le reste de l’image est conservé. Chaque modification coûte 1 crédit.', ai: 'Généré par IA · Gemini', aiNote: 'le fichier téléchargé est sans mention sur l’image',
      noCredit: 'Il vous faut des crédits pour générer.', balance: 'Solde',
      help: 'Un souci de paiement ? Écrivez-nous :', buyTitle: 'Acheter des crédits', buySub: '1 crédit = 1 génération. Les crédits n’expirent pas.', popular: 'Populaire', perCredit: 'par crédit', pay: 'Payer', country: 'Pays', operator: 'Opérateur', phone: 'Numéro mobile money', otp: 'Code OTP', otpHint: 'Orange Burkina : composez #144*4*6*montant# puis saisissez le code reçu.',
      feeLineCard: 'Pack {p} + frais de paiement {f}', usdNote: 'Prix en dollars. Par mobile money, le montant est converti en FCFA.',
      passUnit: 'jours', passTag: 'Sans pub', passOne: 'Pass sans pub', passWhat: 'sur tout le site', passTitle: 'Pass sans pub · 30 jours', passSub: 'Aucune publicité pendant 30 jours. Sans renouvellement automatique.', noAdsUntil: 'Sans pub jusqu’au {d}', paidPass: 'Paiement reçu : pass sans pub activé', passLogin: 'Connectez-vous pour activer votre pass sans pub (30 jours).', passBuy: 'Activer le pass sans pub',
      soon: 'bientôt', cardSoon: 'Le paiement par carte arrive bientôt. Merci, nous avons noté votre demande : en attendant, payez par mobile money.', card: 'Carte bancaire : bientôt', mm: 'Mobile money', cardTab: 'Carte bancaire', feeLine: 'Pack {p} FCFA + frais de paiement {f} FCFA', feeNote: 'Des frais d’opérateur peuvent s’appliquer.', validate: 'Validez {a} sur votre téléphone (frais d’opérateur inclus).', firstName: 'Prénom', lastName: 'Nom', city: 'Ville', zip: 'Code postal', countryCard: 'Pays', phoneCard: 'Téléphone (avec indicatif)', cardGo: 'Payer par carte', cardInfo: 'Vous serez redirigé vers la page de paiement sécurisée de FeexPay (3D Secure).', pending: 'Paiement en cours de vérification…', approx: '≈ {e} €', paying: 'Validez le paiement sur votre téléphone…', waitPay: 'En attente de la confirmation de l’opérateur', paid: 'Paiement reçu, crédits ajoutés', payFailed: 'Paiement refusé ou annulé. Réessayez.', openPay: 'Ouvrir la page de paiement', close: 'Fermer',
      termsAccept: 'J’ai lu et j’accepte les ', termsLink: 'conditions générales', termsNote: ' Je demande l’exécution immédiate du service et je reconnais perdre mon droit de rétractation pour les crédits utilisés.', cardPackOnly: 'Par carte : packs de 20 et 55 crédits.', 
      e: { terms_required: 'Cochez l’acceptation des conditions générales.', card_pack_limited: 'Ce pack n’est pas disponible par carte. Choisissez un pack plus petit.', card_limit: 'Limite d’achats par carte atteinte. Réessayez plus tard ou payez par mobile money.', no_instruction: 'Décrivez la modification à faire.', no_image: 'Image introuvable : refaites une génération.', insufficient_credits: 'Pas assez de crédits.', daily_limit: 'Limite quotidienne atteinte. Revenez demain.', refused: 'L’image n’a pas pu être créée avec cette photo. Essayez-en une autre. Votre crédit est rendu.', busy: 'Service très sollicité. Réessayez dans un instant. Votre crédit est rendu.', gemini_error: 'La création a échoué. Votre crédit est rendu.', photo_too_big: 'Photo trop lourde.', bad_photo: 'Format de photo non pris en charge.', auth: 'Reconnectez-vous.', payment_refused: 'Le paiement n’a pas pu démarrer. Vérifiez le numéro et l’opérateur.', bad_phone: 'Numéro invalide.', bad_card_info: 'Complétez tous les champs.', card_unavailable: 'Le paiement par carte n’est pas encore disponible.', otp_required: 'Code OTP requis.', rate: 'Trop de demandes, patientez un instant.', server: 'Erreur du service, réessayez.' },
    },
    en: {
      login: 'Continue with Google', loginNote: 'Quick sign-in with your Google account. If you already have an account, you are simply signed back in.',
      hello: 'Hello', back: 'Welcome back', welcome: 'Account created', credits: 'credits', credit: 'credit', buy: 'Buy credits', logout: 'Sign out',
      cmd: 'Command', change: 'Change', photos: 'Your photos', photosHint: 'Up to 3 photos (one or several products). JPG, PNG or WebP.', add: 'Add a photo', remove: 'Remove',
      prodLabel: { product: 'Your product', dish: 'Your dish', person: 'In the photo', place: 'Your property' }, prodPh: 'e.g. face cream, 3 juice bottles', single: 'Single', several: 'Several',
      gen: 'Generate', genCost: 'Generate · 1 credit', needPhoto: 'Add a photo to generate', working: 'Creating… about 20 seconds', done: 'Here is your visual', download: 'Download', again: 'Redo · 1 credit', editTitle: 'Spotted a flaw? Fix or change it', editPh: 'e.g. remove the glare on the left, lighter background, sharper logo', editBtn: 'Apply · 1 credit', editing: 'Editing… about 20 seconds', version: 'Version', editHint: 'Describe what to change. The rest of the image is kept. Each edit costs 1 credit.', ai: 'AI-generated · Gemini', aiNote: 'the downloaded file has no mark on the image',
      noCredit: 'You need credits to generate.', balance: 'Balance',
      help: 'Payment problem? Write to us:', buyTitle: 'Buy credits', buySub: '1 credit = 1 generation. Credits do not expire.', popular: 'Popular', perCredit: 'per credit', pay: 'Pay', country: 'Country', operator: 'Operator', phone: 'Mobile money number', otp: 'OTP code', otpHint: 'Orange Burkina: dial #144*4*6*amount# then enter the code you receive.',
      feeLineCard: 'Pack {p} + payment fees {f}', usdNote: 'Prices in US dollars. With mobile money, the amount is converted to FCFA.',
      passUnit: 'days', passTag: 'No ads', passOne: 'No-ads pass', passWhat: 'on the whole site', passTitle: 'No-ads pass · 30 days', passSub: 'No advertising for 30 days. No automatic renewal.', noAdsUntil: 'Ad-free until {d}', paidPass: 'Payment received: no-ads pass activated', passLogin: 'Sign in to activate your no-ads pass (30 days).', passBuy: 'Activate the no-ads pass',
      soon: 'soon', cardSoon: 'Card payment is coming soon. Thanks, we noted your request: for now, please pay by mobile money.', card: 'Card payment: coming soon', mm: 'Mobile money', cardTab: 'Bank card', feeLine: 'Pack {p} FCFA + payment fees {f} FCFA', feeNote: 'Operator fees may apply.', validate: 'Confirm {a} on your phone (operator fees included).', firstName: 'First name', lastName: 'Last name', city: 'City', zip: 'Postal code', countryCard: 'Country', phoneCard: 'Phone (with country code)', cardGo: 'Pay by card', cardInfo: 'You will be redirected to FeexPay’s secure payment page (3D Secure).', pending: 'Checking your payment…', approx: '≈ €{e}', paying: 'Confirm the payment on your phone…', waitPay: 'Waiting for the operator’s confirmation', paid: 'Payment received, credits added', payFailed: 'Payment declined or cancelled. Please try again.', openPay: 'Open the payment page', close: 'Close',
      termsAccept: 'I have read and accept the ', termsLink: 'terms and conditions', termsNote: ' I request immediate performance of the service and acknowledge that I lose my right of withdrawal for credits already used.', cardPackOnly: 'By card: 20 and 55 credit packs.', 
      e: { terms_required: 'Please tick the box to accept the terms.', card_pack_limited: 'This pack is not available by card. Choose a smaller pack.', card_limit: 'Card purchase limit reached. Try again later or pay by mobile money.', no_instruction: 'Describe the change you want.', no_image: 'Image not found: please generate again.', insufficient_credits: 'Not enough credits.', daily_limit: 'Daily limit reached. Come back tomorrow.', refused: 'The image could not be created from this photo. Try another one. Your credit is refunded.', busy: 'The service is busy. Try again in a moment. Your credit is refunded.', gemini_error: 'Creation failed. Your credit is refunded.', photo_too_big: 'Photo too large.', bad_photo: 'Unsupported photo format.', auth: 'Please sign in again.', payment_refused: 'The payment could not start. Check the number and operator.', bad_phone: 'Invalid number.', bad_card_info: 'Please fill in every field.', card_unavailable: 'Card payment is not available yet.', otp_required: 'OTP code required.', rate: 'Too many requests, please wait a moment.', server: 'Service error, please try again.' },
    },
  }[L];
  var data = {}; try { data = JSON.parse(root.dataset.map); } catch (e) {}
  var params = new URLSearchParams(location.search);
  var slug = data.commands[params.get('c')] ? params.get('c') : Object.keys(data.commands)[0];
  var wantPass = params.get('pass') === '1';
  var state = { user: null, credits: 0, photos: [], multi: false, product: '', busy: false, cfg: null, result: null, versions: [], cur: 0, instruction: '', adFreeUntil: 0 };

  var $ = function (s, r) { return (r || root).querySelector(s); };
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var usd = function (n) { var t = (Math.round(n * 100) / 100).toFixed(2); return L === 'fr' ? t.replace('.', ',') + ' $' : '$' + t; };
  var fmt = function (n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ' '); };
  function setAdFree(ms) {
    state.adFreeUntil = ms > Date.now() ? ms : 0;
    try { if (state.adFreeUntil) localStorage.setItem('sa_nopub', String(state.adFreeUntil)); else localStorage.removeItem('sa_nopub'); } catch (e) {}
  }
  var errText = function (code) { return T.e[code] || T.e.server; };

  function cmdBlock() {
    var c = data.commands[slug];
    return '<div class="scmd"><img src="/img/c/' + (c.img ? slug : 'none') + '-t.webp" alt="" ' + (c.img ? '' : 'hidden') + '><div><small>' + T.cmd + '</small><b>' + esc(c.code) + '</b><span>' + esc(c.title) + '</span></div>' +
      '<select id="s-cmd" aria-label="' + T.change + '">' + Object.keys(data.commands).map(function (k) { return '<option value="' + k + '"' + (k === slug ? ' selected' : '') + '>' + esc(data.commands[k].code + ' · ' + data.commands[k].title) + '</option>'; }).join('') + '</select></div>';
  }
  function render() {
    if (!state.user) {
      root.innerHTML = '<div class="sbox">' + (wantPass ? '<p class="lead">' + T.passLogin + '</p>' : cmdBlock()) + '<button class="btn pri big" type="button" data-login>' + T.login + '</button><p class="hint">' + T.loginNote + '</p><p class="fmsg" id="auth-msg" role="status" aria-live="polite"></p></div>';
      bind(); return;
    }
    var kind = data.commands[slug].kind, lab = T.prodLabel[kind] || T.prodLabel.product;
    var thumbs = state.photos.map(function (p, i) { return '<figure class="ph"><img src="' + p.url + '" alt=""><button type="button" data-rm="' + i + '" aria-label="' + T.remove + '">×</button></figure>'; }).join('');
    var addBtn = state.photos.length < 3 ? '<label class="addph"><input id="s-file" type="file" accept="image/jpeg,image/png,image/webp,image/*" multiple hidden><span>+</span><small>' + T.add + '</small></label>' : '';
    var canGen = state.photos.length && !state.busy;
    var genLabel = state.credits < 1 ? T.buy : T.genCost;
    root.innerHTML =
      '<div class="sbar"><div><small>' + T.hello + ', ' + esc((state.user.displayName || '').split(' ')[0] || state.user.email) + '</small><b id="s-bal">' + state.credits + ' ' + (state.credits === 1 ? T.credit : T.credits) + '</b>' + (state.adFreeUntil ? '<small class="okline">' + T.noAdsUntil.replace('{d}', new Date(state.adFreeUntil).toLocaleDateString(L === 'en' ? 'en-GB' : 'fr-FR', { day: 'numeric', month: 'long' })) + '</small>' : '') + '</div><div class="acts"><button class="btn pri sm" type="button" id="s-buy">' + T.buy + '</button>' + (state.user.email === 'jorbienvenu@gmail.com' ? '<a class="btn gl sm" href="/admin/">Hub</a>' : '') + '<button class="btn gl sm" type="button" data-logout>' + T.logout + '</button></div></div>' +
      '<div class="sbox">' + cmdBlock() +
      '<div class="sf"><b>' + T.photos + '</b><div class="phs">' + thumbs + addBtn + '</div><small class="hint">' + T.photosHint + '</small></div>' +
      '<div class="adapt sf"><label>' + lab + '<input id="s-prod" type="text" maxlength="60" placeholder="' + esc(T.prodPh) + '" value="' + esc(state.product) + '" autocomplete="off"></label><div class="seg2" role="group"><button type="button" data-n="1" aria-pressed="' + (!state.multi) + '">' + T.single + '</button><button type="button" data-n="n" aria-pressed="' + state.multi + '">' + T.several + '</button></div></div>' +
      '<button class="btn pri big" type="button" id="s-gen"' + (state.credits >= 1 && !canGen ? ' disabled' : '') + '>' + (state.busy ? T.working : (state.credits >= 1 && !state.photos.length ? T.needPhoto : genLabel)) + '</button>' +
      '<p class="fmsg" id="s-msg" role="status" aria-live="polite"></p></div>' +
      (state.result ? '<div class="sres"><img src="' + state.result.url + '" alt="">' +
        (state.versions.length > 1 ? '<div class="vers">' + state.versions.map(function (v, i) { return '<button type="button" data-v="' + i + '" aria-pressed="' + (i === state.cur) + '">' + T.version + ' ' + (i + 1) + '</button>'; }).join('') + '</div>' : '') +
        '<div class="acts big"><a class="btn pri big" href="' + state.result.url + '" download="slashatlas-' + slug + '-v' + (state.cur + 1) + '.' + state.result.ext + '">' + T.download + '</a><button class="btn gl big" type="button" id="s-again">' + T.again + '</button></div>' +
        '<div class="sedit"><b>' + T.editTitle + '</b><textarea id="s-edit" rows="2" maxlength="300" placeholder="' + esc(T.editPh) + '">' + esc(state.instruction) + '</textarea><small class="hint">' + T.editHint + '</small><button class="btn pri big" type="button" id="s-editgo"' + (state.busy ? ' disabled' : '') + '>' + (state.busy ? T.editing : T.editBtn) + '</button></div>' +
        '<small class="aic">' + T.ai + ' · ' + T.aiNote + '</small></div>' : '');
    bind();
  }
  function msg(t, ok) { var m = $('#s-msg') || $('#auth-msg'); if (m) { m.textContent = t || ''; m.className = 'fmsg' + (ok ? ' ok' : ''); } }

  function bind() {
    var sel = $('#s-cmd'); if (sel) sel.addEventListener('change', function () { slug = sel.value; history.replaceState(null, '', '?c=' + slug); state.result = null; render(); });
    var f = $('#s-file'); if (f) f.addEventListener('change', function () { addFiles(f.files); });
    Array.prototype.forEach.call(root.querySelectorAll('[data-rm]'), function (b) { b.addEventListener('click', function () { var p = state.photos.splice(+b.dataset.rm, 1)[0]; if (p) URL.revokeObjectURL(p.url); render(); }); });
    var pr = $('#s-prod'); if (pr) pr.addEventListener('input', function () { state.product = pr.value; });
    Array.prototype.forEach.call(root.querySelectorAll('.seg2 button'), function (b) { b.addEventListener('click', function () { state.multi = b.dataset.n === 'n'; Array.prototype.forEach.call(root.querySelectorAll('.seg2 button'), function (x) { x.setAttribute('aria-pressed', x === b ? 'true' : 'false'); }); }); });
    var g = $('#s-gen'); if (g) g.addEventListener('click', function () { if (state.credits < 1) openBuy('generer'); else generate(); });
    var ag = $('#s-again'); if (ag) ag.addEventListener('click', function () { if (state.credits < 1) openBuy('refaire'); else generate(); });
    var by = $('#s-buy'); if (by) by.addEventListener('click', openBuy);
    var ed = $('#s-edit'); if (ed) ed.addEventListener('input', function () { state.instruction = ed.value; });
    var eg = $('#s-editgo'); if (eg) eg.addEventListener('click', function () { if (state.credits < 1) openBuy('corriger'); else editImage(); });
    Array.prototype.forEach.call(root.querySelectorAll('[data-v]'), function (b) { b.addEventListener('click', function () { state.cur = +b.dataset.v; state.result = state.versions[state.cur]; render(); }); });
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
    state.busy = true; state.result = null; state.versions = []; render(); msg('');
    var body = { slug: slug, lang: L, product: state.product, multi: state.multi, photos: state.photos.map(function (p) { return { mime: p.mime, data: p.data }; }) };
    window.slashAuth.call('generate', body).then(function (r) {
      state.busy = false;
      if (r.status === 200) {
        var bin = atob(r.data.image), arr = new Uint8Array(bin.length); for (var i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
        var ext = r.data.mime.indexOf('jpeg') >= 0 ? 'jpg' : 'png';
        state.result = { id: r.data.id, url: URL.createObjectURL(new Blob([arr], { type: r.data.mime })), ext: ext };
        state.versions = [state.result]; state.cur = 0; state.instruction = '';
        state.credits = r.data.credits; render(); window.scrollTo({ top: $('.sres').offsetTop - 70, behavior: 'smooth' });
      } else {
        if (r.data && r.data.error === 'insufficient_credits') { render(); openBuy('serveur'); return; }
        render(); msg(errText(r.data && r.data.error));
      }
    }).catch(function () { state.busy = false; render(); msg(T.e.server); });
  }

  function editImage() {
    var cur = state.versions[state.cur];
    if (state.busy || !cur) return;
    var text = (state.instruction || '').trim();
    if (text.length < 3) return msg(T.e.no_instruction);
    state.busy = true; render();
    window.slashAuth.call('edit', { id: cur.id, lang: L, instruction: text }).then(function (r) {
      state.busy = false;
      if (r.status === 200) {
        var bin = atob(r.data.image), arr = new Uint8Array(bin.length); for (var i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
        var v = { id: r.data.id, url: URL.createObjectURL(new Blob([arr], { type: r.data.mime })), ext: r.data.mime.indexOf('jpeg') >= 0 ? 'jpg' : 'png' };
        state.versions.push(v); state.cur = state.versions.length - 1; state.result = v; state.instruction = ''; state.credits = r.data.credits; render();
      } else if (r.data && r.data.error === 'insufficient_credits') { render(); openBuy('serveur'); }
      else { render(); msg(errText(r.data && r.data.error)); }
    }).catch(function () { state.busy = false; render(); msg(T.e.server); });
  }

  // ── achat de crédits (mobile money) ──
  function quoteUsd(price, payin, payout) { var r2 = function (n) { return Math.round(n * 100) / 100; }, send = r2(price * (1 + payout / 100)), total = r2(send * (1 + payin / 100)); return { send: send, total: total, fee: r2(total - price) }; }
  function quote(price, payin, payout) { var send = Math.ceil(price * (1 + payout / 100)), total = Math.ceil(send * (1 + payin / 100)); return { send: send, total: total, fee: total - price }; }
  function openBuy(from) {
    var cfg = state.cfg; if (!cfg) return;
    try { window.saTrack && window.saTrack('buyopen', { n: typeof from === 'string' ? from : 'button' }); } catch (e) {}
    var countries = []; cfg.operators.forEach(function (o) { if (countries.indexOf(o.country) < 0) countries.push(o.country); });
    var sel = { pack: (typeof from === 'string' && from === 'pass') ? 'nopub' : (cfg.packs[1] ? cfg.packs[1].id : cfg.packs[0].id), country: countries[0], op: null, method: 'mm', terms: false };
    var TL = L === 'en' ? '/en/terms/' : '/conditions/';
    function cardOk(id) { return !cfg.card.packs || cfg.card.packs.indexOf(id) >= 0; }
    var modal = document.createElement('div'); modal.className = 'smodal'; modal.setAttribute('role', 'dialog'); modal.setAttribute('aria-modal', 'true');
    document.body.appendChild(modal); document.body.style.overflow = 'hidden';
    var timer = null, ISO = ['FR', 'BE', 'CH', 'LU', 'DE', 'ES', 'PT', 'IT', 'NL', 'GB', 'IE', 'US', 'CA', 'BR', 'MX', 'CO', 'BJ', 'TG', 'CI', 'SN', 'BF', 'ML', 'CM', 'CG', 'GA', 'GN', 'NE', 'TD', 'CD', 'MA', 'DZ', 'TN', 'GH', 'NG'];
    function close() { clearInterval(timer); modal.remove(); document.body.style.overflow = ''; }
    function ops() { return cfg.operators.filter(function (o) { return o.country === sel.country; }); }
    function countryName(c) { try { return new Intl.DisplayNames([L], { type: 'region' }).of(c) || c; } catch (e) { return c; } }
    function draw() {
      if (!sel.op || sel.op.country !== sel.country) sel.op = ops()[0];
      var pk = cfg.packs.filter(function (p) { return p.id === sel.pack; })[0];
      var isCard = sel.method === 'card';
      if (isCard && !cardOk(sel.pack)) sel.pack = cfg.packs.filter(function (p) { return cardOk(p.id); }).pop().id;
      pk = cfg.packs.filter(function (p) { return p.id === sel.pack; })[0];
      var tabs = '<div class="mtabs" role="tablist"><button type="button" data-m="mm" aria-pressed="' + !isCard + '">' + T.mm + '</button>' + (cfg.card && cfg.card.enabled ? '<button type="button" data-m="card" aria-pressed="' + isCard + '">' + T.cardTab + '</button>' : '<button type="button" data-soon="1">' + T.cardTab + ' <em class="soon">' + T.soon + '</em></button>') + '</div>';
      var form;
      if (!isCard) {
        form = '<label>' + T.country + '<select id="b-country">' + countries.map(function (c) { return '<option' + (c === sel.country ? ' selected' : '') + '>' + esc(c) + '</option>'; }).join('') + '</select></label>' +
          '<label>' + T.operator + '<select id="b-op">' + ops().map(function (o) { return '<option value="' + o.code + '"' + (o.code === sel.op.code ? ' selected' : '') + '>' + esc(o.label) + '</option>'; }).join('') + '</select></label>' +
          '<label>' + T.phone + '<span class="pfx"><i>+' + sel.op.dial + '</i><input id="b-phone" type="tel" inputmode="tel" autocomplete="tel-national" placeholder="XXXXXXXX"></span></label>' +
          (sel.op.otp ? '<label>' + T.otp + '<input id="b-otp" type="text" inputmode="numeric" autocomplete="one-time-code"></label><p class="hint">' + T.otpHint + '</p>' : '');
      } else {
        var nm = (state.user.displayName || '').split(' ');
        form = '<div class="two"><label>' + T.firstName + '<input id="c-first" autocomplete="given-name" value="' + esc(nm[0] || '') + '"></label><label>' + T.lastName + '<input id="c-last" autocomplete="family-name" value="' + esc(nm.slice(1).join(' ')) + '"></label></div>' +
          '<label>' + T.phoneCard + '<input id="c-phone" type="tel" inputmode="tel" autocomplete="tel" placeholder="+33…"></label>' +
          '<div class="two"><label>' + T.city + '<input id="c-city" autocomplete="address-level2"></label><label>' + T.zip + '<input id="c-zip" autocomplete="postal-code"></label></div>' +
          '<label>' + T.countryCard + '<select id="c-country">' + ISO.map(function (c) { return '<option value="' + c + '">' + esc(countryName(c)) + '</option>'; }).join('') + '</select></label><p class="hint">' + T.cardInfo + '</p>';
      }
      modal.innerHTML = '<div class="sheet"><button class="x" type="button" aria-label="' + T.close + '">×</button><h2>' + (pk.days ? T.passTitle : T.buyTitle) + '</h2><p class="hint">' + (pk.days ? T.passSub : T.buySub) + '</p>' +
        '<div class="packs">' + cfg.packs.map(function (p) { return '<button type="button" class="pack' + (p.id === sel.pack ? ' on' : '') + '" data-p="' + p.id + '"' + (isCard && !cardOk(p.id) ? ' disabled' : '') + '>' + (p.tag ? '<i>' + T.popular + '</i>' : '') + (p.days ? '<b>' + p.days + '</b><span>' + T.passUnit + '</span><em>' + usd(p.usd) + '</em><small>≈ ' + fmt(p.xof) + ' FCFA</small>' : '<b>' + p.credits + '</b><span>' + T.credits + '</span><em>' + usd(p.usd) + '</em><small>≈ ' + fmt(p.xof) + ' FCFA</small>') + '</button>'; }).join('') + '</div>' + tabs + form +
        '<p class="hint soft">' + T.feeNote + '</p><label class="terms"><input type="checkbox" id="b-terms"' + (sel.terms ? ' checked' : '') + '><span>' + T.termsAccept + '<a href="' + TL + '" target="_blank" rel="noopener">' + T.termsLink + '</a>.' + T.termsNote + '</span></label>' + (isCard ? '<p class="hint">' + T.cardPackOnly + '</p>' : '') +
        '<button class="btn pri big" type="button" id="b-pay">' + (isCard ? T.cardGo + ' ' + usd(pk.usd) : T.pay + ' ' + fmt(pk.xof) + ' FCFA') + '</button><p class="fmsg" id="b-msg" role="status" aria-live="polite"></p>' + (CONTACT ? '<p class="hint soft">' + T.help + ' <a href="mailto:' + CONTACT + '">' + CONTACT + '</a></p>' : '') + '</div>';
      $('.x', modal).onclick = close;
      Array.prototype.forEach.call(modal.querySelectorAll('.pack'), function (b) { b.onclick = function () { sel.pack = b.dataset.p; draw(); }; });
      Array.prototype.forEach.call(modal.querySelectorAll('[data-m]'), function (b) { b.onclick = function () { sel.method = b.dataset.m; draw(); }; });
      var co = $('#b-country', modal); if (co) co.onchange = function (e) { sel.country = e.target.value; sel.op = null; draw(); };
      var op = $('#b-op', modal); if (op) op.onchange = function (e) { sel.op = ops().filter(function (o) { return o.code === e.target.value; })[0]; draw(); };
      var sn = $('[data-soon]', modal); if (sn) sn.onclick = function () { try { window.saTrack && window.saTrack('cardwish', { n: sel.pack }); } catch (e) {} bmsg(T.cardSoon, true); };
      $('#b-terms', modal).onchange = function (e) { sel.terms = e.target.checked; };
      $('#b-pay', modal).onclick = isCard ? payCard : pay;
    }
    function bmsg(t, ok) { var m = $('#b-msg', modal); if (m) { m.textContent = t || ''; m.className = 'fmsg' + (ok ? ' ok' : ''); } }
    function track(orderId, btn, total) {
      var tries = 0; bmsg(total ? T.validate.replace('{a}', fmt(total) + ' FCFA') : T.waitPay, true);
      timer = setInterval(function () {
        tries++;
        window.slashAuth.call('pay/status', { orderId: orderId }).then(function (s) {
          if (s.status !== 200) return;
          if (s.data.status === 'paid') { clearInterval(timer); try { localStorage.removeItem('sa_pending'); } catch (e) {} state.credits = s.data.balance; if (s.data.adFreeUntil) setAdFree(s.data.adFreeUntil); bmsg(s.data.adFreeUntil && !s.data.credits ? T.paidPass : T.paid, true); setTimeout(function () { close(); render(); }, 1200); }
          else if (s.data.status === 'failed') { clearInterval(timer); btn.disabled = false; bmsg(T.payFailed); }
        });
        if (tries > 60) { clearInterval(timer); btn.disabled = false; bmsg(T.payFailed); }
      }, 4000);
    }
    function pay() {
      var btn = $('#b-pay', modal), phone = $('#b-phone', modal).value.replace(/\D/g, ''), otp = sel.op.otp ? ($('#b-otp', modal).value || '').trim() : '';
      var okForm = phone.length >= 8 && !(sel.op.otp && !otp) && sel.terms;
      try { window.saTrack && window.saTrack('paytry', { m: 'mm', n: sel.pack, o: sel.op.code, v: okForm ? 1 : 0 }); } catch (e) {}
      if (phone.length < 8) return bmsg(T.e.bad_phone);
      if (sel.op.otp && !otp) return bmsg(T.e.otp_required);
      if (!sel.terms) return bmsg(T.e.terms_required);
      btn.disabled = true; bmsg(T.paying, true);
      window.slashAuth.call('pay/start', { packId: sel.pack, operator: sel.op.code, phone: phone, otp: otp, terms: cfg.termsVersion }).then(function (r) {
        if (r.status !== 200) { btn.disabled = false; return bmsg(errText(r.data && r.data.error)); }
        if (r.data.paymentUrl) { var a = document.createElement('a'); a.href = r.data.paymentUrl; a.target = '_blank'; a.rel = 'noopener'; a.textContent = T.openPay; a.className = 'btn gl'; $('#b-msg', modal).after(a); }
        track(r.data.orderId, btn, r.data.total);
      }).catch(function () { btn.disabled = false; bmsg(T.e.server); });
    }
    function payCard() {
      var btn = $('#b-pay', modal), v = function (id) { return ($('#' + id, modal).value || '').trim(); };
      var body = { packId: sel.pack, firstName: v('c-first'), lastName: v('c-last'), phone: v('c-phone'), city: v('c-city'), zip: v('c-zip'), country: $('#c-country', modal).value, terms: cfg.termsVersion };
      if (!sel.terms) return bmsg(T.e.terms_required);
      if (!body.firstName || !body.lastName || !body.city || !body.zip || body.phone.replace(/\D/g, '').length < 8) return bmsg(T.e.bad_card_info);
      btn.disabled = true; bmsg(T.paying, true);
      window.slashAuth.call('pay/card', body).then(function (r) {
        if (r.status !== 200) { btn.disabled = false; return bmsg(errText(r.data && r.data.error)); }
        try { localStorage.setItem('sa_pending', r.data.orderId); } catch (e) {}
        location.href = r.data.paymentUrl;
      }).catch(function () { btn.disabled = false; bmsg(T.e.server); });
    }
    draw();
  }
  // retour de la page de paiement par carte : on vérifie la commande en attente
  function resumePending() {
    var id = null; try { id = localStorage.getItem('sa_pending'); } catch (e) {}
    if (!id || !state.user) return;
    msg(T.pending, true);
    var tries = 0, t = setInterval(function () {
      tries++;
      window.slashAuth.call('pay/status', { orderId: id }).then(function (s) {
        if (s.status === 200 && s.data.status === 'paid') { clearInterval(t); try { localStorage.removeItem('sa_pending'); } catch (e) {} state.credits = s.data.balance; if (s.data.adFreeUntil) setAdFree(s.data.adFreeUntil); render(); msg(s.data.adFreeUntil && !s.data.credits ? T.paidPass : T.paid, true); }
        else if (s.status === 200 && s.data.status === 'failed') { clearInterval(t); try { localStorage.removeItem('sa_pending'); } catch (e) {} msg(T.payFailed); }
        else if (s.status === 404) { clearInterval(t); try { localStorage.removeItem('sa_pending'); } catch (e) {} msg(''); }
      });
      if (tries > 30) clearInterval(t);
    }, 4000);
  }

  function maybePass() { if (wantPass && state.user && state.cfg && !state.adFreeUntil && state.meLoaded) { wantPass = false; openBuy('pass'); } }

  // ── démarrage ──
  import('/js/auth.js');
  fetch('/api/config').then(function (r) { return r.json(); }).then(function (c) { state.cfg = c; maybePass(); }).catch(function () {});
  document.addEventListener('sa:auth', function (e) {
    var u = e.detail.user; state.user = u;
    if (!u) { state.credits = 0; state.result = null; render(); return; }
    window.slashAuth.call('me').then(function (r) {
      if (r.status === 200) { state.meLoaded = true; state.credits = r.data.credits; setAdFree(r.data.adFreeUntil || 0); render(); msg(r.data.created ? T.welcome : T.back, true); setTimeout(function () { msg(''); }, 2500); resumePending(); maybePass(); }
      else { render(); msg(errText(r.data && r.data.error)); }
    });
  });
  render();
})();
