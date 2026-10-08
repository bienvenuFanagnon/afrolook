# Réduction des coûts Firestore (octobre 2026)

## Constat
- Facture « App Engine » = en réalité le transfert de données Firestore (base en `us-central`) vers les utilisateurs.
- ~250 000 lectures/jour, essentiellement des listes lues par l'application. Les publications pèsent ~2,5 Ko ;
  les profils `Users` ~7,8 Ko en moyenne (jusqu'à 146 Ko) à cause des listes qui grandissent
  (`viewedPostIds`, `unreadPosts`, `followingIds`, `postViews*`…).
- Le CDN des médias n'est pas en cause (Cloud Storage ≈ 0 $).

## Modifications déployées
1. `cleanupUnreadPosts` (quotidien 03:30 UTC, `functions/src/posts/unreadCleanup.ts`) :
   - `unreadPosts` : 30 jours / 200 entrées max (avant : 60 jours / 1000) ;
   - `viewedPostIds` : au-delà de 500, on garde les 300 plus récentes.
   Premier passage manuel : 42 591 entrées retirées sur 282 profils ; poids moyen d'un profil 7 852 → 5 970 octets (−24 %).
2. Miroir de présence `UserPresence/{uid}` (`functions/src/users/presenceMirror.ts`, trigger sur `Users`) :
   `isConnected`, `last_time_active`, `privacySettings.{ghostMode,hideLastSeen}` (quelques dizaines d'octets).
   Règles Firestore : lecture authentifiée, écriture interdite aux clients. Backfill des utilisateurs actifs < 60 jours.
3. `UserPresenceWidget` (app) écoute `UserPresence/{uid}` et se replie sur `Users/{uid}` si le miroir n'existe pas.
   Effectif à partir de la prochaine version de l'application ; les anciennes versions gardent l'ancien comportement.

## À mesurer
- Dans ~1 semaine : coût du SKU « Firestore Internet Data Transfer Out » (Facturation → Rapports → SKU) et taille moyenne des profils
  (échantillon des 600 `Users` les plus récemment actifs).

## Piste suivante (non faite)
- Sortir les listes lourdes du profil vers un document séparé lu seulement par son propriétaire (gros gain, migration + compatibilité anciennes versions).
