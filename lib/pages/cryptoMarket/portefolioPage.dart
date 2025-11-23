// views/crypto/portfolio_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import '../../models/crypto_model.dart';
import '../../providers/crypto_portfolio_controller.dart';
import 'crypto_detail_page.dart';





class CryptoPortfolioPage extends StatefulWidget {
  @override
  State<CryptoPortfolioPage> createState() => _CryptoPortfolioPageState();
}

class _CryptoPortfolioPageState extends State<CryptoPortfolioPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<CryptoPortfolioProvider>(context, listen: false);
      controller.initializeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F111C),
      body: Consumer<CryptoPortfolioProvider>(
        builder: (context, controller, child) {
          if (controller.isLoading && controller.portfolio == null) {
            return _buildLoadingState();
          }

          if (controller.errorMessage.isNotEmpty) {
            return _buildErrorState(controller);
          }

          return RefreshIndicator(
            onRefresh: () => controller.refreshData(),
            backgroundColor: Color(0xFF0F111C),
            color: Color(0xFF00B894),
            child: CustomScrollView(
              physics: BouncingScrollPhysics(),
              slivers: [
                // Header avec valeur totale
                SliverToBoxAdapter(
                  child: _buildPortfolioHeader(controller),
                ),

                // Section Solde Principal + Actions
                SliverToBoxAdapter(
                  child: _buildBalanceAndActionsSection(controller),
                ),

                // Statistiques de performance
                SliverToBoxAdapter(
                  child: _buildPerformanceStats(controller),
                ),

                // Section des cryptos
                _buildCryptosSection(controller),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCryptoLoader(),
          SizedBox(height: 20),
          Text(
            'Chargement du portefeuille...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCryptoLoader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00B894), Color(0xFF00D4AA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 3,
            backgroundColor: Colors.transparent,
          ),
        ),
        Icon(Iconsax.wallet_3, color: Colors.white, size: 30),
      ],
    );
  }

  Widget _buildErrorState(CryptoPortfolioProvider controller) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Color(0xFFFF4D4D).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Iconsax.warning_2, color: Color(0xFFFF4D4D), size: 40),
          ),
          SizedBox(height: 20),
          Text(
            'Oups! Quelque chose s\'est mal passé',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            controller.errorMessage,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 25),
          ElevatedButton(
            onPressed: controller.refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00B894),
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Réessayer',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioHeader(CryptoPortfolioProvider controller) {
    final portfolio = controller.portfolio;
    final totalValue = portfolio?.totalValue ?? 0;

    return Container(
      padding: EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre et menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mon Portefeuille Crypto',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                icon: Icon(Iconsax.refresh, color: Colors.white),
                onPressed: controller.refreshData,
                tooltip: 'Actualiser',
              ),
            ],
          ),
          SizedBox(height: 25),

          // Carte principale de la valeur totale
          Container(
            padding: EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF00B894).withOpacity(0.15),
                  Color(0xFF00D4AA).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Color(0xFF00B894).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Valeur Totale du Portefeuille',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${NumberFormat('#,##0.00').format(totalValue)} FCFA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 15),
                _buildPortfolioBreakdown(controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioBreakdown(CryptoPortfolioProvider controller) {
    final portfolio = controller.portfolio;
    final balance = portfolio?.balance ?? 0;
    final investedValue = (portfolio?.totalValue ?? 0) - balance;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildBreakdownItem(
          'Solde Disponible',
          balance,
          Color(0xFF00B894),
        ),
        Container(
          width: 1,
          height: 30,
          color: Color(0xFF2A3649),
        ),
        _buildBreakdownItem(
          'Investi',
          investedValue,
          Color(0xFF667EEA),
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(String title, double value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '${NumberFormat('#,##0').format(value)} FCFA',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceAndActionsSection(CryptoPortfolioProvider controller) {
    final user = controller.currentUser;
    final principalBalance = user?.votre_solde_principal ?? 0;
    final portfolioBalance = controller.portfolio?.balance ?? 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          // Carte du solde principal
          _buildPrincipalBalanceCard(principalBalance),
          SizedBox(height: 16),

          // Boutons d'actions
          _buildActionButtons(controller, portfolioBalance),
        ],
      ),
    );
  }

  Widget _buildPrincipalBalanceCard(double balance) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2A3649)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00B894), Color(0xFF00D4AA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Iconsax.profile_circle, color: Colors.white, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solde Principal Disponible',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${NumberFormat('#,##0.00').format(balance)} FCFA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Utilisez ce solde pour recharger votre portefeuille crypto',
                  style: TextStyle(
                    color: Colors.grey[500],
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

  Widget _buildActionButtons(CryptoPortfolioProvider controller, double portfolioBalance) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Iconsax.arrow_down,
            title: 'Recharger',
            subtitle: 'Depuis solde principal',
            amount: '${NumberFormat('#,##0').format(controller.currentUser?.votre_solde_principal ?? 0)} FCFA',
            color: Color(0xFF00B894),
            onTap: () => controller.showAddFundsDialog(context),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Iconsax.arrow_up,
            title: 'Encaisser',
            subtitle: 'Vers compte principal',
            amount: '${NumberFormat('#,##0').format(portfolioBalance)} FCFA',
            color: Color(0xFFFF4D4D),
            onTap: () => controller.showWithdrawalDialog(context),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.15),
                color.withOpacity(0.05),
              ],
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  Spacer(),
                  Text(
                    amount,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceStats(CryptoPortfolioProvider controller) {
    final portfolio = controller.portfolio;
    final dailyProfit = portfolio?.dailyProfitLoss ?? 0;
    final totalProfit = portfolio?.totalProfitLoss ?? 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2A3649)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPerformanceItem(
            'Performance Jour',
            dailyProfit,
            Iconsax.chart_1,
          ),
          Container(
            width: 1,
            height: 40,
            color: Color(0xFF2A3649),
          ),
          _buildPerformanceItem(
            'Performance Total',
            totalProfit,
            Iconsax.trend_up,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceItem(String title, double value, IconData icon) {
    final isPositive = value >= 0;
    final color = isPositive ? Color(0xFF00B894) : Color(0xFFFF4D4D);

    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Text(
          '${isPositive ? '+' : ''}${NumberFormat('#,##0.00').format(value)} FCFA',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCryptosSection(CryptoPortfolioProvider controller) {
    final portfolio = controller.portfolio;
    final ownedCryptos = portfolio?.ownedCryptos ?? [];

    if (ownedCryptos.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyPortfolio(),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'Mes Cryptomonnaies',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          final cryptoIndex = index - 1;
          if (cryptoIndex < ownedCryptos.length) {
            return _buildModernAssetItem(ownedCryptos[cryptoIndex], controller);
          }

          return SizedBox();
        },
        childCount: ownedCryptos.length + 1,
      ),
    );
  }

  Widget _buildEmptyPortfolio() {
    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF2A3649)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Color(0xFF00B894).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Iconsax.wallet_3, color: Color(0xFF00B894), size: 35),
          ),
          SizedBox(height: 20),
          Text(
            'Portefeuille Crypto Vide',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Utilisez les boutons de recharge pour commencer à trader',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernAssetItem(OwnedCrypto ownedCrypto, CryptoPortfolioProvider controller) {
    final crypto = controller.getCryptoById(ownedCrypto.cryptoId);
    if (crypto == null) return SizedBox();

    final currentValue = ownedCrypto.quantity * crypto.currentPrice;
    final investedValue = ownedCrypto.quantity * ownedCrypto.averageBuyPrice;
    final profit = currentValue - investedValue;
    final isProfit = profit >= 0;
    final profitPercentage = investedValue > 0 ? (profit / investedValue * 100) : 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CryptoDetailPage(cryptoId: crypto.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF1A202C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF2A3649)),
            ),
            child: Row(
              children: [
                // Logo crypto
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF00B894).withOpacity(0.3),
                        Color(0xFF667EEA).withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _getCryptoEmoji(crypto.symbol),
                      style: TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                SizedBox(width: 16),

                // Infos principales
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
                        '${ownedCrypto.quantity.toStringAsFixed(4)} ${crypto.symbol}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Valeur et performance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${NumberFormat('#,##0.00').format(currentValue)} FCFA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isProfit
                            ? Color(0xFF00B894).withOpacity(0.2)
                            : Color(0xFFFF4D4D).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isProfit ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
                            color: isProfit ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${profitPercentage.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: isProfit ? Color(0xFF00B894) : Color(0xFFFF4D4D),
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
}