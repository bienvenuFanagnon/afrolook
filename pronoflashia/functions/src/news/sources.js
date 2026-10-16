'use strict';
// Sources d'actualités football : flux RSS publics. On ne garde que le titre, le nom du site, la date et le lien vers l'article.
// `actif` : état de départ (modifiable dans l'admin). `filtre` : flux généraliste dont on ne garde que les titres de football.
// Les flux marqués actif: false ont refusé nos robots lors des essais : à tester depuis le serveur, puis à activer si ça passe.

const FOOT_FR = /\b(foot|football|ligue|CAN|CAF|FIFA|UEFA|coupe|mondial|éliminatoires|championnat|Lions|Éléphants|Aigles|Pharaons|Super Eagles|Black Stars)\b/i;
const FOOT_EN = /\b(football|soccer|AFCON|CAF|FIFA|UEFA|league|cup|Premier League|World Cup|qualifier)/i;

const SOURCES = [
  { id: 'africatopsports', nom: 'Africa Top Sports', url: 'https://www.africatopsports.com/feed/', lang: 'fr', filtre: FOOT_FR, actif: true },
  { id: 'afrikfoot', nom: 'Afrik-Foot', url: 'https://www.afrik-foot.com/feed', lang: 'fr', filtre: null, actif: true },
  { id: 'footmercato', nom: 'Foot Mercato', url: 'https://www.footmercato.net/flux-rss', lang: 'fr', filtre: null, actif: true },
  { id: 'africanews', nom: 'Africanews', url: 'https://www.africanews.com/feed/rss?themes=sport', lang: 'en', filtre: FOOT_EN, actif: true },
  { id: 'footafrique', nom: 'Foot Afrique', url: 'https://www.footafrique.com/feed', lang: 'fr', filtre: null, actif: false },
  { id: 'rmcsport', nom: 'RMC Sport', url: 'https://rmcsport.bfmtv.com/rss/football/', lang: 'fr', filtre: null, actif: false },
  { id: 'rfisport', nom: 'RFI Sport', url: 'https://www.rfi.fr/fr/sport/rss', lang: 'fr', filtre: FOOT_FR, actif: false },
  { id: 'lemonde', nom: 'Le Monde Football', url: 'https://www.lemonde.fr/football/rss_full.xml', lang: 'fr', filtre: null, actif: false },
];

module.exports = { SOURCES, FOOT_FR, FOOT_EN };
