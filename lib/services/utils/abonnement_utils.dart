// utils/abonnement_utils.dart
import 'package:flutter/material.dart';

import '../../models/model_data.dart';



class AbonnementUtils {
  // Vérifier si l'utilisateur peut faire un live HD
  static bool canLiveHD(AfrolookAbonnement? abonnement) {
    return abonnement?.estPremium == true;
  }

  // Vérifier la latence autorisée
  static int getLiveLatency(AfrolookAbonnement? abonnement) {
    return abonnement?.estPremium == true ? 500 : 2000;
  }

  // Vérifier si peut poster plusieurs photos
  static bool canPostMultiplePhotos(AfrolookAbonnement? abonnement) {
    return abonnement?.estPremium == true;
  }

  // Nombre maximum de photos par look
  static int getMaxPhotosPerLook(AfrolookAbonnement? abonnement) {
    return abonnement?.estPremium == true ? 10 : 1;
  }

  // Vérifier la restriction de temps
  static bool hasTimeRestriction(AfrolookAbonnement? abonnement) {
    return abonnement?.estPremium != true;
  }

  // Temps de restriction en minutes
  static int getRestrictionTime(AfrolookAbonnement? abonnement) {
    return abonnement?.estPremium == true ? 0 : 60;
  }

  // Vérifier si peut participer aux challenges librement
  static bool canJoinChallengesFreely(AfrolookAbonnement? abonnement) {
    return abonnement?.estPremium == true;
  }

  // Vérifier si peut partager plus de texte
  static bool canShareMoreText(AfrolookAbonnement? abonnement) {
    return abonnement?.estPremium == true;
  }

  // Vérifier si peut participer aux événements sponsors
  static bool canJoinSponsorEvents(AfrolookAbonnement? abonnement) {
    return abonnement?.estPremium == true;
  }

  // Obtenir le badge utilisateur
  static Widget getUserBadge({
    required AfrolookAbonnement? abonnement,
    required bool isVerified,
    double size = 16,
  }) {
    if (abonnement?.estPremium == true) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDB813), Color(0xFFFF416C)],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(Icons.workspace_premium,
            color: Colors.white,
            size: size * 0.6),
      );
    }

    if (isVerified) {
      return Icon(Icons.verified,
          color: Colors.blue,
          size: size);
    }

    return SizedBox();
  }

  // Vérifier si l'abonnement expire bientôt
  static bool isExpiringSoon(AfrolookAbonnement? abonnement) {
    return abonnement?.expireBientot == true;
  }

  // Obtenir les jours restants - CORRECTION ICI
  static int getDaysRemaining(AfrolookAbonnement? abonnement) {
    return abonnement?.joursRestants ?? 0;
  }

  // Vérifier si l'abonnement est expiré
  static bool isExpired(AfrolookAbonnement? abonnement) {
    return abonnement?.estExpire == true;
  }

  // Vérifier si premium actif
  static bool isPremiumActive(AfrolookAbonnement? abonnement) {
    return abonnement?.estPremium == true;
  }

  // Obtenir la date de fin formatée
  static String getFormattedEndDate(AfrolookAbonnement? abonnement) {
    if (abonnement == null) return 'N/A';

    if (abonnement.type == 'gratuit') {
      return 'Illimité';
    }

    final dateFin = abonnement.dateFin;
    return '${dateFin.day}/${dateFin.month}/${dateFin.year}';
  }
}