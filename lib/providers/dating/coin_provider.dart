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

  // Charger les packs de pièces disponibles
  Future<void> loadCoinPackages() async {
    _setLoading(true);
    _error = null;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('coin_packages')
          .where('isActive', isEqualTo: true)
          .orderBy('priceXof')
          .get();

      _availablePackages = snapshot.docs
          .map((doc) => CoinPackage.fromJson(doc.data()))
          .toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Acheter des pièces
  Future<bool> buyCoins(CoinPackage package) async {
    _setLoading(true);
    _error = null;

    try {
      final success = await _coinService.buyCoins(package);
      if (success) {
        await loadUserTransactions();
        // Rafraîchir les données utilisateur
        if (authProvider?.loginUserData.id != null) {
          await authProvider?.getCurrentUser(authProvider!.loginUserData.id!);
        }
      }
      return success;
    } catch (e) {
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
      _transactions = await _coinService.getUserTransactions(
          authProvider!.loginUserData.id!
      );
      notifyListeners();
    } catch (e) {
      print('Erreur chargement transactions: $e');
    }
  }

  // Convertir des pièces en FCFA (pour créateurs)
  Future<bool> convertCoinsToXof(int amount) async {
    if (authProvider?.loginUserData.id == null) return false;

    _setLoading(true);
    _error = null;

    try {
      return await _coinService.convertCoinsToXof(
        creatorId: authProvider!.loginUserData.id!,
        amount: amount,
      );
    } catch (e) {
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