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

  static const _personalOfficialTypes = {
    'influencer', 'artist', 'publicFigure', 'entrepreneur'
  };
  static const _institutionalOfficialTypes = {
    'company', 'stateInstitution', 'media', 'journalist', 'ngo', 'association', 'other'
  };

  // Obtenir le badge utilisateur — source unique pour toute l'app
  // Priorité : isVerify > officialBadge (personnel = orange, institutionnel = bleu carré) > premium (or)
  static Widget getUserBadge({
    AfrolookAbonnement? abonnement,
    required bool isVerified,
    bool officialBadge = false,
    String? officialAccountType,
    bool? isPremiumOverride,
    double size = 16,
    bool withBackground = false,
  }) {
    final isPremium = isPremiumOverride ?? abonnement?.estPremium == true;

    Widget? badge;

    // 1. Badge bleu admin : utilisateur vérifié par l'administrateur
    if (isVerified) {
      badge = Icon(Icons.verified, color: Colors.blue, size: size);
    }
    // 2. Badge orange cercle : compte officiel personnel (influenceur, artiste…)
    else if (officialBadge && _personalOfficialTypes.contains(officialAccountType)) {
      badge = Icon(Icons.verified, color: Colors.orange, size: size);
    }
    // 3. Badge bleu carré : compte officiel institutionnel (entreprise, média…)
    else if (officialBadge && _institutionalOfficialTypes.contains(officialAccountType)) {
      badge = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: Icon(Icons.verified, color: Colors.white, size: size * 0.75),
      );
    }
    // 4. Badge or : utilisateur premium (sans badge officiel)
    else if (isPremium) {
      badge = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFDB813), Color(0xFFFF416C)],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(Icons.workspace_premium, color: Colors.white, size: size * 0.6),
      );
    }

    if (badge == null) return const SizedBox.shrink();

    if (!withBackground) return badge;

    // Fond rond blanc derrière le badge
    return Container(
      width: size + 6,
      height: size + 6,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(child: badge),
    );
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