// lib/pages/creator/creator_subscription_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/authProvider.dart';
import '../../providers/dating/coin_provider.dart';
import '../../providers/dating/creator_provider.dart';
import 'buy_coins_page.dart';

class CreatorSubscriptionPage extends StatefulWidget {
  final String creatorId;
  final String creatorName;

  const CreatorSubscriptionPage({
    Key? key,
    required this.creatorId,
    required this.creatorName,
  }) : super(key: key);

  @override
  State<CreatorSubscriptionPage> createState() => _CreatorSubscriptionPageState();
}

class _CreatorSubscriptionPageState extends State<CreatorSubscriptionPage> {
  bool _isSubscribing = false;
  bool _isPaidSubscription = false;
  int _subscriptionPrice = 500; // 500 coins par défaut

  final Color primaryRed = const Color(0xFFE63946);
  final Color primaryYellow = const Color(0xFFFFD700);
  final Color primaryBlack = Colors.black;
  final Color secondaryGrey = const Color(0xFF2C2C2C);
  final Color lightGrey = const Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context);
    final creatorProvider = Provider.of<CreatorProvider>(context, listen: false);
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);

    final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;

    return Scaffold(
      backgroundColor: primaryBlack,
      appBar: AppBar(
        title: Text(
          'S\'abonner à ${widget.creatorName}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryRed,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header avec icône et solde
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
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.star, size: 40, color: primaryYellow),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Soutenez ${widget.creatorName}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Abonnez-vous pour accéder à du contenu exclusif',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '$currentCoins pièces disponibles',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Options d'abonnement
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSubscriptionOption(
                    title: 'Abonnement gratuit',
                    price: 0,
                    isFree: true,
                    benefits: const [
                      'Accès aux contenus gratuits',
                      'Notifications des nouveaux contenus',
                      'Soutien au créateur',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSubscriptionOption(
                    title: 'Abonnement Premium',
                    price: _subscriptionPrice,
                    isFree: false,
                    benefits: const [
                      'Accès à TOUS les contenus',
                      'Contenus exclusifs',
                      'Accès aux lives privés',
                      'Badge de supporter',
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Message d'avertissement si solde insuffisant
                  if (_isPaidSubscription && currentCoins < _subscriptionPrice)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Il vous manque ${_subscriptionPrice - currentCoins} pièces. '
                                  'Achetez des pièces pour continuer.',
                              style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubscribing
                        ? null
                        : () => _subscribe(
                      context,
                      creatorProvider,
                      coinProvider,
                      authProvider,
                      currentCoins,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPaidSubscription
                          ? (_isPaidSubscription && currentCoins < _subscriptionPrice
                          ? Colors.grey
                          : primaryYellow)
                          : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isSubscribing
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      _isPaidSubscription
                          ? 'S\'abonner pour $_subscriptionPrice pièces'
                          : 'S\'abonner gratuitement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isPaidSubscription && currentCoins < _subscriptionPrice
                            ? Colors.white70
                            : primaryBlack,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Plus tard'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionOption({
    required String title,
    required int price,
    required bool isFree,
    required List<String> benefits,
  }) {
    final isSelected = _isPaidSubscription == !isFree;

    return GestureDetector(
      onTap: () {
        if (!_isSubscribing) {
          setState(() {
            _isPaidSubscription = !isFree;
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? primaryRed : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? primaryRed.withOpacity(0.05) : secondaryGrey,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? primaryRed : Colors.white,
                      ),
                    ),
                  ),
                  if (!isFree)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on,
                            size: 14,
                            color: Colors.amber.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$price pièces',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isFree)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Gratuit',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ...benefits.map((benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: isSelected ? primaryRed : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        benefit,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.grey.shade800 : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _subscribe(
      BuildContext context,
      CreatorProvider creatorProvider,
      CoinProvider coinProvider,
      UserAuthProvider authProvider,
      int currentCoins,
      ) async {
    if (_isPaidSubscription && currentCoins < _subscriptionPrice) {
      // Afficher un modal avec option d'achat de pièces
      final shouldBuy = await _showInsufficientCoinsDialog(context);
      if (shouldBuy) {
        // Naviguer vers la page d'achat de pièces
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BuyCoinsPage()),
        );
      }
      return;
    }

    setState(() => _isSubscribing = true);

    try {
      bool success;
      if (_isPaidSubscription) {
        success = await creatorProvider.subscribeToCreator(
          creatorId: widget.creatorId,
          isPaid: true,
          paidCoinsAmount: _subscriptionPrice,
        );
      } else {
        success = await creatorProvider.subscribeToCreator(
          creatorId: widget.creatorId,
          isPaid: false,
        );
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Abonnement réussi !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de l\'abonnement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubscribing = false);
      }
    }
  }

  Future<bool> _showInsufficientCoinsDialog(BuildContext context) async {
    return await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: secondaryGrey,
        title: Row(
          children: [
            Icon(Icons.monetization_on, color: primaryYellow),
            const SizedBox(width: 8),
            const Text('Solde insuffisant', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vous n\'avez pas assez de pièces pour cet abonnement.',
              style: TextStyle(color: Colors.grey[300]),
            ),
            const SizedBox(height: 8),
            Text(
              'Achetez des pièces pour continuer.',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pièces nécessaires :', style: TextStyle(color: Colors.grey[400])),
                  Text('$_subscriptionPrice', style: TextStyle(color: primaryYellow, fontWeight: FontWeight.bold)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text('Acheter des pièces', style: TextStyle(color: primaryBlack)),
          ),
        ],
      ),
    ) ?? false;
  }
}