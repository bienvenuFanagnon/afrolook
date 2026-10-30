// Génère la maquette « Afrolook Ads » (HTML statique, mêmes styles que le site vitrine). À valider avant tout développement.
import fs from 'node:fs';
import path from 'node:path';

const OUT = 'C:/Users/ANVT/AppData/Local/Temp/claude/D--bienvenu-Projets-otherProjets-afrolook-V2-afrolookofficiel-v2/cd66b75e-9121-492e-887c-0cb48f2d4947/scratchpad/ads-maquette';
const AUDIENCE = 'près de 10 000'; // valeur à justifier par de vraies sources avant la mise en ligne

const IC = {
  globe: 'M12 2a10 10 0 100 20 10 10 0 000-20zm6.9 9h-3.2a15.7 15.7 0 00-1.4-5.2A8 8 0 0118.9 11zM12 4c.9 1.2 1.6 3.2 1.9 7h-3.8c.3-3.8 1-5.8 1.9-7zM4.1 13h3.2c.2 1.9.7 3.7 1.4 5.2A8 8 0 014.1 13zm3.2-2H4.1a8 8 0 014.6-5.2A15.7 15.7 0 007.3 11zM12 20c-.9-1.2-1.6-3.2-1.9-7h3.8c-.3 3.8-1 5.8-1.9 7zm3.3-1.8c.7-1.5 1.2-3.3 1.4-5.2h3.2a8 8 0 01-4.6 5.2z',
  phone: 'M17 1H7a2 2 0 00-2 2v18a2 2 0 002 2h10a2 2 0 002-2V3a2 2 0 00-2-2zm0 18H7V5h10v14z',
  rocket: 'M12 2c3.3 2 5 5.3 5 9 0 1.6-.4 3.1-1 4.4L18 18l-3 1-1.2-1.8H10.2L9 19l-3-1 2-2.6A9.800 9.800 0 017 11c0-3.700 1.700-7 5-9zm0 6a2 2 0 100 4 2 2 0 000-4z',
  poster: 'M5 3h14a2 2 0 012 2v14a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2zm1 12l3-4 2.300 3 3.200-4.200L19 15H6z',
  bag: 'M18 6h-2a4 4 0 00-8 0H6a2 2 0 00-2 2v11a2 2 0 002 2h12a2 2 0 002-2V8a2 2 0 00-2-2zm-6-2a2 2 0 012 2h-4a2 2 0 012-2z',
  check: 'M9 16.2L4.800 12l-1.400 1.400L9 19 21 7l-1.400-1.400z',
  gift: 'M20 7h-2.200A3 3 0 0012 4.200 3 3 0 006.200 7H4a1 1 0 00-1 1v3a1 1 0 001 1v7a2 2 0 002 2h12a2 2 0 002-2v-7a1 1 0 001-1V8a1 1 0 00-1-1zM15 5a1 1 0 110 2h-3a2 2 0 013-2zM9 5a1 1 0 011 2H9a1 1 0 010-2zm2 15H6v-7h5v7zm7 0h-5v-7h5v7z',
  eye: 'M12 5C7 5 2.700 8.100 1 12c1.700 3.900 6 7 11 7s9.300-3.100 11-7c-1.700-3.900-6-7-11-7zm0 11a4 4 0 110-8 4 4 0 010 8zm0-6.400a2.400 2.400 0 100 4.800 2.400 2.400 0 000-4.800z',
  click: 'M9 2v14l3.500-3.500L16 20l2.500-1-3.500-7.500H20L9 2z',
  video: 'M17 10.500V7a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h12a1 1 0 001-1v-3.500l4 4v-11l-4 4z',
  layers: 'M12 2L1 8l11 6 9-4.900V17h2V8L12 2zM5 13.200v4L12 21l7-3.800v-4L12 17l-7-3.800z',
  bell: 'M12 22c1.100 0 2-.9 2-2h-4c0 1.100.9 2 2 2zm6-6v-5c0-3.100-1.600-5.600-4.500-6.300V4a1.500 1.500 0 00-3 0v.7C7.600 5.400 6 7.900 6 11v5l-2 2v1h16v-1l-2-2z',
  banner: 'M3 6h18a1 1 0 011 1v6a1 1 0 01-1 1H3a1 1 0 01-1-1V7a1 1 0 011-1zm2 2v4h14V8H5zm-3 8h20v2H2v-2z',
  card: 'M4 4h16a2 2 0 012 2v12a2 2 0 01-2 2H4a2 2 0 01-2-2V6a2 2 0 012-2zm0 2v6h16V6H4zm0 8v4h9v-4H4zm11 0v4h5v-4h-5z',
  users: 'M16 11c1.700 0 3-1.300 3-3s-1.300-3-3-3-3 1.300-3 3 1.300 3 3 3zm-8 0c1.700 0 3-1.300 3-3S9.700 5 8 5 5 6.300 5 8s1.300 3 3 3zm0 2c-2.300 0-7 1.200-7 3.500V19h14v-2.500C15 14.200 10.300 13 8 13zm8 0c-.3 0-.6 0-1 .1 1.200.8 2 2 2 3.400V19h6v-2.500c0-2.300-4.700-3.500-7-3.500z',
  arrow: 'M5 12h12.200l-5.600-5.600L13 5l8 8-8 8-1.400-1.400 5.600-5.600H5z',
  mail: 'M20 4H4a2 2 0 00-2 2v12a2 2 0 002 2h16a2 2 0 002-2V6a2 2 0 00-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z',
  shield: 'M12 1L3 5v6c0 5.500 3.800 10.700 9 12 5.200-1.300 9-6.500 9-12V5l-9-4zm-1 15l-4-4 1.400-1.400L11 13.200l5.600-5.600L18 9l-7 7z',
  bolt: 'M11 21h-1l1-7H7.500c-.6 0-.6-.3-.4-.7L13 3h1l-1 7h3.500c.5 0 .6.300.4.700L11 21z',
};
const ico = (n, s = 22) => `<svg class="ico" width="${s}" height="${s}" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="${IC[n].replace(/(\d)\.(\d{3})(?=\D|$)/g, '$1.$2')}"/></svg>`;
const G = '<svg width="20" height="20" viewBox="0 0 48 48" aria-hidden="true"><path fill="#FFC107" d="M43.600 20.100H42V20H24v8h11.300C33.700 32.700 29.200 36 24 36c-6.600 0-12-5.400-12-12s5.400-12 12-12c3.100 0 5.800 1.100 7.900 3l5.700-5.700C34 6.100 29.300 4 24 4 13 4 4 13 4 24s9 20 20 20 20-9 20-20c0-1.300-.1-2.600-.4-3.900z"/><path fill="#FF3D00" d="M6.300 14.700l6.600 4.800C14.700 15.100 19 12 24 12c3.100 0 5.800 1.100 7.900 3l5.700-5.700C34 6.100 29.300 4 24 4 16.300 4 9.700 8.300 6.300 14.700z"/><path fill="#4CAF50" d="M24 44c5.200 0 9.900-2 13.400-5.200l-6.200-5.200C29.200 35.100 26.700 36 24 36c-5.200 0-9.600-3.300-11.300-7.900l-6.500 5C9.500 39.600 16.200 44 24 44z"/><path fill="#1976D2" d="M43.600 20.100H42V20H24v8h11.300c-.8 2.200-2.200 4.200-4.100 5.600l6.200 5.200C37 39.200 44 34 44 24c0-1.300-.1-2.600-.4-3.900z"/></svg>';

const head = (title, desc, rel = '') => `<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title}</title><meta name="description" content="${desc}"><link rel="icon" href="${rel}img/favicon-32.png">
<link rel="stylesheet" href="${rel}css/site.css"><link rel="stylesheet" href="${rel}css/ads.css"></head><body>`;

const header = (rel = '', on = '') => `<header class="top"><div class="wrap in">
 <a class="brand" href="${rel}index.html"><img src="${rel}img/logo.webp" width="36" height="36" alt=""><span>afro<i>look</i></span></a>
 <nav class="main" aria-label="Menu"><a href="#">Comment gagner</a><a href="#">Studio Cartes</a><a href="#">Musique</a><a href="#">Fêtes</a><a class="adlink ${on}" href="${rel}ads/index.html">Annoncer</a><a href="#">Contact</a></nav>
 <div class="right"><span class="lang-sw"><span aria-current="true">FR</span><a href="#">EN</a></span><a class="btn btn-line" href="#">Ouvrir sur le web</a><a class="btn btn-primary" href="#">Télécharger</a></div>
</div><div class="tri"></div></header>`;

const footer = (rel = '') => `<footer><div class="tri" style="position:absolute;left:0;right:0;top:0"></div><div class="wrap">
<div class="cols"><div><a class="brand" href="#" style="color:#fff"><img src="${rel}img/logo.webp" width="36" height="36" alt=""><span>afro<i>look</i></span></a><p class="about">Le réseau social qui rémunère ses créateurs. Publier, vendre, partager, retirer.</p></div>
 <div><h4>Produit</h4><ul><li><a href="#">Comment gagner</a></li><li><a href="#">Studio Cartes</a></li><li><a href="#">Musique</a></li><li><a href="${rel}ads/index.html">Afrolook Ads</a></li></ul></div>
 <div><h4>Annonceurs</h4><ul><li><a href="${rel}ads/index.html">Annonce gratuite</a></li><li><a href="${rel}espace/index.html">Mon espace</a></li><li><a href="#">Nous contacter</a></li></ul></div>
 <div><h4>Légal</h4><ul><li><a href="#">Règles et conditions</a></li><li><a href="#">Confidentialité</a></li></ul></div></div>
<div class="bottom"><span>© 2026 Afrolook. Tous droits réservés.</span><span>afrolookmedia.com</span></div></div></footer></body></html>`;

// ── Téléphone : le fil Afrolook avec une annonce « Sponsorisé » et son bouton d'action ──
const phone = (cap = '') => `<figure class="mkw"><div class="mkp"><div class="mk"><div class="mkb"><span>9:41</span><span class="mkn"></span><span>5G ▮</span></div>
<div class="mkab"><span>${ico('globe', 22)}</span><b class="logo">Afrolook</b><i></i><span>${ico('bell', 22)}</span></div>
<div class="mktabs2"><span class="on">✨ Pour toi</span><span>⚽ Sport</span><span>📅 Sorties</span></div>
<div class="admk"><div class="admk-top"><i class="admk-av">K</i><span><b>Kofi Studio</b><small>Sponsorisé · Annonce gratuite</small></span></div>
 <p class="admk-txt">Ton site web professionnel en 7 jours, paiement Mobile Money accepté. 🚀</p>
 <div class="admk-img"><img src="../img/card-collector.webp" alt=""></div>
 <div class="admk-cta"><span>kofistudio.com</span><b>Visiter le site</b></div>
 <div class="admk-meta"><span>${ico('eye', 14)} 2 480</span><span>${ico('click', 14)} 186</span></div></div>
<div class="admk admk2"><div class="admk-top"><i class="admk-av g">M</i><span><b>Maman Ama Cuisine</b><small>Sponsorisé</small></span></div><p class="admk-txt">Commandes de plats togolais livrés à Lomé.</p></div>
</div></div><figcaption>${cap}</figcaption></figure>`;

const stat = (big, label, note) => `<div class="adst"><b>${big}</b><span>${label}</span><small>${note}</small></div>`;

// ───────────────────────── Page /ads/ ─────────────────────────
const gallery = [
  ['../img/card-bogolan.webp', 'Boutique en ligne', 'Tissus bogolan, livraison dans toute l\'Afrique de l\'Ouest.', 'Visiter le site', 'globe', '3 210', '241', 'Site web'],
  ['../img/card-film.webp', 'Court-métrage « Retour au village »', 'Projection gratuite samedi à Abidjan. Entrée libre.', 'En savoir plus', 'poster', '5 804', '412', 'Affiche'],
  ['../img/card-duo.webp', 'App « Taxi Lomé »', 'Commande ta moto-taxi en 2 touches. Disponible sur Android.', 'Télécharger', 'phone', '1 946', '158', 'Application'],
  ['../img/card-anime.webp', 'Académie de dessin', 'Cours de manga et d\'illustration, premier atelier offert.', 'En savoir plus', 'rocket', '2 377', '190', 'Projet'],
  ['../img/card-collector.webp', 'Kofi Studio', 'Sites web et applications pour les entrepreneurs.', 'Visiter le site', 'globe', '4 012', '305', 'Site web'],
  ['../img/card-anime.webp', 'Festival Afro Beats', 'Billets en prévente, scène ouverte aux jeunes talents.', 'En savoir plus', 'poster', '6 120', '520', 'Affiche'],
];
const galleryHtml = gallery.map((g) => `<article class="adc"><div class="adc-img"><img src="${g[0]}" alt="" loading="lazy"><span class="adc-tag">${ico(g[4], 14)} ${g[7]}</span></div>
 <div class="adc-b"><h3>${g[1]}</h3><p>${g[2]}</p><div class="adc-f"><span class="adc-s">${ico('eye', 15)} ${g[5]} <i></i> ${ico('click', 15)} ${g[6]}</span><span class="btn btn-primary adc-btn">${g[3]}</span></div></div></article>`).join('');

const adsPage = `${head('Afrolook Ads : annonce gratuitement ton site, ton application, ton projet', 'Publie ton annonce gratuite avec ton compte Google : elle est diffusée sur Afrolook, SlashAtlas et Pronoflash. Près de 10 000 personnes d\'audience.', '../')}
${header('../', 'on')}
<section class="adh"><div class="wrap adh-grid">
 <div class="adh-l">
  <span class="adh-kick">${ico('gift', 16)} Offre de lancement · 100 % gratuit</span>
  <h1>Fais connaître <em>ton site, ton app, ton projet</em>. Gratuitement.</h1>
  <p class="lead">Publie ton annonce en quelques minutes avec ton compte Google. Elle est diffusée automatiquement sur <b>Afrolook</b>, <b>SlashAtlas</b> et <b>Pronoflash</b>, devant une audience qui s'agrandit chaque jour.</p>
  <div class="cta"><a class="btn btn-primary adbig" href="../espace/index.html">${G} Publier mon annonce gratuite</a><a class="btn btn-line adbig" href="#annonces">Voir les annonces en ligne</a></div>
  <ul class="adh-pts"><li>${ico('check', 18)} 3 annonces gratuites</li><li>${ico('check', 18)} 14 jours chacune</li><li>${ico('check', 18)} Sans créer de profil</li><li>${ico('check', 18)} Validée par notre équipe</li></ul>
 </div>
 <div class="adh-r"><div class="adh-glow"></div>${phone('Ton annonce dans le fil Afrolook')}
  <div class="adh-chip c1">${ico('check', 16)} Annonce validée</div><div class="adh-chip c2">${ico('eye', 16)} 2 480 vues</div><div class="adh-chip c3">Gratuit</div></div>
</div></section>

<section class="adstats"><div class="wrap"><div class="adst-row">
 ${stat(AUDIENCE, 'personnes d\'audience', 'cumulée sur nos trois plateformes')}
 ${stat('0 FCFA', 'pour annoncer', '3 annonces gratuites de 14 jours chacune')}
 ${stat('3', 'plateformes', 'une seule annonce, diffusée partout')}
</div></div></section>

<section class="adsec"><div class="wrap"><span class="kicker">Où ton annonce est vue</span><h2 class="h2">Une annonce. Trois plateformes.</h2>
<p class="sub">Dès que ton annonce est validée, elle est diffusée automatiquement, sans que tu aies rien à faire de plus.</p>
<div class="adp3">
 <article class="adp"><div class="adp-top"><img src="../img/logo.webp" width="46" height="46" alt=""><div><h3>Afrolook</h3><small>Réseau social des créateurs africains</small></div></div><p>Ton annonce apparaît dans le fil, entre les publications des créateurs. Un bouton d'action mène vers ton site ou ton application.</p><span class="adp-tag">Dans l'application et sur le web</span></article>
 <article class="adp"><div class="adp-top"><i class="adp-logo sa">SA</i><div><h3>SlashAtlas.com</h3><small>Affiches et créations par commande</small></div></div><p>Une audience de créateurs et de clients qui commandent des affiches, des visuels et des montages.</p><span class="adp-tag">Sur le site et l'application mobile</span></article>
 <article class="adp"><div class="adp-top"><i class="adp-logo pf">PF</i><div><h3>Pronoflash</h3><small>Pronostics et actualité sportive</small></div></div><p>Une audience passionnée de sport, très active les jours de match.</p><span class="adp-tag">Sur le site et l'application</span></article>
 <article class="adp more"><div class="adp-top"><i class="adp-logo plus">+</i><div><h3>D'autres plateformes</h3><small>Le réseau s'agrandit</small></div></div><p>De nouveaux partenaires rejoignent la régie : ton annonce y sera diffusée aussi, sans rien changer de ton côté.</p><span class="adp-tag">Bientôt</span></article>
</div></div></section>

<section class="adsec soft"><div class="wrap"><span class="kicker">Que peux-tu promouvoir ?</span><h2 class="h2">Tout ce qui mérite d'être vu.</h2>
<div class="adt4">
 <article class="adt">${ico('globe', 30)}<h3>Un site web</h3><p>Boutique, blog, portfolio, service : amène des visiteurs.</p></article>
 <article class="adt">${ico('phone', 30)}<h3>Une application</h3><p>Android ou iPhone : un bouton « Télécharger » direct.</p></article>
 <article class="adt">${ico('rocket', 30)}<h3>Un projet</h3><p>Association, startup, événement, financement : fais-le connaître.</p></article>
 <article class="adt">${ico('poster', 30)}<h3>Une affiche</h3><p>Concert, formation, promotion : ton visuel en grand.</p></article>
</div></div></section>

<section class="adsec"><div class="wrap"><span class="kicker">Comment ça marche</span><h2 class="h2">Quatre étapes, quelques minutes.</h2>
<div class="ads4">
 <article class="ads"><i>1</i><h3>Connecte-toi avec Google</h3><p>Un seul clic. Pas de profil à créer, pas de mot de passe de plus.</p></article>
 <article class="ads"><i>2</i><h3>Crée ton annonce</h3><p>Choisis ce que tu promeus, ajoute ton image ou ta vidéo, ton texte et ton bouton d'action.</p></article>
 <article class="ads"><i>3</i><h3>Notre équipe la valide</h3><p>Chaque annonce est relue avant d'être publiée, pour garder une audience de confiance.</p></article>
 <article class="ads"><i>4</i><h3>Elle est diffusée partout</h3><p>Sur Afrolook, SlashAtlas et Pronoflash, avec tes vues et tes clics à suivre dans ton espace.</p></article>
</div>
<div class="cta" style="margin-top:34px"><a class="btn btn-primary adbig" href="../espace/index.html">${G} Commencer maintenant, c'est gratuit</a></div></div></section>

<section class="adsec soft"><div class="wrap"><span class="kicker">Les formats</span><h2 class="h2">Le format qui te ressemble.</h2>
<p class="sub">Chaque annonce a un bouton d'action : <b>Visiter le site</b>, <b>Télécharger</b>, <b>En savoir plus</b>, <b>WhatsApp</b> ou <b>Appeler</b>.</p>
<div class="adf3">
 <article class="adf"><div class="adf-v v1"><div class="fp"><i></i><span></span><span></span></div><div class="fb">Visiter le site</div></div>${ico('card', 22)}<h3>Carte dans le fil</h3><p>Image, texte et bouton, entre les publications.</p></article>
 <article class="adf"><div class="adf-v v2"><div class="fv">▶</div><div class="fb">Télécharger</div></div>${ico('video', 22)}<h3>Vidéo</h3><p>Une courte vidéo qui se lance dans le fil.</p></article>
 <article class="adf"><div class="adf-v v3"><div class="fc"><i></i><i></i><i></i></div><div class="fb">En savoir plus</div></div>${ico('layers', 22)}<h3>Carrousel</h3><p>Plusieurs images à faire défiler.</p></article>
 <article class="adf"><div class="adf-v v4"><div class="fa"></div></div>${ico('banner', 22)}<h3>Bannière</h3><p>Un bandeau discret en haut ou en bas des pages.</p></article>
 <article class="adf"><div class="adf-v v5"><div class="fpo"></div><div class="fb">En savoir plus</div></div>${ico('poster', 22)}<h3>Affiche</h3><p>Ton visuel en grand format, pleine largeur.</p></article>
 <article class="adf"><div class="adf-v v6"><div class="fn">${ico('bell', 18)}<span><b>Afrolook</b> Ton annonce</span></div></div>${ico('bell', 22)}<h3>Notification</h3><p>Sur sélection de notre équipe, pour les meilleures annonces.</p></article>
</div></div></section>

<section class="adsec" id="annonces"><div class="wrap"><span class="kicker">Annonces en ligne</span><h2 class="h2">Ce que les annonceurs publient déjà.</h2>
<p class="sub">Chaque annonce a été validée par notre équipe avant d'apparaître ici.</p>
<div class="adg">${galleryHtml}</div>
<p class="fine" style="margin-top:14px">Maquette : annonces d'exemple. Sur le site, ce sont les vraies annonces validées.</p></div></section>

<section class="adsec soft"><div class="wrap adtwo">
 <div><span class="kicker">Ton espace annonceur</span><h2 class="h2">Suis tes annonces en direct.</h2>
 <p class="sub">Vues, clics, statut de validation, jours restants : tout se gère dans ton espace, avec ton compte Google.</p>
 <ul class="adlist"><li>${ico('check', 18)} Crée, modifie ou arrête une annonce quand tu veux</li><li>${ico('check', 18)} Vois le nombre de vues et de clics, jour après jour</li><li>${ico('check', 18)} Vois combien de jours il reste à chaque annonce</li></ul>
 <div class="cta"><a class="btn btn-primary adbig" href="../espace/index.html">${G} Ouvrir mon espace</a></div></div>
 <div class="addash"><div class="addash-h"><b>Mes annonces <small class="adcount">2 gratuites utilisées sur 3</small></b><span class="btn btn-primary adsm">+ Nouvelle annonce</span></div>
  <div class="addash-r"><div><b>Kofi Studio</b><small>Visiter le site · 14 jours</small></div><span class="st ok">En ligne</span><span class="n">${ico('eye', 14)} 2 480</span><span class="n">${ico('click', 14)} 186</span></div>
  <div class="addash-r"><div><b>Festival Afro Beats</b><small>En savoir plus · 30 jours</small></div><span class="st wait">En validation</span><span class="n">—</span><span class="n">—</span></div>
  <div class="addash-r"><div><b>App Taxi Lomé</b><small>Télécharger · 7 jours</small></div><span class="st end">Terminée</span><span class="n">${ico('eye', 14)} 1 946</span><span class="n">${ico('click', 14)} 158</span></div>
 </div></div></section>

<section class="adsec"><div class="wrap adcontact">
 <div class="adcontact-l"><span class="kicker">Pour les éditeurs : sites, applications, projets</span><h2 class="h2">Diffuse nos annonces chez toi.</h2>
 <p class="sub">Tu as un site, une application ou un projet et tu veux afficher les annonces Afrolook à ton audience ? Parlons-en : nous t'accompagnons pour la mise en place.</p></div>
 <div class="adcontact-r"><a class="btn btn-primary adbig" href="#">${ico('mail', 20)} Nous contacter</a><small>On te répond rapidement.</small></div>
</div></section>

<section class="adsec soft"><div class="wrap"><span class="kicker">Questions fréquentes</span><h2 class="h2">Tu te demandes…</h2>
<div class="faq">
<details open><summary>C'est vraiment gratuit ?</summary><p>Oui. Pour le lancement, publier une annonce ne coûte rien : pas de carte bancaire, pas d'abonnement.</p></details>
<details><summary>Faut-il un compte Afrolook ?</summary><p>Non. Ton compte Google suffit. Tu pourras créer ton profil Afrolook plus tard, si tu veux utiliser l'application.</p></details>
<details><summary>Quelles annonces sont acceptées ?</summary><p>Les sites web, applications, projets, événements et affiches. Chaque annonce est relue par notre équipe : les contenus trompeurs, illégaux ou choquants sont refusés.</p></details>
<details><summary>Où mon annonce est-elle diffusée ?</summary><p>Automatiquement sur Afrolook, SlashAtlas et Pronoflash, dès qu'elle est validée.</p></details>
<details><summary>Combien d'annonces, et pendant combien de temps ?</summary><p>Tu peux publier 3 annonces gratuites. Chacune reste en ligne 2 semaines (14 jours).</p></details>
<details><summary>Comment suivre mes résultats ?</summary><p>Ton espace annonceur affiche les vues et les clics de chaque annonce.</p></details>
</div></div></section>

<section class="adfinal"><div class="wrap"><h2>Prêt à être vu par ${AUDIENCE} personnes ?</h2><p>Gratuit, rapide, sans profil à créer.</p>
 <div class="cta" style="justify-content:center"><a class="btn adbig adwhite" href="../espace/index.html">${G} Publier mon annonce gratuite</a></div></div></section>
${footer('../')}`;

// ───────────────────────── Bloc de l'accueil afrolookmedia.com ─────────────────────────
const homeBlock = `<section class="adhome"><div class="wrap adhome-g">
 <div class="adhome-l"><span class="adh-kick">${ico('gift', 16)} Nouveau · Afrolook Ads</span>
  <h2>Annonce <em>gratuitement</em> ton site, ton app, ton projet.</h2>
  <p>Notre régie publicitaire diffuse ton annonce sur <b>Afrolook</b>, <b>SlashAtlas</b> et <b>Pronoflash</b>, auprès de <b>${AUDIENCE} personnes</b>. Un compte Google suffit.</p>
  <div class="cta"><a class="btn btn-primary adbig" href="ads/index.html">${G} Publier une annonce gratuite</a><a class="btn adghost adbig" href="ads/index.html#annonces">Voir les annonces en ligne ${ico('arrow', 18)}</a></div></div>
 <div class="adhome-r"><div class="adhome-st">${stat(AUDIENCE, 'd\'audience', 'sur 3 plateformes')}${stat('0 FCFA', 'pour annoncer', '3 annonces gratuites de 14 jours chacune')}</div>
  <div class="adhome-pl"><span><img src="img/logo.webp" width="22" height="22" alt=""> Afrolook</span><span><i class="adp-logo sa sm">SA</i> SlashAtlas</span><span><i class="adp-logo pf sm">PF</i> Pronoflash</span></div></div>
</div></section>`;

const homePage = `${head('Afrolook : gagne de l\'argent avec tes posts, tes cartes et ta musique', 'Maquette de l\'accueil avec le bloc Afrolook Ads')}${header('', '')}
<section class="adfake"><div class="wrap"><p>… début de l'accueil actuel (rémunération, Studio Cartes, écrans de l'application) …</p></div></section>
${homeBlock}
<section class="adfake"><div class="wrap"><p>… suite de l'accueil actuel (Musique, comment gagner, questions fréquentes) …</p></div></section>
<div class="adbar"><div class="wrap">${ico('gift', 18)} <b>Annonce gratuitement sur Afrolook Ads</b><a class="btn btn-primary adsm" href="ads/index.html">Annoncer</a></div></div>
${footer('')}`;

// ───────────────────────── Espace annonceur ─────────────────────────
const spacePage = `${head('Mon espace annonceur | Afrolook Ads', 'Crée et suis tes annonces gratuites sur Afrolook, SlashAtlas et Pronoflash.', '../')}${header('../', 'on')}
<section class="adsp"><div class="wrap">
 <div class="adsp-top"><div><span class="kicker">Afrolook Ads</span><h1 class="h2" style="margin-top:6px">Mon espace annonceur</h1></div>
  <div class="adsp-user"><i class="admk-av">K</i><span><b>Kofi A.</b><small>kofi.exemple@gmail.com</small></span><a href="#">Déconnexion</a></div></div>
 <div class="adtabs"><a class="on" href="#">Créer une annonce</a><a href="#">Mes annonces <i>3</i></a></div>

 <div class="adform-g">
  <form class="adform" onsubmit="return false">
   <div class="adfs"><h3><i>1</i> Que veux-tu promouvoir ?</h3>
    <div class="adtype"><label class="on">${ico('globe', 26)}<b>Site web</b></label><label>${ico('phone', 26)}<b>Application</b></label><label>${ico('rocket', 26)}<b>Projet</b></label><label>${ico('poster', 26)}<b>Affiche</b></label></div></div>
   <div class="adfs"><h3><i>2</i> Ton annonce</h3>
    <label class="fl">Titre <small>(60 caractères)</small><input value="Kofi Studio, sites web pour entrepreneurs"></label>
    <label class="fl">Texte <small>(220 caractères)</small><textarea rows="3">Ton site web professionnel en 7 jours, paiement Mobile Money accepté.</textarea></label>
    <div class="fl"><span>Image ou vidéo</span><div class="adup"><div class="adup-i">${ico('poster', 30)}</div><div><b>Glisse ton image ici</b><small>ou clique pour choisir · JPG, PNG, MP4 · 10 Mo max</small></div></div></div></div>
   <div class="adfs"><h3><i>3</i> Bouton d'action</h3>
    <div class="adbtn"><label class="on">Visiter le site</label><label>Télécharger</label><label>En savoir plus</label><label>WhatsApp</label><label>Appeler</label></div>
    <label class="fl">Lien du bouton<input value="https://kofistudio.com"></label></div>
   <div class="adfs"><h3><i>4</i> Durée et pays</h3>
    <div class="adbtn"><label class="on">14 jours · offre gratuite</label></div><p class="adnote">Ton annonce reste en ligne 2 semaines. Tu as droit à 3 annonces gratuites.</p>
    <div class="adchips"><span class="on">Tous les pays</span><span>Togo</span><span>Côte d'Ivoire</span><span>Bénin</span><span>Sénégal</span><span>Cameroun</span><span>France</span></div></div>
   <div class="adsub"><div><b>Gratuit</b><small>2 annonces gratuites utilisées sur 3 · validation par notre équipe avant diffusion</small></div><button class="btn btn-primary adbig" type="button">Envoyer pour validation</button></div>
  </form>
  <aside class="adprev"><span class="kicker">Aperçu en direct</span>${phone('Tel que ton annonce apparaîtra')}
   <div class="adprev-n">${ico('shield', 18)}<span>Ton annonce sera diffusée sur <b>Afrolook</b>, <b>SlashAtlas</b> et <b>Pronoflash</b> après validation.</span></div></aside>
 </div>

 <div class="admine"><h2 class="h2" style="font-size:clamp(24px,3vw,34px)">Mes annonces <small class="adcount">2 gratuites utilisées sur 3</small></h2>
  <div class="addash" style="margin-top:18px">
   <div class="addash-r"><div><b>Kofi Studio</b><small>Site web · Visiter le site · 14 jours · se termine dans 9 jours</small></div><span class="st ok">En ligne</span><span class="n">${ico('eye', 14)} 2 480</span><span class="n">${ico('click', 14)} 186</span></div>
   <div class="addash-r"><div><b>Festival Afro Beats</b><small>Affiche · En savoir plus · 30 jours</small></div><span class="st wait">En validation</span><span class="n">—</span><span class="n">—</span></div>
   <div class="addash-r"><div><b>Ma boutique de bijoux</b><small>Site web · Visiter le site · 7 jours</small></div><span class="st rej">Refusée</span><span class="n adrej" colspan="2">Motif : image non conforme, ajoute une photo de ton produit.</span></div>
   <div class="addash-r"><div><b>App Taxi Lomé</b><small>Application · Télécharger · 7 jours</small></div><span class="st end">Terminée</span><span class="n">${ico('eye', 14)} 1 946</span><span class="n">${ico('click', 14)} 158</span></div>
  </div></div>
</div></section>
${footer('../')}`;

// ───────────────────────── Styles propres à la maquette ─────────────────────────
const css = `
.top .main a.adlink{color:var(--green);font-weight:800;position:relative}
.top .main a.adlink::after{content:"Gratuit";position:absolute;top:-9px;right:-30px;font-size:9px;font-weight:800;background:var(--yellow);color:#2B1A00;padding:1px 6px;border-radius:99px}
.ico{flex:none}
.adbig{padding:15px 26px;font-size:16px}.adsm{padding:8px 16px;font-size:13px}
.adghost{background:transparent;border-color:color-mix(in srgb,var(--ink) 35%,transparent);color:var(--ink)}
.adwhite{background:#fff;color:#06210F}
.adh{background:radial-gradient(900px 500px at 85% 10%,color-mix(in srgb,var(--green-bright) 22%,transparent),transparent),linear-gradient(180deg,color-mix(in srgb,var(--green-bright) 8%,transparent),transparent);padding-block:56px 40px;overflow:hidden}
.adh-grid{display:grid;grid-template-columns:1.1fr .9fr;gap:40px;align-items:center}
.adh-kick{display:inline-flex;align-items:center;gap:8px;font-size:13px;font-weight:800;letter-spacing:.04em;text-transform:uppercase;color:var(--on-green);background:var(--yellow);padding:7px 14px;border-radius:99px}
.adh h1{font-size:clamp(38px,5.4vw,68px);font-weight:800;margin-top:20px}
.adh h1 em{font-style:normal;color:var(--green)}
.adh .lead{font-size:19px;color:var(--muted);max-width:56ch;margin-top:20px}
.adh-pts{list-style:none;display:flex;flex-wrap:wrap;gap:8px 22px;margin:26px 0 0;padding:0;font-weight:700;font-size:14.5px}
.adh-pts li{display:flex;align-items:center;gap:6px}.adh-pts .ico{color:var(--green)}
.adh-r{position:relative;display:grid;place-items:center;min-height:560px}
.adh-glow{position:absolute;inset:8% 6%;border-radius:50%;background:radial-gradient(circle,color-mix(in srgb,var(--green-bright) 35%,transparent),transparent 68%);filter:blur(10px)}
.adh-r .mkw{position:relative;z-index:2}
.adh-chip{position:absolute;z-index:3;display:inline-flex;align-items:center;gap:7px;background:var(--surface);border:1px solid var(--line);border-radius:99px;padding:9px 16px;font-weight:800;font-size:14px;box-shadow:var(--shadow)}
.adh-chip.c1{top:14%;left:0;color:var(--green)}.adh-chip.c2{bottom:20%;right:-2%}.adh-chip.c3{top:40%;right:-4%;background:var(--yellow);color:#2B1A00;border-color:transparent}
.admk{margin:10px 10px 0;padding:11px;border-radius:16px;background:var(--card);border:1px solid var(--line)}
.admk-top{display:flex;gap:9px;align-items:center}.admk-top b{display:block;font-size:13px}.admk-top small{display:block;color:var(--mute);font-size:10.5px}
.admk-av{width:34px;height:34px;border-radius:50%;background:var(--g);color:#0E0E0E;display:grid;place-items:center;font-style:normal;font-weight:900;font-size:15px}.admk-av.g{background:#FF9248}
.admk-txt{margin:8px 0;font-size:12.5px;line-height:1.4}
.admk-img img{border-radius:12px;aspect-ratio:16/11;object-fit:cover;width:100%}
.admk-cta{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:8px;font-size:11px;color:var(--mute)}
.admk-cta b{background:var(--g);color:#0E0E0E;padding:7px 14px;border-radius:99px;font-size:12px;font-weight:900}
.admk-meta{display:flex;gap:14px;margin-top:8px;color:var(--mute);font-size:11px}.admk-meta span{display:flex;align-items:center;gap:4px}
.admk2{margin-top:8px}
.adstats{background:var(--night);color:var(--night-ink);padding-block:34px;border-block:1px solid var(--night-line)}
.adst-row{display:grid;grid-template-columns:repeat(3,1fr);gap:20px}
.adst{text-align:center;padding:10px}.adst b{display:block;white-space:nowrap;font:800 clamp(30px,4.2vw,52px)/1.05 var(--display);background:linear-gradient(90deg,var(--green-bright),var(--yellow));-webkit-background-clip:text;background-clip:text;color:transparent}
.adst span{display:block;font-weight:800;font-size:17px;margin-top:6px}.adst small{display:block;color:var(--night-muted);font-size:13.5px;margin-top:2px}
.adsec{padding-block:72px}.adsec.soft{background:var(--soft)}
.adp3{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:18px;margin-top:40px}
.adp.more{border-style:dashed;background:transparent}.adp-logo.plus{background:var(--soft);color:var(--green);font-size:26px}
.adnote{margin-top:12px;color:var(--muted);font-size:14px}.adcount{font-size:12.5px;font-weight:700;color:var(--green);background:color-mix(in srgb,var(--green-bright) 14%,transparent);padding:3px 10px;border-radius:99px;margin-left:8px;vertical-align:middle}
.adp{background:var(--surface);border:1px solid var(--line);border-radius:22px;padding:24px;display:flex;flex-direction:column;gap:14px}
.adp-top{display:flex;gap:14px;align-items:center}.adp-top h3{font-size:22px}.adp-top small{color:var(--muted);font-size:13px}
.adp p{color:var(--muted);font-size:15px}.adp-tag{margin-top:auto;align-self:flex-start;font-size:12px;font-weight:800;color:var(--green);background:color-mix(in srgb,var(--green-bright) 13%,transparent);padding:5px 12px;border-radius:99px}
.adp-logo{width:46px;height:46px;border-radius:14px;display:grid;place-items:center;font:800 17px var(--display);font-style:normal;color:#fff}
.adp-logo.sa{background:linear-gradient(135deg,#7b2ff7,#f107a3)}.adp-logo.pf{background:linear-gradient(135deg,#ff9248,#e5484d)}.adp-logo.sm{width:22px;height:22px;border-radius:7px;font-size:10px}
.adt4{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-top:38px}
.adt{background:var(--surface);border:1px solid var(--line);border-radius:20px;padding:24px}.adt .ico{color:var(--green)}.adt h3{font-size:20px;margin:14px 0 6px}.adt p{color:var(--muted);font-size:14.5px}
.ads4{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-top:38px}
.ads{border-top:3px solid var(--green-bright);padding-top:18px}.ads i{display:grid;place-items:center;width:38px;height:38px;border-radius:50%;background:var(--green-bright);color:var(--on-green);font:800 18px var(--display);font-style:normal}
.ads h3{font-size:19px;margin:14px 0 6px}.ads p{color:var(--muted);font-size:14.5px}
.adf3{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-top:38px}
.adf{background:var(--surface);border:1px solid var(--line);border-radius:20px;padding:18px;display:flex;flex-direction:column;gap:6px}.adf .ico{color:var(--green);margin-top:8px}.adf h3{font-size:18px}.adf p{color:var(--muted);font-size:14px}
.adf-v{height:150px;border-radius:14px;background:var(--bg);border:1px dashed var(--line);display:grid;place-items:center;padding:12px;position:relative}
.adf-v .fb{background:var(--green-bright);color:var(--on-green);font-weight:800;font-size:12px;padding:6px 14px;border-radius:99px}
.v1 .fp{width:100%;display:grid;gap:6px}.v1 .fp i{height:54px;border-radius:10px;background:linear-gradient(135deg,#5b9cfa,#5bf0e0)}.v1 .fp span{height:8px;border-radius:4px;background:var(--line);width:70%}.v1 .fp span+span{width:45%}
.v2 .fv{width:100%;height:90px;border-radius:12px;background:linear-gradient(135deg,#1b2a6b,#7b2ff7);display:grid;place-items:center;color:#fff;font-size:26px}.adf-v.v2,.adf-v.v3,.adf-v.v5,.adf-v.v1{gap:8px;align-content:center}
.v3 .fc{display:flex;gap:6px;width:100%}.v3 .fc i{flex:1;height:84px;border-radius:10px;background:linear-gradient(135deg,#f5c542,#ff6b6f)}.v3 .fc i:nth-child(2){background:linear-gradient(135deg,#2ecc71,#0d3b1c)}.v3 .fc i:nth-child(3){background:linear-gradient(135deg,#5b9cfa,#1b2a6b);opacity:.6}
.v4 .fa{width:100%;height:42px;border-radius:10px;background:linear-gradient(90deg,var(--green-bright),var(--yellow))}
.v5 .fpo{width:100%;height:92px;border-radius:12px;background:conic-gradient(from 200deg at 30% 70%,#7b2ff7,#2a0a5e,#f107a3,#7b2ff7)}
.v6 .fn{display:flex;gap:10px;align-items:center;background:var(--surface);border:1px solid var(--line);border-radius:14px;padding:12px 14px;box-shadow:var(--shadow);font-size:12.5px}.v6 .fn .ico{color:var(--green)}
.adg{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;margin-top:38px}
.adc{background:var(--surface);border:1px solid var(--line);border-radius:20px;overflow:hidden;display:flex;flex-direction:column}
.adc-img{position:relative}.adc-img img{aspect-ratio:16/10;object-fit:cover;width:100%}
.adc-tag{position:absolute;left:12px;top:12px;display:inline-flex;gap:6px;align-items:center;background:rgba(0,0,0,.62);color:#fff;font-size:12px;font-weight:800;padding:5px 11px;border-radius:99px}
.adc-b{padding:16px;display:flex;flex-direction:column;gap:6px;flex:1}.adc-b h3{font-size:18px}.adc-b p{color:var(--muted);font-size:14px;flex:1}
.adc-f{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:10px}.adc-s{display:flex;align-items:center;gap:5px;color:var(--muted);font-size:12.5px;font-weight:700}.adc-s i{width:8px}
.adc-btn{padding:8px 16px;font-size:13px;pointer-events:none}
.adtwo{display:grid;grid-template-columns:1fr 1fr;gap:44px;align-items:center}
.adlist{list-style:none;padding:0;margin:22px 0 0;display:grid;gap:10px;font-weight:600}.adlist li{display:flex;gap:10px;align-items:flex-start}.adlist .ico{color:var(--green);margin-top:2px}
.addash{background:var(--surface);border:1px solid var(--line);border-radius:22px;padding:8px 18px;box-shadow:var(--shadow)}
.addash-h{display:flex;align-items:center;justify-content:space-between;padding:12px 0;border-bottom:1px solid var(--line)}
.addash-r{display:grid;grid-template-columns:1fr auto auto auto;gap:14px;align-items:center;padding:14px 0;border-bottom:1px solid var(--line)}.addash-r:last-child{border-bottom:0}
.addash-r b{display:block}.addash-r small{color:var(--muted);font-size:12.5px}.addash-r .n{display:inline-flex;gap:5px;align-items:center;color:var(--muted);font-weight:700;font-size:13px}
.st{font-size:12px;font-weight:800;padding:5px 12px;border-radius:99px;white-space:nowrap}.st.ok{background:color-mix(in srgb,var(--green-bright) 18%,transparent);color:var(--green)}.st.wait{background:color-mix(in srgb,var(--yellow) 28%,transparent);color:#8a6a00}.st.end{background:var(--soft);color:var(--muted)}.st.rej{background:color-mix(in srgb,var(--red) 16%,transparent);color:var(--red)}
.adrej{grid-column:3/5;font-size:12px;line-height:1.3}
.adcontact{display:grid;grid-template-columns:1.4fr .6fr;gap:30px;align-items:center;background:var(--surface);border:1px solid var(--line);border-radius:26px;padding:40px}
.adcontact-r{display:grid;gap:10px;justify-items:start}.adcontact-r small{color:var(--muted)}
.adfinal{background:linear-gradient(135deg,#0f7a3a,#14a04e 55%,#2ecc71);color:#fff;text-align:center;padding-block:64px}.adfinal h2{font-size:clamp(30px,4.6vw,52px);font-weight:800}.adfinal p{margin-top:10px;font-size:18px;opacity:.9}
.adhome{background:linear-gradient(135deg,var(--night),#0f2a18);color:var(--night-ink);padding-block:64px;position:relative;overflow:hidden}
.adhome::before{content:"";position:absolute;right:-8%;top:-30%;width:520px;height:520px;border-radius:50%;background:radial-gradient(circle,rgba(46,204,113,.3),transparent 65%)}
.adhome-g{display:grid;grid-template-columns:1.2fr .8fr;gap:40px;align-items:center;position:relative}
.adhome h2{font-size:clamp(32px,4.4vw,56px);font-weight:800;margin-top:18px}.adhome h2 em{font-style:normal;color:var(--yellow)}
.adhome-l p{font-size:18px;color:var(--night-muted);margin-top:16px;max-width:54ch}.adhome-l p b{color:var(--night-ink)}
.adhome .adghost{color:#fff;border-color:rgba(255,255,255,.4)}
.adhome-r{display:grid;gap:16px}.adhome-st{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.adhome-st .adst{background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.12);border-radius:20px;padding:20px 12px}
.adhome-pl{display:flex;flex-wrap:wrap;gap:10px}.adhome-pl span{display:inline-flex;align-items:center;gap:8px;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.14);padding:9px 15px;border-radius:99px;font-weight:700;font-size:14px}
.adfake{padding-block:56px;text-align:center;color:var(--muted);background:var(--bg)}
.adbar{position:sticky;bottom:0;z-index:20;background:var(--green-bright);color:var(--on-green);padding-block:10px}.adbar .wrap{display:flex;align-items:center;justify-content:center;gap:12px;flex-wrap:wrap;font-size:15px}.adbar .btn{background:var(--on-green);color:#fff}
.adsp{padding-block:46px 70px}.adsp-top{display:flex;justify-content:space-between;align-items:end;gap:20px;flex-wrap:wrap}
.adsp-user{display:flex;gap:12px;align-items:center}.adsp-user small{display:block;color:var(--muted);font-size:12.5px}.adsp-user a{color:var(--muted);font-size:13px;margin-left:8px}
.adtabs{display:flex;gap:8px;margin:26px 0 24px;border-bottom:1px solid var(--line)}.adtabs a{padding:12px 18px;font-weight:800;text-decoration:none;color:var(--muted);border-bottom:3px solid transparent;margin-bottom:-1px}.adtabs a.on{color:var(--green);border-color:var(--green)}.adtabs i{background:var(--green-bright);color:var(--on-green);border-radius:99px;font-size:11px;padding:1px 8px;font-style:normal;margin-left:6px}
.adform-g{display:grid;grid-template-columns:1fr 340px;gap:28px;align-items:start}
.adform{display:grid;gap:18px}
.adfs{background:var(--surface);border:1px solid var(--line);border-radius:20px;padding:22px}.adfs h3{font-size:19px;display:flex;align-items:center;gap:10px;margin-bottom:16px}.adfs h3 i{display:grid;place-items:center;width:28px;height:28px;border-radius:50%;background:var(--green-bright);color:var(--on-green);font-size:14px;font-style:normal}
.adtype{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}.adtype label,.adbtn label{display:flex;flex-direction:column;align-items:center;gap:8px;padding:16px 8px;border:2px solid var(--line);border-radius:16px;font-size:14px;cursor:pointer;text-align:center}
.adtype label.on,.adbtn label.on{border-color:var(--green-bright);background:color-mix(in srgb,var(--green-bright) 10%,transparent)}.adtype .ico{color:var(--green)}
.adbtn{display:flex;gap:10px;flex-wrap:wrap}.adbtn label{padding:11px 20px;font-weight:700;flex-direction:row}
.fl{display:grid;gap:6px;margin-top:12px;font-weight:700;font-size:14px}.fl small{color:var(--muted);font-weight:500}
.fl input,.fl textarea{font:inherit;font-weight:500;padding:12px 14px;border-radius:12px;border:1px solid var(--line);background:var(--bg);color:var(--ink)}
.adup{display:flex;gap:14px;align-items:center;border:2px dashed var(--line);border-radius:16px;padding:18px;background:var(--bg)}.adup-i{width:56px;height:56px;border-radius:14px;background:var(--soft);display:grid;place-items:center;color:var(--green)}.adup small{display:block;color:var(--muted);font-weight:500}
.adchips{display:flex;flex-wrap:wrap;gap:8px;margin-top:14px}.adchips span{padding:8px 15px;border-radius:99px;border:1px solid var(--line);font-weight:700;font-size:13.5px}.adchips span.on{background:var(--green-bright);color:var(--on-green);border-color:transparent}
.adsub{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap;background:var(--surface);border:2px solid var(--green-bright);border-radius:20px;padding:18px 22px}.adsub b{font-size:22px;color:var(--green)}.adsub small{display:block;color:var(--muted)}
.adprev{position:sticky;top:96px;display:grid;gap:12px;justify-items:center}.adprev-n{display:flex;gap:10px;align-items:flex-start;background:var(--soft);border-radius:14px;padding:12px 14px;font-size:13px;max-width:300px}.adprev-n .ico{color:var(--green);flex:none}
.adprev .mkw{margin-top:4px}
.admine{margin-top:56px}
@media (prefers-color-scheme:dark){.st.wait{color:var(--yellow)}}
@media (max-width:980px){.adh-grid,.adtwo,.adhome-g,.adform-g,.adcontact{grid-template-columns:1fr}.adp3,.adf3,.adg{grid-template-columns:1fr 1fr}.adt4,.ads4{grid-template-columns:1fr 1fr}.adprev{position:static}.adh-r{min-height:auto;padding-block:20px}.adh-chip.c1{left:4%}.adh-chip.c2,.adh-chip.c3{right:4%}}
@media (max-width:620px){.adp3,.adf3,.adg,.adt4,.ads4,.adst-row{grid-template-columns:1fr}.adtype{grid-template-columns:1fr 1fr}.addash-r{grid-template-columns:1fr auto}.addash-r .n{display:none}.adrej{display:block!important;grid-column:1/3}.adhome-st{grid-template-columns:1fr 1fr}.adsec{padding-block:48px}.adbig{width:100%}.adcontact{padding:24px}}
`;

fs.mkdirSync(path.join(OUT, 'ads'), { recursive: true });
fs.mkdirSync(path.join(OUT, 'espace'), { recursive: true });
fs.writeFileSync(path.join(OUT, 'css/ads.css'), css);
fs.writeFileSync(path.join(OUT, 'index.html'), homePage);
fs.writeFileSync(path.join(OUT, 'ads/index.html'), adsPage);
fs.writeFileSync(path.join(OUT, 'espace/index.html'), spacePage);
console.log('maquette écrite dans', OUT);
