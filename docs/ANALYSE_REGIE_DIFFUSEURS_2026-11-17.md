# Analyse de la régie Afrolook Ads côté diffuseurs (17/11/2026)

Demande du propriétaire : analyse complète du système d'annonces et des diffuseurs (documentation, intégration dans les autres projets, failles, surtout l'intégration par API, où quelqu'un pourrait se faire payer des vues sans rien afficher). Rien n'est corrigé ici : chaque correction est à valider.

Code lu : API `app/Http/Controllers/Api/AdsEngineController.php` (serve, event, go), `app/Ads/Engine.php`, `app/Ads/Settlement.php`, `app/Ads/Watch.php`, `app/Ads/Envelopes.php`, `app/Ads/Space/Publishers.php`, `SpaceAdmin.php` ; site `site/src/ads_docs.mjs`, `site/static/ads/tag.js` ; `slashatlas/static/js/afrolook-ads.js` ; `pronoflashia/site/js/pf.js`.

## 1. Comment une vue devient de l'argent (rappel)

1. `GET /ads/api/serve?pub=ap_…&fmt=…&vid=…` : le serveur choisit une annonce et renvoie un **jeton signé** (annonce, diffuseur, emplacement, format, heure, pays).
2. Le diffuseur affiche l'annonce, puis envoie `POST /ads/api/event` avec le jeton, `e=view` et `ms` (temps visible).
3. Le serveur accepte la vue si : jeton valide et jamais utilisé, moins de 30 min, `ms` ≥ durée du format et ≤ temps écoulé, plafonds respectés (3 vues de la même annonce par visiteur et par jour, 300 par visiteur, intervalle par emplacement, **2 000 par adresse IP et par jour**), pas un robot (navigateur déclaré), bonne origine.
4. Chaque nuit, `Settlement::settleDay` paie 65 % du prix du format pour chaque vue valide d'une annonce payante « Réseau » ; gains bloqués 30 jours, réserve de 10 % pendant 90 jours ; retrait manuel par Mobile Money (≥ 10 000 F), payé par l'équipe.

## 2. Failles et faiblesses (par gravité)

| # | Gravité | Constat | Conséquence | Correction proposée |
|---|---|---|---|---|
| F1 | **Réduite le 17/11** (était haute) | La vue n'est **pas liée au visiteur ni à l'adresse** de la demande : le jeton ne contient ni l'IP ni le `vid`. Un script sur un serveur peut appeler `serve` puis `event` sans jamais rien afficher. Le contrôle d'**origine** repose sur l'en-tête `Origin`, qu'un script hors navigateur écrit comme il veut. | **Un diffuseur peut se faire payer des vues jamais affichées** (intégration par API, ou faux trafic sur son identifiant) | Mettre l'empreinte de l'IP (même réseau /24) et du `vid` dans le jeton, et refuser un `event` qui ne vient pas du même visiteur ; exiger que l'image de l'annonce ait été réellement chargée sur notre CDN par ce visiteur (pixel d'affichage signé) avant de compter la vue |
| F2 | **Corrigée le 17/11** (était haute) | **2 000 vues par IP et par jour** ; le `vid` est libre (12 à 64 caractères) : en changeant de `vid`, une seule IP contourne tous les plafonds par visiteur | Une seule IP = jusqu'à 2 000 vues payées par jour (bannière : ~1 300 F/jour par IP, beaucoup plus avec des proxys mobiles) | Plafond par IP **et par diffuseur** (ex. 60 vues/jour), plafond de `vid` différents par IP (ex. 5/jour), et alerte quand le nombre de visiteurs par IP est anormal |
| F3 | **Corrigée le 17/11** (était haute) | **Les blocages ne bloquent pas le paiement** : `review_hold` (« Paiements bloqués » après une alerte) et `payable` ne sont lus **ni** par `Settlement::settleDay` **ni** par `Publishers::requestPayout`. Seule l'équipe qui paie à la main peut l'empêcher. | Un site sous alerte ou non payable peut quand même demander son retrait | `settleDay` : ignorer `payable = false` ; `requestPayout` : refuser si un emplacement du diffuseur est `review_hold` (ou exclure ses gains) |
| F4 | **Corrigée le 17/11** (était haute) | Nos plateformes internes (`site`, `slashatlas`, `pronoflash`, `epargneplus`) **n'ont aucun contrôle d'origine** (`originOk` renvoie toujours vrai pour un diffuseur interne). Leurs identifiants sont publics. | N'importe qui peut générer des vues sur `pub=slashatlas` et **vider le budget « dans Afrolook » d'un annonceur** (sabotage, faux chiffres) | Donner à chaque plateforme interne sa liste de domaines (slashatlas.com, pronoflashia.web.app, afrolookmedia.com…) et appliquer F1/F2 aussi aux internes |
| F5 | **Corrigée le 17/11** (était moyenne) | Le paiement **ne tient pas compte de l'audience mesurée** : un site qui déclare 5 000 visiteurs et en montre 300 dans nos mesures est payé pour toutes ses vues valides ; l'écart ne fait qu'une alerte | Le faux trafic qui passe les contrôles est payé | Plafonner les vues payées d'un jour à (visiteurs mesurés par la balise × vues par visiteur raisonnables), ou suspendre le paiement quand l'écart mesuré/déclaré dépasse un seuil |
| F6 | Moyenne | Intégration **par API seule** : la mesure d'audience (`ad_audience_daily`) vient de la balise ; un diffuseur API n'a donc ni mesure fiable ni preuve d'affichage | Impossible de vérifier qu'il affiche vraiment | Réserver le paiement des sites à la **balise web** (ou à notre composant), et l'API brute aux applications vérifiées (attestation) ; le dire clairement dans la documentation |
| F7 | **Corrigée le 17/11** (était moyenne) | **Récompensée** : la documentation promet « 3 500 F la vue **complète** », mais le paiement et la dépense comptent les **vues** (`d.views`), pas les lectures complètes | Annonceur facturé et diffuseur payé à la vue, contrairement à ce qui est écrit | Facturer/payer `rewarded` (et `video`) sur `completes`, ou corriger la documentation |
| F8 | Faible | Applications : « rémunérées après attestation (étape prévue) » ; l'attestation n'existe pas pour les applications externes | Aujourd'hui aucune application externe n'est payée (sécurité OK, mais promesse non tenue) | Dire « pas encore rémunérées » dans la documentation, ou mettre en place l'attestation (Play Integrity / App Attest) |
| F9 | **Corrigée le 17/11** (était faible) | `Engine::isBot` lit seulement le navigateur déclaré (`User-Agent`), facile à imiter | Les robots simples sont filtrés, pas les autres | Ajouter F1/F2 ; refuser les IP de centres de données connues |
| F10 | Info | Le clic (`/go`) peut aussi être généré par un script, mais les clics ne sont pas payés (prix au millier de vues) | Faux taux de clic pour l'annonceur | Sans gravité financière ; même liaison au visiteur que F1 |

Points solides constatés : jeton signé à usage unique, durée minimale visible et « pas plus visible que son âge », intervalle par emplacement, plafonds par visiteur, catégories sensibles jamais sans accord, sites validés seulement après **preuve de propriété** (balise de vérification re-contrôlée, suspension après 3 jours), trafic invalide > 25 % = suspension automatique, alertes d'anomalies (`Watch`), gains retenus 30 jours + réserve 90 jours, retrait manuel.

## 3. Intégration dans nos autres projets

| Projet | Comment il affiche les annonces | État |
|---|---|---|
| Site afrolookmedia.com | balise `tag.js` (diffuseur interne `site`) | à jour |
| Application Afrolook | stock d'annonces (`/ads/pool`) + jeton par affichage, connectée | à jour |
| **SlashAtlas** | **son propre script** `slashatlas/static/js/afrolook-ads.js` avec l'identifiant **externe** `ap_2a4tcdjohi`, appels à `afrolookmedia.com/ads/api` | marche, mais copie maison du dessin (à garder au niveau de `tag.js` : marque, image entière sur fond flouté, bannières prêtes) |
| **PronoFlash IA** | **son propre script** `pronoflashia/site/js/pf.js` qui appelle **l'ancien système** `us-central1-afrolooki.cloudfunctions.net/adsServe` (anciennes fonctions Firebase, remplacées par l'API) | **à refaire** avant la mise en ligne de PronoFlash : passer à `tag.js` ou à `/ads/api/serve` |
| Épargne+ | diffuseur interne `epargneplus` prévu ; pas de code trouvé dans ce dépôt | à vérifier |

Recommandation : une seule façon de faire pour nos sites, **la balise `tag.js`** (un seul code à maintenir), avec un identifiant et une liste de domaines par site (voir F4).

## 4. La documentation actuelle (`/ads/diffuseur/documentation/`)

Ce qui va : démarrage en 4 étapes, balise web, exemple Flutter, API (serve / event / clic), tableau des formats avec la part du diffuseur, tailles des bannières, catégories, comptage et fraude, mesures, questions fréquentes.

Ce qui manque ou ne va pas :
- **Présentation** : une seule longue colonne ; le code et les explications se mélangent ; pas de bouton « Copier » ; pas d'onglets par langage ; pas de menu fixe ; on ne repère pas vite « le code à coller ».
- **Formats** : la balise gère les 8 formats, mais le **composant Flutter ne fait que les bannières** (mini, grande, rectangle, leaderboard) : rien de prêt pour carte native, carrousel, vidéo, interstitiel, récompensée dans une application. La **récompensée** n'explique pas comment récompenser la personne (attendre `complete`). La **vidéo + images** (17/11) n'est pas expliquée (média servi selon le format). Les attributs `data-size` de la balise ne sont pas listés.
- **Exactitude** : le commentaire du fichier renvoie aux anciennes fonctions Firebase (`functions/src/ads/adsEngine_logic.ts`) ; la récompensée est payée à la vue, pas à la vue complète (F7) ; « une application est rémunérée après attestation (étape prévue) » (F8).
- **Manque** : intégration WordPress / site sans code (copier la balise dans un bloc HTML), sites en React/Vue (appel de la balise après navigation), Android natif (Kotlin) et iOS (Swift) par l'API, tableau des erreurs, liste de vérification avant d'être payé, testeur d'intégration.

## 5. Proposition (à valider)

1. **Nouvelle page de documentation** : maquette `docs/maquettes/documentation_diffuseurs_proposition.html` (menu latéral fixe, code dans des cadres sombres séparés des explications, onglets Balise / Flutter / API / cURL, bouton Copier, tableau « formats × intégration », référence de l'API avec badges GET/POST, erreurs, liste de vérification, testeur d'intégration).
2. **Corrections de sécurité** F1 à F5 (API), dans cet ordre : F3 et F4 (simples, immédiates), puis F2, puis F1 et F5.
3. **Composant Flutter complet** (carte native, carrousel, vidéo, interstitiel, récompensée) ou documentation honnête : « dans une application : bannières prêtes ; autres formats par l'API ».
4. **PronoFlash** branché sur la balise avant sa mise en ligne ; SlashAtlas aligné sur `tag.js`.
