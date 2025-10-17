import 'package:afrotok/providers/authProvider.dart';
import 'package:cinetpay/cinetpay.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../paiement/newDepot.dart';
import '../../user/monetisation.dart';


import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as Path;
import 'dart:io';

// Models (à adapter selon vos imports)
// import 'package:your_app/models/entreprise_data.dart';
// import 'package:your_app/models/user_data.dart';
// import 'package:your_app/models/entreprise_abonnement.dart';
// import 'package:your_app/enums/type_abonnement.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';

class PremiumSubscriptionPage extends StatefulWidget {
  final EntrepriseData? entreprise;
  final UserData user;

  const PremiumSubscriptionPage({
    Key? key,
    required this.entreprise,
    required this.user,
  }) : super(key: key);

  @override
  State<PremiumSubscriptionPage> createState() => _PremiumSubscriptionPageState();
}

class _PremiumSubscriptionPageState extends State<PremiumSubscriptionPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late UserAuthProvider authProvider;
  bool isLoading = false;
  int selectedDays = 30;
  double minProductCount = 15.0; // 15 posts pour 30 jours
  double maxProductCount = 100.0; // 100 posts pour 365 jours

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = _calculateTotalPrice();
    final productCount = _calculateProductCount();
    final hasEnoughBalance = (widget.user.votre_solde_principal ?? 0) >= totalPrice;
    final canSubscribe = _canSubscribeToPremium(widget.entreprise?.abonnement);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Abonnement Premium',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.02),
              Color(0xFF2ECC71).withOpacity(0.05),
              Colors.amber.withOpacity(0.02),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête premium
              _buildPremiumHeader(),
              SizedBox(height: 20),

              // Information abonnement actuel
              _buildCurrentSubscriptionInfo(),
              SizedBox(height: 20),

              // Carte des avantages
              _buildBenefitsCard(),
              SizedBox(height: 20),

              // Sélecteur de durée
              _buildDurationSelector(totalPrice, productCount),
              SizedBox(height: 20),

              // Détails de l'abonnement
              _buildSubscriptionDetails(totalPrice, productCount),
              SizedBox(height: 30),

              // Bouton de souscription
              _buildSubscribeButton(totalPrice, hasEnoughBalance, canSubscribe),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black,
            Color(0xFF2ECC71),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ABONNEMENT PREMIUM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'De 15 à 100 posts selon la durée !',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber),
            ),
            child: Text(
              '📈 PROGRESSION DES POSTS',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSubscriptionInfo() {
    final currentAbonnement = widget.entreprise?.abonnement;
    final hasActiveSubscription = currentAbonnement != null &&
        currentAbonnement.isFinished == false &&
        currentAbonnement.end! > DateTime.now().millisecondsSinceEpoch;

    if (hasActiveSubscription) {
      final daysLeft = _calculateDaysLeft(currentAbonnement.end!);
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.amber[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Abonnement en cours',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _buildInfoRow('Type', currentAbonnement.type ?? "Inconnu"),
              _buildInfoRow('Jours restants', '$daysLeft jours'),
              if (currentAbonnement.type != TypeAbonement.GRATUIT.name)
                _buildInfoRow('Produits restants', '${_calculateRemainingProducts(currentAbonnement)}'),
            ],
          ),
        ),
      );
    }
    return SizedBox();
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Color(0xFF2ECC71),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎯 AVANTAGES PREMIUM',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16),
            _buildBenefitItem(
              '📦 De 15 à 100 posts',
              'Plus la durée est longue, plus vous avez de posts !',
            ),
            _buildBenefitItem(
              '👀 Visibilité maximale',
              'Apparaissez dans toutes les pages de l\'application',
            ),
            _buildBenefitItem(
              '🖼️ 5 images par produit',
              'Montrez vos produits sous tous les angles',
            ),
            _buildBenefitItem(
              '🚀 5 boosts gratuits',
              'Mettez vos produits en avant gratuitement',
            ),
            _buildBenefitItem(
              '📊 Statistiques détaillées',
              'Suivez les performances de vos produits',
            ),
            _buildBenefitItem(
              '🔔 Notifications abonnés',
              'Alertes instantanées pour vos nouveaux produits',
            ),
            _buildBenefitItem(
              '⭐ Support prioritaire',
              'Assistance rapide pour vos questions',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Color(0xFF2ECC71).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              color: Color(0xFF2ECC71),
              size: 16,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSelector(double totalPrice, double productCount) {
    double postsProgress = (productCount - minProductCount) / (maxProductCount - minProductCount);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⏰ DURÉE DE L\'ABONNEMENT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '$selectedDays jours',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2ECC71),
              ),
            ),
            SizedBox(height: 12),
            Slider(
              min: 30,
              max: 365,
              divisions: 11,
              value: selectedDays.toDouble(),
              activeColor: Color(0xFF2ECC71),
              inactiveColor: Colors.grey[300],
              thumbColor: Colors.amber,
              label: '$selectedDays jours',
              onChanged: (newValue) {
                setState(() {
                  selectedDays = newValue.toInt();
                });
              },
            ),
            SizedBox(height: 16),

            // Barre de progression des posts
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Posts inclus',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${productCount.toInt()} posts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2ECC71),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: postsProgress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '15 posts',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '100 posts',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  _buildPriceRow('Prix total', '${totalPrice.toInt()} FCFA'),
                  SizedBox(height: 8),
                  _buildPriceRow('Posts par mois', '~${(productCount / (selectedDays / 30)).roundToDouble().toInt()}'),

                  if (selectedDays > 30)
                    SizedBox(height: 8),
                  if (selectedDays > 30)
                    _buildDiscountBadge(),
                  if (selectedDays >= 365)
                    SizedBox(height: 8),
                  if (selectedDays >= 365)
                    _buildMaxPostsBadge(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2ECC71),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountBadge() {
    double discount = selectedDays > 60 ? 10.0 : 4.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_offer, size: 14, color: Colors.amber[800]),
          SizedBox(width: 4),
          Text(
            'Réduction de $discount% !',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.amber[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaxPostsBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFF2ECC71).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF2ECC71)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.celebration, size: 14, color: Color(0xFF2ECC71)),
          SizedBox(width: 4),
          Text(
            'MAXIMUM 100 POSTS ATTEINT !',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2ECC71),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionDetails(double totalPrice, double productCount) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📋 RÉCAPITULATIF',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            _buildDetailRow('Durée de l\'abonnement', '$selectedDays jours'),
            _buildDetailRow('Prix total', '${totalPrice.toInt()} FCFA'),
            _buildDetailRow('Nombre total de posts', '${productCount.toInt()}'),
            _buildDetailRow('Posts par mois', '~${(productCount / (selectedDays / 30)).roundToDouble().toInt()}'),
            _buildDetailRow('Produits boostés inclus', '5'),
            _buildDetailRow('Images par produit', '5'),
            _buildDetailRow('Support prioritaire', 'Inclus'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2ECC71),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton(double totalPrice, bool hasEnoughBalance, bool canSubscribe) {
    return Column(
      children: [
        if (!hasEnoughBalance)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Solde insuffisant. Il vous manque ${(totalPrice - (widget.user.votre_solde_principal ?? 0)).toInt()} FCFA',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: (hasEnoughBalance && canSubscribe) ? Color(0xFF2ECC71) : Colors.grey,
              foregroundColor: Colors.white,
              elevation: 4,
              padding: EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              shadowColor: (hasEnoughBalance && canSubscribe) ? Color(0xFF2ECC71) : Colors.grey,
            ),
            onPressed: isLoading
                ? null
                : () {
              if (!canSubscribe) {
                _showCannotSubscribeDialog();
                return;
              }
              if (!hasEnoughBalance) {
                _showInsufficientBalanceDialog(totalPrice);
                return;
              }
              _subscribeToPremium();
            },
            child: isLoading
                ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, size: 20),
                SizedBox(width: 8),
                Text(
                  'S\'ABONNER - ${totalPrice.toInt()} FCFA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Logique de calcul
  double _calculateTotalPrice() {
    if (selectedDays <= 30) {
      return 2000.0; // Prix de base pour 30 jours
    } else if (selectedDays <= 60) {
      return (2000.0 * (selectedDays / 30)) * 0.96;
    } else {
      return (2000.0 * (selectedDays / 30)) * 0.90;
    }
  }

  double _calculateProductCount() {
    // Calcul linéaire de 15 posts à 30 jours jusqu'à 100 posts à 365 jours
    double progress = (selectedDays - 30) / (365 - 30);
    double productCount = minProductCount + (progress * (maxProductCount - minProductCount));

    return productCount.floorToDouble();
  }

  bool _canSubscribeToPremium(EntrepriseAbonnement? currentAbonnement) {
    if (currentAbonnement == null) return true;
    final isExpired = currentAbonnement.isFinished == true ||
        currentAbonnement.end! <= DateTime.now().millisecondsSinceEpoch;
    final isFree = currentAbonnement.type == TypeAbonement.GRATUIT.name;
    return isExpired || isFree;
  }

  int _calculateDaysLeft(int endTimestamp) {
    final endDate = DateTime.fromMillisecondsSinceEpoch(endTimestamp);
    final now = DateTime.now();
    final difference = endDate.difference(now);
    return difference.inDays.clamp(0, 365);
  }

  int _calculateRemainingProducts(EntrepriseAbonnement abonnement) {
    return (abonnement.nombre_pub ?? 0) - (widget.entreprise?.produitsIds?.length ?? 0);
  }

  void _showCannotSubscribeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Abonnement en cours', style: TextStyle(color: Colors.black87)),
        content: Text('Vous avez déjà un abonnement premium actif. '
            'Veuillez attendre qu\'il expire pour souscrire à un nouvel abonnement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Compris', style: TextStyle(color: Color(0xFF2ECC71))),
          ),
        ],
      ),
    );
  }

  void _showInsufficientBalanceDialog(double requiredAmount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Solde insuffisant', style: TextStyle(color: Colors.black87)),
        content: Text('Votre solde (${widget.user.votre_solde_principal?.toInt() ?? 0} FCFA) '
            'est insuffisant pour cet abonnement (${requiredAmount.toInt()} FCFA). '
            'Voulez-vous recharger votre compte ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => DepositScreen()));
            },
            child: Text('Recharger', style: TextStyle(color: Color(0xFF2ECC71))),
          ),
        ],
      ),
    );
  }

  Future<void> _subscribeToPremium() async {
    if (widget.entreprise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez d\'abord créer une entreprise')),
      );
      return;
    }

    setState(() { isLoading = true; });

    try {
      final totalPrice = _calculateTotalPrice();
      final productCount = _calculateProductCount().toInt();
      final userDoc = await firestore.collection('Users').doc(widget.user.id!).get();

      if (!userDoc.exists) throw Exception('Utilisateur non trouvé');

      final userData = UserData.fromJson(userDoc.data()!);

      if ((userData.votre_solde_principal ?? 0) < totalPrice) {
        _showInsufficientBalanceDialog(totalPrice);
        setState(() { isLoading = false; });
        return;
      }

      final now = DateTime.now();
      final endDate = now.add(Duration(days: selectedDays));

      EntrepriseAbonnement abonnement = EntrepriseAbonnement()
        ..type = TypeAbonement.PREMIUM.name
        ..id = firestore.collection('EntrepriseAbonnements').doc().id
        ..entrepriseId = widget.entreprise!.id!
        ..description = "Abonnement Premium - $selectedDays jours"
        ..nombre_pub = productCount
        ..nombre_image_pub = 5
        ..nbr_jour_pub_afrolook = 0
        ..nbr_jour_pub_annonce_afrolook = 0
        ..userId = widget.user.id!
        ..afroshop_user_magasin_id = ""
        ..createdAt = now.millisecondsSinceEpoch
        ..updatedAt = now.millisecondsSinceEpoch
        ..star = now.millisecondsSinceEpoch
        ..end = endDate.millisecondsSinceEpoch
        ..isFinished = false
        ..dispo_afrolook = false
        ..produistIdBoosted = [];

      await firestore.collection('Users').doc(widget.user.id!).update({
        'votre_solde_principal': FieldValue.increment(-totalPrice),
      });

      await authProvider.incrementAppGain(totalPrice);

      await firestore.collection('TransactionSoldes').add({
        'user_id': widget.user.id,
        'montant': totalPrice,
        'type': TypeTransaction.DEPENSE.name,
        'description': 'Abonnement Premium - $selectedDays jours',
        'createdAt': now.millisecondsSinceEpoch,
        'statut': StatutTransaction.VALIDER.name,
      });

      await firestore.collection('Entreprises').doc(widget.entreprise!.id!).update({
        'abonnement': abonnement.toJson(),
        'updatedAt': now.millisecondsSinceEpoch,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Color(0xFF2ECC71),
          content: Text('🎉 Abonnement Premium activé pour $selectedDays jours avec ${productCount} posts !'),
        ),
      );

      Navigator.pop(context);

    } catch (e) {
      print("Erreur lors de l'abonnement: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Erreur lors de l\'abonnement: ${e.toString()}'),
        ),
      );
    } finally {
      setState(() { isLoading = false; });
    }
  }
}

// class SubscriptionPage extends StatefulWidget {
//   @override
//   State<SubscriptionPage> createState() => _SubscriptionPageState();
// }
//
// class _SubscriptionPageState extends State<SubscriptionPage> {
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Choisissez un abonnement'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: SingleChildScrollView(
//           child: Column(
//             children: [
//               _buildSubscriptionTile(
//                 context,
//                 icon: Icons.free_breakfast,
//                 title: 'Gratuit',
//                 price: '0 FCFA',
//                 features: [
//                   'Nombre de produits à poster 📦 : 10',
//                   "Nombre d'images par produit 📸 : 1",
//                 ],
//                 isPremium: false,
//               ),
//               SizedBox(height: 20),
//               _buildSubscriptionTile(
//                 context,
//                 icon: Icons.star,
//                 title: 'Premium',
//                 price: '2000 FCFA / 30 jours',
//                 features: [
//                   "Nombre de produits à poster: Illimité 📦",
//                   "Visible dans les autres pages 👀",
//                   "Nombre d'images par produit 📸 : 5",
//                   "Nombre de produit à Booster 🚀 : 5",
//                   "Voir les statistiques 📊",
//                   "Notifier vos abonnés pour chaque produit 🔔",
//                 ],
//                 isPremium: true,
//               ),
//               SizedBox(height: 20),
//               _buildSubscriptionTile(
//                 context,
//                 icon: Icons.ads_click,
//                 title: 'Afrolook Ads',
//                 price: 'Contactez-nous',
//                 features: [
//                   "Toutes les fonctionnalités du plan Premium",
//                   "Publicité de vos produits sur :",
//                   "Facebook Ads",
//                   "Instagram Ads",
//                   "Google Ads",
//                   "TikTok Ads",
//                   "LinkedIn Ads",
//                   "Twitter Ads",
//                   "Snapchat Ads",
//                   "YouTube Ads",
//                 ],
//                 isPremium: true,
//                 isContact: true,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSubscriptionTile(BuildContext context, {
//     required IconData icon,
//     required String title,
//     required String price,
//     required List<String> features,
//     required bool isPremium,
//     bool isContact = false,
//   }) {
//     return Card(
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(15),
//       ),
//       elevation: 5,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             ListTile(
//               leading: Icon(icon, color: isPremium ? Colors.orange : Colors.blue, size: 30),
//               title: Text(
//                 title,
//                 style: TextStyle(
//                   fontSize: 22,
//                   fontWeight: FontWeight.bold,
//                   color: isPremium ? Colors.orange : Colors.blue,
//                 ),
//               ),
//             ),
//             SizedBox(height: 10),
//             ...features.map((feature) => ListTile(
//               leading: Icon(Icons.check_circle, color: Colors.green),
//               title: Text(feature, style: TextStyle(fontSize: 16)),
//             )),
//             SizedBox(height: 15),
//             Center(
//               child: Text(
//                 price,
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//             ),
//             SizedBox(height: 10),
//             if (isPremium)
//               Center(
//                 child: ElevatedButton(
//                   onPressed: () {
//                     if (isContact) {
//                       Navigator.pushNamed(context, '/contact');
//                     } else {
//                       _showSubscriptionModal(context);
//                     }
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     foregroundColor: Colors.white,
//                   ),
//                   child: Text(isContact ? 'Contactez-nous' : 'Sélectionner'),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _showSubscriptionModal(BuildContext context) {
//     int days = 30;
//     double pricePer30Days = 2000;
//     double calculatedPrice = pricePer30Days;
//     double discountRate = 0.0;
//
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text('Sélectionnez la durée'),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   RichText(
//                     text: TextSpan(
//                       style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
//                       children: <TextSpan>[
//                         TextSpan(text: 'Réduction de '),
//                         TextSpan(
//                           text: '4%',
//                           style: TextStyle(color: Colors.green),
//                         ),
//                         TextSpan(text: ' pour plus de 30 jours:'),
//                         TextSpan(text: '\n'), // Saut de ligne
//                         TextSpan(text: 'Réduction de '),
//                         TextSpan(
//                           text: '10%',
//                           style: TextStyle(color: Colors.green),
//                         ),
//                         TextSpan(text: ' pour plus de 60 jours:'),
//                       ],
//                     ),
//                   ),
//                   SizedBox(height: 10),
//                   Text('Nombre de jours:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                   Slider(
//                     min: 30,
//                     max: 365,
//                     divisions: 11,
//                     value: days.toDouble(),
//                     activeColor: Colors.green,
//                     inactiveColor: Colors.grey,
//                     label: '$days jours',
//                     onChanged: (newValue) {
//                       setState(() {
//                         days = newValue.toInt();
//                         if (days > 60) {
//                           discountRate = 0.10;
//                         } else if (days > 30) {
//                           discountRate = 0.04;
//                         } else {
//                           discountRate = 0.0;
//                         }
//                         calculatedPrice = ((days / 30) * pricePer30Days) * (1 - discountRate);
//                       });
//                     },
//                   ),
//                   Text('$days jours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
//                   Text('${calculatedPrice.toStringAsFixed(0)} FCFA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
//                   if (discountRate > 0)
//                     Text('Réduction de ${(discountRate * 100).toInt()}% appliquée!', style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
//                 ],
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.pop(context),
//                   style: TextButton.styleFrom(foregroundColor: Colors.red),
//                   child: Text('Annuler'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     // Navigator.push(context, MaterialPageRoute(builder: (context) =>  paiment(double.parse(calculatedPrice.toStringAsFixed(0)))
//                     // ,));
//
//                     showContactSubscriptionModal(context);
//
//                   },
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
//                   child: Text('Confirmer'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
//
//   void showContactSubscriptionModal(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (_) => Dialog(
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               CircleAvatar(
//                 radius: 30,
//                 backgroundColor: Color(0xFFF1C40F).withOpacity(0.1),
//                 child: Icon(Icons.contact_support, color: Color(0xFFF1C40F), size: 32),
//               ),
//               SizedBox(height: 12),
//               Text(
//                 "Abonnement requis",
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//               SizedBox(height: 8),
//               Text(
//                 "Pour profiter de cette fonctionnalité, veuillez nous contacter pour souscrire à un abonnement.",
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 13, color: Colors.black54),
//               ),
//               SizedBox(height: 20),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Color(0xFF2ECC71),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                 ),
//                 onPressed: () {
//                   Navigator.pop(context);
//                   Navigator.pushNamed(context, '/contact');
//
//                   // Ici tu peux ouvrir WhatsApp ou un mail pour le contact
//                   // par exemple : launchUrl(Uri.parse('https://wa.me/+22896198801'));
//                 },
//                 child: Text("Nous contacter", style: TextStyle(color: Colors.white)),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
// }