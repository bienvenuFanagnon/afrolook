//BuyCoinsPage - Page d'achat de pièces

// lib/pages/coins/buy_coins_page.dart
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

class _BuyCoinsPageState extends State<BuyCoinsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CoinProvider>(context, listen: false).loadCoinPackages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context);
    final currentBalance = authProvider.loginUserData.votre_solde_principal ?? 0;
    final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Acheter des pièces',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade400, Colors.orange.shade600],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Votre solde',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${currentBalance.toStringAsFixed(0)} FCFA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.monetization_on,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '$currentCoins pièces',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<CoinProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.availablePackages.isEmpty) {
                  return Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Erreur: ${provider.error}'),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.loadCoinPackages(),
                          child: Text('Réessayer'),
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
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Aucun pack disponible',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: provider.availablePackages.length,
                  itemBuilder: (context, index) {
                    final package = provider.availablePackages[index];
                    return _buildPackageCard(context, package, provider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(
      BuildContext context,
      CoinPackage package,
      CoinProvider provider,
      ) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentBalance = authProvider.loginUserData.votre_solde_principal ?? 0;
    final isAffordable = currentBalance >= package.priceXof;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.amber.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.monetization_on,
                  size: 40,
                  color: Colors.amber.shade800,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '${package.coinsAmount}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
              Text(
                'pièces',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '${package.priceXof.toStringAsFixed(0)} FCFA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              SizedBox(height: 8),
              if (!isAffordable)
                Text(
                  'Solde insuffisant',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: isAffordable && !provider.isLoading
                    ? () => _buyPackage(context, package, provider)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAffordable ? Colors.amber.shade700 : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  minimumSize: Size(double.infinity, 40),
                ),
                child: provider.isLoading
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  'Acheter',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buyPackage(
      BuildContext context,
      CoinPackage package,
      CoinProvider provider,
      ) async {
    final success = await provider.buyCoins(package);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Achat réussi ! Vous avez reçu ${package.coinsAmount} pièces.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'achat'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}