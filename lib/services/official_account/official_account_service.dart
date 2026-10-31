import 'dart:async';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/admin_complements_api.dart';

import '../../models/official_account/official_account_enums.dart';
import '../../models/official_account/official_account_request.dart';
import '../../models/model_data.dart' show OfficialSubscription;

/// Service métier pour les demandes de compte officiel (API : `/official-accounts/*` et `/admin/official-accounts/*`).
/// Les règles (nom unique, une demande à la fois, 18 ans, décisions, badge et droits de monétisation) sont appliquées par le serveur.
/// Aucune lecture Firebase : une erreur est transmise à l'écran (message en français + « Réessayer »).
class OfficialAccountService {
  OfficialAccountService._();
  static final OfficialAccountService instance = OfficialAccountService._();

  // ── Soumission ──

  /// Soumet une nouvelle demande et retourne son identifiant. [idDocumentUploadId] : envoi PRIVÉ de la pièce d'identité déjà terminé.
  Future<String> submitRequest(OfficialAccountRequest request, {String? idDocumentUploadId}) => AdminComplementsApi.submitOfficial(AdminComplementsApi.requestBody(
        category: request.category,
        officialName: request.officialName,
        description: request.description,
        country: request.country,
        city: request.city,
        phone: request.phone,
        email: request.email,
        website: request.website,
        domains: request.broadcastDomains,
        networks: request.socialNetworks,
        birthDate: request.birthDate,
        idType: request.idDocumentType,
        idNumber: request.idNumber,
        idDocumentUploadId: idDocumentUploadId,
        acceptTerms: true,
      ));

  // ── Lecture utilisateur ──

  /// Demande en cours (la plus récente) de la personne connectée.
  Future<OfficialAccountRequest?> getMyRequest(String userId) => AdminComplementsApi.myOfficialRequest();

  /// Suivi de la demande : relecture toutes les 30 s (pas de temps réel côté API).
  Stream<OfficialAccountRequest?> watchMyRequest(String userId) => _poll(() => getMyRequest(userId));

  // ── Lecture admin ──

  Future<List<OfficialAccountRequest>> listFiltered({OfficialAccountStatus? status, OfficialAccountCategory? category}) =>
      AdminComplementsApi.adminOfficialRequests(status: status, category: category);

  Stream<List<OfficialAccountRequest>> watchByStatus(OfficialAccountStatus status) => watchFiltered(status: status);

  Stream<List<OfficialAccountRequest>> watchFiltered({OfficialAccountStatus? status, OfficialAccountCategory? category}) => _poll(() => listFiltered(status: status, category: category));

  Stream<T> _poll<T>(Future<T> Function() load) async* {
    while (true) {
      yield await load();
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }

  // ── Actions admin ──

  /// Change le statut d'une demande. Le serveur historise l'action (qui, quand, motif), met à jour le profil (badge, vérification,
  /// droits de monétisation) et prévient la personne par notification.
  Future<void> updateStatus({
    required OfficialAccountRequest request,
    required OfficialAccountStatus newStatus,
    required String adminId,
    String? note,
  }) =>
      AdminComplementsApi.adminOfficialDecide(request.id, newStatus, note: note);

  Future<void> requestMoreInfo({required OfficialAccountRequest request, required String adminId, required String note}) =>
      updateStatus(request: request, newStatus: OfficialAccountStatus.moreInfoNeeded, adminId: adminId, note: note);

  Future<void> startReview({required OfficialAccountRequest request, required String adminId}) =>
      updateStatus(request: request, newStatus: OfficialAccountStatus.underReview, adminId: adminId);

  // ── Mise à jour d'une demande existante (moreInfoNeeded) ──

  /// Complète la demande quand l'équipe a demandé des informations : elle repasse « en attente ». [fields] : noms de champs de l'API.
  Future<void> updateRequest({required String requestId, required String userId, required Map<String, dynamic> fields}) =>
      AdminComplementsApi.updateOfficial(requestId, fields);

  // ── Unicité du nom officiel ──

  /// `true` si le nom est disponible.
  Future<bool> isNameAvailable(String slug) async {
    if (slug.isEmpty) return false;
    return AdminComplementsApi.nameAvailable(slug);
  }

  // ── Abonnement mensuel ──

  /// Paiement de l'abonnement officiel en pièces (clé d'idempotence conservée par l'appelant). Retourne `false` si le solde est insuffisant.
  Future<bool> paySubscription(String userId, {String? idempotencyKey}) async {
    try {
      await AdminComplementsApi.paySubscription(idempotencyKey ?? ApiClient.newIdempotencyKey());
      return true;
    } on ApiException catch (e) {
      if (e.isInsufficientCoins || e.status == 402) return false;
      rethrow;
    }
  }

  /// Abonnement en cours (null si jamais payé).
  Future<OfficialSubscription?> getSubscription(String userId) async {
    final s = await AdminComplementsApi.subscription();
    if (s['next_due_at'] == null && s['last_paid_at'] == null) return null;
    int? ms(Object? v) => v is String ? DateTime.tryParse(v)?.millisecondsSinceEpoch : null;
    return OfficialSubscription.fromJson({'active': s['active'] == true, 'lastPaidAt': ms(s['last_paid_at']), 'nextDueAt': ms(s['next_due_at']), 'autoPayEnabled': false});
  }
}
