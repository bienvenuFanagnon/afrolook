import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dating_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/dating/coin_provider.dart';
import '../../l10n/app_localizations.dart';


class BuyCoinsPage extends StatefulWidget {
  const BuyCoinsPage({Key? key}) : super(key: key);

  @override
  State<BuyCoinsPage> createState() => _BuyCoinsPageState();
}

class _BuyCoinsPageState extends State<BuyCoinsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Couleurs
  final Color primaryRed = const Color(0xFFE63946);
  final Color primaryYellow = const Color(0xFFFFD700);
  final Color primaryBlack = Colors.black;
  final Color secondaryGrey = const Color(0xFF2C2C2C);

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }
  void _showRechargeDialog(
      BuildContext context,
      double balance,
      double required,
      ) {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: secondaryGrey,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet,
                  size: 50, color: primaryYellow),

              const SizedBox(height: 16),

              Text(
                t.datingInsufficientBalance,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                t.datingBalanceRequired
                    .replaceAll('{balance}', balance.toStringAsFixed(0))
                    .replaceAll('{required}', required.toStringAsFixed(0)),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400]),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);

                  // 👉 redirection vers page dépôt
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DepositScreen(),));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryYellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  t.datingRechargeNow,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  t.datingLaterButton,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  /// Catalogue des packs de pièces, défini localement (et non plus dans
  /// Firestore) pour éviter les doublons/anciens tarifs et garder le
  /// contrôle total de la grille tarifaire dans le code de l'application.
  /// Tarifs en FCFA inchangés par rapport à l'offre initiale, nombre de
  /// pièces doublé, et nouveaux paliers ajoutés jusqu'à 100 000 FCFA avec
  /// une réduction progressive (plus de pièces par FCFA sur les gros packs).
  static List<CoinPackage> get _localPackages {
    final now = DateTime.now().millisecondsSinceEpoch;
    Map<String, dynamic> raw(String id, String name, int coins, double price) => {
      'id': id,
      'name': name,
      'coinsAmount': coins,
      'priceXof': price,
      'isActive': true,
      'createdAt': now,
      'updatedAt': now,
    };
    return [
      raw('coin_pack_1', 'Découverte', 200, 250.0),
      raw('coin_pack_2', 'Starter', 420, 500.0),
      raw('coin_pack_3', 'Bronze', 900, 1000.0),
      raw('coin_pack_4', 'Silver', 2400, 2500.0),
      raw('coin_pack_5', 'Gold', 5000, 5000.0),
      raw('coin_pack_6', 'Platinum', 10500, 10000.0),
      raw('coin_pack_7', 'Diamond', 27500, 25000.0),
      raw('coin_pack_8', 'Legend', 57500, 50000.0),
      raw('coin_pack_9', 'Ultimate', 120000, 100000.0),
    ].map((json) => CoinPackage.fromJson(json)).toList();
  }

  Future<void> _buyPackage(
      BuildContext context,
      CoinPackage package,
      CoinProvider provider,
      ) async {
    final t = AppLocalizations.of(context);
    print('📱 === Achat de pièces ===');
    print('📦 Pack: ${package.name}');
    print('💰 Coût: ${package.priceXof} FCFA');
    print('🎁 Pièces: ${package.coinsAmount}');

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentBalance = authProvider.loginUserData.votre_solde_principal ?? 0;
    print('💳 Solde actuel: $currentBalance FCFA');

    if (currentBalance < package.priceXof) {
      print('❌ Solde insuffisant');
      _showErrorDialog(t.datingInsufficientBalance,
          t.datingInsufficientBalanceMessagePack
              .replaceAll('{balance}', currentBalance.toStringAsFixed(0))
              .replaceAll('{price}', package.priceXof.toStringAsFixed(0)));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: secondaryGrey,
        title: Row(
          children: [
            Icon(Icons.shopping_cart, color: primaryYellow),
            const SizedBox(width: 8),
            Text(t.datingConfirmPurchase, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: Text(
                _packageIcon(package.name),
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              package.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.datingBuyCoinsAmount.replaceAll('{count}', _formatNumber(package.coinsAmount)),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatNumber(package.priceXof.toInt())} FCFA',
              style: TextStyle(
                fontSize: 14,
                color: primaryYellow,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.grey[400], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    t.datingBalanceAfterPurchase.replaceAll('{balance}', (currentBalance - package.priceXof).toStringAsFixed(0)),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.datingCancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryYellow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              t.datingConfirmButton,
              style: TextStyle(color: primaryBlack, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      print('❌ Achat annulé par l\'utilisateur');
      return;
    }

    print('🔄 Exécution de l\'achat...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryGrey,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: primaryYellow),
            SizedBox(height: 16),
            Text(t.datingProcessing, style: TextStyle(color: Colors.white)),
            SizedBox(height: 8),
            Text(t.datingPleaseWait, style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      ),
    );

    bool success = false;
    try {
      success = await provider.buyCoins(package);
    } finally {
      // Fermer le dialog de chargement
      Navigator.pop(context); // ferme le dialog de chargement
    }
    if (success && mounted) {
      print('✅ Achat réussi ! ${package.coinsAmount} pièces ajoutées');

      // Recharger les données utilisateur
      await authProvider.refreshUserData();

      _showSuccessDialog(package);

      // Retourner à la page précédente après 1 secondes
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } else if (mounted) {
      print('❌ Échec de l\'achat');
      _showErrorDialog(t.datingErrorTitle, t.datingPurchaseErrorMessage);
    }
  }

  void _showSuccessDialog(CoinPackage package) {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: secondaryGrey,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 50, color: Colors.green),
            ),
            const SizedBox(height: 20),
            Text(
              t.datingPurchaseSuccess,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.datingReceivedCoins.replaceAll('{count}', '${package.coinsAmount}'),
              style: TextStyle(
                fontSize: 14,
                color: primaryYellow,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.datingCoinsUsageHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              t.datingRedirecting,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: secondaryGrey,
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.datingOkButton, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final authProvider = Provider.of<UserAuthProvider>(context);
    final currentBalance = authProvider.loginUserData.votre_solde_principal ?? 0;
    final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;

    print('📱 Build BuyCoinsPage - Solde: $currentBalance FCFA, Pièces: $currentCoins');

    return Scaffold(
      backgroundColor: primaryBlack,
      appBar: AppBar(
        title: Text(
          t.datingBuyCoinsTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryRed,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Header avec solde
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryRed, primaryRed.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      t.datingYourBalanceLabel,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.currency_franc, color: primaryYellow, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          '${currentBalance.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            t.datingCoinsCount.replaceAll('{count}', '$currentCoins'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        t.datingExchangeRate,
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

              // Liste des packs (catalogue local, défini dans le code)
              Expanded(
                child: Consumer<CoinProvider>(
                  builder: (context, provider, child) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _localPackages.length,
                      itemBuilder: (context, index) {
                        final package = _localPackages[index];
                        return _buildPackageCard(context, package, provider, currentBalance);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Emoji représentatif de chaque palier, du plus modeste au plus prestigieux.
  String _packageIcon(String name) {
    switch (name) {
      case 'Découverte':
        return '🪙';
      case 'Starter':
        return '⭐';
      case 'Bronze':
        return '🌟';
      case 'Silver':
        return '🔥';
      case 'Gold':
        return '💎';
      case 'Platinum':
        return '👑';
      case 'Diamond':
        return '🏆';
      case 'Legend':
        return '🚀';
      case 'Ultimate':
        return '🏰';
      default:
        return '🪙';
    }
  }

  String _formatNumber(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  Widget _buildPackageCard(
      BuildContext context,
      CoinPackage package,
      CoinProvider provider,
      double currentBalance,
      ) {
    final t = AppLocalizations.of(context);
    final isAffordable = currentBalance >= package.priceXof;
    final discount = package.coinsAmount >= 500 ? 10 : (package.coinsAmount >= 200 ? 5 : 0);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: primaryYellow.withOpacity(0.25)),
      ),
      color: secondaryGrey,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (isAffordable) {
            _buyPackage(context, package, provider);
          } else {
            _showRechargeDialog(context, currentBalance, package.priceXof);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // 🔥 Badge
              if (discount > 0)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '-$discount%',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ),

              // 🔥 Contenu principal
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryYellow, Colors.amber],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _packageIcon(package.name),
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Nom du pack
                    Text(
                      package.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Nombre de pièces
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.monetization_on, color: primaryYellow, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          t.datingCoinsCount.replaceAll('{count}', _formatNumber(package.coinsAmount)),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[300],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Prix
                    Text(
                      '${_formatNumber(package.priceXof.toInt())} FCFA',
                      style: TextStyle(
                        fontSize: 16,
                        color: primaryYellow,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // 🔥 Bouton
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (isAffordable) {
                      _buyPackage(context, package, provider);
                    } else {
                      _showRechargeDialog(context, currentBalance, package.priceXof);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    isAffordable ? primaryYellow : Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    isAffordable ? t.datingBuyButton : t.datingRechargeNow,
                    style: TextStyle(
                      color: isAffordable ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}