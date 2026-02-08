import 'dart:js' as js;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html; // Nécessaire pour détecter le mode standalone



Future<void> showInstallModal(BuildContext context) async {
  if (!kIsWeb) return;

  final prefs = await SharedPreferences.getInstance();

  // 1. Vérifier si l'utilisateur a demandé de ne plus voir le modal
  bool hideModal = prefs.getBool('hide_install_modal') ?? false;

  // 2. Vérifier si l'app est DÉJÀ lancée en tant que PWA (installée)
  // On vérifie si le média query 'display-mode: standalone' est actif
  bool isInstalled = html.window.matchMedia('(display-mode: standalone)').matches;

  if (hideModal || isInstalled) {
    print("PWA: Modal masqué (Déjà installé ou refusé)");
    return;
  }

  // Affichage du modal
  showDialog(
    context: context,
    barrierDismissible: false, // Force une action
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_to_home_screen_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                "Installe Afrolook",
                style: TextStyle(color: Color(0xFFFFD700), fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Accède à ton réseau social préféré plus rapidement et sans passer par le navigateur.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 25),
              // BOUTON INSTALLER
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    js.context.callMethod('installPWA');
                    // On enregistre qu'il a essayé d'installer pour ne plus le harceler
                    await prefs.setBool('hide_install_modal', true);
                    Navigator.pop(context);
                  },
                  child: const Text("Installer maintenant", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              // BOUTON DÉJÀ INSTALLÉ (Nouveau !)
              TextButton(
                onPressed: () async {
                  await prefs.setBool('hide_install_modal', true);
                  Navigator.pop(context);
                },
                child: const Text(
                  "C'est déjà fait / Ne plus afficher",
                  style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, decoration: TextDecoration.underline),
                ),
              ),
              // BOUTON FERMER TEMPORAIREMENT
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Plus tard", style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      );
    },
  );
}