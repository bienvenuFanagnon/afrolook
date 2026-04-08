import 'package:afrotok/services/ad_service.dart';
import 'package:flutter/material.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart'; // ✅ SDK Appodeal

class AdAdminPage extends StatefulWidget {
  const AdAdminPage({Key? key}) : super(key: key);

  @override
  _AdAdminPageState createState() => _AdAdminPageState();
}

class _AdAdminPageState extends State<AdAdminPage> {
  String _lastStatus = "En attente d'action...";
  bool _isBannerLoaded = false;

  void _updateStatus(String status) {
    setState(() => _lastStatus = status);
    print("📢 [ADMIN AD]: $status");
  }

  /// 1. Lancer l'Inspecteur de Médiation (Le remplaçant d'Ad Inspector)
  /// C'est l'outil ultime pour voir si Unity, AdMob et les autres fonctionnent.
  void _launchTestScreen() {
    _updateStatus("Ouverture de l'écran de test Appodeal...");
    AdService.showTestScreen();
  }

  /// 2. Forcer le chargement d'une pub (Toutes plateformes confondues)
  void _loadTestBanner() async {
    _updateStatus("Tentative de chargement d'une bannière...");

    // On vérifie si elle est déjà prête (Appodeal auto-cache)
    bool isLoaded = await Appodeal.isLoaded(AppodealAdType.Banner);

    if (isLoaded) {
      setState(() => _isBannerLoaded = true);
      _updateStatus("✅ Bannière prête et affichée !");
    } else {
      _updateStatus("⏳ Pas encore en cache, rafraîchissement demandé...");
      // Forcer une mise à jour
      setState(() => _isBannerLoaded = true);
    }
  }

  /// 3. Afficher un Interstitiel de test
  void _testInterstitial() async {
    bool isLoaded = await Appodeal.isLoaded(AppodealAdType.Interstitial);
    if (isLoaded) {
      Appodeal.show(AppodealAdType.Interstitial);
      _updateStatus("✅ Affichage de l'interstitiel");
    } else {
      _updateStatus("❌ Interstitiel non chargé (Attente cache)");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("APPODEAL ADMIN PANEL",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFFD600), // Ton Jaune Afrolook
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Diagnostic
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE21221), Color(0xFFFF5252)], // Ton dégradé Rouge
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Column(
                children: [
                  Icon(Icons.bug_report, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text("CONTRÔLE RÉSEAUX PUB",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("MÉDIATION : ADMOB + UNITY + OTHERS",
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Bouton Inspecteur (LE PLUS IMPORTANT)
            _buildAdminButton(
              title: "LANCER L'ÉCRAN DE TEST",
              subtitle: "Vérifier l'état de chaque régie (SDK & Config)",
              icon: Icons.analytics,
              color: const Color(0xFFFFD600),
              onTap: _launchTestScreen,
            ),

            const SizedBox(height: 15),

            // Bouton Test Bannière
            _buildAdminButton(
              title: "TESTER LA BANNIÈRE",
              subtitle: "Vérifier l'affichage visuel en bas",
              icon: Icons.ads_click,
              color: const Color(0xFFE21221),
              onTap: _loadTestBanner,
            ),

            const SizedBox(height: 15),

            // Bouton Test Interstitiel
            _buildAdminButton(
              title: "TESTER INTERSTITIEL",
              subtitle: "Forcer l'affichage plein écran",
              icon: Icons.fullscreen_exit,
              color: Colors.blue,
              onTap: _testInterstitial,
            ),

            const SizedBox(height: 30),

            // Console de Logs
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD600).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.terminal, color: Color(0xFFFFD600), size: 16),
                      SizedBox(width: 8),
                      Text("LOGS SYSTEM:",
                          style: TextStyle(color: Color(0xFFFFD600), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  Text(_lastStatus,
                      style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Zone d'affichage de la bannière si chargée
            if (_isBannerLoaded)
              Center(
                child: Column(
                  children: [
                    const Text("--- APERÇU BANNIÈRE ---", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    const SizedBox(height: 10),
                    AppodealBanner(
                      adSize: AppodealBannerSize.BANNER,
                      placement: "default", // Optionnel : pour tes stats sur le dashboard
                    )                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Ton Widget de bouton stylisé
  Widget _buildAdminButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(15),
            border: Border(left: BorderSide(color: color, width: 5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(subtitle,
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
