import 'package:afrolook_api_client/afrolook_api_client.dart';

import 'jeux_api.dart';

/// Administration du quiz, d'Étude et des Contes (équipe, permission « content.moderate » côté API) :
/// `/admin/quiz/*`, `/admin/etude/overview`, `/admin/contes`.
/// Les réponses de l'API sont en snake_case ; les écrans lisent du camelCase (clés `byRegion`, `playedToday`, `qHash`…).
/// Aucun retour à Firebase : une erreur est remontée telle quelle (voir [errorText]).
class LearningAdminApi {
  LearningAdminApi._();

  /// Message en français à afficher pour une erreur d'une page d'administration.
  static String errorText(Object e) {
    if (e is ApiException) {
      if (e.isNotFound || e.status == 403) return "Cette page est réservée à l'équipe.";
      return e.message;
    }
    return 'Une erreur est survenue. Réessayez.';
  }

  static Map<String, dynamic> _asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  // ── Quiz ──

  /// Participation par jour, progression, Grand Défi, rétention, joueurs les plus actifs et réglages (`GET /admin/quiz/stats`).
  static Future<Map<String, dynamic>> quizStats({int days = 7}) async =>
      parseQuizStats(JeuxApi.map(await JeuxApi.client.get('/admin/quiz/stats', query: {'days': days.clamp(1, 30)})));

  static Map<String, dynamic> parseQuizStats(Map<String, dynamic> m) {
    final out = JeuxApi.camelKeys(m, deep: {'overview', 'retention', 'days', 'top'});
    out['config'] = _asMap(m['config']);
    return out;
  }

  /// Les 5 niveaux d'une unité (1 à 40) avec la bonne réponse et le taux de réussite (`GET /admin/quiz/units/{u}`).
  static Future<Map<String, dynamic>> quizUnit(int unit, {String region = 'af'}) async =>
      JeuxApi.map(await JeuxApi.client.get('/admin/quiz/units/$unit', query: {'region': region}));

  /// Signalements ouverts regroupés par question (`GET /admin/quiz/reports`) : `{total, reports[{qHash, q, options, shown, count, reasons, comments, last}]}`.
  static Future<Map<String, dynamic>> quizReports() async => parseQuizReports(JeuxApi.map(await JeuxApi.client.get('/admin/quiz/reports')));

  static Map<String, dynamic> parseQuizReports(Map<String, dynamic> m) => JeuxApi.camelKeys(m, deep: {'reports'});

  /// Clôture les signalements d'une question : [status] « done » (traité) ou « ignored » (ignoré).
  static Future<Map<String, dynamic>> quizResolve(String qHash, String status) async =>
      JeuxApi.map(await JeuxApi.client.post('/admin/quiz/reports/$qHash/resolve', body: {'status': status}));

  // ── Étude ──

  /// Vue d'ensemble d'Étude (`GET /admin/etude/overview`).
  static Future<Map<String, dynamic>> etudeOverview() async => parseEtudeOverview(JeuxApi.map(await JeuxApi.client.get('/admin/etude/overview')));

  static Map<String, dynamic> parseEtudeOverview(Map<String, dynamic> m) {
    final out = JeuxApi.camelKeys(m);
    out['config'] = JeuxApi.camelKeys(_asMap(m['config']));
    for (final k in const ['started', 'classes', 'diplomas', 'unlocks']) {
      out[k] = _asMap(m[k]);
    }
    out['topChapters'] = m['top_chapters'] is List ? m['top_chapters'] : const [];
    out['tracks'] = m['tracks'] is List ? m['tracks'] : const [];
    return out;
  }

  // ── Contes ──

  /// Vue d'ensemble des Contes (`GET /admin/contes`).
  static Future<Map<String, dynamic>> contesOverview() async => parseContesOverview(JeuxApi.map(await JeuxApi.client.get('/admin/contes')));

  static Map<String, dynamic> parseContesOverview(Map<String, dynamic> m) {
    final out = JeuxApi.camelKeys(m, deep: {'week', 'perDay', 'topOpened', 'topFinished', 'worstDrop', 'collections', 'catalog'});
    out['config'] = _asMap(m['config']); // un réglage absent arrive sous la forme d'une liste vide
    out['week'] = _asMap(out['week']);
    for (final k in const ['perDay', 'topOpened', 'topFinished', 'worstDrop']) {
      out[k] = out[k] is List ? out[k] : const [];
    }
    return out;
  }

  /// Masque / démasque un conte (`active`), le met à la une (`featured`) ou change son prix (`price` : 0 à 500, `null` = prix du genre).
  static Future<Map<String, dynamic>> patchConte(String id, Map<String, dynamic> patch) async =>
      JeuxApi.map(await JeuxApi.client.patch('/admin/contes/${Uri.encodeComponent(id)}', body: patch));
}
