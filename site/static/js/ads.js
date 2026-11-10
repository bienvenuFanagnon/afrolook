// Afrolook Ads : galerie publique des annonces en ligne (page /ads/) et espace annonceur (page /ads/espace/).
// Aucune donnée n'est insérée comme HTML : tout passe par textContent (les annonces viennent d'annonceurs).
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
function h(tag, attrs = {}, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) { if (v === false || v == null) continue; if (k === 'class') e.className = v; else if (k === 'text') e.textContent = v; else if (typeof v === 'function') e.addEventListener(k.replace(/^on/, ''), v); else e.setAttribute(k, v === true ? '' : v); }
  for (const c of kids.flat()) if (c != null) e.append(c.nodeType ? c : document.createTextNode(String(c)));
  return e;
}
const EN = document.documentElement.lang === 'en'; // page anglaise : vues et boutons traduits
const n = (v) => Number(v || 0).toLocaleString(EN ? 'en-US' : 'fr-FR');
/** Carte de chiffre clé : libellé, valeur, précision, ton (ok, wait, alert), clic facultatif. */
const kpiCard = (label, value, sub, tone, onclick) => h(onclick ? 'button' : 'div', { class: 'adk' + (tone ? ' ' + tone : '') + (onclick ? ' clk' : ''), type: onclick ? 'button' : false, onclick: onclick || false },
  h('small', { text: label }), h('b', { text: value }), h('span', { text: sub || '\u00a0' }));
const pct = (a, b) => (b > 0 ? (a / b * 100).toFixed(1).replace('.', ',') + ' %' : '—');
const VUES = EN ? 'views' : 'vues';
const ACT = (s) => (EN ? ({ Visiter: 'Visit', 'Télécharger': 'Download', 'En savoir plus': 'Learn more', Appeler: 'Call' }[s] || s) : s);
let IS_ADMIN = false; // compte de l'équipe de la régie
let IS_OFFERED = false; // équipe d'argent : ses annonces et campagnes sont offertes (aucun débit du solde)
const safeUrl = (u) => { try { const x = new URL(u); return x.protocol === 'https:' || x.protocol === 'tel:' ? x.href : ''; } catch { return ''; } };

// ───────── messages : fenêtre modale claire, fermée par la personne elle-même (un message en haut de page se perdait dès qu'on avait défilé) ─────────
//  - erreur : le problème expliqué en français ; on la ferme avec le bouton (ou Échap), jamais toute seule
//  - succès : même fenêtre, en vert ; elle se ferme aussi d'un clic à côté et ne bloque rien (la page continue de se mettre à jour derrière)
let msgDlg = null;
const MISSING = /^(Ajoute|Choisis|Écris|Indique|Décris|Explique|Présente|Coche|Patiente|Crée d|Avant ta|Complète)/;
function showMessage(kind, message, title) {
  const msg = String(message || '').trim(); if (!msg) return;
  if (!msgDlg) {
    const ic = h('i', { class: 'amdlg-ic', 'aria-hidden': 'true' }), t = h('h2', { id: 'amdlg-t' }), m = h('p', { class: 'amdlg-msg', id: 'amdlg-m' });
    const b = h('button', { class: 'btn btn-primary adbig', type: 'button', onclick: () => msgDlg.close() });
    msgDlg = h('dialog', { class: 'amdlg', 'aria-labelledby': 'amdlg-t', 'aria-describedby': 'amdlg-m' }, h('div', { class: 'amdlg-in' }, ic, t, m, b));
    Object.assign(msgDlg, { _ic: ic, _t: t, _m: m, _b: b });
    msgDlg.addEventListener('click', (e) => { if (e.target === msgDlg && msgDlg.dataset.kind === 'success') msgDlg.close(); });   // un clic à côté ferme un succès, jamais une erreur
    msgDlg.addEventListener('close', () => { if (!msgDlg.open) delete msgDlg.dataset.kind; });   // l'événement arrive après la fermeture : ne pas effacer le type d'un message déjà rouvert
    document.body.append(msgDlg);
  }
  const d = msgDlg, bad = kind === 'error';
  if (d.open && d.dataset.kind === 'error' && !bad) return;   // un succès ne recouvre pas une erreur encore à lire
  if (d.open && d.dataset.kind === kind) { if (!d._m.textContent.includes(msg) && d._m.textContent.length < 700) d._m.textContent += '\n\n' + msg; }   // plusieurs messages d'affilée : ils s'ajoutent
  else {
    d._m.textContent = msg; d.dataset.kind = kind; d.setAttribute('role', bad ? 'alertdialog' : 'dialog');
    d._ic.textContent = bad ? '!' : '✓';
    d._t.textContent = title || (bad ? (MISSING.test(msg) ? (EN ? 'Something is missing' : 'Il manque une information') : (EN ? 'Something went wrong' : 'Un problème est survenu')) : (EN ? 'Done' : 'C’est fait'));
    d._b.textContent = bad ? (EN ? 'Got it' : 'J’ai compris') : (EN ? 'Close' : 'Fermer');
  }
  if (!d.open) d.showModal();
  d._b.focus();
}
const showError = (message, title) => showMessage('error', message, title);
const showSuccess = (message, title) => showMessage('success', message, title);
/** Explication simple d'une erreur technique (réseau, session, droits, envoi de fichier) ; sinon le texte de repli donné par l'appelant. */
function friendly(e, fallback) {
  const m = String((e && e.message) || ''), c = String((e && e.code) || '');
  if (c === 'functions/unavailable' || /^réseau$|failed to fetch|networkerror|load failed/i.test(m)) return 'Impossible de joindre le serveur. Vérifie ta connexion internet, puis réessaie.';
  if (c === 'functions/unauthenticated' || /unauthenticated/i.test(m)) return 'Ta connexion a expiré. Recharge la page et reconnecte-toi avec Google.';
  if (c === 'functions/permission-denied') return 'Ce compte n’a pas le droit de faire cette action.';
  if (/trop_vite/.test(m)) return 'Tu vas trop vite : attends quelques secondes, puis réessaie.';
  if (/^envoi (refusé|échoué|non confirmé)/.test(m)) return 'L’envoi du fichier a échoué. Vérifie ta connexion et que le fichier est bien une image (PNG, JPG ou WebP), puis réessaie.';
  return fallback;
}

// ───────── fenêtre de détail d'une annonce (galerie publique et « Mes annonces ») ─────────
const dlg = $('#addetail');
const closeDetail = () => { if (dlg && dlg.open) dlg.close(); };
if (dlg) {
  $('#addetail-x').addEventListener('click', closeDetail);
  dlg.addEventListener('click', (e) => { if (e.target === dlg) closeDetail(); }); // clic à côté de la fenêtre
  dlg.addEventListener('close', () => { if (location.hash.startsWith('#annonce-')) history.replaceState(null, '', location.pathname + location.search); });
}
const initial = (a) => (a.title || 'A').trim().charAt(0).toUpperCase();

// ───────── pays : tous les pays du monde (codes ISO 3166-1), noms dans la langue de la page ─────────
const ISO_COUNTRIES = 'AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW'.split(' ');
const AFRICA_CODES = 'DZ AO BJ BW BF BI CM CV CF TD KM CG CD CI DJ EG GQ ER SZ ET GA GM GH GN GW KE LS LR LY MG MW ML MR MU MA MZ NA NE NG RW ST SN SC SL SO ZA SS SD TZ TG TN UG ZM ZW EH'.split(' ');
const countryName = (() => { let dn = null; try { dn = new Intl.DisplayNames([EN ? 'en' : 'fr'], { type: 'region' }); } catch { /* ancien navigateur : le code est affiché */ } return (c) => { try { return (dn && dn.of(c)) || c; } catch { return c; } }; })();
const sortedCountries = () => ISO_COUNTRIES.map((c) => [c, countryName(c)]).sort((a, b) => a[1].localeCompare(b[1], EN ? 'en' : 'fr'));
/** Sélection multiple de pays : pastilles retirables, liste (Afrique puis autres pays) pour en ajouter, « Toute l'Afrique » et « Tous les pays ». Lit et modifie l'ensemble rendu par get(). */
function countryPick(root, get) {
  const AFR = new Set(AFRICA_CODES);
  const render = () => {
    const set = get(), names = sortedCountries(), picked = names.filter(([c]) => set.has(c)), free = names.filter(([c]) => !set.has(c));
    const chips = h('div', { class: 'catpick-chips' });
    if (!picked.length) chips.append(h('span', { class: 'catpick-none', text: 'Aucun pays choisi : ajoute au moins un pays.' }));
    for (const [c, nm] of picked.slice(0, 24)) chips.append(h('span', { class: 'catpick-chip' }, nm, h('button', { type: 'button', 'aria-label': 'Retirer ' + nm, text: '×', onclick: () => { set.delete(c); render(); } })));
    if (picked.length > 24) chips.append(h('span', { class: 'catpick-none', text: `+ ${picked.length - 24} autres pays` }));
    const sel = h('select', { class: 'catpick-add', 'aria-label': 'Ajouter un pays' }, h('option', { value: '', text: '+ Ajouter un pays…' }),
      h('optgroup', { label: 'Afrique' }, ...free.filter(([c]) => AFR.has(c)).map(([c, nm]) => h('option', { value: c, text: nm }))),
      h('optgroup', { label: 'Autres pays' }, ...free.filter(([c]) => !AFR.has(c)).map(([c, nm]) => h('option', { value: c, text: nm }))));
    sel.addEventListener('change', () => { if (sel.value) { set.add(sel.value); render(); } });
    const act = h('div', { class: 'catpick-act' },
      h('button', { type: 'button', class: 'catpick-link', text: 'Toute l\u2019Afrique', onclick: () => { AFRICA_CODES.forEach((c) => set.add(c)); render(); } }),
      h('button', { type: 'button', class: 'catpick-link', text: 'Tous les pays', onclick: () => { ISO_COUNTRIES.forEach((c) => set.add(c)); render(); } }),
      picked.length ? h('button', { type: 'button', class: 'catpick-link', text: 'Tout retirer', onclick: () => { set.clear(); render(); } }) : null);
    root.replaceChildren(h('div', { class: 'catpick-grp' }, chips, sel, act));
  };
  render();
  return render;
}

/** Sélection multiple des catégories d'annonces : les catégories retenues sont des pastilles (× pour retirer), une liste déroulante sert à en ajouter.
 *  Les vraies cases (cachées, dans `.catpick-store`) gardent la valeur : le formulaire les lit avec `input:checked`, comme avant. */
const CAT_GROUPS = {
  standard: { title: 'Catégories courantes', note: 'toutes acceptées au départ : retire celles que tu ne veux pas', none: 'Aucune catégorie retenue.', add: '+ Ajouter une catégorie…' },
  sensitive: { title: 'Catégories sensibles', note: 'aucune au départ : ajoute seulement celles que tu acceptes toi-même', none: 'Aucune : rien de sensible ne s\'affiche chez toi.', add: '+ Accepter une catégorie…', sens: true },
};
function catPick(root) {
  const store = $('.catpick-store', root); if (!store) return;
  const inputs = $$('input', store);
  const render = () => {
    const old = $('.catpick-ui', root); if (old) old.remove();
    const ui = h('div', { class: 'catpick-ui' });
    for (const [lvl, g] of Object.entries(CAT_GROUPS)) {
      const list = inputs.filter((i) => i.dataset.lvl === lvl); if (!list.length) continue;
      const on = list.filter((i) => i.checked), off = list.filter((i) => !i.checked);
      const chips = h('div', { class: 'catpick-chips' });
      if (!on.length) chips.append(h('span', { class: 'catpick-none', text: g.none }));
      for (const i of on) chips.append(h('span', { class: 'catpick-chip', title: i.dataset.hint || false }, i.dataset.label,
        h('button', { type: 'button', 'aria-label': 'Retirer ' + i.dataset.label, text: '×', onclick: () => { i.checked = false; render(); } })));
      const sel = h('select', { class: 'catpick-add', 'aria-label': g.title }, h('option', { value: '', text: g.add }), ...off.map((i) => h('option', { value: i.value, text: i.dataset.label })));
      sel.addEventListener('change', () => { const i = list.find((x) => x.value === sel.value); if (i) { i.checked = true; render(); } });
      const act = h('div', { class: 'catpick-act' });
      if (off.length > 1) act.append(h('button', { type: 'button', class: 'catpick-link', text: 'Tout ajouter', onclick: () => { off.forEach((i) => { i.checked = true; }); render(); } }));
      if (on.length > 1) act.append(h('button', { type: 'button', class: 'catpick-link', text: 'Tout retirer', onclick: () => { on.forEach((i) => { i.checked = false; }); render(); } }));
      ui.append(h('div', { class: 'catpick-grp' + (g.sens ? ' sens' : '') }, h('b', {}, g.title, h('small', { text: g.note })), chips, off.length ? sel : null, act.children.length ? act : null));
    }
    root.append(ui);
  };
  render();
  const form = root.closest('form');
  if (form) form.addEventListener('reset', () => setTimeout(render)); // après l'envoi, le formulaire revient à son état de départ
}
const stCls = { validation: 'wait', ligne: 'ok', refusee: 'rej', arretee: 'end', terminee: 'end' };
const stLab = { validation: 'En validation', ligne: 'En ligne', refusee: 'Refusée', arretee: 'Arrêtée', terminee: 'Terminée' };

/** Nombre d'images d'une annonce (les vidéos n'en ont pas) : plusieurs images = défileur dans le détail, repère « N photos » sur les cartes. */
const imgCount = (a) => (!a.video && Array.isArray(a.images) ? a.images.length : 0);
const kindLabel = (a) => (a.video ? 'Vidéo' : imgCount(a) > 1 ? `${imgCount(a)} photos` : 'Annonce');

/** Défileur d'images : balayage au doigt, flèches, points, compteur, touches ← → ; tout passe par le défilement natif (accrochage image par image). */
function slider(imgs) {
  const last = imgs.length - 1;
  const track = h('div', { class: 'adsl-track', tabindex: '0', role: 'group', 'aria-label': `Images de l'annonce (${imgs.length})` },
    imgs.map((u, i) => h('img', { src: u, alt: `Image ${i + 1} sur ${imgs.length}`, loading: i ? 'lazy' : 'eager', draggable: 'false' })));
  const cnt = h('span', { class: 'adsl-cnt', text: `1 / ${imgs.length}` });
  const cur = () => Math.max(0, Math.min(last, Math.round(track.scrollLeft / (track.clientWidth || 1))));
  const go = (i) => track.scrollTo({ left: Math.max(0, Math.min(last, i)) * track.clientWidth, behavior: 'smooth' });
  const prev = h('button', { class: 'adsl-b adsl-p', type: 'button', 'aria-label': 'Image précédente', text: '‹', onclick: () => go(cur() - 1) });
  const next = h('button', { class: 'adsl-b adsl-n', type: 'button', 'aria-label': 'Image suivante', text: '›', onclick: () => go(cur() + 1) });
  const dots = imgs.map((_, i) => h('button', { class: 'adsl-d' + (i ? '' : ' on'), type: 'button', 'aria-label': `Voir l'image ${i + 1}`, onclick: () => go(i) }));
  const sync = () => { const i = cur(); dots.forEach((d, k) => d.classList.toggle('on', k === i)); cnt.textContent = `${i + 1} / ${imgs.length}`; prev.disabled = i === 0; next.disabled = i === last; };
  track.addEventListener('scroll', sync, { passive: true });
  track.addEventListener('keydown', (e) => { if (e.key === 'ArrowLeft') { e.preventDefault(); go(cur() - 1); } else if (e.key === 'ArrowRight') { e.preventDefault(); go(cur() + 1); } });
  prev.disabled = true;
  return h('div', { class: 'adsl' }, track, prev, next, cnt, h('div', { class: 'adsl-ds' }, dots));
}

/** Ouvre le détail d'une annonce : média, texte, aperçu du lien, bouton d'action, statistiques. opt.mine : actions de l'annonceur (renouveler, arrêter, supprimer, avec confirmation). */
function openDetail(a, opt = {}) {
  if (!dlg) return;
  const body = $('#addetail-body'); body.replaceChildren();
  const href = a.url ? safeUrl(a.url) : '';
  const pv = a.preview && (a.preview.title || a.preview.description) ? a.preview : null;
  const media = imgCount(a) > 1 ? slider(a.images) : a.video && a.media ? h('video', { src: a.media, poster: a.thumb || '', controls: true, playsinline: true, preload: 'metadata' })
    : a.media || a.thumb ? h('img', { src: a.media || a.thumb, alt: '' }) : h('div', { class: 'adc-ph', text: initial(a) });
  body.append(h('div', { class: 'addlg-media' }, media));
  const days = opt.mine ? a.daysLeft : a.days;
  const info = h('div', { class: 'addlg-info' },
    opt.mine ? h('span', { class: `st ${stCls[a.status] || 'end'}`, text: stLab[a.status] || a.status }) : h('span', { class: 'adc-tag-s', text: kindLabel(a) }),
    h('h2', { text: a.title }),
    a.text ? h('p', { class: 'addlg-text', text: a.text }) : null,
    pv && href ? h('a', { class: 'addlg-pv', href, target: '_blank', rel: 'nofollow sponsored noopener', onclick: () => opt.onVisit && opt.onVisit() },
      pv.image ? h('img', { src: pv.image, alt: '', loading: 'lazy' }) : null,
      h('span', {}, h('small', { text: pv.site || new URL(href).hostname.replace(/^www\./, '') }), h('b', { text: pv.title || '' }), pv.description ? h('em', { text: pv.description }) : null)) : null,
    h('p', { class: 'addlg-stats', text: [a.status === 'validation' ? '' : (opt.mine ? `${n(a.views)} vues · ${n(a.clicks)} clics` : `${n(a.views)} vues`), days ? `${days} jour${days > 1 ? 's' : ''} restant${days > 1 ? 's' : ''}` : ''].filter(Boolean).join(' · ') || 'En attente de validation' }),
    a.reason ? h('p', { class: 'aderr', text: `Motif : ${a.reason}` }) : null,
    a.action && href ? h('a', { class: 'btn btn-primary adbig', href, target: '_blank', rel: 'nofollow sponsored noopener', text: a.action, onclick: () => opt.onVisit && opt.onVisit() }) : null);
  body.append(info);
  if (opt.mine) {
    const zone = h('div', { class: 'addlg-act' }); info.append(zone);
    const run = async (fn) => { zone.querySelectorAll('button').forEach((b) => { b.disabled = true; }); try { await fn(); closeDetail(); } catch (e) { showError(friendly(e, 'Action impossible pour le moment. Réessaie.')); zone.querySelectorAll('button').forEach((b) => { b.disabled = false; }); } };
    const confirmBox = (msg, label, fn) => { zone.replaceChildren(h('p', { class: 'addlg-conf', text: msg }), h('div', { class: 'addlg-row' }, h('button', { class: 'btn adsm adred', type: 'button', text: label, onclick: () => run(fn) }), h('button', { class: 'btn btn-line adsm', type: 'button', text: 'Annuler', onclick: () => openDetail(a, opt) }))); };
    const buttons = [];
    if (a.renew === 'free') buttons.push(h('button', { class: 'btn btn-primary adsm', type: 'button', text: 'Renouveler gratuitement', onclick: () => run(opt.onRenew) }));
    if (a.renew === 'paid') buttons.push(h('span', { class: 'adnote', text: 'Limite de prolongations gratuites atteinte : l’offre payante Afrolook Ads arrive bientôt' }));
    if (a.status === 'validation' || a.status === 'ligne') buttons.push(h('button', { class: 'btn btn-line adsm', type: 'button', text: 'Arrêter la diffusion', onclick: () => confirmBox('Arrêter la diffusion ? L\'annonce ne sera plus visible. Tu pourras ensuite la supprimer.', 'Oui, arrêter', opt.onStop) }));
    buttons.push(h('button', { class: 'btn adsm adred-o', type: 'button', text: 'Supprimer', onclick: () => confirmBox('Supprimer cette annonce ? Elle sera retirée de la diffusion et de ta liste. Elle restera comptée dans tes annonces gratuites.', 'Oui, supprimer', opt.onDelete) }));
    zone.append(...buttons);
  }
  if (!dlg.open) dlg.showModal();
}

// ───────── simulateur d'audience (page Annoncer) : budget → audience payée, visites estimées, coût par visite ─────────
const simBox = $('#adsim');
if (simBox) {
  const cfg = { per: Number(simBox.dataset.per) || 500, ctr: Number(simBox.dataset.ctr) || 2 };
  const num = $('#sim-n'), rng = $('#sim-b'), nfmt = (v) => Number(v).toLocaleString(EN ? 'en-US' : 'fr-FR');
  const drawSim = () => {
    const b = Math.max(0, Math.min(2500000, Math.round(Number(num.value) || 0)));
    const aud = Math.round((b / cfg.per) * 1000), vis = Math.round((aud * cfg.ctr) / 100), cpv = vis > 0 ? Math.round(b / vis) : 0;
    $('#sim-aud').textContent = b >= 1000 ? nfmt(aud) : '—'; $('#sim-vis').textContent = vis > 0 && b >= 1000 ? '≈ ' + nfmt(vis) : '—'; $('#sim-cpv').textContent = cpv > 0 && b >= 1000 ? '≈ ' + nfmt(cpv) + ' F' : '—';
    $('#sim-go').href = '/ads/espace/' + (aud >= 1000 ? '?aud=' + Math.min(5000000, Math.round(aud / 1000) * 1000) : '');
    if (b >= Number(rng.min) && b <= Number(rng.max)) rng.value = String(b);
    const ctrTxt = String(cfg.ctr).replace('.', EN ? '.' : ','), perTxt = nfmt(cfg.per), note = $('#sim-note');
    note.textContent = EN
      ? `Indicative estimate: ${ctrTxt}% of the audience visits your link (observed average rate, it varies with your ad). Current rate: ${perTxt} F per 1,000 people. You pay for the audience; only valid visits are counted and you follow everything live in your space.`
      : `Estimation indicative : ${ctrTxt} % de l'audience visite ton lien (taux moyen constaté, il varie selon ton annonce). Tarif actuel : ${perTxt} F pour 1 000 personnes. Tu paies l'audience ; seules les visites valides sont comptées et tu suis tout en direct dans ton espace.`;
  };
  num.addEventListener('input', drawSim);
  rng.addEventListener('input', () => { num.value = rng.value; drawSim(); });
  $$('#sim-quick span').forEach((x) => x.addEventListener('click', () => { num.value = x.dataset.v; drawSim(); }));
  drawSim();
  // valeurs réelles du moment (prix de 1 000 personnes, taux de visite) ; les valeurs de départ restent affichées si l'API ne répond pas
  fetch(simBox.dataset.api).then((r) => (r.ok ? r.json() : null)).then((j) => { if (!j) return; if (j.sharePer1000 > 0) cfg.per = j.sharePer1000; if (j.ctr > 0) cfg.ctr = j.ctr; drawSim(); }).catch(() => {});
}

// ───────── galerie publique + bandeau « À la une » ─────────
const gallery = $('#adgallery');
if (gallery) {
  // Vues et clics : le navigateur garde un identifiant anonyme ; le serveur compte au plus UNE vue et UN clic par visiteur, annonce et jour.
  const trackUrl = gallery.dataset.api.replace('/web/public', '/web/track');
  const vid = (() => {
    try {
      let v = localStorage.getItem('adsvid');
      if (!v) { v = (crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2) + Date.now().toString(36)).replace(/[^A-Za-z0-9-]/g, ''); localStorage.setItem('adsvid', v); }
      return v;
    } catch { return 'anon-' + Math.random().toString(36).slice(2, 12) + Date.now().toString(36); }
  })();
  const sent = new Set();
  const track = (id, type) => {
    const k = id + type; if (sent.has(k)) return; sent.add(k);
    try { fetch(trackUrl, { method: 'POST', body: JSON.stringify({ id, type, vid, placement: 'site' }), headers: { 'Content-Type': 'text/plain' }, keepalive: true }).catch(() => {}); } catch { /* le comptage ne doit jamais gêner la page */ }
  };
  // « vue » = l'annonce est à l'écran (au moins à moitié)
  const seeing = 'IntersectionObserver' in window ? new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) { track(e.target.dataset.adid, 'view'); seeing.unobserve(e.target); } }), { threshold: 0.5 }) : null;
  const watch = (el, id) => { el.dataset.adid = id; if (seeing) seeing.observe(el); else track(id, 'view'); };

  (async () => {
    try {
      const r = await fetch(gallery.dataset.api, { cache: 'no-store' });
      const { items = [] } = await r.json();
      if (!items.length) { $('#adempty').hidden = false; return; }
      for (const a of items.slice(0, 24)) {
        const href = a.url ? safeUrl(a.url) : '';
        const media = a.thumb || a.media ? h('img', { src: a.thumb || a.media, alt: '', loading: 'lazy' }) : h('div', { class: 'adc-ph', text: initial(a) });
        const card = h('article', { class: 'adc', tabindex: '0', role: 'button', 'aria-label': `Voir l'annonce : ${a.title}`, id: `annonce-${a.id}` },
          h('div', { class: 'adc-img' }, media, h('span', { class: 'adc-tag', text: kindLabel(a) })),
          h('div', { class: 'adc-b' }, h('h3', { text: a.title }), h('p', { text: a.text || (a.preview && a.preview.description) || '' }),
            h('div', { class: 'adc-f' }, h('span', { class: 'adc-s', text: `${n(a.views)} ${VUES}` }),
              a.action && href ? h('a', { class: 'btn btn-primary adc-btn', href, rel: 'nofollow sponsored noopener', target: '_blank', text: ACT(a.action), onclick: (e) => { e.stopPropagation(); track(a.id, 'click'); } }) : null)));
        // ouvrir une annonce = un clic ; le bouton d'action (dans la carte ou dans le détail) = un clic aussi (compté une seule fois par jour)
        const open = () => { track(a.id, 'click'); history.replaceState(null, '', `#annonce-${a.id}`); openDetail(a, { onVisit: () => track(a.id, 'click') }); };
        card.addEventListener('click', open);
        card.addEventListener('keydown', (e) => { if ((e.key === 'Enter' || e.key === ' ') && e.target === card) { e.preventDefault(); open(); } });
        watch(card, a.id);
        gallery.append(card);
      }

      // « À la une » : les annonces les plus vues, sur une ligne fine qui défile lentement (pause au toucher ou au survol)
      const strip = $('#adfeat'); const row = $('#adfeat-row');
      if (strip && row) {
        const top = [...items].sort((x, y) => (y.views || 0) - (x.views || 0)).sort((x, y) => (!!(y.thumb || y.media)) - (!!(x.thumb || x.media))).slice(0, 6);
        const chip = (a, clone) => {
          const b = h('button', { class: 'adfeat-c', type: 'button', tabindex: clone ? '-1' : null, 'aria-hidden': clone ? 'true' : null, onclick: () => { track(a.id, 'click'); openDetail(a, { onVisit: () => track(a.id, 'click') }); } },
            a.thumb || a.media ? h('img', { src: a.thumb || a.media, alt: '', loading: 'lazy' }) : h('i', { text: initial(a) }),
            h('span', {}, h('b', { text: a.title }), h('small', { text: `${n(a.views)} ${VUES}${a.action ? ' · ' + ACT(a.action) : ''}` })));
          if (!clone) watch(b, a.id);
          return b;
        };
        const set1 = h('div', { class: 'adfeat-set' }, top.map((a) => chip(a, false)));
        const lane = h('div', { class: 'adfeat-lane' }, set1);
        row.append(lane);
        strip.hidden = !top.length;
        // Défilement continu et lent, comme un texte qui traverse l'écran : une « période » est la série d'annonces répétée jusqu'à remplir la largeur,
        // et la piste en contient deux (copies masquées aux lecteurs d'écran) ; l'animation avance d'une période, puis recommence sans saut.
        const copy = () => h('div', { class: 'adfeat-set', 'aria-hidden': 'true' }, top.map((a) => chip(a, true)));
        let builtFor = 0;
        const build = () => {
          const rowW = row.clientWidth; const setW = set1.scrollWidth;
          if (!rowW || !setW) return; // pas encore affiché : on réessaie au prochain redimensionnement
          builtFor = rowW;
          const per = Math.max(1, Math.ceil((rowW + 4) / setW));
          lane.replaceChildren(set1);
          for (let i = 1; i < per * 2; i++) lane.append(copy());
          lane.style.setProperty('--dur', `${Math.max(24, Math.round((setW * per) / 45))}s`); // environ 45 pixels par seconde
          lane.classList.add('run');
        };
        build();
        let t = 0;
        addEventListener('resize', () => { clearTimeout(t); t = setTimeout(() => { if (Math.abs(row.clientWidth - builtFor) > 40) build(); }, 200); });
        if (!builtFor) addEventListener('load', build, { once: true });
      }

      // adresse partagée d'une annonce (#annonce-…) : une visite, donc une vue
      const wanted = location.hash.startsWith('#annonce-') ? items.find((x) => `#annonce-${x.id}` === location.hash) : null;
      if (wanted) { track(wanted.id, 'view'); openDetail(wanted, { onVisit: () => track(wanted.id, 'click') }); }
    } catch { $('#adempty').hidden = false; }
  })();
}

// ───────── espace annonceur ─────────
const space = $('#adspace');
if (space) initSpace();

// ───────── connexion Google et Firebase (commune à l'espace annonceur et à l'espace diffuseur) ─────────
function setStatus(msg, bad = false, info = false) { const e = $('#adstatus'); if (msg && !info) { e.hidden = true; e.textContent = ''; (bad ? showError : showSuccess)(msg); return; } e.hidden = !msg; e.textContent = msg || ''; e.className = 'adstatus'; }   // info = message d'attente (bandeau) ; sinon erreur ou succès en fenêtre
// le logo est réduit (512 px au plus) et gardé en PNG pour conserver la transparence ; WebP s'il reste lourd
async function logoBlob(file) {
  const bmp = await createImageBitmap(file);
  if (Math.min(bmp.width, bmp.height) < 64) throw new Error('petit');
  const r = Math.min(1, 512 / Math.max(bmp.width, bmp.height)); const c = h('canvas'); c.width = Math.round(bmp.width * r); c.height = Math.round(bmp.height * r);
  c.getContext('2d').drawImage(bmp, 0, 0, c.width, c.height);
  let blob = await new Promise((res) => c.toBlob(res, 'image/png'));
  if (blob.size > 900 * 1024) { blob = await new Promise((res) => c.toBlob(res, 'image/webp', 0.85)); return { blob, ext: 'webp', type: 'image/webp' }; }
  return { blob, ext: 'png', type: 'image/png' };
}

async function boot(onUser) {
  const V = '10.14.1', G = `https://www.gstatic.com/firebasejs/${V}`;
  const status = setStatus;
  // Le bouton de connexion répond tout de suite, même si les bibliothèques Firebase chargent encore (réseau lent) : sans cela, un clic trop tôt ne faisait rien.
  let ready; const sdk = new Promise((r) => { ready = r; });
  const signin = $('#signin');
  signin.addEventListener('click', async () => {
    status('Connexion en cours…', false, true); signin.disabled = true;
    try {
      const { A, auth } = await Promise.race([sdk, new Promise((_, rej) => setTimeout(() => rej(new Error('lent')), 30000))]);
      const p = new A.GoogleAuthProvider();
      try { await A.signInWithPopup(auth, p); status(''); } catch (e) {
        if (e.code === 'auth/popup-blocked' || e.code === 'auth/operation-not-supported-in-this-environment') return A.signInWithRedirect(auth, p);
        if (e.code === 'auth/unauthorized-domain') status('Ce site n\'est pas encore autorisé pour la connexion Google. Préviens l\'équipe Afrolook Ads.', true);
        else if (e.code === 'auth/popup-closed-by-user' || e.code === 'auth/cancelled-popup-request') status('');
        else status(`Connexion impossible pour le moment (${e.code || 'erreur'}). Réessaie.`, true);
      }
    } catch (e) { status(friendly(e, 'La connexion met du temps à charger. Vérifie ta connexion internet puis réessaie.'), true); }
    finally { signin.disabled = false; }
  });

  let mods;
  try { mods = await Promise.all([import(`${G}/firebase-app.js`), import(`${G}/firebase-auth.js`)]); }
  catch { status('Impossible de charger la connexion Google (réseau). Recharge la page et réessaie.', true); return null; }
  const [{ initializeApp }, A] = mods;
  const app = initializeApp(JSON.parse($('#fbcfg').textContent));
  const auth = A.getAuth(app);
  // Appels des espaces connectés : l'API Afrolook (même nom, mêmes données, mêmes réponses que les anciennes fonctions). Jeton Google dans l'en-tête.
  const SPACE = $('#fbcfg').dataset.space, API_V1 = SPACE.replace(/\/ads\/api\/space$/, '/v1');
  const authHeader = async () => ({ Authorization: 'Bearer ' + (await auth.currentUser.getIdToken()) });
  const call = async (name, data) => {
    let r;
    try { r = await fetch(`${SPACE}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json', Accept: 'application/json', ...(await authHeader()) }, body: JSON.stringify(data || {}) }); }
    catch { throw Object.assign(new Error('réseau'), { code: 'functions/unavailable' }); }
    const j = await r.json().catch(() => ({}));
    if (r.ok) return j;
    if (j.code === 'profile_missing') { status(j.message, true); throw Object.assign(new Error(j.message), { code: 'functions/failed-precondition' }); }   // pas encore de profil Afrolook : ouvrir l'application une première fois
    throw Object.assign(new Error((j.error && j.error.message) || j.message || 'erreur'), { code: 'functions/' + String((j.error && j.error.status) || 'unknown').toLowerCase().replace(/_/g, '-') });
  };
  // Dépôt d'un fichier (logo, image, vidéo, bannière) : l'API donne une adresse d'envoi directe, puis confirme ; on récupère l'adresse publique du fichier.
  const upload = async (blob, contentType) => {
    const a = await fetch(`${API_V1}/uploads`, { method: 'POST', headers: { 'Content-Type': 'application/json', ...(await authHeader()) }, body: JSON.stringify({ content_type: contentType, size: blob.size }) });
    const j = await a.json(); if (!a.ok) throw new Error((j && j.message) || 'envoi refusé');
    const put = await fetch(j.data.url, { method: 'PUT', headers: j.data.headers, body: blob }); if (!put.ok) throw new Error('envoi échoué');
    const c = await fetch(`${API_V1}/uploads/${j.data.upload_id}/complete`, { method: 'POST', headers: await authHeader() });
    const k = await c.json(); if (!c.ok) throw new Error((k && k.message) || 'envoi non confirmé');
    return k.data.url;
  };
  ready({ A, auth });
  $('#signout').addEventListener('click', () => A.signOut(auth));
  A.onAuthStateChanged(auth, (u) => {
    $('#adgate').hidden = !!u; if ($('#adways')) $('#adways').hidden = !!u; $('#adapp').hidden = !u; $('#adsp-user').hidden = !u;
    if (!u) return;
    $('#u-name').textContent = u.displayName || 'Annonceur'; $('#u-mail').textContent = u.email || '';
    $('#u-av').textContent = (u.displayName || u.email || 'A').trim().charAt(0).toUpperCase();
    setTimeout(() => onUser(u), 0); // laisse la page finir son initialisation avant de charger les données
    // Aucun bouton « Administration » sur le site : on détecte le compte à la connexion et on n'affiche l'espace admin qu'aux administrateurs.
    call('adsWho').then((r) => { if (r && r.admin) { IS_ADMIN = true; IS_OFFERED = !!r.offered; showAdminAccess(); window.dispatchEvent(new Event('afl-admin')); } }).catch(() => {});
  });
  return { A, auth, call, upload };
}

/** Ajoute l'accès à l'espace administration (menu du haut + carte du compte) ; appelé seulement pour un administrateur connecté. */
function showAdminAccess() {
  if ($('#adm-access')) return;
  const nav = $('.adsnav .wrap');
  if (nav) nav.append(h('a', { id: 'adm-access', class: 'adm', href: '/ads/admin/', ...(location.pathname.startsWith('/ads/admin') ? { 'aria-current': 'page' } : {}) }, 'Espace administration'));
  const box = $('#adsp-user');
  if (box && !location.pathname.startsWith('/ads/admin')) box.append(h('a', { class: 'adlinkbtn', href: '/ads/admin/' }, "Ouvrir l'administration"));
  if (nav && !$('#adm-dash')) nav.append(h('a', { id: 'adm-dash', class: 'adm', href: '/admin/' }, 'Tableau de bord'));   // statistiques de la plateforme (consultation seule)
}

/** Bandeau d'état du profil, en haut de l'espace : l'annonceur ou le diffuseur sait toujours où en est la validation de son profil. */
const PROFBAN = {
  adv: {
    none: ['warn', '📝', 'Profil à compléter', 'Renseigne ta marque, tes contacts et ton logo : notre équipe valide ton profil, puis ton logo est affiché comme partenaire.'],
    pending: ['wait', '⏳', 'Ton profil est en cours de validation', 'Notre équipe l’examine et tu recevras un e-mail avec la décision. Tu pourras publier ta première annonce dès qu’il est validé.'],
    ok: ['ok', '✅', 'Profil validé', 'Ton profil est validé. Ton logo est affiché parmi nos partenaires dès que tu as une annonce en ligne.'],
    rej: ['rej', '⛔', 'Profil refusé', 'Corrige ton profil dans l’onglet « Mon profil » puis renvoie-le pour une nouvelle validation.'],
  },
  pub: {
    none: ['warn', '📝', 'Profil à compléter', 'Renseigne ton profil de diffuseur : notre équipe le valide avant de traiter tes sites et applications.'],
    pending: ['wait', '⏳', 'Ton profil est en cours de validation', 'Notre équipe l’examine et tu recevras un e-mail avec la décision. Tu peux déjà ajouter tes sites et applications : ils seront traités une fois ton profil validé.'],
    ok: ['ok', '✅', 'Profil validé', 'Ton profil est validé : tes sites et applications sont examinés un par un, chacun reçoit son identifiant publicitaire une fois accepté.'],
    rej: ['rej', '⛔', 'Profil refusé', 'Corrige ton profil puis renvoie-le pour une nouvelle validation.'],
    suspended: ['rej', '⛔', 'Profil suspendu', 'Ton profil est suspendu : tes sites et applications ne diffusent plus d’annonces. Contacte l’équipe Afrolook Ads pour en savoir plus.'],
  },
};
function profBanner(kind, state, reason) {
  const box = $('#profban'); if (!box) return;
  const m = (PROFBAN[kind] || {})[state]; if (!m) { box.hidden = true; return; }
  box.className = 'profban ' + m[0];
  box.replaceChildren(h('i', { text: m[1], 'aria-hidden': 'true' }), h('div', {}, h('b', { text: m[2] }), h('p', { text: m[3] }), reason && (state === 'rej' || state === 'suspended') ? h('p', { class: 'profban-why', text: 'Motif : ' + reason }) : null));
  box.hidden = false;
}

async function initSpace() {
  const status = setStatus;
  const err = (msg) => { const e = $('#aderr'); if (e) { e.hidden = true; e.textContent = ''; } if (msg) showError(msg); };
  const fb = await boot(() => { loadProfile(); loadMine(); loadShareMine(); loadWallet(); });   // les campagnes Partage comptent aussi dans le bandeau de chiffres, dès l'ouverture
  if (!fb) return;
  const { auth, call, upload } = fb;

  // onglets
  const tab = (t) => { $$('.adtabs a').forEach((a) => a.classList.toggle('on', a.dataset.tab === t)); for (const k of ['creer', 'mes', 'solde', 'profil']) $('#tab-' + k).hidden = k !== t; if (t === 'mes') { loadMine(); loadShareMine(); } if (t === 'solde') loadWallet(); };
  $$('.adtabs a').forEach((a) => a.addEventListener('click', (e) => { e.preventDefault(); tab(a.dataset.tab); }));

  // formulaire : choix, aperçu en direct
  const wal = { data: null, per1000: 500 }; // prix de 1 000 personnes : valeur du serveur (adsWalletMe), 500 F tant qu'elle n'est pas chargée
  const nf = (v) => Number(v).toLocaleString('fr-FR');
  // les 7 types d'annonce : le type fixe le bouton (jamais de texte libre qui trompe), la destination attendue et, pour un produit, le prix
  const TYPES = {
    product: { action: 'buy', label: 'Acheter', dest: 'link', kind: 'projet', price: true, ph: 'https://tonsite.com/produit', hint: 'Colle le lien de la page du produit (pas la page d\u2019accueil). Le prix indiqué doit être celui de cette page.' },
    site: { action: 'visit', label: 'Visiter le site', dest: 'link', kind: 'site', ph: 'https://tonsite.com', hint: 'Lien complet de ta boutique ou de ton site, en https://. Les liens raccourcis (bit.ly…) et les téléchargements directs ne sont pas acceptés.' },
    app: { action: 'download', label: 'Installer', dest: 'link', kind: 'app', ph: 'https://play.google.com/store/apps/details?id=…', hint: 'Lien de ton application sur Google Play ou l\u2019App Store.' },
    whatsapp: { action: 'whatsapp', label: 'Écrire sur WhatsApp', dest: 'phone', kind: 'entreprise', ph: '+228 90 00 00 00', hint: 'Le numéro WhatsApp avec l\u2019indicatif du pays : la discussion s\u2019ouvre en un geste.' },
    call: { action: 'call', label: 'Appeler', dest: 'phone', kind: 'entreprise', ph: '+228 90 00 00 00', hint: 'Le numéro à appeler, avec l\u2019indicatif du pays.' },
    social: { action: 'follow', label: 'Suivre la page', dest: 'link', kind: 'projet', ph: 'https://www.facebook.com/tapage', hint: 'Le lien de ta page Facebook, Instagram, TikTok, YouTube ou Telegram.' },
    event: { action: 'book', label: 'Réserver', dest: 'link', kind: 'projet', ph: 'https://tonsite.com/evenement', hint: 'Le lien de la page où l\u2019on réserve ou s\u2019inscrit à ton événement.' },
  };
  const st = { type: 'site', kind: 'site', action: 'visit', countries: new Set(['ALL']), langs: new Set(), devs: new Set(), types: new Set(), files: [], isVideo: false, open: true, left: 3 };
  const tel = () => TYPES[st.type].dest === 'phone';
  const refresh = () => {
    const T = TYPES[st.type], l = $('#f-link'); l.placeholder = T.ph; l.inputMode = tel() ? 'tel' : 'url';
    $('#f-link-l').firstChild.textContent = tel() ? 'Numéro de téléphone, avec l\'indicatif ' : (st.type === 'social' ? 'Lien de ta page ' : st.type === 'app' ? 'Lien de l\u2019application ' : 'Lien du bouton');
    $('#f-price-l').hidden = !T.price; $('#f-link-hint').textContent = T.hint;
    $('#f-btn-note').innerHTML = 'Le bouton de ton annonce sera <b>' + T.label + '</b>.';
    $('#pv-btn').textContent = T.label;
    $('#pv-name').textContent = $('#f-title').value.trim() || 'Ton entreprise';
    $('#pv-av').textContent = ($('#f-title').value.trim() || 'A').charAt(0).toUpperCase();
    $('#pv-text').textContent = $('#f-text').value.trim() || 'Ton texte apparaîtra ici.';
    const pr = TYPES[st.type].price && Number($('#f-price').value) >= 1 ? nf(Number($('#f-price').value)) + ' F · ' : '';
    $('#pv-link').textContent = pr + ($('#f-link').value.trim() || '').replace(/^https?:\/\//, '').slice(0, 28);
  };
  $$('#f-type label').forEach((el) => el.addEventListener('click', () => {
    st.type = el.dataset.v; st.action = TYPES[st.type].action; st.kind = TYPES[st.type].kind;
    $$('#f-type label').forEach((x) => x.classList.toggle('on', x === el)); $('#f-link').value = ''; refresh();
  }));
  const pickCountry = (v) => {
    if (v === 'ALL') st.countries = new Set(['ALL']); else { st.countries.delete('ALL'); st.countries.has(v) ? st.countries.delete(v) : st.countries.add(v); if (!st.countries.size) st.countries.add('ALL'); }
    $$('#f-countries span').forEach((x) => x.classList.toggle('on', st.countries.has(x.dataset.v)));
  };
  $$('#f-countries span').forEach((c) => c.addEventListener('click', () => pickCountry(c.dataset.v)));
  // tous les autres pays du monde : la liste ajoute une pastille de plus
  const moreC = $('#f-more-countries'), knownC = new Set($$('#f-countries span').map((x) => x.dataset.v));
  sortedCountries().filter(([c]) => !knownC.has(c)).forEach(([c, nm]) => moreC.append(h('option', { value: c, text: nm })));
  moreC.addEventListener('change', () => {
    const c = moreC.value; if (!c) return;
    $('#f-countries').append(h('span', { 'data-v': c, text: countryName(c), onclick: () => pickCountry(c) }));
    const o = moreC.querySelector(`option[value="${c}"]`); if (o) o.remove(); moreC.value = ''; pickCountry(c);
  });
  ['#f-title', '#f-text', '#f-link', '#f-price'].forEach((s) => $(s).addEventListener('input', refresh));
  // ciblage facultatif (langues, appareils, types de sites) et note sur les catégories sensibles
  const chips = (box, set) => $$(box + ' span').forEach((c) => c.addEventListener('click', () => { const v = c.dataset.v; set.has(v) ? set.delete(v) : set.add(v); c.classList.toggle('on', set.has(v)); }));
  chips('#f-langs', st.langs); chips('#f-devs', st.devs); chips('#f-types', st.types);
  $('#f-cat').addEventListener('change', () => { const o = $('#f-cat').selectedOptions[0]; $('#f-cat-note').hidden = !(o && o.dataset.s); });
  $('#f-file').addEventListener('change', (e) => {
    const files = [...e.target.files]; err('');
    const vids = files.filter((f) => f.type.startsWith('video/'));
    if (vids.length && files.length > 1) return err('Choisis soit des images (jusqu\'à 5), soit une seule vidéo.');
    if (vids[0] && vids[0].size > 25 * 1024 * 1024) return err('La vidéo dépasse 25 Mo.');
    st.duration = 0;
    if (vids[0]) {
      // durée de la vidéo : 15 secondes maximum, pour qu'elle soit vue vite
      const probe = h('video', { preload: 'metadata' }); probe.src = URL.createObjectURL(vids[0]);
      probe.onloadedmetadata = () => {
        st.duration = probe.duration || 0;
        if (st.duration > 15.5) { st.files = []; $('#f-file').value = ''; $('#f-file-name').textContent = 'Choisis une image ou une vidéo'; err(`La vidéo doit durer 15 secondes maximum (la tienne : ${Math.round(st.duration)} s).`); }
      };
      probe.onerror = () => { st.files = []; $('#f-file').value = ''; err('Vidéo illisible : essaie un fichier MP4.'); };
    }
    if (!vids.length && files.length > 5) return err('5 images au maximum.');
    st.files = files; st.isVideo = vids.length === 1;
    $('#f-file-name').textContent = files.length ? files.map((f) => f.name).join(', ').slice(0, 80) : 'Choisis une image ou une vidéo';
    imageTip(files[0], st.isVideo);
    if (files[0]) { const box = $('#pv-img'); box.replaceChildren(st.isVideo ? h('video', { src: URL.createObjectURL(files[0]), muted: true, playsinline: true }) : h('img', { src: URL.createObjectURL(files[0]), alt: '' })); }
  });

  /** Conseil immédiat sur l'image choisie : trop petite (floue en bannière), trop allongée (illisible) ou parfaite. */
  async function imageTip(file, isVideo) {
    const t = $('#f-file-tip'); if (!t) return;
    t.hidden = true; t.className = 'imgtip';
    if (!file || isVideo) return;
    try {
      const bmp = await createImageBitmap(file); const w = bmp.width, hh = bmp.height, r = w / hh;
      let msg, cls;
      if (Math.min(w, hh) < 400) { cls = 'bad'; msg = 'Image petite (' + w + ' × ' + hh + ') : elle sera floue en bannière. Prends au moins 600 × 600 px.'; }
      else if (r > 2.2 || r < 0.55) { cls = 'warn'; msg = 'Format très allongé (' + w + ' × ' + hh + ') : elle s\u2019affichera très petite. Un carré ou un 4:5 est plus lisible.'; }
      else { cls = 'ok'; msg = 'Image ' + w + ' × ' + hh + ' : ' + (Math.abs(r - 1) < 0.08 ? 'carrée, parfaite pour toutes les bannières.' : r > 1 ? 'paysage : très bien pour les rectangles et les cartes.' : 'portrait : très bien pour les cartes (affichée entière en bannière).'); }
      t.className = 'imgtip ' + cls; t.textContent = msg; t.hidden = false;
    } catch { /* image illisible : le contrôle d'envoi s'en charge */ }
  }

  // bannières prêtes à l'emploi (facultatives) : taille exacte vérifiée tout de suite
  const BANNERS = { b728x90: [728, 90], b320x50: [320, 50], b320x100: [320, 100], b300x250: [300, 250] };
  st.banners = {};
  $$('.bnrow input[type=file]').forEach((inp) => inp.addEventListener('change', async () => {
    const k = inp.dataset.k, tip = $('#bt-' + k), f = inp.files[0]; delete st.banners[k]; tip.textContent = ''; tip.className = 'bt';
    if (!f) return;
    const bad = (m) => { inp.value = ''; tip.className = 'bt bad'; tip.textContent = m; };
    if (f.size > 500 * 1024) return bad('Trop lourde (' + Math.round(f.size / 1024) + ' Ko) : 500 Ko au plus.');
    try {
      const bmp = await createImageBitmap(f), [w, hh] = BANNERS[k];
      if (Math.abs((bmp.width / bmp.height) / (w / hh) - 1) > 0.03 || bmp.width < w) return bad('Taille attendue : ' + w + ' × ' + hh + ' (ou le double). La tienne : ' + bmp.width + ' × ' + bmp.height + '.');
      st.banners[k] = f; tip.className = 'bt ok'; tip.textContent = '✓ ' + bmp.width + ' × ' + bmp.height;
    } catch { bad('Image illisible.'); }
  }));

  // diffusion : trois options cumulables (dans Afrolook, chez les partenaires, partage au clic), chacune avec son budget payé depuis le solde annonceur ; sans option, l'annonce est gratuite
  const NATIVE_CPM = 1500;   // prix pour 1 000 vues d'une carte native : sert seulement à l'estimation affichée
  const opt = (k) => ({ on: $('#o-' + k + '-on').checked, v: Math.round(Number($('#o-' + k + '-v').value) || 0) });
  const diffusion = () => {
    const app = opt('app'), net = opt('net'), sh = opt('share'), sharePrice = sh.on ? Math.round((sh.v / 1000) * wal.per1000) : 0;
    return { app, net, sh, sharePrice, total: (app.on ? app.v : 0) + (net.on ? net.v : 0) + sharePrice, paid: app.on || net.on || sh.on };
  };
  const refreshMode = () => {
    const d = diffusion(), bal = wal.data ? wal.data.balanceXof : 0;
    $('#f-bal').textContent = wal.data ? ' (solde actuel : ' + nf(bal) + ' F)' : '';
    $('#o-app-e').textContent = d.app.on ? '≈ ' + nf(Math.round((d.app.v / NATIVE_CPM) * 1000)) + ' affichages mesurés avec une carte native (davantage avec une bannière, moins avec une vidéo)' : '';
    $('#o-net-e').textContent = d.net.on ? '≈ ' + nf(Math.round((d.net.v / NATIVE_CPM) * 1000)) + ' affichages mesurés avec une carte native (davantage avec une bannière, moins avec une vidéo)' : '';
    const est = wal.data && wal.data.shareEstimate, clicks = est ? Math.floor(d.sharePrice * est.clicksPerFcfa) : 0;
    $('#o-share-e').textContent = d.sh.on ? (IS_OFFERED ? 'Offert par l’équipe : aucun paiement' : nf(d.sharePrice) + ' F pour ' + nf(d.sh.v) + ' personnes à atteindre')
      + (est && clicks > 0 ? ' · jusqu’à ≈ ' + nf(clicks) + ' clics valides, soit entre ' + nf(Math.round(clicks / est.ctrMax)) + ' et ' + nf(Math.round(clicks / est.ctrMin)) + ' personnes touchées (estimation)' : '') : '';
    $$('[data-shareonly]').forEach((e) => { e.hidden = !d.sh.on; });
    $('#f-sbrand-l').hidden = !(IS_OFFERED && d.sh.on);
    $('#f-days-l').hidden = !(d.app.on || d.net.on);
    $('#pv-note').innerHTML = !d.paid ? 'Ton annonce sera diffusée sur <b>Afrolook</b>, <b>SlashAtlas</b>, <b>Pronoflash</b> et <b>Épargne+</b> après validation.'
      : 'Ton annonce sera diffusée ' + [d.app.on ? 'dans <b>Afrolook</b>' : '', d.net.on ? 'chez nos <b>sites et applications partenaires</b>' : '', d.sh.on ? 'par le <b>partage au clic</b>' : ''].filter(Boolean).join(', ').replace(/, ([^,]*)$/, ' et $1') + ' après validation.';
    $('#f-sum-t').textContent = !d.paid ? 'Gratuit' : IS_OFFERED ? 'Offert par l’équipe' : nf(d.total) + ' F';
    $('#f-sum-n').textContent = !d.paid ? 'Une seule annonce gratuite, 14 jours, sur Afrolook, SlashAtlas, Pronoflash et Épargne+. Elle devient payante dès qu\u2019une option est cochée.'
      : IS_OFFERED ? 'Offert par l’équipe : rien n’est débité de ton solde.' : 'Débité de ton solde annonceur' + (wal.data ? ' (solde actuel : ' + nf(bal) + ' F)' : '') + '. Le budget non dépensé te revient à la fin de l\u2019annonce ; si notre équipe la refuse, tu es remboursé en entier.';
    $('#f-send').textContent = !d.paid ? 'Envoyer pour validation' : IS_OFFERED ? 'Lancer l’annonce' : 'Payer et envoyer';
    $('#f-quota').textContent = !d.paid ? (!st.mine ? 'Validation par notre équipe avant diffusion' : !st.open ? 'L\u2019offre gratuite est terminée.' : st.left ? `${st.left} annonce${st.left > 1 ? 's' : ''} gratuite${st.left > 1 ? 's' : ''} restante${st.left > 1 ? 's' : ''} · validation par notre équipe avant diffusion` : 'Tu as utilisé ton annonce gratuite : coche au moins une option de diffusion.')
      : 'Démarre après validation par notre équipe';
    if (st.mine) $('#f-send').disabled = !d.paid && !(st.open && st.left);
    $$('#adform .adfs').filter((e) => !e.hidden).forEach((e) => { const i = e.querySelector('h3 > i'); if (i) i.textContent = e.dataset.step || i.textContent; });
    // solde insuffisant : on le dit tout de suite, avec le bouton pour recharger (jamais de paiement direct)
    const lack = d.total - bal, need = $('#f-need');
    need.hidden = !(d.paid && !IS_OFFERED && wal.data && lack > 0);
    need.dataset.lack = String(Math.max(0, lack));
    $('#f-need-t').textContent = 'Ces options coûtent ' + nf(d.total) + ' F et ton solde est de ' + nf(bal) + ' F : il te manque ' + nf(Math.max(0, lack)) + ' F. Recharge ton solde, puis envoie ton annonce.';
  };
  ['app', 'net', 'share'].forEach((k) => { $('#o-' + k + '-on').addEventListener('change', refreshMode); $('#o-' + k + '-v').addEventListener('input', () => { if (Number($('#o-' + k + '-v').value) > 0) $('#o-' + k + '-on').checked = true; refreshMode(); }); });
  window.addEventListener('afl-admin', refreshMode);
  window.addEventListener('afl-wallet', refreshMode);
  $('#f-need-go').addEventListener('click', () => openTopup(Number($('#f-need').dataset.lack) || 0));

  // quatre étapes : quoi, ton annonce, destination, diffusion
  let step = 1;
  const showStep = (n) => {
    step = n;
    $$('.adstep').forEach((e) => { e.hidden = Number(e.dataset.step) !== n; });
    $$('#f-steps span').forEach((x, i) => { x.classList.toggle('on', i + 1 === n); x.classList.toggle('done', i + 1 < n); });
    $('#f-prev').hidden = n === 1; $('#f-next').hidden = n === 4; $('#f-subrow').hidden = n !== 4;
    if (n === 4) refreshMode(); else $('#f-need').hidden = true;
    $('#f-steps').scrollIntoView({ block: 'start', behavior: 'smooth' });
  };
  const validate = (n) => {
    if (n === 2) {
      if ($('#f-title').value.trim().length < 2) return 'Ajoute un titre.';
      if ($('#f-text').value.trim().length < 10) return 'Écris un texte d\'au moins 10 caractères.';
      if (!$('#f-cat').value) return 'Choisis la catégorie de ton annonce.';
      if (!st.files.length) return 'Ajoute une image ou une vidéo.';
      if (st.isVideo && !(st.duration > 0)) return 'Patiente un instant : la durée de la vidéo est en cours de lecture.';
    }
    if (n === 3) {
      const link = $('#f-link').value.trim();
      if (TYPES[st.type].price && !(Number($('#f-price').value) >= 1)) return 'Indique le prix du produit, en francs CFA.';
      if (!link) return tel() ? 'Ajoute ton numéro de téléphone.' : 'Ajoute le lien du bouton (https://…).';
      if (!tel() && !/^https:\/\//i.test(link)) return 'Le lien doit commencer par https://';
    }
    if (n === 4) {
      const d = diffusion();
      for (const [o, nom] of [[d.app, 'dans Afrolook'], [d.net, 'chez les partenaires']]) if (o.on && (o.v < 1000 || o.v > 5000000)) return 'Budget ' + nom + ' : entre 1 000 et 5 000 000 F.';
      if (d.sh.on && (d.sh.v < 1000 || d.sh.v > 5000000)) return 'Partage au clic : entre 1 000 et 5 000 000 personnes à atteindre.';
      if (!d.paid && st.mine && !(st.open && st.left)) return 'Tu as déjà utilisé ton annonce gratuite : coche au moins une option de diffusion.';
    }
    return '';
  };
  $('#f-next').addEventListener('click', () => { err(''); const m = validate(step); if (m) return err(m); showStep(step + 1); });
  $('#f-prev').addEventListener('click', () => { err(''); showStep(step - 1); });
  try {   // venant du simulateur : ?aud=25000 ouvre l'option « Partage au clic » avec cette audience
    const q = Number(new URLSearchParams(location.search).get('aud')), v = Math.round(q / 1000) * 1000;
    if (v >= 1000 && v <= 5000000) { $('#o-share-v').value = String(v); $('#o-share-on').checked = true; tab('creer'); }
  } catch { /* sans paramètre */ }

  // mes campagnes Partage : statut, audience engagée, clics valides (visibles seulement ici)
  const shareStat = { pending: ['wait', 'En attente de validation'], active: ['ok', 'En cours'], paused: ['end', 'En pause'], refused: ['rej', 'Refusée'], ended: ['end', 'Terminée'] };
  async function loadShareMine() {
    try {
      const r = await call('adsShareCampaignMine'), box = $('#sharemine');
      st.shares = r.items; drawAdvKpis();
      box.hidden = !r.items.length;
      $('#sharelist').replaceChildren(...r.items.map((c) => {
        const [cls, lab] = shareStat[c.status] || ['end', c.status];
        const reached = Number(c.deliveredAudience != null ? c.deliveredAudience : 0), reach = c.estimatedReach || { low: 0, high: 0 }, ctr = c.ctrRange || [0.022, 0.038], pc = (x) => (x * 100).toFixed(1).replace('.', ',') + ' %';   // estimation à partir des clics valides, jamais l'audience déclarée par les partageurs
        const pctDone = Math.min(100, c.targetAudience ? Math.round((reached / c.targetAudience) * 100) : 0);
        const zone = h('div', { class: 'rg-act' });
        const act = (name, okMsg) => async () => { zone.querySelectorAll('button').forEach((x) => { x.disabled = true; }); try { await call(name, { id: c.id }); status(okMsg); await loadShareMine(); } catch (e) { showError(friendly(e, 'Action impossible pour le moment. Réessaie.')); zone.querySelectorAll('button').forEach((x) => { x.disabled = false; }); } };
        const ask = (msg, label, fn) => zone.replaceChildren(h('p', { class: 'addlg-conf', text: msg }), h('div', { class: 'addlg-row' }, h('button', { class: 'btn adsm adred', type: 'button', text: label, onclick: fn }), h('button', { class: 'btn btn-line adsm', type: 'button', text: 'Annuler', onclick: () => draw() })));
        // ajout de budget à tout moment : l'annonceur choisit combien de personnes en plus, voit le prix exact et son solde, puis confirme (payé sur son solde, un seul débit par envoi)
        const topUp = () => {
          const ref = 'tu' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8), bal = wal.data ? wal.data.balanceXof : null;
          const sel = h('select', { class: 'rg-sel' }, ...[1000, 5000, 10000, 50000, 100000].filter((x) => x + Number(c.targetAudience) <= 5000000).map((x) => h('option', { value: String(x), text: '+ ' + nf(x) + ' personnes' })));
          const priceOf = () => Math.round((Number(sel.value) / 1000) * wal.per1000);
          const line = h('p', { class: 'addlg-conf' });
          const refresh = () => { const pr = priceOf(); line.textContent = c.free ? 'Offert par l’équipe : aucun paiement.' : 'Prix : ' + nf(pr) + ' F, payé sur ton solde' + (bal != null ? ' (' + nf(bal) + ' F disponibles).' : '.') + (bal != null && bal < pr ? ' Ton solde est insuffisant : recharge-le d’abord.' : ''); };
          sel.onchange = refresh; refresh();
          const go = async () => {
            zone.querySelectorAll('button').forEach((x) => { x.disabled = true; });
            try { await call('adsShareCampaignTopUp', { id: c.id, extraAudience: Number(sel.value), ref }); status('Budget ajouté : la diffusion continue.'); loadWallet(); await loadShareMine(); }
            catch (e) { showError(friendly(e, 'Ajout impossible pour le moment. Réessaie.')); zone.querySelectorAll('button').forEach((x) => { x.disabled = false; }); }
          };
          zone.replaceChildren(h('label', { class: 'rg-lab', text: 'Combien de personnes en plus ?' }), sel, line, h('div', { class: 'addlg-row' }, h('button', { class: 'btn adsm', type: 'button', text: 'Ajouter ce budget', onclick: go }), h('button', { class: 'btn btn-line adsm', type: 'button', text: 'Annuler', onclick: () => draw() })));
        };
        const draw = () => {
          const b = [];
          if (['pending', 'active', 'paused', 'ended'].includes(c.status)) b.push(h('button', { class: 'btn adsm' + (c.budgetState === 'ok' ? ' btn-line' : ''), type: 'button', text: 'Ajouter du budget', onclick: topUp }));
          if (['pending', 'active', 'paused'].includes(c.status)) b.push(h('button', { class: 'btn btn-line adsm', type: 'button', text: 'Arrêter la diffusion', onclick: () => ask('Arrêter la diffusion ? La campagne ne sera plus proposée aux partageurs. Ce qui a déjà été diffusé n’est pas remboursé.', 'Oui, arrêter', act('adsShareCampaignStop', 'Campagne arrêtée.')) }));
          b.push(h('button', { class: 'btn adsm adred-o', type: 'button', text: 'Supprimer', onclick: () => ask('Supprimer cette campagne ? Elle sera retirée de ta liste et de la diffusion. Aucun remboursement n’est possible.', 'Oui, supprimer', act('adsShareCampaignDelete', 'Campagne supprimée.')) }));
          zone.replaceChildren(...b);
        };
        draw();
        return h('article', { class: 'rg-card' },
          h('div', { class: 'rg-h' }, h('div', {}, h('b', { text: c.title }), h('small', { text: c.free ? 'Campagne offerte par l’équipe' : nf(c.priceFcfa || c.listPriceFcfa) + ' F pour ' + nf(c.targetAudience) + ' personnes' })), h('span', { class: 'st ' + cls, text: lab })),
          h('div', { class: 'rg-reach rg-' + (c.budgetState || 'ok') }, h('small', { text: 'Budget consommé' }), h('b', { text: c.usedPct + ' %' }),
            h('div', { class: 'rg-bar' }, h('i', { style: 'width:' + Math.min(100, c.usedPct || 0) + '%' })),
            h('small', { class: 'rg-note', text: c.status === 'ended' || c.budgetState === 'used' ? 'Budget entièrement consommé : la diffusion est terminée.' : c.budgetState === 'low' ? 'Il reste ' + Math.max(0, 100 - c.usedPct) + ' % du budget : la diffusion va bientôt se terminer. Tu peux lancer une nouvelle campagne pour continuer.' : 'Il reste ' + Math.max(0, 100 - c.usedPct) + ' % du budget. La diffusion se termine quand il est entièrement consommé.' })),
          h('div', { class: 'rg-row' }, h('span', { text: 'Clics valides' }), h('b', { text: nf(c.valid) })),
          c.status === 'active' ? h('div', { class: 'rg-row' }, h('span', { text: 'Clics encore possibles' }), h('b', { text: nf(c.clicksLeft) })) : null,
          h('div', { class: 'rg-row' }, h('span', { text: 'Audience touchée (estimation)' }), h('b', { text: reach.high > 0 ? nf(reach.low) + ' à ' + nf(reach.high) + ' personnes' : 'pas encore de clic valide' })),
          c.reason ? h('div', { class: 'rg-row' }, h('span', { text: 'Motif' }), h('b', { text: c.reason })) : null,
          h('details', { class: 'rg-more' }, h('summary', { text: 'Plus de détails' }),
            h('div', { class: 'rg-row' }, h('span', { text: 'Partageurs qui ont publié' }), h('b', { text: nf(c.sharersPublished) + ' / ' + nf(c.sharers) })),
            h('div', { class: 'rg-row' }, h('span', { text: 'Visites du lien (avant v\u00e9rification des clics)' }), h('b', { text: nf(c.uniqueOpens) }))),
          zone);
      }));
    } catch { /* pas de campagne ou service indisponible */ }
  }

  // fichiers : réduction des images, miniature de la vidéo, dépôt dans le stockage
  const shrink = async (file) => {
    const bmp = await createImageBitmap(file); const r = Math.min(1, 1600 / Math.max(bmp.width, bmp.height));
    const c = h('canvas'); c.width = Math.round(bmp.width * r); c.height = Math.round(bmp.height * r); c.getContext('2d').drawImage(bmp, 0, 0, c.width, c.height);
    return new Promise((res) => c.toBlob(res, 'image/jpeg', 0.82));
  };
  const frame = (file) => new Promise((res, rej) => {
    const v = h('video', { muted: true, playsinline: true, preload: 'metadata' }); v.src = URL.createObjectURL(file);
    v.onloadeddata = () => { v.currentTime = Math.min(0.5, (v.duration || 1) / 2); };
    v.onseeked = () => { const c = h('canvas'); c.width = v.videoWidth || 640; c.height = v.videoHeight || 360; c.getContext('2d').drawImage(v, 0, 0, c.width, c.height); c.toBlob(res, 'image/jpeg', 0.8); };
    v.onerror = () => rej(new Error('Vidéo illisible.'));
  });
  const put = async (folder, blob, ext, type) => upload(blob, type);   // le dossier et l'extension n'existent plus : l'API range les fichiers

  const explain = (e) => {
    const m = String(e?.message || '');
    if (/profil_manquant/.test(m)) return 'Complète d\'abord ton profil de marque (nom et logo).';
    if (/catégorie/.test(m)) return 'Choisis la catégorie de ton annonce.';
    if (/profil_en_validation/.test(m)) return 'Ton profil est en cours de validation : tu pourras publier ta première annonce dès qu’il est validé (tu recevras un e-mail).';
    if (/logo_refuse/.test(m)) return "Ton profil annonceur a été refusé : corrige-le dans l'onglet Profil puis renvoie-le.";
    if (/15 secondes/.test(m)) return 'La vidéo doit durer 15 secondes maximum.';
    if (/solde_insuffisant/.test(m)) { loadWallet(); return 'Ton solde est insuffisant : recharge-le avec le bouton « Recharger maintenant », puis renvoie ton annonce.'; }
    if (/limite_atteinte/.test(m)) return 'Tu as déjà utilisé ton annonce gratuite : elle est unique et non renouvelable. Pour en publier une autre, coche au moins une option de diffusion (payante).';
    if (/limite_du_jour/.test(m)) return 'Trop d\'annonces envoyées aujourd\'hui. Réessaie demain.';
    if (/gratuite_terminee/.test(m)) return 'L\'offre gratuite est terminée. Contacte-nous pour annoncer.';
    if (e?.code === 'functions/invalid-argument') return m.replace(/^.*?:\s*/, '') || 'Vérifie les champs de ton annonce.';
    return friendly(e, 'Impossible d\'envoyer l\'annonce pour le moment. Réessaie.');
  };
  $('#adform').addEventListener('submit', async (ev) => {
    ev.preventDefault(); err(''); status('');
    if (step < 4) { $('#f-next').click(); return; }   // « Entrée » dans un champ : on passe à l'étape suivante
    if (!IS_ADMIN && !pst.profile) { tab('profil'); return err('Avant ta première annonce, complète ton profil de marque : nom et logo.'); }
    if (!IS_ADMIN && pst.profile.logoStatus !== 'approved') { tab('profil'); return err(pst.profile.logoStatus === 'rejected' ? 'Ton profil a été refusé : corrige-le puis renvoie-le.' : 'Ton profil est en cours de validation : tu pourras publier ta première annonce dès qu’il est validé (tu recevras un e-mail).'); }
    for (const n of [2, 3, 4]) { const m = validate(n); if (m) { showStep(n); return err(m); } }
    const title = $('#f-title').value.trim(), text = $('#f-text').value.trim(), link = $('#f-link').value.trim(), dif = diffusion();
    if (dif.paid && !IS_OFFERED) {   // solde annonceur : si le total dépasse le solde, on propose la recharge du montant manquant
      const need = dif.total - (wal.data ? wal.data.balanceXof : 0);
      if (need > 0) { err(''); refreshMode(); $('#f-need').scrollIntoView({ block: 'center', behavior: 'smooth' }); openTopup(need); return; }
    }
    const btn = $('#f-send'); btn.disabled = true; const label = btn.textContent;
    try {
      btn.textContent = 'Envoi des fichiers…';
      const regions = st.countries.has('AFRICA') ? ['AFRICA'] : [];
      const payload = { type: st.type, title, text, category: $('#f-cat').value, countries: [...st.countries].filter((c) => c !== 'AFRICA'), regions, languages: [...st.langs], devices: [...st.devs], categories: [...st.types], [tel() ? 'phone' : 'link']: link };
      if (st.isVideo) {
        const f = st.files[0]; payload.mediaType = 'video'; payload.videoDuration = st.duration;
        payload.videoUrl = await put('ad_videos', f, f.type === 'video/quicktime' ? 'mov' : 'mp4', f.type);
        try { payload.thumbnailUrl = await put('ad_thumbnails', await frame(f), 'jpg', 'image/jpeg'); } catch { /* la miniature est facultative */ }
      } else {
        payload.mediaType = 'image'; payload.images = [];
        for (const f of st.files) payload.images.push(await put('ad_images', await shrink(f), 'jpg', 'image/jpeg'));
      }
      const bk = Object.keys(st.banners);
      if (bk.length) { payload.banners = {}; for (const k of bk) { const f = st.banners[k]; payload.banners[k] = await put('ad_images', f, f.type === 'image/png' ? 'png' : f.type === 'image/webp' ? 'webp' : 'jpg', f.type); } }
      btn.textContent = 'Envoi de l\'annonce…';
      if (TYPES[st.type].price) payload.price = Number($('#f-price').value);
      if (dif.app.on) payload.budgetApp = dif.app.v;
      if (dif.net.on) payload.budgetNetwork = dif.net.v;
      if (dif.sh.on) { payload.shareAudience = dif.sh.v; if (IS_OFFERED && $('#f-sbrand').value.trim()) payload.brand = $('#f-sbrand').value.trim(); }
      if (dif.app.on || dif.net.on) payload.days = Number($('#f-days').value);
      const done = await call('adsWebCreate', payload);
      loadWallet();
      $('#adform').reset(); st.banners = {}; $$('.bnrow .bt').forEach((t) => { t.textContent = ''; t.className = 'bt'; }); st.langs.clear(); st.devs.clear(); st.types.clear(); $$('#f-langs span, #f-devs span, #f-types span').forEach((x) => x.classList.remove('on')); st.countries = new Set(['ALL']); $$('#f-countries span').forEach((x) => x.classList.toggle('on', x.dataset.v === 'ALL')); $('#f-cat-note').hidden = true; st.files = []; $('#f-file-name').textContent = 'Choisis une image ou une vidéo'; refresh();
      status(dif.paid && IS_OFFERED ? 'Annonce envoyée, offerte par l’équipe : aucun débit. Elle démarre dès sa validation.' : (dif.paid ? 'Annonce envoyée et payée avec ton solde (' + nf(dif.total) + ' F). Elle démarre dès sa validation par notre équipe ; si elle est refusée, tu es remboursé en entier, et le budget non dépensé te revient à la fin.' : 'Annonce envoyée ! Notre équipe la valide, tu recevras un e-mail dès qu\'elle est en ligne.'));
      showStep(1); refreshMode();
      tab('mes');
    } catch (e) { err(explain(e)); } finally { btn.disabled = false; btn.textContent = label; }
  });

  // ─── profil de marque : nom, secteur, pays, contact et LOGO (obligatoire pour publier ; le logo validé est affiché comme partenaire) ───
  const pst = { profile: null, blob: null, ext: 'png', type: 'image/png', preview: '' };
  const perr = (m) => { const e = $('#perr'); if (e) { e.hidden = true; e.textContent = ''; } if (m) showError(m); };
  const logoShow = (src) => $('#logo-pv').replaceChildren(src ? h('img', { src, alt: 'Logo de ta marque' }) : h('span', { text: 'Logo' }));
  const logoBadge = { pending: ['wait', 'Profil en validation'], approved: ['ok', 'Profil validé'], rejected: ['rej', 'Profil refusé'] };
  function showProfile(p) {
    pst.profile = p;
    $('#profbadge').textContent = p ? (p.logoStatus === 'approved' ? '✓' : '…') : '!';
    profBanner('adv', p ? ({ pending: 'pending', approved: 'ok', rejected: 'rej' })[p.logoStatus] || 'pending' : 'none', p && p.logoReason);
    if (!p) return;
    $('#f-brand').value = p.brandName || ''; $('#f-sector').value = p.sector && p.sector !== 'autre' ? p.sector : ''; $('#f-pcountry').value = p.country || 'TG'; $('#f-city').value = p.city || '';
    $('#f-site').value = p.website || ''; $('#f-wa').value = p.whatsapp || ''; $('#f-about').value = p.about || ''; $('#f-consent').checked = !!p.partnerConsent;
    logoShow(p.logoUrl);
    const [cls, lab] = logoBadge[p.logoStatus] || ['end', '']; const bd = $('#logo-st'); bd.hidden = !lab; bd.className = 'st ' + cls; bd.textContent = lab;
    const why = $('#logo-why'); why.hidden = p.logoStatus !== 'rejected' || !p.logoReason; why.textContent = p.logoReason ? 'Motif : ' + p.logoReason : '';
  }
  async function loadProfile() {
    try {
      const d = await call('adsAdvMe'); showProfile(d.profile);
      if (!d.profile) { tab('profil'); status('Bienvenue ! Avant ta première annonce, complète ton profil de marque : nom et logo.', false, true); }
    } catch (e) { status(friendly(e, 'Impossible de charger ton profil pour le moment. Recharge la page.'), true); }
  }
  $('#f-logo').addEventListener('change', async (e) => {
    perr('');
    const f = e.target.files[0]; if (!f) return;
    if (!/^image\/(png|jpeg|webp)$/.test(f.type)) return perr('Choisis une image PNG, JPG ou WebP.');
    try { const o = await logoBlob(f); pst.blob = o.blob; pst.ext = o.ext; pst.type = o.type; if (pst.preview) URL.revokeObjectURL(pst.preview); pst.preview = URL.createObjectURL(o.blob); logoShow(pst.preview); }
    catch { pst.blob = null; perr('Image illisible ou trop petite (64 px au moins). Essaie un autre fichier.'); }
  });
  $('#adprof').addEventListener('submit', async (ev) => {
    ev.preventDefault(); perr('');
    const v = { brandName: $('#f-brand').value.trim(), sector: $('#f-sector').value, country: $('#f-pcountry').value, city: $('#f-city').value.trim(), website: $('#f-site').value.trim(), whatsapp: $('#f-wa').value.trim(), about: $('#f-about').value.trim(), partnerConsent: $('#f-consent').checked };
    if (v.brandName.length < 2) return perr('Ajoute le nom de ta marque.');
    if (v.whatsapp.replace(/[^\d]/g, '').length < 8) return perr('Ajoute ton numéro WhatsApp avec l\'indicatif : c\'est ton contact.');
    if (v.about.length < 20) return perr('Explique ce que fait ta marque (20 caractères au moins).');
    if (!pst.blob && !(pst.profile && pst.profile.logoUrl)) return perr('Ajoute le logo de ta marque.');
    if (!v.partnerConsent) return perr('Coche l\'accord d\'affichage du logo comme partenaire.');
    const btn = $('#p-send'); btn.disabled = true; const label = btn.textContent;
    try {
      v.logoUrl = pst.profile && pst.profile.logoUrl;
      if (pst.blob) { btn.textContent = 'Envoi du logo…'; v.logoUrl = await upload(pst.blob, pst.type); }
      btn.textContent = 'Enregistrement…';
      const r = await call('adsAdvSaveProfile', v);
      pst.blob = null;
      await loadProfile();
      status(r.logoStatus === 'approved' ? 'Profil enregistré.' : 'Profil envoyé : il est en validation par notre équipe. Tu pourras publier ta première annonce dès qu’il est validé (e-mail).');
      tab('creer');
    } catch (e) {
      const m = String(e && e.message || '');
      perr(e && e.code === 'functions/invalid-argument' ? (m.replace(/^.*?:\s*/, '') || 'Vérifie les champs.') : friendly(e, 'Impossible d\'enregistrer le profil pour le moment. Réessaie.'));
    } finally { btn.disabled = false; btn.textContent = label; }
  });

  // mes annonces
  const badge = { validation: ['wait', 'En validation'], ligne: ['ok', 'En ligne'], refusee: ['rej', 'Refusée'], arretee: ['end', 'Arrêtée'], terminee: ['end', 'Terminée'] };
  /** Chiffres clés de l'annonceur : annonces affichées ET campagnes Partage (les deux alimentent le même bandeau). */
  function drawAdvKpis() {
    const d = st.mine, sh = st.shares || [];
    if (!d) return;
    $('#mycount').textContent = d.items.length + sh.length;   // l'onglet « Mes annonces » montre les annonces ET les campagnes Partage : le badge les compte toutes
    const live = d.items.filter((a) => a.status === 'ligne'), wait = d.items.filter((a) => a.status === 'validation'), stats = d.items.filter((a) => a.status !== 'validation');
    const views = stats.reduce((x, a) => x + (a.views || 0), 0), clicks = stats.reduce((x, a) => x + (a.clicks || 0), 0);
    const shLive = sh.filter((c) => c.status === 'active'), shWait = sh.filter((c) => c.status === 'pending');
    const online = live.length + shLive.length, waiting = wait.length + shWait.length;
    const goMine = () => $('.adtabs a[data-tab="mes"]').click();
    const bal = wal.data ? wal.data.balanceXof : null;
    $('#advkpis').replaceChildren(
      kpiCard('Solde annonceur', bal === null ? '—' : nf(bal) + ' F', bal === null ? 'Complète d’abord ton profil' : (bal > 0 ? 'Recharger' : 'Recharge-le pour lancer une campagne'), bal ? 'ok' : '', () => (bal === null ? tab('profil') : openTopup(0))),
      kpiCard('En ligne', n(online), online ? 'annonces et campagnes diffusées' : 'aucune pour l’instant', online ? 'ok' : '', goMine),
      kpiCard('En attente', n(waiting), waiting ? 'validation par l’équipe sous 48 h' : 'rien en attente', waiting ? 'wait' : '', goMine),
      kpiCard('Vues', n(views), `${n(clicks)} clic${clicks > 1 ? 's' : ''}`));
  }
  // ───────── solde annonceur (FCFA) : séparé des pièces et des gains de l'application ─────────
  const kindLab = { topup: 'Recharge', spend: 'Campagne payée', refund: 'Remboursement', adjustment: 'Ajustement' };
  async function loadWallet() {
    try { wal.data = await call('adsWalletMe'); wal.per1000 = wal.data.sharePricePer1000 || wal.per1000; }
    catch { wal.data = null; }
    drawAdvKpis(); drawWallet(); window.dispatchEvent(new Event('afl-wallet'));
  }
  function drawWallet() {
    const d = wal.data;
    $('#wal-bal').textContent = d ? nf(d.balanceXof) + ' F' : '—';
    $('#wal-tx').replaceChildren(...(!d ? [h('p', { class: 'adempty', text: 'Complète d’abord ton profil de marque : ton solde est créé ensuite.' })]
      : d.transactions.length ? d.transactions.map((t) => h('div', { class: 'waltx-r' },
        h('div', {}, h('b', { text: t.description }), h('small', { text: kindLab[t.kind] + ' · ' + new Date(t.createdAt).toLocaleString('fr-FR', { dateStyle: 'medium', timeStyle: 'short' }) })),
        h('div', { class: 'waltx-a ' + (t.amountXof > 0 ? 'pos' : 'neg') }, h('b', { text: (t.amountXof > 0 ? '+' : '−') + nf(Math.abs(t.amountXof)) + ' F' }), h('small', { text: 'Solde : ' + nf(t.balanceAfter) + ' F' }))))
        : [h('p', { class: 'adempty', text: 'Aucun mouvement pour l’instant. Recharge ton solde pour lancer ta première campagne.' })]));
  }
  const topDlg = $('#adtopup'), tp = { method: 'momo', key: '', timer: 0, quoteT: 0, busy: false };
  // traitement en cours : bouton « Payer » grisé avec une roue qui tourne, pour qu'on ne le touche pas deux fois
  const setTopBusy = (on, label) => { tp.busy = on; const go = $('#top-go'); go.disabled = on; go.classList.toggle('busy', on); go.setAttribute('aria-busy', on ? 'true' : 'false'); go.textContent = on ? (label || 'Traitement en cours…') : 'Payer'; };
  // raisons d'échec renvoyées par l'opérateur : message clair (les autres s'affichent telles quelles)
  const payFail = (code) => ({ PAYER_NOT_FOUND: 'Ce numéro est introuvable chez l’opérateur choisi. Vérifie que le numéro correspond bien à cet opérateur et à son pays (ex. un numéro togolais avec Togocom ou Moov Togo, pas MTN Bénin).' }[String(code || '').toUpperCase()] || null);
  const topErr = (m) => { const e = $('#top-err'); if (e) { e.hidden = true; e.textContent = ''; } if (m) showError(m); };
  const topExplain = (e) => {
    const m = String((e && e.message) || '');
    const map = { otp_required: 'Ajoute le code OTP généré sur ton téléphone (Orange Burkina Faso).', terms_required: 'Accepte les conditions pour payer par carte.', card_identity_required: 'Complète ton identité et ton adresse.', phone_required: 'Ajoute ton numéro de téléphone.',
      provider_refused: 'L’opérateur a refusé la demande. Vérifie le numéro et l’opérateur, puis réessaie.', provider_unavailable: 'Le paiement par carte est indisponible pour le moment. Réessaie plus tard.', card_blocked: 'La carte est désactivée sur ce compte : utilise le Mobile Money.',
      card_disabled: 'Le paiement par carte est désactivé pour le moment.', limite_du_jour: 'Trop de recharges aujourd’hui. Réessaie demain.', montant_invalide: 'Entre un montant de 1 000 à 2 000 000 F.', email_required: 'Ton compte doit avoir une adresse e-mail.', profil_manquant: 'Complète d’abord ton profil de marque.' };
    const k = Object.keys(map).find((x) => m.includes(x));
    return k ? map[k] : 'Impossible de lancer la recharge pour le moment. Réessaie.';
  };
  const topQuote = () => {
    clearTimeout(tp.quoteT);
    tp.quoteT = setTimeout(async () => {
      const amount = Number($('#top-amt').value) || 0, box = $('#top-quote');
      box.querySelector('b').textContent = '…'; box.querySelector('small').textContent = '';
      try {
        const q = await call('adsWalletQuote', { amountXof: amount, method: tp.method, operator: $('#top-op').value });
        // le montant payé (frais compris) n'est affiché qu'au moment de payer, sur le téléphone ou la page de paiement : ici, seulement ce qui arrive sur le solde
        box.querySelector('b').textContent = nf(q.creditedXof) + ' F seront ajoutés à ton solde';
        box.querySelector('small').textContent = tp.method === 'card' ? 'Le montant à payer s’affiche sur la page de paiement sécurisée.' : 'Tu valides le paiement sur ton téléphone : le montant demandé par ton opérateur inclut les frais de paiement.';
      } catch (e) { box.querySelector('b').textContent = '—'; box.querySelector('small').textContent = topExplain(e); }
    }, 250);
  };
  const setMethod = (m) => {
    tp.method = m; $$('#top-method label').forEach((l) => l.classList.toggle('on', l.dataset.v === m));
    $('#top-momo').hidden = m !== 'momo'; $('#top-card').hidden = m !== 'card'; topErr(''); topQuote();
  };
  function openTopup(need) {
    if (!wal.data) { tab('profil'); status('Complète d’abord ton profil de marque : ton solde est créé ensuite.', true); return; }
    const o = wal.data.options, op = $('#top-op');
    if (!op.options.length) { op.replaceChildren(...o.operators.map((x) => h('option', { value: x.code, text: x.label }))); }
    $('#top-method label[data-v="card"]').hidden = !o.card.enabled;
    tp.key = ''; topErr(''); $('#top-wait').hidden = true; setTopBusy(false);
    const nb = $('#top-need');
    nb.hidden = !(need > 0); nb.textContent = need > 0 ? 'Il te manque ' + nf(need) + ' F pour cette campagne. Montant proposé : de quoi la payer.' : '';
    if (need > 0) $('#top-amt').value = String(Math.min(o.maxXof, Math.max(o.minXof, Math.ceil(need / 500) * 500)));
    $('#top-otp-l').hidden = !(o.operators.find((x) => x.code === op.value) || {}).otp;
    setMethod('momo');
    if (!topDlg.open) topDlg.showModal();
  }
  async function pollTopup(id, tries = 0) {
    clearTimeout(tp.timer);
    try {
      const r = await call('adsWalletTopupStatus', { id });
      if (r.status === 'paid') { try { sessionStorage.removeItem('adtopup'); } catch { /* sans stockage */ } if (topDlg.open) topDlg.close(); status('Recharge confirmée : ' + nf(r.creditedXof) + ' F ajoutés à ton solde.'); loadWallet(); return; }
      if (r.status === 'failed' || r.status === 'expired') { try { sessionStorage.removeItem('adtopup'); } catch { /* sans stockage */ } tp.key = ''; setTopBusy(false); $('#top-wait').hidden = true; topErr(payFail(r.failure) || ('Le paiement n’a pas abouti' + (r.failure ? ' (' + r.failure + ')' : '') + '. Tu peux réessayer.')); return; }
    } catch { /* on réessaie */ }
    if (tries < 75) tp.timer = setTimeout(() => pollTopup(id, tries + 1), 4000);
    else { setTopBusy(false); $('#top-wait').textContent = 'Toujours en attente. Si tu as validé le paiement, ton solde sera crédité dès confirmation : reviens dans quelques minutes.'; }
  }
  if (topDlg) {
    $('#adtopup-x').addEventListener('click', () => { clearTimeout(tp.timer); topDlg.close(); });
    topDlg.addEventListener('click', (e) => { if (e.target === topDlg) { clearTimeout(tp.timer); topDlg.close(); } });
    $$('#top-quick span').forEach((x) => x.addEventListener('click', () => { $('#top-amt').value = x.dataset.v; topQuote(); }));
    $$('#top-method label').forEach((l) => l.addEventListener('click', () => setMethod(l.dataset.v)));
    $('#top-amt').addEventListener('input', topQuote);
    $('#top-op').addEventListener('change', () => { const o = wal.data && wal.data.options.operators.find((x) => x.code === $('#top-op').value); $('#top-otp-l').hidden = !(o && o.otp); topQuote(); });
    $('#wal-topup').addEventListener('click', () => openTopup(0));
    $('#topform').addEventListener('submit', async (ev) => {
      ev.preventDefault(); topErr('');
      if (tp.busy) return;   // déjà en cours : un second toucher ne fait rien
      const amount = Number($('#top-amt').value) || 0;
      if (amount < 1000) return topErr('Entre un montant de 1 000 F au moins.');
      tp.key = tp.key || (crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2) + Date.now().toString(36)).replace(/[^A-Za-z0-9-]/g, '');
      const body = { amountXof: amount, method: tp.method, key: tp.key };
      if (tp.method === 'momo') Object.assign(body, { operator: $('#top-op').value, phone: $('#top-phone').value.trim(), otp: $('#top-otp').value.trim() });
      else Object.assign(body, { terms: $('#top-terms').checked, firstName: $('#top-fn').value.trim(), lastName: $('#top-ln').value.trim(), city: $('#top-city').value.trim(), zip: $('#top-zip').value.trim(), country: $('#top-cc').value.trim(), phone: $('#top-cphone').value.trim() });
      setTopBusy(true, 'Envoi du paiement…');
      try {
        const r = await call('adsWalletTopup', body);
        try { sessionStorage.setItem('adtopup', r.id); } catch { /* sans stockage */ }
        if (tp.method === 'card' && r.paymentUrl) { $('#top-wait').hidden = false; $('#top-wait').textContent = 'Ouverture de la page de paiement sécurisée…'; setTopBusy(true, 'Ouverture du paiement…'); location.href = r.paymentUrl; return; }
        $('#top-wait').hidden = false; $('#top-wait').textContent = (r.message || 'Valide le paiement sur ton téléphone') + '. Cette fenêtre se met à jour toute seule.';
        setTopBusy(true, 'En attente de ta validation…');
        pollTopup(r.id);
      } catch (e) { setTopBusy(false); tp.key = /provider|otp|terms|identity|phone/.test(String((e && e.message) || '')) ? '' : tp.key; topErr(topExplain(e)); }
    });
    // retour de la page de paiement par carte : on vérifie la recharge en cours
    try { const pend = sessionStorage.getItem('adtopup'); if (pend) { status('Vérification de ta recharge…', false, true); pollTopup(pend, 60); } } catch { /* sans stockage */ }
  }

  async function loadMine() {
    try {
      const d = await call('adsWebMine');
      st.open = d.open; st.left = Math.max(0, d.max - d.used);
      $('#mycount').textContent = d.items.length + (st.shares || []).length; $('#myquota').textContent = `${d.used} gratuite${d.used > 1 ? 's' : ''} utilisée${d.used > 1 ? 's' : ''} sur ${d.max}`;
      st.mine = d; refreshMode();
      st.mine = d; drawAdvKpis();   // chiffres clés, visibles sans ouvrir d'onglet
      const box = $('#mylist'); box.replaceChildren();
      if (!d.items.length) { box.append(h('p', { class: 'adempty', text: 'Tu n\'as pas encore d\'annonce. Crée la première, c\'est gratuit.' })); return; }
      const doAct = (name, id, okMsg) => async () => { try { await call(name, { id }); status(okMsg); } catch (er) { status(/paiement_requis/.test(String(er?.message)) ? 'Limite de prolongations gratuites atteinte : l’offre payante Afrolook Ads arrive bientôt.' : friendly(er, 'Action impossible pour le moment.'), true); throw er; } finally { loadMine(); } };
      for (const a of d.items) {
        const [cls, lab] = badge[a.status] || ['end', a.status];
        const thumb = a.thumb || a.media ? h('img', { class: 'addash-th', src: a.thumb || a.media, alt: '', loading: 'lazy' }) : h('i', { class: 'addash-th ph', text: initial(a) });
        const meta = `${a.action} · ${a.days} jours${a.budgetApp ? ` · Afrolook ${n(a.spentApp)} / ${n(a.budgetApp)} F` : ''}${a.budgetNet ? ` · Partenaires ${n(a.spentNet)} / ${n(a.budgetNet)} F` : ''}${a.shareId ? ' · Partage au clic' : ''}${a.refunded ? ` · ${n(a.refunded)} F remboursés` : ''}${a.networkRequested && !a.budgetNet ? (a.network ? ' · Offre Réseau' : ' · Offre Réseau demandée (payante)') : ''}${a.status === 'ligne' ? ` · ${a.daysLeft} jour${a.daysLeft > 1 ? 's' : ''} restant${a.daysLeft > 1 ? 's' : ''}` : ''}${a.renewals ? ` · renouvelée ${a.renewals} fois` : ''}`;
        const row = h('div', { class: 'addash-r', 'data-id': a.id, tabindex: '0', role: 'button', 'aria-label': `Voir le détail : ${a.title}` },
          h('div', { class: 'addash-main' }, thumb, h('div', {}, h('b', { text: a.title }), imgCount(a) > 1 ? h('span', { class: 'adc-tag-s adsl-mine', text: `${imgCount(a)} photos` }) : null, h('small', { text: meta }), h('small', { class: 'st-m', text: a.status === 'validation' ? 'Pas encore de statistiques' : `${n(a.views)} vues · ${n(a.clicks)} clics` }))),
          h('span', { class: `st ${cls}`, text: lab }),
          h('span', { class: 'n', text: a.status === 'validation' ? '—' : `${n(a.views)} vues` }), h('span', { class: 'n', text: a.status === 'validation' ? '—' : `${n(a.clicks)} clics` }));
        const opt = { mine: true, onRenew: doAct('adsWebRenew', a.id, 'Annonce renouvelée : elle est de nouveau en ligne pour 14 jours.'), onStop: doAct('adsWebStop', a.id, 'Annonce arrêtée.'), onDelete: doAct('adsWebDelete', a.id, 'Annonce supprimée.') };
        row.addEventListener('click', () => openDetail(a, opt));
        row.addEventListener('keydown', (e) => { if ((e.key === 'Enter' || e.key === ' ') && e.target === row) { e.preventDefault(); openDetail(a, opt); } });
        box.append(row);
      }
    } catch {
      $('#advkpis').replaceChildren(kpiCard('Tes chiffres', '—', 'indisponibles pour le moment', 'alert', () => loadMine()));
      $('#mylist').replaceChildren(h('p', { class: 'adempty', text: 'Impossible de charger tes annonces pour le moment.' }));
    }
  }
  refresh();
}

// ───────── partenaires et audience du réseau (page /ads/) ─────────
const wallDyn = $('#adpartners-dyn');
if (wallDyn) {
  fetch(wallDyn.dataset.api).then((r) => r.json()).then(({ items = [] }) => {
    for (const p of items) {
      if (!String(p.logo).startsWith('https://')) continue;
      const href = p.url ? safeUrl(p.url) : '';
      wallDyn.append(h(href ? 'a' : 'div', { class: 'adpart', title: p.name + (p.kind === 'publisher' ? ' · diffuseur' : p.kind === 'advertiser' ? ' · annonceur' : ''), href: href || false, target: href ? '_blank' : false, rel: href ? 'nofollow sponsored noopener' : false }, h('img', { src: p.logo, alt: p.name, width: 56, height: 56, loading: 'lazy' }), h('span', { text: p.name })));
    }
  }).catch(() => {});
  // l'audience « plus de X » est mise à jour par site.js (data-aud), la même sur tout le site
}

// ───────── espace diffuseur ─────────
if ($('#pubspace')) initPub();

async function initPub() {
  const status = setStatus;
  const fb = await boot(() => load());
  if (!fb) return;
  const { call, upload } = fb;
  const st = { profile: null, props: [], kind: 'site', type: 'individual', countries: new Set(['TG']) };
  const perr = (m) => { const e = $('#perr'); if (e) { e.hidden = true; e.textContent = ''; } if (m) showError(m); };
  const qerr = (m) => { const e = $('#qerr'); if (e) { e.hidden = true; e.textContent = ''; } if (m) showError(m); };
  $('#p-country').replaceChildren(...sortedCountries().map(([c, nm]) => h('option', { value: c, text: nm }))); $('#p-country').value = 'TG';   // pays du profil : tous les pays du monde
  const renderQCountries = countryPick($('#q-countries'), () => st.countries);
  const tab = (t) => { $$('.adtabs a').forEach((a) => a.classList.toggle('on', a.dataset.tab === t)); $('#tab-profil').hidden = t !== 'profil'; $('#tab-sites').hidden = t !== 'sites'; $('#tab-gains').hidden = t !== 'gains'; if (t === 'gains') loadGains(); };
  $$('.adtabs a').forEach((a) => a.addEventListener('click', (e) => { e.preventDefault(); tab(a.dataset.tab); }));
  const toggle = (box, cb) => $$('label', $(box)).forEach((l) => l.addEventListener('click', () => { $$('label', $(box)).forEach((x) => x.classList.toggle('on', x === l)); cb(l.dataset.v); }));
  toggle('#p-type', (v) => { st.type = v; });
  // logo du diffuseur : obligatoire, affiché sur les pages de partenaires une fois le profil validé
  const plogo = { blob: null, type: '', preview: null };
  const plogoShow = (src) => $('#pl-pv').replaceChildren(src ? h('img', { src, alt: 'Ton logo' }) : h('span', { text: 'Logo' }));
  $('#p-logo').addEventListener('change', async (e) => {
    perr('');
    const f = e.target.files[0]; if (!f) return;
    if (!/^image\/(png|jpeg|webp)$/.test(f.type)) return perr('Choisis une image PNG, JPG ou WebP.');
    try { const o = await logoBlob(f); plogo.blob = o.blob; plogo.type = o.type; if (plogo.preview) URL.revokeObjectURL(plogo.preview); plogo.preview = URL.createObjectURL(o.blob); plogoShow(plogo.preview); }
    catch { plogo.blob = null; perr('Image illisible ou trop petite (64 px au moins). Essaie un autre fichier.'); }
  });
  $('#p-rules-accept').addEventListener('click', async () => { try { await call('adsPubAcceptRules', { version: $('#pubspace').dataset.rules }); status('Règles acceptées. Merci !'); load(); } catch (e) { status(friendly(e, 'Impossible d\'enregistrer ton acceptation pour le moment.'), true); } });
  toggle('#q-kind', (v) => { st.kind = v; $('#q-site').hidden = v !== 'site'; $('#q-app').hidden = v !== 'app'; });
  // image du site ou de l'application : obligatoire (logo, capture d'écran ou autre) ; réduite comme le logo
  const qimg = { blob: null, type: '', preview: null, url: '' };
  const qimgShow = (src) => $('#qi-pv').replaceChildren(src ? h('img', { src, alt: 'Image du site ou de l\u2019application' }) : h('span', { text: 'Image' }));
  $('#q-img').addEventListener('change', async (e) => {
    const f = e.target.files[0]; if (!f) return;
    if (!/^image\/(png|jpeg|webp)$/.test(f.type)) return qerr('Choisis une image PNG, JPG ou WebP.');
    try { const o = await logoBlob(f); qimg.blob = o.blob; qimg.type = o.type; qimg.url = ''; if (qimg.preview) URL.revokeObjectURL(qimg.preview); qimg.preview = URL.createObjectURL(o.blob); qimgShow(qimg.preview); }
    catch { qimg.blob = null; qerr('Image illisible ou trop petite (64 px au moins). Essaie un autre fichier.'); }
  });

  const stLab = { pending: ['wait', 'En validation'], active: ['ok', 'Validé'], refused: ['rej', 'Refusé'], suspended: ['rej', 'Suspendu'] };
  const profState = { pending: 'Profil en validation par notre équipe', active: 'Profil validé', refused: 'Profil refusé', suspended: 'Profil suspendu' };
  function fillProfile() {
    const p = st.profile;
    $('#pbadge').textContent = p ? (p.status === 'active' ? '✓' : '…') : '!';
    profBanner('pub', p ? ({ pending: 'pending', active: 'ok', refused: 'rej', suspended: 'suspended' })[p.status] || 'pending' : 'none', p && p.reason);
    if (!p) return;
    $('#p-name').value = p.name || ''; $('#p-country').value = p.country || 'TG'; $('#p-city').value = p.city || ''; $('#p-phone').value = p.phone || ''; $('#p-web').value = p.website || ''; $('#p-about').value = p.about || ''; $('#p-terms').checked = true; plogoShow(p.logoUrl); $('#p-consent').checked = !!p.logoUrl;
    $('#pl-need').hidden = !!p.logoUrl;
    st.type = p.type === 'company' ? 'company' : 'individual'; $$('#p-type label').forEach((l) => l.classList.toggle('on', l.dataset.v === st.type));
    $('#p-state').textContent = profState[p.status] || 'Profil'; $('#p-send').textContent = p.status === 'refused' ? 'Renvoyer mon profil' : 'Mettre à jour';
    if (p.status === 'refused' && p.reason) perr('Motif du refus : ' + p.reason);
  }
  const copy = async (text, btn) => { try { await navigator.clipboard.writeText(text); } catch { const t = h('textarea', { value: text }); document.body.append(t); t.select(); try { document.execCommand('copy'); } catch { /* copie impossible */ } t.remove(); } const o = btn.textContent; btn.textContent = 'Copié'; setTimeout(() => { btn.textContent = o; }, 1600); };
  // catégories d'annonces acceptées : le diffuseur coche ce qu'il accepte d'afficher chez lui (les sensibles ne s'affichent jamais sans son accord)
  function catsBlock(p) {
    const box = h('details', { class: 'adfold pubcats' }, h('summary', { text: `Catégories d'annonces acceptées (${(p.acceptedCategories || []).length})` }));
    const acc = new Set(p.acceptedCategories || []);
    const pick = h('div', { class: 'catpick' }, h('div', { class: 'catpick-store', hidden: true },
      ...Object.entries(st.cats).map(([k, c]) => h('input', { type: 'checkbox', value: k, checked: acc.has(k), 'data-lvl': c.level, 'data-label': c.label, 'data-hint': c.hint || false }))));
    catPick(pick);
    box.append(pick,
      h('div', { class: 'logo-r' }, h('button', { class: 'btn btn-primary adsm', type: 'button', text: 'Enregistrer mes catégories', onclick: async (e) => {
        const list = $$('input:checked', box).map((i) => i.value); if (!list.length) return status('Choisis au moins une catégorie.', true);
        const b = e.currentTarget; b.disabled = true;
        try { await call('adsPubUpdateProperty', { id: p.id, acceptedCategories: list }); status('Catégories enregistrées.'); load(); } catch (e) { status(friendly(e, 'Enregistrement impossible pour le moment.'), true); } finally { b.disabled = false; }
      } })));
    return box;
  }

  // audience réelle mesurée par Afrolook sur 60 jours, comparée à l'audience déclarée
  const gapText = { no_data: 'Mesure en cours : il faut au moins 7 jours de données pour comparer avec ta déclaration.', conform: 'Conforme : l\'audience mesurée correspond à ta déclaration.', below: 'En dessous de ta déclaration : l\'audience mesurée est plus faible que celle annoncée.', far_below: 'Très en dessous de ta déclaration : un écart important et durable peut entraîner un ajustement de l\'audience retenue, voire une suspension.', above: 'Au-dessus de ta déclaration : tu peux mettre à jour ton audience déclarée.' };
  const gapCls = { no_data: 'wait', conform: 'ok', below: 'wait', far_below: 'rej', above: 'ok' };
  function renderStats(box, s) {
    box.replaceChildren();
    const r = s.report, max = Math.max(1, ...s.series.map((d) => d.uniques));
    const kpi = (k, v) => h('div', { class: 'stk' }, h('b', { text: v }), h('small', { text: k }));
    box.append(
      h('div', { class: 'stgap' }, h('span', { class: 'st ' + gapCls[r.status], text: ({ no_data: 'En cours de mesure', conform: 'Conforme', below: 'En dessous', far_below: 'Très en dessous', above: 'Au-dessus' })[r.status] }), h('p', { text: gapText[r.status] })),
      h('div', { class: 'stgrid' }, kpi('Audience déclarée (par mois)', n(s.declared)), kpi('Audience retenue', n(s.counted)), kpi('Mesurée sur 30 jours', n(r.u30)), kpi('Mesurée sur 60 jours', n(r.u60)), kpi('Moyenne par jour (7 j)', n(r.perDay7)), kpi('Mesurée / déclarée', r.declared ? Math.round(r.ratio * 100) + ' %' : '—')),
      h('div', { class: 'stbar' }, h('i', { style: 'width:' + Math.min(100, Math.round(r.ratio * 100)) + '%' })),
      h('small', { class: 'stnote', text: 'Audience mesurée = personnes différentes pour lesquelles ta balise ou ton composant a été chargé (un visiteur qui revient ne compte qu\'une fois). Elle est comparée à ta déclaration sur les 30 derniers jours.' }),
      h('b', { class: 'sth', text: 'Visiteurs différents par jour (60 derniers jours)' }),
      h('div', { class: 'chart', role: 'img', 'aria-label': 'Visiteurs par jour sur 60 jours' }, ...s.series.map((d) => h('i', { title: `${d.day} : ${n(d.uniques)} visiteurs`, style: 'height:' + Math.max(2, Math.round(d.uniques / max * 100)) + '%' }))),
      h('div', { class: 'stgrid' }, kpi('Affichages valides (60 j)', n(s.totals.impressions60)), kpi('Trafic invalide (60 j)', n(s.totals.invalid60) + ' (' + (s.totals.invalidRate * 100).toFixed(1).replace('.', ',') + ' %)'), kpi('Appels depuis un autre domaine', n(s.totals.foreign60)), kpi('Rémunérable', s.payable ? 'Oui' : 'Pas encore')),
      h('small', { class: 'stnote', text: `Trafic invalide : moins de ${Math.round(s.thresholds.alert * 100)} % normal, de ${Math.round(s.thresholds.alert * 100)} à ${Math.round(s.thresholds.suspend * 100)} % alerte, plus de ${Math.round(s.thresholds.suspend * 100)} % emplacement suspendu. ${s.payable ? '' : 'Un site doit avoir sa preuve de propriété et une application doit être attestée avant d\'être rémunérée.'}` }));
    if (s.geo && s.geo.length) {
      box.append(h('b', { class: 'sth', text: 'D\'où viennent tes visiteurs (30 derniers jours)' }),
        h('div', { class: 'stgeo' }, ...s.geo.map((g) => h('span', { class: (s.declaredCountries || []).includes(g.cc) ? 'in' : '' }, `${g.cc} ${Math.round(g.share * 100)} %`))));
      if (s.declaredGeo && s.declaredGeo.total >= 200) box.append(h('small', { class: 'stnote', text: `${Math.round(s.declaredGeo.share * 100)} % de tes visiteurs viennent des pays que tu as annoncés (${(s.declaredCountries || []).join(', ')}).${s.declaredGeo.share < 0.6 ? ' Écart important : il est examiné par l\'équipe.' : ''}` }));
    }
  }
  function statsBlock(p) {
    const wrap = h('details', { class: 'adfold pubstats' }, h('summary', { text: 'Mes mesures : audience réelle sur 60 jours' }));
    const body = h('div', { class: 'statpanel' }, h('p', { class: 'adnote', text: 'Chargement…' })); wrap.append(body);
    wrap.addEventListener('toggle', async () => {
      if (!wrap.open || wrap.dataset.done) return; wrap.dataset.done = '1';
      try { renderStats(body, await call('adsPubStats', { id: p.id })); } catch (e) { wrap.dataset.done = ''; const why = friendly(e, 'Impossible de charger les mesures pour le moment.'); body.replaceChildren(h('p', { class: 'aderr', text: why })); showError(why); }
    });
    return wrap;
  }

  /** Chiffres clés du diffuseur : profil, sites validés, puis audience et trafic mesurés (60 jours) des sites validés. */
  async function pubKpis(d) {
    const box = $('#pubkpis'); if (!box) return;
    const props = d.properties || [], ok = props.filter((p) => p.status === 'active'), wait = props.filter((p) => p.status === 'pending');
    const prof = d.profile ? ({ active: ['Validé', 'ok'], pending: ['En validation', 'wait'], refused: ['Refusé', 'alert'], suspended: ['Suspendu', 'alert'] })[d.profile.status] || [d.profile.status, ''] : ['À créer', 'wait'];
    const base = [kpiCard('Mon profil', prof[0], d.profile ? '' : 'commence par ton profil', prof[1], () => $('.adtabs a[data-tab="profil"]').click()),
      kpiCard('Sites et applications', `${ok.length} / ${props.length}`, props.length ? `${ok.length} validé${ok.length > 1 ? 's' : ''}${wait.length ? ` · ${wait.length} en validation` : ''}` : 'aucun pour l\u2019instant', ok.length ? 'ok' : (wait.length ? 'wait' : ''), () => $('.adtabs a[data-tab="sites"]').click())];
    box.replaceChildren(...base, kpiCard('Affichages (60 j)', '…', 'calcul en cours'), kpiCard('Trafic invalide', '…', 'calcul en cours'));
    if (!ok.length) { box.replaceChildren(...base, kpiCard('Affichages (60 j)', '0', 'aucun site validé'), kpiCard('Trafic invalide', '—', 'aucun site validé')); return; }
    const res = await Promise.allSettled(ok.map((p) => call('adsPubStats', { id: p.id })));
    const good = res.filter((r) => r.status === 'fulfilled').map((r) => r.value);
    const imp = good.reduce((s, x) => s + ((x.totals && x.totals.impressions60) || 0), 0), bad = good.reduce((s, x) => s + ((x.totals && x.totals.invalid60) || 0), 0);
    box.replaceChildren(...base, kpiCard('Affichages (60 j)', good.length ? n(imp) : '—', good.length ? `sur ${good.length} site${good.length > 1 ? 's' : ''}` : 'mesures indisponibles', imp ? 'ok' : ''),
      kpiCard('Trafic invalide', good.length ? pct(bad, imp + bad) : '—', good.length ? `${n(bad)} affichage${bad > 1 ? 's' : ''} écarté${bad > 1 ? 's' : ''}` : '', good.length && imp + bad > 0 && bad / (imp + bad) > 0.1 ? 'alert' : ''));
  }

  function renderProps() {
    $('#pcount').textContent = st.props.length;
    const box = $('#plist'); box.replaceChildren();
    if (!st.props.length) { box.append(h('p', { class: 'adempty', text: st.profile ? 'Aucun site ni application pour l\'instant. Ajoute le premier avec le formulaire.' : 'Crée d\'abord ton profil, puis ajoute tes sites et applications.' })); return; }
    for (const p of st.props) {
      const [cls, lab] = stLab[p.status] || ['end', p.status];
      const where = p.kind === 'site' ? p.url : [p.androidUrl, p.iosUrl].filter(Boolean).join('  ');
      const imgFile = h('input', { type: 'file', accept: 'image/png,image/jpeg,image/webp', hidden: true });
      imgFile.addEventListener('change', async () => {
        const f = imgFile.files[0]; if (!f) return;
        if (!/^image\/(png|jpeg|webp)$/.test(f.type)) return showError('Choisis une image PNG, JPG ou WebP.');
        try { const o = await logoBlob(f); const url = await upload(o.blob, o.type); await call('adsPubUpdateProperty', { id: p.id, imageUrl: url }); status('Image enregistrée.'); load(); }
        catch (e) { showError(friendly(e, 'Image illisible, trop petite (64 px au moins) ou envoi impossible. Essaie un autre fichier.')); }
      });
      const card = h('article', { class: 'pubprop' },
        h('div', { class: 'pubprop-h' }, h('b', { text: p.name }), h('span', { class: 'st ' + cls, text: lab })),
        h('div', { class: 'pubprop-im' }, p.imageUrl ? h('img', { class: 'pubprop-img', src: p.imageUrl, alt: '', loading: 'lazy' }) : h('span', { class: 'pubprop-img ph', text: '?' }),
          h('div', {}, p.imageUrl ? null : h('small', { class: 'aderr', text: 'Ajoute une image de ce site ou de cette application.' }), h('button', { class: 'adlinkbtn', type: 'button', text: p.imageUrl ? 'Changer l\u2019image' : 'Ajouter une image', onclick: () => imgFile.click() }), imgFile)),
        h('small', { class: 'pubprop-w', text: (p.kind === 'site' ? 'Site web · ' : 'Application · ') + where }),
        h('div', { class: 'pubid' }, h('span', {}, h('small', { text: 'Identifiant publicitaire' }), h('code', { text: p.id })), h('button', { class: 'btn btn-line adsm', type: 'button', text: 'Copier', onclick: (e) => copy(p.id, e.currentTarget) })),
        h('p', { class: 'pubprop-a', text: `Audience déclarée : ${n(p.audienceMonthly)} par mois` + (p.status === 'active' ? ` · retenue : ${n(p.audienceCounted)}` : '') }));
      if (p.status === 'pending') card.append(h('p', { class: 'adnote', text: 'Notre équipe examine ta demande. Tu recevras un e-mail avec la décision.' }));
      if (p.status === 'refused' || p.status === 'suspended') card.append(h('p', { class: 'aderr', text: 'Motif : ' + (p.reason || 'non précisé') }));
      if (p.status === 'active') card.append(h('p', { class: 'adnote', text: 'Site ou application validé : l\'identifiant ci-dessus est le tien. La balise d\'intégration et les statistiques arrivent ici.' }));
      if (p.status === 'active' || p.status === 'pending' || p.status === 'suspended') card.append(statsBlock(p), catsBlock(p));
      if (p.kind === 'site' && p.status !== 'refused') {
        const vbox = h('div', { class: 'pubverify' });
        if (p.verified) vbox.append(h('small', { class: 'okline', text: '✓ Propriété du site vérifiée' }));
        else {
          vbox.append(h('small', { text: 'Preuve de propriété (facultative, rassure l\'équipe) : ajoute cette balise dans la page d\'accueil de ton site, ou ce code seul dans le fichier /afrolook-ads.txt, puis clique sur Vérifier.' }),
            h('code', { class: 'pubtag', text: `<meta name="afrolook-ads-verify" content="${p.verifyToken}">` }),
            h('div', { class: 'logo-r' }, h('button', { class: 'btn btn-line adsm', type: 'button', text: 'Vérifier', onclick: async (e) => {
              const b = e.currentTarget; b.disabled = true;
              try { const r = await call('adsPubVerifyProperty', { id: p.id }); status(r.verified ? 'Propriété vérifiée.' : 'Code introuvable sur ton site pour l\'instant. Vérifie la balise puis réessaie.', !r.verified); if (r.verified) load(); }
              catch (e) { status(friendly(e, 'Vérification impossible pour le moment.'), true); } finally { b.disabled = false; }
            } })));
        }
        card.append(vbox);
      }
      const del = h('button', { class: 'adlinkbtn', type: 'button', text: 'Retirer', onclick: () => {
        del.replaceWith(h('span', { class: 'confirm' }, 'Retirer ? ', h('button', { class: 'adlinkbtn danger', type: 'button', text: 'Oui', onclick: async () => { try { await call('adsPubDeleteProperty', { id: p.id }); load(); } catch (e) { status(friendly(e, 'Action impossible pour le moment.'), true); } } }), ' ', h('button', { class: 'adlinkbtn', type: 'button', text: 'Non', onclick: () => renderProps() })));
      } });
      card.append(h('div', { class: 'pubprop-f' }, del));
      box.append(card);
    }
  }

  // ───────── gains et retraits du diffuseur ─────────
  const FC = (v) => n(v) + ' F';
  const OPERATORS = ['T-Money (Togocel)', 'Flooz (Moov)', 'MTN MoMo', 'Orange Money', 'Wave', 'Autre'];
  const FMT_LAB = { banner: 'Bannière', sticky: 'Bandeau collant', native: 'Carte native', carousel: 'Carrousel', poster: 'Affiche', video: 'Vidéo dans le fil', interstitial: 'Interstitiel', rewarded: 'Récompensée' };
  const EARN_LAB = { held: 'En attente', available: 'Disponible', requested: 'Retrait demandé', paid: 'Payé' };
  const PAY_LAB = { requested: ['wait', 'Demandé'], paid: ['ok', 'Payé'], refused: ['rej', 'Refusé'] };
  $('#g-op').replaceChildren(...OPERATORS.map((o) => h('option', { value: o, text: o })));
  const gainErr = (e) => {
    const m = String((e && e.message) || '');
    if (/sous_le_minimum/.test(m)) return 'Il faut au moins 10 000 F disponibles pour demander un retrait.';
    if (/profil_non_valide/.test(m)) return 'Ton profil doit être validé par notre équipe avant un retrait.';
    if (e && e.code === 'functions/invalid-argument') return m.replace(/^.*?:\s*/, '') || 'Vérifie le numéro et l\u2019opérateur.';
    return friendly(e, 'Impossible d\u2019envoyer la demande de retrait pour le moment. Réessaie.');
  };
  let gst = null;
  function drawGains(g) {
    gst = g; $('#gcount').textContent = FC(g.availableFcfa);
    $('#g-kpis').replaceChildren(
      kpiCard('En attente', FC(g.pendingFcfa), `bloqués ${g.holdDays} jours`, g.pendingFcfa ? 'wait' : ''),
      kpiCard('Disponible', FC(g.availableFcfa), g.canRequest ? 'prêt à retirer' : `minimum ${FC(g.minPayoutFcfa)}`, g.canRequest ? 'ok' : ''),
      kpiCard('Retrait demandé', FC(g.requestedFcfa), 'en cours de paiement', g.requestedFcfa ? 'wait' : ''),
      kpiCard('Payé', FC(g.paidFcfa), 'déjà versé', g.paidFcfa ? 'ok' : ''),
      kpiCard('Réserve', FC(g.reserveFcfa), `${g.reservePct} % gardés ${g.reserveDays} jours`));
    $('#g-amount').textContent = FC(g.availableFcfa);
    const ok = st.profile && (st.profile.status === 'active');
    $('#g-sub').textContent = !ok ? 'Ton profil doit être validé pour retirer tes gains.' : g.canRequest ? 'Montant retiré : tous tes gains disponibles (net de la réserve).' : `Il faut au moins ${FC(g.minPayoutFcfa)} : il te manque ${FC(Math.max(0, g.minPayoutFcfa - g.availableFcfa))}.`;
    $('#g-send').disabled = !(ok && g.canRequest);
    const pb = $('#g-payouts'); pb.replaceChildren();
    if (!g.payouts.length) pb.append(h('p', { class: 'adempty', text: 'Aucune demande de retrait pour l\u2019instant.' }));
    for (const p of g.payouts) {
      const [cls, lab] = PAY_LAB[p.status] || ['end', p.status];
      pb.append(h('div', { class: 'gpay' }, h('div', {}, h('b', { text: FC(p.amountFcfa) }), h('small', { text: `${date2(p.createdAt)} · ${p.operator} · ${p.phone}` }),
        p.status === 'paid' ? h('small', { text: 'Référence : ' + p.reference }) : null, p.status === 'refused' ? h('small', { class: 'aderr', text: 'Motif : ' + (p.reason || 'non précisé') }) : null), h('span', { class: 'st ' + cls, text: lab })));
    }
    const db = $('#g-detail'); db.replaceChildren();
    if (!g.properties.length) { db.append(h('p', { class: 'adempty', text: 'Aucun site ni application pour l\u2019instant.' })); return; }
    const table = (head, rows) => h('div', { class: 'gscroll' }, h('table', { class: 'gtab' }, h('thead', {}, h('tr', {}, ...head.map((x) => h('th', { class: x[1] || false, text: x[0] })))), h('tbody', {}, ...rows)));
    db.append(table([['Site ou application'], ['Vues valides', 'r'], ['Gains nets', 'r']], g.properties.map((p) => h('tr', {}, h('td', { text: p.name }), h('td', { class: 'r', text: n(p.views) }), h('td', { class: 'r', text: FC(p.netFcfa) })))));
    if (g.daily.length) {
      const det = h('details', { class: 'adfold' }, h('summary', { text: 'Jour par jour (90 derniers jours)' }));
      det.append(table([['Jour'], ['Site ou application'], ['Format'], ['Vues', 'r'], ['Net', 'r'], ['État']], g.daily.map((e) => h('tr', {}, h('td', { text: e.day }), h('td', { text: e.property }), h('td', { text: FMT_LAB[e.format] || e.format }), h('td', { class: 'r', text: n(e.views) }), h('td', { class: 'r', text: FC(e.netFcfa) }),
        h('td', { text: (EARN_LAB[e.status] || e.status) + (e.status === 'held' ? ' · dispo le ' + e.releaseOn : '') })))));
      db.append(det);
    }
  }
  const date2 = (ms) => (ms ? new Date(Number(ms)).toLocaleDateString('fr-FR') : '—');
  async function loadGains(quiet) {
    try { drawGains(await call('adsPubEarnings')); }
    catch (e) { if (!quiet) status(friendly(e, 'Impossible de charger tes gains pour le moment.'), true); }
  }
  $('#g-send').addEventListener('click', async () => {
    const phone = $('#g-phone').value.trim(), operator = $('#g-op').value;
    if (phone.replace(/[^\d]/g, '').length < 8) return showError('Écris ton numéro Mobile Money avec l\u2019indicatif du pays, par exemple +228 90 00 00 00.');
    const b = $('#g-send'); b.disabled = true;
    try { const r = await call('adsPubRequestPayout', { phone, operator }); status(`Demande envoyée : ${FC(r.amountFcfa)} sur ton Mobile Money (${operator}). Notre équipe te paie puis tu reçois un e-mail avec la référence.`); await loadGains(true); }
    catch (e) { showError(gainErr(e)); }
    finally { b.disabled = false; }
  });
  async function load() {
    try {
      const d = await call('adsPubMe'); st.profile = d.profile; st.props = d.properties;
      const t = Math.floor(Number(d.audience.total) / 1000) * 1000; $('#aud-total').textContent = 'plus de ' + n(Math.max(50000, t));
      st.cats = d.adCategories || {}; $('#p-rules-new').hidden = !(d.profile && d.rules && !d.rules.accepted);
      fillProfile(); renderProps(); pubKpis(d); loadGains(true);
      if (!d.profile) { tab('profil'); status('Bienvenue ! Commence par ton profil de diffuseur.', false, true); } else if (!$('#tab-profil').hidden && d.properties.length) tab('sites');
    } catch (e) { status(friendly(e, 'Impossible de charger ton espace pour le moment. Recharge la page.'), true); }
  }

  $('#pform').addEventListener('submit', async (ev) => {
    ev.preventDefault(); perr('');
    const v = { type: st.type, name: $('#p-name').value.trim(), country: $('#p-country').value, city: $('#p-city').value.trim(), phone: $('#p-phone').value.trim(), website: $('#p-web').value.trim(), about: $('#p-about').value.trim(), acceptTerms: $('#p-terms').checked, partnerConsent: $('#p-consent').checked, rulesVersion: $('#pubspace').dataset.rules };
    if (v.name.length < 2) return perr('Ajoute ton nom ou celui de ton entreprise.');
    if (v.city.length < 2) return perr('Ajoute ta ville.');
    if (v.phone.replace(/[^\d]/g, '').length < 8) return perr('Ajoute ton numéro WhatsApp avec l\'indicatif.');
    if (v.about.length < 20) return perr('Présente ton activité en 20 caractères au moins.');
    if (!plogo.blob && !(st.profile && st.profile.logoUrl)) return perr('Ajoute ton logo : il est obligatoire, car il est affiché sur les pages de partenaires.');
    if (!v.partnerConsent) return perr('Coche l\'accord d\'affichage de ton logo comme partenaire.');
    if (!v.acceptTerms) return perr('Coche l\'acceptation des règles des diffuseurs.');
    const btn = $('#p-send'); btn.disabled = true; const plabel = btn.textContent;
    try { v.logoUrl = st.profile && st.profile.logoUrl; if (plogo.blob) { btn.textContent = 'Envoi du logo…'; v.logoUrl = await upload(plogo.blob, plogo.type); plogo.blob = null; }
      const r = await call('adsPubSaveProfile', v); status(r.status === 'active' ? 'Profil mis à jour.' : 'Profil envoyé ! Notre équipe le valide et tu recevras un e-mail. Tu peux déjà préparer tes sites et applications.'); await load(); tab('sites'); }
    catch (e) { perr(/profil_suspendu/.test(String(e && e.message)) ? 'Ton profil est suspendu. Contacte-nous.' : (e && e.code === 'functions/invalid-argument' ? String(e.message).replace(/^.*?:\s*/, '') : friendly(e, 'Impossible d\'envoyer le profil pour le moment. Réessaie.'))); }
    finally { btn.disabled = false; btn.textContent = plabel; }
  });

  const explain = (e) => {
    const m = String(e && e.message || '');
    if (/hors_ligne/.test(m)) return 'Ce site ou cette application ne répond pas : il doit être en ligne et accessible au public. Vérifie l\'adresse.';
    if (/deja_enregistre/.test(m)) return 'Ce site ou cette application est déjà déclaré par un diffuseur.';
    if (/limite_atteinte/.test(m)) return 'Tu as atteint le nombre maximum de sites et d\'applications.';
    if (/profil_manquant/.test(m)) return 'Crée d\'abord ton profil de diffuseur.';
    if (/profil_non_valide/.test(m)) return 'Ton profil n\'est pas valide pour ajouter un site : contacte-nous.';
    if (/regles_a_accepter/.test(m)) return 'Accepte d\'abord la version courante des règles des diffuseurs.';
    if (/logo_manquant/.test(m)) return 'Ajoute d\'abord le logo de ton profil (onglet Mon profil) : il est obligatoire.';
    if (e && e.code === 'functions/invalid-argument') return String(e.message).replace(/^.*?:\s*/, '') || 'Vérifie les champs.';
    return friendly(e, 'Impossible d\'envoyer la demande pour le moment. Réessaie.');
  };
  $$('#propform .catpick').forEach(catPick);
  $('#propform').addEventListener('submit', async (ev) => {
    ev.preventDefault(); qerr('');
    if (!st.profile) { tab('profil'); return qerr('Crée d\'abord ton profil de diffuseur.'); }
    if (!st.profile.logoUrl) { tab('profil'); perr('Ajoute le logo de ton profil avant d\'ajouter un site ou une application : il est obligatoire.'); return qerr('Ajoute d\'abord le logo de ton profil (onglet Mon profil).'); }
    const v = { kind: st.kind, name: $('#q-name').value.trim(), url: $('#q-url').value.trim(), androidUrl: $('#q-and').value.trim(), iosUrl: $('#q-ios').value.trim(), category: $('#q-cat').value, countries: [...st.countries], languages: ['fr'], audienceMonthly: Number($('#q-aud').value), sessionsMonthly: Number($('#q-ses').value) || 0, description: $('#q-desc').value.trim(), acceptedCategories: $$('#q-cats input:checked').map((i) => i.value) };
    if (v.name.length < 2) return qerr('Ajoute le nom.');
    if (!qimg.blob && !qimg.url) return qerr('Ajoute une image de ton site ou de ton application (logo, capture d\u2019écran ou autre) : elle est obligatoire.');
    if (!v.countries.length) return qerr('Choisis au moins un pays pour ton audience.');
    if (st.kind === 'site' && !v.url) return qerr('Ajoute l\'adresse du site (https://…).');
    if (st.kind === 'app' && !v.androidUrl && !v.iosUrl) return qerr('Ajoute le lien Google Play ou App Store : l\'application doit être en ligne.');
    if (!(v.audienceMonthly >= 100)) return qerr('Indique ton audience mensuelle (100 personnes au moins).');
    if (v.description.length < 20) return qerr('Décris ton site ou ton application en 20 caractères au moins.');
    const btn = $('#q-send'); btn.disabled = true; const label = btn.textContent; btn.textContent = 'Vérification en cours…';
    try {
      if (!qimg.url) { btn.textContent = 'Envoi de l\u2019image…'; qimg.url = await upload(qimg.blob, qimg.type); }
      v.imageUrl = qimg.url;
      const r = await call('adsPubAddProperty', v);
      $('#propform').reset(); st.countries = new Set(['TG']); renderQCountries();
      qimg.blob = null; qimg.url = ''; if (qimg.preview) { URL.revokeObjectURL(qimg.preview); qimg.preview = null; } qimgShow(null);
      status(`Demande envoyée ! Ton identifiant publicitaire : ${r.id}. Notre équipe te répond par e-mail.`);
      await load();
    } catch (e) { qerr(explain(e)); } finally { btn.disabled = false; btn.textContent = label; }
  });
}

// ───────── administration de la régie (annonceurs, diffuseurs, sites et applications) : réservée aux administrateurs ─────────
if ($('#regieadmin')) initRegieAdmin();

async function initRegieAdmin() {
  const status = setStatus;
  const fb = await boot(() => load());
  if (!fb) return;
  const { call } = fb;
  const st = { tab: 'adv', filter: 'pending', afilter: 'open', adv: [], ads: [], pays: [], payMeta: null, page: 1, profiles: [], props: [], alerts: [], alertsOpen: 0, sharers: [], camps: [], mail: null, mstatus: 'all', mkind: '', mq: '', totals: null, shq: '', shSort: 'earned', shSel: null, shLimit: 24 };
  window.addEventListener('afl-admin', () => { if (typeof drawBar === 'function') drawBar(); });   // l'onglet « Soldes » n'apparaît qu'une fois le compte reconnu comme équipe d'argent
  const date = (ms) => (ms ? new Date(Number(ms)).toLocaleDateString('fr-FR') : '—');
  const row = (k, v) => h('div', { class: 'rg-row' }, h('span', { text: k }), h('b', { text: v == null || v === '' ? '—' : String(v) }));
  const lnk = (label, url) => { const u = url ? safeUrl(url) : ''; return u ? h('a', { class: 'rg-link', href: u, target: '_blank', rel: 'nofollow noopener', text: label }) : null; };
  const tag = (cls, text) => h('span', { class: 'st ' + cls, text });
  const nice = (e) => { const m = String(e && e.message || ''); if (/administrateurs|permission/.test(m) || (e && e.code === 'functions/permission-denied')) return 'Cette page est réservée aux administrateurs : connecte-toi avec le compte Google utilisé dans l\'application.'; if (/profil_non_valide/.test(m)) return 'Valide d\'abord le profil du diffuseur (onglet Diffuseurs).'; if (/verification_requise/.test(m)) return 'Ce site n\'a pas encore prouvé qu\'il appartient au diffuseur : le diffuseur doit ajouter la balise de vérification sur son site, puis cliquer sur « Vérifier » dans son espace.'; if (/hors_ligne/.test(m)) return 'Ce site ou cette application ne répond pas : il doit être en ligne.'; if (/regles_a_accepter/.test(m)) return 'Le diffuseur doit d\'abord accepter la dernière version des règles (dans son espace).'; if (/motif_obligatoire/.test(m)) return 'Le motif doit faire 5 caractères au moins.'; if (/r.f.rence_obligatoire/.test(m)) return 'La référence du paiement est obligatoire (3 caractères au moins).'; if (/deja_traite/.test(m)) return 'Cette demande a déjà été traitée.'; return friendly(e, m.replace(/^.*?:\s*/, '') || 'Action impossible pour le moment.'); };

  const tabs = { adv: 'Annonceurs', ads: 'Annonces', pub: 'Diffuseurs', prop: 'Sites et applications', share: 'Partageurs', camp: 'Campagnes Partage', pay: 'Retraits', alert: 'Alertes', wal: 'Soldes', mail: 'E-mails' };
  const payFilters = [['requested', 'À payer'], ['paid', 'Payés'], ['refused', 'Refusés'], ['all', 'Tous']];
  const alertFilters = [['open', 'À vérifier'], ['held', 'Paiements bloqués'], ['reviewed', 'Vérifiées'], ['all', 'Toutes']];
  const filters = [['all', 'Tous'], ['pending', 'En attente'], ['active', 'Validés'], ['refused', 'Refusés'], ['suspended', 'Suspendus']];
  /** Total de chaque rubrique ET ce qui attend une décision, chargés d'un coup (pas besoin d'ouvrir chaque onglet pour savoir ce qu'il y a). */
  async function loadKpis() {
    const one = (name, args, pick, wait) => call(name, args).then((r) => { const l = pick(r); return { total: l.length, wait: l.filter(wait).length }; }).catch(() => null);
    const pend = (x) => String(x.status || x.logoStatus) === 'pending', open = (x) => String(x.status) === 'open';
    const [adv, ads, pub, prop, share, camp, alert, pay] = await Promise.all([
      one('adsAdvAdminList', { status: 'all' }, (r) => r.items || [], pend),
      one('adsPubAdminList', { ads: true, status: 'all' }, (r) => r.ads || [], pend),
      one('adsPubAdminList', { status: 'all' }, (r) => r.profiles || [], pend),
      one('adsPubAdminList', { status: 'all' }, (r) => r.properties || [], pend),
      one('adsPubAdminList', { sharers: true, status: 'all' }, (r) => r.sharers || [], pend),
      one('adsPubAdminList', { campaigns: true, status: 'all' }, (r) => r.campaigns || [], pend),
      one('adsPubAdminList', { alerts: true, status: 'all' }, (r) => r.alerts || [], open),
      call('adsPubAdminList', { payouts: true, status: 'all' }).then((r) => ({ total: Number(r.total) || 0, wait: Number(r.toPay) || 0 })).catch(() => null)]);
    st.k = { adv, ads, pub, prop, share, camp, alert, pay };
    drawKpis(); drawBar();
  }
  function drawKpis() {
    const k = st.k;
    const go = (tab, filter) => () => { st.tab = tab; st.page = 1; if (tab === 'alert') st.afilter = 'open'; else st.filter = tab === 'pay' ? (filter === 'pending' ? 'requested' : 'all') : filter; load(); };
    // grand chiffre = total ; dessous = ce qui attend une décision (jaune) ou « tout est traité » (vert)
    const card = (label, key, tab, what) => {
      const x = k[key];
      if (!x) return kpiCard(label, '—', 'indisponible', 'alert', () => loadKpis());
      return kpiCard(label, n(x.total), x.wait ? `${n(x.wait)} ${what}` : (x.total ? 'tout est traité' : 'aucun pour l\u2019instant'), x.wait ? (tab === 'alert' ? 'alert' : 'wait') : 'ok', go(tab, x.wait ? 'pending' : 'all'));
    };
    $('#rg-kpis').replaceChildren(card('Annonceurs', 'adv', 'adv', 'à valider'), card('Annonces', 'ads', 'ads', 'à valider'), card('Diffuseurs', 'pub', 'pub', 'à valider'), card('Sites et applications', 'prop', 'prop', 'à valider'),
      card('Partageurs', 'share', 'share', 'à valider'), card('Campagnes Partage', 'camp', 'camp', 'à valider'), ...(k.pay ? [card('Retraits', 'pay', 'pay', 'à payer')] : []), card('Alertes', 'alert', 'alert', 'à vérifier'));
  }
  const drawBar = () => {
    // pastille de chaque rubrique = TOTAL (chargé d'un coup, voir loadKpis) ; sinon, longueur de la liste affichée
    const k = st.k || {}, pick = (x, fallback) => (x ? x.total : fallback);
    const waiting = (key) => !!(k[key] && k[key].wait);
    const count = { adv: pick(k.adv, st.adv.length), ads: pick(k.ads, st.ads.length), pub: pick(k.pub, st.profiles.length), prop: pick(k.prop, st.props.length), share: pick(k.share, st.sharers.length), camp: pick(k.camp, st.camps.length), pay: pick(k.pay, st.pays.length), alert: k.alert ? k.alert.wait : (st.tab === 'alert' && st.afilter === 'open' ? st.alerts.length : st.alertsOpen) };
    $('#rg-tabs').replaceChildren(...Object.entries(tabs).filter(([tk]) => (tk !== 'pay' || !st.k || st.k.pay) && ((tk !== 'wal' && tk !== 'mail') || IS_OFFERED)).map(([tk, l]) => h('a', { href: '#', class: (st.tab === tk ? 'on ' : '') + (tk === 'alert' && count.alert ? 'rg-alert' : (waiting(tk) ? 'rg-wait' : '')), onclick: (e) => { e.preventDefault(); st.tab = tk; st.page = 1; if (tk === 'pay' && !payFilters.some(([f]) => f === st.filter)) st.filter = 'requested'; if (tk !== 'pay' && tk !== 'alert' && !filters.some(([f]) => f === st.filter)) st.filter = 'pending'; load(); } }, l, tk === 'wal' ? null : h('i', { text: String(count[tk]) }))));
    const fl = (st.tab === 'wal' || st.tab === 'mail') ? [] : st.tab === 'alert' ? alertFilters : st.tab === 'pay' ? payFilters : st.tab === 'share' ? [...filters, ['hold', 'Gains bloqués']] : filters, cur = st.tab === 'alert' ? st.afilter : st.filter;
    $('#rg-filters').replaceChildren(...fl.map(([k, l]) => h('span', { class: cur === k ? 'on' : false, onclick: () => { if (st.tab === 'alert') st.afilter = k; else { st.filter = k; st.shLimit = 24; st.shSel = null; } st.page = 1; load(); } }, l)));
  };

  /** Zone de décision avec motif : jamais de fenêtre du navigateur, tout est dans la carte. */
  function decide(card, specs) {
    const zone = h('div', { class: 'rg-act' });
    // en cas de refus du serveur, la raison s'affiche dans la carte (le message du haut de la page est hors de l'écran quand on a défilé)
    const show = (err) => zone.replaceChildren(...(err ? [h('p', { class: 'aderr rg-err', role: 'alert', text: err })] : []), ...specs.map((s) => h('button', { class: 'btn ' + (s.primary ? 'btn-primary' : 'btn-line') + ' adsm', type: 'button', text: s.label, onclick: () => (s.ask || s.audience != null || s.networkChoice ? ask(s) : send(s)) })));
    const send = async (s, extra = {}) => { try { await call(s.fn, { ...s.data, ...extra }); status('Décision enregistrée.'); load(); } catch (e) { const m = nice(e); status(m, true); show(m); } };
    const ask = (s) => {
      const ta = h('textarea', { rows: 2, maxlength: 300, placeholder: s.ask });
      const num = s.audience != null ? h('input', { type: 'number', min: 0, value: s.audience, 'aria-label': 'Audience retenue' }) : null;
      const net = s.networkChoice ? h('label', { class: 'adcheck rg-net' }, h('input', { type: 'checkbox', checked: s.networkDefault ? true : false }), h('span', {}, h('b', { text: 'Offre Réseau' }), ' : diffuser aussi cette annonce chez les diffuseurs externes (leurs sites et applications). Sans cette case, elle reste sur les plateformes Afrolook.')) : null;
      zone.replaceChildren(h('div', { class: 'rg-ask' }, num ? h('label', { class: 'fl' }, 'Audience retenue (ajoutée aux 50 000) ', num) : null, net, s.ask ? ta : null,
        h('div', { class: 'logo-r' }, h('button', { class: 'btn btn-primary adsm', type: 'button', text: 'Confirmer', onclick: () => {
          const extra = {};
          if (s.ask) { const min = s.askKey ? 3 : 5; if (ta.value.trim().length < min) return status(s.askKey ? 'La référence du paiement doit faire 3 caractères au moins.' : 'Le motif doit faire 5 caractères au moins.', true); extra[s.askKey || 'reason'] = ta.value.trim(); }
          if (num) extra[s.audienceKey || 'audienceCounted'] = Number(num.value);
          if (net) extra.network = net.querySelector('input').checked;
          send(s, extra);
        } }), h('button', { class: 'adlinkbtn', type: 'button', text: 'Annuler', onclick: show }))));
    };
    show(); card.append(zone);
  }

  function advCard(p) {
    const c = h('article', { class: 'rg-card' },
      h('div', { class: 'rg-h' }, h('div', { class: 'rg-logo' }, p.logoUrl && String(p.logoUrl).startsWith('https://') ? h('img', { src: p.logoUrl, alt: '' }) : h('span', { text: '?' })),
        h('div', {}, h('b', { text: p.brandName }), h('small', { text: [p.sector, p.city, p.country].filter(Boolean).join(' · ') })),
        tag(({ pending: 'wait', approved: 'ok', rejected: 'rej' })[p.logoStatus] || 'end', ({ pending: 'Profil en validation', approved: 'Profil validé', rejected: 'Profil refusé' })[p.logoStatus] || '')),
      row('Ce qu\'ils font', p.about), row('Contact', [p.whatsapp, p.email].filter(Boolean).join(' · ')), row('Inscrit le', date(p.createdAt)),
      row('Annonces', `${p.stats.ads} (dont ${p.stats.active} en ligne) · ${n(p.stats.views)} vues · ${n(p.stats.clicks)} clics`), row('Accord partenaire', p.partnerConsent ? 'Oui' : 'Non'));
    if (p.logoReason) c.append(row('Motif du refus', p.logoReason));
    const l = lnk('Voir le site', p.website); if (l) c.append(l);
    const specs = [];
    if (p.logoStatus !== 'approved') specs.push({ label: 'Valider le profil', primary: true, fn: 'adsAdvAdminReview', data: { uid: p.uid, decision: 'approve' } });
    if (p.logoStatus !== 'rejected') specs.push({ label: 'Refuser le profil', ask: 'Motif du refus (envoyé par e-mail)', fn: 'adsAdvAdminReview', data: { uid: p.uid, decision: 'reject' } });
    decide(c, specs); return c;
  }
  /** Demande de retrait d'un diffuseur : montant, Mobile Money, ses gains ; Payer (avec la référence du paiement) ou Refuser (avec le motif). */
  function payCard(p) {
    const stl = { requested: ['wait', 'À payer'], paid: ['ok', 'Payé'], refused: ['rej', 'Refusé'] }[p.status] || ['end', p.status], e = p.earnings || {};
    const c = h('article', { class: 'rg-card' },
      h('div', { class: 'rg-h' }, h('div', {}, h('b', { text: `${n(p.amountFcfa)} F · ${p.name || p.email || 'Diffuseur'}` }), h('small', { text: `${p.operator} · ${p.phone}` })), tag(stl[0], stl[1])),
      row('Diffuseur', [p.name, p.email].filter(Boolean).join(' · ')), row('Mobile Money', `${p.operator} · ${p.phone}`), row('Demandé le', date(p.createdAt)),
      row('Ses gains', `${n(e.availableFcfa || 0)} F disponibles · ${n(e.pendingFcfa || 0)} F en attente · ${n(e.requestedFcfa || 0)} F en retrait · ${n(e.paidFcfa || 0)} F payés · réserve ${n(e.reserveFcfa || 0)} F`));
    if (p.status === 'paid') c.append(row('Référence du paiement', p.reference), row('Payé le', date(p.decidedAt)));
    if (p.status === 'refused') c.append(row('Motif du refus', p.reason), row('Décidé le', date(p.decidedAt)));
    if (p.status === 'requested') {
      const d = (decision) => ({ target: 'payout', id: String(p.id), decision });
      decide(c, [{ label: 'Payer', primary: true, ask: `Référence du paiement de ${n(p.amountFcfa)} F envoyé à ${p.phone} (${p.operator})`, askKey: 'reference', fn: 'adsPubAdminReview', data: d('pay') },
        { label: 'Refuser', ask: 'Motif du refus (envoyé par e-mail ; les gains redeviennent disponibles)', fn: 'adsPubAdminReview', data: d('refuse') }]);
    }
    return c;
  }
  /** Annonce déposée depuis le site : ce que l'équipe regarde pour la valider (visuel, texte, lien, pays), et l'offre Réseau. */
  function adCard(a) {
    const stl = { pending: ['wait', 'En validation'], active: ['ok', 'En ligne'], refused: ['rej', 'Refusée'], suspended: ['rej', 'Suspendue'], stopped: ['end', 'Arrêtée par l\u2019annonceur'] }[a.status] || ['end', a.status];
    const img = a.imageUrl && String(a.imageUrl).startsWith('https://') ? h('img', { src: a.imageUrl, alt: '', loading: 'lazy' }) : h('span', { text: a.video ? '▶' : '?' });
    const c = h('article', { class: 'rg-card' },
      h('div', { class: 'rg-h' }, h('div', { class: 'rg-logo' }, img), h('div', {}, h('b', { text: a.title }), h('small', { text: (a.brand || 'Annonceur') + ' · ' + (a.networkRequested ? 'Offre Réseau demandée (payante)' : (a.free ? 'Annonce gratuite' : 'Annonce')) + ' · ' + a.id.slice(0, 8) })), tag(stl[0], stl[1])),
      row('Texte', a.text), row('Bouton', a.action), row('Annonceur', [a.brand, a.ownerEmail].filter(Boolean).join(' · ')), row('Catégorie', a.categoryLabel || a.category),
      row('Pays', (a.countries || []).join(', ') || 'Tous'), row('Langues, appareils', [(a.languages || []).join(', '), (a.devices || []).join(', ')].filter(Boolean).join(' · ') || 'Toutes'),
      row('Offre Réseau', a.network ? 'Oui : aussi servie chez les diffuseurs externes' : (a.networkRequested ? 'Demandée par l\u2019annonceur (offre payante) : convenir du tarif avec lui avant de valider' : 'Non : plateformes Afrolook seulement')),
      row('Résultats', `${n(a.views)} vues · ${n(a.clicks)} clics`), row('Déposée le', date(a.createdAt)), row('Fin prévue', a.endsAt ? date(a.endsAt) : '—'));
    if (a.reason) c.append(row('Motif', a.reason));
    const l = lnk('Ouvrir le lien de l\u2019annonce', a.actionUrl); if (l) c.append(l);
    const d = (decision, more = {}) => ({ target: 'ad', id: a.id, decision, ...more }), specs = [];
    if (a.status === 'pending' || a.status === 'refused') specs.push({ label: 'Valider', primary: true, networkChoice: true, networkDefault: !!a.networkRequested, fn: 'adsPubAdminReview', data: d('approve') });
    if (a.status === 'pending') specs.push({ label: 'Refuser', ask: 'Motif du refus (envoyé par e-mail)', fn: 'adsPubAdminReview', data: d('refuse') });
    if (a.status === 'active') {
      specs.push({ label: a.network ? 'Retirer l\u2019offre Réseau' : 'Activer l\u2019offre Réseau', primary: !a.network, fn: 'adsPubAdminReview', data: d('approve', { network: !a.network }) });
      specs.push({ label: 'Suspendre', ask: 'Motif de la suspension', fn: 'adsPubAdminReview', data: d('suspend') });
    }
    if (a.status === 'suspended') specs.push({ label: 'Réactiver', primary: true, fn: 'adsPubAdminReview', data: d('reactivate') });
    if (specs.length) decide(c, specs);
    return c;
  }
  function pubCard(p) {
    const c = h('article', { class: 'rg-card' },
      h('div', { class: 'rg-h' }, h('div', { class: 'rg-logo' }, p.logoUrl && String(p.logoUrl).startsWith('https://') ? h('img', { src: p.logoUrl, alt: '' }) : h('span', { text: '?' })), h('div', {}, h('b', { text: p.name }), h('small', { text: (p.type === 'company' ? 'Entreprise' : 'Particulier') + ' · ' + [p.city, p.country].filter(Boolean).join(', ') })), tag(({ pending: 'wait', active: 'ok', refused: 'rej', suspended: 'rej' })[p.status] || 'end', ({ pending: 'En validation', active: 'Validé', refused: 'Refusé', suspended: 'Suspendu' })[p.status] || p.status)),
      row('Présentation', p.about), row('Contact', [p.phone, p.email].filter(Boolean).join(' · ')), row('Inscrit le', date(p.createdAt)),
      p.earnings ? row('Gains', `${n(p.earnings.availableFcfa)} F disponibles · ${n(p.earnings.pendingFcfa)} F en attente · ${n(p.earnings.requestedFcfa)} F en retrait · ${n(p.earnings.paidFcfa)} F payés · réserve ${n(p.earnings.reserveFcfa)} F · ${n(p.earnings.views)} vues valides`) : null);
    if (p.reason) c.append(row('Motif', p.reason));
    const l = lnk('Voir le site', p.website); if (l) c.append(l);
    const specs = [];
    if (p.status === 'pending' || p.status === 'refused') specs.push({ label: 'Valider le profil', primary: true, fn: 'adsPubAdminReview', data: { target: 'profile', id: p.uid, decision: 'approve' } });
    if (p.status === 'suspended') specs.push({ label: 'Réactiver', primary: true, fn: 'adsPubAdminReview', data: { target: 'profile', id: p.uid, decision: 'reactivate' } });
    if (p.status === 'pending') specs.push({ label: 'Refuser', ask: 'Motif du refus (envoyé par e-mail)', fn: 'adsPubAdminReview', data: { target: 'profile', id: p.uid, decision: 'refuse' } });
    if (p.status === 'active') specs.push({ label: 'Suspendre', ask: 'Motif de la suspension', fn: 'adsPubAdminReview', data: { target: 'profile', id: p.uid, decision: 'suspend' } });
    decide(c, specs); return c;
  }
  function propCard(p) {
    const c = h('article', { class: 'rg-card' },
      h('div', { class: 'rg-h' }, p.imageUrl && String(p.imageUrl).startsWith('https://') ? h('div', { class: 'rg-logo' }, h('img', { src: p.imageUrl, alt: '' })) : null, h('div', {}, h('b', { text: p.name }), h('small', { text: (p.kind === 'site' ? 'Site web' : 'Application') + ' · ' + p.id })), tag(({ pending: 'wait', active: 'ok', refused: 'rej', suspended: 'rej' })[p.status] || 'end', ({ pending: 'En validation', active: 'Validé', refused: 'Refusé', suspended: 'Suspendu' })[p.status] || p.status)),
      row('Diffuseur', `${p.ownerName} · ${p.ownerEmail} (profil : ${({ active: 'validé', pending: 'en attente', refused: 'refusé', suspended: 'suspendu' })[p.ownerStatus] || 'aucun'})`),
      row('Catégorie, pays', `${p.category} · ${(p.countries || []).join(', ')}`), row('Audience déclarée', `${n(p.audienceMonthly)} par mois`), p.status === 'active' ? row('Audience retenue', n(p.audienceCounted)) : null,
      row('En ligne', p.online ? 'Oui' + (p.protectedSite ? ' (site protégé contre les robots)' : '') : 'Non'), row('Propriété du site', p.verified ? 'Vérifiée ✓' : 'Non vérifiée'), row('Rémunérable', p.payable ? 'Oui' : 'Non (site non vérifié ou application non attestée)'),
      row('Catégories acceptées', (p.acceptedCategories || []).join(', ') || 'courantes par défaut'),
      row('Audience mesurée', p.measured ? `${n(p.measured.u30)} sur 30 j · ${n(p.measured.u60)} sur 60 j · ${p.measured.daysWithData} jours de mesure · ${({ no_data: 'pas encore comparable', conform: 'conforme', below: 'en dessous', far_below: 'TRÈS EN DESSOUS de la déclarée', above: 'au-dessus' })[p.measured.status] || ''}` : 'pas encore de mesure'),
      p.measured && p.measured.geo && p.measured.geo.length ? row('Pays des visiteurs', p.measured.geo.map((g) => `${g.cc} ${Math.round(g.share * 100)} %`).join(' · ') + (p.measured.geoFlag ? ' : ÉCART avec les pays annoncés' : '')) : null,
      row('Trafic invalide (60 j)', p.measured ? `${(p.measured.invalidRate * 100).toFixed(1)} % · ${n(p.measured.foreign60)} appels d'un autre domaine` : '—'),
      row('Description', p.description));
    if (p.reason) c.append(row('Motif', p.reason));
    if (p.reviewHold) c.append(row('Paiements', 'Bloqués : ' + (p.holdReason || 'alerte à vérifier') + ' (onglet Alertes)'));
    for (const [lab, u] of [['Ouvrir le site', p.url], ['Google Play', p.androidUrl], ['App Store', p.iosUrl]]) { const l = lnk(lab, u); if (l) c.append(l); }
    const specs = [];
    if (p.status === 'pending' || p.status === 'refused') specs.push({ label: 'Valider', primary: true, audience: p.audienceMonthly, fn: 'adsPubAdminReview', data: { target: 'property', id: p.id, decision: 'approve' } });
    if (p.status === 'suspended') specs.push({ label: 'Réactiver', primary: true, fn: 'adsPubAdminReview', data: { target: 'property', id: p.id, decision: 'reactivate' } });
    if (p.status === 'pending') specs.push({ label: 'Refuser', ask: 'Motif du refus (envoyé par e-mail)', fn: 'adsPubAdminReview', data: { target: 'property', id: p.id, decision: 'refuse' } });
    if (p.status === 'active') specs.push({ label: 'Suspendre', ask: 'Motif de la suspension', fn: 'adsPubAdminReview', data: { target: 'property', id: p.id, decision: 'suspend' } });
    decide(c, specs); return c;
  }
  /** Partageur (utilisateur de l'application) : petite carte dans une grille, détails et décisions dans le panneau sous la grille. Fraude confirmée = gains retirés. */
  const coinsFmt = (v) => Number(v || 0).toLocaleString('fr-FR', { maximumFractionDigits: 2 });
  const money = (m) => h('span', { class: 'sh-m' }, h('b', { text: coinsFmt(m.coins) }), h('small', { text: ' pièces ≈ ' + n(Math.round(m.fcfa)) + ' FCFA' }));
  const stlOf = (p) => ({ pending: ['wait', 'En validation'], active: ['ok', 'Validé'], refused: ['rej', 'Refusé'], suspended: ['rej', 'Suspendu'] }[p.status] || ['end', p.status]);
  const initials = (p) => String(p.name || p.email || '?').trim().split(/\s+/).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
  function sharerMini(p) {
    const stl = stlOf(p), e = p.earned || { coins: 0, fcfa: 0 }, w = p.pending || { coins: 0, fcfa: 0 };
    const place = [p.country, p.city].filter(Boolean).join(' · ');
    return h('button', { type: 'button', class: 'sh-mini' + (p.fraudHold ? ' hold' : '') + (st.shSel === p.uid ? ' sel' : ''), 'data-uid': p.uid, 'aria-pressed': st.shSel === p.uid ? 'true' : 'false',
      onclick: () => { st.shSel = st.shSel === p.uid ? null : p.uid; drawShare(); const el = $('.sh-sheet'); el && el.scrollIntoView({ behavior: 'smooth', block: 'nearest' }); } },
      h('span', { class: 'sh-top' }, h('span', { class: 'sh-av', text: initials(p) }), h('span', { class: 'sh-nm' }, h('b', { text: p.name || p.email || p.uid }), h('small', { text: place || '—' }))),
      h('span', { class: 'sh-fig' },
        h('span', {}, h('small', { text: 'Gagné' }), h('b', { class: 'g', text: coinsFmt(e.coins) }), h('em', { text: '≈ ' + n(Math.round(e.fcfa)) + ' FCFA' })),
        h('span', {}, h('small', { text: 'En attente' }), h('b', { class: 'w', text: coinsFmt(w.coins) }), h('em', { text: '≈ ' + n(Math.round(w.fcfa)) + ' FCFA' }))),
      h('span', { class: 'sh-foot' }, h('span', { text: n(p.validClicks) + ' clics valides' }), p.fraudHold ? h('span', { class: 'sh-alert', text: '⚠ Gains bloqués' }) : tag(stl[0], stl[1])));
  }
  function sharerSheet(p) {
    const stl = stlOf(p), e = p.earned || { coins: 0, fcfa: 0 }, w = p.pending || { coins: 0, fcfa: 0 };
    const kv = (k, v) => (v == null || v === '' ? null : h('div', { class: 'sh-kv' }, h('span', { text: k }), h('b', { text: String(v) })));
    const dayLab = { released: 'Versé', held: 'Retenu 24 h', blocked: 'Bloqué' };
    const days = (p.days || []).length
      ? h('table', { class: 'sh-days' }, h('thead', {}, h('tr', {}, ...['Jour', 'Clics', 'Pièces', 'FCFA', 'État'].map((t, i) => h('th', { class: i ? 'n' : '', text: t })))),
        h('tbody', {}, ...p.days.map((d) => h('tr', {}, h('td', { text: d.day }), h('td', { class: 'n', text: n(d.clicks) }), h('td', { class: 'n', text: coinsFmt(d.coins) }), h('td', { class: 'n', text: n(Math.round(d.fcfa)) }), h('td', { text: dayLab[d.status] || d.status })))))
      : h('p', { class: 'adempty', text: 'Aucun gain pour le moment.' });
    const c = h('article', { class: 'rg-card sh-sheet' + (p.fraudHold ? ' hold' : '') },
      h('div', { class: 'rg-h' }, h('span', { class: 'sh-av', text: initials(p) }), h('div', {}, h('b', { text: p.name || p.email || p.uid }), h('small', { text: [p.country, p.city].filter(Boolean).join(' · ') })), p.fraudHold ? h('span', { class: 'sh-alert', text: '⚠ Gains bloqués : fraude possible' }) : null, tag(stl[0], stl[1]),
        h('button', { class: 'adlinkbtn', type: 'button', text: 'Fermer', onclick: () => { st.shSel = null; drawShare(); } })),
      h('div', { class: 'sh-cols' },
        h('div', { class: 'sh-blk' }, h('h3', { text: 'Gains' }),
          h('div', { class: 'sh-kv' }, h('span', { text: 'Gagné' }), money(e)),
          h('div', { class: 'sh-kv' }, h('span', { text: 'En attente' }), money(w)),
          kv('Prochain versement', w.releaseAt ? date(w.releaseAt) : null), kv('Clics valides', n(p.validClicks))),
        h('div', { class: 'sh-blk' }, h('h3', { text: 'Audience' }),
          kv('Déclarée', n(p.declared) + ' personnes'), kv('Détail', 'statut ' + n(p.statusAudience) + ' · Telegram ' + n(p.telegramAudience) + ' · autres ' + n(p.otherAudience)),
          kv('Groupes', (p.groups || []).map((g) => g.name + ' (' + g.members + ')').join(', ')), p.status === 'active' ? kv('Retenue', n(p.retained)) : null, kv('Présentation', p.about)),
        h('div', { class: 'sh-blk' }, h('h3', { text: 'Contact' }), kv('WhatsApp', p.whatsapp), kv('E-mail', p.email), kv('Inscrit le', date(p.createdAt)), kv('Motif', p.reason))),
      h('div', { class: 'sh-blk' }, h('h3', { text: 'Derniers jours' }), h('div', { class: 'sh-scroll' }, days)));
    const d = (decision) => ({ target: 'sharer', id: p.uid, decision }), specs = [];
    if (p.status === 'pending' || p.status === 'refused') specs.push({ label: 'Valider', primary: true, audience: p.declared, audienceKey: 'audienceRetained', fn: 'adsPubAdminReview', data: d('approve') });
    if (p.status === 'suspended') specs.push({ label: 'Réactiver', primary: true, audience: p.declared, audienceKey: 'audienceRetained', fn: 'adsPubAdminReview', data: d('reactivate') });
    if (p.status === 'pending') specs.push({ label: 'Refuser', ask: 'Motif du refus (envoyé par e-mail)', fn: 'adsPubAdminReview', data: d('refuse') });
    if (p.status === 'active') specs.push({ label: 'Suspendre', ask: 'Motif de la suspension', fn: 'adsPubAdminReview', data: d('suspend') });
    if (p.fraudHold) specs.push({ label: 'Vérifié : lever le blocage', fn: 'adsPubAdminReview', data: d('clear') });
    if (p.status !== 'refused') specs.push({ label: 'Fraude confirmée : retirer les gains', ask: 'Motif (gardé dans le journal)', fn: 'adsPubAdminReview', data: d('fraud') });
    decide(c, specs); return c;
  }
  /** Onglet Partageurs : bandeau de totaux, recherche + tri, grille de petites cartes, panneau de détails, « Voir la suite ». */
  function sharersView() {
    const t = st.totals;
    const q = st.shq.trim().toLowerCase();
    let list = st.sharers.filter((p) => (st.filter !== 'hold' || p.fraudHold) && (!q || [p.name, p.email, p.country, p.city, p.whatsapp].filter(Boolean).join(' ').toLowerCase().includes(q)));
    const key = { earned: (p) => (p.earned || {}).fcfa || 0, pending: (p) => (p.pending || {}).fcfa || 0, clicks: (p) => p.validClicks || 0, recent: (p) => p.createdAt || 0 }[st.shSort];
    list = [...list].sort((a, b) => key(b) - key(a));
    const sum = t ? h('div', { class: 'sh-sum' },
      h('div', {}, h('small', { text: 'Partageurs validés' }), h('b', { text: n(t.validated) })),
      h('div', {}, h('small', { text: 'Total gagné' }), h('b', { class: 'g', text: coinsFmt(t.earned.coins) + ' pièces' }), h('em', { text: '≈ ' + n(Math.round(t.earned.fcfa)) + ' FCFA' })),
      h('div', {}, h('small', { text: 'Total en attente' }), h('b', { class: 'w', text: coinsFmt(t.pending.coins) + ' pièces' }), h('em', { text: '≈ ' + n(Math.round(t.pending.fcfa)) + ' FCFA' })),
      h('div', {}, h('small', { text: 'Clics valides' }), h('b', { text: n(t.validClicks) }), t.blocked ? h('em', { class: 'r', text: t.blocked + ' compte(s) bloqué(s)' }) : null)) : null;
    const search = h('input', { type: 'search', class: 'sh-in', placeholder: 'Chercher un nom, un pays, un e-mail…', value: st.shq, 'aria-label': 'Chercher un partageur', oninput: (e) => { st.shq = e.target.value; st.shLimit = 24; drawShare(true); } });
    const sort = h('select', { class: 'sh-in sh-sort', 'aria-label': 'Trier', onchange: (e) => { st.shSort = e.target.value; drawShare(); } },
      ...[['earned', 'Trier : plus gagné'], ['pending', 'Trier : plus en attente'], ['clicks', 'Trier : plus de clics'], ['recent', 'Trier : plus récents']].map(([v, l]) => h('option', { value: v, text: l, selected: v === st.shSort ? true : false })));
    const shown = list.slice(0, st.shLimit);
    const grid = shown.length ? h('div', { class: 'sh-grid' }, ...shown.map(sharerMini)) : h('p', { class: 'adempty', text: 'Rien à afficher pour ce filtre.' });
    const sel = st.shSel && st.sharers.find((p) => p.uid === st.shSel);
    return h('div', { class: 'sh' }, sum, h('div', { class: 'sh-tools' }, search, sort), grid,
      list.length > shown.length ? h('button', { class: 'btn btn-line adsm sh-more', type: 'button', text: 'Voir la suite (' + (list.length - shown.length) + ')', onclick: () => { st.shLimit += 24; drawShare(); } }) : null,
      sel ? sharerSheet(sel) : null);
  }
  function drawShare(keepFocus) {
    $('#rg-list').replaceChildren(sharersView());
    if (keepFocus) { const i = $('.sh-in'); if (i) { i.focus(); const l = i.value.length; i.setSelectionRange && i.setSelectionRange(l, l); } }
  }
  /** Campagne Partage : à valider une fois le paiement reçu ; l'équipe peut aussi la mettre en pause ou la terminer. */
  function campCard(p) {
    const stl = { pending: ['wait', 'À valider'], active: ['ok', 'En cours'], paused: ['end', 'En pause'], refused: ['rej', 'Refusée'], ended: ['end', 'Terminée'] }[p.status] || ['end', p.status];
    const c = h('article', { class: 'rg-card' },
      h('div', { class: 'rg-h' }, h('div', {}, h('b', { text: p.brand + ' · ' + p.title }), h('small', { text: p.ownerEmail || '' })), tag(stl[0], stl[1])),
      row('Texte', p.text), row('Audience à atteindre', n(p.targetAudience) + ' personnes'), row('Prix', p.free ? 'Offerte par l’équipe' : p.fromBalance ? n(p.listPriceFcfa) + ' F (payée avec le solde annonceur)' : n(p.listPriceFcfa) + ' F (à encaisser avant de valider)'),
      row('Pays', (p.countries || []).filter((c) => c !== 'ALL').join(', ') || 'Tous les pays'), row('Résultats', n(p.valid) + ' clics valides · ' + n(p.sharers) + ' partageurs · audience engagée ' + n(p.allocatedReach)), row('Audience touch\u00e9e (estimation)', (p.estimatedReach && p.estimatedReach.high > 0) ? n(p.estimatedReach.low) + ' \u00e0 ' + n(p.estimatedReach.high) + ' personnes \u00b7 d\u2019apr\u00e8s ' + n(p.valid) + ' clics valides et un taux de clic de ' + (((p.ctrRange || [0.022, 0.038])[0]) * 100).toFixed(1).replace('.', ',') + ' % \u00e0 ' + (((p.ctrRange || [0.022, 0.038])[1]) * 100).toFixed(1).replace('.', ',') + ' %' : 'Pas encore assez de clics valides pour estimer'), row('Gains versés (plafond)', n(p.spentFcfa) + ' F'),
      p.reason ? row('Motif', p.reason) : null);
    const l = lnk('Voir le lien de l’annonceur', p.actionUrl); if (l) c.append(l);
    const d = (decision) => ({ target: 'campaign', id: p.id, decision }), specs = [];
    if (p.status === 'pending') specs.push({ label: (p.free || p.fromBalance) ? 'Valider' : 'Valider (paiement reçu)', primary: true, ...((p.free || p.fromBalance) ? {} : { ask: 'Référence du paiement reçu (virement, Mobile Money…)' }), fn: 'adsPubAdminReview', data: d('approve') }, { label: 'Refuser', ask: 'Motif du refus (envoyé par e-mail)', fn: 'adsPubAdminReview', data: d('refuse') });
    if (p.status === 'active') specs.push({ label: 'Mettre en pause', ask: 'Motif (gardé dans le journal)', fn: 'adsPubAdminReview', data: d('pause') }, { label: 'Terminer', ask: 'Motif (gardé dans le journal)', fn: 'adsPubAdminReview', data: d('end') });
    if (p.status === 'paused') specs.push({ label: 'Reprendre', primary: true, fn: 'adsPubAdminReview', data: d('resume') });
    decide(c, specs); return c;
  }
  /** Alerte de la surveillance : ce qui a été détecté, et trois décisions (vérifiée, bloquer les paiements, lever le blocage). */
  function alertCard(a) {
    const high = a.severity === 'high', ext = /^ap_/.test(a.pub);
    const c = h('article', { class: 'rg-card' + (high ? ' rg-high' : '') },
      h('div', { class: 'rg-h' }, h('div', { class: 'rg-logo' }, h('span', { text: high ? '🚨' : '⚠️' })),
        h('div', {}, h('b', { text: (a.pubName || a.pub) + (a.adId ? ' · annonce ' + String(a.adId).slice(0, 8) : '') }), h('small', { text: 'Détectée le ' + date(a.createdAt) + ' (journée du ' + a.day + ')' })),
        tag(high ? 'rej' : 'wait', high ? 'Gravité haute' : 'Gravité moyenne')),
      row('Ce qui a été détecté', a.message), row('Statut', ({ open: 'À vérifier', held: 'Paiements bloqués', reviewed: 'Vérifiée' })[a.status] || a.status));
    if (a.autoHold) c.append(row('Blocage', 'Paiements bloqués automatiquement dès la détection : la diffusion continue, aucun gain n\u2019est versable.'));
    if (a.note) c.append(row('Note', a.note));
    const data = (decision) => ({ target: 'alert', id: a.id, decision }), specs = [];
    if (a.status !== 'reviewed') specs.push({ label: 'Vérifiée : rien d\u2019anormal', primary: true, fn: 'adsPubAdminReview', data: data('ack') });
    if (ext && a.status !== 'held' && !a.autoHold) specs.push({ label: 'Bloquer les paiements', ask: 'Pourquoi bloquer ? (gardé dans le journal)', fn: 'adsPubAdminReview', data: data('hold') });
    if (ext && (a.status === 'held' || a.autoHold)) specs.push({ label: 'Lever le blocage', fn: 'adsPubAdminReview', data: data('release') });
    if (specs.length) decide(c, specs);
    return c;
  }
  function draw() {
    drawBar();
    if (st.tab === 'share') return drawShare();
    const list = st.tab === 'wal' ? [walCard()] : st.tab === 'mail' ? [mailCard()] : st.tab === 'share' ? st.sharers.map(sharerCard) : st.tab === 'camp' ? st.camps.map(campCard) : st.tab === 'alert' ? st.alerts.map(alertCard) : st.tab === 'adv' ? st.adv.map(advCard) : st.tab === 'ads' ? st.ads.map(adCard) : st.tab === 'pay' ? st.pays.map(payCard) : st.tab === 'pub' ? st.profiles.map(pubCard) : st.props.map(propCard);
    $('#rg-list').replaceChildren(...(list.length ? list : [h('p', { class: 'adempty', text: 'Rien à afficher pour ce filtre.' })]));
    const pm = st.payMeta;   // retraits : pages de 50
    if (st.tab === 'pay' && pm && pm.total > pm.pageSize) { const pages = Math.ceil(pm.total / pm.pageSize); $('#rg-list').append(h('div', { class: 'rg-act' }, h('button', { class: 'btn btn-line adsm', type: 'button', text: 'Précédent', disabled: st.page <= 1, onclick: () => { st.page -= 1; load(); } }), h('small', { text: `Page ${st.page} sur ${pages} · ${n(pm.total)} demandes` }), h('button', { class: 'btn btn-line adsm', type: 'button', text: 'Suivant', disabled: st.page >= pages, onclick: () => { st.page += 1; load(); } }))); }
  }
  // « E-mails » : suivi des e-mails de l'application (équipe d'argent) : état du mode d'envoi, chiffres des 24 h, derniers e-mails avec la raison des échecs, envoyer maintenant, réessayer.
  // Le texte des e-mails n'est jamais montré : seulement l'objet, le destinataire et l'état.
  function mailCard() {
    const m = st.mail || { config: {}, counts24h: {}, kinds: [], items: [] }, cfg = m.config || {}, cnt = m.counts24h || {};
    const okCfg = cfg.real && (cfg.mailer !== 'smtp' || (cfg.smtpHost && cfg.smtpUser));
    const banner = h('div', { class: 'rg-note', style: 'border-left:4px solid ' + (okCfg ? '#0f8a3c' : '#c0392b') + ';padding:8px 12px;margin-bottom:10px' },
      !cfg.real ? 'Les e-mails ne sont PAS vraiment envoyés : le mode d’envoi est « ' + cfg.mailer + ' » (ils sont seulement écrits dans un journal). Il faut régler le fournisseur d’e-mails sur le serveur.'
        : (cfg.mailer === 'smtp' && !(cfg.smtpHost && cfg.smtpUser)) ? 'Mode SMTP, mais l’hôte ou l’identifiant ne semble pas réglé : les envois risquent d’échouer.'
          : 'Envoi réel actif (' + cfg.mailer + '). Expéditeur : ' + cfg.from + '.');
    const tiles = h('div', { class: 'adchips' }, h('span', { text: 'Envoyés (24 h) : ' + n(cnt.sent || 0) }), h('span', { text: 'En attente : ' + n(cnt.pending || 0) }), h('span', { text: 'En échec : ' + n(cnt.failed || 0) }));
    const act = h('div', { class: 'rg-act' });
    const reload = () => load();
    const dispatch = h('button', { class: 'btn btn-primary adsm', type: 'button', text: 'Envoyer maintenant ce qui attend' + (st.mkind ? ' (' + st.mkind + ')' : '') });
    dispatch.addEventListener('click', async () => {
      dispatch.disabled = true;
      try { const r = await call('adsEmailsDispatch', { kind: st.mkind || '' }); status(n(r.sent || 0) + ' envoyé(s), ' + n(r.failed || 0) + ' en échec.'); await reload(); } catch (e) { showError(friendly(e, 'Envoi impossible pour le moment.')); dispatch.disabled = false; }
    });
    act.append(dispatch);
    const statuses = [['all', 'Tous'], ['pending', 'En attente'], ['sent', 'Envoyés'], ['failed', 'En échec']];
    const fs = h('div', { class: 'adchips' }, ...statuses.map(([k, l]) => h('span', { class: st.mstatus === k ? 'on' : false, text: l, onclick: () => { st.mstatus = k; reload(); } })));
    const ks = h('div', { class: 'adchips' }, h('span', { class: st.mkind ? false : 'on', text: 'Tous les types', onclick: () => { st.mkind = ''; reload(); } }), ...(m.kinds || []).map((k) => h('span', { class: st.mkind === k ? 'on' : false, text: k, onclick: () => { st.mkind = st.mkind === k ? '' : k; reload(); } })));
    const q = h('input', { type: 'search', placeholder: 'Chercher une adresse ou un objet', value: st.mq, 'aria-label': 'Chercher un e-mail' });
    q.addEventListener('keydown', (e) => { if (e.key === 'Enter') { st.mq = q.value.trim(); reload(); } });
    const rows = (m.items || []).map((it) => {
      const when = it.sentAt || it.createdAt, d = when ? new Date(when) : null;
      const retry = it.status === 'failed' ? h('button', { class: 'btn btn-line adsm', type: 'button', text: 'Réessayer', onclick: async () => { try { await call('adsEmailRetry', { id: it.id }); status('Remis en file : il repartira à la prochaine passe ou avec « Envoyer maintenant ».'); await reload(); } catch (e) { showError(friendly(e, 'Action impossible pour le moment.')); } } }) : null;
      return h('div', { class: 'rg-row' }, h('span', { text: (it.status === 'sent' ? '✅ ' : it.status === 'failed' ? '❌ ' : '⏳ ') + it.subject + ' · ' + it.to + ' · ' + it.kind + (d ? ' · ' + d.toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '') + (it.error ? ' · ' + it.error : '') }), retry);
    });
    return h('article', { class: 'rg-card' }, h('div', { class: 'rg-h' }, h('div', {}, h('b', { text: 'Suivi des e-mails' }), h('small', { text: 'Derniers e-mails de l’application : état, destinataire et raison des échecs. Le texte n’est jamais affiché.' }))),
      banner, tiles, act, fs, ks, h('label', { class: 'fl' }, h('span', { text: 'Recherche (Entrée)' }), q), ...(rows.length ? rows : [h('p', { class: 'adempty', text: 'Aucun e-mail ne correspond.' })]));
  }
  // « Soldes » : l'équipe d'argent recharge GRATUITEMENT le solde d'un annonceur, retrouvé par son e-mail (aucun paiement, motif obligatoire, journal de l'équipe)
  let walKey = '';
  const newKey = () => { walKey = (window.crypto && crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + Math.random().toString(36).slice(2)).replace(/[^A-Za-z0-9-]/g, ''); };
  newKey();
  function walCard() {
    const email = h('input', { type: 'email', placeholder: 'adresse e-mail de l’annonceur', autocomplete: 'off', 'aria-label': 'Adresse e-mail de l’annonceur' });
    const result = h('div', { class: 'rg-act' });
    const find = async () => {
      const v = email.value.trim(); if (!v) return showError('Écris l’adresse e-mail de l’annonceur.');
      result.replaceChildren(h('small', { text: 'Recherche…' }));
      try {
        const w = await call('adsWalletAdminFind', { email: v });
        const amt = h('input', { type: 'number', min: '100', max: '5000000', step: '500', value: '10000', 'aria-label': 'Montant offert en francs' });
        const why = h('input', { maxlength: '200', placeholder: 'Motif (ex. : offre de lancement)', 'aria-label': 'Motif' });
        const quick = h('div', { class: 'adchips' }, ...[5000, 10000, 25000, 50000].map((x) => h('span', { text: n(x), onclick: () => { amt.value = String(x); } })));
        const go = h('button', { class: 'btn btn-primary adsm', type: 'button', text: 'Recharger gratuitement' });
        go.addEventListener('click', async () => {
          if (String(why.value).trim().length < 5) return showError('Écris le motif de cette recharge (5 caractères au moins).');
          go.disabled = true;
          try {
            const r = await call('adsWalletAdminGift', { email: w.email, amount: Number(amt.value), reason: why.value.trim(), key: walKey });
            newKey(); showSuccess('Solde rechargé : ' + n(r.creditedXof) + ' F offerts. Nouveau solde de ' + (w.brand || w.name || w.email) + ' : ' + n(r.balanceXof) + ' F.'); find();
          } catch (e) { showError(nice(e)); } finally { go.disabled = false; }
        });
        result.replaceChildren(
          h('div', { class: 'rg-row' }, h('span', { text: 'Compte' }), h('b', { text: (w.name ? w.name + ' · ' : '') + w.email })),
          h('div', { class: 'rg-row' }, h('span', { text: 'Marque annonceur' }), h('b', { text: w.brand ? w.brand + (w.brandStatus === 'approved' ? '' : ' (profil non validé)') : 'aucun profil annonceur' })),
          h('div', { class: 'rg-row' }, h('span', { text: 'Solde actuel' }), h('b', { text: n(w.balanceXof) + ' F' })),
          h('label', { class: 'fl' }, h('span', { text: 'Montant à offrir (F)' }), amt), quick, h('label', { class: 'fl' }, h('span', { text: 'Motif' }), why), go);
      } catch (e) { result.replaceChildren(h('small', { class: 'aderr', text: nice(e) })); }
    };
    email.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); find(); } });
    return h('article', { class: 'rg-card' }, h('div', { class: 'rg-h' }, h('div', {}, h('b', { text: 'Recharger un compte annonceur (offert)' }), h('small', { text: 'Cherche l’annonceur par son adresse e-mail. Aucun paiement : le montant est offert par Afrolook Ads et noté dans le journal de l’équipe.' }))),
      h('label', { class: 'fl' }, h('span', { text: 'Adresse e-mail' }), email), h('div', { class: 'rg-act' }, h('button', { class: 'btn btn-line adsm', type: 'button', text: 'Chercher', onclick: find })), result);
  }
  async function load() {
    loadKpis();
    if (st.tab === 'wal') { draw(); return; }
    if (st.tab === 'mail') {
      $('#rg-list').replaceChildren(h('p', { class: 'adempty', text: 'Chargement…' }));
      try { st.mail = await call('adsEmailsAdmin', { status: st.mstatus, kind: st.mkind || undefined, q: st.mq || undefined }); draw(); }
      catch (e) { $('#rg-list').replaceChildren(h('p', { class: 'adempty', text: friendly(e, 'Impossible de charger les e-mails pour le moment.') })); }
      return;
    }
    $('#rg-list').replaceChildren(h('p', { class: 'adempty', text: 'Chargement…' }));
    try {
      if (st.tab === 'pay') { const r = await call('adsPubAdminList', { payouts: true, status: st.filter, page: st.page }); st.pays = r.payouts || []; st.payMeta = r; draw(); return; }
      if (st.tab === 'ads') { const r = await call('adsPubAdminList', { ads: true, status: st.filter }); if (!Array.isArray(r.ads)) throw new Error('API pas à jour : la liste des annonces n’existe pas encore sur le serveur. Redéploie l’API.'); st.ads = r.ads; draw(); return; }
      if (st.tab === 'share') { const r = await call('adsPubAdminList', { sharers: true, status: st.filter === 'hold' ? 'all' : st.filter }); st.sharers = r.sharers; st.totals = r.totals || null; draw(); return; }
      if (st.tab === 'camp') { st.camps = (await call('adsPubAdminList', { campaigns: true, status: st.filter })).campaigns; draw(); return; }
      if (st.tab === 'alert') { const r = await call('adsPubAdminList', { alerts: true, status: st.afilter }); st.alerts = r.alerts; if (st.afilter === 'open') st.alertsOpen = r.alerts.length; draw(); return; }
      const advStatus = ({ all: 'all', pending: 'pending', active: 'approved', refused: 'rejected' })[st.filter];
      const [a, p, al] = await Promise.all([advStatus ? call('adsAdvAdminList', { status: advStatus }) : Promise.resolve({ items: [] }), call('adsPubAdminList', { status: st.filter }), call('adsPubAdminList', { alerts: true, status: 'open' }).catch(() => ({ alerts: [] }))]);
      st.adv = a.items; st.profiles = p.profiles; st.props = p.properties; st.alertsOpen = al.alerts.length; draw();
    } catch (e) { st.adv = st.profiles = st.props = st.ads = st.pays = []; drawBar(); $('#rg-list').replaceChildren(h('p', { class: 'aderr', text: nice(e) })); showError(nice(e)); }
  }
}

// ───────── section des formats : bascule téléphone / ordinateur ─────────
const fmts = $('.fmts');
if (fmts) $$('.fmt-tabs button', fmts).forEach((b) => b.addEventListener('click', () => { fmts.dataset.dev = b.dataset.dev; $$('.fmt-tabs button', fmts).forEach((x) => { x.classList.toggle('on', x === b); x.setAttribute('aria-selected', x === b ? 'true' : 'false'); }); }));

