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

  // ── Disponibilité, file d'attente, historique, rendez-vous ──

  /// « Disponible maintenant » (expert) : accepte les appels directs et la file pendant [hours] heures.
  static Future<Map<String, dynamic>> presence(bool online, {int hours = 3}) async => JeuxApi.map(await _c.post('/consultations/presence', body: {'online': online, 'hours': hours}));

  /// Espace de l'expert : `active`, `ringing`, `waiting` (avec rang), `slots` à venir, `online`.
  static Future<Map<String, dynamic>> queue() async => JeuxApi.map(await _c.get('/consultations/queue'));

  /// Le patient quitte la file (ou raccroche avant le décrochage) : sans frais.
  static Future<Map<String, dynamic>> cancel(String id) async => JeuxApi.map(await _c.post('/consultations/$id/cancel'));

  /// `role` : `expert` ou `client`. Réponse : `totals` et `items`.
  static Future<Map<String, dynamic>> history(String role) async => JeuxApi.map(await _c.get('/consultations/history?role=$role'));

  /// Créneaux libres d'un expert.
  static Future<List<Map<String, dynamic>>> expertSlots(String userId) async => JeuxApi.list(await _c.get('/consultations/experts/$userId/slots'));

  /// Mes rendez-vous : `booked` (réservés par moi) et `published` (mes créneaux d'expert).
  static Future<Map<String, dynamic>> mySlots() async => JeuxApi.map(await _c.get('/consultations/slots/mine'));
  static Future<Map<String, dynamic>> createSlot(DateTime startsAt, int minutes) async => JeuxApi.map(await _c.post('/consultations/slots', body: {'starts_at': startsAt.toUtc().toIso8601String(), 'minutes': minutes}));
  static Future<void> deleteSlot(String id) => _c.delete('/consultations/slots/$id');
  static Future<Map<String, dynamic>> bookSlot(String id, String media) async => JeuxApi.map(await _c.post('/consultations/slots/$id/book', body: {'media': media}));
  static Future<void> unbookSlot(String id) => _c.delete('/consultations/slots/$id/book');
}
