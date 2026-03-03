import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdAdminPage extends StatefulWidget {
  @override
  _AdAdminPageState createState() => _AdAdminPageState();
}

class _AdAdminPageState extends State<AdAdminPage> {
  String _lastStatus = "En attente d'action...";
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  // ID de test officiel Google
  final String testBannerId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';

  void _updateStatus(String status) {
    setState(() => _lastStatus = status);
  }

  /// 1. Lancer l'Ad Inspector
  void _launchInspector() {
    MobileAds.instance.openAdInspector((error) {
      if (error != null) {
        _updateStatus("❌ Erreur Inspecteur: ${error.message}");
      } else {
        _updateStatus("✅ Inspecteur fermé avec succès");
      }
    });
  }

  /// 2. Tester une Bannière de Test
  void _loadTestAd() {
    _bannerAd = BannerAd(
      adUnitId: testBannerId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() => _isLoaded = true);
          _updateStatus("✅ Pub de TEST chargée !");
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _updateStatus("❌ Échec TEST: ${error.code} - ${error.message}");
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fond Noir
      appBar: AppBar(
        title: Text("ADMOB ADMIN PANEL", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.yellow, // AppBar Jaune
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Stylisé
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.red, // Accent Rouge
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Icon(Icons.admin_panel_settings, size: 50, color: Colors.white),
                  Text("CONSOLE DE DIAGNOSTIC", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Section Ad Inspector
            _buildAdminButton(
              title: "LANCER AD INSPECTOR",
              subtitle: "Vérifier la médiation et les erreurs",
              icon: Icons.search,
              color: Colors.yellow,
              onTap: _launchInspector,
            ),

            SizedBox(height: 15),

            // Section Test de Pub
            _buildAdminButton(
              title: "TESTER BANNIÈRE (TEST ID)",
              subtitle: "Forcer le chargement d'une pub de test",
              icon: Icons.ads_click,
              color: Colors.red,
              onTap: _loadTestAd,
            ),

            SizedBox(height: 30),

            // Zone d'affichage du Status
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.yellow),
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("LOGS EN DIRECT :", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
                  Divider(color: Colors.yellow),
                  Text(_lastStatus, style: TextStyle(color: Colors.white, fontFamily: 'monospace')),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Emplacement de la pub de test
            if (_isLoaded && _bannerAd != null)
              Container(
                height: _bannerAd!.size.height.toDouble(),
                width: _bannerAd!.size.width.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }

  // Widget réutilisable pour les boutons Admin
  Widget _buildAdminButton({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 6)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 15),
          ],
        ),
      ),
    );
  }
}