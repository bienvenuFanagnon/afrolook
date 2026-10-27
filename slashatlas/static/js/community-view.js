// Pages d'une commande communautaire et d'un profil de créateur : partage du lien (avec le parrainage de la personne connectée) et copie d'une commande gratuite.
(function () {
  'use strict';
  var lang = document.body.dataset.lang === 'en' ? 'en' : 'fr';
  var data = {}; try { data = JSON.parse(document.getElementById('cdata').textContent); } catch (e) {}
  var T = { fr: { copied: 'Lien copié ✓', share: 'Partager', text: 'Découvre cette commande sur SlashAtlas :' }, en: { copied: 'Link copied ✓', share: 'Share', text: 'Check out this command on SlashAtlas:' } }[lang];
  var refCode = '';
  var url = function () { return 'https://slashatlas.com' + location.pathname + (refCode ? '?ref=' + refCode : ''); };

  var sh = document.getElementById('cv-share');
  if (sh) sh.addEventListener('click', function () {
    var u = url(), done = function () { sh.textContent = T.copied; setTimeout(function () { sh.textContent = sh.dataset.label; }, 1800); };
    sh.dataset.label = sh.dataset.label || sh.textContent;
    if (navigator.share) { navigator.share({ title: document.title, text: T.text, url: u }).catch(function () {}); return; }
    try { navigator.clipboard.writeText(u).then(done, function () { window.prompt('', u); }); } catch (e) { window.prompt('', u); }
  });

  var cp = document.getElementById('cv-copy'), pre = document.getElementById('cv-prompt');
  if (cp && pre) cp.addEventListener('click', function () {
    var txt = pre.textContent, label = cp.textContent, done = function () { cp.textContent = cp.dataset.done || '✓'; setTimeout(function () { cp.textContent = label; }, 1800); };
    try { navigator.clipboard.writeText(txt).then(done, function () { var r = document.createRange(); r.selectNodeContents(pre); var s = getSelection(); s.removeAllRanges(); s.addRange(r); document.execCommand('copy'); done(); }); } catch (e) { /* sélection manuelle */ }
    try { document.dispatchEvent(new CustomEvent('sa:copied', { detail: { slug: 'u-' + (data.id || '') } })); } catch (e) { /* facultatif */ }
    try { fetch('/api/event', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ t: 'copy', s: 'u-' + (data.id || '') }) }); } catch (e) { /* mesure facultative */ }
  });

  // commande payante : le texte est livré par le serveur contre 1 crédit (acheté), une seule fois par personne ; il revient au créateur
  var buy = document.getElementById('cv-buy'), out = document.getElementById('cv-unlocked');
  var M = { fr: { login: 'Connectez-vous pour débloquer', purchased_required: 'Il faut avoir acheté des crédits pour débloquer une commande payante.', insufficient_credits: 'Crédits insuffisants.', daily_limit: 'Limite de copies du jour atteinte.', server: 'Une erreur est survenue. Réessayez.', copy: 'Copier la commande', copied: 'Copié ✓' }, en: { login: 'Sign in to unlock', purchased_required: 'You need to have bought credits to unlock a paid command.', insufficient_credits: 'Not enough credits.', daily_limit: 'Daily copy limit reached.', server: 'Something went wrong. Please try again.', copy: 'Copy the command', copied: 'Copied ✓' } }[lang];
  if (buy) buy.addEventListener('click', function () {
    var msg = document.getElementById('cv-msg'); msg.textContent = '';
    if (!window.slashAuth || !window.slashAuth.user) { if (window.slashAuth) window.slashAuth.login(); else msg.textContent = M.login; return; }
    buy.disabled = true;
    window.slashAuth.call('community/copy', { id: data.id }).then(function (r) {
      buy.disabled = false;
      if (r.status !== 200) { msg.textContent = M[r.data && r.data.error] || M.server; return; }
      var txt = lang === 'en' ? r.data.en : r.data.fr;
      out.hidden = false; out.querySelector('pre').textContent = txt; buy.hidden = true;
      var c = out.querySelector('button'); try { document.dispatchEvent(new CustomEvent('sa:copied', { detail: { slug: 'u-' + (data.id || '') } })); } catch (e) { /* débloquée : on demande tout de suite */ } c.addEventListener('click', function () { try { navigator.clipboard.writeText(txt).then(function () { c.textContent = M.copied; setTimeout(function () { c.textContent = M.copy; }, 1800); }); } catch (e) {} });
    }).catch(function () { buy.disabled = false; msg.textContent = M.server; });
  });

  // le lien partagé par une personne connectée porte son code de parrainage
  import('/js/auth.js');
  document.addEventListener('sa:auth', function (e) {
    if (!e.detail.user || !window.slashAuth) return;
    window.slashAuth.call('referrals').then(function (r) { if (r.status === 200 && r.data && r.data.code) refCode = r.data.code; }).catch(function () {});
  });
})();
