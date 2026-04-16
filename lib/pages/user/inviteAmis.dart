import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/linkService.dart';
import 'package:provider/provider.dart';
import 'package:afrotok/providers/authProvider.dart';

/// Affiche une boîte de dialogue invitant l'utilisateur à parrainer ses amis.
/// Inspirée du design de showRemunerationAnnounceModal, avec affichage du nombre de parrainages
/// et un bouton de partage utilisant les mêmes informations que la page de profil.
///
/// [currentUser] : les données de l'utilisateur connecté (contenant id, pseudo, codeParrainage,
///                 userAbonnesIds, userlikes, imageUrl, usersParrainer, etc.)
Future<void> showInviteFriendsModal(BuildContext context, UserData currentUser) async {
  return showDialog(
    context: context,
    barrierDismissible: true, // Permet de fermer en tapant à l'extérieur
    builder: (BuildContext context) {
      return WillPopScope(
        onWillPop: () async => true, // Autorise le retour arrière
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône principale (groupe d'amis)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.group_add_rounded,
                    color: Color(0xFFFFD700),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),

                // Titre accrocheur
                const Text(
                  '👥 INVITE TES AMIS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Message principal attrayant
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Afrolook est encore plus génial avec tes amis ! 🌟',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Invite-les avec ton code parrain et profitez ensemble des avantages :',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Liste des avantages
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAdvantageChip('📈', 'Popularité'),
                          const SizedBox(width: 4),
                          _buildAdvantageChip('💰', 'Monétisation'),
                          const SizedBox(width: 4),
                          _buildAdvantageChip('🎁', 'Bonus'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Bloc code de parrainage + nombre de parrainages
                _buildReferralInfoCompact(currentUser,context),
                const SizedBox(height: 16),

                // Message d'incitation supplémentaire
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '👉 Plus tes amis sont actifs, plus ta popularité et tes revenus augmentent !',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Boutons d'action
                Row(
                  children: [
                    // Bouton "Plus tard"
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'PLUS TARD',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Bouton Partager
                    Expanded(
                      child: _ShareButton(currentUser: currentUser),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// Petit widget pour les chips d'avantages
Widget _buildAdvantageChip(String emoji, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFFFD700).withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade300,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );
}

// Bloc compact affichant le code de parrainage, le nombre de parrainages et la copie
Widget _buildReferralInfoCompact(UserData user, BuildContext context) {
  final int parrainagesCount = user.usersParrainer?.length ?? 0;
  final String referralCode = user.codeParrainage ?? "XXXXXXXX";

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.yellow.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.yellow),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Colonne gauche : code de parrainage (avec gestion de l'overflow)
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Ton code de parrainage",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                referralCode,
                style: const TextStyle(
                  color: Colors.yellow,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,  // Évite les débordements
                maxLines: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Colonne droite : total invités + bouton copier (ne se réduit pas)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Affichage du total d'invités
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_alt, color: Colors.blue, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    "Total invités : $parrainagesCount",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Bouton copier
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: referralCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copié dans le presse-papier !'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Icon(Icons.copy, color: Colors.yellow, size: 20),
            ),
          ],
        ),
      ],
    ),
  );
}
// Bouton de partage avec état de chargement
class _ShareButton extends StatefulWidget {
  final UserData currentUser;

  const _ShareButton({required this.currentUser});

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _isSharing = false;

  Future<void> _shareProfile() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final appLinkService = AppLinkService();

      // Message attractif pour inviter des amis
      final String shareMessage =
          "🚀 @${widget.currentUser.pseudo} t'invite sur Afrolook !\n"
          "👥 ${widget.currentUser.userAbonnesIds?.length ?? 0} followers, "
          "❤️ ${widget.currentUser.userlikes ?? 0} likes.\n"
          "💰 Dès 100 vues, tu es rémunéré (+25 000 FCFA/mois) !\n"
          "🎁 Utilise MON CODE à l'inscription : ${widget.currentUser.codeParrainage}\n"
          "📱 Afrolook - Le réseau social qui paie ton talent";

      await appLinkService.shareProfil(
        type: AppLinkType.profil,
        id: widget.currentUser.id!,
        message: shareMessage,
        mediaUrl: widget.currentUser.imageUrl ?? '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors du partage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isSharing ? null : _shareProfile,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFD700),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: _isSharing
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.black,
        ),
      )
          : const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.share, size: 16),
          SizedBox(width: 6),
          Text(
            'PARTAGER MON CODE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}