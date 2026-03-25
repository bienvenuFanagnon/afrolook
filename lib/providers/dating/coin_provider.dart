// lib/providers/coin_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/dating_data.dart';
import '../../services/dating/coin_service.dart';
import '../authProvider.dart';

class CoinProvider extends ChangeNotifier {
  final CoinService _coinService = CoinService();
  final UserAuthProvider? authProvider;

  List<CoinPackage> _availablePackages = [];
  List<UserCoinTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  CoinProvider({this.authProvider});

  // Getters
  List<CoinPackage> get availablePackages => _availablePackages;
  List<UserCoinTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Charger les packs de pièces disponibles avec création automatique si vide
  Future<void> loadCoinPackages() async {
    _setLoading(true);
    _error = null;

    try {
      print('📱 === Chargement des packs de pièces ===');

      final snapshot = await FirebaseFirestore.instance
          .collection('coin_packages')
          .where('isActive', isEqualTo: true)
          .orderBy('priceXof')
          .get();

      print('📊 Packs trouvés: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('⚠️ Aucun pack trouvé, création des packs par défaut...');
        await _createDefaultCoinPackages();
        // Recharger après création
        final newSnapshot = await FirebaseFirestore.instance
            .collection('coin_packages')
            .where('isActive', isEqualTo: true)
            .orderBy('priceXof')
            .get();

        _availablePackages = newSnapshot.docs
            .map((doc) => CoinPackage.fromJson(doc.data()))
            .toList();
        print('✅ ${_availablePackages.length} packs créés et chargés');
      } else {
        _availablePackages = snapshot.docs
            .map((doc) => CoinPackage.fromJson(doc.data()))
            .toList();
        print('✅ ${_availablePackages.length} packs chargés');
      }

      notifyListeners();
    } catch (e) {
      print('❌ Erreur chargement packs: $e');
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Créer les packs de pièces par défaut avec réductions
  Future<void> _createDefaultCoinPackages() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = FirebaseFirestore.instance.batch();

    // Packs avec réductions progressives
    final packages = [
      CoinPackage(
        id: FirebaseFirestore.instance.collection('coin_packages').doc().id,
        name: 'Pack Mini',
        coinsAmount: 100,
        priceXof: 250.0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      CoinPackage(
        id: FirebaseFirestore.instance.collection('coin_packages').doc().id,
        name: 'Pack Starter',
        coinsAmount: 250,
        priceXof: 600.0,  // 250 pièces = 625 FCFA normal, réduction de 25 FCFA
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      CoinPackage(
        id: FirebaseFirestore.instance.collection('coin_packages').doc().id,
        name: 'Pack Populaire',
        coinsAmount: 500,
        priceXof: 1150.0, // 500 pièces = 1250 FCFA normal, réduction de 100 FCFA
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      CoinPackage(
        id: FirebaseFirestore.instance.collection('coin_packages').doc().id,
        name: 'Pack Premium',
        coinsAmount: 1000,
        priceXof: 2200.0, // 1000 pièces = 2500 FCFA normal, réduction de 300 FCFA
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      CoinPackage(
        id: FirebaseFirestore.instance.collection('coin_packages').doc().id,
        name: 'Pack Gold',
        coinsAmount: 2500,
        priceXof: 5300.0, // 2500 pièces = 6250 FCFA normal, réduction de 950 FCFA
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      CoinPackage(
        id: FirebaseFirestore.instance.collection('coin_packages').doc().id,
        name: 'Pack Platinum',
        coinsAmount: 5000,
        priceXof: 10000.0, // 5000 pièces = 12500 FCFA normal, réduction de 2500 FCFA
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    print('📦 Création des packs:');
    for (var package in packages) {
      final docRef = FirebaseFirestore.instance.collection('coin_packages').doc(package.id);
      batch.set(docRef, package.toJson());

      final discount = ((package.coinsAmount * 2.5) - package.priceXof);
      final discountPercent = (discount / (package.coinsAmount * 2.5) * 100).toStringAsFixed(0);
      print('   ✅ ${package.name}: ${package.coinsAmount} pièces - ${package.priceXof} FCFA (Économie: $discount FCFA - ${discountPercent}%)');
    }

    await batch.commit();
    print('✅ Tous les packs ont été créés avec succès');
  }

  // Acheter des pièces
  Future<bool> buyCoins(CoinPackage package) async {
    _setLoading(true);
    _error = null;

    try {
      print('📱 === Achat de pièces ===');
      print('📦 Pack: ${package.name}');
      print('💰 Coût: ${package.priceXof} FCFA');
      print('🎁 Pièces: ${package.coinsAmount}');

      final success = await _coinService.buyCoins(package);

      if (success) {
        print('✅ Achat réussi !');
        await loadUserTransactions();
        // Rafraîchir les données utilisateur
        if (authProvider?.loginUserData.id != null) {
          await authProvider?.getCurrentUser(authProvider!.loginUserData.id!);
        }
      } else {
        print('❌ Échec de l\'achat');
      }
      return success;
    } catch (e) {
      print('❌ Erreur lors de l\'achat: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Charger les transactions de l'utilisateur
  Future<void> loadUserTransactions() async {
    if (authProvider?.loginUserData.id == null) return;

    try {
      print('📱 Chargement des transactions pour ${authProvider!.loginUserData.id}');
      _transactions = await _coinService.getUserTransactions(
          authProvider!.loginUserData.id!
      );
      print('✅ ${_transactions.length} transactions chargées');
      notifyListeners();
    } catch (e) {
      print('❌ Erreur chargement transactions: $e');
    }
  }

  // Convertir des pièces en FCFA (pour créateurs)
  Future<bool> convertCoinsToXof(int amount) async {
    if (authProvider?.loginUserData.id == null) return false;

    _setLoading(true);
    _error = null;

    try {
      print('📱 Conversion de $amount pièces en FCFA');
      return await _coinService.convertCoinsToXof(
        creatorId: authProvider!.loginUserData.id!,
        amount: amount,
      );
    } catch (e) {
      print('❌ Erreur conversion: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}