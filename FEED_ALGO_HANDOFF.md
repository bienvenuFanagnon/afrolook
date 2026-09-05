# Afrolook — Feed Algo & Canal System — Handoff

> Dernière mise à jour : 2026-09-05  
> Branche active : `refonte_claude`

---

## Résumé de ce qui a été fait

### 1. Migration des posts (terminée — ne pas rejouer)
- **Quoi** : ajout des champs `postInterests` (tableau) et `feedTier` sur les posts existants.
- **Résultat** : 420+ posts migrés, confirmé en prod.
- **Fichiers supprimés** : `functions/src/posts/feedMigration.ts`, `functions/scripts/run_feed_migration.js`, export retiré de `functions/src/index.ts`.
- **Ne pas recréer** : la migration est one-shot, les posts sont déjà migrés.

### 2. Seuil Discovery Boost (fait — commit passé)
- `lib/services/feed/discovery_boost_service.dart` : `followersThreshold` passé de 200 → 20.
- L'app compte ~1 300 users, ~50 actifs/mois → personne ne dépassait 200.

### 3. Badges Tier dans le feed (fait — `homeConstPost.dart`)
- Tier 1 (non vus abonnements) → badge vert "Nouveau · Abonnement"
- Tier 2 (intérêts) → badge violet "Découverte · Intérêts"
- Tier 3 (tendance/récents) → badge gris "Tendance" ← ajouté dernier pour debug
- Discovery (nouveaux créateurs < 20 abonnés) → `_NewCreatorBadge`
- Widget : `_FeedTierBadge` (bas du fichier `homeConstPost.dart`)

### 4. Boutons like insensibles (fait — commits `1e172c8`, `9275b75`)
- `postDetails.dart`, `postDetailsVideo.dart` : `HitTestBehavior.opaque` sur les 4 GestureDetectors.
- `post_video_format_tel_details.dart` : GestureDetector enveloppé autour de la Column entière (icon + texte).
- `_onPostBecameVisible` connecté dans `_handleVisibilityChanged` (était défini mais jamais appelé).

### 5. Dates notifications "2101/70" (fait — commit `be568cc`)
- `lib/models/model_data.dart` → `NotificationData.fromJson` : normalise `created_at` / `updated_at` vers des microsecondes quelle que soit l'unité stockée (μs/ms/secondes).
- Cause : CF Messages stockait en ms (JS `Date.now()`), affichage Flutter utilisait `fromMicrosecondsSinceEpoch`.

### 6. CreatorUnseenPostsPage n'affiche plus les posts de canaux (fait — commit `be568cc`)
- `lib/pages/user/creator_unseen_posts_page.dart` → `_filterUnseen` : filtre `canal_id != null && canal_id.isNotEmpty`.

### 7. `newPostsByCanal` — compteur Cloud Function (fait — commit `be568cc`)
- `functions/src/posts/lifecycle.ts` : quand un post a un `canal_id`, fan-out `newPostsByCanal.{canalId} += 1` vers tous les `usersSuiviId` du canal.
- `lib/models/model_data.dart` — `UserData` : nouveau champ `Map<String, int>? newPostsByCanal` + parsing `fromJson`.

---

## Ce qui reste à faire

### A. Déployer les Cloud Functions
```bash
cd functions
npm run build
firebase deploy --only functions
```
Les fonctions modifiées : `updateFollowersNewPostCount` (lifecycle.ts).

### B. Badge `newPostsByCanal` dans la section Accueil (canaux actifs)
- **Fichier** : `lib/widgets/feed/sections/active_creators_section_widget.dart`
- **Objectif** : afficher le compteur de posts non vus sur les bulles de canaux, comme pour les créateurs.
- **Données** : `loginUserData.newPostsByCanal[canalId]` (champ déjà présent dans le modèle).
- **Pattern** : copier exactement ce qui est fait pour `newPostsByCreator` et les bulles de créateurs.
- **Reset** : quand l'user ouvre un canal, faire `newPostsByCanal.$canalId: FieldValue.delete()` dans Firestore (voir `active_creators_service.dart:clearCreatorUnseenCount`).

### C. Comprendre pourquoi Tier 1 et Tier 2 n'apparaissent pas
- **Tier 1 vide** : `loginUserData.unreadPosts` est peut-être vide → aucun abonnement récent n'a posté ou la CF `updateFollowersNewPostCount` ne tourne pas encore sur l'env de dev.
- **Tier 2 vide** : `loginUserData.interests` est peut-être `[]` → l'utilisateur n'a pas configuré ses intérêts dans son profil. Vérifier avec `print(authProvider.loginUserData.interests)` au démarrage.
- **Posts sans `postInterests`** : tester dans Firestore console : un post au hasard a-t-il le champ `postInterests: [...]` ?

### D. Badge "Tendance" — décision UX finale
- Actuellement : badge gris "Tendance" ajouté sur TOUS les posts Tier 3 pour debug.
- Décision à prendre : garder ce badge en prod ou le retirer une fois le debug terminé.
- **Si on retire** : supprimer le bloc `else if (isTier3)` dans `_buildPostWidget` dans `homeConstPost.dart`.

### E. Même algo feed partout (non fait)
Pages qui doivent utiliser le même algo Tier 1/2/3 :
- `lib/pages/home/HomeSportPost.dart` (page sport)
- `lib/pages/post_video_format_tel_details.dart` (format téléphone)
- `lib/pages/user/following_unseen_feed_page.dart` (feed abonnements)
- Page catégorie (clic sur une catégorie dans le feed)

### F. Section catégories dans le feed ("aucune catégorie pour aller voir plus")
- Le widget `feed_category_section.dart` est importé dans `homeConstPost.dart`.
- Vérifier qu'il est bien injecté dans la liste `contentWidgets` (chercher `FeedCategorySection` dans `homeConstPost.dart`).
- Si absent ou conditionnel, l'ajouter à la bonne position dans la liste de posts.

---

## Architecture du feed algo (rappel)

```
Tier 1  unreadPosts (map {postId: createdAtMs})        → badge vert
        Source : CF lifecycle.ts (fan-out sur abonnés créateur)
        Reset  : markPostsSeen CF ou dispose() de la page

Tier 2  postInterests arrayContainsAny loginUser.interests → badge violet
        Source : FeedRepository.fetchInterestPosts()
        Requis : posts avec champ `postInterests`, user avec `interests`

Tier 3  Posts récents/pays (fallback)                  → badge gris "Tendance"
        Source : _loadInitialRecentPosts() / background loading

Boost   DiscoveryBoostService (créateurs < 20 abonnés) → badge "Nouveau créateur"
```

## Fichiers clés

| Fichier | Rôle |
|---|---|
| `lib/pages/home/homeConstPost.dart` | Feed principal, logique tiers, badges |
| `lib/services/feed/feed_repository.dart` | Requêtes Firestore par tier |
| `lib/services/feed/discovery_boost_service.dart` | Boost nouveaux créateurs |
| `lib/services/active_creators_service.dart` | Section créateurs actifs + canaux |
| `lib/widgets/feed/sections/active_creators_section_widget.dart` | UI bulles créateurs/canaux |
| `lib/pages/user/creator_unseen_posts_page.dart` | Posts non vus d'un créateur (sans canaux) |
| `lib/models/model_data.dart` | Modèles : UserData, Post, NotificationData |
| `functions/src/posts/lifecycle.ts` | CF : fan-out newPostsByCreator + newPostsByCanal |

## Règles de sécurité (ne jamais modifier)

- Ne jamais afficher les 25% de commission Afrolook dans l'UI
- CinetPay Mobile Money → jamais dans le sélecteur de paiement
- Toujours passer par une Cloud Function pour les paiements
- Les boosts doivent avoir `status: 'active'` avant d'être affichés
- Ne jamais committer `functions/.env`
- Toujours utiliser `loginUserData` (JAMAIS `userData`) pour les données utilisateur
