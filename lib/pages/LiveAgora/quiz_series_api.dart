import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:afrotok/services/api/chat_api.dart';

import 'live_quiz_ui.dart';

/// Séries de questions du quiz enregistrées sur le serveur (Gold, 16/11/2026) : branchement de [QuizSeriesStore] sur l'API.
QuizSeriesStore quizSeriesApiStore() => QuizSeriesStore(
      list: () async {
        final d = await LivesApi.quizSeries();
        return [for (final x in (d['series'] as List? ?? const [])) if (QuizSeriesItem.fromJson(x) != null) QuizSeriesItem.fromJson(x)!];
      },
      save: (id, name, questions) async {
        try {
          final d = await LivesApi.saveQuizSeries(id: id, name: name, questions: [for (final q in questions) q.toJson()]);
          final it = QuizSeriesItem.fromJson(d);
          if (it == null) throw QuizSeriesError('Réponse inattendue du serveur.');
          return it;
        } on ApiException catch (e) {
          throw QuizSeriesError(e.message);   // limite de 20 séries, Gold nécessaire, question non jouable : message du serveur
        }
      },
      delete: (id) => LivesApi.deleteQuizSeries(id),
    );
