import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/crypto_model.dart';
import 'authProvider.dart';

class CryptoMarketProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CryptoCurrency> _cryptos = [];
  List<CryptoCurrency> _trendingCryptos = [];
  List<CryptoCurrency> _featuredCryptos = [];
  bool _isLoading = true;
  String _errorMessage = '';
  CryptoPortfolio? _portfolio;
  double _totalMarketCap = 0;
  double _marketChange24h = 0;

  List<CryptoCurrency> get cryptos => _cryptos;
  List<CryptoCurrency> get trendingCryptos => _trendingCryptos;
  List<CryptoCurrency> get featuredCryptos => _featuredCryptos;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  CryptoPortfolio? get portfolio => _portfolio;
  double get totalMarketCap => _totalMarketCap;
  double get marketChange24h => _marketChange24h;


  // Ajouter une référence au UserAuthProvider
  final UserAuthProvider? userAuthProvider;

  CryptoMarketProvider({this.userAuthProvider});

  // ... autres propriétés existantes ...

  bool get isAdmin {
    if (userAuthProvider == null) return false;

    // Vérifier le rôle de l'utilisateur connecté
    final UserData userData = userAuthProvider!.loginUserData;

    // Vérifier si l'utilisateur a le rôle ADM
    // Adaptez cette logique selon votre structure UserData
    if (userData.role != null) {
      return userData.role == UserRole.ADM.name;
    }

    // Alternative: vérifier par email ou autre champ
    // if (userData.email != null) {
    //   return userData.email!.endsWith('@admin.afrolook.com');
    // }

    return false;
  }

  // AJOUTEZ CETTE FONCTION DANS LA CLASSE :
  List<PriceHistory> _generateDefaultPriceHistory(CryptoCurrency crypto) {
    final List<PriceHistory> history = [];
    final now = DateTime.now();
    final random = Random();

    final initialPrice = crypto.initialPrice;
    final currentPrice = crypto.currentPrice;
    const totalDays = 90; // 3 mois d'historique

    double price = initialPrice;

    for (int i = totalDays; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));

      // Calculer la progression vers le prix actuel
      final progress = 1 - (i / totalDays);
      final targetPrice = initialPrice + (currentPrice - initialPrice) * progress;

      // Ajouter de la volatilité réaliste
      final volatility = (random.nextDouble() - 0.5) * 0.06; // ±3%
      price = targetPrice * (1 + volatility);

      // Pour aujourd'hui, forcer le prix actuel exact
      if (i == 0) {
        price = currentPrice;
      }

      history.add(PriceHistory(
        price: double.parse(price.toStringAsFixed(4)),
        timestamp: date,
      ));
    }

    return history;
  }

  // MODIFIEZ votre fonction fetchCryptos existante :
  Future<void> fetchCryptos2() async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('cryptos')
          .orderBy('rank')
          .limit(100)
          .get();

      // Transformez les documents en CryptoCurrency
      List<CryptoCurrency> loadedCryptos = snapshot.docs
          .map((doc) => CryptoCurrency.fromFirestore(doc))
          .toList();

      // ICI : AJOUTER L'HISTORIQUE POUR CHAQUE CRYPTO
      _cryptos = loadedCryptos.map((crypto) {
        // Si pas d'historique ou historique insuffisant, on génère
        if (crypto.priceHistory.isEmpty || crypto.priceHistory.length < 10) {
          return crypto.copyWith(
            priceHistory: _generateDefaultPriceHistory(crypto),
          );
        }
        return crypto; // Sinon garder l'historique existant
      }).toList();

      _trendingCryptos = _cryptos
          .where((crypto) => crypto.isTrending)
          .take(5)
          .toList();

      _featuredCryptos = _cryptos
          .where((crypto) => crypto.rank <= 10)
          .take(3)
          .toList();

      // Calculer les métriques du marché
      _calculateMarketMetrics();

      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des cryptos: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<void> fetchCryptos() async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('cryptos')
          .orderBy('rank')
          .limit(100)
          .get();

      _cryptos = snapshot.docs
          .map((doc) => CryptoCurrency.fromFirestore(doc))
          .toList();

      _trendingCryptos = _cryptos
          .where((crypto) => crypto.isTrending)
          .take(5)
          .toList();

      _featuredCryptos = _cryptos
          .where((crypto) => crypto.rank <= 10)
          .take(3)
          .toList();

      // Calculer les métriques du marché
      _calculateMarketMetrics();

      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des cryptos: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _calculateMarketMetrics() {
    _totalMarketCap = _cryptos.fold(0, (sum, crypto) => sum + crypto.marketCap);

    final double totalChange = _cryptos.fold(0, (sum, crypto) {
      final weightedChange = crypto.dailyPriceChange * (crypto.marketCap / _totalMarketCap);
      return sum + weightedChange;
    });

    _marketChange24h = totalChange;
  }

  Future<void> fetchPortfolio() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('crypto_portfolios').doc(user.uid).get();
      if (doc.exists) {
        _portfolio = CryptoPortfolio.fromFirestore(doc);
        _updatePortfolioValue();
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement du portefeuille: ${e.toString()}';
    }
  }

  void _updatePortfolioValue() {
    if (_portfolio == null) return;

    double totalValue = _portfolio!.balance;
    double totalProfitLoss = 0;

    // Créer une nouvelle liste pour les cryptos mis à jour
    List<OwnedCrypto> updatedOwnedCryptos = [];

    for (var ownedCrypto in _portfolio!.ownedCryptos) {
      final crypto = _cryptos.firstWhere(
            (c) => c.id == ownedCrypto.cryptoId,
        orElse: () => CryptoCurrency(
          id: '',
          symbol: '',
          name: '',
          imageUrl: '',
          currentPrice: 0,
          initialPrice: 0,
          marketCap: 0,
          circulatingSupply: 0,
          totalSupply: 0,
          lastUpdated: DateTime.now(),
        ),
      );

      final currentValue = ownedCrypto.quantity * crypto.currentPrice;
      final profitLoss = currentValue - (ownedCrypto.quantity * ownedCrypto.averageBuyPrice);

      // Créer une nouvelle instance avec les valeurs mises à jour
      final updatedCrypto = OwnedCrypto(
        cryptoId: ownedCrypto.cryptoId,
        quantity: ownedCrypto.quantity,
        averageBuyPrice: ownedCrypto.averageBuyPrice,
        currentValue: currentValue,
        profitLoss: profitLoss,
      );

      updatedOwnedCryptos.add(updatedCrypto);

      totalValue += currentValue;
      totalProfitLoss += profitLoss;
    }

    // Utiliser copyWith pour créer une nouvelle instance du portfolio
    _portfolio = _portfolio!.copyWith(
      totalValue: totalValue,
      totalProfitLoss: totalProfitLoss,
      ownedCryptos: updatedOwnedCryptos,
    );
  }
  Future<void> createPortfolio(double initialBalance) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final portfolio = CryptoPortfolio(
        userId: user.uid,
        balance: initialBalance,
        ownedCryptos: [],
      );

      await _firestore
          .collection('crypto_portfolios')
          .doc(user.uid)
          .set(portfolio.toMap());

      await fetchPortfolio();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur lors de la création du portefeuille: ${e.toString()}';
    }
  }

  Future<void> buyCrypto(String cryptoId, double quantity) async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = 'Utilisateur non connecté';
      notifyListeners();
      return;
    }

    try {
      await _firestore.runTransaction((transaction) async {
        // Récupérer le crypto
        final cryptoDoc = await transaction.get(_firestore.collection('cryptos').doc(cryptoId));
        if (!cryptoDoc.exists) {
          throw 'Crypto non trouvée';
        }

        final crypto = CryptoCurrency.fromFirestore(cryptoDoc);
        final totalCost = crypto.currentPrice * quantity;

        // Récupérer le portefeuille
        final portfolioDoc = await transaction.get(_firestore.collection('crypto_portfolios').doc(user.uid));
        if (!portfolioDoc.exists) {
          throw 'Portefeuille non trouvé';
        }

        final portfolio = CryptoPortfolio.fromFirestore(portfolioDoc);

        if (portfolio.balance < totalCost) {
          throw 'Solde insuffisant';
        }

        // Mettre à jour le portefeuille
        final updatedOwnedCryptos = _updateOwnedCryptos(
          portfolio.ownedCryptos,
          cryptoId,
          quantity,
          crypto.currentPrice,
        );

        transaction.update(_firestore.collection('crypto_portfolios').doc(user.uid), {
          'balance': portfolio.balance - totalCost,
          'ownedCryptos': updatedOwnedCryptos.map((e) => e.toMap()).toList(),
        });

        // Créer la transaction
        final transactionRef = _firestore.collection('crypto_transactions').doc();
        transaction.set(transactionRef, CryptoTransaction(
          id: transactionRef.id,
          userId: user.uid,
          cryptoId: cryptoId,
          unitPrice: crypto.currentPrice,
          quantity: quantity,
          date: DateTime.now(),
          type: TransactionType.buy,
          profit: 0,
          commission: totalCost * 0.01, // 1% de commission
        ).toMap());
      });

      await fetchPortfolio();
      _errorMessage = '';

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur lors de l\'achat: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> sellCrypto(String cryptoId, double quantity) async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = 'Utilisateur non connecté';
      notifyListeners();
      return;
    }

    try {
      await _firestore.runTransaction((transaction) async {
        // Récupérer le crypto
        final cryptoDoc = await transaction.get(_firestore.collection('cryptos').doc(cryptoId));
        if (!cryptoDoc.exists) {
          throw 'Crypto non trouvée';
        }

        final crypto = CryptoCurrency.fromFirestore(cryptoDoc);

        // Récupérer le portefeuille
        final portfolioDoc = await transaction.get(_firestore.collection('crypto_portfolios').doc(user.uid));
        if (!portfolioDoc.exists) {
          throw 'Portefeuille non trouvé';
        }

        final portfolio = CryptoPortfolio.fromFirestore(portfolioDoc);

        // Vérifier la possession
        final ownedCrypto = portfolio.ownedCryptos.firstWhere(
              (c) => c.cryptoId == cryptoId,
          orElse: () => throw 'Vous ne possédez pas cette crypto',
        );

        if (ownedCrypto.quantity < quantity) {
          throw 'Quantité insuffisante';
        }

        // Calculer les gains
        final grossAmount = crypto.currentPrice * quantity;
        final commission = grossAmount * 0.01; // 1% de commission
        final netAmount = grossAmount - commission;
        final profit = (crypto.currentPrice - ownedCrypto.averageBuyPrice) * quantity;

        // Mettre à jour le portefeuille
        final updatedOwnedCryptos = List<OwnedCrypto>.from(portfolio.ownedCryptos);
        final existingIndex = updatedOwnedCryptos.indexWhere((c) => c.cryptoId == cryptoId);

        if (existingIndex >= 0) {
          final existing = updatedOwnedCryptos[existingIndex];
          final newQuantity = existing.quantity - quantity;

          if (newQuantity > 0) {
            updatedOwnedCryptos[existingIndex] = OwnedCrypto(
              cryptoId: cryptoId,
              quantity: newQuantity,
              averageBuyPrice: existing.averageBuyPrice,
            );
          } else {
            updatedOwnedCryptos.removeAt(existingIndex);
          }
        }

        transaction.update(_firestore.collection('crypto_portfolios').doc(user.uid), {
          'balance': portfolio.balance + netAmount,
          'ownedCryptos': updatedOwnedCryptos.map((e) => e.toMap()).toList(),
        });

        // Créer la transaction
        final transactionRef = _firestore.collection('crypto_transactions').doc();
        transaction.set(transactionRef, CryptoTransaction(
          id: transactionRef.id,
          userId: user.uid,
          cryptoId: cryptoId,
          unitPrice: crypto.currentPrice,
          quantity: quantity,
          date: DateTime.now(),
          type: TransactionType.sell,
          profit: profit,
          commission: commission,
        ).toMap());
      });

      await fetchPortfolio();
      _errorMessage = '';

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur lors de la vente: ${e.toString()}';
      notifyListeners();
    }
  }

  List<OwnedCrypto> _updateOwnedCryptos(
      List<OwnedCrypto> current,
      String cryptoId,
      double quantity,
      double price,
      ) {
    final updated = List<OwnedCrypto>.from(current);
    final existingIndex = updated.indexWhere((c) => c.cryptoId == cryptoId);

    if (existingIndex >= 0) {
      final existing = updated[existingIndex];
      final newQuantity = existing.quantity + quantity;
      final newAvgPrice = ((existing.averageBuyPrice * existing.quantity) + (price * quantity)) / newQuantity;

      updated[existingIndex] = OwnedCrypto(
        cryptoId: cryptoId,
        quantity: newQuantity,
        averageBuyPrice: newAvgPrice,
      );
    } else {
      updated.add(OwnedCrypto(
        cryptoId: cryptoId,
        quantity: quantity,
        averageBuyPrice: price,
      ));
    }

    return updated;
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
}