// lib/pages/dating/dating_subscription_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../providers/authProvider.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import 'buy_coins_page.dart';

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
  String? _currentSubscriptionDocId;
  bool _incognitoMode = false;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  /// Catalogue des plans d'abonnement, défini localement (et non plus dans
  /// Firestore) pour éviter les doublons/anciens tarifs et garder le contrôle
  /// total de la grille tarifaire dans le code de l'application.
  List<SubscriptionPlan> _buildLocalPlans() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      SubscriptionPlan(
        id: 'gratuit',
        code: 'gratuit',
        name: 'Gratuit',
        description: 'Fonctionnalités de base',
        priceCoins: 0,
        durationInDays: 0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        defaultLikes: 5,
        defaultSuperLikes: 1,
        defaultSwipes: 15,
        features: const [
          '5 likes par jour',
          '1 super like par jour',
          '15 profils à découvrir par jour',
          'Profils recommandés',
          'Recharge de quota avec des pièces',
        ],
      ),
      SubscriptionPlan(
        id: 'plus',
        code: 'plus',
        name: 'AfroLove Plus',
        description: 'Profitez de plus de fonctionnalités',
        priceCoins: 1499,
        durationInDays: 30,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        defaultLikes: 20,
        defaultSuperLikes: 5,
        defaultSwipes: 50,
        features: const [
          '20 likes par jour',
          '5 super likes par jour',
          '50 profils à découvrir par jour',
          'Annuler le dernier swipe (rewind)',
          'Badge exclusif',
          'Recharge de quota avec des pièces',
        ],
      ),
      SubscriptionPlan(
        id: 'gold',
        code: 'gold',
        name: 'AfroLove Gold',
        description: "L'expérience ultime",
        priceCoins: 3999,
        durationInDays: 30,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        defaultLikes: 50,
        defaultSuperLikes: 20,
        defaultSwipes: -1,
        features: const [
          'Profils à découvrir illimités',
          '50 likes par jour',
          '20 super likes par jour',
          'Voir qui vous a liké',
          'Annuler le dernier swipe (rewind)',
          'Message direct sans match (1/jour)',
          'Filtre "profils vérifiés"',
          'Statistiques de profil',
          'Boost quotidien gratuit',
          'Mode incognito (parcourir sans être vu)',
          'Recharge de quota à -50%',
          'Badge Gold exclusif',
        ],
      ),
    ];
  }

  Future<void> _loadPlans() async {
    print('📱 === Chargement des plans d\'abonnement dating (local) ===');
    _plans = _buildLocalPlans()..sort((a, b) => a.priceCoins.compareTo(b.priceCoins));
    for (var plan in _plans) {
      print('   📌 ${plan.name} - ${plan.priceCoins} coins');
    }
    setState(() => _isLoading = false);

    // Charger l'abonnement actuel après avoir les plans
    await _loadCurrentSubscription();
  }

  /// Active/désactive le mode incognito (avantage Gold) : tant qu'il est
  /// actif, les visites de profils de l'utilisateur ne sont pas enregistrées
  /// (cf. `dating_profile_detail_page.dart` -> `_recordVisit`).
  Future<void> _toggleIncognitoMode(bool value) async {
    if (_currentSubscriptionDocId == null) return;
    setState(() => _incognitoMode = value);
    try {
      await firestore
          .collection('user_dating_subscriptions')
          .doc(_currentSubscriptionDocId)
          .update({'incognitoMode': value});
    } catch (e) {
      print('❌ Erreur mise à jour mode incognito: $e');
      setState(() => _incognitoMode = !value);
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
        _currentSubscriptionDocId = snapshot.docs.first.id;
        _incognitoMode = snapshot.docs.first.data()['incognitoMode'] ?? false;
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
    if (_currentSubscriptionPlan == plan.code) {
      print('⚠️ Utilisateur déjà abonné à ${plan.name}');
      _showSnackBar(AppLocalizations.of(context).datingAlreadySubscribedToPlan, Colors.orange);
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

      // Récupérer les anciens abonnements actifs AVANT la transaction : une requête
      // (where + get) ne fait pas partie du contrat de lecture/écriture d'une
      // transaction Firestore et provoquait des incohérences (docs non désactivés
      // de façon fiable, doublons d'abonnements actifs détectés en production).
      final oldSubscriptions = await firestore
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

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

        // 2. Désactiver les anciens abonnements (lus via transaction.get pour
        // respecter les règles de cohérence des transactions Firestore)
        for (var doc in oldSubscriptions.docs) {
          await transaction.get(doc.reference);
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
          remainingSwipes: plan.defaultSwipes,
          lastResetDate: now,
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

      if (mounted) {
        _showSuccessSnackBar(plan);
        await authProvider.refreshUserData();
        // Revenir sur la page swipe (racine du module Dating) afin que
        // _loadUserSubscription() s'y exécute automatiquement au retour
        // (via didChangeDependencies/_refreshData) et prenne en compte le nouveau plan.
        Navigator.of(context).popUntil((route) => route.isFirst);
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
// 2. FONCTIONS UTILITAIRES
// =====================================================

  Future<bool?> _showConfirmationDialog(SubscriptionPlan plan) async {
    final t = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              plan.code == 'gold' ? Icons.diamond :
              (plan.code == 'plus' ? Icons.star : Icons.favorite),
              color: plan.code == 'gold' ? Colors.amber : Colors.red,
            ),
            SizedBox(width: 8),
            Text(t.datingConfirmSubscriptionTitle, style: TextStyle(color: colors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),
            Text(
              t.datingConfirmSubscribeTo.replaceAll('{plan}', plan.name),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
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
                  t.datingCoinsSuffix.replaceAll('{count}', '${plan.priceCoins}'),
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            SizedBox(height: 12),
            Text(
              t.datingDurationDays.replaceAll('{days}', '${plan.durationInDays}'),
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildLimitRow(
                    t.datingLikesPerDay,
                    plan.defaultLikes == -1 ? t.datingUnlimitedWord : '${plan.defaultLikes}',
                    Icons.favorite,
                    colors,
                  ),
                  SizedBox(height: 8),
                  _buildLimitRow(
                    t.datingSuperLikesPerDay,
                    '${plan.defaultSuperLikes}',
                    Icons.star,
                    colors,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.datingCancelButton, style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(t.datingConfirmButton),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitRow(String label, String value, IconData icon, AppColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.amber),
            SizedBox(width: 8),
            Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.amber.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showSuccessSnackBar(SubscriptionPlan plan) {
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                t.datingSubscriptionActiveBadge.replaceAll('{plan}', plan.name),
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
    final t = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.datingInsufficientBalanceTitle, style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on, size: 50, color: Colors.red),
            SizedBox(height: 16),
            Text(
              t.datingInsufficientBalanceMessage.replaceAll('{plan}', plan.name),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textPrimary),
            ),
            SizedBox(height: 8),
            Text(
              t.datingCoinsRequired.replaceAll('{price}', '${plan.priceCoins}'),
              style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              t.datingBuyCoinsPrompt,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.datingCancelButton, style: TextStyle(color: colors.textSecondary)),
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
            child: Text(t.datingBuyCoinsButton),
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
    final t = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          t.datingSubscriptionPageTitle,
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
            Text(t.datingLoadingOffers, style: TextStyle(color: colors.textPrimary)),
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
            Text('${t.datingErrorPrefix}: $_error', style: TextStyle(color: colors.textPrimary)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _loadPlans();
              },
              child: Text(t.datingRetry),
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
            Text(t.datingNoPlanAvailable, style: TextStyle(color: colors.textPrimary)),
            SizedBox(height: 8),
            Text(t.datingTryAgainLater, style: TextStyle(color: colors.textSecondary)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _loadPlans();
              },
              child: Text(t.datingRetry),
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
                  t.datingBalanceLabel,
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
                    SizedBox(width: 4),
                    Text(
                      t.datingCoinsWord,
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
                          t.datingSubscriptionActiveBadge.replaceAll(
                            '{plan}',
                            _currentSubscriptionPlan == 'gold' ? t.datingPlanGold : t.datingPlanPlus,
                          ),
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if (_currentSubscriptionPlan == 'gold')
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_off, size: 16, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(t.datingIncognitoModeTitle, style: TextStyle(color: Colors.white, fontSize: 13)),
                        Switch(
                          value: _incognitoMode,
                          activeColor: Colors.amber,
                          onChanged: _toggleIncognitoMode,
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
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    gradient: isCurrentPlan
                        ? LinearGradient(
                      colors: [Colors.red.shade50, Colors.pink.shade50],
                    )
                        : null,
                    border: Border.all(
                      color: isCurrentPlan ? Colors.red.shade300 : colors.border,
                      width: isCurrentPlan ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
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
                                      color: colors.textSecondary,
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
                              t.datingWhatYouGet,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: colors.textPrimary,
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
                                      style: TextStyle(fontSize: 13, color: colors.textPrimary),
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
                                    Icon(Icons.calendar_today, size: 14, color: colors.textSecondary),
                                    SizedBox(width: 8),
                                    Text(
                                      t.datingDurationDays.replaceAll('{days}', '${plan.durationInDays}'),
                                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
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
                              t.datingSubscriptionActiveButton,
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
                                  ? t.datingStayFree
                                  : t.datingSubscribeForCoins.replaceAll('{price}', '${plan.priceCoins}'),
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
              t.datingSubscriptionFooterNote,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}