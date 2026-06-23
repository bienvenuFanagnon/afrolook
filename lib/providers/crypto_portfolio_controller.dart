// controllers/crypto_portfolio_controller.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/crypto_model.dart';
import '../models/model_data.dart';

class CryptoPortfolioProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Observables
  CryptoPortfolio? _portfolio;
  UserData? _currentUser;
  List<CryptoCurrency> _allCryptos = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Getters
  CryptoPortfolio? get portfolio => _portfolio;
  UserData? get currentUser => _currentUser;
  List<CryptoCurrency> get allCryptos => _allCryptos;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // Text controllers pour les dialogs
  final TextEditingController _rechargeAmountController = TextEditingController();
  final TextEditingController _withdrawalAmountController = TextEditingController();

  TextEditingController get rechargeAmountController => _rechargeAmountController;
  TextEditingController get withdrawalAmountController => _withdrawalAmountController;

  @override
  void dispose() {
    _rechargeAmountController.dispose();
    _withdrawalAmountController.dispose();
    super.dispose();
  }

  Future<void> initializeData() async {
    await fetchUserData();
    await fetchPortfolio();
    await fetchAllCryptos();
  }

  Future<void> fetchUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('Users').doc(user.uid).get();
      if (userDoc.exists) {
        _currentUser = UserData.fromJson(userDoc.data()!);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des données utilisateur: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> fetchPortfolio({bool createIfNotExists = true}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        printVm("❌ Aucun utilisateur connecté pour charger le portefeuille");
        return;
      }

      printVm("👤 Chargement du portefeuille pour l'utilisateur: ${user.email} (${user.uid})");

      final portfolioDoc = await _firestore.collection('crypto_portfolios').doc(user.uid).get();

      if (portfolioDoc.exists) {
        _portfolio = CryptoPortfolio.fromFirestore(portfolioDoc);
        printVm("✅ Portefeuille existant chargé - Solde: ${_portfolio!.balance} FCFA, ${_portfolio!.ownedCryptos.length} cryptos");
      } else {
        printVm("⚠️ Aucun portefeuille trouvé pour l'utilisateur");

        if (createIfNotExists) {
          printVm("🔄 Création d'un nouveau portefeuille...");

          final newPortfolio = CryptoPortfolio(
            userId: user.uid,
            balance: 0.0,
            ownedCryptos: [],
            totalValue: 0.0,
            dailyProfitLoss: 0.0,
            totalProfitLoss: 0.0,
          );

          // Sauvegarder dans Firebase
          await _firestore.collection('crypto_portfolios').doc(user.uid).set(newPortfolio.toMap());

          _portfolio = newPortfolio;
          printVm("🎉 Nouveau portefeuille créé avec succès dans Firebase");
        } else {
          printVm("ℹ️ Création de portefeuille désactivée, portfolio restera null");
          _portfolio = null;
        }
      }

      notifyListeners();

    } catch (e) {
      printVm('❌ Erreur lors du chargement/création du portefeuille: ${e.toString()}');
      _errorMessage = 'Erreur lors du chargement du portefeuille: ${e.toString()}';
      notifyListeners();

      // Relancer l'exception pour une gestion plus fine si nécessaire
      throw e;
    }
  }
  Future<void> fetchAllCryptos() async {
    try {
      final snapshot = await _firestore.collection('cryptos').get();
      _allCryptos = snapshot.docs.map((doc) => CryptoCurrency.fromFirestore(doc)).toList();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des cryptos: ${e.toString()}';
      notifyListeners();
    }
  }

  CryptoCurrency? getCryptoById(String cryptoId) {
    try {
      return _allCryptos.firstWhere((crypto) => crypto.id == cryptoId);
    } catch (e) {
      return null;
    }
  }

  // Méthodes de recharge et retrait
  Future<void> rechargePortfolio(double amount) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Utilisateur non connecté';

      if (amount <= 0) throw 'Le montant doit être supérieur à 0';

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('Users').doc(user.uid);
        final portfolioRef = _firestore.collection('crypto_portfolios').doc(user.uid);
        final transRef = _firestore.collection('crypto_fund_transactions').doc();

        // 🔹 1. LIRE AVANT TOUTE ÉCRITURE
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) throw 'Utilisateur non trouvé';

        final currentUserBalance =
        (userDoc.data()?['votre_solde_principal'] ?? 0).toDouble();

        if (currentUserBalance < amount) {
          throw 'Solde insuffisant. Vous avez $currentUserBalance FCFA';
        }

        final portfolioDoc = await transaction.get(portfolioRef);

        // 🔹 2. ÉCRITURES APRÈS TOUS LES READS
        transaction.update(userRef, {
          'votre_solde_principal': FieldValue.increment(-amount),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });

        if (portfolioDoc.exists) {
          transaction.update(portfolioRef, {
            'balance': FieldValue.increment(amount),
            // 'totalValue': FieldValue.increment(amount),
          });
        } else {
          transaction.set(portfolioRef, {
            'userId': user.uid,
            'balance': amount,
            'ownedCryptos': [],
            'totalValue': 0.0,
            'dailyProfitLoss': 0.0,
            'totalProfitLoss': 0.0,
          });
        }

        transaction.set(transRef, {
          'userId': user.uid,
          'type': 'recharge',
          'amount': amount,
          'status': 'completed',
          'timestamp': DateTime.now(),
          'description': 'Recharge du portefeuille crypto',
        });
      });

      await fetchUserData();
      await fetchPortfolio();
      _rechargeAmountController.clear();
      notifyListeners();

    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> withdrawFromPortfolio(double amount) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Utilisateur non connecté';

      if (amount <= 0) throw 'Le montant doit être supérieur à 0';

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('Users').doc(user.uid);
        final portfolioRef = _firestore.collection('crypto_portfolios').doc(user.uid);
        final transRef = _firestore.collection('crypto_fund_transactions').doc();

        // 🔹 1. READS
        final portfolioDoc = await transaction.get(portfolioRef);
        if (!portfolioDoc.exists) throw 'Portefeuille non trouvé';

        final balance = (portfolioDoc.data()?['balance'] ?? 0).toDouble();
        if (balance < amount) {
          throw 'Solde insuffisant dans le portefeuille. Vous avez $balance FCFA';
        }

        // 🔹 2. WRITES
        transaction.update(portfolioRef, {
          'balance': FieldValue.increment(-amount),
          'totalValue': FieldValue.increment(-amount),
        });

        transaction.update(userRef, {
          'votre_solde_principal': FieldValue.increment(amount),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });

        transaction.set(transRef, {
          'userId': user.uid,
          'type': 'retrait',
          'amount': amount,
          'status': 'completed',
          'timestamp': DateTime.now(),
          'description': 'Retrait du portefeuille crypto',
        });
      });

      await fetchUserData();
      await fetchPortfolio();
      _withdrawalAmountController.clear();
      notifyListeners();

    } catch (e) {
      throw e.toString();
    }
  }


  // Méthodes pour afficher les dialogs
  void showAddFundsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A202C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Recharger le Portefeuille',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Solde disponible: ${_currentUser?.votre_solde_principal ?? 0} FCFA',
              style: TextStyle(color: Colors.green, fontSize: 14),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _rechargeAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant (FCFA)',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF00B894)),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ANNULER', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(_rechargeAmountController.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                await rechargePortfolio(amount);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Portefeuille rechargé avec succès!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF00B894)),
            child: Text('CONFIRMER'),
          ),
        ],
      ),
    );
  }

  void showWithdrawalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A202C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Encaisser vers Mon Compte',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Solde du portefeuille: ${_portfolio?.balance ?? 0} FCFA',
              style: TextStyle(color: Color(0xFF00B894), fontSize: 14),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _withdrawalAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant (FCFA)',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF00B894)),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ANNULER', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(_withdrawalAmountController.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                await withdrawFromPortfolio(amount);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Retrait effectué avec succès!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF00B894)),
            child: Text('CONFIRMER'),
          ),
        ],
      ),
    );
  }

  // Méthode pour rafraîchir toutes les données
  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    await fetchUserData();
    await fetchPortfolio();
    await fetchAllCryptos();

    _isLoading = false;
    notifyListeners();
  }
}