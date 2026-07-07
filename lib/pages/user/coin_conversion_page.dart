import 'package:afrotok/layout/centered_content.dart';
import 'package:flutter/material.dart';

// pages/coins/coin_conversion_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/coin_gift_provider.dart';
import '../../services/coin_gift_service.dart';

class CoinConversionPage extends StatefulWidget {
  const CoinConversionPage({Key? key}) : super(key: key);

  @override
  State<CoinConversionPage> createState() => _CoinConversionPageState();
}

class _CoinConversionPageState extends State<CoinConversionPage> {
  final TextEditingController _coinsController = TextEditingController();
  final double _fcfaRate = 0.4; // 1 pièce = 0.4 FCFA
  bool _isLoading = false;
  int _coinsBalance = 0;
  int _coinsToConvert = 0;
  double _fcfaToGet = 0;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final authPro = Provider.of<UserAuthProvider>(context, listen: false);
    final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    await coinProvider.refreshBalance(authPro.loginUserData!.id!);

    final user = coinProvider.currentUser;
    if (user != null) {
      setState(() {
        _coinsBalance = user.giftCoinsBalance ?? 0;
      });
    }
  }

  void _updateConversion(String value) {
    setState(() {
      _errorMessage = '';

      if (value.isEmpty) {
        _coinsToConvert = 0;
        _fcfaToGet = 0;
        return;
      }

      final parsed = int.tryParse(value);

      if (parsed == null) {
        _errorMessage = 'Veuillez entrer un nombre valide';
        _coinsToConvert = 0;
        _fcfaToGet = 0;
        return;
      }

      if (parsed > _coinsBalance) {
        _errorMessage = 'Solde insuffisant. Maximum : ${_formatNumber(_coinsBalance)} pièces';
        _coinsToConvert = 0;
        _fcfaToGet = 0;
      } else if (parsed < 100) {
        _errorMessage = 'Minimum 100 pièces pour la conversion';
        _coinsToConvert = 0;
        _fcfaToGet = 0;
      } else {
        _coinsToConvert = parsed;
        _fcfaToGet = parsed * _fcfaRate;
      }
    });
  }

// Dans CoinConversionPage
  Future<void> _convertCoins() async {
    if (_coinsToConvert < 100) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);

      final userId = authProvider.loginUserData!.id!;

      await CoinGiftService.convertCoinsToFcfa(
        userId: userId,
        coinsAmount: _coinsToConvert,
        firestore: FirebaseFirestore.instance,
      );

      // // Rafraîchir les données
      // await authProvider.refreshUserData();
      //
      // // Vérifier si le widget est toujours monté avant de mettre à jour l'UI
      // if (!mounted) return;
      //
      // await coinProvider.refreshBalance(userId);
      //
      // if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Conversion réussie !'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      await _loadBalance();
      _coinsController.clear();
      setState(() {
        _coinsToConvert = 0;
        _fcfaToGet = 0;
      });
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur : ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'Convertir pièces en FCFA',
          style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFFD700)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CenteredContent(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte d'information
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('🪙', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Taux de conversion',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '25 pièces = 10 FCFA',
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Solde disponible',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Row(
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            _formatNumber(_coinsBalance),
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Champ de saisie
            const Text(
              'Nombre de pièces à convertir',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _errorMessage.isNotEmpty
                      ? Colors.red.withOpacity(0.5)
                      : const Color(0xFFFFD700).withOpacity(0.3),
                ),
              ),
              child: TextField(
                controller: _coinsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Text('🪙', style: TextStyle(fontSize: 20)),
                  hintText: 'Ex: 100, 500, 1000...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onChanged: _updateConversion,
              ),
            ),

            // Message d'erreur
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),

            const SizedBox(height: 24),

            // Résumé de la conversion
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: _coinsToConvert >= 100
                    ? const LinearGradient(
                  colors: [Color(0xFF00CC66), Color(0xFF00994D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : const LinearGradient(
                  colors: [Color(0xFF333333), Color(0xFF222222)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Vous recevrez',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _coinsToConvert >= 100
                        ? '${_fcfaToGet.toStringAsFixed(0)} FCFA'
                        : '0 FCFA',
                    style: TextStyle(
                      color: _coinsToConvert >= 100 ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_coinsToConvert >= 100)
                    Text(
                      'Soit ${_formatNumber(_coinsToConvert)} pièces',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Bouton Convertir
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (_coinsToConvert >= 100 && !_isLoading)
                    ? _convertCoins
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_coinsToConvert >= 100 && !_isLoading)
                      ? const Color(0xFFFFD700)
                      : Colors.grey,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
                    : const Text(
                  'Convertir maintenant',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Information sur le minimum
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade900.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFFFD700), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ Minimum 100 pièces pour la conversion. Les FCFA seront ajoutés à votre solde principal.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )),
    );
  }

  String _formatNumber(int num) {
    // if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    // if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }
}