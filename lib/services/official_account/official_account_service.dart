import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/official_account/official_account_enums.dart';
import '../../models/official_account/official_account_request.dart';
import '../../models/model_data.dart' show TypeTransaction, OfficialSubscription;

/// Montant mensuel de l'abonnement officiel en FCFA.
const _kSubscriptionAmount = 5000.0;

/// Nom de la collection Firestore principale.
const _kCollection = 'OfficialAccountRequests';

/// Service métier pour les demandes de compte officiel.
/// Toutes les interactions avec Firestore sont centralisées ici.
class OfficialAccountService {
  OfficialAccountService._();
  static final OfficialAccountService instance = OfficialAccountService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_kCollection);

  // ── Soumission ──────────────────────────────────────────────────────────────

  /// Soumet une nouvelle demande et retourne l'ID du document créé.
  Future<String> submitRequest(OfficialAccountRequest request) async {
    final doc = _col.doc(request.id.isEmpty ? _col.doc().id : request.id);
    final data = request.toMap();
    data['id'] = doc.id;
    await doc.set(data);
    return doc.id;
  }

  // ── Lecture utilisateur ─────────────────────────────────────────────────────

  /// Demande en cours (la plus récente) pour un utilisateur.
  Future<OfficialAccountRequest?> getMyRequest(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return OfficialAccountRequest.fromMap(doc.data(), doc.id);
  }

  /// Stream temps-réel de la demande en cours d'un utilisateur.
  Stream<OfficialAccountRequest?> watchMyRequest(String userId) =>
      _col
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .map((snap) {
        if (snap.docs.isEmpty) return null;
        final doc = snap.docs.first;
        return OfficialAccountRequest.fromMap(doc.data(), doc.id);
      });

  // ── Lecture admin ───────────────────────────────────────────────────────────

  /// Stream filtré par statut (admin).
  Stream<List<OfficialAccountRequest>> watchByStatus(
          OfficialAccountStatus status) =>
      _col
          .where('status', isEqualTo: status.id)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => OfficialAccountRequest.fromMap(d.data(), d.id))
              .toList());

  /// Stream filtré par statut + catégorie (admin).
  Stream<List<OfficialAccountRequest>> watchFiltered({
    OfficialAccountStatus? status,
    OfficialAccountCategory? category,
  }) {
    Query<Map<String, dynamic>> q = _col;
    if (status != null) q = q.where('status', isEqualTo: status.id);
    if (category != null) q = q.where('category', isEqualTo: category.id);
    return q
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OfficialAccountRequest.fromMap(d.data(), d.id))
            .toList());
  }

  // ── Actions admin ───────────────────────────────────────────────────────────

  /// Change le statut d'une demande et historise l'action.
  Future<void> updateStatus({
    required OfficialAccountRequest request,
    required OfficialAccountStatus newStatus,
    required String adminId,
    String? note,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final action = OfficialAccountAction(
      action: newStatus.label,
      note: note,
      adminId: adminId,
      timestamp: now,
    );

    final updatedHistory = [...request.actionHistory, action];

    // Mise à jour de la demande
    await _col.doc(request.id).update({
      'status': newStatus.id,
      'adminNote': note ?? request.adminNote,
      'actionHistory': updatedHistory.map((a) => a.toMap()).toList(),
      'updatedAt': now,
      'processedAt': now,
      'processedBy': adminId,
    });

    // Mise à jour du profil utilisateur
    final isApproved = newStatus == OfficialAccountStatus.approved;
    final isSuspended = newStatus == OfficialAccountStatus.suspended;
    final isRejected = newStatus == OfficialAccountStatus.rejected;

    final userUpdate = <String, dynamic>{
      'officialAccountRequestId': request.id,
    };

    if (isApproved) {
      final category = request.category;
      userUpdate.addAll({
        'officialAccountType': category.id,
        'officialAccountStatus': 'approved',
        'officialBadge': true,
        'isVerify': true,
        'officialName': request.officialName,
        'officialDescription': request.description,
        'officialCountry': request.country,
        'officialCity': request.city,
        'officialWebsite': request.website,
        'broadcastDomains':
            request.broadcastDomains.map((d) => d.id).toList(),
        'officialSocialLinks':
            request.socialNetworks.map((s) => s.toMap()).toList(),
        // Monétisation
        'canMonetize': category.canMonetize,
        'canReceiveGiftCommission': category.canMonetize,
        'canDoParrainage': category.canMonetize,
        // Recherche par nom officiel
        'officialNameSlug': officialNameToSlug(request.officialName),
        'officialSearchKeywords': officialNameToKeywords(request.officialName),
      });
    } else if (isSuspended) {
      userUpdate.addAll({
        'officialAccountStatus': 'suspended',
        'officialBadge': false,
        'isVerify': false,
      });
    } else if (isRejected) {
      // On ne retire pas le badge s'il était déjà approuvé — l'admin peut changer d'avis
      userUpdate['officialAccountStatus'] = 'rejected';
    }

    await _db.collection('Users').doc(request.userId).update(userUpdate);
  }

  /// Demande des informations complémentaires (note obligatoire).
  Future<void> requestMoreInfo({
    required OfficialAccountRequest request,
    required String adminId,
    required String note,
  }) =>
      updateStatus(
        request: request,
        newStatus: OfficialAccountStatus.moreInfoNeeded,
        adminId: adminId,
        note: note,
      );

  /// Passe la demande en "En cours d'analyse".
  Future<void> startReview({
    required OfficialAccountRequest request,
    required String adminId,
  }) =>
      updateStatus(
        request: request,
        newStatus: OfficialAccountStatus.underReview,
        adminId: adminId,
      );

  // ── Mise à jour d'une demande existante (moreInfoNeeded) ───────────────────

  /// Met à jour les champs modifiables d'une demande et repasse le statut à
  /// `pending` pour que l'admin la revoie.
  Future<void> updateRequest({
    required String requestId,
    required String userId,
    required Map<String, dynamic> updatedFields,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final action = OfficialAccountAction(
      action: 'Mise à jour par l\'utilisateur',
      note: null,
      adminId: userId,
      timestamp: now,
    );

    await _col.doc(requestId).update({
      ...updatedFields,
      'status': OfficialAccountStatus.pending.id,
      'adminNote': null,
      'updatedAt': now,
      'actionHistory': FieldValue.arrayUnion([action.toMap()]),
    });
  }

  // ── Unicité du nom officiel ─────────────────────────────────────────────────

  /// Vérifie que le slug n'est pas déjà utilisé par un compte approuvé ou une
  /// demande en cours (pending / underReview / approved).
  /// Retourne `true` si le nom est disponible.
  Future<bool> isNameAvailable(String slug) async {
    if (slug.isEmpty) return false;

    // 1. Profils déjà approuvés
    final usersSnap = await _db
        .collection('Users')
        .where('officialNameSlug', isEqualTo: slug)
        .limit(1)
        .get();
    if (usersSnap.docs.isNotEmpty) return false;

    // 2. Demandes en cours
    final reqSnap = await _col
        .where('officialNameSlug', isEqualTo: slug)
        .where('status', whereIn: ['pending', 'underReview', 'approved'])
        .limit(1)
        .get();
    return reqSnap.docs.isEmpty;
  }

  // ── Abonnement mensuel ──────────────────────────────────────────────────────

  /// Prélève 5 000 FCFA sur le solde de l'utilisateur.
  ///
  /// Retourne `true` si le paiement a réussi, `false` si le solde est insuffisant.
  /// Lance une exception en cas d'erreur Firestore.
  Future<bool> paySubscription(String userId) async {
    final userRef = _db.collection('Users').doc(userId);
    final txRef = _db.collection('TransactionSoldes').doc();
    final now = DateTime.now().millisecondsSinceEpoch;

    bool success = false;

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final balance = (userSnap.data()?['votre_solde_principal'] ?? 0.0) as num;

      if (balance < _kSubscriptionAmount) {
        success = false;
        return;
      }

      final nextDue = DateTime.now().add(const Duration(days: 30));
      final sub = OfficialSubscription(
        active: true,
        lastPaidAt: DateTime.now(),
        nextDueAt: nextDue,
        autoPayEnabled: true,
      );

      // Débit solde
      tx.update(userRef, {
        'votre_solde_principal': FieldValue.increment(-_kSubscriptionAmount),
        'officialSubscription': sub.toJson(),
        'officialAccountStatus': 'approved',
        'officialBadge': true,
        'isVerify': true,
      });

      // Transaction
      tx.set(txRef, {
        'id': txRef.id,
        'user_id': userId,
        'type': TypeTransaction.ABONNEMENT_OFFICIEL.name,
        'statut': 'VALIDER',
        'description': 'Abonnement compte officiel — mensuel',
        'montant': _kSubscriptionAmount,
        'montant_total': _kSubscriptionAmount,
        'frais': 0,
        'methode_paiement': 'SOLDE',
        'numero_depot': null,
        'createdAt': now,
        'updatedAt': now,
        'reference': 'ABON_OFF_$now',
      });

      success = true;
    });

    return success;
  }

  /// Retourne l'abonnement en cours d'un utilisateur (snapshot unique).
  Future<OfficialSubscription?> getSubscription(String userId) async {
    final snap = await _db.collection('Users').doc(userId).get();
    final data = snap.data()?['officialSubscription'];
    if (data == null) return null;
    return OfficialSubscription.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ── Utilitaire ──────────────────────────────────────────────────────────────

  String newId() => _col.doc().id;
}
