import 'dart:async';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

class InactiveUserReminderService {
  static const int DAYS_INACTIVE_THRESHOLD = 3;
  static const int MAX_EMAILS_PER_MONTH = 2;

  // Constantes pour les conversions
  static const int ONE_DAY_IN_MILLISECONDS = 24 * 60 * 60 * 1000; // 86,400,000 ms
  static const int ONE_DAY_IN_MICROSECONDS = ONE_DAY_IN_MILLISECONDS * 1000; // 86,400,000,000 μs
  static const int MAX_REASONABLE_DAYS = 500; // Si >500 jours, c'est probablement en microsecondes

  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static bool _isProcessing = false;
  static DateTime? _lastProcessDate;

  /// Appelée lors de la connexion de l'utilisateur
  /// S'exécute en arrière-plan sans bloquer l'UI
  static Future<void> checkAndNotifyInactiveUsers() async {
    // Éviter les appels multiples simultanés
    if (_isProcessing) {
      debugPrint('📧 Traitement déjà en cours, ignoré');
      return;
    }

    // Limiter à une fois par jour maximum
    final now = DateTime.now();
    if (_lastProcessDate != null &&
        now.difference(_lastProcessDate!).inHours < 24) {
      debugPrint('📧 Dernier traitement il y a moins de 24h, ignoré');
      return;
    }

    _isProcessing = true;
    _lastProcessDate = now;

    try {
      debugPrint('📧 Début traitement utilisateurs inactifs en arrière-plan');

      // Appel asynchrone sans attendre (fire-and-forget)
      unawaited(_callCloudFunction());
    } catch (e) {
      debugPrint('❌ Erreur lors du lancement: $e');
      _isProcessing = false;
    }
  }

  static Future<void> _callCloudFunction() async {
    try {
      final callable = _functions.httpsCallable('processInactiveUsersReminder');
      final result = await callable.call();

      if (kDebugMode) {
        debugPrint('📧 Résultat: ${result.data}');
      }
    } catch (e) {
      debugPrint('❌ Erreur Cloud Function: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Détecte automatiquement si le timestamp est en millisecondes ou microsecondes
  /// et retourne le nombre de jours d'inactivité
  static int calculateDaysInactive(int lastTimeActive) {
    if (lastTimeActive == 0) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Vérifier si le timestamp semble être en microsecondes
    // Si la valeur est très grande (>= 1e12) ou si le calcul donne plus de 500 jours
    final bool seemsMicroseconds =
        lastTimeActive > 1000000000000 || // > 1e12 (an 33658 en ms)
            (now - (lastTimeActive ~/ 1000)).abs() < (now - lastTimeActive).abs();

    int diffMillis;
    if (seemsMicroseconds) {
      // Convertir microsecondes en millisecondes
      final lastTimeActiveMillis = lastTimeActive ~/ 1000;
      diffMillis = now - lastTimeActiveMillis;
    } else {
      diffMillis = now - lastTimeActive;
    }

    // Calculer les jours
    int daysInactive = (diffMillis / ONE_DAY_IN_MILLISECONDS).floor();

    // Si le résultat est anormal (>500 jours), réessayer avec l'autre format
    if (daysInactive > MAX_REASONABLE_DAYS) {
      // Tenter l'autre format
      if (seemsMicroseconds) {
        // On était en μs, essayer en ms
        diffMillis = now - lastTimeActive;
      } else {
        // On était en ms, essayer en μs
        final lastTimeActiveMicros = lastTimeActive * 1000;
        diffMillis = now - (lastTimeActiveMicros ~/ 1000);
      }
      daysInactive = (diffMillis / ONE_DAY_IN_MILLISECONDS).floor();
    }

    return daysInactive < 0 ? 0 : daysInactive;
  }

  /// Vérifie si l'utilisateur est inactif (3+ jours)
  static Future<bool> isUserInactive(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final lastTimeActive = userData['last_time_active'] ?? 0;

      final daysInactive = calculateDaysInactive(lastTimeActive);
      final isInactive = daysInactive >= DAYS_INACTIVE_THRESHOLD && lastTimeActive > 0;

      printVm('📊 isUserInactive: userId=$userId, daysInactive=$daysInactive, isInactive=$isInactive');

      return isInactive;
    } catch (e) {
      printVm('Erreur isUserInactive: $e');
      return false;
    }
  }

  /// Vérifie si l'utilisateur a encore droit à un email ce mois-ci
  static Future<bool> canReceiveReminder(String userId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfMonthTimestamp = startOfMonth.millisecondsSinceEpoch;

      final remindersSnapshot = await FirebaseFirestore.instance
          .collection('user_email_reminders')
          .where('userId', isEqualTo: userId)
          .where('sentAt', isGreaterThanOrEqualTo: startOfMonthTimestamp)
          .count()
          .get();

      final count = remindersSnapshot.count ?? 0;
      final canReceive = count < MAX_EMAILS_PER_MONTH;

      printVm('📧 canReceiveReminder: userId=$userId, count=$count, canReceive=$canReceive');

      return canReceive;
    } catch (e) {
      printVm('Erreur canReceiveReminder: $e');
      return false;
    }
  }

  /// Récupère toutes les données utilisateur nécessaires pour l'email
  static Future<Map<String, dynamic>?> getUserEmailData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return null;

      final data = userDoc.data()!;
      final lastTimeActive = data['last_time_active'] ?? 0;
      final daysInactive = calculateDaysInactive(lastTimeActive);

      // Compter les nouvelles interactions sur ses posts (7 derniers jours)
      final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch;
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('Posts')
          .where('user_id', isEqualTo: userId)
          .get();

      int newLikesCount = 0;
      for (var postDoc in postsSnapshot.docs) {
        final post = postDoc.data();
        final postCreatedAt = post['created_at'] ?? 0;

        // Vérifier si le timestamp du post est en millisecondes ou microsecondes
        int postCreatedAtMillis = postCreatedAt;
        if (postCreatedAt > 1000000000000) {
          postCreatedAtMillis = postCreatedAt ~/ 1000;
        }

        if (postCreatedAtMillis > sevenDaysAgo) {
          newLikesCount += (post['loves'] as int? ?? 0);
        }
      }

      return {
        'userId': userId,
        'userEmail': data['email'] ?? '',
        'userName': data['pseudo'] ?? data['fullName'] ?? 'Utilisateur',
        'pseudo': data['pseudo'] ?? 'user',
        'giftCoinsBalance': data['giftCoinsBalance'] ?? 0,
        'soldePrincipal': data['votre_solde_principal'] ?? 0,
        'totalCoinsEarned': data['totalCoinsEarnedFromLikes'] ?? 0,
        'totalLikesReceived': data['totalLikesReceived'] ?? 0,
        'totalFollowers': (data['userAbonnesIds'] as List?)?.length ?? 0,
        'daysInactive': daysInactive,
        'newLikesOnMyPosts': newLikesCount,
        'newCommentsOnMyPosts': 0,
        'profileImage': data['imageUrl'] ?? '',
        'raw_last_time_active': lastTimeActive, // Pour débogage
      };
    } catch (e) {
      printVm('Erreur getUserEmailData: $e');
      return null;
    }
  }

  /// Fonction utilitaire pour nettoyer les anciens timestamps (optionnel)
  /// Convertit tous les timestamps en millisecondes pour uniformiser
  static Future<void> migrateTimestampsToMilliseconds() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .get();

      int updatedCount = 0;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final lastTimeActive = data['last_time_active'] ?? 0;

        if (lastTimeActive > 1000000000000) {
          // Convertir microsecondes en millisecondes
          final newTimestamp = lastTimeActive ~/ 1000;
          await doc.reference.update({
            'last_time_active': newTimestamp,
            'last_time_active_updated_at': FieldValue.serverTimestamp(),
          });
          updatedCount++;
          printVm('✅ Migration userId ${doc.id}: $lastTimeActive → $newTimestamp');
        }
      }

      printVm('📊 Migration terminée: $updatedCount utilisateurs mis à jour');
    } catch (e) {
      printVm('Erreur migration: $e');
    }
  }
}