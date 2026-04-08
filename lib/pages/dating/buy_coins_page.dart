import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dating_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/dating/coin_provider.dart';


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
    _loadCoinPackages();
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

              const Text(
                "Solde insuffisant",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Solde: ${balance.toStringAsFixed(0)} FCFA\n"
                    "Requis: ${required.toStringAsFixed(0)} FCFA",
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
                child: const Text(
                  "Recharger maintenant",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Plus tard",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _loadCoinPackages() async {
    print('📱 === Chargement des packs de pièces ===');
    final provider = Provider.of<CoinProvider>(context, listen: false);
    await provider.loadCoinPackages();
    print('📊 Packs disponibles: ${provider.availablePackages.length}');
  }

  Future<void> _buyPackage(
      BuildContext context,
      CoinPackage package,
      CoinProvider provider,
      ) async {
    print('📱 === Achat de pièces ===');
    print('📦 Pack: ${package.name}');
    print('💰 Coût: ${package.priceXof} FCFA');
    print('🎁 Pièces: ${package.coinsAmount}');

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentBalance = authProvider.loginUserData.votre_solde_principal ?? 0;
    print('💳 Solde actuel: $currentBalance FCFA');

    if (currentBalance < package.priceXof) {
      print('❌ Solde insuffisant');
      _showErrorDialog('Solde insuffisant',
          'Vous n\'avez pas assez de FCFA pour acheter ce pack.\n'
              'Solde disponible: ${currentBalance.toStringAsFixed(0)} FCFA\n'
              'Prix du pack: ${package.priceXof.toStringAsFixed(0)} FCFA');
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
            const Text('Confirmer l\'achat', style: TextStyle(color: Colors.white)),
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
                '${package.coinsAmount}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Acheter ${package.coinsAmount} pièces',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${package.priceXof.toStringAsFixed(0)} FCFA',
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
                    'Solde après achat: ${(currentBalance - package.priceXof).toStringAsFixed(0)} FCFA',
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
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
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
              'Confirmer',
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
            Text('Traitement en cours...', style: TextStyle(color: Colors.white)),
            SizedBox(height: 8),
            Text('Veuillez patienter', style: TextStyle(color: Colors.grey[400])),
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
      _showErrorDialog('Erreur', 'Une erreur est survenue lors de l\'achat. Veuillez réessayer.');
    }
  }

  void _showSuccessDialog(CoinPackage package) {
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
            const Text(
              'Achat réussi !',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vous avez reçu ${package.coinsAmount} pièces',
              style: TextStyle(
                fontSize: 14,
                color: primaryYellow,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Utilisez vos pièces pour des super likes, abonnements et contenus exclusifs !',
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
              'Redirection...',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
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
            child: const Text('OK', style: TextStyle(color: Colors.white)),
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
    final authProvider = Provider.of<UserAuthProvider>(context);
    final currentBalance = authProvider.loginUserData.votre_solde_principal ?? 0;
    final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;

    print('📱 Build BuyCoinsPage - Solde: $currentBalance FCFA, Pièces: $currentCoins');

    return Scaffold(
      backgroundColor: primaryBlack,
      appBar: AppBar(
        title: const Text(
          'Acheter des pièces',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    const Text(
                      'Votre solde',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
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
                            '$currentCoins pièces',
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
                        '100 pièces = 250 FCFA',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

              // Liste des packs
              Expanded(
                child: Consumer<CoinProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.availablePackages.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Chargement des packs...'),
                          ],
                        ),
                      );
                    }

                    if (provider.error != null) {
                      print('❌ Erreur chargement packs: ${provider.error}');
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 60, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              'Erreur: ${provider.error}',
                              style: TextStyle(color: Colors.grey[400]),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => provider.loadCoinPackages(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                              ),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (provider.availablePackages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[600]),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun pack disponible',
                              style: TextStyle(color: Colors.grey[500], fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Revenez plus tard',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: provider.availablePackages.length,
                      itemBuilder: (context, index) {
                        final package = provider.availablePackages[index];
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

  Widget _buildPackageCard(
      BuildContext context,
      CoinPackage package,
      CoinProvider provider,
      double currentBalance,
      ) {
    final isAffordable = currentBalance >= package.priceXof;
    final discount = package.coinsAmount >= 500 ? 10 : (package.coinsAmount >= 200 ? 5 : 0);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryYellow, Colors.amber],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${package.coinsAmount}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      '${package.coinsAmount} pièces',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '${package.priceXof.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
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
                    isAffordable ? 'Acheter' : 'Recharger',
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