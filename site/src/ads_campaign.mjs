// Sections de la page « Annoncer » consacrées à la CAMPAGNE PARTAGE (annonce partagée sur WhatsApp, Telegram, Facebook…) : simulateur d'audience,
// exemples d'affichage (illustrations fabriquées, sans logo ni donnée réelle), confiance et anti-fraude, réseau de partageurs.
// Aucun chiffre de résultat n'est promis : le simulateur donne une ESTIMATION à partir du tarif et du taux de visite réels du moment (API publique /ads/api/audience).
// Les fonctions reçoivent `ico` (icônes de ads.mjs) pour éviter un import circulaire.

const T = {
  fr: {
    simK: 'Simulateur d\'audience', simH: 'Combien de personnes touches-tu avec ton budget ?',
    simSub: 'Choisis ton budget : tu vois tout de suite l\'audience que tu paies et les visites que tu peux attendre sur ton lien (site, application, page WhatsApp…).',
    budget: 'Mon budget', aud: ['Audience payée', 'personnes à atteindre'], vis: ['Visites estimées', 'sur ton lien'], cpv: ['Coût par visite', 'estimé'],
    note: (ctr, per) => `Estimation indicative : le nombre de visites dépend de ceux qui cliquent sur ton lien ; la fourchette suit les résultats constatés sur Afrolook. Tarif actuel : ${per} F pour 1 000 personnes. Tu paies l'audience ; seules les visites valides sont comptées et tu suis tout en direct dans ton espace.`,
    go: 'Lancer cette campagne',
    chK: 'Exemples d\'affichage', chH: 'Voilà comment ton annonce apparaît chez les partageurs.',
    chSub: 'Chaque partageur publie ton annonce avec ton visuel, ton texte et un lien suivi : une page d\'aperçu s\'ouvre, puis la personne arrive sur ton site, ton application ou ta page.',
    chCap: 'Illustrations : exemples d\'affichage avec une annonce fictive. Le rendu exact dépend de l\'application du partageur.',
    wa: ['Statut WhatsApp', 'Ton annonce en statut : vue par tous les contacts du partageur.'], grp: ['Groupes WhatsApp et Telegram', 'Message avec aperçu du lien dans les groupes et les canaux.'],
    fb: ['Publication Facebook', 'Ton annonce dans le fil, avec l\'aperçu de ton lien.'], af: ['Fil Afrolook', 'Et sur nos plateformes, avec les annonces gratuites.'],
    ad: { name: 'Boutique Awa', title: 'Pagnes wax : nouvelle collection', text: 'Livraison dans toute l\'Afrique de l\'Ouest. Paiement Mobile Money accepté.', cta: 'Voir la collection', who: 'Ama', ago: 'il y a 2 h', reply: 'Répondre', pub: '(Pub)', group: 'Mode et beauté', friend: 'Qui connaît une bonne boutique de pagnes ?', members: 'Groupe', channel: 'Canal' },
    trK: 'Confiance et sécurité', trH: 'Tu paies de vraies visites, pas des promesses.',
    trSub: 'Notre système est conçu pour que ton budget serve une audience réelle. Voici ce qui te protège.',
    tr: [
      ['Audience mesurée par nous', 'Chaque partageur a un lien personnel suivi. Nous comptons les vraies ouvertures de ton annonce : l\'audience payée est celle qui est effectivement touchée, jamais une simple déclaration.'],
      ['Ton budget est un plafond', 'La campagne se ferme dès que l\'audience choisie est atteinte. Elle ne dépasse jamais ton budget et tu vois l\'audience touchée avancer en direct.'],
      ['Un clic = une personne', 'Doublons, auto-clics et robots sont écartés : seules les visites valides sont comptées vers ton site, ton application ou ta page.'],
      ['Système anti-fraude', 'Des contrôles automatiques surveillent chaque lien. Les comportements suspects bloquent le compte, les gains frauduleux sont retenus puis repris, et les fraudes ne sont jamais comptées pour toi.'],
      ['Partageurs validés', 'Chaque partageur présente son audience et notre équipe la valide avant sa première mission. Ton annonce est aussi relue avant d\'être proposée.'],
      ['Paiement sécurisé, remboursement si refus', 'Tu recharges ton solde annonceur par Mobile Money ou carte bancaire. Si notre équipe refuse ton annonce, le montant retourne sur ton solde pour une autre campagne.'],
    ],
    nwK: 'Un réseau de partageurs', nwH: 'Des diffuseurs partout en Afrique, sur les applications que tout le monde utilise.',
    nwSub: 'Ton annonce est publiée par des personnes inscrites sur Afrolook qui ont une vraie audience : contacts et statuts WhatsApp, groupes, canaux Telegram, Facebook, TikTok.',
    nw: [['WhatsApp', 'Statuts, groupes et conversations'], ['Telegram', 'Groupes et canaux'], ['Facebook', 'Profils, pages et groupes'], ['TikTok', 'Comptes et communautés'], ['Sites et applications', 'Diffuseurs partenaires']],
    nwCta: 'Lancer ma campagne', nwGhost: 'Devenir diffuseur',
    stepK: 'Comment ça marche', stepH: 'Quatre étapes pour lancer ta campagne.',
    steps: [['Choisis ton audience', 'Tu fixes le nombre de personnes à atteindre ; le prix est affiché avant que tu valides.'], ['Recharge ton solde', 'Mobile Money ou carte bancaire. Le solde sert à payer tes campagnes.'], ['Les partageurs publient', 'Après relecture par notre équipe, ton annonce est proposée aux partageurs validés.'], ['Tu suis tes résultats', 'Audience touchée, visites valides et budget utilisé, en direct dans ton espace annonceur.']],
  },
  en: {
    simK: 'Audience simulator', simH: 'How many people do you reach with your budget?',
    simSub: 'Pick your budget: you instantly see the audience you pay for and the visits you can expect on your link (website, app, WhatsApp page…).',
    budget: 'My budget', aud: ['Audience paid', 'people to reach'], vis: ['Estimated visits', 'on your link'], cpv: ['Cost per visit', 'estimated'],
    note: (ctr, per) => `Indicative estimate: the number of visits depends on who clicks your link; the range follows the results observed on Afrolook. Current rate: ${per} F per 1,000 people. You pay for the audience; only valid visits are counted and you follow everything live in your space.`,
    go: 'Launch this campaign',
    chK: 'Display examples', chH: 'This is how your ad appears with the sharers.',
    chSub: 'Each sharer posts your ad with your visual, your text and a tracked link: a preview page opens, then the person lands on your website, your app or your page.',
    chCap: 'Illustrations: display examples with a fictional ad. The exact look depends on the sharer\'s app.',
    wa: ['WhatsApp status', 'Your ad as a status: seen by all the sharer\'s contacts.'], grp: ['WhatsApp and Telegram groups', 'A message with a link preview in groups and channels.'],
    fb: ['Facebook post', 'Your ad in the feed, with your link preview.'], af: ['Afrolook feed', 'And on our platforms, with the free ads.'],
    ad: { name: 'Awa Boutique', title: 'Wax prints: new collection', text: 'Delivery across West Africa. Mobile Money accepted.', cta: 'See the collection', who: 'Ama', ago: '2 h ago', reply: 'Reply', pub: '(Ad)', group: 'Fashion and beauty', friend: 'Anyone know a good wax print shop?', members: 'Group', channel: 'Channel' },
    trK: 'Trust and security', trH: 'You pay for real visits, not promises.',
    trSub: 'Our system is designed so your budget serves a real audience. Here is what protects you.',
    tr: [
      ['Audience measured by us', 'Each sharer has a personal tracked link. We count the real openings of your ad: the audience you pay for is the audience actually reached, never a mere declaration.'],
      ['Your budget is a ceiling', 'The campaign closes as soon as the audience you chose is reached. It never exceeds your budget and you watch the audience reached grow live.'],
      ['One click = one person', 'Duplicates, self-clicks and bots are discarded: only valid visits to your website, app or page are counted.'],
      ['Anti-fraud system', 'Automatic checks watch every link. Suspicious behavior blocks the account, fraudulent earnings are held then taken back, and frauds are never counted for you.'],
      ['Approved sharers', 'Each sharer describes their audience and our team approves it before their first mission. Your ad is also reviewed before it is offered.'],
      ['Secure payment, refund if refused', 'You top up your advertiser balance by Mobile Money or bank card. If our team refuses your ad, the amount goes back to your balance for another campaign.'],
    ],
    nwK: 'A network of sharers', nwH: 'Publishers all over Africa, on the apps everyone uses.',
    nwSub: 'Your ad is published by people registered on Afrolook who have a real audience: WhatsApp contacts and statuses, groups, Telegram channels, Facebook, TikTok.',
    nw: [['WhatsApp', 'Statuses, groups and chats'], ['Telegram', 'Groups and channels'], ['Facebook', 'Profiles, pages and groups'], ['TikTok', 'Accounts and communities'], ['Websites and apps', 'Partner publishers']],
    nwCta: 'Launch my campaign', nwGhost: 'Become a publisher',
    stepK: 'How it works', stepH: 'Four steps to launch your campaign.',
    steps: [['Choose your audience', 'You set the number of people to reach; the price is shown before you confirm.'], ['Top up your balance', 'Mobile Money or bank card. The balance pays for your campaigns.'], ['Sharers publish', 'After review by our team, your ad is offered to approved sharers.'], ['You follow the results', 'Audience reached, valid visits and budget used, live in your advertiser space.']],
  },
};

/** Maquette d'un statut WhatsApp (CSS seul, annonce fictive). */
export function waPhone(lang) {
  const t = T[lang], a = t.ad;
  return `<div class="chm-ph chm-wa"><div class="chm-bars"><i class="on"></i><i></i><i></i></div>
   <div class="chm-top"><span class="chm-av">${a.who[0]}</span><span><b>${a.who}</b><small>${a.ago}</small></span></div>
   <div class="chm-st"><div class="chm-vis"><i>🛍️</i><b>${a.title}</b></div><p>${a.title}<br>${a.text}<br>👉 afrolookmedia.com/p/a8Kd3mQx ${a.pub}</p></div>
   <div class="chm-reply">${a.reply}</div></div>`;
}

const BUDGETS = [5000, 10000, 25000, 50000, 100000];

/** Simulateur : budget → audience payée, visites estimées, coût par visite. Le script (ads.js) lit data-per (FCFA pour 1 000 personnes) et data-ctr (%), mis à jour depuis l'API. */
export function simulatorSection(lang, api, ico, G) {
  const t = T[lang], loc = lang === 'fr' ? 'fr-FR' : 'en-US';
  return `<section class="adsec" id="simulateur"><div class="wrap"><span class="kicker">${t.simK}</span><h2 class="h2">${t.simH}</h2><p class="sub">${t.simSub}</p>
<div class="adsim" id="adsim" data-api="${api}/ads/api/audience" data-per="500" data-ctr="2">
 <div class="adsim-in"><label class="adsim-l" for="sim-n">${t.budget}</label>
  <div class="adsim-n"><input id="sim-n" type="number" inputmode="numeric" min="1000" max="2500000" step="500" value="25000" aria-label="${t.budget}"><b>F CFA</b></div>
  <input id="sim-b" type="range" min="1000" max="200000" step="1000" value="25000" aria-label="${t.budget}">
  <div class="adchips" id="sim-quick">${BUDGETS.map((b) => `<span data-v="${b}">${b.toLocaleString(loc)}</span>`).join('')}</div></div>
 <div class="adsim-out" aria-live="polite">
  <div class="adsim-k"><small>${t.aud[0]}</small><b id="sim-aud">—</b><span>${t.aud[1]}</span></div>
  <div class="adsim-k"><small>${t.vis[0]}</small><b id="sim-vis">—</b><span>${t.vis[1]}</span></div>
  <div class="adsim-k"><small>${t.cpv[0]}</small><b id="sim-cpv">—</b><span>${t.cpv[1]}</span></div>
 </div>
 <p class="adsim-note" id="sim-note">${t.note('2', '500')}</p>
 <a class="btn btn-primary adbig" id="sim-go" href="/ads/espace/">${G} ${t.go}</a>
</div></div></section>`;
}

/** Quatre maquettes (CSS seul, sans logo ni capture réelle) : statut WhatsApp, groupe, Facebook, fil Afrolook. */
export function channelMocks(lang, ico, phoneHtml) {
  const t = T[lang], a = t.ad;
  const card = `<div class="chm-card"><div class="chm-img" aria-hidden="true"><i>🛍️</i></div><b>${a.title}</b><span>${a.text}</span><em>afrolookmedia.com</em></div>`;
  return `<section class="adsec soft" id="exemples"><div class="wrap"><span class="kicker">${t.chK}</span><h2 class="h2">${t.chH}</h2><p class="sub">${t.chSub}</p>
<div class="chm-grid">
 <figure class="chm">${waPhone(lang)}<figcaption><b>${t.wa[0]}</b><span>${t.wa[1]}</span></figcaption></figure>
 <figure class="chm"><div class="chm-ph chm-tg"><div class="chm-top"><span class="chm-av g">${a.group[0]}</span><span><b>${a.group}</b><small>${a.members}</small></span></div>
   <div class="chm-chat"><div class="chm-b in">${a.friend}</div><div class="chm-b out">${card}<p>👉 afrolookmedia.com/p/a8Kd3mQx ${a.pub}</p></div></div></div><figcaption><b>${t.grp[0]}</b><span>${t.grp[1]}</span></figcaption></figure>
 <figure class="chm"><div class="chm-ph chm-fb"><div class="chm-top"><span class="chm-av b">${a.who[0]}</span><span><b>${a.who}</b><small>${a.ago}</small></span></div>
   <p class="chm-cap">${a.title} · ${a.text}<br>👉 afrolookmedia.com/p/a8Kd3mQx ${a.pub}</p>${card}
   <div class="chm-react">👍 ❤️ · 💬 · ↗</div></div><figcaption><b>${t.fb[0]}</b><span>${t.fb[1]}</span></figcaption></figure>
 <figure class="chm"><div class="chm-ph chm-af">${phoneHtml}</div><figcaption><b>${t.af[0]}</b><span>${t.af[1]}</span></figcaption></figure>
</div><p class="chm-cap-note">${t.chCap}</p></div></section>`;
}

export function trustSection(lang, ico) {
  const t = T[lang];
  return `<section class="adsec" id="confiance"><div class="wrap"><span class="kicker">${t.trK}</span><h2 class="h2">${t.trH}</h2><p class="sub">${t.trSub}</p>
<div class="adp3">${t.tr.map(([h, p]) => `<article class="adp"><div class="adp-top"><i class="adp-logo plus">${ico('shield', 22)}</i><div><h3>${h}</h3></div></div><p>${p}</p></article>`).join('')}</div></div></section>`;
}

export function networkSection(lang, ico) {
  const t = T[lang];
  return `<section class="adsec soft" id="reseau"><div class="wrap"><span class="kicker">${t.nwK}</span><h2 class="h2">${t.nwH}</h2><p class="sub">${t.nwSub}</p>
<div class="adnet">${t.nw.map(([h, p]) => `<div class="adnet-i"><b>${h}</b><span>${p}</span></div>`).join('')}</div>
<div class="cta" style="margin-top:26px"><a class="btn btn-primary adbig" href="/ads/espace/">${t.nwCta}</a><a class="btn btn-line adbig" href="/ads/diffuseur/">${t.nwGhost}</a></div></div></section>`;
}

export function stepsSection(lang) {
  const t = T[lang];
  return `<section class="adsec" id="partage"><div class="wrap"><span class="kicker">${t.stepK}</span><h2 class="h2">${t.stepH}</h2>
<div class="ads4">${t.steps.map(([h, p], i) => `<article class="ads"><i>${i + 1}</i><h3>${h}</h3><p>${p}</p></article>`).join('')}</div></div></section>`;
}
