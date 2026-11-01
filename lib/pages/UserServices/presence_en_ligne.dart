import 'dart:async';
import 'package:afrotok/services/api/users_api.dart';
// Présence en ligne : reste sur Firebase (décision du propriétaire). Document léger `UserPresence/{identifiant API}`, écrit par la personne elle-même.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PresenceService {
  Timer? _heartbeatTimer;
  int _lastSentTimestamp = 0;
  String? _currentUserId;

  // Réglages de confidentialité (mode fantôme, dernière connexion) recopiés dans le document de présence, relus toutes les 10 minutes
  Map<String, dynamic> _privacy = const {};
  int _privacyReadAt = 0;

  Future<void> _refreshPrivacy(int now) async {
    if (now - _privacyReadAt < 600000) return;
    try {
      final p = await UsersApi.privacy();
      _privacy = {'ghostMode': p['ghostMode'] == true, 'hideLastSeen': p['hideLastSeen'] == true};
      _privacyReadAt = now;
    } catch (_) {
      // on garde les derniers réglages connus ; nouvel essai au prochain battement
    }
  }

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
          .collection('UserPresence')
          .doc(_currentUserId)
          .set({
        'isConnected': false,
        'last_time_active': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
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

      await _refreshPrivacy(now);
      await FirebaseFirestore.instance
          .collection('UserPresence')
          .doc(_currentUserId)
          .set({
        'isConnected': true,
        'last_time_active': now,
        if (_privacy.isNotEmpty) 'privacySettings': _privacy,
      }, SetOptions(merge: true));

      // Mettre à jour le cache local du timestamp uniquement après succès de l'écriture
      _lastSentTimestamp = now;
    } catch (e) {
      debugPrint('❌ [PRESENCE SERVICE] Erreur d\'écriture présence: $e');
    }
  }
}