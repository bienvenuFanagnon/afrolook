import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/crypto_model.dart';


// ✅ CLASSES POUR LA SÉCURITÉ
class SellCheckResult {
  final bool allowed;
  final String errorMessage;

  SellCheckResult({required this.allowed, this.errorMessage = ''});
}

class SecurityCheckResult {
  final bool allowed;
  final String? errorMessage;
  final RiskLevel riskLevel;
  final double? estimatedPrice;

  SecurityCheckResult({
    required this.allowed,
    this.errorMessage,
    this.riskLevel = RiskLevel.low,
    this.estimatedPrice,
  });
}

class VolumeCheckResult {
  final bool allowed;
  final int waitTime;

  VolumeCheckResult({required this.allowed, this.waitTime = 0});
}

class FinancialImpact {
  final RiskLevel riskLevel;
  final double potentialLoss;

  FinancialImpact({required this.riskLevel, required this.potentialLoss});
}

enum RiskLevel { low, medium, high }

class CryptoTradingProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final String cryptoId;
  CryptoCurrency? _crypto;
  final List<CryptoTransaction> _transactions = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isBuying = false;
  bool _isSelling = false;
  double _selectedQuantity = 1.0;
  OwnedCrypto? _ownedCrypto;
  final double _commissionRate = 0.1; // 10% commission
  final double _commissionRateByCrypto = 0.07; // 7% commission

  // Variables de sécurité
  final Map<String, DateTime> _userLastTransactions = {};
  final Map<String, double> _cryptoVolumeLast5min = {};

  // Getters
  CryptoCurrency? get crypto => _crypto;
  List<CryptoTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isBuying => _isBuying;
  bool get isSelling => _isSelling;
  double get selectedQuantity => _selectedQuantity;
  OwnedCrypto? get ownedCrypto => _ownedCrypto;

  // Setters
  set selectedQuantity(double value) {
    _selectedQuantity = value;
    notifyListeners();
  }

  CryptoTradingProvider(this.cryptoId) {
    _initialize();
  }

  void _initialize() {
    fetchCryptoDetails();
    fetchTransactions();
    checkOwnedCrypto();
    _initializeSecuritySystems();
  }

  void _initializeSecuritySystems() {
    _startVolumeMonitoring();
  }

  void _startVolumeMonitoring() {
    Future.delayed(Duration(minutes: 1), () {
      _updateVolumeData();
      _startVolumeMonitoring();
    });
  }

  void _updateVolumeData() {
    final fiveMinutesAgo = DateTime.now().subtract(Duration(minutes: 5));
    _userLastTransactions.removeWhere(
          (_, timestamp) => timestamp.isBefore(fiveMinutesAgo),
    );
  }

  // ✅ FONCTION DE CALCUL DE PRIX POUR CRYPTO
  double calculateNewPrice(
      CryptoCurrency crypto,
      double quantity,
      String transactionType,
      ) {
    // Coefficients asymétriques pour crypto
    final double baseCoefficient;

    if (transactionType == 'buy') {
      baseCoefficient = 9.1; // Pump effect pour achat
    } else { // 'sell'
      baseCoefficient = 2.0; // HODL effect pour vente
    }

    // Calcul d'impact basé sur la liquidité
    final double liquidityRatio = crypto.circulatingSupply / crypto.totalSupply;
    final double adjustedCoefficient = baseCoefficient * (0.3 + liquidityRatio * 0.7);

    // Impact proportionnel au supply
    final double availableSupply = crypto.circulatingSupply > 0 ? crypto.circulatingSupply : 1.0;
    final double impact = adjustedCoefficient * (quantity / availableSupply);

    double newPrice;
    if (transactionType == 'buy') {
      newPrice = crypto.currentPrice * (1 + impact);
    } else {
      newPrice = crypto.currentPrice * (1 - impact);
    }

    // Limites journalières
    final dailyReferencePrice = _getDailyReferencePrice(crypto);
    final maxDaily = dailyReferencePrice * (1 + crypto.dailyMaxChange);
    final minDaily = dailyReferencePrice * (1 + crypto.dailyMinChange);

    newPrice = newPrice.clamp(minDaily, maxDaily);

    // Limites absolues pour crypto
    return newPrice.clamp(0.01, 1000000.0);
  }

  double _getDailyReferencePrice(CryptoCurrency crypto) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final todayPrices = crypto.priceHistory.where(
          (h) => h.timestamp.isAfter(todayStart) &&
          h.transactionType != 'initial' &&
          h.transactionType != 'current',
    ).toList();

    return todayPrices.isNotEmpty ? todayPrices.first.price : crypto.currentPrice;
  }

  // ✅ VÉRIFICATIONS DE SÉCURITÉ
  Future<VolumeCheckResult> _checkInstantVolume(
      String cryptoId,
      double quantity,
      ) async {
    final last5min = DateTime.now().subtract(Duration(minutes: 5));

    final recentTransactions = await _firestore
        .collection('crypto_transactions')
        .where('cryptoId', isEqualTo: cryptoId)
        .where('date', isGreaterThan: last5min)
        .get();

    final totalVolume = recentTransactions.docs.fold<double>(
      0,
          (sum, doc) => sum + ((doc['quantity'] ?? 0) as num).toDouble(),
    );

    final cryptoDoc = await _firestore.collection('cryptos').doc(cryptoId).get();
    final cryptoData = CryptoCurrency.fromFirestore(cryptoDoc);

    // Si plus de 25% du volume échangé en 5 min → bloquer
    final volumeRatio = (totalVolume + quantity) / cryptoData.circulatingSupply;

    if (volumeRatio > 0.25) return VolumeCheckResult(allowed: false, waitTime: 5);
    if (volumeRatio > 0.15) return VolumeCheckResult(allowed: false, waitTime: 2);

    return VolumeCheckResult(allowed: true);
  }

  Future<double> _checkCryptoConcentration(String cryptoId) async {
    final allPortfolios = await _firestore.collection('crypto_portfolios').get();
    double totalOwned = 0;

    for (final portfolioDoc in allPortfolios.docs) {
      final portfolio = CryptoPortfolio.fromFirestore(portfolioDoc);
      final crypto = portfolio.ownedCryptos.firstWhere(
            (c) => c.cryptoId == cryptoId,
        orElse: () => OwnedCrypto(
          cryptoId: cryptoId,
          quantity: 0,
          averageBuyPrice: 0,
        ),
      );
      totalOwned += crypto.quantity;
    }

    final cryptoDoc = await _firestore.collection('cryptos').doc(cryptoId).get();
    final totalSupply = CryptoCurrency.fromFirestore(cryptoDoc).circulatingSupply;

    return totalOwned / totalSupply;
  }

  Future<FinancialImpact> _calculateFinancialImpact(
      CryptoCurrency crypto,
      double quantity,
      double newPrice,
      String type,
      ) async {
    final priceDifference = (newPrice - crypto.currentPrice).abs();
    final priceImpact = priceDifference / crypto.currentPrice;
    final potentialLoss = priceDifference * quantity;

    // Seuils de risque adaptés pour crypto
    if (priceImpact > 0.08 || quantity > crypto.circulatingSupply * 0.1) {
      return FinancialImpact(
        riskLevel: RiskLevel.high,
        potentialLoss: potentialLoss,
      );
    }
    if (priceImpact > 0.04 || quantity > crypto.circulatingSupply * 0.05) {
      return FinancialImpact(
        riskLevel: RiskLevel.medium,
        potentialLoss: potentialLoss,
      );
    }

    return FinancialImpact(riskLevel: RiskLevel.low, potentialLoss: 0);
  }

  // ✅ VÉRIFICATIONS AVANT TRANSACTION
  Future<SecurityCheckResult> _performSecurityChecksBeforeTransaction(
      String cryptoId,
      double quantity,
      String userId,
      )
  async {
    try {
      // 1. Vérifier si la crypto existe
      final cryptoDoc = await _firestore.collection('cryptos').doc(cryptoId).get();
      if (!cryptoDoc.exists) {
        return SecurityCheckResult(
          allowed: false,
          errorMessage: 'Crypto non trouvée',
        );
      }

      final currentCrypto = CryptoCurrency.fromFirestore(cryptoDoc);

      // 2. Vérification volume instantané
      final volumeCheck = await _checkInstantVolume(cryptoId, quantity);
      if (!volumeCheck.allowed) {
        return SecurityCheckResult(
          allowed: false,
          errorMessage: 'Volume d\'achat trop important. Attendez un instant',
        );
      }

      // 3. Vérification concentration
      final cryptoConcentration = await _checkCryptoConcentration(cryptoId);
      if (cryptoConcentration > 0.4) {
        return SecurityCheckResult(
          allowed: false,
          errorMessage: 'Concentration de crypto trop élevée. Achat temporairement suspendu',
        );
      }

      // 4. Calcul du prix estimé et impact financier
      final estimatedPrice = calculateNewPrice(currentCrypto, quantity, 'buy');
      final financialImpact = await _calculateFinancialImpact(
        currentCrypto,
        quantity,
        estimatedPrice,
        'buy',
      );

      if (financialImpact.riskLevel == RiskLevel.high) {
        return SecurityCheckResult(
          allowed: false,
          errorMessage: 'Impact financier trop important. Réduisez la quantité',
          riskLevel: financialImpact.riskLevel,
        );
      }

      // 5. Vérification solde approximative
      final portfolioDoc = await _firestore.collection('crypto_portfolios').doc(userId).get();
      if (!portfolioDoc.exists) {
        return SecurityCheckResult(
          allowed: false,
          errorMessage: 'Portefeuille non trouvé',
        );
      }

      final portfolio = CryptoPortfolio.fromFirestore(portfolioDoc);
      final estimatedCost = currentCrypto.currentPrice * quantity * (1 + _commissionRateByCrypto);

      if (portfolio.balance < estimatedCost) {
        return SecurityCheckResult(
          allowed: false,
          errorMessage: 'Solde insuffisant. Il vous manque ${(estimatedCost - portfolio.balance).toStringAsFixed(2)} FCFA',
        );
      }



      return SecurityCheckResult(
        allowed: true,
        riskLevel: financialImpact.riskLevel,
        estimatedPrice: estimatedPrice,
      );
    } catch (e) {
      print('Erreur lors des vérifications de sécurité: ${e.toString()}');
      return SecurityCheckResult(
        allowed: false,
        errorMessage: 'Erreur lors des vérifications de sécurité: ${e.toString()}',
      );
    }
  }

  Future<SecurityCheckResult> _performSellSecurityChecksBeforeTransaction(
      String cryptoId,
      double quantity,
      String userId,
      ) async {
    try {
      // 1. Vérifier si l'utilisateur possède la crypto
      final portfolioDoc = await _firestore.collection('crypto_portfolios').doc(userId).get();
      if (!portfolioDoc.exists) {
        return SecurityCheckResult(
          allowed: false,
          errorMessage: 'Portefeuille non trouvé',
        );
      }

      final portfolio = CryptoPortfolio.fromFirestore(portfolioDoc);
      final owned = portfolio.ownedCryptos.firstWhere(
            (c) => c.cryptoId == cryptoId,
        orElse: () => OwnedCrypto(
          cryptoId: cryptoId,
          quantity: 0,
          averageBuyPrice: 0,
        ),
      );

      if (owned.quantity < quantity) {
        return SecurityCheckResult(
          allowed: false,
          errorMessage: 'Quantité insuffisante. Vous possédez seulement ${owned.quantity} unités',
        );
      }

      // 2. Vérification volume instantané
      final volumeCheck = await _checkInstantVolume(cryptoId, quantity);
      if (!volumeCheck.allowed) {
        return SecurityCheckResult(
          allowed: false,
          errorMessage: 'Volume de vente trop important. Attendez ${volumeCheck.waitTime} minutes',
        );
      }

      // 3. Vérifier si la crypto existe
      final cryptoDoc = await _firestore.collection('cryptos').doc(cryptoId).get();
      if (!cryptoDoc.exists) {
        return SecurityCheckResult(
          allowed: false,
          errorMessage: 'Crypto non trouvée',
        );
      }

      final currentCrypto = CryptoCurrency.fromFirestore(cryptoDoc);

      // 4. Calcul du prix estimé et impact financier
      final estimatedPrice = calculateNewPrice(currentCrypto, quantity, 'sell');
      final financialImpact = await _calculateFinancialImpact(
        currentCrypto,
        quantity,
        estimatedPrice,
        'sell',
      );

      if (financialImpact.riskLevel == RiskLevel.high) {
        return SecurityCheckResult(
          allowed: false,
          errorMessage: 'Impact financier trop important. Réduisez la quantité',
          riskLevel: financialImpact.riskLevel,
        );
      }

      // 5. Vérification période de blocage après achat
      final canSell = await _checkSellTimeRestrictions(userId, cryptoId);
      if (!canSell.allowed) {
        return SecurityCheckResult(
          allowed: false,
          errorMessage: canSell.errorMessage,
        );
      }

      return SecurityCheckResult(
        allowed: true,
        riskLevel: financialImpact.riskLevel,
        estimatedPrice: estimatedPrice,
      );
    } catch (e) {
      print('Erreur lors des vérifications de sécurité: ${e.toString()}');

      return SecurityCheckResult(
        allowed: false,
        errorMessage: 'Erreur lors des vérifications de sécurité: ${e.toString()}',
      );
    }
  }

  Future<SellCheckResult> _checkSellTimeRestrictions(String userId, String cryptoId) async {
    try {
      final now = DateTime.now();
      final twoHoursAgo = now.subtract(Duration(hours: 2));

      // Vérifier les achats récents de cette crypto par cet utilisateur
      final recentPurchases = await _firestore
          .collection('crypto_transactions')
          .where('userId', isEqualTo: userId)
          .where('cryptoId', isEqualTo: cryptoId)
          .where('type', isEqualTo: 'buy')
          .where('date', isGreaterThan: twoHoursAgo)
          .get();

      if (recentPurchases.docs.isNotEmpty) {
        final lastPurchase = recentPurchases.docs.first;
        final purchaseDate = (lastPurchase['date'] as Timestamp).toDate();
        final timeSincePurchase = now.difference(purchaseDate);
        final remainingTime = Duration(hours: 2).inMinutes - timeSincePurchase.inMinutes;

        if (remainingTime > 0) {
          return SellCheckResult(
            allowed: false,
            errorMessage: 'Vous devez attendre un moment avant de vendre cette crypto (période de blocage anti-manipulation)',
          );
        }
      }

      return SellCheckResult(allowed: true);
    } catch (e) {
      print('Erreur vérification période blocage: $e');

      debugPrint('Erreur vérification période blocage: $e');
      return SellCheckResult(allowed: true);
    }
  }

  // ✅ FONCTION D'ACHAT SÉCURISÉE POUR CRYPTO
  Future<void> buyCrypto(BuildContext _context) async {
    final user = _auth.currentUser;
    if (user == null || _crypto == null) {
      _errorMessage = 'Utilisateur non connecté ou crypto non chargée';
      notifyListeners();
      return;
    }

    if (_selectedQuantity <= 0) {
      _errorMessage = 'Quantité invalide';
      notifyListeners();
      return;
    }

    _isBuying = true;
    notifyListeners();

    try {
      // Vérifications de sécurité
      final securityCheck = await _performSecurityChecksBeforeTransaction(
        cryptoId,
        _selectedQuantity,
        user.uid,
      );
      if (!securityCheck.allowed) {
        throw securityCheck.errorMessage!;
      }

      // Transaction Firestore
      await _firestore.runTransaction((transaction) async {
        // Vérifications de base
        final portfolioDoc = await transaction.get(
          _firestore.collection('crypto_portfolios').doc(user.uid),
        );
        if (!portfolioDoc.exists) {
          throw 'Veuillez créer un portefeuille avant de trader';
        }
        final portfolio = CryptoPortfolio.fromFirestore(portfolioDoc);

        final cryptoDoc = await transaction.get(
          _firestore.collection('cryptos').doc(cryptoId),
        );
        if (!cryptoDoc.exists) {
          throw 'Crypto non trouvée';
        }
        final currentCrypto = CryptoCurrency.fromFirestore(cryptoDoc);

        // Limite par transaction (1.6% du supply)
        final double maxPurchaseRatio = 0.016;
        final double purchaseRatio = _selectedQuantity / currentCrypto.circulatingSupply;
        if (purchaseRatio > maxPurchaseRatio) {
          final double maxAllowed = (currentCrypto.circulatingSupply * maxPurchaseRatio);
          throw 'Achat maximum par transaction dépassé. Maximum: ${maxAllowed.toStringAsFixed(2)} unités';
        }

        // Calcul du prix
        final newPrice = calculateNewPrice(
          currentCrypto,
          _selectedQuantity,
          'buy',
        );

        // Calcul des coûts
        final totalCostBeforeCommission = currentCrypto.currentPrice * _selectedQuantity;
        final commission = totalCostBeforeCommission * _commissionRateByCrypto;
        final totalCost = totalCostBeforeCommission + commission;

        if (portfolio.balance < totalCost) {
          throw 'Solde insuffisant. Il vous manque ${(totalCost - portfolio.balance).toStringAsFixed(2)} FCFA';
        }


        // Mise à jour de la crypto avec historique
        final updatedPriceHistory = List<PriceHistory>.from(currentCrypto.priceHistory);
        updatedPriceHistory.add(
          PriceHistory(
            price: newPrice,
            timestamp: DateTime.now(),
            transactionType: 'buy',
            quantity: _selectedQuantity,
          ),
        );

        transaction.update(
          _firestore.collection('cryptos').doc(cryptoId),
          {
            'currentPrice': newPrice,
            'lastUpdated': Timestamp.now(),
            'priceHistory': updatedPriceHistory.map((h) => h.toMap()).toList(),
          },
        );

        // Mise à jour du portefeuille
        final updatedOwnedCryptos = _updateOwnedCryptos(
          portfolio.ownedCryptos,
          cryptoId,
          _selectedQuantity,
          currentCrypto.currentPrice,
        );

        transaction.update(_firestore.collection('crypto_portfolios').doc(user.uid), {
          'balance': FieldValue.increment(-totalCost),
          'ownedCryptos': updatedOwnedCryptos.map((e) => e.toMap()).toList(),
          'totalValue': FieldValue.increment(totalCostBeforeCommission),
        });

        // Enregistrement surveillance
        final surveillanceRef = _firestore.collection('crypto_surveillance').doc();
        transaction.set(surveillanceRef, {
          'userId': user.uid,
          'cryptoId': cryptoId,
          'quantity': _selectedQuantity,
          'type': 'buy',
          'price': newPrice,
          'riskLevel': securityCheck.riskLevel.toString(),
          'timestamp': DateTime.now(),
          'ipHash': 'recorded-later',
        });

        // Commission
        final appDefaultRef = _firestore.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT');
        transaction.update(appDefaultRef, {
          'solde_commission_crypto': FieldValue.increment(commission),
        });

        // Transaction
        final transactionRef = _firestore.collection('crypto_transactions').doc();
        transaction.set(
          transactionRef,
          CryptoTransaction(
            id: transactionRef.id,
            userId: user.uid,
            cryptoId: cryptoId,
            unitPrice: currentCrypto.currentPrice,
            quantity: _selectedQuantity,
            date: DateTime.now(),
            type: TransactionType.buy,
            profit: 0,
            commission: commission,
          ).toMap(),
        );

        // Mise à jour locale
        _crypto = currentCrypto.copyWith(
          currentPrice: newPrice,
          lastUpdated: DateTime.now(),
          priceHistory: updatedPriceHistory,
        );

        _ownedCrypto = updatedOwnedCryptos.firstWhere(
              (c) => c.cryptoId == cryptoId,
        );
      });

      // Actions post-transaction
      await _recordIpAddress(user.uid, cryptoId);

      // Points pour investissement


      _errorMessage = '';
      notifyListeners();

    } catch (e) {
      await _handleBuyError(e, user.uid);
    } finally {
      _isBuying = false;
      notifyListeners();
    }
  }

  // ✅ FONCTION DE VENTE SÉCURISÉE POUR CRYPTO
  Future<void> sellCrypto() async {
    final user = _auth.currentUser;
    if (user == null || _crypto == null || _ownedCrypto == null) {
      _errorMessage = 'Action non autorisée';
      notifyListeners();
      return;
    }

    _isSelling = true;
    notifyListeners();

    try {
      final securityCheck = await _performSellSecurityChecksBeforeTransaction(
        cryptoId,
        _selectedQuantity,
        user.uid,
      );
      if (!securityCheck.allowed) {
        throw securityCheck.errorMessage!;
      }

      await _firestore.runTransaction((transaction) async {
        final portfolioDoc = await transaction.get(
          _firestore.collection('crypto_portfolios').doc(user.uid),
        );
        if (!portfolioDoc.exists) {
          throw 'Portefeuille non trouvé';
        }
        final portfolio = CryptoPortfolio.fromFirestore(portfolioDoc);

        final owned = portfolio.ownedCryptos.firstWhere(
              (c) => c.cryptoId == cryptoId,
          orElse: () => throw 'Vous ne possédez pas cette crypto',
        );

        if (owned.quantity < _selectedQuantity) {
          throw 'Quantité insuffisante. Vous possédez seulement ${owned.quantity} unités';
        }

        final cryptoDoc = await transaction.get(
          _firestore.collection('cryptos').doc(cryptoId),
        );
        final currentCrypto = CryptoCurrency.fromFirestore(cryptoDoc);

        final newPrice = calculateNewPrice(
          currentCrypto,
          _selectedQuantity,
          'sell',
        );

        final grossAmount = currentCrypto.currentPrice * _selectedQuantity;
        final commission = grossAmount * _commissionRate;
        final netAmount = grossAmount - commission;
        final profit = (currentCrypto.currentPrice - owned.averageBuyPrice) * _selectedQuantity;

        // Mise à jour crypto
        final updatedPriceHistory = List<PriceHistory>.from(currentCrypto.priceHistory);
        updatedPriceHistory.add(
          PriceHistory(
            price: newPrice,
            timestamp: DateTime.now(),
            transactionType: 'sell',
            quantity: _selectedQuantity,
          ),
        );

        transaction.update(
          _firestore.collection('cryptos').doc(cryptoId),
          {
            'currentPrice': newPrice,
            'lastUpdated': Timestamp.now(),
            'priceHistory': updatedPriceHistory.map((h) => h.toMap()).toList(),
          },
        );

        // Mise à jour portefeuille
        final updatedOwnedCryptos = List<OwnedCrypto>.from(portfolio.ownedCryptos);
        final existingIndex = updatedOwnedCryptos.indexWhere((c) => c.cryptoId == cryptoId);

        if (existingIndex >= 0) {
          final existing = updatedOwnedCryptos[existingIndex];
          final newQuantity = existing.quantity - _selectedQuantity;

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
          'balance': FieldValue.increment(netAmount),
          'ownedCryptos': updatedOwnedCryptos.map((e) => e.toMap()).toList(),
          'totalValue': FieldValue.increment(netAmount),
        });

        // Surveillance
        final surveillanceRef = _firestore.collection('crypto_surveillance').doc();
        transaction.set(surveillanceRef, {
          'userId': user.uid,
          'cryptoId': cryptoId,
          'quantity': _selectedQuantity,
          'type': 'sell',
          'price': newPrice,
          'riskLevel': securityCheck.riskLevel.toString(),
          'timestamp': DateTime.now(),
          'ipHash': 'recorded-later',
        });

        // Commission
        final appDefaultRef = _firestore.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT');
        transaction.update(appDefaultRef, {
          'solde_commission_crypto': FieldValue.increment(commission),
        });

        // Transaction
        final transactionRef = _firestore.collection('crypto_transactions').doc();
        transaction.set(
          transactionRef,
          CryptoTransaction(
            id: transactionRef.id,
            userId: user.uid,
            cryptoId: cryptoId,
            unitPrice: currentCrypto.currentPrice,
            quantity: _selectedQuantity,
            date: DateTime.now(),
            type: TransactionType.sell,
            profit: profit,
            commission: commission,
          ).toMap(),
        );

        // Mise à jour locale
        _crypto = currentCrypto.copyWith(
          currentPrice: newPrice,
          lastUpdated: DateTime.now(),
          priceHistory: updatedPriceHistory,
        );

        if (_selectedQuantity == owned.quantity) {
          _ownedCrypto = null;
        } else {
          _ownedCrypto = OwnedCrypto(
            cryptoId: cryptoId,
            quantity: owned.quantity - _selectedQuantity,
            averageBuyPrice: owned.averageBuyPrice,
          );
        }
      });

      await _recordIpAddress(user.uid, cryptoId);
      _errorMessage = '';
      notifyListeners();

    } catch (e) {
      await _handleSellError(e, user.uid);
    } finally {
      _isSelling = false;
      notifyListeners();
    }
  }
  void _showInsufficientBalanceModal(BuildContext context, double missingAmount) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Solde insuffisant'),
          content: Text(
            'Vous n’avez pas assez de solde pour cette transaction.\nIl vous manque ${missingAmount.toStringAsFixed(2)} FCFA',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // fermer le modal
              },
              child: Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // fermer le modal
                Navigator.pushNamed(context, '/portfolio'); // rediriger vers portefeuille
              },
              child: Text('Recharger'),
            ),
          ],
        );
      },
    );
  }

  // ✅ GESTION DES ERREURS
  Future<void> _handleBuyError(dynamic error, String userId) async {
    String errorMessage;

    if (error is FirebaseException) {
      errorMessage = 'Erreur Firebase: ${error.code} - ${error.message}';
    } else if (error is String) {
      errorMessage = error;
    } else {
      errorMessage = error.toString();
    }

    debugPrint('Erreur achat crypto: $errorMessage');

    // Ne pas afficher de snackbar pour les soldes insuffisants
    if (errorMessage.contains('Solde insuffisant')) {
      _errorMessage = errorMessage;
      notifyListeners();
      return;
    }

    // Enregistrer l'erreur pour analyse
    await _recordError(userId, errorMessage, 'buy');

    _errorMessage = errorMessage;
    notifyListeners();
  }

  Future<void> _handleSellError(dynamic error, String userId) async {
    String errorMessage;

    if (error is FirebaseException) {
      errorMessage = 'Erreur Firebase: ${error.code} - ${error.message}';
    } else if (error is String) {
      errorMessage = error;
    } else {
      errorMessage = error.toString();
    }

    debugPrint('Erreur vente crypto: $errorMessage');

    // Enregistrer l'erreur pour analyse
    await _recordError(userId, errorMessage, 'sell');

    _errorMessage = errorMessage;
    notifyListeners();
  }

  // ✅ MÉTHODES UTILITAIRES
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
      updated.add(
        OwnedCrypto(
          cryptoId: cryptoId,
          quantity: quantity,
          averageBuyPrice: price,
        ),
      );
    }

    return updated;
  }

  Future<void> fetchCryptoDetails() async {
    try {
      print('Chargement cryptoId: ${cryptoId}');
      _isLoading = true;
      notifyListeners();

      final doc = await _firestore.collection('cryptos').doc(cryptoId).get();
      if (doc.exists) {
        _crypto = CryptoCurrency.fromFirestore(doc);
      } else {
        _errorMessage = 'Crypto non trouvée';
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Erreur lors du chargement: ${e.toString()}');
      _errorMessage = 'Erreur lors du chargement: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTransactions() async {
    try {
      final snapshot = await _firestore
          .collection('crypto_transactions')
          .where('cryptoId', isEqualTo: cryptoId)
          .orderBy('date', descending: true)
          .limit(50)
          .get();

      _transactions.clear();
      _transactions.addAll(
        snapshot.docs.map((doc) => CryptoTransaction.fromFirestore(doc)),
      );
      notifyListeners();
    } catch (e) {
      print('Erreur transactions: ${e.toString()}');

      _errorMessage = 'Erreur transactions: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> checkOwnedCrypto() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final portfolioDoc = await _firestore.collection('crypto_portfolios').doc(user.uid).get();
      if (portfolioDoc.exists) {
        final portfolio = CryptoPortfolio.fromFirestore(portfolioDoc);
        final owned = portfolio.ownedCryptos.firstWhere(
              (c) => c.cryptoId == cryptoId,
        );
        _ownedCrypto = owned;
        notifyListeners();
      }
    } catch (e) {
      // L'utilisateur ne possède pas cette crypto
      _ownedCrypto = null;
      notifyListeners();
    }
  }

  // ✅ MÉTHODES DE SURVEILLANCE
  Future<void> _recordIpAddress(String userId, String cryptoId) async {
    try {
      final ip = await _getUserIp();
      final ipHash = _hashIp(ip);

      final surveillanceQuery = await _firestore
          .collection('crypto_surveillance')
          .where('userId', isEqualTo: userId)
          .where('cryptoId', isEqualTo: cryptoId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (surveillanceQuery.docs.isNotEmpty) {
        final lastDoc = surveillanceQuery.docs.first;
        await _firestore
            .collection('crypto_surveillance')
            .doc(lastDoc.id)
            .update({'ipHash': ipHash, 'realIpRecordedAt': DateTime.now()});
      }
    } catch (e) {
      debugPrint('Erreur enregistrement IP: $e');
    }
  }

  Future<void> _recordError(String userId, String error, String type) async {
    try {
      await _firestore.collection('crypto_trading_errors').add({
        'userId': userId,
        'error': error,
        'type': type,
        'timestamp': DateTime.now(),
        'ipHash': _hashIp(await _getUserIp()),
      });
    } catch (e) {
      debugPrint('Erreur enregistrement erreur: $e');
    }
  }

  String _hashIp(String ip) {
    return md5.convert(utf8.encode(ip)).toString();
  }

  Future<String> _getUserIp() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      return response.body;
    } catch (e) {
      return 'unknown';
    }
  }

  // ✅ MÉTHODES DE RÉINITIALISATION
  void resetState() {
    _errorMessage = '';
    _isBuying = false;
    _isSelling = false;
    _selectedQuantity = 1.0;
    notifyListeners();
  }

  void refreshData() {
    fetchCryptoDetails();
    fetchTransactions();
    checkOwnedCrypto();
  }

  // ✅ DESTRUCTEUR
  @override
  void dispose() {
    super.dispose();
  }
}