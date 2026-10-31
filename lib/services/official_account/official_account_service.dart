import 'dart:async';

import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';

import '../../models/official_account/official_account_enums.dart';
import '../../models/official_account/official_account_request.dart';
import '../../models/model_data.dart' show OfficialSubscription;

/// Service métier pour les demandes de compte officiel (API).
///
/// ATTENTION : l'API n'a pas encore ces routes (voir lacunes_api_utilisateurs.md, section « Comptes officiels »). Les appels sont prêts ;
/// tant que les routes n'existent pas, les écrans affichent l'erreur / « Réessayer » (aucun retour à Firebase).
class OfficialAccountService {
  OfficialAccountService._();
  static final OfficialAccountService instance = OfficialAccountService._();

  ApiClient get _c => ApiGateway.instance.client;

  static Map<String, dynamic> _m(dynamic r) => Map<String, dynamic>.from(ApiClient.data(r) as Map);
  static List<OfficialAccountRequest> _list(dynamic r) {
    final data = (r is Map ? r['data'] : r) as List? ?? const [];
    return data.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return OfficialAccountRequest.fromMap(m, '${m['id'] ?? ''}');
    }).toList();
  }

  // ── Soumission ──

  /// Soumet une nouvelle demande et retourne son identifiant (POST /official-accounts/requests).
  Future<String> submitRequest(OfficialAccountRequest request) async {
    final data = request.toMap();
    final r = _m(await _c.post('/official-accounts/requests', body: data));
    return '${r['id'] ?? request.id}';
  }

  // ── Lecture utilisateur ──

  /// Demande en cours (la plus récente) pour un utilisateur (GET /official-accounts/requests/mine).
  Future<OfficialAccountRequest?> getMyRequest(String userId) async {
    final r = await _c.get('/official-accounts/requests/mine');
    final data = ApiClient.data(r);
    if (data == null || (data is List && data.isEmpty)) return null;
    final m = Map<String, dynamic>.from((data is List ? data.first : data) as Map);
    return OfficialAccountRequest.fromMap(m, '${m['id'] ?? ''}');
  }

  /// Suivi de la demande : relecture toutes les 30 s (pas de temps réel côté API).
  Stream<OfficialAccountRequest?> watchMyRequest(String userId) => _poll(() => getMyRequest(userId));

  // ── Lecture admin ──

  Stream<List<OfficialAccountRequest>> watchByStatus(OfficialAccountStatus status) => watchFiltered(status: status);

  Stream<List<OfficialAccountRequest>> watchFiltered({OfficialAccountStatus? status, OfficialAccountCategory? category}) => _poll(() async => _list(await _c.get('/admin/official-accounts/requests', query: {if (status != null) 'status': status.id, if (category != null) 'category': category.id})));

  Stream<T> _poll<T>(Future<T> Function() load) async* {
    while (true) {
      yield await load();
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }

  // ── Actions admin ──

  /// Change le statut d'une demande (le serveur historise l'action et met à jour le profil : badge, vérification, droits de monétisation).
  Future<void> updateStatus({
    required OfficialAccountRequest request,
    required OfficialAccountStatus newStatus,
    required String adminId,
    String? note,
  }) =>
      _c.post('/admin/official-accounts/requests/${request.id}/decision', body: {'status': newStatus.id, if (note != null) 'note': note});

  Future<void> requestMoreInfo({required OfficialAccountRequest request, required String adminId, required String note}) =>
      updateStatus(request: request, newStatus: OfficialAccountStatus.moreInfoNeeded, adminId: adminId, note: note);

  Future<void> startReview({required OfficialAccountRequest request, required String adminId}) =>
      updateStatus(request: request, newStatus: OfficialAccountStatus.underReview, adminId: adminId);

  // ── Mise à jour d'une demande existante (moreInfoNeeded) ──

  Future<void> updateRequest({required String requestId, required String userId, required Map<String, dynamic> updatedFields}) =>
      _c.patch('/official-accounts/requests/$requestId', body: updatedFields);

  // ── Unicité du nom officiel ──

  /// `true` si le nom est disponible (GET /official-accounts/name-available?slug=).
  Future<bool> isNameAvailable(String slug) async {
    if (slug.isEmpty) return false;
    final r = _m(await _c.get('/official-accounts/name-available', query: {'slug': slug}));
    return r['available'] == true;
  }

  // ── Abonnement mensuel ──

  /// Paiement de l'abonnement officiel par le serveur (solde, ou pièces déjà payées si [paidWithCoins]). Clé d'idempotence conservée par appel.
  /// Retourne `false` si le solde est insuffisant.
  Future<bool> paySubscription(String userId, {bool paidWithCoins = false, String? idempotencyKey}) async {
    try {
      await _c.pay('/official-accounts/subscription', body: {'paid_with_coins': paidWithCoins}, idempotencyKey: idempotencyKey);
      return true;
    } on ApiException catch (e) {
      if (e.isInsufficientCoins || e.status == 402) return false;
      rethrow;
    }
  }

  /// Abonnement en cours (GET /official-accounts/subscription).
  Future<OfficialSubscription?> getSubscription(String userId) async {
    final data = ApiClient.data(await _c.get('/official-accounts/subscription'));
    if (data == null) return null;
    return OfficialSubscription.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ── Utilitaire ──

  /// Identifiant provisoire de brouillon (l'identifiant définitif est attribué par le serveur).
  String newId() => '';
}
