import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Couleurs
final Color _primaryColor = Color(0xFFE21221);
final Color _secondaryColor = Color(0xFFFFD600);
final Color _backgroundColor = Color(0xFF121212);
final Color _cardColor = Color(0xFF1E1E1E);
final Color _textColor = Colors.white;
final Color _hintColor = Colors.grey[400]!;
final Color _successColor = Color(0xFF4CAF50);
final Color _audioColor = Color(0xFF2196F3);
final String appId = 'XgkSxKc10vWsJJ2uBraT';

const _kPlayStoreUrl = 'https://play.google.com/store/apps/details?id=com.afrotok.afrotok';
const _kPrefNeverShow  = 'install_modal_never_show';
const _kPrefLastShown  = 'install_modal_last_shown';

Future<void> showInstallModal(BuildContext context) async {
  if (!kIsWeb) return;

  final prefs = await SharedPreferences.getInstance();

  // Ne plus jamais afficher si l'utilisateur a coché "Ne plus afficher"
  if (prefs.getBool(_kPrefNeverShow) ?? false) return;

  // Afficher max 1 fois par jour
  final lastShown = prefs.getString(_kPrefLastShown);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  if (lastShown == today) return;

  await prefs.setString(_kPrefLastShown, today);

  if (!context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.75),
    builder: (ctx) => _InstallAppModal(prefs: prefs),
  );
}

class _InstallAppModal extends StatefulWidget {
  final SharedPreferences prefs;
  const _InstallAppModal({required this.prefs});

  @override
  State<_InstallAppModal> createState() => _InstallAppModalState();
}

class _InstallAppModalState extends State<_InstallAppModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openPlayStore() async {
    final uri = Uri.parse(_kPlayStoreUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _neverShow() async {
    await widget.prefs.setBool(_kPrefNeverShow, true);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE21221).withOpacity(0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE21221).withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Barre rouge supérieure + bouton fermer ──────────────────
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Container(
                    height: 4,
                    color: const Color(0xFFE21221),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white54, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Logo ────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Image.asset(
                    'assets/logo/afrolook_logo.png',
                    width: 72,
                    height: 72,
                  ),
                ),

                // ── Titre ───────────────────────────────────────────────────
                const Text(
                  'Afrolook',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'Vis l\'expérience Afrolook pleinement sur mobile — plus rapide, plus fluide.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.65),
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Boutons stores ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Google Play
                      GestureDetector(
                        onTap: _openPlayStore,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A8F3C),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1A8F3C).withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/logo/afrolook_logo.png',
                                width: 24,
                                height: 24,
                                color: Colors.white,
                                colorBlendMode: BlendMode.srcIn,
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Disponible sur',
                                    style: TextStyle(fontSize: 10, color: Colors.white70),
                                  ),
                                  Text(
                                    'Google Play',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white60, size: 14),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Apple Store — bientôt
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.apple, color: Colors.white38, size: 26),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bientôt sur',
                                  style: TextStyle(fontSize: 10, color: Colors.white38),
                                ),
                                Text(
                                  'App Store',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white.withOpacity(0.3),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD600).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFFD600).withOpacity(0.3)),
                              ),
                              child: const Text(
                                'Bientôt',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFD600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Actions secondaires ─────────────────────────────────────
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _neverShow,
                        child: Text(
                          'Ne plus afficher',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.35),
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withOpacity(0.2),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Plus tard',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE21221),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



// ========== MODAL POUR FONCTIONNALITÉS NON DISPONIBLES SUR WEB ==========

void showWebUnavailableModal(BuildContext context,String feature) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: _primaryColor.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header avec icône
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: _primaryColor,
                        size: 30,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fonctionnalité non disponible',
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Version Web',
                            style: TextStyle(
                              color: _hintColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Contenu
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Icône spécifique à la fonctionnalité
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900]!,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getFeatureIcon(feature),
                            color: _primaryColor,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            feature,
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Message d'explication
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900]!.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Cette fonctionnalité nécessite l\'accès au matériel du téléphone et n\'est pas disponible sur la version Web.',
                                  style: TextStyle(
                                    color: _hintColor,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_android,
                                color: Colors.green,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_right_alt,
                                color: _hintColor,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.computer,
                                color: _primaryColor.withOpacity(0.5),
                                size: 24,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Alternative
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: _secondaryColor,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Utilisez l\'application mobile pour accéder à toutes les fonctionnalités.',
                              style: TextStyle(
                                color: _secondaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Boutons
              Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _hintColor,
                          side: BorderSide(color: Colors.grey[700]!),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'FERMER',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
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
    },
  );
}

// Helper pour obtenir l'icône selon la fonctionnalité
IconData _getFeatureIcon(String feature) {
  switch (feature) {
    case 'Enregistrement audio':
      return Icons.mic;
    case 'Import audio':
      return Icons.audio_file;
    case 'Image de couverture':
      return Icons.image;
    case 'Sélection des pays':
      return Icons.public;
    default:
      return Icons.warning;
  }
}



class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({
    Key? key,
    required this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          /// Bouton fermer
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


Widget buildTotalInteractions({
  required int totalCount,
  Color color = const Color(0xFFFFD700), // Jaune par défaut
  double iconSize = 15,
  double fontSize = 10,
  bool showLabel = true,
}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.grey[900]!.withOpacity(0.8),
          Colors.grey[850]!.withOpacity(0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icône d'interactions
        Icon(
          Icons.bar_chart, // Icône représentant les interactions
          size: iconSize,
          color: color,
        ),

        SizedBox(width: 2),

        // Texte "interactions"
        if (showLabel) ...[
          Text(
            'interactions',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize ,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(width: 8),
        ],

        // Valeur
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            formatCount(totalCount),
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildTotalVues({
  required int totalCount,
  Color color = const Color(0xFFFFD700), // Jaune par défaut
  double iconSize = 15,
  double fontSize = 10,
  bool showLabel = true,
}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.grey[900]!.withOpacity(0.8),
          Colors.grey[850]!.withOpacity(0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icône d'interactions
        Icon(
          Icons.remove_red_eye, // Icône représentant les interactions
          size: iconSize,
          color: color,
        ),

        SizedBox(width: 2),

        // Texte "interactions"
        if (showLabel) ...[
          Text(
            'interactions',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize ,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(width: 8),
        ],

        // Valeur
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            formatCount(totalCount),
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
String formatCount(int count) {
  if (count < 1000) return count.toString();
  if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
  return '${(count / 1000000).toStringAsFixed(1)}M';
}