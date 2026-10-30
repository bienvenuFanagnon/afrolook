# « Partage et gagne » : marketing WhatsApp d'Afrolook Ads (conception, 30/10/2026)

> **Modèle final (29/10/2026)** : voir docs/PROJET_MEMOIRE.md (journal du 29/10 soir). Résumé : les annonceurs paient l'AUDIENCE à atteindre (pas de prix au clic, pas d'offre gratuite), l'administrateur lance des campagnes offertes, 5 F par clic valide au partageur (plafond 100 clics = 500 F par jour), parrain +10 %, partageurs validés avant toute mission. Le reste de ce document décrit le principe ; en cas de différence, la mémoire du projet fait foi.

**État : conception à valider par le propriétaire, rien n'est codé.** Voir les décisions ouvertes en fin de document.

## 1. Principe
Un utilisateur de l'application partage des annonces d'annonceurs sur **son statut WhatsApp, ses groupes ou ses conversations**, avec **son lien personnel suivi**. Chaque **clic valide** sur son lien est payé en pièces ; l'annonceur paie le clic, Afrolook Ads garde la différence (jamais affichée).

**Limite technique à connaître :** WhatsApp ne donne à personne le nombre de personnes qui ont vu un statut. On ne peut donc **pas payer à la vue du statut**. Ce qui est mesurable : le **clic** sur le lien (et, plus tard, une action : inscription, installation).

## 2. Les trois acteurs
| Acteur | Ce qu'il fait |
|---|---|
| **Annonceur** | crée une « campagne Partage » (espace annonceur) : visuels, texte, lien, pays visés, **prix qu'il paie par clic valide**, budget total ; suit les clics dans SON espace (jamais publics). |
| **Partageur** (utilisateur de l'application) | choisit une campagne, reçoit le visuel et son lien personnel, le publie lui-même sur WhatsApp ; suit ses clics et ses gains. |
| **Afrolook Ads** | choisit les campagnes proposées, suit et valide les clics, applique les garde-fous, paie le partageur (pièces), alerte l'administration. |

## 3. Parcours du partageur (dans l'application)
1. Onglet « Partage et gagne » : liste des campagnes ouvertes (aperçu, **gain par clic valide en pièces**, budget restant, pays).
2. Bouton « Partager » : choix du canal (**Statut**, **Groupe**, **Conversation**). Un lien différent est créé pour chaque canal : on mesure ce qui marche.
3. L'application prépare le visuel adapté au canal (statut : vertical 9:16, vidéo de 30 s au plus ; groupe et conversation : carré 1:1 ou 4:5) avec une légende contenant le lien et la mention **« Pub »** (obligatoire, non retirable), puis ouvre le **partage natif vers WhatsApp**. **C'est toujours l'utilisateur qui valide l'envoi** : aucune automatisation.
4. Suivi : clics reçus, clics valides, gains en attente et validés, par campagne et par canal.

## 4. Le lien suivi et le comptage des clics
- Lien : \`https://afrolookmedia.com/p/<code>\` (code court lié à : partageur, campagne, canal). Il affiche un **aperçu propre dans WhatsApp** (image, titre) puis redirige vers l'annonceur.
- **Un clic est VALIDE seulement si** : le navigateur est réel (une petite page intermédiaire de ≈ 1 seconde prouve que le JavaScript s'exécute, ce qui écarte les robots) ; ce n'est pas l'aperçu de lien généré par WhatsApp (robot) ; c'est le **premier clic** de ce visiteur sur ce lien dans la journée (empreinte de visiteur et d'adresse IP salée, comme le moteur actuel) ; le **pays du visiteur** (déterminé par nos serveurs) est dans les pays visés ; ce n'est pas le partageur lui-même ; la campagne est active et son budget n'est pas épuisé.
- Les clics non valides sont gardés pour les statistiques de fraude, jamais payés.

## 5. Paiement
- Prix payé par l'annonceur par clic valide (**minimum fixé par Afrolook Ads**) ; le partageur reçoit **un pourcentage fixe** (proposé : 60 %) ; la part d'Afrolook Ads n'est **jamais affichée**.
- Gains en **pièces** (2,5 pièces = 1 F, comme partout), d'abord « en attente », **validés après 72 h** de contrôles, puis ajoutés au solde « pièces gagnées » (même circuit que les tâches : historique, retrait selon les règles existantes).
- **Plafonds** : clics payés par lien et par jour, gains par utilisateur et par jour, nombre de partages par jour (évite le spam et protège le compte WhatsApp de l'utilisateur).
- Budget de la campagne : arrêt automatique à l'épuisement ; lissage dans la journée (même logique que \`deliveryAllowed\`).
- Offre payante uniquement pour les annonceurs externes (budget prépayé par FeexPay, comme l'offre Réseau). **Pilote** : campagnes d'Afrolook, SlashAtlas, PronoFlash et Épargne+, financées par nous.

## 6. Anti-fraude (en plus du moteur existant)
Un clic payé par visiteur, appareil et jour ; auto-clics exclus (même empreinte que la création du lien dans les 24 h, clic dans les 10 premières secondes) ; plafonds par lien, utilisateur, adresse IP et pays ; **alertes automatiques** (système \`adsWatch\`) : pic de clics sur un lien, trop de clics du même pays inattendu, taux de clic anormal ; comptes suspects : gains bloqués jusqu'à vérification ; **retenue de 72 h** ; l'administration peut annuler des clics et reprendre les pièces non retirées.

## 7. Règles WhatsApp et conformité
- **Partage volontaire seulement** (jamais d'envoi automatique ni en masse, pas de liste de numéros) : c'est ce qui évite le blocage du compte de l'utilisateur et respecte les conditions de WhatsApp.
- Pour les groupes : rappel dans l'application de respecter les règles de chaque groupe ; limite de partages par jour.
- La mention « Pub » est obligatoire ; catégories sensibles (finance, paris, sensuel, etc.) **exclues par défaut** ; chaque partageur choisit les catégories qu'il accepte de partager (comme les diffuseurs).
- Page d'aperçu : mention « ce lien est suivi pour compter les clics, sans cookie ».

## 8. Données et fonctions (proposition technique)
- Collections serveur seulement : \`AdShareLinks/{code}\` (partageur, annonce, canal, compteurs), \`AdShareClicks\` (clics bruts, purgés), \`AdShareEarnings\` (gains par jour : en attente, validés).
- Campagne : champs ajoutés à \`Advertisements\` (\`shareCampaign: { cpcFcfa, userSharePct, dailyCapPerLink, creatives… }\`).
- Fonctions : \`adsShareList\` / \`adsShareCreate\` (appelables, connexion + App Check), \`adsShareGo\` (redirection + page intermédiaire, publique), \`adsShareConfirm\`, \`adsShareRollup\` (planifiée : valide les gains après 72 h), administration via les écrans régie existants (alertes, validation des campagnes).
- Réutilise : jetons signés et empreintes du moteur, \`adsWatch\`, catégories, ciblage par pays, circuit de pièces des tâches.

## 9. Côté annonceur (site, espace annonceur)
Nouvel onglet « Campagne Partage » : visuels (vertical 9:16 pour statut, carré 1:1 pour groupes, vidéo ≤ 30 s), texte court (≤ 150 caractères), lien, pays, **prix par clic**, budget. Tableau de bord : partages, clics bruts, clics valides, coût, pays — **visible uniquement dans son espace**.

## 10. Phases
0. Validation de ce document par le propriétaire.
1. **Pilote** : nos propres promotions ; liens suivis, clics valides, gains en pièces, écran admin ; mesure du taux de clic réel et de la fraude.
2. **Annonceurs externes payants** : onglet annonceur, budget FeexPay, validation des campagnes.
3. Extensions : paiement à l'action (inscription, installation), classements de partageurs, parrainage de partageurs.

## 11. Décisions ouvertes
1. Canaux autorisés au départ (statut, groupes, conversations privées).
2. Gain par clic valide pour le partageur pendant le pilote.
3. Plafond de gains par utilisateur et par jour.
4. Part du partageur (proposé : 60 %) et prix minimum du clic payé par l'annonceur.
5. Paiement à l'action (inscription, installation) dès la phase 2 ou plus tard.
