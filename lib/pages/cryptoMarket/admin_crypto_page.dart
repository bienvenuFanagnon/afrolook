import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/crypto_model.dart';
import '../../models/model_data.dart';
import '../../providers/crypto_admin_provider.dart';
import '../../providers/crypto_market_provider.dart';
import 'crypto_form_page.dart';

class AdminCryptoPage extends StatefulWidget {
  @override
  State<AdminCryptoPage> createState() => _AdminCryptoPageState();
}

class _AdminCryptoPageState extends State<AdminCryptoPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Statistiques
  int _totalTransactions = 0;
  double _totalVolume = 0.0;
  double _totalCommissions = 0.0;
  List<CryptoTransaction> _allTransactions = [];
  List<CryptoPortfolio> _allPortfolios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Récupérer les transactions
      final transactionsSnapshot = await _firestore
          .collection('crypto_transactions')
          .orderBy('date', descending: true)
          .get();

      _allTransactions = transactionsSnapshot.docs
          .map((doc) => CryptoTransaction.fromFirestore(doc))
          .toList();

      // Récupérer les portfolios
      final portfoliosSnapshot = await _firestore
          .collection('crypto_portfolios')
          .get();

      _allPortfolios = portfoliosSnapshot.docs
          .map((doc) => CryptoPortfolio.fromFirestore(doc))
          .toList();

      // Calculer les statistiques
      _calculateStats();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateStats() {
    _totalTransactions = _allTransactions.length;

    double commissions = 0;
    double volume = 0;

    for (var transaction in _allTransactions) {
      volume += transaction.unitPrice * transaction.quantity;
      commissions += transaction.commission;
    }

    _totalCommissions = commissions;
    _totalVolume = volume;
  }
  Widget _buildCryptoDetail(String label, String value) {
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
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, CryptoTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A202C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              transaction.type == TransactionType.buy ? Iconsax.arrow_down : Iconsax.arrow_up_3,
              color: transaction.type == TransactionType.buy ? Color(0xFF00B894) : Color(0xFFFF6B9D),
            ),
            SizedBox(width: 8),
            Text(
              'Détails Transaction',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTransactionDetail('Type', transaction.type == TransactionType.buy ? 'Achat' : 'Vente'),
              _buildTransactionDetail('Crypto', _getCryptoName(transaction.cryptoId)),
              _buildTransactionDetail('Quantité', transaction.quantity.toString()),
              _buildTransactionDetail('Prix unitaire', '\$${transaction.unitPrice.toStringAsFixed(2)}'),
              _buildTransactionDetail('Montant total', '\$${(transaction.unitPrice * transaction.quantity).toStringAsFixed(2)}'),
              if (transaction.profit != 0)
                _buildTransactionDetail(
                  'Profit',
                  '\$${transaction.profit.toStringAsFixed(2)}',
                  valueColor: transaction.profit > 0 ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                ),
              _buildTransactionDetail('Commission', '\$${transaction.commission.toStringAsFixed(2)}'),
              _buildTransactionDetail('Date', _formatFullDate(transaction.date)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'FERMER',
              style: TextStyle(
                color: Color(0xFF00B894),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionDetail(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
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
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F111C),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: Color(0xFF0F111C),
              elevation: 0,
              pinned: true,
              floating: true,
              title: Text(
                'Admin Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Iconsax.refresh, color: Colors.white),
                  onPressed: _fetchData,
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Color(0xFF00B894),
                indicatorWeight: 3,
                labelColor: Color(0xFF00B894),
                unselectedLabelColor: Colors.grey[400],
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                tabs: [
                  Tab(text: 'MARCHÉ'),
                  Tab(text: 'PORTEFEUILLES'),
                  Tab(text: 'TRANSACTIONS'),
                  Tab(text: 'STATISTIQUES'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMarketTab(),
            _buildPortfoliosTab(),
            _buildTransactionsTab(),
            _buildStatsTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CryptoFormPage()),
          );
        },
        backgroundColor: Color(0xFF00B894),
        child: Icon(Iconsax.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMarketTab() {
    return Consumer<CryptoMarketProvider>(
      builder: (context, marketProvider, child) {
        if (marketProvider.isLoading) {
          return Center(
            child: CircularProgressIndicator(color: Color(0xFF00B894)),
          );
        }

        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // En-tête avec statistiques rapides
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A202C), Color(0xFF131A26)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickStat(
                        'Cryptos', marketProvider.cryptos.length.toString(),
                        Iconsax.coin),
                    _buildQuickStat('Trending',
                        marketProvider.trendingCryptos.length.toString(),
                        Iconsax.trend_up),
                    _buildQuickStat('Market Cap',
                        '${_formatNumber(marketProvider.totalMarketCap)} FCFA',
                        Iconsax.chart_2),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Liste des cryptos
              Expanded(
                child: ListView.builder(
                  itemCount: marketProvider.cryptos.length,
                  itemBuilder: (context, index) {
                    final crypto = marketProvider.cryptos[index];
                    return _buildCryptoCard(crypto);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCryptoCard(CryptoCurrency crypto) {
    final isPositive = crypto.dailyPriceChange >= 0;
    final rankColors = [
      Color(0xFFFFD700), // Gold
      Color(0xFFC0C0C0), // Silver
      Color(0xFFCD7F32), // Bronze
      Color(0xFF00B894), // Green
    ];
    final rankColor = crypto.rank <= 3
        ? rankColors[crypto.rank - 1]
        : rankColors[3];

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showCryptoEditModal(context, crypto);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Rank
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rankColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: rankColor.withOpacity(0.5)),
                  ),
                  child: Center(
                    child: Text(
                      '${crypto.rank}',
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Emoji de la crypto
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color(0xFF2A3649),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _getCryptoEmoji(crypto.symbol),
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crypto.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        crypto.symbol.toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFF00B894).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: Color(0xFF00B894).withOpacity(0.3)),
                            ),
                            child: Text(
                              crypto.category,
                              style: TextStyle(
                                color: Color(0xFF00B894),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          if (crypto.isTrending)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFFFF6B9D).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: Color(0xFFFF6B9D).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Iconsax.trend_up, size: 10,
                                      color: Color(0xFFFF6B9D)),
                                  SizedBox(width: 2),
                                  Text(
                                    'TRENDING',
                                    style: TextStyle(
                                      color: Color(0xFFFF6B9D),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
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
                // Prix et variation
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${crypto.currentPrice.toStringAsFixed(2)} FCFA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? Color(0xFF00B894).withOpacity(0.2)
                            : Color(0xFFFF4D4D).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPositive ? Iconsax.arrow_up_3 : Iconsax
                                .arrow_down,
                            color: isPositive ? Color(0xFF00B894) : Color(
                                0xFFFF4D4D),
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${(crypto.dailyPriceChange * 100).toStringAsFixed(
                                2)}%',
                            style: TextStyle(
                              color: isPositive ? Color(0xFF00B894) : Color(
                                  0xFFFF4D4D),
                              fontSize: 12,
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
        ),
      ),
    );
  }
  void _showCryptoEditModal(BuildContext context, CryptoCurrency crypto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Color(0xFF1A202C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF131A26),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: crypto.imageUrl.isNotEmpty
                          ? DecorationImage(
                        image: NetworkImage(crypto.imageUrl),
                        fit: BoxFit.cover,
                      )
                          : null,
                      color: crypto.imageUrl.isEmpty ? Color(0xFF2A3649) : null,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          crypto.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          crypto.symbol.toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Iconsax.edit_2, color: Color(0xFF00B894)),
                    onPressed: () {
                      Navigator.pop(context);
                      // context.read<CryptoAdminProvider>().setCryptoToEdit(crypto);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CryptoFormPage(cryptoId: crypto.id)),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Contenu
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCryptoDetail('Prix actuel', '\$${crypto.currentPrice.toStringAsFixed(2)}'),
                    _buildCryptoDetail('Market Cap', '\$${_formatNumber(crypto.marketCap)}'),
                    _buildCryptoDetail('Circulating Supply', _formatNumber(crypto.circulatingSupply)),
                    _buildCryptoDetail('Total Supply', _formatNumber(crypto.totalSupply)),
                    _buildCryptoDetail('Catégorie', crypto.category),
                    _buildCryptoDetail('Rank', '#${crypto.rank}'),
                    _buildCryptoDetail('Variation 24h', '${(crypto.dailyPriceChange * 100).toStringAsFixed(2)}%'),
                    Spacer(),
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [Color(0xFF00B894), Color(0xFF00D4AA)],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(context);
                            // context.read<CryptoAdminProvider>().setCryptoToEdit(crypto);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => CryptoFormPage(cryptoId: crypto.id)),
                            );
                          },
                          child: Center(
                            child: Text(
                              'MODIFIER LA CRYPTO',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfoliosTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Color(0xFF00B894)),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Statistiques portfolios
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A202C), Color(0xFF131A26)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat(
                    'Portefeuilles', _allPortfolios.length.toString(),
                    Iconsax.wallet_3),
                _buildQuickStat('Valeur Totale',
                    '${_formatNumber(_calculateTotalPortfolioValue())} FCFA',
                    Iconsax.dollar_circle),
                _buildQuickStat('Solde Moyen',
                    '${_formatNumber(_calculateAverageBalance())} FCFA',
                    Iconsax.chart_success),
              ],
            ),
          ),
          SizedBox(height: 16),
          // Liste des portfolios
          Expanded(
            child: ListView.builder(
              itemCount: _allPortfolios.length,
              itemBuilder: (context, index) {
                final portfolio = _allPortfolios[index];
                return _buildPortfolioCard(portfolio);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioCard(CryptoPortfolio portfolio) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showPortfolioDetails(context, portfolio);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar utilisateur
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Color(0xFF00B894).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Icon(
                        Iconsax.profile_circle, color: Color(0xFF00B894),
                        size: 24),
                  ),
                ),
                SizedBox(width: 12),
                // Infos utilisateur
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('Users').doc(
                            portfolio.userId).get(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData = UserData.fromJson(
                                snapshot.data!.data() as Map<String, dynamic>);
                            return Text(
                              userData.pseudo ??
                                  'Utilisateur ${portfolio.userId.substring(
                                      0, 8)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            );
                          }
                          return Text(
                            'Utilisateur ${portfolio.userId.substring(0, 8)}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${portfolio.ownedCryptos.length} cryptos',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFF667EEA).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Color(0xFF667EEA)
                              .withOpacity(0.3)),
                        ),
                        child: Text(
                          'ID: ${portfolio.userId.substring(0, 8)}...',
                          style: TextStyle(
                            color: Color(0xFF667EEA),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Solde et valeur
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${portfolio.balance.toStringAsFixed(2)} FCFA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${portfolio.totalValue.toStringAsFixed(2)} FCFA',
                      style: TextStyle(
                        color: Color(0xFF00B894),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: portfolio.totalProfitLoss >= 0
                            ? Color(0xFF00B894).withOpacity(0.2)
                            : Color(0xFFFF4D4D).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${portfolio.totalProfitLoss >= 0 ? '+' : ''}${portfolio
                            .totalProfitLoss.toStringAsFixed(2)} FCFA',
                        style: TextStyle(
                          color: portfolio.totalProfitLoss >= 0 ? Color(
                              0xFF00B894) : Color(0xFFFF4D4D),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Color(0xFF00B894)),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Statistiques transactions
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A202C), Color(0xFF131A26)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat('Transactions', _totalTransactions.toString(),
                    Iconsax.receipt_2),
                _buildQuickStat('Volume', '${_formatNumber(_totalVolume)} FCFA',
                    Iconsax.dollar_circle),
                _buildQuickStat(
                    'Commissions', '${_formatNumber(_totalCommissions)} FCFA',
                    Iconsax.wallet_money),
              ],
            ),
          ),
          SizedBox(height: 16),
          // Liste des transactions
          Expanded(
            child: ListView.builder(
              itemCount: _allTransactions.length,
              itemBuilder: (context, index) {
                final transaction = _allTransactions[index];
                return _buildTransactionCard(transaction);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(CryptoTransaction transaction) {
    final isBuy = transaction.type == TransactionType.buy;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showTransactionDetails(context, transaction);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Type de transaction
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isBuy ? Color(0xFF00B894).withOpacity(0.2) : Color(
                        0xFFFF6B9D).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      isBuy ? Iconsax.arrow_down : Iconsax.arrow_up_3,
                      color: isBuy ? Color(0xFF00B894) : Color(0xFFFF6B9D),
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Détails
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBuy ? 'ACHAT' : 'VENTE',
                        style: TextStyle(
                          color: isBuy ? Color(0xFF00B894) : Color(0xFFFF6B9D),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${transaction.quantity} ${_getCryptoName(
                            transaction.cryptoId)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _formatDate(transaction.date),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Montant
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(transaction.unitPrice * transaction.quantity)
                          .toStringAsFixed(2)} FCFA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    if (transaction.profit != 0)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: transaction.profit > 0 ? Color(0xFF00B894)
                              .withOpacity(0.2) : Color(0xFFFF4D4D).withOpacity(
                              0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${transaction.profit > 0 ? '+' : ''}${transaction
                              .profit.toStringAsFixed(2)} FCFA',
                          style: TextStyle(
                            color: transaction.profit > 0
                                ? Color(0xFF00B894)
                                : Color(0xFFFF4D4D),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Cartes de statistiques
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Transactions',
                  _totalTransactions.toString(),
                  Iconsax.receipt_2,
                  Color(0xFF667EEA),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Volume Total',
                  '${_formatNumber(_totalVolume)} FCFA',
                  Iconsax.dollar_circle,
                  Color(0xFF00B894),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Commissions',
                  '${_formatNumber(_totalCommissions)} FCFA',
                  Iconsax.wallet_money,
                  Color(0xFFFF6B9D),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Portefeuilles',
                  _allPortfolios.length.toString(),
                  Iconsax.wallet_3,
                  Color(0xFFF093FB),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          // Graphique de distribution (simplifié)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A202C), Color(0xFF131A26)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Iconsax.chart_2, color: Color(0xFF00B894)),
                    SizedBox(width: 8),
                    Text(
                      'ACTIVITÉ DU MARCHÉ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Graphique simplifié
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Color(0xFF2A3649).withOpacity(0.5),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            Iconsax.chart_1, size: 50, color: Colors.grey[400]),
                        SizedBox(height: 12),
                        Text(
                          'Graphique des performances',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Données en temps réel',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF00B894).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Color(0xFF00B894), size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Spacer(),
              Icon(Iconsax.arrow_up_3, color: Color(0xFF00B894), size: 16),
            ],
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Méthodes utilitaires
  String _formatNumber(double number) {
    if (number >= 1e9) {
      return '${(number / 1e9).toStringAsFixed(2)}B';
    } else if (number >= 1e6) {
      return '${(number / 1e6).toStringAsFixed(2)}M';
    } else if (number >= 1e3) {
      return '${(number / 1e3).toStringAsFixed(2)}K';
    }
    return number.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes < 1) return 'À l\'instant';
        return 'Il y a ${difference.inMinutes} min';
      }
      return 'Il y a ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatFullDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour.toString()
        .padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getCryptoName(String cryptoId) {
    final crypto = context
        .read<CryptoMarketProvider>()
        .cryptos
        .firstWhere(
          (c) => c.id == cryptoId,
      orElse: () =>
          CryptoCurrency(
            id: '',
            symbol: 'UNK',
            name: 'Inconnu',
            imageUrl: '',
            currentPrice: 0,
            initialPrice: 0,
            marketCap: 0,
            circulatingSupply: 0,
            totalSupply: 0,
            lastUpdated: DateTime.now(),
          ),
    );
    return crypto.symbol;
  }

  String _getCryptoEmoji(String symbol) {
    switch (symbol) {
      case 'AFC':
        return '🪙'; // AfroCoin
      case 'KRC':
        return '⚡'; // KoraCoin
      case 'NIG':
        return '🏺'; // NiloGold
      case 'SVT':
        return '🌍'; // Savannah Token
      case 'TBD':
        return '💎'; // Timbuktu Dollar
      default:
        return '🪙';
    }
  }

  double _calculateTotalPortfolioValue() {
    return _allPortfolios.fold(
        0.0, (sum, portfolio) => sum + portfolio.totalValue);
  }

  double _calculateAverageBalance() {
    if (_allPortfolios.isEmpty) return 0.0;
    return _calculateTotalPortfolioValue() / _allPortfolios.length;
  }

  void _showPortfolioDetails(BuildContext context, CryptoPortfolio portfolio) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: Color(0xFF1A202C),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Iconsax.wallet_3, color: Color(0xFF00B894)),
                SizedBox(width: 8),
                Text(
                  'Détails Portefeuille',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            content: FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('Users')
                  .doc(portfolio.userId)
                  .get(),
              builder: (context, snapshot) {
                String userName = 'Utilisateur ${portfolio.userId.substring(
                    0, 8)}';
                String userEmail = 'Non disponible';

                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData = UserData.fromJson(
                      snapshot.data!.data() as Map<String, dynamic>);
                  userName = userData.pseudo ?? userName;
                  userEmail = userData.email ?? userEmail;
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPortfolioDetail('Utilisateur', userName),
                      _buildPortfolioDetail('Email', userEmail),
                      _buildPortfolioDetail('Solde',
                          '${portfolio.balance.toStringAsFixed(2)} FCFA'),
                      _buildPortfolioDetail('Valeur Totale',
                          '${portfolio.totalValue.toStringAsFixed(2)} FCFA'),
                      _buildPortfolioDetail('Profit/Perte',
                          '${portfolio.totalProfitLoss.toStringAsFixed(
                              2)} FCFA',
                          valueColor: portfolio.totalProfitLoss >= 0 ? Color(
                              0xFF00B894) : Color(0xFFFF4D4D)),
                      _buildPortfolioDetail('Cryptos Possédées',
                          portfolio.ownedCryptos.length.toString()),
                      SizedBox(height: 16),
                      if (portfolio.ownedCryptos.isNotEmpty) ...[
                        Text(
                          'Détail des Cryptos:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        ...portfolio.ownedCryptos.map((crypto) =>
                            _buildCryptoDetailItem(crypto)
                        ).toList(),
                      ],
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'FERMER',
                  style: TextStyle(
                    color: Color(0xFF00B894),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildPortfolioDetail(String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
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
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCryptoDetailItem(OwnedCrypto ownedCrypto) {
    final crypto = context
        .read<CryptoMarketProvider>()
        .cryptos
        .firstWhere(
          (c) => c.id == ownedCrypto.cryptoId,
      orElse: () =>
          CryptoCurrency(
            id: '',
            symbol: 'UNK',
            name: 'Inconnu',
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
    final profit = currentValue -
        (ownedCrypto.quantity * ownedCrypto.averageBuyPrice);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Color(0xFF2A3649),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Color(0xFF1A202C),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                _getCryptoEmoji(crypto.symbol),
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crypto.symbol,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${ownedCrypto.quantity.toStringAsFixed(4)}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${currentValue.toStringAsFixed(2)} FCFA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                '${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(2)} FCFA',
                style: TextStyle(
                  color: profit >= 0 ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
