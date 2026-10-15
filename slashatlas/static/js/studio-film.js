(function () {
  'use strict';
  import('/js/auth.js');
  var $ = function (s) { return document.querySelector(s); };
  var lang = document.documentElement.lang || 'fr';
  var isFr = lang !== 'en';

  var T = {
    fr: {
      creating: 'Scénario en cours…',
      rendering: 'Génération des images et de la voix…',
      assembling: 'Assemblage de la vidéo…',
      done: 'Votre film est prêt !',
      download: 'Télécharger la vidéo',
      err: 'Une erreur est survenue. Vos crédits n\'ont pas été débités.',
      errCred: 'Crédits insuffisants.',
      e: {
        rate_user: 'Vous avez atteint le nombre maximum de films pour aujourd\'hui. Revenez demain.',
        rate_global: 'Le service est saturé pour aujourd\'hui. Réessayez demain.',
        gemini_unavailable: 'Le service de génération d\'images est temporairement indisponible. Réessayez dans quelques minutes.',
        gemini_error: 'La génération a échoué. Vos crédits n\'ont pas été débités. Réessayez.',
        gemini_404: 'Le modèle d\'IA est indisponible. Réessayez dans quelques instants.',
        busy: 'Service très sollicité. Réessayez dans un instant.',
        no_credits: 'Crédits insuffisants pour créer ce film.',
        missing_fields: 'Veuillez remplir tous les champs obligatoires.',
        no_json: 'Erreur de génération du scénario. Réessayez.',
        server: 'Erreur du service. Réessayez.',
      },
      credLink: 'Recharger',
      wait: 'La vidéo prend 3 à 6 minutes. Ne fermez pas cette page.',
      steps: ['Scénario', 'Images & voix', 'Assemblage'],
      credModalH: 'Crédits insuffisants',
      credModalP: 'Il vous faut au moins 10 crédits pour créer un film de 2 min. Rechargez facilement via mobile money ou carte bancaire.',
      credMomo: '📱 Mobile Money',
      credCard: '💳 Carte bancaire',
      credClose: 'Fermer',
      seriesH: 'Mes séries',
      seriesSub: 'Continuez une série existante ou créez-en une nouvelle.',
      seriesEp: 'épisode',
      seriesEps: 'épisodes',
      seriesContinue: 'Ajouter un épisode',
      seriesEmpty: 'Aucune série pour l\'instant.',
      seriesNew: '+ Nouvelle série',
      episodeBadge: 'Épisode',
    },
    en: {
      creating: 'Writing the script…',
      rendering: 'Generating images and voice…',
      assembling: 'Assembling the video…',
      done: 'Your film is ready!',
      download: 'Download the video',
      err: 'An error occurred. Your credits were not deducted.',
      errCred: 'Not enough credits.',
      e: {
        rate_user: 'You have reached the maximum number of films for today. Come back tomorrow.',
        rate_global: 'The service is fully booked for today. Try again tomorrow.',
        gemini_unavailable: 'The image generation service is temporarily unavailable. Try again in a few minutes.',
        gemini_error: 'Generation failed. Your credits were not deducted. Please try again.',
        gemini_404: 'The AI model is currently unavailable. Try again in a moment.',
        busy: 'The service is very busy. Try again in a moment.',
        no_credits: 'Not enough credits to create this film.',
        missing_fields: 'Please fill in all required fields.',
        no_json: 'Script generation error. Please try again.',
        server: 'Service error. Please try again.',
      },
      credLink: 'Top up',
      wait: 'The video takes 3 to 6 minutes. Do not close this page.',
      steps: ['Script', 'Images & voice', 'Assembly'],
      credModalH: 'Not enough credits',
      credModalP: 'You need at least 10 credits to create a 2-min film. Top up via mobile money or bank card.',
      credMomo: '📱 Mobile Money',
      credCard: '💳 Bank card',
      credClose: 'Close',
      seriesH: 'My series',
      seriesSub: 'Continue an existing series or start a new one.',
      seriesEp: 'episode',
      seriesEps: 'episodes',
      seriesContinue: 'Add an episode',
      seriesEmpty: 'No series yet.',
      seriesNew: '+ New series',
      episodeBadge: 'Episode',
    },
  }[isFr ? 'fr' : 'en'];

  var pollTimer = null;
  var currentSeriesId = null; // série sélectionnée pour le prochain épisode
  var uploadedAudioPath = null; // chemin Firebase Storage de l'audio importé
  var userBalance = null;

  function updateSerieMode() {
    var genreEl = $('#film-genre');
    var serieFields = document.getElementById('film-serie-fields');
    var titleLabel = document.getElementById('film-title-label');
    var synopsisLabel = document.getElementById('film-synopsis-label');
    var isNewSerie = genreEl && genreEl.value === 'serie' && !currentSeriesId;
    if (serieFields) serieFields.hidden = !isNewSerie;
    if (titleLabel) titleLabel.textContent = isNewSerie
      ? (isFr ? 'Titre de l\'épisode 1' : 'Episode 1 title')
      : (isFr ? 'Titre de votre film ou série' : 'Title of your film or series');
    if (synopsisLabel) synopsisLabel.textContent = isNewSerie
      ? (isFr ? 'Synopsis de l\'épisode 1' : 'Episode 1 synopsis')
      : (isFr ? 'Description de l\'histoire' : 'Story description');
    if (!isNewSerie) {
      var stEl = document.getElementById('film-series-title');
      var ssEl = document.getElementById('film-series-synopsis');
      if (stEl) stEl.value = '';
      if (ssEl) ssEl.value = '';
    }
  }

  function refreshBalance(onDone) {
    if (!window.slashAuth) { if (onDone) onDone(); return; }
    window.slashAuth.call('me').then(function (r) {
      if (r && r.status === 200 && r.data) {
        userBalance = r.data.credits || 0;
        var balEl = document.getElementById('film-bal');
        if (balEl) balEl.textContent = String(userBalance);
        checkBalWarning();
      }
      if (onDone) onDone();
    }).catch(function () { if (onDone) onDone(); });
  }

  function checkBalWarning() {
    var cost = recalcCost();
    var warn = document.getElementById('film-cred-warn');
    if (!warn || userBalance === null) return;
    if (userBalance < cost) {
      warn.textContent = (isFr ? 'Solde insuffisant. ' : 'Insufficient balance. ') + (isFr ? 'Rechargez avant de créer.' : 'Top up before creating.');
      warn.hidden = false;
    } else {
      warn.hidden = true;
    }
  }

  // ── Calcul dynamique du coût ──────────────────────────────────────────────────
  var FILM_COST = { 2: 10, 3: 15 };
  function recalcCost() {
    var durEl = document.querySelector('input[name="dur"]:checked');
    var dur = durEl ? +durEl.value : 2;
    var wm = $('#film-watermark') ? $('#film-watermark').checked : true;
    var audioToggle = document.getElementById('film-audio-toggle');
    var hasAudio = !!(uploadedAudioPath && audioToggle && audioToggle.checked);
    var cost = FILM_COST[dur] || 10;
    if (wm) cost -= 1;
    if (hasAudio) cost -= 2;
    cost = Math.max(1, cost);
    var costEl = $('#film-cost-val');
    if (costEl) costEl.textContent = String(cost);
    return cost;
  }

  function recalcCostAndWarn() { recalcCost(); checkBalWarning(); }

  // ── Modal crédits insuffisants ────────────────────────────────────────────────
  var credModal = null;
  function buildCredModal() {
    if (credModal) return;
    credModal = document.createElement('div');
    credModal.className = 'film-cred-modal';
    credModal.innerHTML =
      '<div class="film-cred-inner">' +
        '<button class="film-cred-close" aria-label="' + T.credClose + '">✕</button>' +
        '<div class="film-cred-icon">🪙</div>' +
        '<h3 class="film-cred-h">' + T.credModalH + '</h3>' +
        '<p class="film-cred-p">' + T.credModalP + '</p>' +
        '<div class="film-cred-btns">' +
          '<button class="btn pri film-cred-btn" data-buy="mm">' + T.credMomo + '</button>' +
          '<button class="btn pri film-cred-btn" data-buy="card">' + T.credCard + '</button>' +
        '</div>' +
      '</div>';
    document.body.appendChild(credModal);
    credModal.querySelector('.film-cred-close').addEventListener('click', closeCredModal);
    credModal.querySelectorAll('[data-buy]').forEach(function (btn) {
      btn.addEventListener('click', function () { openFilmBuy(btn.dataset.buy); });
    });
    credModal.addEventListener('click', function (e) { if (e.target === credModal) closeCredModal(); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeCredModal(); });
  }
  function openCredModal() {
    buildCredModal();
    credModal.classList.add('open');
    document.body.style.overflow = 'hidden';
  }
  function closeCredModal() {
    if (!credModal) return;
    credModal.classList.remove('open');
    document.body.style.overflow = '';
  }

  // ── Achat de crédits inline depuis la page film ────────────────────────────────
  var filmCfg = null;
  function loadFilmCfg(cb) {
    if (filmCfg) { cb(filmCfg); return; }
    fetch('/api/config').then(function (r) { return r.json(); }).then(function (d) { filmCfg = d; cb(filmCfg); }).catch(function () { cb(null); });
  }
  function openFilmBuy(method) {
    if (window.saTrack) window.saTrack('film_buy_open', { f: 'film', m: method });
    closeCredModal();
    loadFilmCfg(function (cfg) {
      if (!cfg) return;
      var L = isFr ? 'fr' : 'en';
      var TL = isFr ? '/conditions/' : '/en/terms/';
      var TB = {
        fr: { buyTitle: 'Acheter des crédits', buySub: '1 crédit = 1 génération. Les crédits n\'expirent pas.', mm: 'Mobile money', cardTab: 'Carte bancaire', soon: 'bientôt', cardSoon: 'Le paiement par carte arrive bientôt. Merci, nous avons noté votre demande.', country: 'Pays', operator: 'Opérateur', phone: 'Numéro mobile money', otp: 'Code OTP', otpHint: 'Orange Burkina : composez #144*4*6*montant# puis saisissez le code reçu.', pay: 'Payer', cardGo: 'Payer par carte', cardInfo: 'Vous serez redirigé vers la page de paiement sécurisée FeexPay (3D Secure).', firstName: 'Prénom', lastName: 'Nom', city: 'Ville', zip: 'Code postal', countryCard: 'Pays', phoneCard: 'Téléphone (avec indicatif)', feeNote: 'Des frais d\'opérateur peuvent s\'appliquer.', credits: 'crédits', popular: 'Populaire', validate: 'Validez {a} sur votre téléphone (frais d\'opérateur inclus).', paying: 'Validez le paiement sur votre téléphone…', waitPay: 'En attente de la confirmation de l\'opérateur', paid: 'Paiement reçu, crédits ajoutés', payFailed: 'Paiement refusé ou annulé. Réessayez.', openPay: 'Ouvrir la page de paiement', close: 'Fermer', termsTag: 'À cocher pour payer', termsAccept: 'J\'ai lu et j\'accepte les ', termsLink: 'conditions générales', termsNote: ' Je demande l\'exécution immédiate du service et je reconnais perdre mon droit de rétractation pour les crédits utilisés.', cardPackOnly: 'Par carte : packs de 20 et 55 crédits.', e: { bad_phone: 'Numéro invalide.', otp_required: 'Code OTP requis.', terms_required: 'Cochez l\'acceptation des conditions générales.', bad_card_info: 'Complétez tous les champs.', server: 'Erreur du service, réessayez.', payment_refused: 'Le paiement n\'a pas pu démarrer. Vérifiez le numéro et l\'opérateur.' } },
        en: { buyTitle: 'Buy credits', buySub: '1 credit = 1 generation. Credits do not expire.', mm: 'Mobile money', cardTab: 'Bank card', soon: 'soon', cardSoon: 'Card payment is coming soon. Thanks, we noted your request.', country: 'Country', operator: 'Operator', phone: 'Mobile money number', otp: 'OTP code', otpHint: 'Orange Burkina: dial #144*4*6*amount# then enter the code you receive.', pay: 'Pay', cardGo: 'Pay by card', cardInfo: 'You will be redirected to FeexPay\'s secure payment page (3D Secure).', firstName: 'First name', lastName: 'Last name', city: 'City', zip: 'Postal code', countryCard: 'Country', phoneCard: 'Phone (with country code)', feeNote: 'Operator fees may apply.', credits: 'credits', popular: 'Popular', validate: 'Confirm {a} on your phone (operator fees included).', paying: 'Confirm the payment on your phone…', waitPay: 'Waiting for the operator\'s confirmation', paid: 'Payment received, credits added', payFailed: 'Payment declined or cancelled. Please try again.', openPay: 'Open the payment page', close: 'Close', termsTag: 'Tick to pay', termsAccept: 'I have read and accept the ', termsLink: 'terms and conditions', termsNote: ' I request immediate performance of the service and acknowledge that I lose my right of withdrawal for credits already used.', cardPackOnly: 'By card: 20 and 55 credit packs.', e: { bad_phone: 'Invalid number.', otp_required: 'OTP code required.', terms_required: 'Please tick the box to accept the terms.', bad_card_info: 'Please fill in every field.', server: 'Service error, please try again.', payment_refused: 'The payment could not start. Check the number and operator.' } },
      }[L];
      var countries = []; cfg.operators.forEach(function (o) { if (countries.indexOf(o.country) < 0) countries.push(o.country); });
      var sel = { pack: (cfg.packs.filter(function (p) { return p.tag; })[0] || cfg.packs[0]).id, country: countries[0], op: null, method: method || 'mm', terms: false };
      function cardOk(id) { return !cfg.card.packs || cfg.card.packs.indexOf(id) >= 0; }
      function fmtN(n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ' '); }
      function usdN(n) { var t = (Math.round(n * 100) / 100).toFixed(2); return isFr ? t.replace('.', ',') + ' $' : '$' + t; }
      function esc2(s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
      function ops() { return cfg.operators.filter(function (o) { return o.country === sel.country; }); }
      function cname(c) { try { return new Intl.DisplayNames([L], { type: 'region' }).of(c) || c; } catch (e) { return c; } }
      var ISO = ['FR', 'BE', 'CH', 'LU', 'DE', 'ES', 'PT', 'IT', 'NL', 'GB', 'IE', 'US', 'CA', 'BR', 'MX', 'CO', 'BJ', 'TG', 'CI', 'SN', 'BF', 'ML', 'CM', 'CG', 'GA', 'GN', 'NE', 'TD', 'CD', 'MA', 'DZ', 'TN', 'GH', 'NG'];
      var modal = document.createElement('div'); modal.className = 'smodal'; modal.setAttribute('role', 'dialog'); modal.setAttribute('aria-modal', 'true');
      document.body.appendChild(modal); document.body.style.overflow = 'hidden';
      var ptimer = null;
      function busyB(btn, on) { if (!btn) return; btn.disabled = !!on; btn.classList.toggle('loading', !!on); }
      function flagT() { var t = modal.querySelector('.terms'); if (!t) return; t.classList.remove('err'); void t.offsetWidth; t.classList.add('err'); try { t.scrollIntoView({ behavior: 'smooth', block: 'center' }); } catch (e) {} }
      function closeM() { clearInterval(ptimer); modal.remove(); document.body.style.overflow = ''; }
      function bmsg(txt, ok) { var m = modal.querySelector('#bf-msg'); if (m) { m.textContent = txt || ''; m.className = 'fmsg' + (ok ? ' ok' : ' err'); } }
      function errT(code) { return TB.e[code] || TB.e.server; }
      function draw() {
        if (!sel.op || sel.op.country !== sel.country) sel.op = ops()[0];
        var pk = cfg.packs.filter(function (p) { return p.id === sel.pack; })[0];
        var isCard = sel.method === 'card';
        if (isCard && !cardOk(sel.pack)) { var fb = cfg.packs.filter(function (p) { return cardOk(p.id) && p.tag; })[0] || cfg.packs.filter(function (p) { return cardOk(p.id); })[0]; if (fb) sel.pack = fb.id; }
        pk = cfg.packs.filter(function (p) { return p.id === sel.pack; })[0];
        var tabs = '<div class="mtabs" role="tablist"><button type="button" data-m="mm" aria-pressed="' + !isCard + '">' + TB.mm + '</button>' + (cfg.card && cfg.card.enabled ? '<button type="button" data-m="card" aria-pressed="' + isCard + '">' + TB.cardTab + '</button>' : '<button type="button" data-soon="1">' + TB.cardTab + ' <em class="soon">' + TB.soon + '</em></button>') + '</div>';
        var form;
        if (!isCard) {
          form = '<label>' + TB.country + '<select id="bf-country">' + countries.map(function (c) { return '<option' + (c === sel.country ? ' selected' : '') + '>' + esc2(c) + '</option>'; }).join('') + '</select></label>' +
            '<label>' + TB.operator + '<select id="bf-op">' + ops().map(function (o) { return '<option value="' + o.code + '"' + (o.code === sel.op.code ? ' selected' : '') + '>' + esc2(o.label) + '</option>'; }).join('') + '</select></label>' +
            '<label>' + TB.phone + '<span class="pfx"><i>+' + sel.op.dial + '</i><input id="bf-phone" type="tel" inputmode="tel" autocomplete="tel-national" placeholder="XXXXXXXX"></span></label>' +
            (sel.op.otp ? '<label>' + TB.otp + '<input id="bf-otp" type="text" inputmode="numeric" autocomplete="one-time-code"></label><p class="hint">' + TB.otpHint + '</p>' : '');
        } else {
          var nm = ((window.slashAuth && window.slashAuth.user && window.slashAuth.user.displayName) || '').split(' ');
          form = '<div class="two"><label>' + TB.firstName + '<input id="bf-cfirst" autocomplete="given-name" value="' + esc2(nm[0] || '') + '"></label><label>' + TB.lastName + '<input id="bf-clast" autocomplete="family-name" value="' + esc2(nm.slice(1).join(' ')) + '"></label></div>' +
            '<label>' + TB.phoneCard + '<input id="bf-cphone" type="tel" inputmode="tel" autocomplete="tel" placeholder="+33…"></label>' +
            '<div class="two"><label>' + TB.city + '<input id="bf-ccity" autocomplete="address-level2"></label><label>' + TB.zip + '<input id="bf-czip" autocomplete="postal-code"></label></div>' +
            '<label>' + TB.countryCard + '<select id="bf-ccountry">' + ISO.map(function (c) { return '<option value="' + c + '">' + esc2(cname(c)) + '</option>'; }).join('') + '</select></label><p class="hint">' + TB.cardInfo + '</p>';
        }
        modal.innerHTML = '<div class="sheet"><button class="x" type="button" aria-label="' + esc2(TB.close) + '">×</button><h2>' + TB.buyTitle + '</h2><p class="hint">' + TB.buySub + '</p>' +
          '<div class="packs">' + cfg.packs.filter(function (p) { return !p.days; }).map(function (p) { return '<button type="button" class="pack' + (p.id === sel.pack ? ' on' : '') + '" data-p="' + p.id + '"' + (isCard && !cardOk(p.id) ? ' disabled' : '') + '>' + (p.tag ? '<i>' + TB.popular + '</i>' : '') + '<b>' + p.credits + '</b><span>' + TB.credits + '</span><em>' + usdN(p.usd) + '</em><small>≈ ' + fmtN(p.xof) + ' FCFA</small></button>'; }).join('') + '</div>' +
          tabs + form +
          '<p class="hint soft">' + TB.feeNote + '</p>' +
          '<label class="terms"><input type="checkbox" id="bf-terms"' + (sel.terms ? ' checked' : '') + '><span><b class="ttag">' + TB.termsTag + '</b>' + TB.termsAccept + '<a href="' + TL + '" target="_blank" rel="noopener">' + TB.termsLink + '</a>.' + TB.termsNote + '</span></label>' +
          (isCard ? '<p class="hint">' + TB.cardPackOnly + '</p>' : '') +
          '<button class="btn pri big" type="button" id="bf-pay">' + (isCard ? TB.cardGo + ' ' + usdN(pk.usd) : TB.pay + ' ' + fmtN(pk.xof) + ' FCFA') + '</button>' +
          '<p class="fmsg" id="bf-msg" role="status" aria-live="polite"></p></div>';
        modal.querySelector('.x').onclick = closeM;
        Array.prototype.forEach.call(modal.querySelectorAll('.pack'), function (b) { b.onclick = function () { sel.pack = b.dataset.p; draw(); }; });
        Array.prototype.forEach.call(modal.querySelectorAll('[data-m]'), function (b) { b.onclick = function () { sel.method = b.dataset.m; draw(); }; });
        var sn = modal.querySelector('[data-soon]'); if (sn) sn.onclick = function () { bmsg(TB.cardSoon, true); };
        var co = modal.querySelector('#bf-country'); if (co) co.onchange = function (e) { sel.country = e.target.value; sel.op = null; draw(); };
        var opEl = modal.querySelector('#bf-op'); if (opEl) opEl.onchange = function (e) { sel.op = ops().filter(function (o) { return o.code === e.target.value; })[0]; draw(); };
        var tc = modal.querySelector('#bf-terms'); if (tc) tc.onchange = function (e) { sel.terms = e.target.checked; var t = modal.querySelector('.terms'); if (t) t.classList.remove('err'); };
        var payBtn = modal.querySelector('#bf-pay'); if (payBtn) payBtn.onclick = isCard ? payCard : pay;
      }
      function trackPay(orderId, btn, total) {
        var tries = 0; bmsg(total ? TB.validate.replace('{a}', fmtN(total) + ' FCFA') : TB.waitPay, true);
        ptimer = setInterval(function () {
          tries++;
          window.slashAuth.call('pay/status', { orderId: orderId }).then(function (s) {
            if (s.status !== 200) return;
            if (s.data.status === 'paid') {
              clearInterval(ptimer);
              bmsg(TB.paid, true);
              if (window.saTrack) window.saTrack('film_pay_done', { f: 'film', m: sel.method });
              refreshBalance(function () { setTimeout(closeM, 1200); });
            }
            else if (s.data.status === 'failed') { clearInterval(ptimer); busyB(btn, false); bmsg(TB.payFailed); }
          });
          if (tries > 60) { clearInterval(ptimer); busyB(btn, false); bmsg(TB.payFailed); }
        }, 4000);
      }
      function pay() {
        var btn = modal.querySelector('#bf-pay');
        var phoneEl = modal.querySelector('#bf-phone'); var phone = phoneEl ? phoneEl.value.replace(/\D/g, '') : '';
        var otpEl = modal.querySelector('#bf-otp'); var otp = sel.op.otp ? (otpEl ? otpEl.value.trim() : '') : '';
        if (phone.length < 8) return bmsg(TB.e.bad_phone);
        if (sel.op.otp && !otp) return bmsg(TB.e.otp_required);
        if (!sel.terms) { flagT(); return bmsg(TB.e.terms_required); }
        busyB(btn, true); bmsg(TB.paying, true);
        if (window.saTrack) window.saTrack('film_pay_start', { f: 'film', m: 'mm', pack: sel.pack });
        window.slashAuth.call('pay/start', { packId: sel.pack, operator: sel.op.code, phone: phone, otp: otp, terms: cfg.termsVersion }).then(function (r) {
          if (r.status !== 200) { busyB(btn, false); return bmsg(errT(r.data && r.data.error)); }
          if (r.data.paymentUrl) { var a = document.createElement('a'); a.href = r.data.paymentUrl; a.target = '_blank'; a.rel = 'noopener'; a.textContent = TB.openPay; a.className = 'btn gl'; var mEl = modal.querySelector('#bf-msg'); if (mEl) mEl.after(a); }
          trackPay(r.data.orderId, btn, r.data.total);
        }).catch(function () { busyB(btn, false); bmsg(TB.e.server); });
      }
      function payCard() {
        var btn = modal.querySelector('#bf-pay');
        var v = function (id) { var el = modal.querySelector('#' + id); return el ? (el.value || '').trim() : ''; };
        var body = { packId: sel.pack, firstName: v('bf-cfirst'), lastName: v('bf-clast'), phone: v('bf-cphone'), city: v('bf-ccity'), zip: v('bf-czip'), country: (modal.querySelector('#bf-ccountry') || {}).value || '', terms: cfg.termsVersion };
        if (!sel.terms) { flagT(); return bmsg(TB.e.terms_required); }
        if (!body.firstName || !body.lastName || !body.city || !body.zip || body.phone.replace(/\D/g, '').length < 8) return bmsg(TB.e.bad_card_info);
        busyB(btn, true); bmsg(TB.paying, true);
        if (window.saTrack) window.saTrack('film_pay_start', { f: 'film', m: 'card', pack: sel.pack });
        window.slashAuth.call('pay/card', body).then(function (r) {
          if (r.status !== 200) { busyB(btn, false); return bmsg(errT(r.data && r.data.error)); }
          try { localStorage.setItem('sa_pending', r.data.orderId); } catch (e) {}
          location.href = r.data.paymentUrl;
        }).catch(function () { busyB(btn, false); bmsg(TB.e.server); });
      }
      draw();
    });
  }

  // ── Progression ───────────────────────────────────────────────────────────────
  function showProgress(step) {
    var res = $('#film-result');
    if (!res) return;
    res.hidden = false;
    var genAd = document.getElementById('film-gen-ad');
    if (genAd && genAd.hidden) { genAd.hidden = false; if (window.saAds) window.saAds.late(); }
    var labels = [T.steps[0], T.steps[1], T.steps[2]];
    var html = '<div class="film-progress"><div class="film-progress-steps">';
    for (var i = 0; i < 3; i++) {
      var cls = i < step ? 'done' : i === step && step < 3 ? 'active' : '';
      var icon = i < step ? '✓' : (i === step && step < 3 ? '⏳' : '○');
      html += '<div class="film-ps ' + cls + '"><span class="film-ps-icon">' + icon + '</span>' + labels[i] + '</div>';
    }
    html += '</div>';
    if (step < 3) html += '<p class="hint">' + T.wait + '</p>';
    html += '</div>';
    res.innerHTML = html;
  }

  function showDone(videoUrl, episodeNumber) {
    if (window.saTrack) window.saTrack('film_done', { f: 'film', ep: episodeNumber || 0 });
    var genAd = document.getElementById('film-gen-ad');
    if (genAd) genAd.hidden = true;
    var res = $('#film-result');
    if (!res) return;
    var epBadge = episodeNumber ? '<span class="film-ep-badge">' + T.episodeBadge + ' ' + episodeNumber + '</span>' : '';
    res.innerHTML = '<div class="film-result-card">' + epBadge + '<h3>' + T.done + '</h3><video src="' + videoUrl + '" controls playsinline></video><a class="btn pri" href="' + videoUrl + '" download>' + T.download + '</a></div>';
    // Rafraîchir la liste des séries après un épisode généré
    if (currentSeriesId) loadSeriesList();
  }

  function errText(code) { return (T.e && T.e[code]) || T.err; }
  function showErr(msg) {
    var genAd = document.getElementById('film-gen-ad');
    if (genAd) genAd.hidden = true;
    var msg2 = $('#film-msg');
    if (msg2) { msg2.textContent = (msg ? errText(msg) : T.err); msg2.className = 'fmsg'; }
    var sub = $('#film-submit');
    if (sub) { sub.disabled = false; sub.textContent = isFr ? 'Réessayer' : 'Retry'; }
  }

  // ── Polling ───────────────────────────────────────────────────────────────────
  function poll(jobId) {
    window.slashAuth.call('studio-film/status', { jobId: jobId }).then(function (r) {
      if (!r || r.status !== 200) { showErr(); return; }
      var d = r.data;
      if (d.status === 'done') {
        clearTimeout(pollTimer);
        showDone(d.videoUrl, d.episodeNumber);
      } else if (d.status === 'error') {
        clearTimeout(pollTimer);
        showErr(d.message || T.err);
      } else if (d.status === 'rendering') {
        showProgress(1);
        pollTimer = setTimeout(function () { poll(jobId); }, 8000);
      } else if (d.status === 'assembling') {
        showProgress(2);
        pollTimer = setTimeout(function () { poll(jobId); }, 6000);
      } else if (d.status === 'pending_render') {
        showProgress(1);
        pollTimer = setTimeout(function () { poll(jobId); }, 10000);
      } else {
        showProgress(0);
        pollTimer = setTimeout(function () { poll(jobId); }, 8000);
      }
    }).catch(function () {
      pollTimer = setTimeout(function () { poll(jobId); }, 10000);
    });
  }

  // ── Watermark + dur toggles ───────────────────────────────────────────────────
  var wmChk = $('#film-watermark');
  if (wmChk) {
    wmChk.addEventListener('change', recalcCostAndWarn);
    document.querySelectorAll('input[name="dur"]').forEach(function (r) { r.addEventListener('change', recalcCostAndWarn); });
    recalcCost();
  }

  // ── Mise à jour du mode série (champs série/épisode) ─────────────────────────
  var genreChgEl = $('#film-genre');
  if (genreChgEl) genreChgEl.addEventListener('change', updateSerieMode);

  // ── Toggle audio : affiche/masque le sélecteur de fichier ────────────────────
  var audioToggleEl = document.getElementById('film-audio-toggle');
  var audioWrapEl = document.getElementById('film-audio-wrap');
  if (audioToggleEl && audioWrapEl) {
    audioToggleEl.addEventListener('change', function () {
      audioWrapEl.hidden = !audioToggleEl.checked;
      if (!audioToggleEl.checked) {
        uploadedAudioPath = null;
        var nameEl = document.getElementById('film-audio-name');
        if (nameEl) nameEl.textContent = '';
      }
      recalcCostAndWarn();
    });
  }

  // ── Import audio ─────────────────────────────────────────────────────────────
  var audioInput = document.getElementById('film-audio-input');
  if (audioInput) {
    audioInput.addEventListener('change', function () {
      var file = audioInput.files && audioInput.files[0];
      var nameEl = document.getElementById('film-audio-name');
      var sub = $('#film-submit');
      if (!file) { uploadedAudioPath = null; if (nameEl) nameEl.textContent = ''; recalcCost(); return; }
      if (nameEl) nameEl.textContent = isFr ? 'Envoi en cours…' : 'Uploading…';
      if (sub) sub.disabled = true;
      var ct = file.type || 'audio/mpeg';
      window.slashAuth.call('studio-film/upload-url', { contentType: ct }).then(function (r) {
        if (!r || r.status !== 200 || !r.data || !r.data.uploadUrl) {
          uploadedAudioPath = null;
          if (nameEl) nameEl.textContent = isFr ? 'Erreur d\'envoi' : 'Upload error';
          if (sub) sub.disabled = false;
          return;
        }
        return fetch(r.data.uploadUrl, { method: 'PUT', body: file, headers: { 'Content-Type': ct } })
          .then(function (res) {
            if (!res.ok) throw new Error('http ' + res.status);
            uploadedAudioPath = r.data.storagePath;
            if (nameEl) nameEl.textContent = file.name;
            recalcCost();
            if (sub) sub.disabled = false;
          });
      }).catch(function () {
        uploadedAudioPath = null;
        if (nameEl) nameEl.textContent = isFr ? 'Erreur d\'envoi' : 'Upload error';
        if (sub) sub.disabled = false;
      });
    });
  }

  // ── Soumission du formulaire ──────────────────────────────────────────────────
  var form = $('#film-form');
  if (form) {
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var sub = $('#film-submit');
      var msg = $('#film-msg');
      if (msg) { msg.textContent = ''; msg.className = 'fmsg'; }
      sub.disabled = true;
      sub.textContent = T.creating;
      showProgress(0);
      if (window.saTrack) window.saTrack('film_start', { f: 'film', dur: (document.querySelector('input[name="dur"]:checked') || {}).value || '2', genre: ($('#film-genre') || {}).value || '' });

      var dur = document.querySelector('input[name="dur"]:checked');
      var wmEl = document.getElementById('film-watermark');
      var payload = {
        title: ($('#film-title') || {}).value || '',
        synopsis: ($('#film-synopsis') || {}).value || '',
        genre: ($('#film-genre') || {}).value || 'film',
        lang: ($('#film-lang') || {}).value || lang,
        duration: dur ? +dur.value : 2,
        watermark: wmEl ? wmEl.checked : true,
      };
      var serieFieldsEl = document.getElementById('film-serie-fields');
      if (serieFieldsEl && !serieFieldsEl.hidden) {
        var stEl = document.getElementById('film-series-title');
        var ssEl = document.getElementById('film-series-synopsis');
        if (stEl && stEl.value.trim()) payload.seriesTitle = stEl.value.trim();
        if (ssEl && ssEl.value.trim()) payload.seriesSynopsis = ssEl.value.trim();
      }
      if (uploadedAudioPath) payload.customAudioPath = uploadedAudioPath;
      if (currentSeriesId) payload.seriesId = currentSeriesId;

      window.slashAuth.call('studio-film/create', payload).then(function (r) {
        if (!r) { showErr(); sub.disabled = false; return; }
        if (r.status === 402) {
          sub.disabled = false;
          sub.textContent = isFr ? 'Créer mon film' : 'Create my film';
          if (window.saTrack) window.saTrack('film_nocredit', { f: 'film' });
          openCredModal();
          return;
        }
        if (r.status !== 200) { showErr(r.data && r.data.error); sub.disabled = false; return; }
        var jobId = r.data && r.data.jobId;
        // Sauvegarder le seriesId retourné si c'est une série
        if (r.data && r.data.seriesId) currentSeriesId = r.data.seriesId;
        if (!jobId) { showErr(); sub.disabled = false; return; }
        // Réinitialiser l'audio après soumission
        uploadedAudioPath = null;
        if (audioInput) { audioInput.value = ''; }
        var nameEl2 = document.getElementById('film-audio-name');
        if (nameEl2) nameEl2.textContent = '';
        var tog2 = document.getElementById('film-audio-toggle');
        var wrap2 = document.getElementById('film-audio-wrap');
        if (tog2) { tog2.checked = false; }
        if (wrap2) { wrap2.hidden = true; }
        pollTimer = setTimeout(function () { poll(jobId); }, 5000);
      }).catch(function () { showErr(); sub.disabled = false; });
    });
  }

  // ── Séries : chargement et affichage ─────────────────────────────────────────
  function loadSeriesList() {
    var wrap = document.getElementById('film-series-wrap');
    if (!wrap) return;
    window.slashAuth.call('studio-film/series', {}).then(function (r) {
      if (!r || r.status !== 200 || !r.data) return;
      var series = r.data.series || [];
      if (!series.length) {
        wrap.innerHTML = '<p class="film-series-empty">' + T.seriesEmpty + '</p>';
        return;
      }
      var html = '<div class="film-series-grid">';
      series.forEach(function (s) {
        var epLabel = s.episodeCount === 1 ? '1 ' + T.seriesEp : s.episodeCount + ' ' + T.seriesEps;
        var synopsis = s.synopsis ? s.synopsis.slice(0, 120) + (s.synopsis.length > 120 ? '…' : '') : '';
        html +=
          '<div class="film-series-card" data-sid="' + s.id + '" data-title="' + esc(s.title) + '" data-synopsis="' + esc(s.synopsis) + '" data-genre="serie" data-dur="' + s.duration + '">' +
            '<div class="film-series-top">' +
              '<b class="film-series-name">' + esc(s.title) + '</b>' +
              '<span class="film-series-ep-badge">' + epLabel + '</span>' +
            '</div>' +
            (synopsis ? '<p class="film-series-synopsis">' + esc(synopsis) + '</p>' : '') +
            (s.characters && s.characters.length ? '<p class="film-series-chars">👤 ' + s.characters.slice(0, 4).map(esc).join(', ') + '</p>' : '') +
            '<button class="btn sec film-series-btn" type="button">' + T.seriesContinue + '</button>' +
          '</div>';
      });
      html += '</div>';
      wrap.innerHTML = html;
      wrap.querySelectorAll('.film-series-btn').forEach(function (btn) {
        btn.addEventListener('click', function () {
          var card = btn.closest('.film-series-card');
          selectSeries(card.dataset.sid, card.dataset.title, card.dataset.synopsis, card.dataset.genre, card.dataset.dur);
        });
      });
    }).catch(function () {});
  }

  function selectSeries(sid, title, synopsis, genre, dur) {
    currentSeriesId = sid;
    // Pré-remplir : garder le titre de la série mais laisser l'utilisateur saisir le titre de l'épisode
    var titleEl = $('#film-title');
    var synopsisEl = $('#film-synopsis');
    var genreEl = $('#film-genre');
    var durEl = document.querySelector('input[name="dur"][value="' + dur + '"]');
    if (titleEl) titleEl.value = '';  // titre de l'épisode à saisir
    if (synopsisEl) synopsisEl.value = synopsis || '';
    if (genreEl) genreEl.value = 'serie';
    if (durEl) durEl.checked = true;
    // Indicateur série sélectionnée
    var badge = document.getElementById('film-series-badge');
    if (badge) {
      badge.textContent = isFr ? '📺 Suite de : ' + title : '📺 Continuing: ' + title;
      badge.hidden = false;
    }
    var resetBtn = document.getElementById('film-series-reset');
    if (resetBtn) resetBtn.hidden = false;
    // Marquer la carte sélectionnée
    document.querySelectorAll('.film-series-card').forEach(function (c) { c.classList.toggle('selected', c.dataset.sid === sid); });
    // Scroll vers le formulaire
    var formEl = $('#film-form');
    if (formEl) formEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
    // Mettre à jour le label du bouton
    var sub = $('#film-submit');
    if (sub) sub.textContent = isFr ? 'Générer l\'épisode suivant' : 'Generate next episode';
    updateSerieMode();
  }

  // Bouton reset série
  var resetBtn = document.getElementById('film-series-reset');
  if (resetBtn) {
    resetBtn.addEventListener('click', function () {
      currentSeriesId = null;
      resetBtn.hidden = true;
      var badge = document.getElementById('film-series-badge');
      if (badge) badge.hidden = true;
      document.querySelectorAll('.film-series-card').forEach(function (c) { c.classList.remove('selected'); });
      var sub = $('#film-submit');
      if (sub) sub.textContent = isFr ? 'Créer mon film' : 'Create my film';
      updateSerieMode();
    });
  }

  function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  // ── Cartes d'inspiration ──────────────────────────────────────────────────────
  document.querySelectorAll('.film-idea-card').forEach(function (btn) {
    btn.addEventListener('click', function () {
      currentSeriesId = null;
      var titleEl = $('#film-title');
      var synopsisEl = $('#film-synopsis');
      var genreEl = $('#film-genre');
      var durEl = document.querySelector('input[name="dur"][value="' + btn.dataset.dur + '"]');
      if (titleEl) titleEl.value = btn.dataset.title;
      if (synopsisEl) synopsisEl.value = btn.dataset.synopsis;
      if (genreEl) genreEl.value = btn.dataset.genre;
      if (durEl) durEl.checked = true;
      updateSerieMode();
      document.querySelectorAll('.film-idea-card').forEach(function (b) { b.classList.remove('selected'); });
      btn.classList.add('selected');
      // Reset badge série si on clique une idée
      var badge = document.getElementById('film-series-badge');
      if (badge) badge.hidden = true;
      var rst = document.getElementById('film-series-reset');
      if (rst) rst.hidden = true;
      var formEl = $('#film-form');
      if (formEl && !formEl.hidden) {
        formEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
      } else {
        var formWrap = document.getElementById('film-out');
        if (formWrap) formWrap.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });

  // ── Auth ──────────────────────────────────────────────────────────────────────
  document.addEventListener('sa:auth', function (e) {
    var u = e.detail.user;
    var wall = $('#film-login-wall');
    var frm = $('#film-form');
    var seriesSection = document.getElementById('film-series-section');
    if (wall) wall.hidden = !!u;
    if (frm) frm.hidden = !u;
    if (seriesSection) seriesSection.hidden = !u;
    if (u) { loadSeriesList(); refreshBalance(); }
  });
})();
