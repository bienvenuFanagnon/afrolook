// services/pronostic_admin_service.dart

import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/services/pronostic_payment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/providers/pronostic_provider.dart';
import 'package:flutter/cupertino.dart';

import '../models/model_data.dart';

class PronosticAdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PronosticProvider _pronosticProvider;
  final PronosticPaymentService _paymentService;

  PronosticAdminService({
    required PronosticProvider pronosticProvider,
    required PronosticPaymentService paymentService,
  })  : _pronosticProvider = pronosticProvider,
        _paymentService = paymentService;

  // DÉMARRER le match (État 1)
  Future<bool> demarrerMatch(Pronostic pronostic, UserAuthProvider authProvider) async {
    try {
      // Démarrer le match
      await _pronosticProvider.updateStatut(
          pronosticId: pronostic.id,
          nouveauStatut: PronosticStatut.EN_COURS
      );

      // Récupérer les IDs des participants
      List<String> participantsIds = pronostic.toutesParticipations
          .map((participation) => participation.userId)
          .where((userId) => userId.isNotEmpty)
          .toList();

      // Message de notification
      String message = '⚽ Le match ${pronostic.equipeA.nom} vs ${pronostic.equipeB.nom} a commencé ! Les pronostics sont maintenant fermés.';

      // Envoyer la notification à tous les participants
      if (participantsIds.isNotEmpty) {
        await authProvider.sendPushToSpecificUsers(
          userIds: participantsIds,
          sender: authProvider.loginUserData,
          message: message,
          typeNotif: NotificationType.POST.name,
          postId: pronostic.postId,
          postType: 'PRONOSTIC',
          chatId: '',
        );
      }

      print('✅ Match démarré, ${participantsIds.length} participants notifiés');
      return true;
    } catch (e) {
      print('❌ Erreur démarrage match: $e');
      return false;
    }
  }
  // TERMINER le match (État 2)
  Future<bool> terminerMatch({
    required String pronosticId,
    required int scoreA,
    required int scoreB,
  }) async {
    try {
      await _pronosticProvider.updateScoreFinal(
        pronosticId: pronosticId,
        scoreA: scoreA,
        scoreB: scoreB,
      );

      return true;
    } catch (e) {
      print('Erreur terminaison match: $e');
      return false;
    }
  }


  // Notifier les participants (optionnel)
  Future<void> _notifierParticipants(String pronosticId, String type) async {
    // Implémentez la logique de notification
    // via Firebase Cloud Messaging
  }

  // Rembourser les participants en cas d'annulation
  Future<bool> rembourserParticipants(String pronosticId) async {
    try {
      final pronostic = await _pronosticProvider.getPronosticById(pronosticId);
      if (pronostic == null) return false;

      // Logique de remboursement si nécessaire
      // Utiliser des transactions pour chaque remboursement

      return true;
    } catch (e) {
      print('Erreur remboursement: $e');
      return false;
    }
  }
}

