# Quiz Afrolook

Module de questions par niveaux (type Duolingo) mené par une mascotte, l'épervier. Aucun gain en argent :
les points servent au classement et à la boutique (cadres, titres, accessoires, bouclier de flamme).

## Ce que voit le joueur
- **Parcours** : 200 niveaux de 5 questions, en 40 unités de 5 niveaux (8 thèmes × 5 paliers de difficulté).
  Il faut 3 bonnes réponses sur 5 pour passer. Une erreur coûte un cœur (5 cœurs, 1 cœur rendu toutes les 30 min).
- **Quiz du jour** : 3 questions identiques pour tout le monde, jouables dans le fil ou sur une page.
- **Grand Défi** (façon « Qui veut gagner des millions ») : 15 questions d'affilée de plus en plus dures (3 par difficulté),
  30 s par question, paliers garantis à la 5e et à la 10e bonne réponse, jokers 50/50 et « Changer de question »,
  « M'arrêter ici » pour garder ses points. Une erreur ramène au dernier palier. 1 partie gratuite par jour,
  2 de plus contre une vidéo, et une seconde chance (nouvelle question) contre une vidéo. Un seul callable serveur : `quizChallenge`
  (actions info, start, resume, answer, j50, swap, rescue, giveup, cashout). Gains : 10, 20, 30, 50, 100, 150, 200, 300, 400, 600, 800, 1000, 1500, 2000, 3000 points.
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
`challengeEnabled`, `challengeFree`, `challengeExtraMax`, `challengeSeconds`, `challengeDailyCap`, `challengeRescue`,
`adsEnabled`, `interstitialEveryLevels`, `interstitialMaxPerDay`, `feedCardEnabled`.

## Les questions (tools/quiz)
- `questions/01..08_*.json` : 125 questions par thème (bonne réponse, 3 fausses, explication), classées par difficulté croissante.
- `node build_levels.js` : contrôle (doublons, longueurs, 4 réponses distinctes) et produit cinq jeux de 200 niveaux : `levels_af/eu/as/am/mx.json` (réponses mélangées).
- `GOOGLE_APPLICATION_CREDENTIALS=... node upload_levels.js [af eu as am mx]` : importe dans Firestore `QuizLevels/{région}_{NNN}` (écrase les niveaux existants).

### Questions par région
- Région du joueur déduite de `Users.countryData.countryCode` (`functions/src/quiz/regions.ts`) : `af` Afrique, `eu` Europe, `as` Asie + Océanie, `am` Amériques ; pays inconnu → `mx` (mélange égal des 4 régions + monde).
- Chaque jeu régional : environ 60 % de questions de sa région, le reste « monde » et autres régions.
- Fichiers : `01_…08_` (125 questions, région indiquée dans `regions.json`) + `EU_/AS_/AM_NN_thème.json` (75 questions chacun, 5 difficultés de 15).
- Pour ajouter des niveaux au-delà de 200 : agrandir les fichiers de questions, adapter `LEVELS` dans `quiz.ts`, redéployer, réimporter.
- **Relire les questions avant toute extension** : elles ont été rédigées avec l'aide d'une IA ; vérifier les faits précis.
- Les questions sont en français. Une traduction côté serveur reste possible plus tard.

## Application (lib)
- `services/quiz/quiz_service.dart` (appels au serveur), `quiz_sound.dart` (sons fabriqués par le code, aucun fichier ajouté).
- `pages/quiz/` : accueil et parcours, niveau, quiz du jour, historique, classement, boutique ; `widgets/hawk_mascot.dart` (épervier dessiné en code).
- `widgets/feed/sections/quiz_feed_card.dart` : carte du fil (après le 3e post, rappel après le 17e).
- Entrée dans le menu latéral (« Quiz »). Traductions : `l10n/tr_quiz.dart`.
- Aucune dépendance native ni fichier ajouté : une mise à jour Shorebird (`shorebird patch android`) suffit.

## Admin (menu admin → « Quiz »)
Page `lib/pages/admin/quiz_admin_page.dart`, données de la fonction `quizAdmin` (rôle `ADM` obligatoire) :
- **Aujourd'hui** : joueurs du jour, quiz du jour finis, niveaux terminés, parties du Défi, temps moyen et total, points donnés,
  part des joueurs d'hier revenus aujourd'hui, top 20 du temps passé, répartition du parcours, scores du Défi, réglages actuels.
- **Jours** : 7, 14 ou 30 jours (joueurs, temps moyen, temps total, niveaux).
- **Questions** : les 200 niveaux par difficulté et thème, bonne réponse en vert, explication et taux de réussite réel de chaque question.
Le temps vient de l'app (`QuizUsageTracker` : une mesure par minute quand le quiz est ouvert et au premier plan → `quizPing` → `QuizUsage/{jour}_{uid}`).
Il ne compte que les joueurs ayant la version de l'app qui contient ce suivi.

## Rythme
- **Barre de temps douce** de 25 s (rien n'est retiré au joueur) ; l'épervier s'agite après 15 s (ailes, sueur) ;
  « réponse éclair » (juste en moins de 10 s) avec étincelle et son, compteur sur l'écran de fin (`quiz_pace.dart`).
  Grand Défi : le vrai chronomètre de 30 s, l'épervier s'agite sous 10 s.
- La lecture des questions à voix haute (Google Text-to-Speech) a été essayée puis abandonnée pour éviter une facturation :
  l'API est désactivée et les fichiers de voix supprimés.

## Avertissement et signalements
- **Avertissement** à accepter avant de jouer (accueil du quiz, et avant la première réponse du quiz du jour dans le fil) :
  le quiz peut contenir des erreurs, les réponses ne sont pas une source officielle, les points n'ont aucune valeur en argent,
  signaler avec le bouton ou écrire à officiel.afrolook@gmail.com. L'acceptation est enregistrée avec la date serveur dans
  `QuizConsent/{uid}` (`{version, acceptedAt, platform}`) ; changer `QuizService.consentVersion` le redemande à tout le monde.
- **« Signaler une erreur »** sous chaque question corrigée (niveaux, quiz du jour, Grand Défi) : motif + commentaire, fonction `quizReport`
  (1 signalement par joueur et par question, 15 par jour) → `QuizReports`. Admin → Quiz → onglet **Signalements** : questions
  regroupées, les plus signalées d'abord, boutons « Traité » / « Ignorer ». Correction : modifier `tools/quiz/questions/*.json`,
  `build_levels.js`, `upload_levels.js`.
- Ce texte est une information claire pour les joueurs ; il ne remplace pas l'avis d'un juriste sur les conditions d'utilisation.
