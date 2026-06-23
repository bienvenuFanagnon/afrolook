import 'package:shared_preferences/shared_preferences.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/authProvider.dart';

import 'session_expired_modal.dart';

class SessionCheckerService {
  static const String TOKEN_KEY = 'token';
  static const String LAST_ACTIVE_KEY = 'last_active_timestamp';

  /// Vérifie l'état de la session et affiche la modal si expirée
  /// Retourne true si la session est valide, false si expirée
  static Future<bool> checkSessionAndShowModalIfNeeded({
    required BuildContext context,
    required UserAuthProvider authProvider,
    bool showModalIfExpired = true,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    // Si l'utilisateur Firebase est null
    if (currentUser == null) {
      printVm('🔍 [SessionChecker] Firebase Auth: utilisateur null');

      _showSessionExpiredModal(context, authProvider);

      return false;

    } else {
      // Utilisateur connecté, mettre à jour l'activité
      await _updateSessionActivity();
      printVm('✅ [SessionChecker] Session valide pour: ${currentUser.uid}');
      return true;
    }

    return false;
  }

  /// Vérification silencieuse (sans modal)
  static Future<bool> isSessionValid() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString(TOKEN_KEY);
      return storedUserId == null;
    }

    return true;
  }

  /// Nettoie la session
  static Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(TOKEN_KEY);
    await prefs.remove(LAST_ACTIVE_KEY);
    printVm('🗑️ [SessionChecker] Session effacée');
  }

  /// Met à jour l'activité
  static Future<void> _updateSessionActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(LAST_ACTIVE_KEY, DateTime.now().millisecondsSinceEpoch);
  }

  /// Affiche la modal de session expirée
  static void _showSessionExpiredModal(BuildContext context, UserAuthProvider authProvider) {
    // Éviter les doublons de modal
    if (ModalRoute.of(context)?.isCurrent != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SessionExpiredModal(
        authProvider: authProvider,
      ),
    );
  }
}