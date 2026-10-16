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

## Points à vérifier avant le lancement

- **Jeton Cloudflare** : celui fourni en octobre 2026 expire le **11 novembre 2026**. En créer un sans expiration ou prévoir le renouvellement, sinon l'IA bascule sur Gemini puis sur le texte de secours (le site continue de fonctionner, mais sans analyses rédigées). Le jeton a été partagé dans une conversation : le renouveler après la mise en place.
- **Identifiants de championnats** d'API-Football : l'admin vérifie chaque identifiant à l'ajout.
- **Offre API-Football** : une saison complète d'un championnat coûte 1 requête par jour, chaque match terminé 1 requête de statistiques, plus les cotes et confrontations. Le quota restant s'affiche dans l'admin. L'offre gratuite (quelques dizaines à centaines de requêtes par jour) ne suffira pas pour beaucoup de championnats.
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
