// lib/pages/dating/dating_profile_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/dating/dating_provider.dart';
import 'creator_content_detail_page.dart';
import 'creator_subscription_page.dart';
import 'dating_chat_page.dart';

// lib/pages/dating/dating_profile_detail_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dating_profile_setup_page.dart';
import 'dating_subscription_page.dart';


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

  late TabController _tabController;
  final List<Tab> _tabs = const [
    Tab(text: 'Profil'),
    Tab(text: 'Posts'),
  ];

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadUserData();
    _loadSubscriptionStatus();
    _checkLikeStatus();
    _checkCoupDeCoeurStatus();
    _recordVisit();
    _loadVisitorsCount();
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

  Future<void> _loadSubscriptionStatus() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null) {
      setState(() => _isCheckingSubscription = false);
      return;
    }

    try {
      // Vérifier l'abonnement dating
      final subSnapshot = await firestore
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (subSnapshot.docs.isNotEmpty) {
        final subscription = UserDatingSubscription.fromJson(subSnapshot.docs.first.data());
        final now = DateTime.now().millisecondsSinceEpoch;
        if (subscription.endAt > now) {
          _currentSubscriptionPlan = subscription.planCode;
          print('📌 Abonnement dating actif: $_currentSubscriptionPlan');
        }
      }

      // Charger les limites
      final prefs = await SharedPreferences.getInstance();
      _remainingLikes = prefs.getInt('dating_remaining_likes_$currentUserId') ?? 10;
      _remainingSuperLikes = prefs.getInt('dating_remaining_super_likes_$currentUserId') ?? 1;

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
      setState(() => _isCheckingSubscription = false);
    }
  }

  Future<void> _recordVisit() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null || currentUserId == widget.profile.userId) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final visitId = firestore.collection('dating_profile_visits').doc().id;

      await firestore.collection('dating_profile_visits').doc(visitId).set({
        'id': visitId,
        'visitorUserId': currentUserId,
        'visitedUserId': widget.profile.userId,
        'createdAt': now,
      });

      // Incrémenter le compteur de visites
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

      print('✅ Visite enregistrée pour ${widget.profile.pseudo}');
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

    // Vérifier la limite de likes
    if (_remainingLikes <= 0 && _currentSubscriptionPlan == null) {
      _showUpgradeDialog('limite de likes');
      return;
    }

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final likeId = firestore.collection('dating_likes').doc().id;

      await firestore.collection('dating_likes').doc(likeId).set({
        'id': likeId,
        'fromUserId': currentUserId,
        'toUserId': widget.profile.userId,
        'createdAt': now,
      });

      setState(() {
        _isLiked = true;
        if (_remainingLikes > 0) _remainingLikes--;
      });

      // Mettre à jour les limites
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dating_remaining_likes_$currentUserId', _remainingLikes);

      // Envoyer notification
      await _sendNotification(
        toUserId: widget.profile.userId,
        message: "❤️ @${authProvider.loginUserData.pseudo} vous a liké !",
        type: 'like',
      );

      // Mettre à jour le compteur
      await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: widget.profile.userId)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update({
            'likesCount': FieldValue.increment(1),
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❤️ Vous avez liké ${widget.profile.pseudo} (+5 points)'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Vérifier le match
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du like'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleCoupDeCoeur() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    if (_remainingSuperLikes <= 0 && _currentSubscriptionPlan == null) {
      _showUpgradeDialog('super like');
      return;
    }

    final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;
    const coupDeCoeurPrice = 20;

    if (_currentSubscriptionPlan != 'gold' && currentCoins < coupDeCoeurPrice) {
      _showInsufficientCoinsDialog();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('✨ Envoyer un super like'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 50, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'Envoyer un super like à ${widget.profile.pseudo} ?',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              _currentSubscriptionPlan == 'gold'
                  ? 'Gratuit avec votre abonnement Gold'
                  : 'Coût: $coupDeCoeurPrice pièces',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
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
              backgroundColor: Colors.amber,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text('Envoyer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      if (_currentSubscriptionPlan != 'gold') {
        await firestore.collection('Users').doc(currentUserId).update({
          'coinsBalance': FieldValue.increment(-coupDeCoeurPrice),
          'totalCoinsSpent': FieldValue.increment(coupDeCoeurPrice),
        });
      }

      final coupId = firestore.collection('dating_coup_de_coeurs').doc().id;
      await firestore.collection('dating_coup_de_coeurs').doc(coupId).set({
        'id': coupId,
        'fromUserId': currentUserId,
        'toUserId': widget.profile.userId,
        'createdAt': now,
      });

      setState(() {
        _isCoupDeCoeur = true;
        if (_remainingSuperLikes > 0) _remainingSuperLikes--;
      });

      // Mettre à jour les limites
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dating_remaining_super_likes_$currentUserId', _remainingSuperLikes);

      await _sendNotification(
        toUserId: widget.profile.userId,
        message: "⭐ @${authProvider.loginUserData.pseudo} vous a envoyé un super like !",
        type: 'super_like',
      );

      // Mettre à jour le compteur
      await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: widget.profile.userId)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update({
            'coupsDeCoeurCount': FieldValue.increment(1),
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ Super like envoyé à ${widget.profile.pseudo} (+20 points)'),
          backgroundColor: Colors.amber,
        ),
      );

    } catch (e) {
      print('❌ Erreur super like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du super like'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sendNotification({
    required String toUserId,
    required String message,
    required String type,
  }) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final now = DateTime.now().microsecondsSinceEpoch;

    final notificationId = firestore.collection('Notifications').doc().id;
    await firestore.collection('Notifications').doc(notificationId).set({
      'id': notificationId,
      'titre': type == 'match' ? 'Nouveau match ! 🎉' : type == 'super_like' ? 'Super like ! ⭐' : 'Nouveau like ❤️',
      'media_url': authProvider.loginUserData.imageUrl,
      'type': 'DATING_${type.toUpperCase()}',
      'description': message,
      'users_id_view': [],
      'user_id': authProvider.loginUserData.id,
      'receiver_id': toUserId,
      'createdAt': now,
      'updatedAt': now,
      'status': 'VALIDE',
    });

    final toUserDoc = await firestore.collection('Users').doc(toUserId).get();
    final toUser = UserData.fromJson(toUserDoc.data() ?? {});

    if (toUser.oneIgnalUserid != null && toUser.oneIgnalUserid!.isNotEmpty) {
      await authProvider.sendNotification(
        userIds: [toUser.oneIgnalUserid!],
        smallImage: authProvider.loginUserData.imageUrl ?? '',
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
    final isPremium = _currentSubscriptionPlan != null &&
        (_currentSubscriptionPlan == 'plus' || _currentSubscriptionPlan == 'gold');

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
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.pink.shade400],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.favorite, size: 60, color: Colors.white),
              ),
              SizedBox(height: 20),
              Text(
                'C\'est un match ! 🎉',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
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
                        if (isPremium) {
                          _openChat();
                        } else {
                          _showPremiumChatDialog();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
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

  Future<void> _openChat() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null) return;

    // Chercher ou créer la connexion
    final connection = await _getOrCreateConnection();
    if (connection != null && mounted) {
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
      // Chercher connexion existante
      final snapshot = await firestore
          .collection('dating_connections')
          .where('userId1', isEqualTo: currentUserId)
          .where('userId2', isEqualTo: widget.profile.userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return DatingConnection.fromJson(snapshot.docs.first.data());
      }

      final snapshot2 = await firestore
          .collection('dating_connections')
          .where('userId1', isEqualTo: widget.profile.userId)
          .where('userId2', isEqualTo: currentUserId)
          .limit(1)
          .get();

      if (snapshot2.docs.isNotEmpty) {
        return DatingConnection.fromJson(snapshot2.docs.first.data());
      }

      // Créer nouvelle connexion
      final now = DateTime.now().millisecondsSinceEpoch;
      final connectionId = firestore.collection('dating_connections').doc().id;
      final connection = DatingConnection(
        id: connectionId,
        userId1: currentUserId,
        userId2: widget.profile.userId,
        createdAt: now,
        isActive: true,
      );

      await firestore
          .collection('dating_connections')
          .doc(connectionId)
          .set(connection.toJson());

      // Créer la conversation
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

  void _showPremiumChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('💬 Discuter en privé', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 50, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'La messagerie privée est réservée aux membres AfroLove Plus et Gold.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Passez à l\'abonnement Premium pour discuter avec vos matchs !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DatingSubscriptionPage()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: Text('Voir les offres'),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Limite atteinte', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 50, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'Vous avez atteint votre $feature gratuits.',
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DatingSubscriptionPage()),
              );
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
              'Vous n\'avez pas assez de pièces pour envoyer un super like.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '20 pièces requis',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
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

  Future<void> _handleReport() async {
    final reportReason = await showDialog<String>(
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
                .map((reason) => ListTile(
              leading: Icon(Icons.flag, size: 20),
              title: Text(reason),
              onTap: () => Navigator.pop(context, reason),
            ))
                .toList(),
          ],
        ),
      ),
    );

    if (reportReason == null) return;

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    try {
      final reportId = firestore.collection('dating_reports').doc().id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await firestore.collection('dating_reports').doc(reportId).set({
        'id': reportId,
        'reporterUserId': currentUserId,
        'targetUserId': widget.profile.userId,
        'reason': reportReason,
        'description': '',
        'createdAt': now,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signalement envoyé. Merci !'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du signalement'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleBlock() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Bloquer ${widget.profile.pseudo}'),
        content: Text(
          'Êtes-vous sûr de vouloir bloquer cet utilisateur ? '
              'Vous ne pourrez plus voir son profil ni recevoir ses messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Bloquer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    try {
      final blockId = firestore.collection('dating_blocks').doc().id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await firestore.collection('dating_blocks').doc(blockId).set({
        'id': blockId,
        'blockerUserId': currentUserId,
        'blockedUserId': widget.profile.userId,
        'createdAt': now,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.profile.pseudo} a été bloqué'), backgroundColor: Colors.red),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du blocage'), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateToChatList() {
    Navigator.pushNamed(context, '/dating/conversations');
  }

  void _navigateToMatches() {
    Navigator.pushNamed(context, '/dating/connections');
  }

  void _navigateToLikes() {
    final isPremium = _currentSubscriptionPlan != null &&
        (_currentSubscriptionPlan == 'plus' || _currentSubscriptionPlan == 'gold');

    if (!isPremium) {
      _showUpgradeDialog('voir vos likes');
      return;
    }
    Navigator.pushNamed(context, '/dating/likes-list');
  }

  void _navigateToNotifications() {
    Navigator.pushNamed(context, '/dating/notifications');
  }

  void _goToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DatingProfileSetupPage(profile: widget.profile),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context);
    final currentUserId = authProvider.loginUserData.id;
    final isOwnProfile = currentUserId == widget.profile.userId;
    final isPremium = _currentSubscriptionPlan != null &&
        (_currentSubscriptionPlan == 'plus' || _currentSubscriptionPlan == 'gold');

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
                    switch (value) {
                      case 'report':
                        _handleReport();
                        break;
                      case 'block':
                        _handleBlock();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Signaler'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Bloquer'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Barre d'actions supérieure (messages, matchs, etc.)
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionChip(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages',
                    onTap: _navigateToChatList,
                    color: Colors.blue,
                  ),
                  _buildActionChip(
                    icon: Icons.favorite_border,
                    label: 'Matchs',
                    onTap: _navigateToMatches,
                    color: Colors.red,
                  ),
                  _buildActionChip(
                    icon: Icons.thumb_up_outlined,
                    label: 'Likes',
                    onTap: _navigateToLikes,
                    color: isPremium ? Colors.pink : Colors.grey,
                    isLocked: !isPremium,
                  ),
                  _buildActionChip(
                    icon: Icons.notifications_none,
                    label: 'Notif',
                    onTap: _navigateToNotifications,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ),

          // Infos profil
          SliverToBoxAdapter(
            child: _buildProfileInfo(isOwnProfile),
          ),

          // TabBar
          SliverToBoxAdapter(
            child: _buildTabBar(),
          ),

          // TabBarView
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

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isLocked = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLocked ? Icons.lock : icon,
              size: 22,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isLocked ? Colors.grey : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCarousel() {
    return PageView.builder(
      itemCount: widget.profile.photosUrls.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _showFullScreenImage(widget.profile.photosUrls[index]),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                widget.profile.photosUrls[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: Icon(Icons.person, size: 100, color: Colors.grey.shade400),
                  );
                },
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        '${index + 1}/${widget.profile.photosUrls.length}',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo(bool isOwnProfile) {
    final isPremium = _currentSubscriptionPlan != null &&
        (_currentSubscriptionPlan == 'plus' || _currentSubscriptionPlan == 'gold');

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
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${widget.profile.pseudo}, ${widget.profile.age}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (widget.profile.isVerified)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified, size: 14, color: Colors.blue),
                            SizedBox(width: 4),
                            Text('Vérifié', style: TextStyle(fontSize: 12, color: Colors.blue)),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      '${widget.profile.ville}, ${widget.profile.pays}',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),

                // Dans DatingProfileDetailPage, ajouter dans _buildProfileInfo:

// Après l'affichage de la ville/pays, ajouter:
                if (widget.profile.countryCode != null || widget.profile.region != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.public, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          '${widget.profile.countryCode ?? ''}${widget.profile.region != null ? ' - ${widget.profile.region}' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                if (widget.profile.profession?.isNotEmpty ?? false) ...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.work, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        widget.profile.profession!,
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(Icons.favorite, '${widget.profile.likesCount}', 'Likes', Colors.red),
                    _buildStatItem(Icons.star, '${widget.profile.coupsDeCoeurCount}', 'Coups de cœur', Colors.amber),
                    _buildStatItem(Icons.people, '${widget.profile.connexionsCount}', 'Connexions', Colors.blue),
                    _buildStatItem(Icons.visibility, '${_visitorsCount}', 'Visites', Colors.green),
                  ],
                ),
              ],
            ),
          ),
          if (!isOwnProfile) _buildActionButtons(),
          if (isOwnProfile) _buildOwnProfileActions(),
          if (isPremium && _currentSubscriptionPlan != null)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _currentSubscriptionPlan == 'gold'
                    ? Colors.amber.shade100
                    : Colors.red.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentSubscriptionPlan == 'gold' ? Icons.diamond : Icons.star,
                    size: 14,
                    color: _currentSubscriptionPlan == 'gold' ? Colors.amber : Colors.red,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Abonnement ${_currentSubscriptionPlan == 'gold' ? 'Gold' : 'Plus'} actif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _currentSubscriptionPlan == 'gold' ? Colors.amber.shade800 : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
        ],
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

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _handleLike,
              icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, size: 20),
              label: Text(_isLiked ? 'Liké' : 'Liker'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLiked ? Colors.red.shade400 : Colors.red,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _handleCoupDeCoeur,
              icon: Icon(_isCoupDeCoeur ? Icons.star : Icons.star_border, size: 20),
              label: Text(_isCoupDeCoeur ? 'Coup de cœur' : 'Coup de cœur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCoupDeCoeur ? Colors.amber.shade600 : Colors.amber,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnProfileActions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _goToEditProfile,
              icon: Icon(Icons.edit, size: 20),
              label: Text('Modifier profil'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DatingSubscriptionPage()),
                );
              },
              icon: Icon(Icons.star, size: 20),
              label: Text('Premium'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.amber),
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
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
        labelColor: Colors.red,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.red,
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
          Text(
            widget.profile.bio,
            style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey.shade700),
          ),
          SizedBox(height: 24),

          if (widget.profile.centresInteret.isNotEmpty) ...[
            Text('Centres d\'intérêt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.profile.centresInteret.map((interet) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    interet,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 24),
          ],

          Text('Recherche', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
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
          SizedBox(height: 24),
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
        if (snapshot.hasError) {
          print('❌ Erreur chargement posts: ${snapshot.error}');
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final contents = snapshot.data?.docs
            .map((doc) => CreatorContent.fromJson(doc.data() as Map<String, dynamic>))
            .toList() ?? [];

        if (contents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 80, color: Colors.grey.shade400),
                SizedBox(height: 16),
                Text(
                  'Aucun post pour le moment',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreatorContentDetailPage(content: content),
                    ),
                  );
                } else {
                  _showSubscriptionRequiredDialog();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
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
                            Image.network(
                              content.thumbnailUrl ?? content.mediaUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.image, size: 40, color: Colors.grey.shade400),
                                );
                              },
                            ),
                            if (content.isPaid && !canAccess)
                              Container(
                                color: Colors.black54,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock, size: 30, color: Colors.white),
                                      SizedBox(height: 4),
                                      Text(
                                        'Abonnement requis',
                                        style: TextStyle(color: Colors.white, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (content.isPaid && canAccess)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_open, size: 10, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        '${content.priceCoins} coins',
                                        style: TextStyle(color: Colors.white, fontSize: 10),
                                      ),
                                    ],
                                  ),
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
                          Text(
                            content.titre,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.favorite, size: 10, color: Colors.red),
                              SizedBox(width: 2),
                              Text(
                                '${content.likesCount + content.lovesCount}',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.visibility, size: 10, color: Colors.grey),
                              SizedBox(width: 2),
                              Text(
                                '${content.viewsCount}',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
                              ),
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
        content: Text(
          'Pour accéder aux posts payants de ${widget.profile.pseudo}, '
              'vous devez vous abonner à son contenu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _subscribeToCreator();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('S\'abonner'),
          ),
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