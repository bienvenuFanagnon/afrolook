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
3. **Secrets** (jamais dans le dépôt) :
   ```bash
   firebase functions:secrets:set API_FOOTBALL_KEY     # clé API-Football
   firebase functions:secrets:set CF_API_TOKEN         # jeton Cloudflare Workers AI
   firebase functions:secrets:set CF_ACCOUNT_ID        # identifiant du compte Cloudflare
   firebase functions:secrets:set GEMINI_API_KEY       # facultatif, IA de secours
   firebase functions:secrets:set STATS_SALT           # une longue chaîne aléatoire (mesure des visiteurs)
   ```
   et le paramètre `ADMIN_EMAILS` (adresse Google du premier administrateur) à la première publication.
4. Renseigner `site/admin/firebase-config.js` (configuration web du projet : Paramètres du projet → Application web).
5. Déployer : `node scripts/build-site.js && firebase deploy --only firestore,functions,hosting`.
6. Dans la console Firestore : stratégie **TTL** sur le champ `expireAt` de la collection `ai_status_log`.
7. Ouvrir `/admin` : ajouter les championnats (identifiant API-Football, ex. 61 Ligue 1, 39 Premier League, 12 Ligue des champions CAF), remplir les mentions légales, puis relancer `syncFixtures` depuis « IA et tâches ».
8. Brancher le domaine `pronoflashia.com` dans Firebase Hosting, déclarer le site dans Search Console.
9. Quand le site a 2 à 3 semaines de contenu : demander Adsterra et Monetag, coller les codes et les lignes ads.txt dans l'admin, puis activer l'interrupteur général des publicités.

## Premier déploiement depuis Google Cloud Shell (sans rien installer)

Projet Firebase : `pronoflashia` (forfait Blaze). Depuis la console Firebase, ouvrir Cloud Shell (icône `>_` en haut à droite de console.cloud.google.com), puis :

```bash
git clone https://github.com/bienvenufanagnon/afrolook.git && cd afrolook && git checkout refonte_claude && cd pronoflashia
(cd functions && npm ci)
firebase use pronoflashia
# secrets : chaque commande demande la valeur à coller (rien n'est écrit dans le dépôt)
firebase functions:secrets:set API_FOOTBALL_KEY
firebase functions:secrets:set CF_API_TOKEN
firebase functions:secrets:set CF_ACCOUNT_ID
firebase functions:secrets:set GEMINI_API_KEY      # sans clé Gemini : coller le mot « aucune »
firebase functions:secrets:set STATS_SALT          # une longue chaîne aléatoire
node scripts/build-site.js && firebase deploy --only firestore,functions,hosting
```

À la première publication, Firebase demande la valeur de `ADMIN_EMAILS` (adresse Google du premier administrateur). Adresse provisoire : `https://pronoflashia.web.app`. Tant que le nom de domaine n'est pas acheté, mettre `indexable` à faux dans l'admin (Réglages) pour que Google n'indexe pas l'adresse provisoire.

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
