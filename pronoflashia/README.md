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
- **Bilan sur l'accueil** : mis en avant seulement à partir de 30 pronostics terminés et 55 % de réussite (constantes `BILAN_MIN_N` et `BILAN_MIN_RATE` dans `pages.js`, et le même seuil dans `sideColumn`). La page Bilan reste toujours complète.
- **Notifications** (`sendPush`, toutes les 15 min) : coupons du jour (~07:30 UTC), pronostic le plus confiant (~12:30), coupon du soir (~16:30), chacun une fois par jour ; alerte ~1 h avant les matchs des équipes suivies (2 par jour et par abonné au plus). Envoi Web Push (bibliothèque `web-push`) : les clés VAPID se créent toutes seules au premier usage (`push_keys/vapid`, inaccessible au navigateur). Interrupteur et historique des envois dans l'admin. Sur iPhone, les notifications ne marchent qu'avec l'app installée (iOS 16.4 et plus).

## Moteur de calcul : notes d'équipes (« la mémoire » de l'IA sur chaque club)

- `functions/src/engine/ratings.js` : pour chaque championnat, une note d'attaque et une note de faiblesse défensive par équipe, estimées sur tous les matchs connus (**saison précédente comprise**, récupérée une seule fois par `syncFixtures` et gardée dans `league_history/{id}`), en comptant davantage les matchs récents (demi-vie 240 jours) et en tenant compte du niveau des adversaires. Notes recalculées chaque jour dans `league_ratings/{id}`, avec l'évolution sur 60 jours.
- **Jugées avant d'être utilisées** (walk-forward : à chaque match, seul le passé est connu) : le résultat est inscrit sur le championnat (`leagues/{id}.ratings`) et visible dans l'admin (Réglages). Si, sur au moins 100 matchs, les notes expliquent moins bien les buts que l'ancien calcul, l'ancien calcul est conservé automatiquement.
- **Mesure sur de vrais matchs** (`node scripts/backtest.js [saison]`, données openfootball, domaine public) : sur 1 510 matchs de 5 grands championnats (2023-24), la vraisemblance des buts passe de −2,9643 à −2,9254 par match et le score de probabilité RPS de 0,2014 à 0,1962 ; sur 2022-23 (saison non utilisée pour régler les paramètres), gain de +0,054 par match. Une correction « résiduelle » par équipe a aussi été essayée et **rejetée** (elle dégradait le résultat de 0,02 par match).
- La fiche d'analyse affiche « Ce que l'IA sait de ces équipes » (attaque, défense, évolution sur 60 jours). Les textes de l'IA peuvent citer ces notes quand l'écart à la moyenne est net.
- Avec l'offre gratuite de football-data.org, la saison précédente peut être refusée : les notes se calculent alors sur la saison en cours seulement (gain plus faible, mesuré à +0,02 par match), avec un nouvel essai chaque semaine.

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
