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

---

# Erreurs « quota CPU » (octobre 2026)

## Symptôme
Abonnement, réponses Quiz, etc. : « Erreur technique » / « Une erreur est survenue » par moments (9 h–11 h et 17 h–18 h UTC).
Journaux : « The request failed because the project exceeded its quota limit for run.googleapis.com/cpu_allocation ».

## Cause
- Quota régional Cloud Run : **20 vCPU** (`CpuAllocPerProjectRegion`, us-central1). Une hausse (30 000 / 40 000 / 60 000) a été demandée par l'API Cloud Quotas :
  refusée automatiquement « pour le moment » (reste 20 000). À redemander depuis la console si besoin.
- Le SDK `firebase-functions` v6 réserve **1 vCPU entier par fonction** (≠ 0,167 de l'ancien comportement) : 125 services × 1 vCPU, alors que le trafic est faible
  (~15 000 requêtes / 24 h, ~40 utilisateurs actifs / jour sur 1 598 inscrits).
- `syncFollowsFromLegacy` (déclencheur sur chaque écriture de `Users`) = 64 % des invocations.

## Correctif
- `functions/src/shared/globalOptions.ts` : `setGlobalOptions({ cpu: "gcf_gen1", maxInstances: 30 })` (fraction de vCPU, 1 requête à la fois par instance), importé en première ligne de `index.ts`.
- `cpu: 1` (concurrence 80, `maxInstances: 10`) conservé pour : `followUser`, `syncFollowsFromLegacy`, `mirrorUserPresence`, `quizAnswer`, `quizStartLevel`, `etudeAnswer`, `updateFollowersNewPostCount`, `repostFanOut`
  + les webhooks de paiement et calculs hebdomadaires lourds qui avaient déjà `cpu: 1`.
- App : `FollowService`, `QuizService._call`, `EtudeService._call` rejouent la requête (1 s, 2 s) si le serveur répond `resource-exhausted` / `unavailable` (refus avant exécution → pas de doublon).

## Lectures Firestore côté app
- Écoute des notifications non ouvertes de l'accueil : sans limite → jusqu'à 2 812 documents relus à chaque ouverture (moyenne 123 / utilisateur actif).
  Désormais `limit(100)` + pastille « 99+ ».
