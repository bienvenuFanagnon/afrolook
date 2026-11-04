(function () {
  'use strict';
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  // menu mobile
  var burger = $('#burger'), drawer = $('#drawer');
  if (burger && drawer) {
    burger.addEventListener('click', function () {
      var open = drawer.classList.toggle('open');
      burger.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    $$('a', drawer).forEach(function (a) { a.addEventListener('click', function () { drawer.classList.remove('open'); burger.setAttribute('aria-expanded', 'false'); }); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') { drawer.classList.remove('open'); burger.setAttribute('aria-expanded', 'false'); } });
  }

  // vitrine des cartes : familles et miniatures
  var show = $('[data-showcase]');
  if (show) {
    var big = $('#big', show), name = $('#capname', show), sub = $('#capsub', show);
    var pick = function (btn) {
      big.src = btn.dataset.src; big.alt = btn.dataset.name; name.textContent = btn.dataset.name; sub.textContent = btn.dataset.sub;
      $$('.thumbs button', show).forEach(function (b) { b.setAttribute('aria-pressed', b === btn ? 'true' : 'false'); });
    };
    $$('.thumbs button', show).forEach(function (b) { b.addEventListener('click', function () { pick(b); }); });
    $$('.tabs button', show).forEach(function (t) {
      t.addEventListener('click', function () {
        $$('.tabs button', show).forEach(function (x) { x.setAttribute('aria-selected', x === t ? 'true' : 'false'); });
        $$('.thumbs', show).forEach(function (g) { g.hidden = g.dataset.pack !== t.dataset.pack; });
        var first = $('.thumbs[data-pack="' + t.dataset.pack + '"] button', show);
        if (first) pick(first);
      });
    });
  }

  // copier l'adresse e-mail
  var copy = $('#copymail');
  if (copy) {
    copy.addEventListener('click', function () {
      var t = $('#mailtxt'), done = copy.dataset.done, label = copy.dataset.label;
      var ok = function () { copy.textContent = done; setTimeout(function () { copy.textContent = label; }, 1800); };
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(t.textContent).then(ok, function () { sel(t); });
      else sel(t);
      function sel(el) { var r = document.createRange(); r.selectNodeContents(el); var s = getSelection(); s.removeAllRanges(); s.addRange(r); }
    });
  }

  // formulaire de contact
  var form = $('#contact-form');
  if (form) {
    var status = $('.status', form), btn = $('button[type=submit]', form);
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var d = {
        name: form.name.value.trim(), email: form.email.value.trim(), subject: form.subject.value,
        message: form.message.value.trim(), website: form.website.value, lang: form.dataset.lang
      };
      status.className = 'status';
      if (d.name.length < 2 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(d.email) || d.message.length < 10) { status.textContent = form.dataset.invalid; status.className = 'status err'; return; }
      btn.disabled = true; status.textContent = form.dataset.sending;
      fetch(form.dataset.endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d) })
        .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
        .then(function () { status.textContent = form.dataset.ok; status.className = 'status ok'; form.reset(); })
        .catch(function () { status.innerHTML = ''; status.appendChild(document.createTextNode(form.dataset.err + ' ')); var a = document.createElement('a'); a.href = 'mailto:' + form.dataset.mail; a.textContent = form.dataset.mail; status.appendChild(a); status.className = 'status err'; })
        .then(function () { btn.disabled = false; });
    });
  }

  // audience du réseau Afrolook Ads : UN seul chiffre pour tout le site, lu sur l'API (50 000 sur nos plateformes + l'audience retenue des diffuseurs validés, arrondie au millier inférieur)
  var auds = $$('[data-aud]'), audApi = $('meta[name="afl-audience-api"]');
  if (auds.length && audApi) {
    var en = document.documentElement.lang === 'en';
    fetch(audApi.content).then(function (r) { return r.json(); }).then(function (a) {
      var t = Math.floor(Number(a.total) / 1000) * 1000;
      if (!(t >= 50000)) return;
      var txt = (en ? 'over ' : 'plus de ') + t.toLocaleString(en ? 'en-US' : 'fr-FR');
      auds.forEach(function (el) { el.textContent = txt; });
    }).catch(function () { /* le chiffre écrit dans la page reste affiché */ });
  }

  // page de téléchargement : envoie vers la bonne boutique
  var play = $('meta[name="afrolook-play"]'), ios = $('meta[name="afrolook-ios"]');
  if (play && ios) {
    var ua = navigator.userAgent || '';
    var isIos = /iPhone|iPad|iPod/i.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    var target = isIos ? ios.content : (/Android/i.test(ua) ? play.content : null);
    if (target) { var r = $('#redir'); if (r) r.style.display = 'block'; setTimeout(function () { location.replace(target); }, 700); }
  }
})();
