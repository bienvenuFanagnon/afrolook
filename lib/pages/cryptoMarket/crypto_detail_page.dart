// views/crypto/crypto_detail_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import '../../models/crypto_model.dart';
import '../../providers/crypto_market_provider.dart';
import 'package:provider/provider.dart';

import '../../providers/crypto_trading_controller.dart';

// views/crypto/crypto_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import '../../models/crypto_model.dart';
import '../../providers/crypto_market_provider.dart';
import '../../providers/crypto_trading_controller.dart';

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

  // Données pour les activités en temps réel
  final List<Map<String, dynamic>> _marketActivities = [
    {'user': 'Fatou D.', 'action': 'a acheté', 'amount': '150', 'time': '2 min'},
    {'user': 'Mohamed K.', 'action': 'a vendu', 'amount': '75', 'time': '5 min'},
    {'user': 'Aïcha B.', 'action': 'a investi', 'amount': '200', 'time': '8 min'},
    {'user': 'Jean-Paul M.', 'action': 'a acheté', 'amount': '100', 'time': '12 min'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialiser les données du trading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tradingController = Provider.of<CryptoTradingProvider>(context, listen: false);
      // Vérifier si c'est la même crypto, sinon réinitialiser
      if (tradingController.crypto?.id != widget.cryptoId) {
        tradingController.refreshData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    final isPositive = crypto.dailyPriceChange >= 0;

    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        // Header avec infos principales
        SliverAppBar(
          backgroundColor: Color(0xFF0F111C),
          elevation: 0,
          pinned: true,
          expandedHeight: 220,
          flexibleSpace: _buildCryptoHeader(crypto, isPositive),
          leading: IconButton(
            icon: Icon(Iconsax.arrow_left_2, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Iconsax.refresh, color: Colors.white),
              onPressed: tradingController.refreshData,
            ),
          ],
        ),

        // Contenu principal
        SliverToBoxAdapter(
          child: Column(
            children: [
              // Statistiques rapides
              _buildQuickStats(crypto),

              // Graphique et timeframe selector
              _buildChartSection(crypto),

              // Contrôles d'achat/vente
              _buildTradeControls(crypto, tradingController),

              // Informations détaillées
              _buildCryptoInfo(crypto),

              // Activités du marché
              _buildMarketActivity(),

              // Historique des transactions
              _buildTransactionHistory(tradingController),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCryptoHeader(CryptoCurrency crypto, bool isPositive) {
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
                  SizedBox(height: 12),
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
                      SizedBox(width: 12),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                            SizedBox(width: 4),
                            Text(
                              '${(crypto.dailyPriceChange * 100).toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: isPositive ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
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

  Widget _buildQuickStats(CryptoCurrency crypto) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2A3649)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Capitalisation', '${_formatNumber(crypto.marketCap)} FCFA'),
          _buildStatItem('Volume 24h', '${_formatNumber(crypto.dailyVolume)} FCFA'),
          _buildStatItem('Rang', '#${crypto.rank}'),
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

          // Graphique placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Color(0xFF1A202C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF2A3649)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.chart_2, color: Color(0xFF00B894), size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Graphique en développement',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
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
          // Quantité selector
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
                  IconButton(
                    icon: Icon(Iconsax.minus_square, color: Colors.white),
                    onPressed: () {
                      if (tradingController.selectedQuantity > 1) {
                        tradingController.selectedQuantity = tradingController.selectedQuantity - 1;
                      }
                    },
                  ),
                  Container(
                    width: 60,
                    child: Text(
                      tradingController.selectedQuantity.toStringAsFixed(2),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Iconsax.add_square, color: Colors.white),
                    onPressed: () => tradingController.selectedQuantity = tradingController.selectedQuantity + 1,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),

          // Prix total
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Color(0xFF2A3649),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
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
                      tradingController.ownedCrypto!.quantity < tradingController.selectedQuantity)
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
                    child: Text(
                      'Vous possédez ${tradingController.ownedCrypto!.quantity.toStringAsFixed(4)} ${crypto.symbol}',
                      style: TextStyle(
                        color: Color(0xFF00B894),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
                'Activité Récente',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
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
    final isBuy = activity['action'].contains('acheté');

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
                  '${activity['user']} ${activity['action']} ${activity['amount']}',
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
      case 'NIG': return '🪙';
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