# Publicité AdMob — mode d'emploi

## Règles d'affichage
- **Gold actif : aucune pub.** Premium et gratuit : pubs. **Admin : toujours des pubs** (même Gold), pour vérifier.
- « Une journée sans pub » (pub récompensée, 2 par jour) masque les pubs 24 h (sauf admin).
- Pub Afrolook et pub AdMob se partagent chaque emplacement (`AdSlot`) : alternance 1 sur 2 si les deux existent, repli sur l'autre si une ne charge pas, rien si aucune (pas de trou).
- Liste courte ou vide : la pub s'affiche quand même (`AdPositions`, états vides).
- Aucune pub dans la liste des conversations, le portefeuille, le paiement, la création de post.

## Mode debug
En build debug : pubs de TEST de Google partout, sans condition (pas de pourcentage, pas de sessions d'attente,
plein écran toutes les 2 vidéos). Écran admin : `AdAdminPage` (état, inspecteur AdMob, essai de chaque format).

## Production
Configuration dans Firestore `AppConfig/ads` (`tools/ads/set_config.js`). Par défaut **coupée** (`enabled:false`).
Mise en route : `node tools/ads/set_config.js '{"enabled":true,"rolloutPercent":0}'` → seuls les admins voient les pubs ;
puis `rolloutPercent` 10, 50, 100. Coupure d'urgence : `{"enabled":false}`.
Android : emplacements déjà créés (`ad_config.dart`). **iPhone** : renseigner `units.ios`, remplacer
`GADApplicationIdentifier` dans `ios/Runner/Info.plist`, mettre à jour la fiche de confidentialité de l'App Store,
puis `{"enabledIos":true}`.
