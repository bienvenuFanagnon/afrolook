# PRONOFLASH IA — CAHIER DES CHARGES POUR L'AGENT
_Rédigé le 15 octobre 2026. Dossier : `pronoflashia/` du dépôt `bienvenuFanagnon/afrolook`, branche `refonte_claude`._

Ce document contient **tout ce qu'il faut savoir** pour construire le site. Lis-le en entier avant de commencer. La maquette visuelle validée comme point de départ se trouve dans [`maquette/index.html`](maquette/index.html) : ouvre-la dans un navigateur, elle a 7 onglets (Accueil, Fiche match, Bilan, Publicités, Analyse, Nom & domaine, Valider).

---

## 0. Règles de travail (obligatoires)

1. **Tout en français** : textes du site, interface d'administration, messages, commits. L'anglais viendra ensuite comme seconde langue du site.
2. **Proposer avant d'agir** : le propriétaire valide chaque étape. Présente ce que tu vas faire, attends son accord, puis fais-le. Ne coche jamais une décision « à valider » (§2.2) à sa place.
3. **Ne jamais** acheter de domaine, créer de compte payant, publier, déployer en production ni accepter de conditions sans l'accord explicite du propriétaire. C'est lui qui achète le domaine, crée les comptes publicitaires et le projet Firebase.
4. **Secrets** : aucune clé ni aucun mot de passe dans le dépôt. Les clés (API sportive, Cloudflare, Gemini, réseaux publicitaires si besoin) vont dans **Firebase Secrets** (`defineSecret`). Ne jamais commiter `functions/.env` ni `service-account.json`.
5. Avant tout déploiement de l'hébergement, regénérer les pages statiques (même logique que `slashatlas/build.mjs` : build puis déploiement).
6. Vérifie ton travail par toi-même (aperçu dans un navigateur, en largeur téléphone et ordinateur) avant d'annoncer qu'une étape est finie.

---

## 1. Le projet en bref

- **Nom** : **PronoFlash IA**. **Domaine** : **pronoflashia.com**. Libre en .com, .net et .fr le 15/10/2026, vérifié dans les registres officiels (RDAP). Il faut aussi réserver **pronoflash.com**, libre lui aussi, et le rediriger vers le site. Attention : **pronoflash.fr est déjà pris**.
- **But** : site public de **pronostics sportifs gratuits, sans inscription**. Les pronostics sont générés automatiquement : un calcul statistique, puis un texte rédigé par l'IA.
- **Le principe de base** : **le pronostic est visible tout de suite** sur chaque match, sans clic, sans dépliant, sans compte, sans rien à débloquer.
- **Sports** : **football d'abord**. Basket, tennis, etc. viendront plus tard : le modèle de données doit les prévoir dès le départ (champ `sport`).
- **Public** : Afrique francophone en priorité, plus la France et la Belgique. Il faut mettre en avant le football africain : Ligue des champions CAF, CAN, éliminatoires, grands championnats africains selon ce que couvre l'API.
- **Revenus** : publicités hors Google AdSense (**Adsterra** en principal, **Monetag** en secours), plus des encarts de **promotion d'Afrolook**, l'application sociale du propriétaire, comme sur SlashAtlas. Il faut **plus de publicités, sans gêner** le visiteur.
- **Administration** : un **hub admin** avec connexion Google, statistiques de visites (pays, historique par semaine), état de l'IA, gestion des pronostics, réglage des pubs (voir §8).

---

## 2. Décisions

### 2.1 Demandé explicitement par le propriétaire (acquis)
- Gratuit, sans inscription ni connexion pour les visiteurs.
- Le pronostic est visible immédiatement sur chaque carte de match.
- Le football d'abord, puis d'autres sports.
- Mode sombre par défaut, site moderne, optimisé pour téléphone.
- Plus de publicités sans gêner l'utilisateur, avec des encarts Afrolook parmi elles.
- Nom PronoFlash IA, domaine pronoflashia.com.
- Firebase (Hosting, Firestore, Cloud Functions), Cloudflare Workers AI (Gemini en secours), Adsterra.
- Hub admin avec connexion par compte Google : statistiques de visites, visiteurs par pays, état de l'IA, pronostics, historique de chaque semaine avec ses visiteurs.
- Site prêt à être accepté par les réseaux publicitaires (toutes les conditions remplies).

### 2.2 Proposé dans la maquette, à faire confirmer par le propriétaire
Montre-lui la liste et attends ses réponses. L'onglet « Valider » de la maquette génère un résumé qu'il peut te renvoyer.
- **Mise à jour chaque jour**, et non chaque semaine comme dans le premier cahier des charges, plus l'enregistrement des résultats après les matchs.
- **Pronostic calculé** par un modèle statistique ; l'IA ne fait que rédiger le texte (§4).
- **Une page HTML par match**, lisible par Google (§5).
- **Page Bilan publique** avec le taux de réussite automatique.
- **API-Football** comme source des matchs (son coût est à valider) ; football-data.org en plan B, mais il ne couvre que les grands championnats.
- **Projet Firebase séparé** d'Afrolook et de SlashAtlas.
- Emplacements et fréquences des publicités (§6), **pop-under coupé au lancement**.
- Français d'abord, anglais ensuite (`/en/`).
- **À décider** : affiliation aux sites de paris (règle 18+, légalité selon les pays, image du site), et une chaîne WhatsApp / Telegram « Pronos du jour ».

---

## 3. Architecture technique

| Élément | Choix |
|---|---|
| Hébergement | Firebase Hosting, avec le domaine pronoflashia.com branché par le propriétaire |
| Base de données | Cloud Firestore |
| Serveur | Cloud Functions v2, région `europe-west1` (comme SlashAtlas). **Attention** : réglage du nombre d'instances, car le quota CPU d'un projet est limité ; sur le projet Afrolook, une fonction à 2 CPU a été refusée sans limite `maxInstances` |
| IA | Cloudflare Workers AI (modèle d'instruction, sortie JSON) ; **Gemini** en secours si Workers AI échoue ou dépasse son quota gratuit quotidien |
| Données sportives | API-Football (api-sports.io) recommandée, à faire valider. Gère le quota de requêtes (cache, regroupement des appels) |
| Publicités | Adsterra (principal), Monetag (secours), encarts Afrolook (maison) |
| Connexion admin | Firebase Authentication, fournisseur **Google** uniquement, avec une liste d'adresses autorisées |
| Statistiques | Mesure maison **sans cookie** (§8.3), sur le modèle de SlashAtlas |

Le projet Firebase et le plan Blaze (nécessaire pour les fonctions planifiées et les appels externes) sont **créés par le propriétaire**. Demande-lui l'identifiant du projet.

---

## 4. Moteur de pronostics (automatique)

### 4.1 Tâches planifiées (`onSchedule`)
| Tâche | Fréquence proposée | Rôle |
|---|---|---|
| `syncFixtures` | chaque jour à 05:00 UTC | Récupère les matchs des 7 prochains jours des championnats suivis, les équipes et les statistiques utiles (forme, buts, face-à-face, cotes si disponibles). |
| `buildPredictions` | après `syncFixtures`, puis chaque heure les jours de match | Calcule les probabilités et pronostics, puis demande le texte à l'IA. Recalcule si une info importante change (report, compositions si l'API les donne). |
| `syncResults` | toutes les 30 min de 12:00 à 02:00 UTC | Enregistre les scores finaux et marque chaque pronostic réussi (✅) ou raté (❌). |
| `weeklyReport` | chaque lundi à 03:00 UTC | Fige le bilan de la semaine passée : pronostics, réussite, visiteurs, pays (voir §8.4). |
| `aiHealthCheck` | toutes les 30 min | Teste l'IA (petit appel) et enregistre son état (§8.5). |

Chaque tâche écrit un compte-rendu dans `jobs/{id}` (début, fin, durée, nombre traité, erreurs) pour l'admin.

### 4.2 Le calcul d'abord, l'IA ensuite (règle importante)
- **Les chiffres viennent du calcul, jamais de l'IA.** Modèle proposé :
  - buts attendus par équipe (loi de Poisson), à partir de l'attaque et de la défense sur les N derniers matchs, avec un avantage du terrain ;
  - mélange avec les probabilités tirées des cotes, si l'API en fournit ;
  - ajustement léger selon la forme récente et les face-à-face.
- **Marchés calculés** : 1 / N / 2, double chance (1X, X2, 12), plus/moins de 2,5 buts, les deux équipes marquent, score le plus probable.
- **Pronostic principal** = le marché qui offre la meilleure confiance utile. Éviter de toujours proposer « 1X » : fixer des règles, par exemple ne choisir une double chance que si aucun résultat simple ne dépasse un seuil.
- **Confiance** = la probabilité du pronostic choisi, ajustée selon le bilan réel (calibration progressive).
- **L'IA rédige seulement** : elle reçoit les chiffres calculés et les faits (forme, séries, face-à-face), et rend un **JSON strict** :
  `{ "analyse": "…3 à 5 phrases…", "pointsCles": ["…","…","…"], "resume": "…une phrase…" }`.
  On vérifie le JSON (schéma, longueur, langue française). Il est interdit à l'IA de changer les chiffres ou d'en inventer.
- **Si l'IA échoue** : essayer Gemini, puis un texte de secours construit à partir des chiffres. Un match ne doit jamais rester sans pronostic visible.
- **Interdit** : « gain garanti », « sûr à 100 % », toute promesse de gain.

### 4.3 Modèle Firestore (proposition)
```
sports/{sportId}                       football, basketball…
leagues/{leagueId}                     sport, nom, pays, saison, suivi:boolean, ordre
teams/{teamId}                         nom, nomCourt, couleurs[] (pour l'écusson généré), pays
matches/{matchId}
  sport, leagueId, saison, journee, coupDEnvoi (Timestamp), statut (prevu|en_cours|termine|reporte)
  domicile:{teamId,nom}, exterieur:{teamId,nom}
  slug: "psg-marseille-2026-10-18"
  stats:{ formeDom:"VVNVV", formeExt:"…", butsPour…, faceAFace:[…] }
  prono:{
    principal:{ marche:"1", libelle:"1 · Paris", confiance:68 },
    probas:{ "1":62, "N":22, "2":16 }, plus25:64, bttsOui:55, scoreProbable:"2-1",
    secondaires:[{libelle:"+2,5 buts",pct:64},{libelle:"Les 2 marquent",pct:55}],
    texte:{ analyse, pointsCles[], resume }, sourceTexte:"workers-ai|gemini|secours",
    calculeLe, version, visible:true
  }
  resultat:{ scoreDom, scoreExt, reussi:boolean|null }
stats_days/{AAAA-MM-JJ}                compteurs de visites (§8.3)
stats_weeks/{AAAA-Wss}                 bilan figé de la semaine (§8.4)
ai_status/current  +  ai_status_log/{id}
jobs/{id}                              comptes-rendus des tâches planifiées
config/ads, config/site, config/leagues  réglages modifiables par l'admin
admins/{email}                          liste des administrateurs autorisés
admin_log/{id}                          journal des actions admin
```
Règles Firestore : le public **lit** uniquement ce qui est publié (les matchs visibles). Tout le reste (stats, config, admins, journaux) est lu et écrit **par le serveur** ou par un admin vérifié. Les visiteurs n'écrivent jamais directement dans Firestore : les événements passent par une fonction (§8.3).

---

## 5. Site public

### 5.1 Pages et adresses (lisibles par Google)
| Page | Adresse | Contenu |
|---|---|---|
| Accueil | `/` | Pronos du jour (onglets par date, filtre par championnat), encadré Bilan |
| Jour | `/football/aujourdhui`, `/football/demain`, `/football/2026-10-18` | Matchs d'une date |
| Championnat | `/football/ligue-1` | Matchs à venir + bilan du championnat |
| Fiche match | `/football/ligue-1/psg-marseille-2026-10-18` | Verdict, probabilités, analyse IA, points clés, face-à-face, autres matchs |
| Bilan | `/bilan` | Taux de réussite (30 jours, par championnat, par niveau de confiance), derniers résultats |
| Pages légales | `/a-propos`, `/contact`, `/confidentialite`, `/conditions`, `/cookies`, `/mentions-legales`, `/jeu-responsable` | Voir §7 |
| Anglais | `/en/…` | Même structure (2e étape) |

- **Rendu côté serveur ou pages pré-générées**, jamais une page vide remplie seulement par le navigateur. Proposition : des pages générées par une fonction, mises en cache par Firebase Hosting (en-têtes `Cache-Control` courts sur l'accueil et les jours, plus longs sur les matchs terminés), ou régénérées après chaque `buildPredictions`. Étudie `slashatlas/build.mjs` pour la génération statique.
- **SEO** : balises `title` et `description` propres à chaque page, `sitemap.xml` mis à jour automatiquement, `robots.txt`, données structurées `SportsEvent` (schema.org) sur les fiches match, image de partage (Open Graph) par match, adresses stables.
- **Performance** : HTML léger, CSS en ligne critique, polices limitées, scripts pub chargés **après** le contenu et de façon paresseuse, **espace réservé** pour chaque emplacement pub (pas de décalage de mise en page).

### 5.2 Design (reprendre la maquette)
- Couleurs : fond `#080D18`, surfaces `#0F1626` / `#141D31`, bordures `#22304D`, **jaune « flash » `#FFD60A`** (pronostic principal), vert `#2BD576` (réussi, confiance), rouge `#FF5A5F` (raté), cyan `#38D6F5` (barres secondaires), texte `#EEF2FF` / `#8E9AB8`.
- Polices : **Barlow Condensed** (titres, verdicts, chiffres), **Inter** (texte).
- **Carte de match** : heure, championnat, deux équipes avec écusson **généré** (initiales + couleurs, **pas de logos officiels**), forme V/N/D (masquée sur téléphone), **pronostic en jaune**, confiance en %, barres 1/N/2 et deux paris secondaires.
- **Fiche match** : grand verdict jaune, jauge de confiance, probabilités, analyse, points clés (⚡), face-à-face.
- Pied de page sur toutes les pages : « 18+ · Jouez de façon responsable », « Pronostics à titre d'information, aucun gain garanti », liens légaux.

---

## 6. Publicités

### 6.1 Règle d'or
**Plus de pubs, sans gêner** : jamais de pub qui cache le pronostic, bloque la page, redirige automatiquement ou joue du son ; aucune pub plein écran à l'ouverture.

### 6.2 Emplacements (voir l'onglet « Publicités » de la maquette)
| Emplacement | Où | Format |
|---|---|---|
| Bannière haut | sous l'en-tête, jamais au-dessus du contenu principal | 728×90 ordinateur / 320×50 téléphone |
| Native dans la liste | **toutes les 4 cartes** de match, étiquette « Sponsorisé » | native Adsterra |
| Carte Afrolook | **toutes les 8 cartes** + **une dans chaque fiche match** (« Tu penses quoi de PSG – OM ? Débats sur Afrolook ») | maison |
| Bannière collante bas | téléphone, petite, **fermable** (✕), reste fermée pendant la visite | 320×50 |
| Fiche match | bannière juste sous le verdict, native après l'analyse | 300×250 / 320×100, native |
| Colonne ordinateur | pavé 300×250, puis 300×600 collant | display |
| Social Bar Adsterra | **1 fois par visite** au maximum, après 20 s | Social Bar |
| Pop-under | **coupé au lancement** ; plus tard, activable par l'admin, 1 fois par 24 h au maximum | — |

- **Remplissage** : si Adsterra ne renvoie rien, essayer Monetag, sinon afficher un encart Afrolook (jamais un vide).
- **Tout est réglable dans l'admin** (`config/ads`), sans republier : activer ou couper chaque emplacement, réseau et code de chaque emplacement, fréquence native, part d'Afrolook (en %), plafonds de répétition. **Respecte le principe de SlashAtlas** : les emplacements restent masqués tant que l'admin n'a pas activé la publicité.

### 6.3 Encarts Afrolook (modèle SlashAtlas)
Étudie `slashatlas/static/js/afrolook-ads.js` et réutilise le même principe :
- liens magasins : Android `https://play.google.com/store/apps/details?id=com.afrotok.afrotok`, iOS `https://apps.apple.com/gh/app/afrolook/id6811423047` ; choisir le lien selon l'appareil ;
- messages qui tournent, à adapter au foot : « Débats foot sur Afrolook », « Partage tes pronos entre amis », « Tes likes deviennent des pièces » ;
- photos et logo Afrolook (`maquette/img/afrolook.png`) ; ajouter des paramètres `utm_source=pronoflashia&utm_campaign=<emplacement>` pour mesurer les clics ;
- vert Afrolook `#1FAA59` ; étiquette « AFROLOOK » discrète.

---

## 7. Être accepté par les réseaux publicitaires (checklist)

À compléter **avant** de demander l'inscription chez Adsterra et Monetag. Le propriétaire fait les demandes lui-même.

- [ ] Domaine propre (pronoflashia.com) en HTTPS, site rapide et adapté aux téléphones.
- [ ] **Contenu réel et suffisant** : au moins 2 à 3 semaines de pronostics publiés et une page Bilan alimentée, plusieurs championnats, textes originaux (pas de copie).
- [ ] Pages obligatoires :
  - **À propos** : qui édite le site, comment sont faits les pronostics (calcul + IA) ;
  - **Contact** : formulaire ou adresse e-mail réelle du propriétaire, à lui demander ;
  - **Politique de confidentialité** : données collectées, mesure sans cookie, publicité, droits RGPD ;
  - **Conditions d'utilisation** ;
  - **Cookies** ;
  - **Mentions légales**, à remplir avec le propriétaire ;
  - **Jeu responsable**, avec des liens d'aide.
- [ ] **Bandeau de consentement (CMP)** pour les visiteurs de l'Union européenne et du Royaume-Uni : les publicités personnalisées attendent le consentement. Bouton « Préférences publicitaires » dans le pied de page.
- [ ] **ads.txt** à la racine, avec les lignes fournies par chaque réseau. Servi comme SlashAtlas (fichier statique ou fonction, modifiable depuis l'admin, voir `slashatlas/firebase.json`, réécriture `/ads.txt`). Ajouter aussi la vérification de propriété demandée par chaque réseau (balise meta ou fichier).
- [ ] Mentions sur toutes les pages : **18+**, « pronostics à titre d'information, **aucun gain garanti** ». Aucune promesse de gain.
- [ ] **Pas de logos officiels** de clubs ou de championnats (écussons générés, noms en texte).
- [ ] Pas de contenu interdit : pas de vente de pronostics, pas de lien vers des sites illégaux. Si l'affiliation paris est validée : seulement des opérateurs autorisés dans le pays du visiteur, avec la règle 18+.
- [ ] `robots.txt` et `sitemap.xml` en place ; site déclaré dans **Google Search Console** (pour être trouvé, même sans AdSense).
- [ ] Aucune pub ne cache le contenu et aucune redirection automatique n'existe : les réseaux et Google pénalisent ces pratiques.

---

## 8. Hub d'administration (`/admin`)

### 8.1 Connexion
- Firebase Authentication, **connexion Google uniquement** (`signInWithPopup` / `signInWithRedirect`).
- Accès réservé aux adresses de `admins/{email}`. Le premier admin est le propriétaire : demande-lui son adresse Google. Toutes les fonctions admin vérifient côté serveur que l'utilisateur connecté est dans la liste. Ne jamais se fier seulement à l'interface.
- Page `/admin` en `noindex`, sans publicité, avec un journal des actions dans `admin_log`.

### 8.2 Écrans
1. **Vue d'ensemble** : visites et visiteurs aujourd'hui / 7 jours / 30 jours, pages vues, matchs les plus vus, sources (direct, Google, réseaux sociaux, Afrolook…), appareils (téléphone / ordinateur), **visiteurs par pays** (tableau + carte ou barres), heures de pointe.
2. **Historique par semaine** : tableau semaine par semaine (lundi → dimanche), avec visites, visiteurs, pages vues, top 5 pays, top 5 matchs, nombre de pronostics, **taux de réussite de la semaine**, clics Afrolook. Comparaison avec la semaine précédente (↑ / ↓ %). Export CSV.
3. **État de l'IA** : voyant (🟢 OK / 🟠 lent / 🔴 en panne), fournisseur actif (Workers AI ou Gemini), dernier test réussi, temps de réponse, quota du jour utilisé, nombre de textes générés, nombre de textes de secours, dernières erreurs. Bouton « Tester maintenant ».
4. **Tâches automatiques** : derniers passages de `syncFixtures`, `buildPredictions`, `syncResults` et `weeklyReport` (heure, durée, nombre de matchs, erreurs), quota restant de l'API sportive. Bouton « Relancer » pour chacune.
5. **Pronostics** : liste filtrable (date, championnat, statut, confiance). Pour chaque match : voir, **masquer ou republier**, **regénérer le texte**, corriger un libellé. Toute modification manuelle est notée dans le journal.
6. **Bilan** : réussite par championnat, par type de pari et par niveau de confiance, sur 7 / 30 / 90 jours.
7. **Publicités** : réglages de `config/ads` (§6.2), lignes de l'`ads.txt`, aperçu des emplacements.
8. **Réglages** : championnats suivis (activer, couper, ordre), horaires des tâches, textes légaux, adresse de contact.

### 8.3 Mesure des visites (sans cookie, sur le modèle de SlashAtlas)
- Étudie `slashatlas/static/js/site.js` (fonction `track`, envoi par `navigator.sendBeacon` vers `/api/event`) et les compteurs journaliers de `slashatlas/functions/index.js` (collection `SlashAtlasStats`, un document par jour).
- **Aucun cookie, aucun identifiant stocké.** Les robots et les navigateurs en « Do Not Track » sont ignorés.
- **Pays** : d'abord l'en-tête de pays transmis à la fonction par l'infrastructure, si disponible (à vérifier sur Firebase Hosting / Cloud Run). Sinon, déduire le pays du fuseau horaire envoyé par le navigateur, avec une table fuseau → pays (SlashAtlas a déjà `static/js/tzc.json`). Ne jamais enregistrer d'adresse IP.
- **Visiteurs uniques** : estimation par jour avec une empreinte hachée et salée (IP + navigateur + sel qui change chaque jour, jamais conservé), comme les outils de mesure respectueux de la vie privée. Seuls des compteurs sont enregistrés.
- Compteurs du jour (`stats_days/{jour}`) : visites, visiteurs estimés, pages vues par type et par match, pays, appareil, source, clics Afrolook, clics par emplacement pub.

### 8.4 Bilan hebdomadaire (`stats_weeks/{AAAA-Wss}`)
Écrit chaque lundi par `weeklyReport` à partir des 7 `stats_days` et des matchs de la semaine : visites, visiteurs, pages vues, pays (classés), top matchs, pronostics publiés, réussis, ratés, taux de réussite, état de l'IA (pannes de la semaine). C'est la source de l'écran « Historique par semaine ».

### 8.5 État de l'IA (`ai_status/current`)
`{ fournisseur, etat: ok|lent|panne, dernierTestOk, dernierTestLe, latenceMs, generesAujourdhui, secoursAujourdhui, quotaUtilise, derniereErreur }`. Il est mis à jour par `aiHealthCheck` et par chaque génération. Un historique court est gardé dans `ai_status_log`.

---

## 9. Plan de travail proposé (à présenter au propriétaire, étape par étape)

| Étape | Contenu | Terminé quand… |
|---|---|---|
| 1 | Projet Firebase, structure du code (`pronoflashia/site`, `pronoflashia/functions`), Firestore et règles | le site vide se déploie sur une adresse de test Firebase |
| 2 | Connexion à l'API sportive + `syncFixtures` pour 2 championnats | les matchs des 7 jours sont dans Firestore |
| 3 | Modèle de calcul + `buildPredictions` + texte IA (Workers AI, Gemini en secours, texte de secours) | chaque match a un pronostic et un texte valides en JSON |
| 4 | Site public : accueil, jour, championnat, fiche match, design de la maquette, SEO | les pages sont lisibles sans JavaScript et vérifiées sur téléphone et ordinateur |
| 5 | `syncResults` + page Bilan | les pronostics passés sont marqués ✅ / ❌ et le taux s'affiche |
| 6 | Hub admin (connexion Google, écrans §8.2) + mesure des visites + `weeklyReport` + `aiHealthCheck` | l'admin voit visites, pays, semaines, état de l'IA et tâches |
| 7 | Publicités (emplacements, réglages admin, Afrolook, ads.txt, CMP) + pages légales | checklist §7 complète |
| 8 | Plus de championnats (Afrique incluse), anglais `/en/` | validé par le propriétaire |
| 9 | Branchement du domaine, Search Console, demandes Adsterra / Monetag (par le propriétaire) | site en ligne et accepté |

---

## 10. Ce que le propriétaire doit fournir

- L'achat de **pronoflashia.com** et **pronoflash.com**.
- La création du **projet Firebase** (plan Blaze) et l'accès pour l'agent.
- Un **compte API sportive** (API-Football recommandé) et sa clé, à mettre dans Firebase Secrets.
- Un **jeton Cloudflare** avec accès à Workers AI et son identifiant de compte (Firebase Secrets). Une clé **Gemini** pour le secours.
- Les comptes **Adsterra** et **Monetag**, avec les codes des emplacements et les lignes ads.txt.
- Son **adresse Google** (premier admin), l'**adresse de contact** publique, les informations des **mentions légales**.
- La **validation de la maquette** et des décisions du §2.2.

---

## 11. Références utiles dans le dépôt

- `slashatlas/build.mjs` : génération des pages statiques, sitemap, balises.
- `slashatlas/static/js/site.js` : mesure sans cookie, chargement paresseux des pubs, emplacements `data-ad`.
- `slashatlas/static/js/afrolook-ads.js` : encarts Afrolook (liens, messages, photos).
- `slashatlas/functions/index.js` : API `/api/config`, compteurs `SlashAtlasStats`, réglages pubs par l'admin, réécriture `ads.txt`.
- `slashatlas/static/js/admin.js` : exemple d'interface admin.
- `pronoflashia/maquette/index.html` : la maquette de référence (design, emplacements pubs, textes).
