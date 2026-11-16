import 'package:afrotok/services/api/chat_api.dart';
import 'package:flutter/material.dart';

import 'live_game_ui.dart';
import 'live_quiz_ui.dart';

/// Historique des jeux d'un live, en cours ou terminé (16/11/2026) : résultats de chaque jeu, questions et réponses du quiz,
/// classement complet du quiz (les 20 premiers, ma place ; copie pour l'hôte) et classement des soutiens du conte.
void openLiveGamesHistory(BuildContext context, String liveId, {bool isHost = false}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => LiveGamesHistorySheet(
      future: LivesApi.gameResults(liveId),
      onQuiz: () {
        Navigator.pop(ctx);
        openLiveQuizHistory(context, liveId, isHost: isHost);
      },
      onQuizRanking: (gameId) => showQuizRankingSheet(ctx, LivesApi.quizRanking(liveId, gameId: gameId), isHost: isHost),
    ),
  );
}

/// Questions et réponses des quiz du live, avec le classement de chacun.
void openLiveQuizHistory(BuildContext context, String liveId, {bool isHost = false}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => LiveQuizHistorySheet(
      future: LivesApi.quizHistory(liveId),
      onRanking: (gameId) => showQuizRankingSheet(ctx, LivesApi.quizRanking(liveId, gameId: gameId), isHost: isHost),
    ),
  );
}
