import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/wallet_api.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';

/// Accès à l'API : fiche d'un compte côté équipe (soldes, suspension, certification, ajustements de pièces et d'argent, restauration).
/// Existent aujourd'hui : fiche (`GET /admin/users/{id}`) et suspension / rétablissement (`POST /admin/users/{id}/status`).
/// Les autres appels sont des points d'accès PRÉVUS (voir lacunes_api_argent_creations.md) : tant qu'ils sont absents, l'erreur est affichée.
class AdminMoneyApi {
  AdminMoneyApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static String message(Object e, {String fallback = 'Action impossible.'}) => WalletApi.message(e, fallback: fallback);

  /// {user, wallet, subscriptions, staff, counts, history}
  static Future<Map<String, dynamic>> user(String id) async => WalletApi.map(await _c.get('/admin/users/$id'));

  /// [action] : suspend | restore ; motif de 5 caractères au moins.
  static Future<void> setStatus(String id, String action, String reason) => _c.post('/admin/users/$id/status', body: {'action': action, 'reason': reason});

  /// Publications d'un compte (30 dernières). Point d'accès prévu : GET /admin/users/{id}/posts
  static Future<List<Map<String, dynamic>>> posts(String id) async => WalletApi.list(await _c.get('/admin/users/$id/posts', query: {'limit': 30}));

  static Future<void> deletePost(String postId) => _c.delete('/posts/$postId');

  /// Certification du compte. Point d'accès prévu : PUT /admin/users/{id}/verification
  static Future<void> setVerified(String id, bool verified) => _c.put('/admin/users/$id/verification', body: {'verified': verified});

  /// Crédit ou débit par l'équipe. [kind] : deposit_coins | earned_coins | deposit_xof | payout_xof ; [amount] signé.
  /// Point d'accès prévu : POST /admin/users/{id}/wallet-adjustments (clé d'idempotence obligatoire)
  static Future<void> adjustWallet(String id, {required String kind, required num amount, required String reason}) =>
      WalletApi.instance.pay('adj:$id:$kind:$amount:$reason', '/admin/users/$id/wallet-adjustments', body: {'kind': kind, 'amount': amount, 'reason': reason});

  /// Restauration d'un compte en cours de suppression. Point d'accès prévu : POST /admin/users/{id}/restore-deletion
  static Future<Map<String, dynamic>> restoreDeleted(String id, {required bool waiveFee}) async =>
      WalletApi.map(await _c.post('/admin/users/$id/restore-deletion', body: {'waive_fee': waiveFee}));

  /// Rappel par e-mail à un compte inactif. Point d'accès prévu : POST /admin/users/{id}/reminder
  static Future<Map<String, dynamic>> sendReminder(String id) async => WalletApi.map(await _c.post('/admin/users/$id/reminder'));
}
