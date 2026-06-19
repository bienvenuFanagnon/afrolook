import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';

class UserPresenceWidget extends StatelessWidget {
  final String userId;
  final double size; // Permet de contrôler la taille du point vert
  final bool showTextStatus; // Permet de choisir si on affiche le texte "En ligne / Il y a..." ou juste le point vert
  final bool isChatHeader;
  const UserPresenceWidget({
    Key? key,
    required this.userId,
    this.size = 10.0,
    this.showTextStatus = false,
    this.isChatHeader = false,
  }) : super(key: key);

  // Fonction logique qui détermine si l'utilisateur est réellement en ligne
  bool _isReallyOnline(Map<String, dynamic> data) {
    final bool isConnected = data['isConnected'] ?? false;
    final int lastTimeActive = data['last_time_active'] ?? 0;
    final int now = DateTime.now().millisecondsSinceEpoch;

    // Seuil de 3 minutes (3 * 60 * 1000 ms)
    const int troisMinutesEnMs = 180000;
    final int difference = now - lastTimeActive;
    final bool isUnderThreshold = difference < troisMinutesEnMs;

    // 🟢 LOG DE CALCUL DE PRÉSENCE
    debugPrint('📊 [PRESENCE CALC] User ID: $userId');
    debugPrint('   -> isConnected (Firestore): $isConnected');
    debugPrint('   -> Last Active Timestamp: $lastTimeActive');
    debugPrint('   -> Décalage actuel: ${difference / 1000} secondes (Limite: 180s)');
    debugPrint('   -> Résultat final En Ligne: ${isConnected && isUnderThreshold}');

    if (!isConnected) return false;
    return isUnderThreshold;
  }

  // Fonction pour formater le texte du dernier hors-ligne
  String _formatLastActiveText(int lastTimeActive) {
    if (lastTimeActive == 0) return "Hors ligne";

    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(lastTimeActive);
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return "En ligne il y a quelques secondes";
    } else if (difference.inMinutes < 60) {
      return "En ligne il y a ${difference.inMinutes} min";
    } else if (difference.inHours < 24) {
      return "En ligne il y a ${difference.inHours} h";
    } else if (difference.inDays < 7) {
      return "En ligne il y a ${difference.inDays} j";
    } else {
      return "En ligne le ${DateFormat('dd/MM/yyyy').format(dateTime)}";
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🟡 LOG AU MOMENT DU CONSTRUCTEUR D'INTERFACE
    debugPrint('🔄 [PRESENCE WIDGET] Initialisation du Stream pour l\'utilisateur: $userId');

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        // En cas d'erreur sur le flux
        if (snapshot.hasError) {
          debugPrint('❌ [PRESENCE STREAM ERROR] Erreur pour l\'utilisateur $userId: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        // Pendant l'attente du premier signal de données
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('⏳ [PRESENCE STREAM] En attente des données de Firestore pour $userId...');
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          debugPrint('⚠️ [PRESENCE STREAM] Document inexistant ou vide sur Firestore pour l\'ID: $userId');
          return const SizedBox.shrink();
        }

        // Extraction des données réelles
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) {
          debugPrint('⚠️ [PRESENCE STREAM] Les données du document sont nulles pour $userId');
          return const SizedBox.shrink();
        }

        // Paramètres de confidentialité Premium de l'utilisateur affiché
        final privacySettings = (data['privacySettings'] as Map<String, dynamic>?) ?? {};
        final bool ghostMode     = privacySettings['ghostMode']     == true;
        final bool hideLastSeen  = privacySettings['hideLastSeen']  == true;

        // ghostMode → cet utilisateur choisit d'apparaître hors ligne
        final bool effectiveOnline = ghostMode ? false : _isReallyOnline(data);
        final int lastActive = data['last_time_active'] ?? 0;

        // hideLastSeen → ne pas révéler l'heure de dernière connexion
        final String lastSeenText = hideLastSeen ? '—' : _formatLastActiveText(lastActive);

        // 🔵 LOG À CHAQUE CHANGEMENT REÇU EN TEMPS RÉEL
        debugPrint('🔔 [PRESENCE UPDATE] $userId -> online=$effectiveOnline ghost=$ghostMode hideLastSeen=$hideLastSeen');

        // Si on veut afficher uniquement le point vert (Ex: sur la photo de profil)
        if (!showTextStatus) {
          return effectiveOnline
              ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366), // Vert WhatsApp
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1.5), // Effet de contour net
            ),
          )
              : const SizedBox.shrink();
        }

        if (isChatHeader) {
          final colors = AppColors.of(context);
          return Text(
            effectiveOnline ? "En ligne" : lastSeenText,
            style: TextStyle(
              color: effectiveOnline
                  ? const Color(0xFF25D366)
                  : colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          );
        }

        // Si on veut afficher le point vert ET le texte d'état (Ex: dans une discussion ou profil complet)
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (effectiveOnline) ...[
              Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: Color(0xFF25D366),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    effectiveOnline ? " En ligne" : lastSeenText,
                    style: TextStyle(
                      color: effectiveOnline ? const Color(0xFF25D366) : Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}