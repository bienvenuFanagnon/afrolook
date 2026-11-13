import 'package:afrotok/services/api/jeux_api.dart';

/// Consultation 1 à 1 à la minute : experts, réglages, appels, jeton, signal de facturation.
class ConsultationsApi {
  ConsultationsApi._();

  static dynamic get _c => JeuxApi.client;

  static Future<List<Map<String, dynamic>>> experts() async => JeuxApi.list(await _c.get('/consultations/experts'));
  static Future<Map<String, dynamic>> expert(String userId) async => JeuxApi.map(await _c.get('/consultations/experts/$userId'));
  static Future<Map<String, dynamic>> settings() async => JeuxApi.map(await _c.get('/consultations/settings'));
  static Future<Map<String, dynamic>> saveSettings({required bool enabled, required String topic, required int videoCoins, required int audioCoins, int minMinutes = 5}) async =>
      JeuxApi.map(await _c.put('/consultations/settings', body: {'enabled': enabled, 'topic': topic, 'video_coins': videoCoins, 'audio_coins': audioCoins, 'min_minutes': minMinutes}));

  /// Le client appelle (402 `insufficient_coins` si son solde ne couvre pas la durée minimale).
  static Future<Map<String, dynamic>> call(String expertId, String media) async => JeuxApi.map(await _c.post('/consultations', body: {'expert_id': expertId, 'media': media}));

  /// Appels qui sonnent chez l'expert.
  static Future<List<Map<String, dynamic>>> incoming() async => JeuxApi.list(await _c.get('/consultations/incoming'));
  static Future<Map<String, dynamic>> get(String id) async => JeuxApi.map(await _c.get('/consultations/$id'));
  static Future<Map<String, dynamic>> accept(String id) async => JeuxApi.map(await _c.post('/consultations/$id/accept'));
  static Future<void> decline(String id) => _c.post('/consultations/$id/decline');
  static Future<Map<String, dynamic>> token(String id, int uid) async => JeuxApi.map(await _c.post('/consultations/$id/token', body: {'uid': uid}));

  /// Signal toutes les 30 secondes : facture les minutes, dit combien il en reste.
  static Future<Map<String, dynamic>> tick(String id) async => JeuxApi.map(await _c.post('/consultations/$id/tick'));
  static Future<Map<String, dynamic>> end(String id) async => JeuxApi.map(await _c.post('/consultations/$id/end'));
}
