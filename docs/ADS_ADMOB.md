# Publicité AdMob — mode d'emploi

## Règles d'affichage
- **Gold actif : aucune pub.** Premium et gratuit : pubs. **Admin : toujours des pubs** (même Gold), pour vérifier.
- « Une journée sans pub » (pub récompensée, 2 par jour) masque les pubs 24 h (sauf admin).
- Pub Afrolook et pub AdMob se partagent chaque emplacement (`AdSlot`) : alternance 1 sur 2 si les deux existent, repli sur l'autre si une ne charge pas, rien si aucune (pas de trou).
- Liste courte ou vide : la pub s'affiche quand même (`AdPositions`, états vides).
- Aucune pub dans le portefeuille, le paiement, la création de post, ni dans une discussion à deux.

## Discussions et groupes
- **Liste des conversations** : pub native (petit format) après la 4ᵉ ligne puis toutes les 10 lignes, jamais parmi les épinglées (`AdPlacement`, `chatListStartAt`, `chatListEvery`, `chatListNative`).
- **Fil d'un groupe** : pub native entre deux messages (groupe officiel : toutes les 12, plus une sous le dernier message ; groupe gratuit d'un utilisateur : toutes les 15), jamais entre un message et sa réponse directe (`groupOfficialEvery`, `groupFreeEvery`, `groupsNative`).
- **Bannière fixe** au-dessus de la saisie des groupes non officiels, masquée quand le clavier est ouvert (`groupsBanner`).
- **Groupe dont le propriétaire est Gold : aucune pub.** Propriétaire Premium ou gratuit : pubs. **Groupes officiels : toujours des pubs**, bien que leur propriétaire soit l'administrateur. Les membres Gold ne voient aucune pub, comme partout.
- **Carte « pub bonus »** (groupes officiels, membre en lecture seule) : une pub récompensée donne les pièces de l'offre `coins_2` de la page Récompenses (2 pièces par défaut), avec les mêmes plafonds par jour et par semaine, décidés par le serveur. Elle apparaît quand le membre arrive en bas du fil en le faisant défiler, ou après `groupRewardDelaySeconds` (20 s). Interrupteur : `groupRewardEnabled`.

## Mode debug
En build debug : pubs de TEST de Google partout, sans condition (pas de pourcentage, pas de sessions d'attente,
plein écran toutes les 2 vidéos). Écran admin : `AdAdminPage` (état, inspecteur AdMob, essai de chaque format).

## Production
Configuration dans Firestore `AppConfig/ads` (`tools/ads/set_config.js`), lue au démarrage par la nouvelle version.
État choisi : **actif pour tout le monde sur Android dès la sortie de la version** (`enabled:true`,
`enabledAndroid:true`, `rolloutPercent:100`), **iPhone coupé** (`enabledIos:false`). Les anciennes versions de
l'app ne lisent pas ces réglages. Coupure d'urgence : `node tools/ads/set_config.js '{"enabled":false}'`.
Les nouveaux comptes n'ont pas de pub AdMob pendant leurs 3 premières sessions (`freeSessions`).

**iPhone, plus tard** : renseigner `units.ios` (emplacements créés dans AdMob), remplacer `GADApplicationIdentifier`
dans `ios/Runner/Info.plist`, mettre à jour la fiche de confidentialité de l'App Store, puis
`node tools/ads/set_config.js '{"enabledIos":true}'`.

## Page Récompenses : contrôle de l'économie
Réglages Firestore `AppConfig/rewards` (`tools/ads/set_rewards.js`), appliqués par le serveur ET affichés par l'app :
- `enabled` : interrupteur général de la page ; `offers.<id>.enabled` : couper une offre (ex. les pièces).
- `offers.<id>.ads` / `cap` : pubs demandées et limite par jour ; `maxAdsPerDay` : pubs par jour (10 par défaut).
- **Garde-fous contre la concurrence avec les abonnements** : `premiumMaxHoursPerWeek` (24 h de Premium gratuit par
  semaine par défaut) et `coinsMaxPerWeek` (20 pièces gagnées avec des pubs par semaine par défaut).
- Suivi : écran admin « Pub AdMob » (récompenses accordées aujourd'hui, pubs échangées) ; données dans
  `AdRewardStats/{jour}`.
