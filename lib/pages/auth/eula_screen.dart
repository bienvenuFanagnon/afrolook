import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './authTest/Screens/Signup/components/signup_form.dart';
import '../regles_confidentialite_page.dart';
import '../../../theme/app_colors.dart';

/// Règle App Store 1.2 : les conditions doivent être acceptées avant l'inscription ET la connexion.
/// Appelé à l'ouverture des écrans de connexion et d'inscription : si elles n'ont pas encore été
/// acceptées sur cet appareil, l'EULA s'ouvre par-dessus et ne peut pas être fermée sans accepter.
class EulaGate {
  static const _prefKey = 'eula_accepted_v2';

  static Future<bool> isAccepted() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markAccepted() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_prefKey, true);
    } catch (_) {}
  }

  static Future<void> ensureAccepted(BuildContext context) async {
    if (await isAccepted() || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const EulaScreen(asGate: true),
    ));
  }
}

/// Écran d'acceptation des CGU (EULA).
/// [asGate] : ouvert par [EulaGate], sans retour possible ; sinon ouvert avant l'inscription.
class EulaScreen extends StatefulWidget {
  final bool asGate;
  const EulaScreen({Key? key, this.asGate = false}) : super(key: key);

  @override
  State<EulaScreen> createState() => _EulaScreenState();
}

class _EulaScreenState extends State<EulaScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return PopScope(
      canPop: !widget.asGate,
      child: Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.asGate,
        title: Text(
          'Conditions d\'utilisation',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        leading: widget.asGate
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colors.divider),
        ),
      ),
      body: Column(
        children: [
          // ── Contenu scrollable ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo / Titre
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('🌍', style: const TextStyle(fontSize: 36)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bienvenue sur Afrolook',
                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Avant de vous connecter ou de créer un compte, veuillez lire et accepter nos conditions.',
                          style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Points essentiels
                  _eulaSection(
                    colors,
                    icon: Icons.people_outline,
                    title: 'Tolérance zéro',
                    body: 'Afrolook applique une tolérance zéro envers les contenus répréhensibles (haineux, violents, à caractère sexuel explicite, harcèlement, arnaques ou contenus illégaux) et envers les utilisateurs abusifs. Tout manquement entraîne la suppression du contenu et l\'exclusion définitive de son auteur.',
                  ),
                  _eulaSection(
                    colors,
                    icon: Icons.flag_outlined,
                    title: 'Signaler et bloquer',
                    body: 'Chaque publication peut être signalée, et chaque utilisateur peut être bloqué : ses contenus disparaissent alors immédiatement de votre fil et notre équipe est prévenue.',
                  ),
                  _eulaSection(
                    colors,
                    icon: Icons.gavel_outlined,
                    title: 'Modération sous 24 heures',
                    body: 'Notre équipe examine chaque signalement dans un délai de 24 heures : le contenu répréhensible est supprimé et l\'utilisateur qui l\'a publié est exclu de la plateforme.',
                  ),
                  _eulaSection(
                    colors,
                    icon: Icons.monetization_on_outlined,
                    title: 'Économie de pièces (Afrocoin)',
                    body: 'Les pièces servent à soutenir les créateurs (cadeaux, votes, DÉFI) et à accéder aux contenus et options premium. Les pièces achetées ne sont ni remboursables ni convertibles en argent. Seules les pièces gagnées (cadeaux reçus, récompenses, gains de DÉFI) peuvent être converties.',
                  ),
                  _eulaSection(
                    colors,
                    icon: Icons.copyright_outlined,
                    title: 'Propriété intellectuelle',
                    body: 'Vous conservez tous les droits sur votre contenu. En le publiant sur Afrolook, vous accordez une licence d\'utilisation limitée à la plateforme pour diffuser ce contenu.',
                  ),
                  _eulaSection(
                    colors,
                    icon: Icons.lock_outline,
                    title: 'Vie privée',
                    body: 'Vos données personnelles sont traitées conformément à notre politique de confidentialité. Nous ne revendons jamais vos données à des tiers.',
                  ),
                  _eulaSection(
                    colors,
                    icon: Icons.person_off_outlined,
                    title: 'Suppression de compte',
                    body: 'Vous pouvez supprimer votre compte à tout moment depuis les paramètres de l\'application. La suppression est définitive et irréversible.',
                  ),

                  // Lien vers CGU complètes
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReglesConfidentialitePage()),
                      ),
                      icon: Icon(Icons.open_in_new, size: 16, color: colors.primary),
                      label: Text(
                        'Lire les règles & conditions complètes',
                        style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Bas fixe : case + bouton ──────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Case à cocher
                InkWell(
                  onTap: () => setState(() => _accepted = !_accepted),
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _accepted,
                        activeColor: colors.primary,
                        onChanged: (v) => setState(() => _accepted = v ?? false),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'J\'ai lu et j\'accepte les conditions d\'utilisation et la politique de confidentialité d\'Afrolook.',
                            style: TextStyle(color: colors.textPrimary, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Bouton continuer
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _accepted
                        ? () async {
                            await EulaGate.markAccepted();
                            if (!context.mounted) return;
                            if (widget.asGate) {
                              Navigator.pop(context, true);
                            } else {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => SignUpScreen()));
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      disabledBackgroundColor: colors.surfaceVariant,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      widget.asGate ? 'Accepter et continuer' : 'Continuer et créer mon compte',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _eulaSection(AppColors colors, {required IconData icon, required String title, required String body}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
