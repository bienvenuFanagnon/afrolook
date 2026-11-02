import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/wallet_api.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';

/// Accès à l'API : fiche d'un compte côté équipe (soldes, suspension, certification, ajustements de pièces et d'argent, restauration).
/// Tout passe par l'API (aucun accès Firebase) : fiche, suspension, certification, publications, retrait de publication, ajustements de solde, restauration, rappel.
class AdminMoneyApi {
  AdminMoneyApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static String message(Object e, {String fallback = 'Action impossible.'}) => WalletApi.message(e, fallback: fallback);

  /// {user, wallet, subscriptions, staff, counts, history}
  static Future<Map<String, dynamic>> user(String id) async => WalletApi.map(await _c.get('/admin/users/$id'));

  /// [action] : suspend | restore ; motif de 5 caractères au moins.
  static Future<void> setStatus(String id, String action, String reason) => _c.post('/admin/users/$id/status', body: {'action': action, 'reason': reason});

  /// Publications d'un compte (30 dernières). GET /admin/users/{id}/posts
  static Future<List<Map<String, dynamic>>> posts(String id) async => WalletApi.list(await _c.get('/admin/users/$id/posts', query: {'limit': 30}));

  /// Retire une publication (modération : elle devient masquée, rétablissable). Droit : content.moderate.
  static Future<void> deletePost(String postId, {String reason = 'Retirée par l\'équipe'}) => _c.post('/admin/moderation/posts/$postId', body: {'action': 'remove', 'reason': reason});

  /// Certification du compte (motif obligatoire pour la retirer). Droit : users.certify ; connexion récente exigée (voir AdminReauth).
  static Future<void> setVerified(String id, bool verified, {String? reason}) =>
      _c.post('/admin/users/$id/certification', body: {'verified': verified, if (reason != null && reason.isNotEmpty) 'reason': reason});

  /// Crédit ou débit par l'équipe. [kind] : deposit_coins | earned_coins | deposit_xof | payout_xof ; [amount] signé.
  /// Point d'accès prévu : POST /admin/users/{id}/wallet-adjustments (clé d'idempotence obligatoire)
  static Future<void> adjustWallet(String id, {required String kind, required num amount, required String reason}) =>
      WalletApi.instance.pay('adj:$id:$kind:$amount:$reason', '/admin/users/$id/wallet-adjustments', body: {'kind': kind, 'amount': amount, 'reason': reason});

  /// Restauration d'un compte en cours de suppression (J+15). Motif obligatoire (journal d'audit).
  static Future<Map<String, dynamic>> restoreDeleted(String id, {required bool waiveFee, String reason = 'Restauration par l\'équipe'}) async =>
      WalletApi.map(await _c.post('/admin/users/$id/restore-deleted', body: {'waive_fee': waiveFee, 'reason': reason}));

  /// Rappel par e-mail à un compte inactif (un par compte et par jour). POST /admin/users/{id}/reminder
  static Future<Map<String, dynamic>> sendReminder(String id) async => WalletApi.map(await _c.post('/admin/users/$id/reminder'));
}
