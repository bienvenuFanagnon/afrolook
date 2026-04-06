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

// import 'dart:io';
// import 'package:flutter/material.dart';
//
//
// class AdAdminPage extends StatefulWidget {
//   @override
//   _AdAdminPageState createState() => _AdAdminPageState();
// }
//
// class _AdAdminPageState extends State<AdAdminPage> {
//   String _lastStatus = "En attente d'action...";
//   BannerAd? _bannerAd;
//   bool _isLoaded = false;
//
//   // ID de test officiel Google
//   final String testBannerId = Platform.isAndroid
//       ? 'ca-app-pub-3940256099942544/6300978111'
//       : 'ca-app-pub-3940256099942544/2934735716';
//
//   void _updateStatus(String status) {
//     setState(() => _lastStatus = status);
//   }
//
//   /// 1. Lancer l'Ad Inspector
//   void _launchInspector() {
//     MobileAds.instance.openAdInspector((error) {
//       if (error != null) {
//         _updateStatus("❌ Erreur Inspecteur: ${error.message}");
//       } else {
//         _updateStatus("✅ Inspecteur fermé avec succès");
//       }
//     });
//   }
//
//   /// 2. Tester une Bannière de Test
//   void _loadTestAd() {
//     _bannerAd = BannerAd(
//       adUnitId: testBannerId,
//       request: const AdRequest(),
//       size: AdSize.banner,
//       listener: BannerAdListener(
//         onAdLoaded: (ad) {
//           setState(() => _isLoaded = true);
//           _updateStatus("✅ Pub de TEST chargée !");
//         },
//         onAdFailedToLoad: (ad, error) {
//           ad.dispose();
//           _updateStatus("❌ Échec TEST: ${error.code} - ${error.message}");
//         },
//       ),
//     )..load();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black, // Fond Noir
//       appBar: AppBar(
//         title: Text("ADMOB ADMIN PANEL", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
//         backgroundColor: Colors.yellow, // AppBar Jaune
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             // Header Stylisé
//             Container(
//               padding: EdgeInsets.all(15),
//               decoration: BoxDecoration(
//                 color: Colors.red, // Accent Rouge
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Column(
//                 children: [
//                   Icon(Icons.admin_panel_settings, size: 50, color: Colors.white),
//                   Text("CONSOLE DE DIAGNOSTIC", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
//                 ],
//               ),
//             ),
//             SizedBox(height: 20),
//
//             // Section Ad Inspector
//             _buildAdminButton(
//               title: "LANCER AD INSPECTOR",
//               subtitle: "Vérifier la médiation et les erreurs",
//               icon: Icons.search,
//               color: Colors.yellow,
//               onTap: _launchInspector,
//             ),
//
//             SizedBox(height: 15),
//
//             // Section Test de Pub
//             _buildAdminButton(
//               title: "TESTER BANNIÈRE (TEST ID)",
//               subtitle: "Forcer le chargement d'une pub de test",
//               icon: Icons.ads_click,
//               color: Colors.red,
//               onTap: _loadTestAd,
//             ),
//
//             SizedBox(height: 30),
//
//             // Zone d'affichage du Status
//             Container(
//               padding: EdgeInsets.all(15),
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.yellow),
//                 color: Colors.grey[900],
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text("LOGS EN DIRECT :", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
//                   Divider(color: Colors.yellow),
//                   Text(_lastStatus, style: TextStyle(color: Colors.white, fontFamily: 'monospace')),
//                 ],
//               ),
//             ),
//
//             SizedBox(height: 20),
//
//             // Emplacement de la pub de test
//             if (_isLoaded && _bannerAd != null)
//               Container(
//                 height: _bannerAd!.size.height.toDouble(),
//                 width: _bannerAd!.size.width.toDouble(),
//                 child: AdWidget(ad: _bannerAd!),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Widget réutilisable pour les boutons Admin
//   Widget _buildAdminButton({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
//     return InkWell(
//       onTap: onTap,
//       child: Container(
//         padding: EdgeInsets.all(15),
//         decoration: BoxDecoration(
//           color: Colors.grey[850],
//           borderRadius: BorderRadius.circular(12),
//           border: Border(left: BorderSide(color: color, width: 6)),
//         ),
//         child: Row(
//           children: [
//             Icon(icon, color: color, size: 30),
//             SizedBox(width: 15),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
//                   Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 12)),
//                 ],
//               ),
//             ),
//             Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 15),
//           ],
//         ),
//       ),
//     );
//   }
// }