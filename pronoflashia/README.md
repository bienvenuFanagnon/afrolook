# PronoFlash IA

Site gratuit de pronostics football (autres sports ensuite), sans inscription, monétisé par des publicités hors Google AdSense (Adsterra, Monetag) et des encarts Afrolook. Cahier des charges : `CAHIER_DES_CHARGES.md`. Marchés de paris et méthode : `MARCHES_DE_PARIS.md`.

## Ce qui est fait

| Étape du plan | État |
|---|---|
| 1. Structure, Firestore, règles, hébergement | Fait, non déployé (il manque le projet Firebase) |
| 2. API-Football + `syncFixtures` | Fait, testé avec une fausse API (clé à fournir) |
| 3. Modèle de calcul + `buildPredictions` + texte IA | Fait. Workers AI testé en réel (voir plus bas) |
| 4. Site public (accueil, jour, championnat, fiche, analyse complète, coupon) | Fait, vérifié sur téléphone et ordinateur |
| 5. `syncResults` + page Bilan | Fait |
| 6. Admin, mesure des visites, `weeklyReport`, `aiHealthCheck` | Fait |
| 7. Publicités, Afrolook, ads.txt, consentement, pages légales | Fait. Textes légaux à compléter et à faire relire |
| 8. Plus de championnats, anglais `/en/` | Championnats : à ajouter depuis l'admin. Anglais : pas commencé |
| 9. Domaine, Search Console, demandes Adsterra / Monetag | À faire par le propriétaire |

Pas encore faits : version anglaise, vote anonyme 1/N/2, paris sur les joueurs (compositions), page « compositions et absences ».

## Voir le site sans rien installer de plus

```bash
cd pronoflashia/functions && npm install        # une seule fois
node ../scripts/dev.js                          # http://localhost:5173
# Administration locale : http://localhost:5173/admin?dev=1
```

Les données d'exemple sont produites par la vraie chaîne (fausse API déterministe → calcul → texte → résultats → bilan). Aucune clé ni aucun compte n'est nécessaire. Pour voir les emplacements publicitaires : `PF_ADS_DEMO=chemin/vers/ads.json node ../scripts/dev.js`.

## Tests

```bash
cd pronoflashia/functions && npm test           # 75 tests : calcul, IA, API, tâches, mesure, admin, rendu des pages
```

## Mise en ligne (à faire par le propriétaire, dans cet ordre)

1. **Créer le projet Firebase** (plan Blaze), séparé d'Afrolook et de SlashAtlas. Activer Firestore (région `europe-west1`) et Authentication (fournisseur Google).
2. Mettre l'identifiant du projet dans `.firebaserc`.
3. **Clés** : dans `functions/.env` (modèle `functions/.env.example`, jamais dans le dépôt) : jeton football-data.org, clé API-Football (facultative au départ), jeton et identifiant Cloudflare, clé Gemini (facultative), `STATS_SALT` (longue chaîne aléatoire) et `ADMIN_EMAILS` (adresse Google du premier administrateur).
4. Renseigner `site/admin/firebase-config.js` (configuration web du projet : Paramètres du projet → Application web).
5. Déployer : `node scripts/build-site.js && firebase deploy --only firestore,functions,hosting`.
6. Dans la console Firestore : stratégie **TTL** sur le champ `expireAt` de la collection `ai_status_log`.
7. Ouvrir `/admin` : ajouter les championnats (identifiant API-Football, ex. 61 Ligue 1, 39 Premier League, 12 Ligue des champions CAF), remplir les mentions légales, puis relancer `syncFixtures` depuis « IA et tâches ».
8. Brancher le domaine `pronoflashia.com` dans Firebase Hosting, déclarer le site dans Search Console.
9. Quand le site a 2 à 3 semaines de contenu : demander Adsterra et Monetag, coller les codes et les lignes ads.txt dans l'admin, puis activer l'interrupteur général des publicités.

## Premier déploiement depuis Google Cloud Shell (sans rien installer)

Projet Firebase : `pronoflashia` (forfait Blaze). Les clés sont lues dans `functions/.env` (ignoré par git, jamais commité ; modèle : `functions/.env.example`). Attention : ces valeurs deviennent des variables d'environnement des fonctions, visibles par les membres du projet dans la console Google Cloud. Les renouveler régulièrement et ne jamais les mettre dans le dépôt.

Dans Cloud Shell (icône `>_` de console.cloud.google.com, connecté au compte propriétaire du projet) :

```bash
git clone https://github.com/bienvenufanagnon/afrolook.git && cd afrolook && git checkout refonte_claude && cd pronoflashia
(cd functions && npm ci)
firebase use pronoflashia
cp functions/.env.example functions/.env
nano functions/.env        # remplir les valeurs ; STATS_SALT : une longue chaîne aléatoire (openssl rand -hex 24)
node scripts/build-site.js && firebase deploy --only firestore,functions,hosting
```

Une clé laissée vide (Gemini, API-Football) désactive simplement la source concernée. Adresse provisoire : `https://pronoflashia.web.app`. Tant que le nom de domaine n'est pas acheté, mettre `indexable` à faux dans l'admin (Réglages) pour que Google n'indexe pas l'adresse provisoire.

## Référencement (indexation) automatique

- **Adresse provisoire** : `pronoflashia.web.app` (réglages `origine` et `domaine` de l'admin). Le sitemap bilingue (`/sitemap.xml`, avec hreflang), `robots.txt`, les adresses canoniques et les données structurées pointent vers elle. À l'achat de `pronoflashia.com` : brancher le domaine dans Firebase Hosting, changer `origine` et `domaine` dans Réglages, rediriger l'ancienne adresse (301) et utiliser « Changement d'adresse » dans Search Console.
- **`robots.txt`** : fichier fixe `site/robots.txt` (Firebase Hosting ne transmet pas cette adresse à la fonction). **À modifier à l'achat du domaine** : la ligne `Sitemap:` doit pointer vers la nouvelle adresse.
- **Revenus Adsterra dans l'admin** : onglet Publicités, carte « Revenus Adsterra » (14 derniers jours, par jour et par emplacement). Nécessite `ADSTERRA_API_TOKEN` dans `functions/.env` (jeton créé dans Adsterra → Paramètres → API, lecture seule des chiffres ; il ne donne pas les codes publicitaires, à copier à la main avec « GET CODE »).
- **Bing, Yandex, Seznam, Naver (IndexNow)** : automatique. Chaque nouvelle page de match et d'analyse (français et anglais) est signalée une seule fois à la publication, par la tâche `buildPredictions`. La clé est générée toute seule et publiée à `/{clé}.txt`. Compte-rendu dans l'onglet « IA et tâches » (infos `indexNow`).
- **Google** n'accepte pas IndexNow : il découvre les pages par le sitemap. À faire une fois dans Search Console : ajouter la propriété « Préfixe d'URL » `https://pronoflashia.web.app`, choisir la vérification par **balise HTML**, coller la balise (ou seulement la valeur de `content`) dans Réglages → « Code de vérification Google Search Console », enregistrer, cliquer sur « Valider », puis ouvrir « Sitemaps » et ajouter `sitemap.xml`. Ensuite, Google revient tout seul ; le `lastmod` du sitemap lui indique les pages mises à jour.

## Application installable, actualités et notifications (tout est automatique)

- **PWA** : manifeste, icônes, `site/sw.js` (page hors connexion, aucune page de pronostics en cache). Bannière d'installation sur téléphone (Android : bouton Installer ; iPhone Safari : consigne Partager), mémorisée 14 jours.
- **Actualités** (`syncNews`, toutes les 2 h) : flux RSS de sites de football (`functions/src/news/sources.js`), on ne garde que titre, site, date, lien et miniature. Bande compacte insérée entre les pronostics de l'accueil et liste sur la fiche d'un match. Sources, images et interrupteur dans l'admin (Réglages). Les sources marquées `actif: false` ont refusé nos robots lors des essais : à tester depuis le serveur. Vérifier les conditions d'utilisation de chaque flux avant d'en ajouter.
- **Lecture de l'actualité par l'IA** (`news/facts.js`, dans `syncNews`) : pour chaque nouvel article qui parle d'une équipe suivie ET contient un mot-clé précis (blessure, suspension, retour de joueur, changement d'entraîneur), l'IA (Workers AI puis Gemini) en tire un fait structuré. Garde-fous : aucun appel sans mot-clé ; JSON strict ; équipe prise dans la liste ; type appuyé par les mots du texte ; nom de joueur présent tel quel dans le texte (sinon ignoré) ; formules rassurantes (« sans gravité ») jamais présentées comme une absence ; « à confirmer » dès que le texte hésite ; repli par règles si l'IA est indisponible ; 6 appels au plus par passage. Le fait s'affiche sur la fiche du match **avec sa source**, mais **ne modifie aucune probabilité** : aucun historique d'actualité ne permet de mesurer son effet. Le bilan (page Bilan, « Nos pronostics selon les signaux affichés ») compare, avec nos propres résultats, la réussite des pronostics avec infos récentes ou données limitées et celle des autres ; on décidera d'un éventuel ajustement quand l'échantillon sera assez grand.
- **Bilan sur l'accueil** : mis en avant seulement à partir de 30 pronostics terminés et 55 % de réussite (constantes `BILAN_MIN_N` et `BILAN_MIN_RATE` dans `pages.js`, et le même seuil dans `sideColumn`). La page Bilan reste toujours complète.
- **Notifications** (`sendPush`, toutes les 15 min) : coupons du jour (~07:30 UTC), pronostic le plus confiant (~12:30), coupon du soir (~16:30), chacun une fois par jour ; alerte ~1 h avant les matchs des équipes suivies (2 par jour et par abonné au plus). Envoi Web Push (bibliothèque `web-push`) : les clés VAPID se créent toutes seules au premier usage (`push_keys/vapid`, inaccessible au navigateur). Interrupteur et historique des envois dans l'admin. Sur iPhone, les notifications ne marchent qu'avec l'app installée (iOS 16.4 et plus).

## Notifications d'actualité, images et annonces

- **Actus qui font cliquer, à heure variable** (`functions/src/push/buzz.js`, `jobs/sendPush.js`) : toutes les 15 minutes, `sendPush` note les articles lus par `syncNews` (stars et valeurs montantes, pépites, enfants de légendes, classicos et derbys, mercato, records, vie des vedettes) et envoie au plus **une** actu toutes les 3 heures. Plafonds par abonné : 2 actus et 4 notifications par jour (réglable), jamais la nuit (heure locale de l'abonné). Un classico ou un duel de grands clubs du jour est annoncé avec notre pronostic. Une même histoire reprise par plusieurs sites ne part qu'une fois par jour.
- **Garde-fous** : sujets sensibles écartés d'office (décès, maladie, drames, violences, justice, mineurs) ; aucune polémique ni vie privée quand un mineur est cité ; le texte accrocheur de l'IA est vérifié (noms, chiffres, promesses, titre non recopié, source citée) sinon texte modèle ; la notification ouvre NOTRE page de l'actu (extrait, source, lien).
- **Images** : chaque notification porte une carte 1200 × 600 dessinée par nous (`push/card.js`, resvg + police Inter embarquée) : coupons, pronostic, match, actu. Servie par `/api/img/{id}.png` (cartes dans `push_cards`, gardées 20 jours). Aucune photo de presse ni logo de club. L'iPhone n'affiche pas les grandes images.
- **Rappel pour les visiteurs qui reviennent** (`site/js/pf.js`, fonction `welcome`) : fenêtre avec trois exemples de notifications, après 12 s et un geste, à partir de la 2e visite, si le visiteur n'a ni activé les notifications ni installé le site ; refus : 7 jours, 3 refus au plus.
- **Annonces à la main** (admin > Réglages) : titre, texte, page à ouvrir, image (carte automatique ou image envoyée, réduite à 1200 px), version anglaise facultative, aperçu, essai sur son propre appareil, envoi à tous avec confirmation (un double clic n'envoie qu'une fois).
- **Contrôle sur le vrai Firestore** : `firebase emulators:exec --only firestore --project demo-pf "node scripts/firestore-push-check.js"`.

## Page « Mes notifications », partage et inscription e-mail

- **Boîte sans compte** (`functions/src/push/inbox.js`, page `/notifications` et `/en/notifications`) : chaque notification envoyée est gardée (50 au plus, 30 jours) pour l'abonnement du navigateur, retrouvée avec son adresse d'envoi. Lien de la notification = lien + `n=…` : l'ouvrir la marque comme lue. La cloche affiche la pastille des non lues (« 9+ » au-delà de 9) et ouvre la page ; liste par 10 avec « Voir 10 de plus », « Tout marquer comme lu », désactivation des notifications depuis la page. Limite : la boîte est propre au navigateur (données vidées ou nouveau téléphone = liste vide). Les messages de test n'y entrent pas.
- **Remerciement et partage** : encadré (WhatsApp, partage natif du téléphone, copie du lien) sur la page notifications et la page coupon. Le texte remercie les visites et les pubs regardées par choix et reste vrai : plus d'audience = plus de moyens pour suivre des championnats et améliorer l'IA ; aucune promesse « plus de coupons si tu partages ».
- **Inscription e-mail aux coupons VIP gratuits** (`functions/src/mail/subs.js`, `/api/mail/subscribe`) : consentement explicite (case à cocher, texte et version gardés), champ piège anti-robots, 6 demandes par minute et par IP, même réponse pour une adresse nouvelle ou déjà connue. **Aucun e-mail n'est envoyé pour l'instant** : il faut un domaine et un service d'envoi. À prévoir pour l'envoi : message de confirmation d'abord (double accord, champ `confirme`), lien de désinscription dans chaque e-mail (`/api/mail/unsubscribe` avec le jeton de l'inscrit), page de désinscription. Admin > Réglages : compteurs et export CSV. Page confidentialité mise à jour.

## Annonceurs et sponsors directs

- **Page « Annoncer sur PronoFlash IA »** (`/annoncer`, `/en/advertise`) : qui nous lit, formats, règles (étiquette « Sponsorisé », pas de paris, de contenu adulte ni de promesse de gains), marche à suivre ; information « Une marque, une entreprise, un commerce ? » sur l'accueil, À propos et en pied de page. Coordonnées : WhatsApp des annonceurs (numéro par défaut dans `functions/src/render/config.js`, modifiable dans l'admin, champ « WhatsApp des annonceurs »), e-mail pré-rempli, canal WhatsApp. Un canal WhatsApp ne permet pas d'écrire : d'où le numéro séparé.
- **Sponsors directs** (admin > Sponsors, `functions/src/sponsors/store.js`) : encart « Coupon du jour offert par … » (emplacement coupon : accueil et page coupon), accueil, pages actus. Formulaire : nom, phrase (90 caractères), lien https, logo envoyé (réduit à 256 px, 200 Ko au plus, collection `sponsor_media`), dates facultatives, activation. Toujours étiqueté « Sponsorisé », lien `rel="sponsored nofollow noopener"`. Un sponsor à la fois par emplacement, à tour de rôle toutes les 15 minutes.
- **Mesure** : affichages (encart vu à moitié, une fois par page) et clics, par sponsor et par jour (`sponsor_stats`) ; admin : 7 jours et 90 jours, taux de clic, rapport CSV jour par jour à remettre au sponsor. Les robots et les visiteurs « Ne pas suivre » ne sont pas comptés.

## Bilan des coupons et cote équivalente

- **Page `/bilan-coupons`** (`/en/slips-track-record`) : tous les coupons archivés (gagnés, perdus, en cours), par jour (10 jours par page), résumé (réglés, gagnés, perdus, taux, probabilité annoncée moyenne, plus grosse cote gagnée, série en cours, 10 derniers), détail par niveau, ce que l'IA apprend de ses coupons, filtre Gagnés / Perdus / En cours. Reliée depuis la page Bilan (onglets Pronostics | Coupons, encadré, bouton sous l'historique), dans le plan du site.
- **Cote équivalente** = 1 / probabilité que tout passe, sans marge (`fairOdds` dans `functions/src/shared/coupon.js`). Affichée sur chaque coupon archivé, sur les coupons proposés (accueil, page coupon) et dans le calculateur de coupon. Toujours présentée comme une estimation, jamais comme une cote de bookmaker (les cotes réelles sont plus basses) ; les textes « n'affiche aucune cote » sont devenus « n'affiche aucune cote de bookmaker ».

## Moteur de calcul : notes d'équipes (« la mémoire » de l'IA sur chaque club)

- `functions/src/engine/ratings.js` : pour chaque championnat, une note d'attaque et une note de faiblesse défensive par équipe, estimées sur tous les matchs connus (**saison précédente comprise**, récupérée une seule fois par `syncFixtures` et gardée dans `league_history/{id}`), en comptant davantage les matchs récents (demi-vie 240 jours) et en tenant compte du niveau des adversaires. Notes recalculées chaque jour dans `league_ratings/{id}`, avec l'évolution sur 60 jours.
- **Jugées avant d'être utilisées** (walk-forward : à chaque match, seul le passé est connu) : le résultat est inscrit sur le championnat (`leagues/{id}.ratings`) et visible dans l'admin (Réglages). Si, sur au moins 100 matchs, les notes expliquent moins bien les buts que l'ancien calcul, l'ancien calcul est conservé automatiquement.
- **Mesure sur de vrais matchs** (`node scripts/backtest.js [saison]`, données openfootball, domaine public) : sur 1 510 matchs de 5 grands championnats (2023-24), la vraisemblance des buts passe de −2,9643 à −2,9254 par match et le score de probabilité RPS de 0,2014 à 0,1962 ; sur 2022-23 (saison non utilisée pour régler les paramètres), gain de +0,054 par match. Une correction « résiduelle » par équipe a aussi été essayée et **rejetée** (elle dégradait le résultat de 0,02 par match).
- La fiche d'analyse affiche « Ce que l'IA sait de ces équipes » (attaque, défense, évolution sur 60 jours). Les textes de l'IA peuvent citer ces notes quand l'écart à la moyenne est net.
- Avec l'offre gratuite de football-data.org, la saison précédente peut être refusée : les notes se calculent alors sur la saison en cours seulement (gain plus faible, mesuré à +0,02 par match), avec un nouvel essai chaque semaine.

## Matchs à « données limitées » (et ce qu'on ne sait pas prédire)

Test sur 3 090 matchs réels : le calcul est bien calibré (52,1 % de réussite du pronostic 1N2 pour 51,8 % annoncés) et **aucun signal statistique n'annonce les surprises** (désaccord entre modèles, probabilité de nul, niveau des équipes : rien de significatif). Le site n'affiche donc pas d'« indice de surprise » inventé. Deux limites réelles sont signalées : début de saison (moins de 8 matchs joués par une équipe ; signal faible, retenu par prudence) et équipe inconnue du moteur de notes. Ces matchs portent la pastille « Données limitées » et sont écartés des coupons du jour archivés, des coupons proposés, des « 3 pronostics les plus confiants » et des notifications. Les probabilités annoncées au-dessus de 70 % sont un peu trop optimistes (−4 points mesurés) : la calibration par le bilan réel (`learn.js`) les corrige au fil du temps. Détail : `node scripts/backtest.js 2023-24 --calibration`.

## « Le point foot » : l'article du jour rédigé par l'IA

Chaque soir (`buildRecaps`, 20:10 UTC), l'IA rédige un article de football en français et en anglais (`/actus`, `/en/news`) : il alimente des pages à pubs, le référencement (sitemap, IndexNow, balisage NewsArticle) et la carte « Le point foot » de l'accueil.
- **Matière** : NOS données (résultats des dernières 30 h, nos pronostics réussis ou ratés, matchs à venir avec notre pronostic, bilan) et les infos de presse **réduites aux faits** (absence, suspension, retour, entraîneur) avec nom du site et lien. Les titres de presse servent de contexte à reformuler ; **aucun texte d'article n'est copié** (les flux ne fournissent d'ailleurs que titre et résumé) et les photos des sites sources ne sont pas réutilisées dans nos articles (couverture générée à nos couleurs).
- **Contrôle strict avant publication** (`recap/validate.js`) : JSON conforme, longueurs, langue, aucune promesse ni conseil de pari, aucun chiffre absent des faits, aucun nom propre (joueur, équipe, site) absent des faits, aucune reprise de 7 mots d'affilée d'un titre de presse. Si l'IA est indisponible ou refusée, un article de secours exact (sans IA) est publié.
- **Sources** : liste en bas de chaque article (site, titre, lien en `nofollow`). Section « Matchs à surveiller » : liens vers les fiches avec notre pronostic ; les infos de presse **ne modifient aucune probabilité**.
- Réglage dans l'admin (Réglages → Actualités foot) ; la tâche se relance depuis « IA et tâches ». La notification « Le point du jour » (texte accrocheur déjà généré et stocké dans `articles/{id}.fr.notif`) est la prochaine étape.

## Coupons flash archivés (preuves de fiabilité)

Chaque jour, `buildPredictions` enregistre une seule fois trois coupons (2, 3 et 5 sélections) dans `coupons_flash/{jour}_{n}`, avant les coups d'envoi : ils ne sont jamais modifiés. `syncResults` les règle (perdu dès une sélection ratée, gagné si toutes réussissent, annulé si une sélection n'est pas évaluable). L'accueil n'affiche « Nos derniers coupons gagnants » que s'il y en a eu dans les 14 derniers jours, avec le taux global à côté ; la page Bilan publie tout l'historique, gagnants et perdus, avec la probabilité annoncée contre le taux réel.

## Source des données de football

- **Démarrage gratuit : football-data.org** (`FOOTBALL_DATA_TOKEN`). Calendriers, scores et mi-temps de 12 championnats (Premier League, Liga, Serie A, Bundesliga, Ligue 1, Ligue des champions, Eredivisie, Primeira Liga, Championship, Brasileirão, Copa Libertadores, Coupe du monde), 10 appels par minute, gérés automatiquement. Sans statistiques de match ni cotes : pas de pronostics corners, tirs, cartons, et pas de recalage sur les cotes. Aucun championnat africain.
- **Plus tard : API-Football Pro** (`API_FOOTBALL_KEY`) pour l'Afrique, les statistiques et les cotes. Choix de la source : paramètre `FOOTBALL_SOURCE` (`football-data` ou `api-football` ; vide = football-data si son jeton existe). Les identifiants de championnats diffèrent d'une source à l'autre : après un changement, rajouter les championnats dans l'admin (Réglages).
- Identifiants football-data.org : 2015 Ligue 1, 2021 Premier League, 2014 Liga, 2019 Serie A, 2002 Bundesliga, 2001 Ligue des champions, 2003 Eredivisie, 2017 Primeira Liga, 2016 Championship.

## Points à vérifier avant le lancement

- **Jeton Cloudflare** : le jeton actuel n'a pas de date de fin, mais il a été partagé dans une conversation : le renouveler une fois installé dans Firebase Secrets (`firebase functions:secrets:set CF_API_TOKEN`).
- **Identifiants de championnats** d'API-Football : l'admin vérifie chaque identifiant à l'ajout.
- **Offre API-Football** : l'offre gratuite n'a accès qu'aux saisons 2022 à 2024 (testé) ; il faut l'offre Pro pour la saison en cours. La clé a été partagée dans une conversation : la renouveler après installation. une saison complète d'un championnat coûte 1 requête par jour, chaque match terminé 1 requête de statistiques, plus les cotes et confrontations. Le quota restant s'affiche dans l'admin. L'offre gratuite (quelques dizaines à centaines de requêtes par jour) ne suffira pas pour beaucoup de championnats.
- **Pays des visiteurs** : l'en-tête de pays de l'infrastructure n'est peut-être pas transmis par Hosting. Sinon le pays est déduit du fuseau horaire. L'admin indique la méthode utilisée (« Pays déduits du fuseau… »).
- **Détection « pas d'annonce »** : le passage Adsterra → Monetag → Afrolook se base sur le contenu de l'iframe (`filled()` dans `site/js/pf.js`). À ajuster avec le comportement réel des réseaux.
- **Textes légaux** (`functions/src/render/legal.js`) : à faire relire par un juriste. Ils affirment que le site ne reçoit aucune commission des bookmakers : à modifier si une affiliation est décidée.
- **Règles des réseaux publicitaires** : vérifier qu'Adsterra et Monetag acceptent un site de pronostics.
- **Fiabilité des paris** : modèle simple (Poisson corrigée + loi binomiale négative). Le bilan public mesure l'écart entre probabilité annoncée et taux réel ; la calibration se corrige toute seule après 60 pronostics terminés.

## Organisation du code

```
functions/index.js           tâches planifiées + fonction web pfWeb (pages, /api/event, /api/config, /api/admin/*)
functions/src/engine/        matrice de scores, marchés, comptages, choix du pronostic, évaluation, bilan
functions/src/shared/        calcul de coupon (partagé serveur et navigateur, copié dans site/js par scripts/build-site.js)
functions/src/ai/            prompt, validation stricte, fournisseurs (Workers AI, Gemini), texte de secours
functions/src/data/          client API-Football et normalisation
functions/src/jobs/          syncFixtures, buildPredictions, syncResults, weeklyReport, aiHealthCheck
functions/src/render/        pages HTML rendues côté serveur (cache CDN), pages légales, routeur, CSS
functions/src/http/          mesure sans cookie (HyperLogLog), API d'administration
site/                        fichiers statiques : polices, scripts du navigateur, administration
firestore.rules              aucun accès direct depuis le navigateur : tout passe par les fonctions
```

Règles de fonctionnement du site : les chiffres viennent du calcul, jamais de l'IA ; une analyse qui contient un chiffre inventé ou une promesse de gain est refusée ; si l'IA échoue, un texte de secours est construit à partir des chiffres (un match n'est jamais sans pronostic) ; aucun cookie ; aucune publicité tierce dans l'Union européenne avant accord.
