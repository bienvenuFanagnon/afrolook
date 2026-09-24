import 'package:flutter/material.dart';
import './authTest/Screens/Signup/components/signup_form.dart';
import '../regles_confidentialite_page.dart';
import '../../../theme/app_colors.dart';

/// Écran d'acceptation des CGU affiché AVANT l'inscription (Apple App Store requirement).
class EulaScreen extends StatefulWidget {
  const EulaScreen({Key? key}) : super(key: key);

  @override
  State<EulaScreen> createState() => _EulaScreenState();
}

class _EulaScreenState extends State<EulaScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Conditions d\'utilisation',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
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
                          'Avant de créer votre compte, veuillez lire et accepter nos conditions.',
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
                    title: 'Communauté et respect',
                    body: 'Afrolook est une plateforme de partage de contenu. Tout contenu haineux, violent, à caractère sexuel explicite ou illégal est strictement interdit et entraîne la suspension du compte.',
                  ),
                  _eulaSection(
                    colors,
                    icon: Icons.monetization_on_outlined,
                    title: 'Économie de pièces (Afrocoin)',
                    body: 'Les pièces achetées ou reçues peuvent être utilisées pour soutenir des créateurs et accéder à du contenu premium. Elles n\'ont pas de valeur monétaire réelle et ne peuvent pas être converties en argent par les utilisateurs.',
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
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SignUpScreen()),
                            )
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
                      'Continuer et créer mon compte',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
