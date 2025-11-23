import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/crypto_model.dart';

class CryptoAdminProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form fields
  final TextEditingController _symbolController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emojiController = TextEditingController();
  double _currentPrice = 0.0;
  double _initialPrice = 0.0;
  double _marketCap = 0.0;
  double _circulatingSupply = 0.0;
  double _totalSupply = 0.0;
  String _category = 'DeFi';
  int _rank = 1;
  bool _isTrending = false;
  double _dailyMaxChange = 0.2;
  double _dailyMinChange = -0.2;

  // State
  bool _isUploading = false;
  CryptoCurrency? _cryptoToEdit;

  // Getters
  TextEditingController get symbolController => _symbolController;
  TextEditingController get nameController => _nameController;
  TextEditingController get emojiController => _emojiController;
  double get currentPrice => _currentPrice;
  double get initialPrice => _initialPrice;
  double get marketCap => _marketCap;
  double get circulatingSupply => _circulatingSupply;
  double get totalSupply => _totalSupply;
  String get category => _category;
  int get rank => _rank;
  bool get isTrending => _isTrending;
  double get dailyMaxChange => _dailyMaxChange;
  double get dailyMinChange => _dailyMinChange;
  bool get isUploading => _isUploading;
  CryptoCurrency? get cryptoToEdit => _cryptoToEdit;

  // Setters
  set currentPrice(double value) {
    _currentPrice = value;
    notifyListeners();
  }

  set initialPrice(double value) {
    _initialPrice = value;
    notifyListeners();
  }

  set marketCap(double value) {
    _marketCap = value;
    notifyListeners();
  }

  set circulatingSupply(double value) {
    _circulatingSupply = value;
    notifyListeners();
  }

  set totalSupply(double value) {
    _totalSupply = value;
    notifyListeners();
  }

  set category(String value) {
    _category = value;
    notifyListeners();
  }

  set rank(int value) {
    _rank = value;
    notifyListeners();
  }

  set isTrending(bool value) {
    _isTrending = value;
    notifyListeners();
  }

  set dailyMaxChange(double value) {
    _dailyMaxChange = value;
    notifyListeners();
  }

  set dailyMinChange(double value) {
    _dailyMinChange = value;
    notifyListeners();
  }

  Future<void> createCrypto() async {
    try {
      _isUploading = true;
      notifyListeners();

      // Validation des champs requis
      if (_symbolController.text.isEmpty ||
          _nameController.text.isEmpty ||
          _emojiController.text.isEmpty) {
        throw 'Veuillez remplir tous les champs obligatoires';
      }

      // Calcul automatique du market cap si non fourni
      double calculatedMarketCap = _marketCap;
      if (calculatedMarketCap == 0 && _circulatingSupply > 0) {
        calculatedMarketCap = _currentPrice * _circulatingSupply;
      }

      final cryptoData = {
        'symbol': _symbolController.text.trim().toUpperCase(),
        'name': _nameController.text.trim(),
        'imageUrl': _emojiController.text.trim(), // Stocker l'emoji dans imageUrl
        'currentPrice': _currentPrice,
        'initialPrice': _initialPrice,
        'marketCap': calculatedMarketCap,
        'circulatingSupply': _circulatingSupply,
        'totalSupply': _totalSupply,
        'dailyPriceChange': 0.0,
        'dailyVolume': 0.0,
        'dailyMaxChange': _dailyMaxChange,
        'dailyMinChange': _dailyMinChange,
        'lastUpdated': Timestamp.now(),
        'priceHistory': [],
        'category': _category,
        'rank': _rank,
        'isTrending': _isTrending,
        'emoji': _emojiController.text.trim(), // Champ dédié pour l'emoji
      };

      await _firestore.collection('cryptos').add(cryptoData);

      resetForm();
      _isUploading = false;
      notifyListeners();

    } catch (e) {
      _isUploading = false;
      notifyListeners();
      throw 'Erreur lors de la création de la crypto: ${e.toString()}';
    }
  }

  Future<void> updateCrypto(String cryptoId) async {
    try {
      _isUploading = true;
      notifyListeners();

      // Validation des champs requis
      if (_symbolController.text.isEmpty ||
          _nameController.text.isEmpty ||
          _emojiController.text.isEmpty) {
        throw 'Veuillez remplir tous les champs obligatoires';
      }

      final cryptoData = {
        'symbol': _symbolController.text.trim().toUpperCase(),
        'name': _nameController.text.trim(),
        'imageUrl': _emojiController.text.trim(),
        'currentPrice': _currentPrice,
        'initialPrice': _initialPrice,
        'marketCap': _marketCap,
        'circulatingSupply': _circulatingSupply,
        'totalSupply': _totalSupply,
        'dailyMaxChange': _dailyMaxChange,
        'dailyMinChange': _dailyMinChange,
        'lastUpdated': Timestamp.now(),
        'category': _category,
        'rank': _rank,
        'isTrending': _isTrending,
        'emoji': _emojiController.text.trim(),
      };

      await _firestore.collection('cryptos').doc(cryptoId).update(cryptoData);

      _isUploading = false;
      notifyListeners();

    } catch (e) {
      _isUploading = false;
      notifyListeners();
      throw 'Erreur lors de la mise à jour de la crypto: ${e.toString()}';
    }
  }

  Future<void> loadCryptoForEdit(String cryptoId) async {
    try {
      final doc = await _firestore.collection('cryptos').doc(cryptoId).get();
      if (doc.exists) {
        final crypto = CryptoCurrency.fromFirestore(doc);
        setCryptoToEdit(crypto);
      } else {
        throw 'Crypto non trouvée';
      }
    } catch (e) {
      throw 'Erreur lors du chargement de la crypto: ${e.toString()}';
    }
  }

  void setCryptoToEdit(CryptoCurrency crypto) {
    _cryptoToEdit = crypto;
    _symbolController.text = crypto.symbol;
    _nameController.text = crypto.name;

    // Utiliser le champ emoji si disponible, sinon utiliser imageUrl
    printVm('crypto : ${crypto.toMap()}');
    final emoji = crypto.emoji;
    _emojiController.text = emoji.isNotEmpty ? emoji : '🪙';

    _currentPrice = crypto.currentPrice;
    _initialPrice = crypto.initialPrice;
    _marketCap = crypto.marketCap;
    _circulatingSupply = crypto.circulatingSupply;
    _totalSupply = crypto.totalSupply;
    _category = crypto.category;
    _rank = crypto.rank;
    _isTrending = crypto.isTrending;
    _dailyMaxChange = crypto.dailyMaxChange;
    _dailyMinChange = crypto.dailyMinChange;

    notifyListeners();
  }

  void resetForm() {
    _cryptoToEdit = null;
    _symbolController.clear();
    _nameController.clear();
    _emojiController.clear();
    _currentPrice = 0.0;
    _initialPrice = 0.0;
    _marketCap = 0.0;
    _circulatingSupply = 0.0;
    _totalSupply = 0.0;
    _category = 'DeFi';
    _rank = 1;
    _isTrending = false;
    _dailyMaxChange = 0.2;
    _dailyMinChange = -0.2;
    _isUploading = false;
    notifyListeners();
  }

  // Méthode utilitaire pour pré-remplir avec des valeurs par défaut
  void prefillWithDefaults() {
    if (_symbolController.text.isEmpty &&
        _nameController.text.isEmpty &&
        _emojiController.text.isEmpty) {
      _emojiController.text = '🪙';
      _currentPrice = 100.0;
      _initialPrice = 100.0;
      _circulatingSupply = 10000.0;
      _totalSupply = 100000.0;
      _marketCap = 1000000.0;
      _dailyMaxChange = 0.15;
      _dailyMinChange = -0.15;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }
}