import 'package:afrolook_api_client/afrolook_api_client.dart';

import 'api_gateway.dart';

/// Gestion de l'équipe (réservée aux super-administrateurs : le serveur répond 404 aux autres).
class StaffApi {
  StaffApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static List<Map<String, dynamic>> _list(dynamic r) => ((r is Map ? r['data'] : r) as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  static Map<String, dynamic> _map(dynamic r) {
    final d = ApiClient.data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  /// Message prêt à afficher.
  static String message(Object e) {
    if (e is ApiException) {
      if (e.isNetwork) return 'Connexion impossible. Vérifie ta connexion puis réessaie.';
      return e.message.isNotEmpty ? e.message : 'Une erreur est survenue. Réessaie.';
    }
    return 'Une erreur est survenue. Réessaie.';
  }

  static Future<List<Map<String, dynamic>>> members() async => _list(await _c.get('/admin/staff'));

  static Future<List<Map<String, dynamic>>> pending() async => _list(await _c.get('/admin/staff/requests', query: {'status': 'pending'}));

  static Future<Map<String, dynamic>> catalog() async => _map(await _c.get('/admin/staff/catalog'));

  static Future<List<Map<String, dynamic>>> lookup(String q) async => _list(await _c.get('/admin/staff/lookup', query: {'q': q}));

  /// Propose (ou applique) un statut. Rend `applied` (effectif) ou `pending` (attend la validation d'une autre personne).
  static Future<String> propose({required String userId, required String type, required List<String> permissions, DateTime? expiresAt}) async {
    final r = _map(await _c.post('/admin/staff/requests', body: {
      'user_id': userId,
      'type': type,
      'permissions': permissions,
      if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String(),
    }));
    return '${r['status']}';
  }

  static Future<void> approve(String id) => _c.post('/admin/staff/requests/$id/approve', body: const {});

  static Future<void> reject(String id) => _c.post('/admin/staff/requests/$id/reject', body: const {});

  static Future<void> revoke(String userId) => _c.delete('/admin/staff/$userId');
}
