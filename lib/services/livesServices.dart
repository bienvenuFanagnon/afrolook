// services/live_service.dart

import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/model_data.dart';
import '../pages/LiveAgora/livesAgora.dart';

class LiveService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Vérifier si l'utilisateur peut créer un live
  Future<Map<String, dynamic>> canCreateLive() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {
          'canCreate': false,
          'message': 'Utilisateur non connecté',
        };
      }

      // Récupérer les stats de live de l'utilisateur
      final userData = userFromBootstrap(await UsersApi.bootstrap());

      // Si admin, toujours autorisé
      if (userData.role == UserRole.ADM.name) {
        return {
          'canCreate': true,
          'message': 'Mode Admin',
          'isAdmin': true,
          'remainingLives': 999,
          'quality': 'HD',
          'latency': 500,
        };
      }

      // Vérifier les stats de live
      final liveStats = userData.liveStats ?? LiveStats.defaultForUser(userId);

      // Vérifier si premium actif
      final isPremiumActive = userData.abonnement?.estPremium == true;

      // Mettre à jour les stats si premium
      if (isPremiumActive && !liveStats.isPremium) {
        liveStats.updateForPremium(premium: true);
      }

      // Vérifier si peut créer un live
      final canCreate = liveStats.canCreateLive() || isPremiumActive;

      return {
        'canCreate': canCreate,
        'message': canCreate ? 'Autorisé' : 'Limite de lives atteinte',
        'remainingLives': isPremiumActive ? 999 : liveStats.remainingLives,
        'totalLivesThisMonth': liveStats.monthlyLiveCount,
        'maxLives': liveStats.maxMonthlyLives,
        'isPremium': isPremiumActive,
        'quality': isPremiumActive ? 'HD' : 'SD',
        'latency': isPremiumActive ? 500 : 2000,
        'canChooseHD': isPremiumActive,
      };

    } catch (e) {
      printVm('Erreur vérification live: $e');
      return {
        'canCreate': false,
        'message': 'Erreur de vérification',
      };
    }
  }

  // Le compteur de lives est tenu par l'API (un live est enregistré par POST /v1/lives) : rien à écrire côté application
  Future<void> incrementLiveCount() async {}

  // Obtenir les restrictions de live
  Future<Map<String, dynamic>> getLiveRestrictions() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return _getDefaultRestrictions(false);
      }

      final userData = userFromBootstrap(await UsersApi.bootstrap());

      // Si admin, toutes les fonctionnalités
      if (userData.role == UserRole.ADM.name) {
        return {
          'maxMonthlyLives': 999,
          'latency': 500,
          'quality': 'HD',
          'bitrate': 4000,
          'resolution': '1080p',
          'canChooseHD': true,
          'canChooseLowLatency': true,
          'isPremium': true,
          'isAdmin': true,
          'remainingLives': 999,
          'totalLivesThisMonth': 0,
          'maxLives': 999,
        };
      }

      // Vérifier abonnement premium
      final isPremiumActive = userData.abonnement?.estPremium == true;
      final liveStats = userData.liveStats ?? LiveStats.defaultForUser(userId);

      if (isPremiumActive) {
        return {
          'maxMonthlyLives': 999,
          'latency': 500,
          'quality': 'HD',
          'bitrate': 4000,
          'resolution': '720p',
          'canChooseHD': true,
          'canChooseLowLatency': true,
          'isPremium': true,
          'isAdmin': false,
          'remainingLives': 999,
          'totalLivesThisMonth': liveStats.monthlyLiveCount,
          'maxLives': 999,
        };
      } else {
        return {
          'maxMonthlyLives': 5,
          'latency': 2000,
          'quality': 'SD',
          'bitrate': 1000,
          'resolution': '480p',
          'canChooseHD': false,
          'canChooseLowLatency': false,
          'isPremium': false,
          'isAdmin': false,
          'remainingLives': liveStats.remainingLives,
          'totalLivesThisMonth': liveStats.monthlyLiveCount,
          'maxLives': 5,
        };
      }

    } catch (e) {
      printVm('Erreur restrictions live: $e');
      return _getDefaultRestrictions(false);
    }
  }

  Map<String, dynamic> _getDefaultRestrictions(bool isPremium) {
    if (isPremium) {
      return {
        'maxMonthlyLives': 999,
        'latency': 500,
        'quality': 'HD',
        'bitrate': 4000,
        'resolution': '720p',
        'canChooseHD': true,
        'canChooseLowLatency': true,
        'isPremium': true,
        'remainingLives': 999,
      };
    } else {
      return {
        'maxMonthlyLives': 5,
        'latency': 2000,
        'quality': 'SD',
        'bitrate': 1000,
        'resolution': '480p',
        'canChooseHD': false,
        'canChooseLowLatency': false,
        'isPremium': false,
        'remainingLives': 5,
      };
    }
  }
}