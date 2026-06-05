import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PresenceService {
  Timer? _heartbeatTimer;
  int _lastSentTimestamp = 0;
  String? _currentUserId;

  // Démarre le battement de cœur
  void startHeartbeat(String userId) {
    if (_heartbeatTimer != null && _currentUserId == userId) return;

    _currentUserId = userId;
    // On coupe l'ancien timer si existant
    stopHeartbeat();

    debugPrint('🚀 [PRESENCE SERVICE] Démarrage du Heartbeat pour l\'utilisateur : $userId');

    // Mettre à jour immédiatement dès l'activation
    _sendPresenceToFirestore();

    // Exécuter un check toutes les 2 minutes (120 secondes)
    // On choisit 2 minutes pour rester bien en dessous du seuil de déconnexion de 3 minutes
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _sendPresenceToFirestore();
    });
  }

  // Arrête le battement de cœur (très important quand l'app passe en arrière-plan)
  void stopHeartbeat() {
    if (_heartbeatTimer != null) {
      debugPrint('🛑 [PRESENCE SERVICE] Arrêt du Heartbeat');
      _heartbeatTimer!.cancel();
      _heartbeatTimer = null;
    }
  }

  // Force l'état hors ligne (AppLifecycleState.paused)
  Future<void> setForceOffline() async {
    stopHeartbeat();
    if (_currentUserId == null) return;

    try {
      debugPrint('🔴 [PRESENCE SERVICE] Envoi de l\'état OFFLINE à Firestore...');
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(_currentUserId)
          .update({
        'isConnected': false,
        'last_time_active': DateTime.now().millisecondsSinceEpoch,
      });
      // Réinitialiser le cache local
      _lastSentTimestamp = 0;
    } catch (e) {
      debugPrint('❌ [PRESENCE SERVICE] Erreur lors de la mise hors ligne: $e');
    }
  }

  // Envoi effectif à Firestore avec contrôle budgétaire
  Future<void> _sendPresenceToFirestore() async {
    if (_currentUserId == null) return;

    final int now = DateTime.now().millisecondsSinceEpoch;

    // CONTRÔLE ANTI-GASPILLAGE DE CRÉDITS FIREBASE :
    // Si la dernière écriture réussie a moins de 1 minute et 50 secondes, on n'écrit rien.
    if (now - _lastSentTimestamp < 110000) {
      debugPrint('🛡️ [PRESENCE SERVICE] Écriture annulée : Économie Firebase (Dernier envoi trop récent)');
      return;
    }

    try {
      debugPrint('📡 [PRESENCE SERVICE] Écriture Firestore : Toujours en ligne !');

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(_currentUserId)
          .update({
        'isConnected': true,
        'last_time_active': now,
      });

      // Mettre à jour le cache local du timestamp uniquement après succès de l'écriture
      _lastSentTimestamp = now;
    } catch (e) {
      debugPrint('❌ [PRESENCE SERVICE] Erreur d\'écriture présence: $e');
    }
  }
}