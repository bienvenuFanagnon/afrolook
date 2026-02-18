// import 'dart:js' as js;
// import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

// Couleurs
final Color _primaryColor = Color(0xFFE21221);
final Color _secondaryColor = Color(0xFFFFD600);
final Color _backgroundColor = Color(0xFF121212);
final Color _cardColor = Color(0xFF1E1E1E);
final Color _textColor = Colors.white;
final Color _hintColor = Colors.grey[400]!;
final Color _successColor = Color(0xFF4CAF50);
final Color _audioColor = Color(0xFF2196F3);

Future<void> showInstallModal(BuildContext context) async {
  // if (!kIsWeb) return;
  //
  // final prefs = await SharedPreferences.getInstance();
  //
  // // 1. Vérifier si l'utilisateur a demandé de ne plus voir le modal
  // bool hideModal = prefs.getBool('hide_install_modal') ?? false;
  //
  // // 2. Vérifier si l'app est DÉJÀ lancée en tant que PWA (installée)
  // // On vérifie si le média query 'display-mode: standalone' est actif
  // bool isInstalled = html.window.matchMedia('(display-mode: standalone)').matches;
  //
  // if (hideModal || isInstalled) {
  //   print("PWA: Modal masqué (Déjà installé ou refusé)");
  //   return;
  // }
  //
  // // Affichage du modal
  // showDialog(
  //   context: context,
  //   barrierDismissible: false, // Force une action
  //   builder: (BuildContext context) {
  //     return Dialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  //       backgroundColor: Colors.transparent,
  //       child: Container(
  //         padding: const EdgeInsets.all(20),
  //         decoration: BoxDecoration(
  //           color: const Color(0xFF1A1A1A),
  //           borderRadius: BorderRadius.circular(20),
  //           border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
  //         ),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Container(
  //               padding: const EdgeInsets.all(15),
  //               decoration: const BoxDecoration(
  //                 color: Color(0xFFE53935),
  //                 shape: BoxShape.circle,
  //               ),
  //               child: const Icon(Icons.add_to_home_screen_rounded, color: Colors.white, size: 40),
  //             ),
  //             const SizedBox(height: 20),
  //             const Text(
  //               "Installe Afrolook",
  //               style: TextStyle(color: Color(0xFFFFD700), fontSize: 22, fontWeight: FontWeight.bold),
  //             ),
  //             const SizedBox(height: 10),
  //             const Text(
  //               "Accède à ton réseau social préféré plus rapidement et sans passer par le navigateur.",
  //               textAlign: TextAlign.center,
  //               style: TextStyle(color: Colors.white70, fontSize: 14),
  //             ),
  //             const SizedBox(height: 25),
  //             // BOUTON INSTALLER
  //             SizedBox(
  //               width: double.infinity,
  //               child: ElevatedButton(
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: const Color(0xFFE53935),
  //                   foregroundColor: Colors.white,
  //                   padding: const EdgeInsets.symmetric(vertical: 15),
  //                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //                 ),
  //                 onPressed: () async {
  //                   js.context.callMethod('installPWA');
  //                   // On enregistre qu'il a essayé d'installer pour ne plus le harceler
  //                   await prefs.setBool('hide_install_modal', true);
  //                   Navigator.pop(context);
  //                 },
  //                 child: const Text("Installer maintenant", style: TextStyle(fontWeight: FontWeight.bold)),
  //               ),
  //             ),
  //             const SizedBox(height: 10),
  //             // BOUTON DÉJÀ INSTALLÉ (Nouveau !)
  //             TextButton(
  //               onPressed: () async {
  //                 await prefs.setBool('hide_install_modal', true);
  //                 Navigator.pop(context);
  //               },
  //               child: const Text(
  //                 "C'est déjà fait / Ne plus afficher",
  //                 style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, decoration: TextDecoration.underline),
  //               ),
  //             ),
  //             // BOUTON FERMER TEMPORAIREMENT
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: const Text("Plus tard", style: TextStyle(color: Colors.white54)),
  //             ),
  //           ],
  //         ),
  //       ),
  //     );
  //   },
  // );
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
