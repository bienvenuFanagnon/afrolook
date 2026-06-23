// utils/crypto_initializer.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CryptoInitializer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> initializeCryptos() async {
    final cryptos = [
      {
        'symbol': 'AFC',
        'name': 'AfroCoin',
        'imageUrl': '',
        'currentPrice': 100.0,
        'initialPrice': 100.0,
        'marketCap': 1000000.0,
        'circulatingSupply': 10000.0,
        'totalSupply': 100000.0,
        'dailyPriceChange': 0.02,
        'dailyVolume': 50000.0,
        'dailyMaxChange': 0.15, // ✅ Corrigé
        'dailyMinChange': -0.15, // ✅ Corrigé
        'lastUpdated': Timestamp.now(),
        'priceHistory': [],
        'category': 'Stable',
        'rank': 1,
        'isTrending': true,
        'emoji': '🪙'
      },
      {
        'symbol': 'KRC',
        'name': 'KoraCoin',
        'imageUrl': '',
        'currentPrice': 50.0,
        'initialPrice': 50.0,
        'marketCap': 500000.0,
        'circulatingSupply': 10000.0,
        'totalSupply': 100000.0,
        'dailyPriceChange': 0.08,
        'dailyVolume': 75000.0,
        'dailyMaxChange': 0.15, // ✅ Corrigé
        'dailyMinChange': -0.15, // ✅ Corrigé
        'lastUpdated': Timestamp.now(),
        'priceHistory': [],
        'category': 'Volatile',
        'rank': 2,
        'isTrending': true,
        'emoji': '⚡'
      },
      {
        'symbol': 'NIG',
        'name': 'NiloGold',
        'imageUrl': '',
        'currentPrice': 200.0,
        'initialPrice': 200.0,
        'marketCap': 2000000.0,
        'circulatingSupply': 10000.0,
        'totalSupply': 50000.0,
        'dailyPriceChange': 0.01,
        'dailyVolume': 25000.0,
        'dailyMaxChange': 0.15, // ✅ Corrigé
        'dailyMinChange': -0.15, // ✅ Corrigé
        'lastUpdated': Timestamp.now(),
        'priceHistory': [],
        'category': 'Precious',
        'rank': 3,
        'isTrending': false,
        'emoji': '🏺'
      },
      {
        'symbol': 'SVT',
        'name': 'Savannah Token',
        'imageUrl': '',
        'currentPrice': 75.0,
        'initialPrice': 75.0,
        'marketCap': 750000.0,
        'circulatingSupply': 10000.0,
        'totalSupply': 150000.0,
        'dailyPriceChange': 0.05,
        'dailyVolume': 60000.0,
        'dailyMaxChange': 0.15, // ✅ Corrigé
        'dailyMinChange': -0.15, // ✅ Corrigé
        'lastUpdated': Timestamp.now(),
        'priceHistory': [],
        'category': 'Community',
        'rank': 4,
        'isTrending': true,
        'emoji': '🌍'
      },
      {
        'symbol': 'TBD',
        'name': 'Timbuktu Dollar',
        'imageUrl': '',
        'currentPrice': 150.0,
        'initialPrice': 150.0,
        'marketCap': 1500000.0,
        'circulatingSupply': 10000.0,
        'totalSupply': 75000.0,
        'dailyPriceChange': 0.015,
        'dailyVolume': 35000.0,
        'dailyMaxChange': 0.15, // ✅ Corrigé
        'dailyMinChange': -0.15, // ✅ Corrigé
        'lastUpdated': Timestamp.now(),
        'priceHistory': [],
        'category': 'Premium',
        'rank': 5,
        'isTrending': false,
        'emoji': '💎'
      },
    ];

    try {
      for (var crypto in cryptos) {
        // Vérifier si la crypto existe déjà
        final query = await _firestore
            .collection('cryptos')
            .where('symbol', isEqualTo: crypto['symbol'])
            .get();

        if (query.docs.isEmpty) {
          await _firestore.collection('cryptos').add(crypto);
          printVm('✅ Crypto ${crypto['symbol']} créée avec succès');
        } else {
          printVm('ℹ️ Crypto ${crypto['symbol']} existe déjà - Mise à jour...');

          // Mettre à jour les limites si nécessaire
          final existingDoc = query.docs.first;
          await _firestore.collection('cryptos').doc(existingDoc.id).update({
            'dailyMaxChange': 0.15,
            'dailyMinChange': -0.15,
            'lastUpdated': Timestamp.now(),
          });
          printVm('✅ Crypto ${crypto['symbol']} mise à jour');
        }
      }
      printVm('🎉 Initialisation des cryptos terminée avec succès!');
    } catch (e) {
      printVm('❌ Erreur lors de l\'initialisation des cryptos: $e');
    }
  }

  // Méthode pour appeler l'initialisation depuis l'admin
  static Future<void> initializeFromAdmin() async {
    await initializeCryptos();
  }
}