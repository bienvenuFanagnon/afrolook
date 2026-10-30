# Afrolook Ads — côté éditeurs (développeurs et diffuseurs) : analyse et proposition

> Statut : **PROPOSITION, rien n'est codé ni validé** (rédigée le 2026-10-29 à la demande du propriétaire, à partir de la note de cadrage « Régie publicitaire multi-réseaux et partenaires tierce »).
> **Mise à jour du 2026-10-29 : la version à valider est désormais `docs/maquette_ads/proposition_regie.html`** (deux offres séparées, formats dessinés, eCPM, tarifs, partage, garde-fous, tableaux de bord). Le présent document garde l'analyse technique détaillée (sécurité, comptage, architecture).
> Vocabulaire : **annonceur** = celui qui paie pour être vu ; **éditeur** = propriétaire d'une application ou d'un site qui affiche nos annonces (la note parle de « partenaire », « développeur » ou « diffuseur »).

---

## 1. Ce qui existe déjà (point de départ)

| Élément | État actuel |
|---|---|
| Dépôt et validation des annonces | `adsWebCreate`, validation par l'administrateur (même écran que l'application), statuts, 3 annonces gratuites par compte, 14 jours, renouvellement |
| Lecture des annonces en ligne | `adsWebPublic` (GET, ouverte à tous, renvoie jusqu'à 60 annonces actives avec aperçu du lien) |
| Comptage | `adsWebTrack` (POST) : une vue et un clic par visiteur, annonce et jour ; robots ignorés ; plafond de 400 évènements par IP et par jour ; repère de plateforme `placements.<nom>` |
| Plateformes qui affichent déjà | Afrolook (application), `/ads/`, SlashAtlas, PronoFlash (déployés le 29/10) |
| Paiement des pubs | Dans l'application Afrolook (paiement habituel des pubs) ; **pas de partage de revenus** |
| Retraits | Demandes manuelles dans Firestore (règle existante : pas d'appel de virement automatique) |

**Constats importants avant d'aller plus loin**

1. **Aujourd'hui, personne ne paie** : les annonces du site sont gratuites (3 par compte, pendant 6 à 10 mois). Sans argent encaissé, il n'y a **rien à partager** avec des éditeurs. C'est le point n° 1 à trancher (§6).
2. **Les endpoints actuels sont ouverts** : n'importe qui peut lire les annonces et envoyer des vues/clics en inventant un repère de plateforme. C'est acceptable tant qu'aucun argent n'en dépend ; ça ne l'est plus dès qu'un éditeur est payé à la vue.
3. **Le compteur actuel ne tient pas la charge d'un réseau** : chaque évènement compté modifie le document de l'annonce dans une transaction. Firestore tient environ 1 écriture par seconde et par document ; avec plusieurs éditeurs, les annonces populaires seraient bloquées.
4. **Lenteur à froid mesurée** : la première lecture des annonces a pris 4 secondes (démarrage à froid de la fonction). Inacceptable pour un encart chez un tiers : il faut un serveur d'annonces rapide.

---

## 2. Réponses aux questions de la note

### A. Faisabilité et évolution

**A1. Comment envoyer les annonces vers des applications externes, de façon fluide et rapide ?**
Créer un **serveur d'annonces** dédié (`adsServe`), distinct de `adsWebPublic` :
- l'éditeur l'appelle avec son identifiant d'éditeur et le code de l'emplacement (`pub`, `slot`, format, langue) ;
- il renvoie **une seule annonce** (titre, image, texte, bouton, lien de clic) choisie parmi les annonces *actives et validées*, avec une rotation équitable ;
- réponse en moins de 300 ms : liste d'annonces gardée en mémoire 60 secondes, au moins **une instance toujours démarrée** (supprime les 4 secondes à froid), et réponse courte (quelques Ko, image redimensionnée et servie depuis notre stockage).

**A2. Le moyen le plus simple pour les développeurs : trois niveaux de connecteur**

| Niveau | Pour qui | Principe | Effort éditeur |
|---|---|---|---|
| **Balise web** | Sites | Une ligne `<script src="…/ads/tag.js" data-pub="…" data-slot="…">` + un `<ins>`. Le script affiche l'annonce **dans un cadre isolé (iframe) hébergé chez nous** | 2 minutes |
| **Widget Flutter / Android / iOS** | Applications (Épargne+ probablement en Flutter) | Un petit composant `AfrolookAd(slot: …)` qui appelle `adsServe`, affiche l'image et le bouton, envoie vue et clic | 10 minutes |
| **API JSON brute** | Les autres | Documentation de `adsServe` et du point de comptage | variable |

Recommandation : **commencer par la balise web et le widget Flutter** ; l'API JSON est la base commune. Pas de SDK lourd au départ.

### B. Sécurité et protection

**B1. Vues et clics frauduleux (faux affichages, clics répétés, robots, sites partenaires malhonnêtes)**

Principe : **ne jamais croire l'éditeur, croire seulement nos jetons**.
1. **Jeton d'affichage signé** : chaque annonce servie est accompagnée d'un jeton (signature secrète côté serveur) contenant l'annonce, l'éditeur, l'emplacement, l'heure et un numéro unique. Une vue ne compte que si le jeton est valide, récent (30 minutes) et **utilisé une seule fois**.
2. **Clic par redirection** : le bouton ne pointe pas vers le site de l'annonceur mais vers `…/go/<jeton>` chez nous ; notre serveur vérifie le jeton, **compte le clic, puis redirige** vers le lien validé. Un clic sans jeton valide n'existe pas.
3. **Vue mesurée chez nous** : dans la balise web, le script tourne dans l'iframe d'Afrolook et mesure « à moitié visible pendant 1 seconde ». L'éditeur ne peut pas modifier cette mesure.
4. **Déduplication** : une vue et un clic par visiteur, annonce et jour (déjà en place), plafonds par IP, par éditeur et par emplacement.
5. **Détection d'anomalies** (automatique, quotidienne) : taux de clic anormal (plus de 5 à 10 %), clics en rafale, un seul visiteur qui fait toutes les vues, trafic nocturne régulier, pics soudains. Les vues douteuses sont marquées **invalides** et ne sont **jamais payées**.
6. **Vérification de l'éditeur** : propriété du site prouvée (fichier ou balise à poser), application identifiée (nom de paquet) ; l'en-tête `Origin/Referer` doit correspondre au domaine enregistré (contrôle faible mais utile). Plus tard : Play Integrity / App Attest pour les applications.
7. **Retenue avant paiement** : les gains restent « en attente » 30 jours pour laisser le temps de détecter la fraude ; l'éditeur fautif est suspendu et ses gains annulés.
8. **Conditions d'utilisation de l'éditeur** : interdiction de cliquer soi-même, d'inciter au clic, de cacher la mention « Annonce », de placer l'annonce à un endroit trompeur.

**B2. Contenu : seulement des annonces validées, impossible à altérer**
- Le serveur ne sert **que** les annonces `active` (déjà validées par l'équipe) ; l'éditeur n'envoie jamais de contenu.
- Dans la balise web, le visuel et le lien vivent **dans notre iframe** : l'éditeur ne peut ni changer le texte, ni l'image, ni la destination.
- Dans une application, l'éditeur affiche lui-même le visuel (on ne peut pas l'empêcher de le déformer), mais **la destination est dans le jeton** (redirection chez nous) : changer l'affichage ne change pas où va le clic, et la modification d'un visuel est un manquement contractuel (suspension).
- **Catégories interdites** par éditeur (par exemple un site pour enfants ne reçoit ni jeux d'argent ni contenu adulte) et liste d'annonces/annonceurs exclus.
- Mention **« Annonce » obligatoire** et non masquable.

**B3. Vie privée sur un réseau partagé**
- **Pas de cookie, pas de suivi entre sites** : l'identifiant anonyme est **propre à chaque éditeur** (dérivé de l'éditeur), donc deux sites ne peuvent pas recouper un même visiteur.
- **Pas de ciblage comportemental** : seulement du contextuel (pays, langue, catégorie du site).
- IP : jamais conservée en clair ; empreinte avec **sel qui change chaque jour**, conservée 48 h au plus (à corriger : l'empreinte actuelle n'a pas de sel quotidien).
- Respect de « Ne pas suivre » et du contrôle global de confidentialité ; dans les applications, l'éditeur transmet le consentement s'il en recueille un.
- Pour Apple et Google : l'éditeur peut déclarer « aucune donnée de suivi » (nous ne faisons pas de suivi entre applications).
- Contrat de traitement des données et politique de confidentialité à rédiger (la loi togolaise de 2019 sur les données personnelles, et le RGPD pour les visiteurs européens).

### C. Performances et statistiques

**C1. Enregistrer en temps réel les vues et clics de dizaines d'applications sans ralentir nos serveurs**

Remplacer le compteur par annonce (point chaud) par :
1. **Écriture d'un évènement léger** (sans transaction sur le document de l'annonce) ;
2. **Compteurs répartis** (plusieurs « sous-compteurs » par annonce) puis **cumul toutes les minutes** par une fonction planifiée vers `Advertisements` et vers `AdsDaily/{jour}_{annonce}_{éditeur}` ;
3. Déduplication par document à durée de vie limitée (suppression automatique, ce qui règle aussi le nettoyage de `AdsWebSeen`).
« Temps réel » = chiffres à jour **à la minute près** pour l'annonceur (suffisant). Capacité estimée : ~100 000 à 200 000 évènements par jour sans souci avec Firestore ; au-delà, passer par une file (Pub/Sub) et BigQuery. On ne dimensionne pas pour l'inconnu : on mesure et on migre si besoin.

**C2. Attribuer avec précision stats et revenus par éditeur**
- Chaque évènement valide porte `éditeur + emplacement + annonce + jour` ; le cumul quotidien `AdsDaily` donne la **vérité comptable**.
- **Registre des gains** (`PublisherEarnings`) : une ligne par éditeur et par jour, jamais modifiée après coup (corrections par lignes d'ajustement).
- Modèle de calcul recommandé (à valider, §6) : chaque jour, le **montant réellement consommé** par chaque annonce payante est réparti entre ses **vues valides** (toutes plateformes) ; la part de l'éditeur = (vues valides sur ses emplacements) × (valeur d'une vue) × (pourcentage éditeur, par exemple 60 à 70 %). Afrolook garde le reste. C'est simple, équitable et ne dépend d'aucun prix inventé.

---

## 3. Architecture proposée (résumé)

```
Éditeur (site/app) ──► balise ou widget ──► adsServe (rapide, jeton signé)
                                             │
                  vue mesurée chez nous ◄────┤        annonce choisie parmi les « active »
                                             ▼
Visiteur ──clic──► /go/<jeton> (vérifie, compte, redirige vers le lien validé)
                                             │
                          événements ──► compteurs répartis ──► cumul à la minute
                                             │                    │
                          détection d'anomalies (quotidienne)     ▼
                                             ▼              Tableau de bord annonceur (totaux, par plateforme)
                          registre des gains éditeur ──► retenue 30 j ──► demande de retrait (manuelle, comme les retraits)
```

Nouvelles données (toutes en accès serveur uniquement, à ajouter aux listes de refus de `firestore.rules`) :
`AdPublishers` (éditeurs : domaine ou paquet, statut, % de part, catégories interdites), `AdSlots` (emplacements), `AdsDaily`, `PublisherEarnings`, `PublisherPayouts`, `AdFraudFlags`.

**Les plateformes d'Afrolook deviennent les premiers « éditeurs »** (Afrolook, SlashAtlas, PronoFlash, Épargne+) : on les migre vers le même serveur d'annonces. Avantage : on teste tout le système avec nos propres sites avant d'ouvrir à des tiers.

---

## 4. Écrans à prévoir

- **Espace éditeur** (nouvel onglet du compte Google existant) : déclarer un site/une application, prouver la propriété, créer des emplacements, copier la balise ou le code du widget, voir vues, clics et (plus tard) gains.
- **Page publique « Éditeurs »** : explication, conditions, formulaire « contactez-nous » au début (inscription ouverte seulement plus tard).
- **Administration** : valider ou suspendre un éditeur, fixer son pourcentage, voir les alertes de fraude, valider les retraits.
- **Tableau de bord annonceur** : déjà en place, ajout du détail par plateforme (les données `placements` sont déjà enregistrées).

---

## 5. Étapes proposées (chacune validée avant la suivante)

| Étape | Contenu | Argent ? |
|---|---|---|
| **0 — Décisions** | Répondre aux questions du §6 ; rédiger les conditions des éditeurs | non |
| **1 — Socle** | `adsServe` rapide, jetons signés, redirection de clic, compteurs répartis, `AdsDaily` ; migration de SlashAtlas, PronoFlash (puis Afrolook et Épargne+) sur ce socle | non |
| **2 — Ouverture pilote** | Espace éditeur, validation par l'administrateur, balise web et widget Flutter, documentation, 2 à 5 partenaires **invités** | non (visibilité seulement) |
| **3 — Argent** | Annonces payantes en production, registre des gains, retenue 30 jours, retraits manuels, détection d'anomalies | oui |
| **4 — Durcissement** | Play Integrity / App Attest, règles d'anomalies affinées, éventuel SDK | oui |

Ordre voulu : **le socle d'abord avec nos propres plateformes**, ensuite des partenaires invités, et **l'argent seulement quand il y a des données réelles**. Mettre de l'argent trop tôt crée l'incitation à la fraude avant que les défenses soient rodées.

---

## 6. Questions à valider par le propriétaire

1. **Modèle de revenus** : (a) % de ce que l'annonceur dépense réellement (recommandé), (b) prix fixe pour 1 000 vues valides, (c) pas d'argent au départ, visibilité seulement. Puisque les annonces sont gratuites pendant 6 à 10 mois, **voulez-vous démarrer sans paiement des éditeurs (c)** ?
2. **Part de l'éditeur** : quel pourcentage (60 à 70 % est courant) ? Les éditeurs devront **connaître leurs conditions** ; la règle « ne jamais afficher la part de 25 % de l'application » concernait les commissions de parrainage : confirmez qu'elle ne s'applique pas à la part éditeur.
3. **Ouverture** : partenaires **invités** au début (recommandé) ou inscription libre avec validation ?
4. **Épargne+** : de quelle technologie est-elle faite (Flutter ?) pour fixer le premier connecteur.
5. **Les annonceurs sont-ils d'accord par défaut** pour que leur annonce aille chez tous les éditeurs ? (Aujourd'hui : « Afrolook, SlashAtlas, Pronoflash et d'autres plateformes ».) Prévoir une option « seulement mes plateformes » ?
6. **Contenus et catégories** : quelles catégories refuser chez les partenaires (adulte, jeux d'argent… PronoFlash parle de paris) ?
7. **Retraits des éditeurs** : monnaie (pièces ou francs CFA), seuil minimum (par exemple 5 000 F), mode de paiement manuel comme les retraits actuels, retenue de 30 jours.
8. **Juridique** : conditions d'utilisation éditeurs, contrat de traitement des données, politique de confidentialité mise à jour : qui les valide ?
9. **Nom** : « Afrolook Ads — Éditeurs » ou un autre nom pour cette partie ?

## 7. Risques à garder en tête

- **Fraude** dès qu'il y a de l'argent (traitée en §2-B, mais jamais éliminée à 100 %).
- **Audience faible au départ** : peu d'éditeurs rentables ; l'effet réseau demande du temps.
- **Image de marque** : un partenaire de mauvaise qualité qui affiche nos annonces ; d'où la validation et les catégories.
- **Coût du serveur** : instance toujours démarrée, écritures Firestore ; à surveiller dès l'étape 1.
- **Ne pas promettre trop tôt** aux annonceurs une diffusion « partout » tant que le réseau n'existe pas réellement.
