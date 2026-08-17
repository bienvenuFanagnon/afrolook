# Suivi — Système de Récompenses Hebdomadaires Afrolook

## Objectif
Récompenser automatiquement chaque lundi :
- **Top 5 commentateurs** de la semaine (commentaires réels, pas de suggestions)
- **Top 3 posts** de la semaine (score = vues uniques + commentateurs uniques + likes uniques)

## Récompenses

### Commentateurs
| Rang | Pièces |
|------|--------|
| 1er  | 500    |
| 2e   | 300    |
| 3e   | 200    |
| 4e   | 100    |
| 5e   | 50     |

### Posts
| Rang | Pièces |
|------|--------|
| 1er  | 1000   |
| 2e   | 500    |
| 3e   | 300    |

## Architecture de sécurité
- **Verrou d'idempotence** : `WeeklyRewardLocks/{année}-W{semaine}_{type}` (écriture atomique `create()`)
- **Anti-spam commentaires** : min 10 chars, 1 commentaire/post/user, ancienneté compte ≥ 7j, pas ses propres posts, pas `type == suggestion`
- **Anti-manipulation posts** : vues/commentateurs/likes UNIQUES uniquement, score minimum ≥ 10
- **Transactions enregistrées** : collection `Transactions` avec `type: 'weekly_reward'`
- **CF uniquement** : aucune logique paiement côté client (admin SDK)

## Collections Firestore créées

### `WeeklyRewardLocks/{année}-W{semaine}_{type}`
```json
{
  "weekId": "2026-W34",
  "type": "commentators | posts",
  "processedAt": "<timestamp>",
  "winnersCount": 5
}
```

### `WeeklyTopCommentators/{weekId}`
```json
{
  "weekId": "2026-W34",
  "computedAt": "<timestamp>",
  "rankings": [
    { "rank": 1, "userId": "...", "commentCount": 42, "rewardedCoins": 500, "paid": true }
  ]
}
```

### `WeeklyTopPosts/{weekId}`
```json
{
  "weekId": "2026-W34",
  "computedAt": "<timestamp>",
  "rankings": [
    { "rank": 1, "postId": "...", "authorId": "...", "score": 120, "uniqueViews": 80, "uniqueComments": 25, "uniqueLikes": 15, "rewardedCoins": 1000, "paid": true }
  ]
}
```

### `Transactions/{id}` (entrée ajoutée par paiement)
```json
{
  "type": "weekly_reward",
  "subType": "top_commentator | top_post",
  "weekId": "2026-W34",
  "receiverId": "...",
  "coinsAmount": 500,
  "rank": 1,
  "timestamp": "<timestamp>"
}
```

## Fichiers créés / modifiés

### Cloud Functions
| Fichier | Statut |
|---------|--------|
| `functions/src/posts/weeklyRewards.ts` | ✅ Fait |
| `functions/src/index.ts` | ✅ Fait |

### Flutter — nouveaux fichiers
| Fichier | Statut |
|---------|--------|
| `lib/pages/weekly_top/weekly_top_posts_page.dart` | ✅ Fait |
| `lib/widgets/feed/sections/weekly_top_posts_section_widget.dart` | ✅ Fait |
| `lib/services/weekly_rewards_service.dart` | ✅ Fait |

### Flutter — fichiers modifiés
| Fichier | Statut |
|---------|--------|
| `lib/widgets/feed/sections/active_creators_section_widget.dart` | ✅ Fait (miniaturisé) |
| `lib/pages/home/HomeConstPost.dart` | ✅ Fait (intégration + preload) |
| `lib/widgets/flame_leaderboard.dart` | ✅ Fait (section récompenses hebdo) |
| `lib/widgets/flame_streak_banner.dart` | ⬜ Non requis (scope non demandé) |
| `lib/pages/home/homeScreen.dart` (menu drawer) | ✅ Fait |
| `lib/pages/info.dart` (modal présentation projet) | ✅ Fait |

## Tâches

### Tâche 1 — Cloud Function weeklyRewards.ts ✅
- [x] Créé `functions/src/posts/weeklyRewards.ts`
  - `weeklyTopCommentatorsReward` : cron `5 0 * * MON` UTC
  - `weeklyTopPostsReward` : cron `10 0 * * MON` UTC
  - Verrou idempotence, anti-spam, transactions enregistrées
- [x] Export ajouté dans `functions/src/index.ts`

### Tâche 2 — WeeklyRewardsService Flutter ✅
- [x] `lib/services/weekly_rewards_service.dart` créé
  - `getCurrentWeekId()`, `getWeekStartMs()`
  - `getWeeklyTopPosts()`, `getWeeklyTopCommentators()`
  - Enrichissement Post + UserData par batch de 10
  - Cache en mémoire par weekId

### Tâche 3 — WeeklyTopPostsPage ✅
- [x] `lib/pages/weekly_top/weekly_top_posts_page.dart` créé
  - Top 20 posts, badge 🥇🥈🥉 + coins pour top 3
  - Pull-to-refresh, état vide/erreur
  - Thème clair/sombre via AppColors

### Tâche 4 — WeeklyTopPostsSectionWidget ✅
- [x] `lib/widgets/feed/sections/weekly_top_posts_section_widget.dart` créé
  - `shouldShow` → lundi et mardi uniquement
  - Mini-cards horizontal top 5, bouton → WeeklyTopPostsPage
  - Skeleton loading, preload statique

### Tâche 5 — Miniaturisation ActiveCreatorsSectionWidget ✅
- [x] Avatars réduits, hauteur compacte

### Tâche 6 — Intégration HomeConstPost ✅
- [x] `WeeklyTopPostsSectionWidget` affiché sous `WeeklyTopCreatorsWidget` dans le pool `'WeeklyTopCreators'`
- [x] Preload des deux widgets dans `_initializeData()`

### Tâche 7 — Flame Leaderboard (info récompenses) ✅
- [x] `flame_leaderboard.dart` : section `_WeeklyRewardRow` x5 + note anti-spam

### Tâche 8 — Menu + Modal présentation projet ✅
- [x] `homeScreen.dart` drawer : ListTile "Top Posts de la semaine" → `WeeklyTopPostsPage`
- [x] `info.dart` : section statique `_buildWeeklyRewardsInfo()` avec récompenses commentateurs + posts

## Notes techniques
- `weekId` format : `{année}-W{numéro_semaine_ISO}` ex. `2026-W34`
- Semaine ISO : lundi = premier jour (compatible avec `DateTime.now().weekday`)
- Paiement : crédit direct sur `giftCoins` du gagnant + enregistrement `Transactions`
- Score post = `uniqueViews + uniqueComments + uniqueLikes` (pondération 1:1:1)
- Widgets lun-mar : `DateTime.now().weekday <= 2`
