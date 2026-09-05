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
- Tier 3 → pas de badge (retiré, était debug seulement)
- Discovery (nouveaux créateurs < 20 abonnés) → `_NewCreatorBadge`
- Widget : `_FeedTierBadge` (bas du fichier `homeConstPost.dart`)

### 3b. Badges Tier + Pays dans les pages de détail (fait — commit `406b291`)
- `DetailsPost`, `VideoYoutubePageDetails`, `PostDetailsVideoFormatTel` : paramètre `feedTier?`
- Badge Tier (vert/violet) affiché si `feedTier == 'tier1'` ou `'tier2'`
- Badge Pays (drapeau + code) affiché si `post.availableCountries` n'est pas `['ALL']`
- `HomePostUsersWidget` : `feedTier` forwardé aux pages de détail
- `homeConstPost.dart` : `feedTier` passé aux deux chemins (YouTubeCard + HomePostUsersWidget)

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

### A. Déployer les Cloud Functions ⚠️ À faire manuellement
```bash
cd functions
npm run build
firebase deploy --only functions
```
Les fonctions modifiées : `updateFollowersNewPostCount` + fan-out `newPostsByCanal` (lifecycle.ts).

### B. Même algo feed partout (non fait — priorité basse)
Pages qui pourraient bénéficier du même algo Tier 1/2/3 :
- `lib/pages/home/HomeSportPost.dart` (page sport)
- `lib/pages/user/following_unseen_feed_page.dart` (feed abonnements)
- Page catégorie (clic sur une catégorie dans le feed)

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
