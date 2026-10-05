# Quiz Afrolook

Module de questions par niveaux (type Duolingo) mené par une mascotte, l'épervier. Aucun gain en argent :
les points servent au classement et à la boutique (cadres, titres, accessoires, bouclier de flamme).

## Ce que voit le joueur
- **Parcours** : 200 niveaux de 5 questions, en 40 unités de 5 niveaux (8 thèmes × 5 paliers de difficulté).
  Il faut 3 bonnes réponses sur 5 pour passer. Une erreur coûte un cœur (5 cœurs, 1 cœur rendu toutes les 30 min).
- **Quiz du jour** : 3 questions identiques pour tout le monde, jouables dans le fil ou sur une page.
- **Série** (jours consécutifs), **classement** de la semaine (joueurs, pays), **historique** (à répondre / déjà répondu),
  **boutique** de points.
- Pubs : native sur l'écran de fin, interstitiel tous les N niveaux (jamais pendant une question),
  vidéo récompensée pour « doubler mes points » ou « +1 cœur ». Jamais pour un Gold.

## Serveur (functions/src/quiz/quiz.ts)
Les questions sont dans `QuizLevels/{001..200}`, illisibles par l'app (règles Firestore). L'app reçoit les questions
sans les réponses, avec les choix mélangés par joueur ; chaque réponse est corrigée par le serveur.

| Fonction | Rôle |
|---|---|
| `quizGetState` | progression du joueur (crée le document au premier appel) |
| `quizStartLevel` | ouvre une partie : 5 questions, sans réponses |
| `quizAnswer` | corrige une réponse (ordre imposé, délai minimal, cœur retiré si faux) |
| `quizFinishLevel` | calcule points, avance le niveau, série, classement (idempotent) |
| `quizDoublePoints` / `quizRefillHeart` | après une vidéo récompensée (plafonds par jour) |
| `quizDailyGet` / `quizDailyAnswer` | les 3 questions du jour |
| `quizShopBuy` / `quizEquip` | boutique et objets équipés |
| `quizMyRank` | rang dans la semaine |
| `quizMergeCountryBoard` | toutes les 10 min : fusionne les compteurs par pays en `QuizCountryBoard/{semaine}` |

Collections : `QuizLevels`, `QuizSessions`, `QuizAttempts` (lecture : le propriétaire), `QuizProgress` (lecture : le propriétaire),
`QuizWeekly` (classement, lecture publique), `QuizCountryShards`, `QuizCountryBoard`. Toutes en écriture serveur seulement.

Règles contre la triche : correction côté serveur, choix mélangés par joueur et par partie, une réponse par question dans l'ordre,
délai minimal entre deux réponses, points seulement à la première réussite d'un niveau, plafond de points par jour,
rejouer un niveau déjà gagné = entraînement sans points ni cœurs, aucune valeur monétaire.

## Réglages à distance (Firestore `AppConfig/quiz`)
Sans mise à jour de l'app : `node tools/quiz/set_config.js '{"dailyPointsCap":300}'` (sans argument : affiche la configuration).
Clés : `enabled`, `heartsMax`, `heartRegenMinutes`, `pointsPerCorrect`, `perfectBonus`, `passMin`, `dailyPointsCap`,
`dailyCorrect`, `dailyBonus`, `doubleMaxPerDay`, `refillMaxPerDay`, `minAnswerMs`, `shieldMax`, `shop` (prix et `enabled` par objet),
`adsEnabled`, `interstitialEveryLevels`, `interstitialMaxPerDay`, `feedCardEnabled`.

## Les questions (tools/quiz)
- `questions/01..08_*.json` : 125 questions par thème (bonne réponse, 3 fausses, explication), classées par difficulté croissante.
- `node build_levels.js` : contrôle (doublons, longueurs, 4 réponses distinctes) et produit `levels.json` (200 niveaux, réponses mélangées).
- `GOOGLE_APPLICATION_CREDENTIALS=... node upload_levels.js` : importe dans Firestore (écrase les niveaux existants).
- Pour ajouter des niveaux au-delà de 200 : agrandir les fichiers de questions, adapter `LEVELS` dans `quiz.ts`, redéployer, réimporter.
- **Relire les questions avant toute extension** : elles ont été rédigées avec l'aide d'une IA ; vérifier les faits précis.
- Les questions sont en français. Une traduction côté serveur reste possible plus tard.

## Application (lib)
- `services/quiz/quiz_service.dart` (appels au serveur), `quiz_sound.dart` (sons fabriqués par le code, aucun fichier ajouté).
- `pages/quiz/` : accueil et parcours, niveau, quiz du jour, historique, classement, boutique ; `widgets/hawk_mascot.dart` (épervier dessiné en code).
- `widgets/feed/sections/quiz_feed_card.dart` : carte du fil (après le 3e post, rappel après le 17e).
- Entrée dans le menu latéral (« Quiz »). Traductions : `l10n/tr_quiz.dart`.
- Aucune dépendance native ni fichier ajouté : une mise à jour Shorebird (`shorebird patch android`) suffit.
