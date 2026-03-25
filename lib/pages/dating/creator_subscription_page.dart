// CreatorSubscriptionPage - Page d'abonnement créateur

// lib/pages/creator/creator_subscription_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/authProvider.dart';
import '../../providers/dating/coin_provider.dart';
import '../../providers/dating/creator_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context);
    final creatorProvider = Provider.of<CreatorProvider>(context, listen: false);
    final coinProvider = Provider.of<CoinProvider>(context, listen: false);

    final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'S\'abonner à ${widget.creatorName}',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.pink.shade50,
                    Colors.white,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.star,
                    size: 60,
                    color: Colors.amber.shade600,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Soutenez ${widget.creatorName}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Abonnez-vous pour accéder à du contenu exclusif',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSubscriptionOption(
                    context,
                    title: 'Abonnement gratuit',
                    price: 0,
                    isFree: true,
                    benefits: [
                      'Accès aux contenus gratuits',
                      'Notifications des nouveaux contenus',
                      'Soutien au créateur',
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildSubscriptionOption(
                    context,
                    title: 'Abonnement Premium',
                    price: _subscriptionPrice,
                    isFree: false,
                    benefits: [
                      'Accès à TOUS les contenus',
                      'Contenus exclusifs',
                      'Accès aux lives privés',
                      'Badge de supporter',
                    ],
                  ),
                  SizedBox(height: 24),
                  if (_isPaidSubscription)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.shade700,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Vous avez ${currentCoins} pièces. '
                                  'Il vous manque ${_subscriptionPrice - currentCoins} pièces '
                                  'pour cet abonnement.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubscribing
                        ? null
                        : () => _subscribe(
                      context,
                      creatorProvider,
                      coinProvider,
                      authProvider,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPaidSubscription
                          ? Colors.amber.shade700
                          : Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubscribing
                        ? SizedBox(
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
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Plus tard'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionOption(
      BuildContext context, {
        required String title,
        required int price,
        required bool isFree,
        required List<String> benefits,
      }) {
    final isSelected = _isPaidSubscription == !isFree;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isPaidSubscription = !isFree;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.red.shade400 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? Colors.red.shade50 : Colors.white,
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
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
                        color: isSelected ? Colors.red.shade700 : Colors.grey.shade800,
                      ),
                    ),
                  ),
                  if (!isFree)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on,
                            size: 16,
                            color: Colors.amber.shade800,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '$price pièces',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isFree)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Gratuit',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12),
              ...benefits.map((benefit) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        benefit,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
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
      ) async {
    setState(() => _isSubscribing = true);

    try {
      bool success;
      if (_isPaidSubscription) {
        // Vérifier le solde
        final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;
        if (currentCoins < _subscriptionPrice) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Solde de pièces insuffisant. Veuillez acheter des pièces.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSubscribing = false);
          return;
        }

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
            content: Text('Abonnement réussi !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'abonnement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubscribing = false);
      }
    }
  }
}