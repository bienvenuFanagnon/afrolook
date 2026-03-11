import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;

class MaPageAvecPub extends StatefulWidget {
  @override
  _MaPageAvecPubState createState() => _MaPageAvecPubState();
}

class _MaPageAvecPubState extends State<MaPageAvecPub> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isFailed = false;

  // ==========================================================
  // IDs DE TEST (à utiliser pendant le développement)
  // ==========================================================
  String get _testAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // ID de test Android
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // ID de test iOS
    } else {
      return 'ca-app-pub-3940256099942544/6300978111'; // Défaut
    }
  }

  // ==========================================================
  // VOTRE ID DE PRODUCTION (à utiliser pour la publication)
  // ==========================================================
  final String _productionAdUnitId = 'ca-app-pub-4937249920200692/9042935121';

  // Variable pour basculer entre test et production
  // Mettre à false pour la production
  final bool _useTestAd = true ;

  @override
  void initState() {
    super.initState();
    _initBannerAd();
  }

  void _initBannerAd() {
    // Choisir l'ID approprié
    final adUnitId = _useTestAd ? _testAdUnitId : _productionAdUnitId;

    print('📢 Chargement de la bannière avec ID: $adUnitId');

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('✅ Bannière chargée avec succès');
          if (mounted) {
            setState(() {
              _isLoaded = true;
              _isFailed = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ Erreur de chargement de la bannière: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isFailed = true;
            });
          }
        },
        onAdOpened: (ad) {
          print('🔄 Bannière ouverte');
        },
        onAdClosed: (ad) {
          print('🔄 Bannière fermée');
        },
        onAdImpression: (ad) {
          print('👁️ Impression de la bannière');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  // Méthode pour recharger la pub en cas d'échec
  void _reloadAd() {
    setState(() {
      _isLoaded = false;
      _isFailed = false;
    });
    _initBannerAd();
  }

  @override
  Widget build(BuildContext context) {
    // Version simplifiée SANS Scaffold (pour intégration dans d'autres pages)
    return _buildBannerWidget();
  }

  Widget _buildBannerWidget() {
    // Taille standard de la bannière
    const double adWidth = 320;
    const double adHeight = 50;

    if (_isLoaded && _bannerAd != null) {
      return Container(
        width: adWidth,
        height: adHeight,
        child: AdWidget(ad: _bannerAd!),
      );
    } else if (_isFailed) {
      // Afficher un message d'erreur avec option de rechargement
      return Container(
        width: adWidth,
        height: adHeight,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 16,
              color: Colors.grey[600],
            ),
            SizedBox(width: 8),
            Text(
              'Publicité non disponible',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            SizedBox(width: 8),
            GestureDetector(
              onTap: _reloadAd,
              child: Icon(
                Icons.refresh,
                size: 16,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      );
    } else {
      // Affichage du chargement
      return Container(
        width: adWidth,
        height: adHeight,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Chargement...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

// Version avec Scaffold (si vous voulez une page dédiée)
class PageAvecPub extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Page avec Publicité"),
        backgroundColor: Color(0xFF1E3A8A),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                "Votre contenu ici",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          // Pub en bas
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Center(
              child: MaPageAvecPub(), // Votre widget de pub sans Scaffold
            ),
          ),
        ],
      ),
    );
  }
}