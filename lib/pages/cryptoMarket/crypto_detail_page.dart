// views/crypto/crypto_detail_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:math';
import '../../models/crypto_model.dart';
import '../../providers/crypto_market_provider.dart';
import 'package:provider/provider.dart';

import '../../providers/crypto_trading_controller.dart';
import 'cryptowidgets/crypto_chart_widget.dart';

class CryptoDetailPage extends StatefulWidget {
  final String cryptoId;

  const CryptoDetailPage({Key? key, required this.cryptoId}) : super(key: key);

  @override
  State<CryptoDetailPage> createState() => _CryptoDetailPageState();
}

class _CryptoDetailPageState extends State<CryptoDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _timeFrames = ['1H', '24H', '1S', '1M', '1A'];
  int _selectedTimeFrame = 1; // 24H par défaut
  final Random _random = Random();
  late TextEditingController _quantityController;

  // Données dynamiques pour les activités
  List<Map<String, dynamic>> _marketActivities = [];
  late List<String> _userNames;
  late List<String> _actions;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _quantityController = TextEditingController();
    _initializeDynamicData();
    _generateMarketActivities();

    // Initialiser les données du trading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tradingController = Provider.of<CryptoTradingProvider>(context, listen: false);
      if (tradingController.crypto?.id != widget.cryptoId) {
        tradingController.refreshData();
      } else {
        _updateQuantityController(tradingController);
      }
    });
  }

  void _initializeDynamicData() {
    _userNames = [
      'Fatou Diallo', 'Mohamed Konaté', 'Aïcha Bâ', 'Jean-Paul Martin', 'Marie Dubois',
      'Abdoulaye Sow', 'Sophie Laurent', 'Moussa Traoré', 'Camille Petit', 'Ibrahim Cissé',
      'Élodie Moreau', 'Koffi Mensah', 'Chantal Ngom', 'Pierre Durand', 'Aminata Diop',
      'Luc Bernard', 'Kadiatou Keita', 'Thomas Leroy', 'Nadia Sarr', 'David Muller',
      'Rokhaya Ndiaye', 'Philippe Blanc', 'Mariam Coulibaly', 'Alain Morel', 'Sofia Ben'
    ];

    _actions = [
      'a acheté', 'a vendu', 'a investi dans', 'a échangé', 'a converti en',
      'a ajouté à son portefeuille', 'a retiré', 'a staké', 'a déstaké', 'a tradé',
      'vient d\'acquérir', 'a réalisé un profit sur', 'a doublé son investissement sur'
    ];
  }

  void _generateMarketActivities() {
    _marketActivities = List.generate(5, (index) {
      final userName = _userNames[_random.nextInt(_userNames.length)];
      final action = _actions[_random.nextInt(_actions.length)];
      final amount = (_random.nextDouble() * 500 + 50).toStringAsFixed(0);
      final time = '${_random.nextInt(59) + 1} min';
      final isBuy = _random.nextDouble() > 0.4;

      return {
        'user': userName.split(' ')[0] + ' ${userName.split(' ')[1][0]}.',
        'action': action,
        'amount': amount,
        'time': time,
        'fullName': userName,
        'type': isBuy ? 'buy' : 'sell',
      };
    });
  }

  void _updateQuantityController(CryptoTradingProvider tradingController) {
    _quantityController.text = tradingController.selectedQuantity.toStringAsFixed(2);
  }

  // Calculer le pourcentage de variation réel basé sur l'historique des prix
  double _calculateRealPriceChange(CryptoCurrency crypto, String timeFrame) {
    if (crypto.priceHistory.isEmpty) return crypto.dailyPriceChange;

    final now = DateTime.now();
    DateTime startTime;

    switch (timeFrame) {
      case '1H':
        startTime = now.subtract(Duration(hours: 1));
        break;
      case '24H':
        startTime = now.subtract(Duration(hours: 24));
        break;
      case '1S':
        startTime = now.subtract(Duration(days: 7));
        break;
      case '1M':
        startTime = now.subtract(Duration(days: 30));
        break;
      case '1A':
        startTime = now.subtract(Duration(days: 365));
        break;
      default:
        startTime = now.subtract(Duration(hours: 24));
    }

    // Trouver le prix le plus proche dans l'historique
    final historicalPrices = crypto.priceHistory
        .where((point) => point.timestamp.isAfter(startTime))
        .toList();

    if (historicalPrices.isEmpty) return crypto.dailyPriceChange;

    // Prendre le prix le plus ancien dans la période
    historicalPrices.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final startPrice = historicalPrices.first.price;
    final currentPrice = crypto.currentPrice;

    // Calculer la variation en pourcentage
    return ((currentPrice - startPrice) / startPrice);
  }

  String _getTrendDescription(double changePercent) {
    if (changePercent > 0.05) return '📈 Forte hausse';
    if (changePercent > 0.02) return '📈 Hausse modérée';
    if (changePercent > 0) return '↗️ Légère hausse';
    if (changePercent == 0) return '➡️ Stable';
    if (changePercent > -0.02) return '↘️ Légère baisse';
    if (changePercent > -0.05) return '📉 Baisse modérée';
    return '📉 Forte baisse';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CryptoTradingProvider(widget.cryptoId),
      child: Scaffold(
        backgroundColor: Color(0xFF0F111C),
        body: Consumer<CryptoTradingProvider>(
          builder: (context, tradingController, child) {
            final crypto = tradingController.crypto;

            if (tradingController.isLoading && crypto == null) {
              return _buildLoadingState();
            }

            if (tradingController.errorMessage.isNotEmpty) {
              return _buildErrorState(tradingController);
            }

            if (crypto == null) {
              return _buildNotFoundState();
            }

            // Mettre à jour le controller de quantité si nécessaire
            if (_quantityController.text.isEmpty) {
              _updateQuantityController(tradingController);
            }

            return _buildMainContent(crypto, tradingController);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF00B894)),
          SizedBox(height: 16),
          Text(
            'Chargement des données...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(CryptoTradingProvider controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.warning_2, color: Colors.red, size: 50),
          SizedBox(height: 16),
          Text(
            controller.errorMessage,
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: controller.refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00B894),
            ),
            child: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.search_status, color: Colors.grey, size: 50),
          SizedBox(height: 16),
          Text(
            'Crypto non trouvée',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(CryptoCurrency crypto, CryptoTradingProvider tradingController) {
    // Calculer la variation réelle pour le timeframe sélectionné
    final realPriceChange = _calculateRealPriceChange(crypto, _timeFrames[_selectedTimeFrame]);
    final isPositive = realPriceChange >= 0;
    final trendDescription = _getTrendDescription(realPriceChange);

    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        // Header avec infos principales
        SliverAppBar(
          backgroundColor: Color(0xFF0F111C),
          elevation: 0,
          pinned: true,
          expandedHeight: 240,
          flexibleSpace: _buildCryptoHeader(crypto, isPositive, realPriceChange, trendDescription),
          leading: IconButton(
            icon: Icon(Iconsax.arrow_left_2, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Iconsax.refresh, color: Colors.white),
              onPressed: () {
                tradingController.refreshData();
                _generateMarketActivities();
              },
            ),
          ],
        ),

        // Contenu principal
        SliverToBoxAdapter(
          child: Column(
            children: [
              // Statistiques rapides avec variation réelle
              _buildQuickStats(crypto, realPriceChange, trendDescription),

              // Graphique et timeframe selector
              _buildChartSection(crypto),

              // Contrôles d'achat/vente
              _buildTradeControls(crypto, tradingController),

              // Informations détaillées
              _buildCryptoInfo(crypto),

              // Activités du marché dynamiques
              _buildMarketActivity(),

              // Historique des transactions
              _buildTransactionHistory(tradingController),

              SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCryptoHeader(CryptoCurrency crypto, bool isPositive, double realPriceChange, String trendDescription) {
    return FlexibleSpaceBar(
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A202C),
              Color(0xFF0F111C),
            ],
          ),
        ),
        padding: EdgeInsets.only(top: 100, left: 20, right: 20, bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo/Emoji de la crypto
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF00B894).withOpacity(0.3),
                    Color(0xFF667EEA).withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  _getCryptoEmoji(crypto.symbol),
                  style: TextStyle(fontSize: 32),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crypto.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    crypto.symbol,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${crypto.currentPrice.toStringAsFixed(2)} FCFA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? Color(0xFF00B894).withOpacity(0.2)
                              : Color(0xFFFF4D4D).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPositive ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
                              color: isPositive ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '${(realPriceChange * 100).toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: isPositive ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              trendDescription,
                              style: TextStyle(
                                color: isPositive ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(CryptoCurrency crypto, double realPriceChange, String trendDescription) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2A3649)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Capitalisation', '${_formatNumber(crypto.marketCap)} FCFA'),
              _buildStatItem('Volume 24h', '${_formatNumber(crypto.dailyVolume)} FCFA'),
              _buildStatItem('Rang', '#${crypto.rank}'),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: realPriceChange >= 0
                  ? Color(0xFF00B894).withOpacity(0.1)
                  : Color(0xFFFF4D4D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: realPriceChange >= 0
                    ? Color(0xFF00B894).withOpacity(0.3)
                    : Color(0xFFFF4D4D).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  realPriceChange >= 0 ? Iconsax.trend_up : Iconsax.trend_down,
                  color: realPriceChange >= 0 ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  trendDescription,
                  style: TextStyle(
                    color: realPriceChange >= 0 ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '${_timeFrames[_selectedTimeFrame]} : ${(realPriceChange * 100).toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: realPriceChange >= 0 ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildChartSection(CryptoCurrency crypto) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Timeframe selector
          Container(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _timeFrames.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTimeFrame = index;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedTimeFrame == index
                          ? Color(0xFF00B894)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedTimeFrame == index
                            ? Color(0xFF00B894)
                            : Color(0xFF2A3649),
                      ),
                    ),
                    child: Text(
                      _timeFrames[index],
                      style: TextStyle(
                        color: _selectedTimeFrame == index
                            ? Colors.white
                            : Colors.grey[400],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16),

          // Graphique interactif
          Container(
            height: 300,
            child: CryptoChartWidget(
              priceHistory: crypto.priceHistory,
              selectedTimeFrame: _timeFrames[_selectedTimeFrame],
              isInteractive: true,
            ),
          ),

          // Bouton pour voir en plein écran
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _showFullScreenChart(crypto),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2A3649),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.maximize_2, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Voir en plein écran',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeControls(CryptoCurrency crypto, CryptoTradingProvider tradingController) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF2A3649)),
      ),
      child: Column(
        children: [
          // Quantité selector avec champ de saisie
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quantité',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  // Bouton moins
                  IconButton(
                    icon: Icon(Iconsax.minus_square, color: Colors.white),
                    onPressed: () {
                      if (tradingController.selectedQuantity > 0.01) {
                        tradingController.selectedQuantity = tradingController.selectedQuantity - 0.01;
                        _quantityController.text = tradingController.selectedQuantity.toStringAsFixed(2);
                        setState(() {});
                      }
                    },
                  ),

                  // Champ de saisie manuelle
                  Container(
                    width: 100,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFF2A3649),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        hintText: '0.00',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) return;

                        final parsedValue = double.tryParse(value) ?? 0.0;
                        if (parsedValue >= 0) {
                          tradingController.selectedQuantity = parsedValue;
                          setState(() {});
                        }
                      },
                      onEditingComplete: () {
                        // Formatage automatique quand l'utilisateur termine la saisie
                        final value = double.tryParse(_quantityController.text) ?? 0.0;
                        _quantityController.text = value.toStringAsFixed(2);
                        tradingController.selectedQuantity = value;
                        setState(() {});
                      },
                    ),
                  ),

                  // Bouton plus
                  IconButton(
                    icon: Icon(Iconsax.add_square, color: Colors.white),
                    onPressed: () {
                      tradingController.selectedQuantity = tradingController.selectedQuantity + 0.01;
                      _quantityController.text = tradingController.selectedQuantity.toStringAsFixed(2);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),

          // Prix total avec mise à jour en temps réel
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Color(0xFF2A3649),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prix unitaire',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${crypto.currentPrice.toStringAsFixed(2)} FCFA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Divider(color: Colors.grey[600], height: 1),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${(crypto.currentPrice * tradingController.selectedQuantity).toStringAsFixed(2)} FCFA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Boutons d'achat/vente
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00B894),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: tradingController.isBuying ? null : () => _showBuyConfirmation(crypto, tradingController),
                  child: tradingController.isBuying
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    'ACHETER',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF4D4D),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: (tradingController.isSelling || tradingController.ownedCrypto == null ||
                      (tradingController.ownedCrypto!.quantity < tradingController.selectedQuantity))
                      ? null
                      : () => _showSellConfirmation(crypto, tradingController),
                  child: tradingController.isSelling
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    'VENDRE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Info crypto possédée
          if (tradingController.ownedCrypto != null) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF00B894).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF00B894).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.wallet_check, color: Color(0xFF00B894), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solde disponible: ${tradingController.ownedCrypto!.quantity.toStringAsFixed(4)} ${crypto.symbol}',
                          style: TextStyle(
                            color: Color(0xFF00B894),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (tradingController.selectedQuantity > tradingController.ownedCrypto!.quantity)
                          Text(
                            'Quantité insuffisante',
                            style: TextStyle(
                              color: Color(0xFFFF4D4D),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Suggestions de quantités rapides
          SizedBox(height: 16),
          Text(
            'Quantités rapides:',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [0.1, 0.5, 1.0, 5.0, 10.0, 25.0].map((amount) {
              return GestureDetector(
                onTap: () {
                  tradingController.selectedQuantity = amount;
                  _quantityController.text = amount.toStringAsFixed(2);
                  setState(() {});
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tradingController.selectedQuantity == amount
                        ? Color(0xFF00B894)
                        : Color(0xFF2A3649),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 1),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showFullScreenChart(CryptoCurrency crypto) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Color(0xFF0F111C),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF1A202C),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Iconsax.arrow_left_2, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Graphique ${crypto.name}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Iconsax.refresh, color: Colors.white),
                    onPressed: () {
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),

            // Timeframe selector pour le mode plein écran
            Container(
              padding: EdgeInsets.all(16),
              child: Container(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _timeFrames.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTimeFrame = index;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(right: 8),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTimeFrame == index
                              ? Color(0xFF00B894)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedTimeFrame == index
                                ? Color(0xFF00B894)
                                : Color(0xFF2A3649),
                          ),
                        ),
                        child: Text(
                          _timeFrames[index],
                          style: TextStyle(
                            color: _selectedTimeFrame == index
                                ? Colors.white
                                : Colors.grey[400],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Graphique en plein écran
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: CryptoChartWidget(
                  priceHistory: crypto.priceHistory,
                  selectedTimeFrame: _timeFrames[_selectedTimeFrame],
                  isInteractive: true,
                ),
              ),
            ),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoInfo(CryptoCurrency crypto) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF2A3649)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 16),
          _buildInfoRow('Symbole', crypto.symbol),
          _buildInfoRow('Catégorie', crypto.category),
          _buildInfoRow('Offre en circulation', '${_formatNumber(crypto.circulatingSupply)} ${crypto.symbol}'),
          _buildInfoRow('Offre totale', '${_formatNumber(crypto.totalSupply)} ${crypto.symbol}'),
          _buildInfoRow('Dernière mise à jour',
              DateFormat('dd/MM/yyyy HH:mm').format(crypto.lastUpdated)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketActivity() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.activity, color: Color(0xFF00B894)),
              SizedBox(width: 8),
              Text(
                'Activité Récente du Marché',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _generateMarketActivities();
                  });
                },
                child: Icon(Iconsax.refresh, color: Colors.grey[400], size: 20),
              ),
            ],
          ),
          SizedBox(height: 12),
          ..._marketActivities.map((activity) => _buildActivityItem(activity)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Consumer<CryptoTradingProvider>(
      builder: (context, tradingController, child) {
        final crypto = tradingController.crypto;
        if (crypto == null) return SizedBox();

        final isBuy = activity['type'] == 'buy';

        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFF1A202C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isBuy
                      ? Color(0xFF00B894).withOpacity(0.2)
                      : Color(0xFFFF4D4D).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    isBuy ? Iconsax.arrow_down : Iconsax.arrow_up_3,
                    color: isBuy ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                    size: 16,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${activity['user']} ${activity['action']} ${activity['amount']} ${crypto.symbol}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Il y a ${activity['time']}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildTransactionHistory(CryptoTradingProvider tradingController) {
    final transactions = tradingController.transactions;

    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.receipt_item, color: Color(0xFF00B894)),
              SizedBox(width: 8),
              Text(
                'Historique des Transactions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (transactions.isEmpty)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF1A202C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Aucune transaction récente',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
            )
          else
            ...transactions.take(5).map((transaction) => _buildTransactionItem(transaction)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(CryptoTransaction transaction) {
    final isBuy = transaction.type == TransactionType.buy;
    final dateFormat = DateFormat('dd/MM HH:mm');

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isBuy
                  ? Color(0xFF00B894).withOpacity(0.2)
                  : Color(0xFFFF4D4D).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                isBuy ? Iconsax.arrow_down : Iconsax.arrow_up_3,
                color: isBuy ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                size: 16,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBuy ? 'Achat' : 'Vente',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${transaction.quantity} • ${dateFormat.format(transaction.date)}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.unitPrice.toStringAsFixed(2)} FCFA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (transaction.profit > 0)
                Text(
                  '+${transaction.profit.toStringAsFixed(2)} FCFA',
                  style: TextStyle(
                    color: Color(0xFF00B894),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Méthodes utilitaires
  String _getCryptoEmoji(String symbol) {
    switch (symbol) {
      case 'AFC': return '🪙';
      case 'KRC': return '⚡';
      case 'NIG': return '🏺';
      case 'SVT': return '🌍';
      case 'TBD': return '💎';
      default: return '🪙';
    }
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }

  void _showBuyConfirmation(CryptoCurrency crypto, CryptoTradingProvider controller) {
    final totalCost = crypto.currentPrice * controller.selectedQuantity;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A202C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirmer l\'achat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voulez-vous acheter ${controller.selectedQuantity} ${crypto.symbol} pour ${totalCost.toStringAsFixed(2)} FCFA?',
              style: TextStyle(color: Colors.grey[400]),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF00B894).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.info_circle, color: Color(0xFF00B894), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le prix peut varier selon la liquidité du marché',
                      style: TextStyle(
                        color: Color(0xFF00B894),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ANNULER', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              controller.buyCrypto(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00B894),
            ),
            child: Text('CONFIRMER'),
          ),
        ],
      ),
    );
  }

  void _showSellConfirmation(CryptoCurrency crypto, CryptoTradingProvider controller) {
    final totalValue = crypto.currentPrice * controller.selectedQuantity;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A202C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirmer la vente',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Voulez-vous vendre ${controller.selectedQuantity} ${crypto.symbol} pour ${totalValue.toStringAsFixed(2)} FCFA?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ANNULER', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              controller.sellCrypto();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF4D4D),
            ),
            child: Text('CONFIRMER'),
          ),
        ],
      ),
    );
  }
}