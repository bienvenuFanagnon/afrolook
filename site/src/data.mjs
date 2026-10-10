// Données du site : styles de cartes, façons de gagner, fêtes nationales. Tout est factuel et repris de l'application.

/** Les 26 styles de cartes (même liste que `CardStyleId` dans l'application). pack : moderne | drapeaux | idees | heritage */
export const CARDS = [
  { id: 'neon', pack: 'moderne', free: true, fr: ['Néon', 'cyber, grille lumineuse'], en: ['Neon', 'cyber, glowing grid'] },
  { id: 'glass', pack: 'moderne', free: true, fr: ['Glass', 'verre dépoli sur fond flou'], en: ['Glass', 'frosted glass on a blurred background'] },
  { id: 'pro', pack: 'moderne', free: true, fr: ['Pro', 'sobre et professionnel'], en: ['Pro', 'clean and professional'] },
  { id: 'manga', pack: 'moderne', fr: ['Manga', 'planche noir et blanc'], en: ['Manga', 'black and white comic page'] },
  { id: 'anime', pack: 'moderne', fr: ['Anime', 'ciel d\'anime au crépuscule'], en: ['Anime', 'anime sky at dusk'] },
  { id: 'magazine', pack: 'moderne', fr: ['Magazine', 'couverture de magazine de mode'], en: ['Magazine', 'fashion magazine cover'] },
  { id: 'collector', pack: 'moderne', fr: ['Collector', 'carte à collectionner holographique'], en: ['Collector', 'holographic trading card'] },
  { id: 'sport', pack: 'moderne', fr: ['Sport', 'affiche de match'], en: ['Sport', 'match poster'] },
  { id: 'gamer', pack: 'moderne', fr: ['Gamer', 'interface de jeu'], en: ['Gamer', 'game interface'] },
  { id: 'y2k', pack: 'moderne', fr: ['Y2K', 'fenêtre rétro des années 2000'], en: ['Y2K', 'retro 2000s window'] },
  { id: 'street', pack: 'moderne', fr: ['Street', 'streetwear, polaroïd au scotch'], en: ['Street', 'streetwear, taped polaroid'] },
  { id: 'flag', pack: 'drapeaux', fr: ['Drapeau', 'le drapeau en plein fond'], en: ['Flag', 'the flag as full background'] },
  { id: 'passport', pack: 'drapeaux', fr: ['Passeport', 'passeport citoyen du monde'], en: ['Passport', 'citizen of the world passport'] },
  { id: 'stamp', pack: 'drapeaux', fr: ['Timbre', 'timbre-poste dentelé'], en: ['Stamp', 'perforated postage stamp'] },
  { id: 'supporter', pack: 'drapeaux', fr: ['Supporter', 'écharpe et écusson'], en: ['Supporter', 'scarf and crest'] },
  { id: 'duo', pack: 'drapeaux', fr: ['Duo', 'deux pays, une carte'], en: ['Duo', 'two countries, one card'] },
  { id: 'pride', pack: 'drapeaux', fr: ['Fierté', 'couronne de drapeaux'], en: ['Pride', 'ring of flags'] },
  { id: 'film', pack: 'idees', fr: ['Film', 'affiche de cinéma'], en: ['Film', 'movie poster'] },
  { id: 'newspaper', pack: 'idees', fr: ['Journal', 'une de journal'], en: ['Newspaper', 'front page'] },
  { id: 'music', pack: 'idees', fr: ['Musique', 'lecteur de musique'], en: ['Music', 'music player'] },
  { id: 'boarding', pack: 'idees', fr: ['Embarquement', 'carte d\'embarquement'], en: ['Boarding pass', 'boarding pass'] },
  { id: 'tarot', pack: 'idees', fr: ['Tarot', 'carte de tarot dorée'], en: ['Tarot', 'golden tarot card'] },
  { id: 'quote', pack: 'idees', fr: ['Citation', 'grosse citation sur dégradé'], en: ['Quote', 'big quote on a gradient'] },
  { id: 'kente', pack: 'heritage', free: true, fr: ['Kente', 'tissage royal, or et vert'], en: ['Kente', 'royal weave, gold and green'] },
  { id: 'wax', pack: 'heritage', free: true, fr: ['Wax', 'motifs pop, couleurs vives'], en: ['Wax', 'pop patterns, bold colors'] },
  { id: 'bogolan', pack: 'heritage', fr: ['Bogolan', 'terre et motifs peints'], en: ['Bogolan', 'earth tones and painted patterns'] },
];
export const PACKS = [
  { id: 'moderne', fr: 'Moderne', en: 'Modern' },
  { id: 'drapeaux', fr: 'Drapeaux', en: 'Flags' },
  { id: 'idees', fr: 'Idées', en: 'Ideas' },
  { id: 'heritage', fr: 'Héritage', en: 'Heritage' },
];

/** Les douze façons de gagner (catalogue de tutoriels de l'application). */
export const EARN = [
  { g: 0, icon: 'heart', fr: ['Les likes', 'Chaque like sur tes posts te rapporte des pièces.'], en: ['Likes', 'Every like on your posts earns you coins.'] },
  { g: 0, icon: 'gift', fr: ['Les cadeaux', 'Tes fans t\'offrent des pièces directement sur tes posts.'], en: ['Gifts', 'Your fans send you coins right on your posts.'] },
  { g: 0, icon: 'chat', fr: ['Les commentaires', 'Un bon commentaire rapporte, et ceux qui l\'aiment aussi.'], en: ['Comments', 'A good comment pays, and so do the people who like it.'] },
  { g: 0, icon: 'eye', fr: ['Les vues', 'Plus ton contenu est vu, plus tu gagnes.'], en: ['Views', 'The more your content is viewed, the more you earn.'] },
  { g: 1, icon: 'tv', fr: ['Canal privé par abonnement', 'Tes abonnés paient pour te suivre.'], en: ['Paid private channel', 'Your subscribers pay to follow you.'] },
  { g: 1, icon: 'film', fr: ['Contenu à paiement unique', 'Vends une vidéo, un ebook ou une formation, une seule fois.'], en: ['One-time paid content', 'Sell a video, an ebook or a course, once.'] },
  { g: 1, icon: 'users', fr: ['Groupes privés payants', 'Fais payer l\'accès à ta communauté privée.'], en: ['Paid private groups', 'Charge for access to your private community.'] },
  { g: 1, icon: 'lock', fr: ['Lives privés payants', 'Fais payer l\'entrée de ton live.'], en: ['Paid private lives', 'Charge for entry to your live.'] },
  { g: 2, icon: 'live', fr: ['Les lives', 'Passe en direct et reçois des cadeaux en temps réel.'], en: ['Lives', 'Go live and receive gifts in real time.'] },
  { g: 2, icon: 'trophy', fr: ['Les DÉFIs', 'Participe, fais voter, remporte la cagnotte.'], en: ['Challenges', 'Take part, get votes, win the prize pool.'] },
  { g: 2, icon: 'link', fr: ['Le parrainage', 'Invite tes amis et gagne avec eux sur leurs achats.'], en: ['Referrals', 'Invite friends and earn with them on their purchases.'] },
  { g: 2, icon: 'rocket', fr: ['Boost et publicités', 'Montre ton profil ou ton post à plus de monde.'], en: ['Boost and ads', 'Show your profile or post to more people.'] },
];

/** Fêtes nationales [mois, jour] : même table que l'application (card_events.dart) et le serveur (cards.ts). */
export const NATIONAL_DAYS = {
  DZ: [7, 5], AO: [11, 11], BJ: [8, 1], BW: [9, 30], BF: [12, 11], BI: [7, 1], CV: [7, 5], CM: [5, 20], CF: [12, 1], TD: [8, 11],
  KM: [7, 6], CG: [8, 15], CD: [6, 30], CI: [8, 7], DJ: [6, 27], EG: [7, 23], GQ: [10, 12], ER: [5, 24], SZ: [9, 6], GA: [8, 17],
  GM: [2, 18], GH: [3, 6], GN: [10, 2], GW: [9, 24], KE: [12, 12], LS: [10, 4], LR: [7, 26], LY: [12, 24], MG: [6, 26], MW: [7, 6],
  ML: [9, 22], MR: [11, 28], MU: [3, 12], MA: [7, 30], MZ: [6, 25], NA: [3, 21], NE: [8, 3], NG: [10, 1], RW: [7, 1], ST: [7, 12],
  SN: [4, 4], SC: [6, 29], SL: [4, 27], SO: [7, 1], ZA: [4, 27], SS: [7, 9], TZ: [12, 9], TG: [4, 27], TN: [3, 20], UG: [10, 9],
  ZM: [10, 24], ZW: [4, 18],
  FR: [7, 14], BE: [7, 21], CA: [7, 1], US: [7, 4], BR: [9, 7], DE: [10, 3], IT: [6, 2], CH: [8, 1], HT: [1, 1], JM: [8, 6],
};
export const AFRICA = new Set(['DZ','AO','BJ','BW','BF','BI','CV','CM','CF','TD','KM','CG','CD','CI','DJ','EG','GQ','ER','SZ','GA','GM','GH','GN','GW','KE','LS','LR','LY','MG','MW','ML','MR','MU','MA','MZ','NA','NE','NG','RW','ST','SN','SC','SL','SO','ZA','SS','TZ','TG','TN','UG','ZM','ZW']);

export const SOCIAL_ICONS = {
  whatsapp: '<path d="M4 20l1.3-4A8 8 0 1 1 8 18.7L4 20z"/>',
  facebook: '<path d="M14 8h3V4h-3a4 4 0 0 0-4 4v3H7v4h3v6h4v-6h3l1-4h-4V8z"/>',
  youtube: '<rect x="3" y="6" width="18" height="12" rx="4"/><path d="M10 9.5v5l4.5-2.5L10 9.5z"/>',
  x: '<path d="M4 4l16 16M20 4L4 20"/>',
};
export const ICONS = {
  heart: '<path d="M12 21s-7-4.5-9.5-9A5.5 5.5 0 0 1 12 6a5.5 5.5 0 0 1 9.5 6C19 16.5 12 21 12 21z"/>',
  gift: '<rect x="3" y="8" width="18" height="4" rx="1"/><path d="M12 8v13M5 12v8h14v-8M12 8c-2-4-6-3.5-5 0M12 8c2-4 6-3.5 5 0"/>',
  chat: '<path d="M4 5h16v11H9l-5 4V5z"/>',
  eye: '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  trophy: '<path d="M7 4h10v4a5 5 0 0 1-10 0V4z"/><path d="M5 5H3v2a3 3 0 0 0 3 3M19 5h2v2a3 3 0 0 1-3 3M12 13v4M8 21h8M10 17h4"/>',
  tv: '<rect x="3" y="5" width="18" height="12" rx="2"/><path d="M8 21h8M12 17v4"/><path d="M10 9.5l4 2-4 2v-4z"/>',
  film: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18M8 4v5M16 4v5M10 13l4 2.5-4 2.5v-5z"/>',
  users: '<circle cx="9" cy="8" r="3.5"/><path d="M2 20a7 7 0 0 1 14 0M16 5a3.5 3.5 0 0 1 0 7M18 20a7 7 0 0 0-3-5.7"/>',
  live: '<rect x="3" y="6" width="13" height="12" rx="3"/><path d="M16 10l5-3v10l-5-3"/>',
  lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
  link: '<path d="M10 14a4 4 0 0 0 5.5 0l3-3a4 4 0 0 0-5.5-5.5l-1 1M14 10a4 4 0 0 0-5.5 0l-3 3a4 4 0 0 0 5.5 5.5l1-1"/>',
  rocket: '<path d="M5 19c0-3 1-4 3-5l5-5M9 15l-3 3M14 4c3 0 6 1 6 1s1 3 1 6l-7 7-6-6 6-8z"/><circle cx="15" cy="9" r="1.2"/>',
  coin: '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5c0-1 1-1.7 2.5-1.7s2.5.7 2.5 1.7-1 1.5-2.5 1.7-2.5.7-2.5 1.7 1 1.7 2.5 1.7 2.5-.7 2.5-1.7M12 6.5v1.3M12 16.2v1.3"/>',
  send: '<path d="M3 11l18-8-8 18-2-8-8-2z"/>',
  img: '<rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="9" cy="10" r="2"/><path d="M21 16l-5-5-8 9"/>',
  bag: '<path d="M5 8h14l-1 12H6L5 8z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>',
  cap: '<path d="M3 7l9-4 9 4-9 4-9-4z"/><path d="M7 10v5c0 1.5 2.2 3 5 3s5-1.5 5-3v-5"/>',
  sticker: '<path d="M4 5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v9l-6 6H6a2 2 0 0 1-2-2V5z"/><path d="M14 20v-4a2 2 0 0 1 2-2h4"/><circle cx="9" cy="9" r="1"/><circle cx="15" cy="9" r="1"/>',
  sparkle: '<path d="M12 3l1.8 4.6L18 9l-4.2 1.4L12 15l-1.8-4.6L6 9l4.2-1.4L12 3zM18 15l.8 2.2L21 18l-2.2.8L18 21l-.8-2.2L15 18l2.2-.8L18 15z"/>',
  mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>',
  trash: '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
};
export const svgIcon = (n) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[n] || SOCIAL_ICONS[n]}</svg>`;
