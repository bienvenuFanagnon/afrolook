// Maquettes de l'application (HTML/CSS, sans image) : mêmes écrans que dans l'appli Afrolook, pour la page d'accueil et la page Musique.
// Un disque vinyle qui tourne, la page Musique, la fiche d'un titre (deux actions), la feuille de fin d'extrait, le fil avec le lecteur flottant.

const MK = {
  fr: {
    title: 'Musique', tabs: ['Pour toi', 'Gratuites', 'Artistes', 'Ma biblio…'], by: '@kofi_aya · Afrobeat', track: 'Soleil d\'Abidjan',
    preview: 'Extrait gratuit · encore 16 s', post: 'Post', postPrice: 'Post · 🪙 5', buy: 'Acheter · 🪙 100', nouv: '🎤 Nouveautés des artistes',
    rowA: ['Nuits de Cotonou', 'Gratuit', 'Mawuli K.'], rowB: ['Lagos Midnight', '🪙 10', 'Tobi Ade'],
    ficheBy: 'par @kofi_aya · Afrobeat', fiche30: 'Extrait gratuit de 30 secondes', ficheTotal: '0:30 · titre complet 3:24', create: 'Créer un post', buyBtn: 'Acheter', share: 'L\'artiste touche 60 pièces sur ton achat.',
    like: 'Tu aimes ce titre ?', ended: 'L\'extrait gratuit de 30 secondes est terminé.',
    support: ['Écoute ', ' en entier et soutiens ', ' : ', '60 pièces', ' de ton achat vont directement à l\'artiste.'],
    sBuy: 'Acheter le titre · 🪙 100', sBal: 'Ton solde : 240 pièces → 140 après', sAd: 'Écouter en entier avec une pub', sPost: 'Créer un post avec ce son · 🪙 5', later: 'Plus tard',
    follow: 'Suivre', caption: 'Coucher de soleil sur la lagune <u>#Abidjan</u>', use: 'Utiliser · 🪙 5', cap1: 'Page Musique', cap2: 'Deux actions : poster ou acheter', cap3: 'Fin de l\'extrait gratuit', cap4: 'Le lecteur reste dans le fil',
    nav: ['Invitations', 'Messages', 'Business', 'Créer', 'Vidéos', 'Quiz & Étude', 'Lives'], tabs2: ['✨ Pour toi', '⚽ Sport', '📅 Sorties'], gift: 'Cadeau', open: 'Ouvrir', lock: 'Débloquer · 🪙 100', ext: 'Extrait · 12 s',
  },
  en: {
    title: 'Music', tabs: ['For you', 'Free', 'Artists', 'My library'], by: '@kofi_aya · Afrobeat', track: 'Soleil d\'Abidjan',
    preview: 'Free preview · 16 s left', post: 'Post', postPrice: 'Post · 🪙 5', buy: 'Buy · 🪙 100', nouv: '🎤 New from artists',
    rowA: ['Nuits de Cotonou', 'Free', 'Mawuli K.'], rowB: ['Lagos Midnight', '🪙 10', 'Tobi Ade'],
    ficheBy: 'by @kofi_aya · Afrobeat', fiche30: 'Free 30-second preview', ficheTotal: '0:30 · full track 3:24', create: 'Create a post', buyBtn: 'Buy', share: 'The artist receives 60 coins from your purchase.',
    like: 'Enjoying this track?', ended: 'The free 30-second preview has ended.',
    support: ['Listen to ', ' in full and support ', ': ', '60 coins', ' of your purchase go straight to the artist.'],
    sBuy: 'Buy the track · 🪙 100', sBal: 'Your balance: 240 coins → 140 after', sAd: 'Listen in full with an ad', sPost: 'Create a post with this sound · 🪙 5', later: 'Later',
    follow: 'Follow', caption: 'Sunset over the lagoon <u>#Abidjan</u>', use: 'Use · 🪙 5', cap1: 'Music page', cap2: 'Two actions: post or buy', cap3: 'End of the free preview', cap4: 'The player stays in your feed',
    nav: ['Invitations', 'Messages', 'Business', 'Create', 'Videos', 'Quiz & Study', 'Lives'], tabs2: ['✨ For you', '⚽ Sport', '📅 Events'], gift: 'Gift', open: 'Open', lock: 'Unlock · 🪙 100', ext: 'Preview · 12 s',
  },
};

const I = {
  play: 'M8 5v14l11-7z', pause: 'M6 5h4v14H6zM14 5h4v14h-4z', next: 'M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z', prev: 'M6 6h2v12H6zM9.5 12l8.5 6V6z',
  shuffle: 'M10.59 9.17L5.41 4 4 5.41l5.17 5.17 1.42-1.41zM14.5 4l2.04 2.04L4 18.59 5.41 20 17.96 7.46 20 9.5V4h-5.5zm.33 9.41l-1.41 1.41 3.13 3.13L14.5 20H20v-5.5l-2.04 2.04-3.13-3.13z',
  close: 'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z', plus: 'M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6z',
  cam: 'M17 10.5V7a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h12a1 1 0 001-1v-3.5l4 4v-11l-4 4z', lock: 'M18 8h-1V6a5 5 0 00-10 0v2H6a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V10a2 2 0 00-2-2zM9 6a3 3 0 016 0v2H9V6z',
  lib: 'M4 6H2v14c0 1.1.9 2 2 2h14v-2H4V6zm16-4H8c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-1 9h-4v4h-2v-4H9V9h4V5h2v4h4v2z',
  search: 'M15.5 14h-.79l-.28-.27A6.47 6.47 0 0016 9.5 6.5 6.5 0 109.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z',
  mic: 'M12 14c1.66 0 2.99-1.34 2.99-3L15 5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.3-3c0 3-2.54 5.1-5.3 5.1S6.7 14 6.7 11H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c3.28-.48 6-3.3 6-6.72h-1.7z',
  back: 'M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z', more: 'M12 8a2 2 0 100-4 2 2 0 000 4zm0 2a2 2 0 100 4 2 2 0 000-4zm0 6a2 2 0 100 4 2 2 0 000-4z',
  moreh: 'M6 10c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm12 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm-6 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z',
  menu: 'M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z', bell: 'M12 22c1.1 0 2-.9 2-2h-4c0 1.1.89 2 2 2zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2zm-2 1H8v-6c0-2.48 1.51-4.5 4-4.5s4 2.02 4 4.5v6z',
  vol: 'M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z',
  refresh: 'M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z',
  group: 'M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z',
  chatb: 'M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 14H6l-2 2V4h16v12z',
  biz: 'M20 7h-4V5l-2-2h-4L8 5v2H4c-1.1 0-2 .9-2 2v5c0 .75.4 1.38 1 1.73V19c0 1.11.89 2 2 2h14c1.11 0 2-.89 2-2v-3.28c.59-.35 1-.99 1-1.72V9c0-1.1-.9-2-2-2zM10 5h4v2h-4V5zM4 9h16v5h-5v-3H9v3H4V9zm9 6h-2v-2h2v2zm6 4H5v-3h4v1h6v-1h4v3z',
  vlib: 'M4 6H2v14c0 1.1.9 2 2 2h14v-2H4V6zm16-4H8c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-8 12.5v-9l6 4.5-6 4.5z',
  school: 'M5 13.18v4L12 21l7-3.82v-4L12 17l-7-3.82zM12 3L1 9l11 6 9-4.91V17h2V9L12 3z',
  live: 'M21 6h-7.59l3.29-3.29L16 2l-4 4-4-4-.71.71L10.59 6H3c-1.1 0-2 .89-2 2v12c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.11-.9-2-2-2zm0 14H3V8h18v12zM9 10v8l7-4z',
  heart: 'M16.5 3c-1.74 0-3.41.81-4.5 2.09C10.91 3.81 9.24 3 7.5 3 4.42 3 2 5.42 2 8.5c0 3.78 3.4 6.86 8.55 11.54L12 21.35l1.45-1.32C18.6 15.36 22 12.28 22 8.5 22 5.42 19.58 3 16.5 3zm-4.4 15.55l-.1.1-.1-.1C7.14 14.24 4 11.39 4 8.5 4 6.5 5.5 5 7.5 5c1.54 0 3.04.99 3.57 2.36h1.87C13.46 5.99 14.96 5 16.5 5c2 0 3.5 1.5 3.5 3.5 0 2.89-3.14 5.74-7.9 10.05z',
  heartf: 'M12 21l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.18L12 21z',
  repeat: 'M7 7h10v3l4-4-4-4v3H5v6h2V7zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2v4z', bars: 'M5 9.2h3V19H5zM10.6 5h2.8v14h-2.8zm5.6 8H19v6h-2.8z',
  chev: 'M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z', user: 'M12 12a4 4 0 100-8 4 4 0 000 8zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z',
  adp: 'M12 2a10 10 0 100 20 10 10 0 000-20zm-2 14.5v-9l7 4.5-7 4.5z',
};
const ic = (n, c = '') => `<svg class="mi ${c}" viewBox="0 0 24 24" aria-hidden="true"><path d="${I[n]}"/></svg>`;
const disc = (c, s, extra = '') => `<span class="mkd" style="--s:${s}px"><span class="mkr"><i class="mkl" data-c="${c}"></i></span></span>${extra}`;
const arm = () => '<svg class="mka" viewBox="0 0 60 110" aria-hidden="true"><circle cx="44" cy="12" r="9" fill="#26302b" stroke="#6c7a72" stroke-width="1.5"/><circle cx="44" cy="12" r="3.5" fill="#9fb0a7"/><path d="M44 12 L31 89" stroke="#b8c4bd" stroke-width="3.5" stroke-linecap="round" fill="none"/><rect x="22" y="87" width="17" height="12" rx="3" fill="#dfe8e3" transform="rotate(14 30 93)"/></svg>';
const status = '<div class="mkb"><span>9:41</span><span class="mkn"></span><span>5G ▮</span></div>';
const wrap = (cap, inner) => `<figure class="mkw"><div class="mkp"><div class="mk">${status}${inner}</div></div><figcaption>${cap}</figcaption></figure>`;

const pagePhone = (m) => `
<div class="mkab"><span>${ic('back')}</span><b>${m.title}</b><span>${ic('search')}</span><span class="g">${ic('mic')}</span></div>
<div class="mktabs"><span class="on">${m.tabs[0]}</span><span>${m.tabs[1]}</span><span>${m.tabs[2]}</span><span>${m.tabs[3]}</span></div>
<div class="mkhero"><div class="mkst">${disc(0, 148)}${arm()}</div><h4>${m.track}</h4><p>${m.by}</p><span class="mkq">${ic('lock')} ${m.preview}</span>
 <div class="mkctl">${ic('shuffle')}${ic('prev')}<span class="mkpp">${ic('pause')}</span>${ic('next')}</div>
 <div class="mktw"><span class="mkg">${ic('cam')} ${m.postPrice}</span><span class="mkf">${ic('lib')} ${m.buy}</span></div></div>
<div class="mksec">${m.nouv}</div>
<div class="mkrow cur"><i class="mkc" data-c="0"></i><span><b>${m.track}</b><em><u class="pd">🪙 5</u> Kofi Aya</em></span><span class="mkpost">${ic('cam')} ${m.post}</span><span class="mkpl">${ic('pause')}</span></div>
<div class="mkrow"><i class="mkc" data-c="1"></i><span><b>${m.rowA[0]}</b><em><u class="fr">${m.rowA[1]}</u> ${m.rowA[2]}</em></span><span class="mkpost">${ic('cam')} ${m.post}</span><span class="mkpl">${ic('play')}</span></div>
<div class="mkrow"><i class="mkc" data-c="2"></i><span><b>${m.rowB[0]}</b><em><u class="pd">${m.rowB[1]}</u> ${m.rowB[2]}</em></span><span class="mkpost">${ic('cam')} ${m.post}</span><span class="mkpl">${ic('play')}</span></div>`;

const fichePhone = (m) => `
<div class="mkab"><span>${ic('back')}</span><b></b><span>${ic('more')}</span></div>
<div class="mkfp"><div class="mkst big"><span class="mkring"></span>${disc(0, 150)}${arm()}</div><h4>${m.track}</h4><p>${m.ficheBy}</p>
 <div class="mkcard"><b>${ic('lock')} ${m.fiche30}</b><div class="mkseek"><i></i><s></s><em>${ic('lock')}</em></div><div class="mktm"><span>0:14</span><span>${m.ficheTotal}</span></div></div>
 <div class="mkctl">${ic('shuffle')}${ic('prev')}<span class="mkpp">${ic('pause')}</span>${ic('next')}</div>
 <div class="mktw tall"><span class="mkg"><b>${ic('cam')} ${m.create}</b><small>🪙 5</small></span><span class="mkf"><b>${ic('lib')} ${m.buyBtn}</b><small>🪙 100</small></span></div>
 <p class="mkshare">${m.share}</p></div>`;

const sheetPhone = (m) => `
<div class="mkfp dim"><div class="mkst big">${disc(0, 150)}</div><h4>${m.track}</h4><p>${m.ficheBy}</p></div>
<div class="mkscrim"></div>
<div class="mksheet"><i class="mkh"></i>
 <div class="mktop"><span class="mkdw">${disc(0, 56)}<em>${ic('lock')}</em></span><span><b>${m.like}</b><small>${m.ended}</small></span></div>
 <div class="mksup">${ic('heart', 'rd')}<span>${m.support[0]}<b>« ${m.track} »</b>${m.support[1]}<b>@kofi_aya</b>${m.support[2]}<b>${m.support[3]}</b>${m.support[4]}</span></div>
 <span class="mkbuy">${ic('lib')} ${m.sBuy}</span><small class="mkbal">${m.sBal}</small>
 <span class="mkout">${ic('adp')} ${m.sAd}</span><span class="mkout">${ic('cam')} ${m.sPost}</span><span class="mklater">${m.later}</span></div>`;

const feedPhone = (m) => `
<div class="mkab"><span>${ic('menu')}</span><b class="logo">Afrolook</b><i></i><span>${ic('bell')}</span><span>${ic('search')}</span><span class="g">${ic('vol')}</span><span class="g">${ic('refresh')}</span></div>
<div class="mknav">${[['group', 0], ['chatb', 1], ['biz', 2], ['plus', 3], ['vlib', 4], ['school', 5], ['live', 6]].map(([i, k]) => `<span class="${k === 3 ? 'cr' : ''}">${k === 3 ? `<s>${ic('plus')}</s>` : ic(i)}<em>${m.nav[k]}</em></span>`).join('')}</div>
<div class="mktabs2"><span class="on">${m.tabs2[0]}</span><span>${m.tabs2[1]}</span><span>${m.tabs2[2]}</span></div>
<article class="mkth"><i class="mkav">${ic('user')}</i><span class="mkvl"></span><div class="mktc">
 <div class="mkhh"><span class="mkps"><u>@</u>fatou_diop</span><span class="mkflw">${m.follow}</span><span class="mkct">🌍</span>${ic('moreh', 'dm')}</div>
 <p class="mkcap">${m.caption}</p><div class="mkimg"></div>
 <div class="mkcr"><span class="mkcp">${disc(0, 20)}<b>${m.track}</b>${ic('chev')}</span><span class="mkus">${ic('cam')} ${m.use}</span></div>
 <div class="mkac"><span>${ic('chatb')}48</span><span class="on">${ic('heartf')}1,2K</span><span>${ic('repeat')}12</span><span class="mkgf"><s>🏆</s>${m.gift}</span><em class="mkin">${ic('bars')}8,9k</em></div></div></article>
<div class="mkcap2"><span class="mkdsc">${disc(0, 38)}</span><span class="mkt"><b>${m.track}</b><small>${m.ext}</small></span><span class="mkcc">${ic('shuffle')}<s>${ic('pause')}</s>${ic('next')}${ic('close')}</span></div>`;

/** Jeu de téléphones : `which` = liste parmi 'page', 'fiche', 'sheet', 'feed'. */
export function musicMocks(lang, which = ['page', 'fiche', 'sheet', 'feed']) {
  const m = MK[lang];
  const map = { page: [m.cap1, pagePhone], fiche: [m.cap2, fichePhone], sheet: [m.cap3, sheetPhone], feed: [m.cap4, feedPhone] };
  return `<div class="mkrow4">${which.map((k) => wrap(map[k][0], map[k][1](m))).join('')}</div>`;
}
