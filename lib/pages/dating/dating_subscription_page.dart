// lib/pages/dating/dating_subscription_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/dating/coin_provider.dart';
import '../../providers/dating/dating_provider.dart';
import 'buy_coins_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatingSubscriptionPage extends StatefulWidget {
  const DatingSubscriptionPage({Key? key}) : super(key: key);

  @override
  State<DatingSubscriptionPage> createState() => _DatingSubscriptionPageState();
}

class _DatingSubscriptionPageState extends State<DatingSubscriptionPage> {
  List<SubscriptionPlan> _plans = [];
  bool _isLoading = true;
  bool _isSubscribing = false;
  String? _error;
  SubscriptionPlan? _selectedPlan;
  String? _currentSubscriptionPlan;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkAndCreatePlans();
  }

  Future<void> _checkAndCreatePlans() async {
    print('📱 === Vérification et création des plans d\'abonnement ===');
    setState(() => _isLoading = true);

    try {
      // Vérifier si les plans existent
      final snapshot = await firestore
          .collection('subscription_plans')
          .where('isActive', isEqualTo: true)
          .get();

      print('📊 Nombre de plans trouvés: ${snapshot.docs.length}');

      final existingCodes = snapshot.docs.map((doc) => doc['code'] as String).toList();
      print('📊 Plans existants: $existingCodes');

      final now = DateTime.now().millisecondsSinceEpoch;
      bool needsRefresh = false;

      // Créer le plan Plus s'il n'existe pas
      if (!existingCodes.contains('plus')) {
        print('➕ Création du plan Plus...');
        await firestore.collection('subscription_plans').add({
          'code': 'plus',
          'name': 'AfroLove Plus',
          'description': 'Profitez de plus de fonctionnalités',
          'priceCoins': 500,
          'durationInDays': 30,
          'features': [
            '50 likes par jour',
            '2 super likes par jour',
            'Voir qui vous a liké',
            'Message prioritaire',
            'Badge exclusif',
          ],
          'isActive': true,
          'createdAt': now,
          'updatedAt': now,
        });
        print('✅ Plan Plus créé avec succès');
        needsRefresh = true;
      }

      // Créer le plan Gold s'il n'existe pas
      if (!existingCodes.contains('gold')) {
        print('💎 Création du plan Gold...');
        await firestore.collection('subscription_plans').add({
          'code': 'gold',
          'name': 'AfroLove Gold',
          'description': 'L\'expérience ultime',
          'priceCoins': 1500,
          'durationInDays': 30,
          'features': [
            'Likes illimités',
            '5 super likes par jour',
            'Voir qui vous a liké',
            'Message prioritaire',
            'Badge Gold exclusif',
            'Profil mis en avant',
            'Boost quotidien',
          ],
          'isActive': true,
          'createdAt': now,
          'updatedAt': now,
        });
        print('✅ Plan Gold créé avec succès');
        needsRefresh = true;
      }

      // Créer le plan Gratuit s'il n'existe pas
      if (!existingCodes.contains('gratuit')) {
        print('🎁 Création du plan Gratuit...');
        await firestore.collection('subscription_plans').add({
          'code': 'gratuit',
          'name': 'Gratuit',
          'description': 'Fonctionnalités de base',
          'priceCoins': 0,
          'durationInDays': 0,
          'features': [
            '10 likes par jour',
            '1 super like par jour',
            'Profils recommandés',
          ],
          'isActive': true,
          'createdAt': now,
          'updatedAt': now,
        });
        print('✅ Plan Gratuit créé avec succès');
        needsRefresh = true;
      }

      if (needsRefresh) {
        print('🔄 Rechargement des plans...');
        await _loadPlans();
      } else {
        await _loadPlans();
      }

    } catch (e) {
      print('❌ Erreur lors de la vérification des plans: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPlans() async {
    print('📱 === Chargement des plans d\'abonnement dating ===');

    try {
      final snapshot = await firestore
          .collection('subscription_plans')
          .where('isActive', isEqualTo: true)
          .orderBy('priceCoins')
          .get();

      print('📊 Nombre de plans trouvés: ${snapshot.docs.length}');

      _plans = snapshot.docs
          .map((doc) => SubscriptionPlan.fromJson(doc.data()))
          .toList();

      // Afficher les plans chargés
      for (var plan in _plans) {
        print('   📌 ${plan.name} - ${plan.priceCoins} coins');
      }

      print('✅ Plans chargés avec succès');
      setState(() => _isLoading = false);

      // Charger l'abonnement actuel après avoir les plans
      _loadCurrentSubscription();

    } catch (e) {
      print('❌ Erreur chargement plans: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentSubscription() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final userId = authProvider.loginUserData.id;

    if (userId == null) return;

    try {
      final snapshot = await firestore
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final subscription = UserDatingSubscription.fromJson(snapshot.docs.first.data());
        _currentSubscriptionPlan = subscription.planCode;
        print('📌 Abonnement actuel: $_currentSubscriptionPlan');

        // Vérifier si l'abonnement est expiré
        final now = DateTime.now().millisecondsSinceEpoch;
        if (subscription.endAt <= now) {
          print('⚠️ Abonnement expiré');
          _currentSubscriptionPlan = null;
        }
      } else {
        print('📌 Aucun abonnement actif');
        _currentSubscriptionPlan = 'gratuit';
      }

      setState(() {});

    } catch (e) {
      print('❌ Erreur chargement abonnement actuel: $e');
    }
  }

// lib/pages/dating/dating_subscription_page.dart

// =====================================================
// 1. FONCTION DE SOUSCRIPTION (AVEC CRÉATION DE L'ABONNEMENT)
// =====================================================

  Future<void> _subscribe(SubscriptionPlan plan) async {
    if (_isSubscribing) return;

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final userId = authProvider.loginUserData.id;
    final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;

    print('📱 === SOUSCRIPTION À UN ABONNEMENT ===');
    print('📌 Plan: ${plan.name} (${plan.code})');
    print('💰 Coût: ${plan.priceCoins} pièces');
    print('💳 Solde actuel: $currentCoins pièces');
    print('👍 Likes par jour: ${plan.defaultLikes == -1 ? 'Illimités' : plan.defaultLikes}');
    print('⭐ Super likes par jour: ${plan.defaultSuperLikes}');
    print('📅 Durée: ${plan.durationInDays} jours');

    // Vérifier si l'utilisateur est déjà abonné à ce plan
    if (_currentSubscriptionPlan == plan.code && plan.code != 'gratuit') {
      print('⚠️ Utilisateur déjà abonné à ${plan.name}');
      _showSnackBar('Vous êtes déjà abonné à ce plan !', Colors.orange);
      return;
    }

    // Vérifier le solde pour les plans payants
    if (plan.priceCoins > 0 && currentCoins < plan.priceCoins) {
      print('❌ Solde insuffisant: $currentCoins < ${plan.priceCoins}');
      _showInsufficientCoinsDialog(plan);
      return;
    }

    // Dialogue de confirmation
    final confirm = await _showConfirmationDialog(plan);
    if (confirm != true) {
      print('❌ Abonnement annulé par l\'utilisateur');
      return;
    }

    setState(() => _isSubscribing = true);

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final startAt = now;
      final endAt = now + (plan.durationInDays * 24 * 60 * 60 * 1000);

      print('🔄 Exécution de la transaction Firestore...');

      await firestore.runTransaction((transaction) async {
        // 1. Déduire les pièces si plan payant
        if (plan.priceCoins > 0) {
          final userRef = firestore.collection('Users').doc(userId);
          final userDoc = await transaction.get(userRef);
          final currentBalance = userDoc.data()?['coinsBalance'] ?? 0;

          if (currentBalance < plan.priceCoins) {
            throw Exception('Solde insuffisant');
          }

          transaction.update(userRef, {
            'coinsBalance': currentBalance - plan.priceCoins,
            'totalCoinsSpent': FieldValue.increment(plan.priceCoins),
          });
          print('💰 ${plan.priceCoins} pièces déduites du solde');
        }

        // 2. Désactiver les anciens abonnements
        final oldSubscriptions = await firestore
            .collection('user_dating_subscriptions')
            .where('userId', isEqualTo: userId)
            .where('isActive', isEqualTo: true)
            .get();

        for (var doc in oldSubscriptions.docs) {
          transaction.update(doc.reference, {'isActive': false});
          print('📌 Ancien abonnement désactivé: ${doc.id}');
        }

        // 3. Créer le nouvel abonnement AVEC les likes restants
        final subscriptionId = firestore.collection('user_dating_subscriptions').doc().id;
        final subscription = UserDatingSubscription(
          id: subscriptionId,
          userId: userId!,
          planCode: plan.code,
          priceCoins: plan.priceCoins,
          startAt: startAt,
          endAt: endAt,
          isActive: true,
          createdAt: now,
          updatedAt: now,
          remainingLikes: plan.defaultLikes,
          remainingSuperLikes: plan.defaultSuperLikes,
        );

        transaction.set(
          firestore.collection('user_dating_subscriptions').doc(subscriptionId),
          subscription.toJson(),
        );
        print('✅ Nouvel abonnement créé: ${plan.name}');
        print('   📊 Likes restants: ${plan.defaultLikes == -1 ? 'Illimités' : plan.defaultLikes}');
        print('   📊 Super likes restants: ${plan.defaultSuperLikes}');

        // 4. Enregistrer la transaction de pièces
        final transactionId = firestore.collection('user_coin_transactions').doc().id;
        transaction.set(
          firestore.collection('user_coin_transactions').doc(transactionId),
          {
            'id': transactionId,
            'userId': userId,
            'type': 'spend_subscription',
            'coinsAmount': -plan.priceCoins,
            'xofAmount': plan.priceCoins * 2.5,
            'referenceId': subscriptionId,
            'description': 'Abonnement ${plan.name}',
            'status': 'success',
            'createdAt': now,
            'updatedAt': now,
          },
        );
        print('💰 Transaction de pièces enregistrée');
      });

      print('✅ === ABONNEMENT SOUSCRIT AVEC SUCCÈS ===');

      // Mettre à jour les données locales
      _currentSubscriptionPlan = plan.code;

      // Mettre à jour les limites dans SharedPreferences
      await _updateLocalLimits(plan);

      // Mettre à jour les limites dans le provider
      await _updateProviderLimits(plan);

      if (mounted) {
        _showSuccessSnackBar(plan);
        await authProvider.refreshUserData();
        Navigator.pop(context);
      }

    } catch (e) {
      print('❌ ERREUR lors de la souscription: $e');
      if (mounted) {
        _showSnackBar('Erreur: ${e.toString()}', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubscribing = false);
      }
    }
  }

// =====================================================
// 2. FONCTION DE MISE À JOUR DES LIMITES LOCALES
// =====================================================

  /// Met à jour les limites de likes dans SharedPreferences
  /// Ces valeurs sont utilisées pour l'affichage immédiat dans l'app
  Future<void> _updateLocalLimits(SubscriptionPlan plan) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final userId = authProvider.loginUserData.id;

    if (userId == null) {
      print('⚠️ Impossible de mettre à jour les limites: userId null');
      return;
    }

    // Utiliser les valeurs du plan
    final likesLimit = plan.defaultLikes;
    final superLikesLimit = plan.defaultSuperLikes;

    await prefs.setInt('dating_remaining_likes_$userId', likesLimit);
    await prefs.setInt('dating_remaining_super_likes_$userId', superLikesLimit);

    print('📊 Mise à jour SharedPreferences:');
    print('   👍 Likes: ${likesLimit == -1 ? 'Illimités' : likesLimit}');
    print('   ⭐ Super likes: $superLikesLimit');
  }

// =====================================================
// 3. FONCTION DE MISE À JOUR DES LIMITES DANS LE PROVIDER
// =====================================================

  /// Met à jour les limites dans le DatingProvider (si utilisé)
  Future<void> _updateProviderLimits(SubscriptionPlan plan) async {
    try {
      final datingProvider = Provider.of<DatingProvider>(context, listen: false);
      // Si votre DatingProvider a une méthode pour mettre à jour les limites
      // datingProvider.updateLimits(plan.defaultLikes, plan.defaultSuperLikes);

      print('📊 Mise à jour du DatingProvider effectuée');
    } catch (e) {
      print('⚠️ Impossible de mettre à jour le DatingProvider: $e');
      // Ce n'est pas critique, on continue
    }
  }

// =====================================================
// 4. FONCTIONS UTILITAIRES
// =====================================================

  Future<bool?> _showConfirmationDialog(SubscriptionPlan plan) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              plan.code == 'gold' ? Icons.diamond :
              (plan.code == 'plus' ? Icons.star : Icons.favorite),
              color: plan.code == 'gold' ? Colors.amber : Colors.red,
            ),
            SizedBox(width: 8),
            Text('Confirmer l\'abonnement'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),
            Text(
              'Souscrire à ${plan.name} ?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            if (plan.priceCoins > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${plan.priceCoins} pièces',
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            SizedBox(height: 12),
            Text(
              'Durée: ${plan.durationInDays} jours',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildLimitRow(
                    'Likes par jour',
                    plan.defaultLikes == -1 ? 'Illimités' : '${plan.defaultLikes}',
                    Icons.favorite,
                  ),
                  SizedBox(height: 8),
                  _buildLimitRow(
                    'Super likes par jour',
                    '${plan.defaultSuperLikes}',
                    Icons.star,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitRow(String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.amber),
            SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showSuccessSnackBar(SubscriptionPlan plan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Abonnement ${plan.name} activé !',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showInsufficientCoinsDialog(SubscriptionPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Solde insuffisant', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on, size: 50, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Vous n\'avez pas assez de pièces pour souscrire à ${plan.name}.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '${plan.priceCoins} pièces requis',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Achetez des pièces pour profiter des fonctionnalités premium !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => BuyCoinsPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
            ),
            child: Text('Acheter des pièces'),
          ),
        ],
      ),
    );
  }

  Color _getPlanColor(String planCode) {
    switch (planCode) {
      case 'gold':
        return Colors.amber;
      case 'plus':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getPlanIcon(String planCode) {
    switch (planCode) {
      case 'gold':
        return Icons.diamond;
      case 'plus':
        return Icons.star;
      default:
        return Icons.favorite;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context);
    final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'AfroLove Premium',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement des offres...'),
          ],
        ),
      )
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red),
            SizedBox(height: 16),
            Text('Erreur: $_error'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _checkAndCreatePlans();
              },
              child: Text('Réessayer'),
            ),
          ],
        ),
      )
          : _plans.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 60, color: Colors.orange),
            SizedBox(height: 16),
            Text('Aucun plan disponible'),
            SizedBox(height: 8),
            Text('Veuillez réessayer plus tard'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _checkAndCreatePlans();
              },
              child: Text('Réessayer'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Header avec solde
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade600, Colors.red.shade400],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Votre solde',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                    SizedBox(width: 8),
                    Text(
                      '$currentCoins',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' pièces',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
                if (_currentSubscriptionPlan != null && _currentSubscriptionPlan != 'gratuit')
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getPlanIcon(_currentSubscriptionPlan!), size: 16, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'Abonnement ${_currentSubscriptionPlan == 'gold' ? 'Gold' : 'Plus'} actif',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Liste des plans
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _plans.length,
              itemBuilder: (context, index) {
                final plan = _plans[index];
                final isCurrentPlan = _currentSubscriptionPlan == plan.code;
                final isFree = plan.code == 'gratuit';

                return Container(
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: isCurrentPlan
                        ? LinearGradient(
                      colors: [Colors.red.shade50, Colors.pink.shade50],
                    )
                        : null,
                    border: Border.all(
                      color: isCurrentPlan ? Colors.red.shade300 : Colors.grey.shade200,
                      width: isCurrentPlan ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // En-tête du plan
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _getPlanColor(plan.code).withOpacity(0.1),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getPlanColor(plan.code),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getPlanIcon(plan.code),
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.name,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: _getPlanColor(plan.code),
                                    ),
                                  ),
                                  Text(
                                    plan.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isFree)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.monetization_on, size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      '${plan.priceCoins} coins',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Bénéfices
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ce que vous obtenez :',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 12),
                            ...plan.features.map((feature) => Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                            if (plan.durationInDays > 0)
                              Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                    SizedBox(width: 8),
                                    Text(
                                      'Durée: ${plan.durationInDays} jours',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Bouton d'action
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: SizedBox(
                          width: double.infinity,
                          child: isCurrentPlan
                              ? OutlinedButton(
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.green),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              'Abonnement actif',
                              style: TextStyle(color: Colors.green),
                            ),
                          )
                              : ElevatedButton(
                            onPressed: _isSubscribing
                                ? null
                                : () => _subscribe(plan),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPlanColor(plan.code),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
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
                              isFree
                                  ? 'Rester gratuit'
                                  : 'S\'abonner - ${plan.priceCoins} pièces',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Footer avec mentions
          Container(
            padding: EdgeInsets.all(16),
            child: Text(
              'Abonnement automatiquement renouvelable. '
                  'Vous pouvez annuler à tout moment dans les paramètres.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}