// lib/pages/dating/dating_profile_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import 'creator_content_detail_page.dart';
import 'creator_profile_page.dart';
import 'creator_subscription_page.dart';
import 'dating_chat_page.dart';
import 'dating_likes_list_page.dart';
import 'dating_my_likes_page.dart';
import 'dating_profile_setup_page.dart';
import 'dating_subscription_page.dart';

import 'dating_connections_page.dart';
import 'dating_conversations_page.dart';
import 'dating_likes_list_page.dart';
import 'dating_notifications_page.dart';
import 'dating_super_likes_list_page.dart';


class DatingProfileDetailPage extends StatefulWidget {
  final DatingProfile profile;

  const DatingProfileDetailPage({
    Key? key,
    required this.profile,
  }) : super(key: key);

  @override
  State<DatingProfileDetailPage> createState() => _DatingProfileDetailPageState();
}

class _DatingProfileDetailPageState extends State<DatingProfileDetailPage>
    with SingleTickerProviderStateMixin {
  // États
  bool _isLiked = false;
  bool _isCoupDeCoeur = false;
  bool _isBlocked = false;
  UserData? _userData;
  bool _isLoading = true;
  bool _isSubscribed = false;
  bool _isCheckingSubscription = true;
  int _visitorsCount = 0;
  String? _currentSubscriptionPlan;
  int _remainingLikes = 0;
  int _remainingSuperLikes = 0;
  bool _isCreator = false;
  bool _isCheckingCreator = true;
  int _unreadNotificationsCount = 0;

  // Animation
  late TabController _tabController;
  int _currentImageIndex = 0;
  final List<Tab> _tabs = const [
    Tab(text: 'Profil'),
    Tab(text: 'Posts'),
  ];

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Couleurs
  final Color primaryRed = const Color(0xFFE63946);
  final Color primaryYellow = const Color(0xFFFFD700);
  final Color primaryBlack = Colors.black;
  final Color secondaryGrey = const Color(0xFF2C2C2C);
  final Color lightGrey = const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadUserData();
    _loadSubscriptionStatus();
    _checkLikeStatus();
    _checkCoupDeCoeurStatus();
    _checkIfUserIsCreator();
    _recordVisit();
    _loadVisitorsCount();
    _loadUnreadNotificationsCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await firestore
          .collection('Users')
          .doc(widget.profile.userId)
          .get();

      if (doc.exists) {
        setState(() {
          _userData = UserData.fromJson(doc.data()!);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Erreur chargement user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUnreadNotificationsCount() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) {
      print('⚠️ _loadUnreadNotificationsCount: currentUserId is null');
      return;
    }

    final datingTypes = [
      'DATING_LIKE',
      'DATING_MATCH',
      'DATING_SUPER_LIKE',
      'DATING_MESSAGE',
      // Ajoutez ici tous les types dating que vous utilisez
    ];

    print('🔔 Chargement compteur notifications non lues pour $currentUserId');
    print('📋 Types recherchés: $datingTypes');

    try {
      final snapshot = await firestore
          .collection('Notifications')
          .where('receiver_id', isEqualTo: currentUserId)
          .where('type', whereIn: datingTypes)
          .where('is_open', isEqualTo: false)
          .get();

      print('📊 ${snapshot.docs.length} notifications non lues trouvées');
      for (var doc in snapshot.docs) {
        print('   - ${doc.id} | type: ${doc['type']}');
      }

      setState(() {
        _unreadNotificationsCount = snapshot.docs.length;
      });
    } catch (e) {
      print('❌ Erreur chargement compteur notifications: $e');
    }
  }
  Future<void> _checkIfUserIsCreator() async {
    try {
      final snapshot = await firestore
          .collection('creator_profiles')
          .where('userId', isEqualTo: widget.profile.userId)
          .where('isCreatorActive', isEqualTo: true)
          .limit(1)
          .get();

      setState(() {
        _isCreator = snapshot.docs.isNotEmpty;
        _isCheckingCreator = false;
      });
    } catch (e) {
      print('❌ Erreur vérification créateur: $e');
      setState(() => _isCheckingCreator = false);
    }
  }

  Future<void> _loadSubscriptionStatus() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null) {
      setState(() => _isCheckingSubscription = false);
      return;
    }

    try {
      final subSnapshot = await firestore
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (subSnapshot.docs.isNotEmpty) {
        final subscription = subSnapshot.docs.first;
        _currentSubscriptionPlan = subscription['planCode'];
        final now = DateTime.now().millisecondsSinceEpoch;
        final endAt = subscription['endAt'] as int;

        if (endAt > now) {
          _remainingLikes = subscription['remainingLikes'] ?? _getDefaultLikes(_currentSubscriptionPlan!);
          _remainingSuperLikes = subscription['remainingSuperLikes'] ?? _getDefaultSuperLikes(_currentSubscriptionPlan!);
          print('📌 Abonnement actif: $_currentSubscriptionPlan');
        } else {
          _currentSubscriptionPlan = null;
          _remainingLikes = _getDefaultLikes('gratuit');
          _remainingSuperLikes = _getDefaultSuperLikes('gratuit');
        }
      } else {
        _currentSubscriptionPlan = null;
        _remainingLikes = _getDefaultLikes('gratuit');
        _remainingSuperLikes = _getDefaultSuperLikes('gratuit');
      }

      // Vérifier l'abonnement créateur
      final creatorSnapshot = await firestore
          .collection('creator_subscriptions')
          .where('userId', isEqualTo: currentUserId)
          .where('creatorId', isEqualTo: widget.profile.userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      setState(() {
        _isSubscribed = creatorSnapshot.docs.isNotEmpty;
        _isCheckingSubscription = false;
      });
    } catch (e) {
      print('❌ Erreur chargement abonnement: $e');
      _remainingLikes = 5;
      _remainingSuperLikes = 1;
      setState(() => _isCheckingSubscription = false);
    }
  }

  int _getDefaultLikes(String plan) {
    switch (plan) {
      case 'gold':
        return -1;
      case 'plus':
        return 50;
      default:
        return 5;
    }
  }

  int _getDefaultSuperLikes(String plan) {
    switch (plan) {
      case 'gold':
        return 5;
      case 'plus':
        return 2;
      default:
        return 1;
    }
  }

  Future<void> _updateRemainingLikes() async {
    if (_currentSubscriptionPlan == null) return;

    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final currentUserId = authProvider.loginUserData.id;

      final snapshot = await firestore
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'remainingLikes': _remainingLikes,
          'remainingSuperLikes': _remainingSuperLikes,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      print('❌ Erreur mise à jour likes: $e');
    }
  }

  Future<void> _updatePopularityScore(String userId) async {
    try {
      final likesCount = await firestore
          .collection('dating_likes')
          .where('toUserId', isEqualTo: userId)
          .count()
          .get();
      final coupsCount = await firestore
          .collection('dating_coup_de_coeurs')
          .where('toUserId', isEqualTo: userId)
          .count()
          .get();
      final connectionsCount = await firestore
          .collection('dating_connections')
          .where('userId1', isEqualTo: userId)
          .count()
          .get();
      final score = (likesCount.count! * 1) + (coupsCount.count! * 2) + (connectionsCount.count! * 3);
      final profileSnapshot = await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (profileSnapshot.docs.isNotEmpty) {
        await profileSnapshot.docs.first.reference.update({
          'popularityScore': score,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      print('❌ Erreur mise à jour score: $e');
    }
  }

  Future<void> _addPointsToUser(String userId, int points, String reason) async {
    await firestore.collection('Users').doc(userId).update({
      'totalPoints': FieldValue.increment(points),
    });
  }

  Future<void> _recordVisit() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || currentUserId == widget.profile.userId) return;

    try {
      final today = DateTime.now().millisecondsSinceEpoch;
      final dayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).millisecondsSinceEpoch;

      final existingVisit = await firestore
          .collection('dating_profile_visits')
          .where('visitorUserId', isEqualTo: currentUserId)
          .where('visitedUserId', isEqualTo: widget.profile.userId)
          .where('createdAt', isGreaterThanOrEqualTo: dayStart)
          .limit(1)
          .get();

      if (existingVisit.docs.isNotEmpty) return;

      await firestore.collection('dating_profile_visits').doc().set({
        'id': firestore.collection('dating_profile_visits').doc().id,
        'visitorUserId': currentUserId,
        'visitedUserId': widget.profile.userId,
        'createdAt': today,
      });

      await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: widget.profile.userId)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update({
            'visitorsCount': FieldValue.increment(1),
          });
        }
      });
    } catch (e) {
      print('❌ Erreur enregistrement visite: $e');
    }
  }

  Future<void> _loadVisitorsCount() async {
    try {
      final snapshot = await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: widget.profile.userId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _visitorsCount = snapshot.docs.first.data()['visitorsCount'] ?? 0;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement visiteurs: $e');
    }
  }

  Future<void> _checkLikeStatus() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    try {
      final snapshot = await firestore
          .collection('dating_likes')
          .where('fromUserId', isEqualTo: currentUserId)
          .where('toUserId', isEqualTo: widget.profile.userId)
          .limit(1)
          .get();
      setState(() => _isLiked = snapshot.docs.isNotEmpty);
    } catch (e) {
      print('❌ Erreur vérification like: $e');
    }
  }

  Future<void> _checkCoupDeCoeurStatus() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    try {
      final snapshot = await firestore
          .collection('dating_coup_de_coeurs')
          .where('fromUserId', isEqualTo: currentUserId)
          .where('toUserId', isEqualTo: widget.profile.userId)
          .limit(1)
          .get();
      setState(() => _isCoupDeCoeur = snapshot.docs.isNotEmpty);
    } catch (e) {
      print('❌ Erreur vérification coup de cœur: $e');
    }
  }

  Future<void> _handleLike() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    // Vérifier les likes restants
    if (_remainingLikes <= 0 && _currentSubscriptionPlan == null) {
      _showUpgradeDialog('likes');
      return;
    }

    // Vérifier la compatibilité des genres
    final isCompatible = await _checkMatchCompatibility();
    if (!isCompatible) return;

    // Vérifier si un match existe déjà
    final alreadyMatched = await _matchAlreadyExists();
    if (alreadyMatched) {
      _showSnackBar('Vous êtes déjà en contact avec ${widget.profile.pseudo}', Colors.orange);
      return;
    }

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await firestore.collection('dating_likes').doc().set({
        'id': firestore.collection('dating_likes').doc().id,
        'fromUserId': currentUserId,
        'toUserId': widget.profile.userId,
        'createdAt': now,
      });

      setState(() {
        _isLiked = true;
        if (_remainingLikes > 0) _remainingLikes--;
      });
      await _updateRemainingLikes();

      await _sendNotification(
        toUserId: widget.profile.userId,
        message: "❤️ @${widget.profile.pseudo} vous a liké !",
        type: 'like',
      );

      await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: widget.profile.userId)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update({'likesCount': FieldValue.increment(1)});
        }
      });

      await _updatePopularityScore(widget.profile.userId);
      await _addPointsToUser(currentUserId, 5, 'Like envoyé');

      _showSnackBar('❤️ Vous avez liké ${widget.profile.pseudo} (+5 points)', Colors.green);

      // Vérifier s'il y a un like mutuel (match)
      final mutualLike = await firestore
          .collection('dating_likes')
          .where('fromUserId', isEqualTo: widget.profile.userId)
          .where('toUserId', isEqualTo: currentUserId)
          .limit(1)
          .get();

      if (mutualLike.docs.isNotEmpty) {
        _showMatchDialog();
      }
    } catch (e) {
      print('❌ Erreur like: $e');
    }
  }
  Future<DatingProfile?> _getCurrentUserDatingProfile() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return null;
    final snapshot = await firestore
        .collection('dating_profiles')
        .where('userId', isEqualTo: currentUserId)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return DatingProfile.fromJson(snapshot.docs.first.data());
    }
    return null;
  }

  Future<bool> _checkMatchCompatibility() async {
    final currentProfile = await _getCurrentUserDatingProfile();
    if (currentProfile == null) return false;

    // Vérifier que le sexe du profil cible correspond à ce que recherche l'utilisateur courant
    bool currentAcceptsTarget = currentProfile.rechercheSexe == 'tous' ||
        currentProfile.rechercheSexe == widget.profile.sexe;

    // Vérifier que le sexe de l'utilisateur courant correspond à ce que recherche le profil cible
    bool targetAcceptsCurrent = widget.profile.rechercheSexe == 'tous' ||
        widget.profile.rechercheSexe == currentProfile.sexe;

    if (!currentAcceptsTarget) {
      _showSnackBar('Vous ne recherchez pas ce genre de personnes.', Colors.orange);
      return false;
    }
    if (!targetAcceptsCurrent) {
      _showSnackBar('Cette personne ne recherche pas votre genre.', Colors.orange);
      return false;
    }
    return true;
  }

  Future<bool> _matchAlreadyExists() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return false;

    final snapshot = await firestore
        .collection('dating_connections')
        .where('userId1', isEqualTo: currentUserId)
        .where('userId2', isEqualTo: widget.profile.userId)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) return true;

    final snapshot2 = await firestore
        .collection('dating_connections')
        .where('userId1', isEqualTo: widget.profile.userId)
        .where('userId2', isEqualTo: currentUserId)
        .limit(1)
        .get();
    return snapshot2.docs.isNotEmpty;
  }
  Future<void> _handleCoupDeCoeur() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    // Vérifier la compatibilité des genres
    final isCompatible = await _checkMatchCompatibility();
    if (!isCompatible) return;

    // Vérifier si un match existe déjà
    final alreadyMatched = await _matchAlreadyExists();
    if (alreadyMatched) {
      _showSnackBar('Vous êtes déjà en contact avec ${widget.profile.pseudo}', Colors.orange);
      return;
    }

    const superLikePriceCoins = 20;

    // Si l'utilisateur a encore des super likes gratuits
    if (_remainingSuperLikes > 0) {
      // Envoyer gratuitement
      await _sendCoupDeCoeur(currentUserId, authProvider, useCoins: false);
      return;
    }

    // Sinon, il n'a plus de super likes gratuits → proposition d'achat avec pièces
    final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;
    if (currentCoins < superLikePriceCoins) {
      _showInsufficientCoinsDialog();
      return;
    }

    // Demander confirmation d'achat
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('✨ Coup de cœur payant ✨'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 50, color: Colors.amber),
            SizedBox(height: 16),
            Text('Vous n\'avez plus de coups de cœur gratuits aujourd\'hui.'),
            SizedBox(height: 8),
            Text(
              'Envoyer un coup de cœur coûte $superLikePriceCoins pièces.',
              style: TextStyle(color: Colors.amber),
            ),
            SizedBox(height: 8),
            Text('Votre solde : $currentCoins pièces', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            child: Text('Acheter et envoyer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Envoyer avec paiement en pièces
    await _sendCoupDeCoeur(currentUserId, authProvider, useCoins: true, priceCoins: superLikePriceCoins);
  }

  /// Méthode auxiliaire pour envoyer le coup de cœur
  Future<void> _sendCoupDeCoeur(String currentUserId, UserAuthProvider authProvider, {required bool useCoins, int priceCoins = 0}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      if (useCoins) {
        // Déduire les pièces
        await firestore.collection('Users').doc(currentUserId).update({
          'coinsBalance': FieldValue.increment(-priceCoins),
          'totalCoinsSpent': FieldValue.increment(priceCoins),
        });
        // Ne pas modifier _remainingSuperLikes car c'est un achat exceptionnel
      } else {
        // Utiliser un super like gratuit
        setState(() {
          _remainingSuperLikes--;
        });
        await _updateRemainingLikes();
      }

      // Créer le document dans dating_coup_de_coeurs
      await firestore.collection('dating_coup_de_coeurs').doc().set({
        'id': firestore.collection('dating_coup_de_coeurs').doc().id,
        'fromUserId': currentUserId,
        'toUserId': widget.profile.userId,
        'createdAt': now,
      });

      setState(() {
        _isCoupDeCoeur = true;
      });

      // Notification
      await _sendNotification(
        toUserId: widget.profile.userId,
        message: "⭐ @${widget.profile.pseudo} vous a envoyé un Coup de cœur ❤️ !",
        type: 'super_like',
      );

      // Mettre à jour le compteur de coups de cœur du profil cible
      await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: widget.profile.userId)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update({'coupsDeCoeurCount': FieldValue.increment(1)});
        }
      });

      // Mettre à jour le score de popularité
      await _updatePopularityScore(widget.profile.userId);

      // Ajouter des points à l'utilisateur
      await _addPointsToUser(currentUserId, 20, 'Coup de cœur envoyé');

      _showSnackBar('✨ Coup de cœur envoyé à ${widget.profile.pseudo} (+20 points)', Colors.amber);

      // Vérifier si un like mutuel (match) existe déjà
      final mutualLike = await firestore
          .collection('dating_likes')
          .where('fromUserId', isEqualTo: widget.profile.userId)
          .where('toUserId', isEqualTo: currentUserId)
          .limit(1)
          .get();

      if (mutualLike.docs.isNotEmpty) {
        _showMatchDialog();
      }
    } catch (e) {
      print('❌ Erreur envoi coup de cœur: $e');
      _showSnackBar('Erreur lors de l\'envoi', Colors.red);
    }
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
  Future<void> _sendNotification({
    required String toUserId,
    required String message,
    required String type,
  })
  async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final now = DateTime.now().microsecondsSinceEpoch;

    final notificationId = firestore.collection('Notifications').doc().id;
    await firestore.collection('Notifications').doc(notificationId).set({
      'id': notificationId,
      'titre': type == 'match' ? 'Nouveau match ! 🎉' : type == 'super_like' ? 'Coup de cœur ❤️ ! ⭐' : 'Nouveau like ❤️',
      'media_url': widget.profile.imageUrl,
      'type': 'DATING_${type.toUpperCase()}',
      'description': 'Afrolove❤️: '+message,
      'users_id_view': [],
      'user_id': authProvider.loginUserData.id,
      'receiver_id': toUserId,
      'createdAt': now,
      'is_open': false,
      'updatedAt': now,
      'status': 'VALIDE',
    });

    final toUserDoc = await firestore.collection('Users').doc(toUserId).get();
    final toUser = UserData.fromJson(toUserDoc.data() ?? {});

    if (toUser.oneIgnalUserid != null && toUser.oneIgnalUserid!.isNotEmpty) {
      await authProvider.sendNotification(
        userIds: [toUser.oneIgnalUserid!],
        smallImage: widget.profile.imageUrl ?? '',
        send_user_id: authProvider.loginUserData.id!,
        recever_user_id: toUserId,
        message: message,
        type_notif: 'DATING_${type.toUpperCase()}',
        post_id: '',
        post_type: '',
        chat_id: '',
      );
    }
  }

  void _showMatchDialog() {
    final isGold = _currentSubscriptionPlan == 'gold';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.red.shade400, Colors.pink.shade400]),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.favorite, size: 60, color: Colors.white),
              ),
              SizedBox(height: 20),
              Text(
                'C\'est un match ! 🎉',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red.shade700),
              ),
              SizedBox(height: 8),
              Text(
                'Vous et ${widget.profile.pseudo} vous êtes likés mutuellement.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Continuer'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (isGold) {
                          _openChat();
                        } else {
                          _showGoldRequiredDialog();
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text('Discuter en privé'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGoldRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('💬 Discuter en privé', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.diamond, size: 50, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'La messagerie privée est réservée aux membres AfroLove Gold.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Passez à l\'abonnement Gold pour discuter avec vos matchs !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Plus tard')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => DatingSubscriptionPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: Text('Voir les offres'),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    final connection = await _getOrCreateConnection();
    if (connection != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DatingChatPage(
            connectionId: connection.id,
            otherUserId: widget.profile.userId,
            otherUserName: widget.profile.pseudo,
            otherUserImage: widget.profile.imageUrl,
          ),
        ),
      );
    }
  }

  Future<DatingConnection?> _getOrCreateConnection() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return null;

    try {
      final snapshot = await firestore
          .collection('dating_connections')
          .where('userId1', isEqualTo: currentUserId)
          .where('userId2', isEqualTo: widget.profile.userId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return DatingConnection.fromJson(snapshot.docs.first.data());

      final snapshot2 = await firestore
          .collection('dating_connections')
          .where('userId1', isEqualTo: widget.profile.userId)
          .where('userId2', isEqualTo: currentUserId)
          .limit(1)
          .get();
      if (snapshot2.docs.isNotEmpty) return DatingConnection.fromJson(snapshot2.docs.first.data());

      final now = DateTime.now().millisecondsSinceEpoch;
      final connectionId = firestore.collection('dating_connections').doc().id;
      final connection = DatingConnection(
        id: connectionId,
        userId1: currentUserId,
        userId2: widget.profile.userId,
        createdAt: now,
        isActive: true,
      );
      await firestore.collection('dating_connections').doc(connectionId).set(connection.toJson());

      final conversationId = firestore.collection('dating_conversations').doc().id;
      await firestore.collection('dating_conversations').doc(conversationId).set({
        'id': conversationId,
        'connectionId': connectionId,
        'userId1': currentUserId,
        'userId2': widget.profile.userId,
        'unreadCountUser1': 0,
        'unreadCountUser2': 0,
        'createdAt': now,
        'updatedAt': now,
      });
      return connection;
    } catch (e) {
      print('❌ Erreur création connexion: $e');
      return null;
    }
  }

  void _showUpgradeDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Limite de $feature atteinte', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 50, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'Vous avez atteint votre limite de $feature gratuits.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Passez à AfroLove Plus ou Gold pour des fonctionnalités illimitées !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Plus tard')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => DatingSubscriptionPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: Text('Voir les offres'),
          ),
        ],
      ),
    );
  }

  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Solde insuffisant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on, size: 50, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Vous n\'avez pas assez de pièces pour envoyer un Coup de cœur ❤️.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text('20 pièces requis', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/coins/buy');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: Text('Acheter des pièces'),
          ),
        ],
      ),
    );
  }

  // Navigation
  void _navigateToMyConversations() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DatingConversationsPage()));
  }

  void _navigateToMyMatches() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DatingConnectionsPage()));
  }

  void _navigateToMyLikes() {
    final isPlusOrGold = _currentSubscriptionPlan == 'plus' || _currentSubscriptionPlan == 'gold';
    if (!isPlusOrGold) {
      _showUpgradeDialog('likes'); // Upgrade vers Plus ou Gold
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => DatingLikesListPage()));
  }

  void _navigateToMySuperLikes() {
    final isPlusOrGold = _currentSubscriptionPlan == 'plus' || _currentSubscriptionPlan == 'gold';
    if (!isPlusOrGold) {
      _showUpgradeDialog('Coup de cœur ❤️');
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => DatingSuperLikesPage()));
  }

  void _navigateToMyNotifications() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DatingNotificationsPage()));
  }

  void _goToEditProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DatingProfileSetupPage(profile: widget.profile)));
  }

  void _goToCreatorProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreatorProfilePage(userId: widget.profile.userId)));
  }

  Future<void> _subscribeToCreator() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorSubscriptionPage(
          creatorId: widget.profile.userId,
          creatorName: widget.profile.pseudo,
        ),
      ),
    );
  }

  Future<void> _handleReport() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Signaler ${widget.profile.pseudo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pourquoi signalez-vous ce profil ?'),
            SizedBox(height: 16),
            ...['Comportement inapproprié', 'Faux profil', 'Spam', 'Contenu offensant', 'Autre']
                .map((r) => ListTile(leading: Icon(Icons.flag, size: 20), title: Text(r), onTap: () => Navigator.pop(context, r))),
          ],
        ),
      ),
    );
    if (reason == null) return;

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    await firestore.collection('dating_reports').doc().set({
      'id': firestore.collection('dating_reports').doc().id,
      'reporterUserId': currentUserId,
      'targetUserId': widget.profile.userId,
      'reason': reason,
      'description': '',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Signalement envoyé'), backgroundColor: Colors.green));
  }

  Future<void> _handleBlock() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Bloquer ${widget.profile.pseudo}'),
        content: Text(
          'Êtes-vous sûr de vouloir bloquer cet utilisateur ? Vous ne pourrez plus voir son profil ni recevoir ses messages.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text('Bloquer')),
        ],
      ),
    );
    if (confirm != true) return;

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    await firestore.collection('dating_blocks').doc().set({
      'id': firestore.collection('dating_blocks').doc().id,
      'blockerUserId': currentUserId,
      'blockedUserId': widget.profile.userId,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.profile.pseudo} a été bloqué'), backgroundColor: Colors.red));
    Navigator.pop(context);
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildPhotoCarousel() {
    return GestureDetector(
      onTap: () => _showFullScreenImage(widget.profile.photosUrls[_currentImageIndex]),
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.profile.photosUrls.length,
            onPageChanged: (index) => setState(() => _currentImageIndex = index),
            itemBuilder: (context, index) => Image.network(
              widget.profile.photosUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade200, child: Icon(Icons.person, size: 100)),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${_currentImageIndex + 1}/${widget.profile.photosUrls.length}',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: Colors.white)),
          body: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(child: Image.network(imageUrl, fit: BoxFit.contain)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context);
    final currentUserId = authProvider.loginUserData.id;
    final isOwnProfile = currentUserId == widget.profile.userId;
    final isGold = _currentSubscriptionPlan == 'gold';
    final isPlusOrGold = _currentSubscriptionPlan == 'plus' || _currentSubscriptionPlan == 'gold';
    final remainingLikesText = _remainingLikes == -1 ? '∞' : '$_remainingLikes';

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : CustomScrollView(
        slivers: [
          // AppBar avec photo
          SliverAppBar(
            expandedHeight: 450,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildPhotoCarousel(),
              collapseMode: CollapseMode.parallax,
            ),
            actions: [
              if (!isOwnProfile)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'report') _handleReport();
                    if (value == 'block') _handleBlock();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag, size: 20), SizedBox(width: 8), Text('Signaler')])),
                    PopupMenuItem(value: 'block', child: Row(children: [Icon(Icons.block, size: 20), SizedBox(width: 8), Text('Bloquer')])),
                  ],
                ),
            ],
          ),

          // Barre d'actions supérieure (Messages, Matchs, Mes likes, Coup de cœur ❤️s, Notif, Mon profil)
          if (isOwnProfile)
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(child: _buildActionChip(icon: Icons.chat_bubble_outline, label: 'Messages', onTap: _navigateToMyConversations, color: Colors.blue)),
                        Expanded(child: _buildActionChip(icon: Icons.favorite_border, label: 'Matchs', onTap: _navigateToMyMatches, color: Colors.red)),
                        Expanded(child: _buildActionChip(icon: Icons.favorite, label: 'Mes likes', onTap: _navigateToMyLikes, color: isPlusOrGold ? Colors.pink : Colors.grey)),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(child: _buildActionChip(icon: Icons.star, label: 'Coup de cœur ❤️', onTap: _navigateToMySuperLikes, color: isPlusOrGold ? Colors.amber : Colors.grey)),
                        Expanded(child: _buildActionChip(icon: Icons.notifications_none, label: 'Notif', onTap: _navigateToMyNotifications, color: Colors.orange, badgeCount: _unreadNotificationsCount)),
                        Expanded(child: _buildActionChip(icon: Icons.person, label: 'Mon profil', onTap: _goToEditProfile, color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Infos profil
          SliverToBoxAdapter(child: _buildProfileInfo(isOwnProfile, isGold, isPlusOrGold)),

          // Boutons d'action (Like, Super like, Discuter en privé)
          if (!isOwnProfile)
            SliverToBoxAdapter(child: _buildActionButtons(remainingLikesText, isGold)),

          // TabBar
          SliverToBoxAdapter(child: _buildTabBar()),

          // Contenu (Profil / Posts)
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileContent(),
                _buildPostsContent(isOwnProfile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(bool isOwnProfile, bool isGold, bool isPlusOrGold) {
    return Container(
      padding: EdgeInsets.only(top: 30),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${widget.profile.pseudo}, ${widget.profile.age}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                    if (widget.profile.isVerified)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [Icon(Icons.verified, size: 14, color: Colors.blue), SizedBox(width: 4), Text('Vérifié', style: TextStyle(fontSize: 12, color: Colors.blue))]),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                Row(children: [Icon(Icons.location_on, size: 14, color: Colors.grey), SizedBox(width: 4), Text('${widget.profile.ville}, ${widget.profile.pays}', style: TextStyle(fontSize: 13, color: Colors.grey))]),
                if (widget.profile.profession?.isNotEmpty ?? false) ...[
                  SizedBox(height: 4),
                  Row(children: [Icon(Icons.work, size: 14, color: Colors.grey), SizedBox(width: 4), Text(widget.profile.profession!, style: TextStyle(fontSize: 13, color: Colors.grey))]),
                ],
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(Icons.favorite, '${widget.profile.likesCount}', 'Likes', Colors.red),
                    _buildStatItem(Icons.star, '${widget.profile.coupsDeCoeurCount}', 'Coup de cœur ❤️', Colors.amber),
                    _buildStatItem(Icons.people, '${widget.profile.connexionsCount}', 'Matchs', Colors.blue),
                    _buildStatItem(Icons.visibility, '${_visitorsCount}', 'Visites', Colors.green),
                  ],
                ),
              ],
            ),
          ),
          if (!isOwnProfile && _isCreator && !_isCheckingCreator)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _goToCreatorProfile,
                icon: Icon(Icons.people, size: 18, color: primaryRed),
                label: Text('Voir le profil créateur', style: TextStyle(color: primaryRed)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: primaryRed), padding: EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              ),
            ),
          if (isGold)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.diamond, size: 14, color: Colors.amber.shade800), SizedBox(width: 6), Text('Abonnement Gold actif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.amber.shade800))],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String remainingLikesText, bool isGold) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          _buildActionItem(
            color: Colors.red,
            activeColor: Colors.red.shade400,
            isActive: _isLiked,
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            label: _isLiked ? 'Liké ❤️' : 'Liker',
            // subText: '$remainingLikesText restants',
            subText: '- restants',
            onTap: _handleLike,
          ),

          SizedBox(width: 10),

          _buildActionItem(
            color: Colors.amber,
            activeColor: Colors.amber.shade600,
            isActive: _isCoupDeCoeur,
            icon: _isCoupDeCoeur ? Icons.favorite : Icons.favorite_border,
            label: _isCoupDeCoeur ? 'Envoyé ❤️' : 'Coup de cœur',
            // subText: '$_remainingSuperLikes restants',
            subText: '- restants',
            onTap: _handleCoupDeCoeur,
          ),

          SizedBox(width: 10),

          _buildChatButton(isGold),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required Color color,
    required Color activeColor,
    required bool isActive,
    required IconData icon,
    required String label,
    required String subText,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 52,
              padding: EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isActive ? activeColor : color,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: Colors.white), // ✅ blanc
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white, // ✅ blanc
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6),
          Text(
            subText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade400, // léger gris pour contraste
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatButton(bool isGold) {
    return Expanded(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => isGold ? _openChat() : _showGoldRequiredDialog(),
            child: Container(
              height: 52,
              padding: EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isGold ? Colors.green : Colors.amber,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: (isGold ? Colors.green : Colors.amber).withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                   Icons.chat,
                    size: 18,
                    color: Colors.white, // ✅ blanc
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                       'Discuter',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white, // ✅ blanc
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6),
          if (!isGold)
            Text(
              'Abonnement requis',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade400,
              ),
            ),
        ],
      ),
    );
  }
  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.only(top: 8),
      child: TabBar(
        controller: _tabController,
        tabs: _tabs,
        labelColor: primaryRed,
        unselectedLabelColor: Colors.grey,
        indicatorColor: primaryRed,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('À propos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(widget.profile.bio, style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey.shade700)),
          SizedBox(height: 24),
          if (widget.profile.centresInteret.isNotEmpty) ...[
            Text('Centres d\'intérêt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.profile.centresInteret.map((interet) => Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                child: Text(interet, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              )).toList(),
            ),
            SizedBox(height: 24),
          ],
          Text('Recherche', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 20, color: Colors.red),
                SizedBox(width: 12),
                Text(
                  '${_getSexeLabel(widget.profile.rechercheSexe)} de ${widget.profile.rechercheAgeMin} à ${widget.profile.rechercheAgeMax} ans',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsContent(bool isOwnProfile) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('creator_contents')
          .where('creatorUserId', isEqualTo: widget.profile.userId)
          .where('isPublished', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        final contents = snapshot.data?.docs.map((doc) => CreatorContent.fromJson(doc.data() as Map<String, dynamic>)).toList() ?? [];
        if (contents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 80, color: Colors.grey.shade400),
                SizedBox(height: 16),
                Text('Aucun post pour le moment', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: contents.length,
          itemBuilder: (context, index) {
            final content = contents[index];
            final canAccess = !content.isPaid || _isSubscribed || isOwnProfile;
            return GestureDetector(
              onTap: () {
                if (canAccess) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CreatorContentDetailPage(content: content)));
                } else {
                  _showSubscriptionRequiredDialog();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(content.thumbnailUrl ?? content.mediaUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade200, child: Icon(Icons.image, size: 40))),
                            if (content.isPaid && !canAccess)
                              Container(
                                color: Colors.black54,
                                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lock, size: 30, color: Colors.white), SizedBox(height: 4), Text('Abonnement requis', style: TextStyle(color: Colors.white, fontSize: 10))])),
                              ),
                            if (content.isPaid && canAccess)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lock_open, size: 10, color: Colors.white), SizedBox(width: 4), Text('${content.priceCoins} coins', style: TextStyle(color: Colors.white, fontSize: 10))]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(content.titre, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.favorite, size: 10, color: Colors.red),
                              SizedBox(width: 2),
                              Text('${content.likesCount + content.lovesCount}', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              SizedBox(width: 8),
                              Icon(Icons.visibility, size: 10, color: Colors.grey),
                              SizedBox(width: 2),
                              Text('${content.viewsCount}', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSubscriptionRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Abonnement requis'),
        content: Text('Pour accéder aux posts payants de ${widget.profile.pseudo}, vous devez vous abonner à son contenu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Plus tard')),
          ElevatedButton(onPressed: () { Navigator.pop(context); _subscribeToCreator(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text('S\'abonner')),
        ],
      ),
    );
  }

  String _getSexeLabel(String sexe) {
    switch (sexe) {
      case 'homme':
        return 'Hommes';
      case 'femme':
        return 'Femmes';
      default:
        return 'Tous';
    }
  }
}