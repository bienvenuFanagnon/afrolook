// Afrolook Ads : section « Les formats » de la page /ads/. Chaque format est reproduit dans un téléphone (application et sites mobiles)
// et dans une fenêtre d'ordinateur (sites) ; une bascule change l'appareil de toutes les cartes. Dessins en HTML et CSS (styles : ads.css, bloc « formats »).
const IM = (n) => `/img/ads/${n}.webp`;
const sk = (n) => Array.from({ length: n }, (_, i) => `<i class="sk${i % 3 === 2 ? ' s' : ''}"></i>`).join('');
const tag = '<span class="mt">Annonce</span>';
const go = (t) => `<span class="go">${t}</span>`;
const post = () => `<div class="po"><i class="av"></i><div>${sk(2)}</div></div><div class="pic"></div>${sk(2)}`;
const phone = (inner, cls = '') => `<div class="dvp ${cls}"><i class="nt"></i><div class="scr"><div class="sbr"><span>9:41</span><span>5G ▮▮▮</span></div>${inner}</div></div>`;
const desk = (inner) => `<div class="dvd"><div class="bar"><i></i><i></i><i></i><b></b></div><div class="pg"><div class="dh"><b>MonSite</b>${sk(1)}</div>${inner}</div></div>`;
const cols = (main, side) => `<div class="cols"><div class="mn">${main}</div><div class="sd">${side}</div></div>`;
const sideSk = `<div class="sb1"></div><div class="sb1 t"></div>${sk(3)}`;
const card = (img, title, btn, extra = '') => `<div class="adc">${tag}${extra}<img src="${IM(img)}" alt=""><div class="b"><b class="t">${title}</b>${sk(1)}${go(btn)}</div></div>`;
const hcard = (img, title, btn) => `<div class="adc h">${tag}<img src="${IM(img)}" alt=""><div class="b"><b class="t">${title}</b>${sk(2)}${go(btn)}</div></div>`;
const strip = (cls = '') => `<div class="bn ${cls}">${tag}<i class="lg"></i><div>${sk(2)}</div>${go('Visiter')}</div>`;

const FORMATS = [
  { n: 'Carte native', free: true, where: 'Application et sites', p: 'Image, titre, texte et bouton, au milieu du fil ou d\'un article, étiquetée « Annonce ».',
    ph: phone(`<div class="hd"><b>Afrolook</b></div>${post()}${card('carte', 'Kofi Studio', 'Visiter le site')}${post()}`),
    dk: desk(cols(`${sk(3)}${hcard('carte', 'Kofi Studio', 'Visiter')}${sk(3)}`, sideSk)) },
  { n: 'Vidéo dans le fil', free: true, where: 'Application et sites', p: 'Une vidéo de 15 secondes au maximum, qui se lance sans son quand elle est à l\'écran.',
    ph: phone(`<div class="hd"><b>Afrolook</b></div>${post()}<div class="adc">${tag}<div class="vd"><img src="${IM('video')}" alt=""><span class="pl">▶</span><span class="tm">0:12</span></div><div class="b"><b class="t">Atelier Kofi</b>${go('Télécharger')}</div></div>${sk(3)}`),
    dk: desk(cols(`${sk(2)}<div class="adc"><div class="vd w"><img src="${IM('video')}" alt=""><span class="pl">▶</span><span class="tm">0:12</span></div>${tag}</div>${sk(3)}`, sideSk)) },
  { n: 'Carrousel', free: true, where: 'Application et sites', p: 'De 2 à 5 images que le visiteur fait glisser.',
    ph: phone(`<div class="hd"><b>Afrolook</b></div>${post()}<div class="adc">${tag}<div class="car"><img src="${IM('carrousel')}" alt=""><img src="${IM('affiche')}" alt=""></div><div class="dots"><i class="on"></i><i></i><i></i></div><div class="b"><b class="t">Nos nouveautés</b>${go('En savoir plus')}</div></div>`),
    dk: desk(cols(`${sk(2)}<div class="adc">${tag}<div class="car w"><img src="${IM('carrousel')}" alt=""><img src="${IM('affiche')}" alt=""><img src="${IM('banniere')}" alt=""></div><span class="arr l">‹</span><span class="arr r">›</span></div>${sk(2)}`, sideSk)) },
  { n: 'Bannière', free: true, where: 'Application et sites', p: 'Un bandeau discret en haut, au milieu ou en bas : 320×50 sur téléphone, 728×90 sur ordinateur.',
    ph: phone(`<div class="hd"><b>Afrolook</b></div>${strip()}${post()}${post()}`),
    dk: desk(`${strip('lb')}${cols(`${sk(4)}<div class="pic"></div>${sk(3)}`, sideSk)}`) },
  { n: 'Bandeau collant', free: false, where: 'Application et sites', p: 'Reste en bas de l\'écran pendant la lecture, et se ferme d\'un geste.',
    ph: phone(`<div class="hd"><b>Afrolook</b></div>${post()}${post()}<div class="stk">${tag}<i class="lg"></i><div>${sk(2)}</div>${go('Visiter')}<em>✕</em></div>`),
    dk: desk(`${cols(`${sk(5)}<div class="pic"></div>${sk(3)}`, sideSk)}<div class="stk d">${tag}<i class="lg"></i><div>${sk(2)}</div>${go('Visiter')}<em>✕</em></div>`) },
  { n: 'Affiche', free: true, where: 'Application et sites', p: 'Une grande image verticale : pleine largeur dans le fil, dans la colonne de droite sur ordinateur.',
    ph: phone(`<div class="hd"><b>Afrolook</b></div><div class="adc poster">${tag}<img src="${IM('affiche')}" alt=""><div class="b">${go('En savoir plus')}</div></div>`),
    dk: desk(cols(`${sk(5)}<div class="pic"></div>${sk(4)}`, `<div class="adc tall">${tag}<img src="${IM('affiche')}" alt=""><div class="b">${go('Voir')}</div></div>`)) },
  { n: 'Plein écran (interstitiel)', free: false, where: 'Application et sites', p: 'Entre deux écrans, fermable après 3 secondes, au plus une fois toutes les 10 minutes pour la même personne.',
    ph: phone(`<div class="ov"><em class="x">✕ 3</em>${tag}<img src="${IM('carte')}" alt=""><b class="t">Kofi Studio</b>${go('Télécharger')}</div>`, 'full'),
    dk: desk(`${cols(`${sk(5)}<div class="pic"></div>${sk(3)}`, sideSk)}<div class="dim"></div><div class="mdl">${tag}<em class="x">✕</em><img src="${IM('carte')}" alt=""><b class="t">Kofi Studio</b>${go('Télécharger')}</div>`) },
  { n: 'Récompensée', free: false, where: 'Application et sites', p: 'Le visiteur choisit de la regarder en entier pour une récompense : des pièces, un contenu débloqué.',
    ph: phone(`<div class="hd"><b>Afrolook</b></div>${post()}${post()}<div class="dim"></div><div class="dlg"><b>Regarde 15 s</b><small>pour gagner</small><b class="g">5 pièces</b><div class="prg"><i></i></div>${go('Regarder')}<small>Non merci</small></div>`),
    dk: desk(`${cols(`${sk(5)}<div class="pic"></div>${sk(3)}`, sideSk)}<div class="dim"></div><div class="mdl r"><b>Regarde 15 s pour lire la suite</b><div class="prg"><i></i></div>${go('Regarder')}<small>Non merci</small></div>`) },
  { n: 'Notification', free: false, where: 'Téléphone et navigateurs', p: 'Une notification pour les personnes qui l\'acceptent, 3 par jour au plus. Sur sélection de notre équipe.',
    ph: phone(`<div class="clk">9:41<small>Jeudi 29 octobre</small></div><div class="nf"><i class="lg"></i><div><b>Boutique Kofi <span class="mt2">Annonce</span></b><small>−20 % ce week-end, livraison à Lomé</small></div></div>`, 'lock'),
    dk: desk(`${cols(`${sk(5)}<div class="pic"></div>${sk(3)}`, sideSk)}<div class="toast"><i class="lg"></i><div><b>Boutique Kofi <span class="mt2">Annonce</span></b><small>−20 % ce week-end</small></div></div>`) },
];

export function formatsSection() {
  return `<section class="adsec soft fmts" id="formats" data-dev="phone"><div class="wrap"><span class="kicker">Les formats</span><h2 class="h2">Le format qui te ressemble, sur téléphone et sur ordinateur.</h2>
<p class="sub">Neuf formats, tous reproduits ici tels que le visiteur les voit. Chaque annonce a un bouton d'action : <b>Visiter le site</b>, <b>Télécharger</b>, <b>En savoir plus</b>, <b>WhatsApp</b> ou <b>Appeler</b>. Un seul visuel suffit : il s'adapte à chaque format.</p>
<div class="fmt-tabs" role="tablist" aria-label="Appareil"><button type="button" class="on" data-dev="phone" role="tab">📱 Sur téléphone et application</button><button type="button" data-dev="desk" role="tab">💻 Sur ordinateur et sites</button></div>
<div class="fmgrid">${FORMATS.map((f) => `<article class="fmc"><div class="mk2"><div class="dvmock p">${f.ph}</div><div class="dvmock d">${f.dk}</div></div>
 <h3>${f.n}</h3><div class="fmchips"><span class="${f.free ? 'g' : 'r'}">${f.free ? 'Offre gratuite et Réseau' : 'Offre Réseau'}</span><span>${f.where}</span></div><p>${f.p}</p></article>`).join('')}</div>
<p class="adnote" style="margin-top:20px">Toutes les annonces portent la mention « Annonce », sont validées par notre équipe et respectent les catégories acceptées par chaque diffuseur. L'offre gratuite couvre nos plateformes ; l'offre Réseau ouvre tous les formats, y compris chez nos partenaires.</p></div></section>`;
}
