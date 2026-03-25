// lib/pages/dating/dating_entry_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/dating/dating_provider.dart';
import '../../providers/authProvider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'buy_coins_page.dart';
import 'dating_chat_page.dart';
import 'dating_profile_detail_page.dart';


// lib/pages/dating/dating_swipe_page.dart
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dating_creator_posts_tab.dart';
import 'dating_profile_setup_page.dart';
import 'dating_subscription_page.dart';


class DatingSwipePage extends StatefulWidget {
  const DatingSwipePage({Key? key}) : super(key: key);

  @override
  State<DatingSwipePage> createState() => _DatingSwipePageState();
}

class _DatingSwipePageState extends State<DatingSwipePage> with TickerProviderStateMixin {
  // Swipe data
  List<DatingProfile> _profiles = [];
  List<DatingProfile> _history = [];
  int _currentIndex = 0;
  int _likeCount = 0; // Compteur de likes pour le modal
  int _likeCountThreshold = 3; // Afficher modal après 3 likes

  // Loading states
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  // User data
  String? _currentUserId;
  DatingProfile? _currentUserProfile;
  int _remainingLikes = 0;
  int _remainingSuperLikes = 0;
  String? _subscriptionPlan;

  // Filters
  String _selectedGenderFilter = 'tous'; // 'tous', 'femme', 'homme'
  String _selectedPopularityFilter = 'tous'; // 'tous', 'populaire', 'moins_populaire'
  int _minAge = 18;
  int _maxAge = 99;
  bool _showFilters = false;

  // Animation
  Offset _dragOffset = Offset.zero;
  double _rotationAngle = 0.0;
  double _opacity = 1.0;
  bool _isSwiping = false;

  // Messages incitatifs
  final List<Map<String, dynamic>> _motivationalMessages = [
    {'text': '✨ Trouvez l\'amour sur AfroLove ✨', 'icon': Icons.favorite, 'color': Colors.red},
    {'text': '💕 Faites des rencontres authentiques 💕', 'icon': Icons.people, 'color': Colors.pink},
    {'text': '⭐ Des personnes vous ont liké ! Passez Premium pour les voir ⭐', 'icon': Icons.star, 'color': Colors.amber},
    {'text': '🎁 Devenez créateur de contenu et gagnez de l\'argent ! 🎁', 'icon': Icons.monetization_on, 'color': Colors.green},
    {'text': '💬 Discutez en privé avec AfroLove Plus 💬', 'icon': Icons.chat, 'color': Colors.blue},
    {'text': '🔥 Des profils populaires vous attendent ! Swipez ! 🔥', 'icon': Icons.whatshot, 'color': Colors.orange},
  ];

  int _currentMessageIndex = 0;
  Timer? _messageTimer;
  bool _showMessage = true;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  static const int _batchSize = 10;

  @override
  void initState() {
    super.initState();
    _startMessageTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      _currentUserId = authProvider.loginUserData.id;
      _loadRemainingLikes();
      _loadUserSubscription();
      _loadCurrentUserProfile();
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  void _startMessageTimer() {
    _messageTimer = Timer.periodic(Duration(seconds: 8), (timer) {
      if (mounted) {
        setState(() {
          _showMessage = false;
        });
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _currentMessageIndex = (_currentMessageIndex + 1) % _motivationalMessages.length;
              _showMessage = true;
            });
          }
        });
      }
    });
  }

  Future<void> _loadRemainingLikes() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLikes = prefs.getInt('dating_remaining_likes_$_currentUserId');
    if (savedLikes != null) {
      setState(() => _remainingLikes = savedLikes);
    }
  }

  Future<void> _saveRemainingLikes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dating_remaining_likes_$_currentUserId', _remainingLikes);
  }

  Future<void> _loadUserSubscription() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await firestore
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final subscription = snapshot.docs.first;
        _subscriptionPlan = subscription['planCode'];

        switch (_subscriptionPlan) {
          case 'gold':
            _remainingLikes = -1;
            _remainingSuperLikes = 5;
            break;
          case 'plus':
            _remainingLikes = 50;
            _remainingSuperLikes = 2;
            break;
          default:
            if (_remainingLikes <= 0) _remainingLikes = 10;
            _remainingSuperLikes = 1;
        }
      } else {
        if (_remainingLikes <= 0) _remainingLikes = 10;
        _remainingSuperLikes = 1;
      }
      _saveRemainingLikes();
      setState(() {});
    } catch (e) {
      print('Erreur chargement abonnement: $e');
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DatingProfileSetupPage(profile: null)),
        );
        return;
      }

      _currentUserProfile = DatingProfile.fromJson(snapshot.docs.first.data());

      if (!_currentUserProfile!.isProfileComplete) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DatingProfileSetupPage(profile: _currentUserProfile)),
        );
        return;
      }

      await _loadProfiles();
    } catch (e) {
      print('Erreur chargement profil: $e');
    }
  }

  Future<void> _loadProfiles({bool isLoadMore = false}) async {
    if (_currentUserId == null || _currentUserProfile == null) return;
    if (isLoadMore && (_isLoadingMore || !_hasMore)) return;

    setState(() {
      if (isLoadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final likedUserIds = await _getLikedUserIds();
      final blockedUserIds = await _getBlockedUserIds();

      Query query = firestore
          .collection('dating_profiles')
          .where('userId', isNotEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      // Appliquer les filtres
      if (_selectedGenderFilter != 'tous') {
        query = query.where('sexe', isEqualTo: _selectedGenderFilter);
      }

      if (_minAge > 18 || _maxAge < 99) {
        query = query.where('age', isGreaterThanOrEqualTo: _minAge)
            .where('age', isLessThanOrEqualTo: _maxAge);
      }

      if (isLoadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final batchSize = _batchSize * 2;
      final snapshot = await query.limit(batchSize).get();

      if (snapshot.docs.isEmpty) {
        if (isLoadMore) setState(() => _hasMore = false);
        setState(() => _isLoading = false);
        return;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      List<DatingProfile> newProfiles = snapshot.docs
          .map((doc) => DatingProfile.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      newProfiles = newProfiles.where((p) =>
      !likedUserIds.contains(p.userId) &&
          !blockedUserIds.contains(p.userId) &&
          p.userId != _currentUserId
      ).toList();

      // Appliquer filtre de popularité
      if (_selectedPopularityFilter != 'tous') {
        if (_selectedPopularityFilter == 'populaire') {
          newProfiles.sort((a, b) => b.likesCount.compareTo(a.likesCount));
          newProfiles = newProfiles.take(newProfiles.length ~/ 2).toList();
        } else if (_selectedPopularityFilter == 'moins_populaire') {
          newProfiles.sort((a, b) => a.likesCount.compareTo(b.likesCount));
          newProfiles = newProfiles.take(newProfiles.length ~/ 2).toList();
        }
      }

      // Équilibrage homme/femme
      final isMale = _currentUserProfile!.sexe.toLowerCase() == 'homme';
      List<DatingProfile> balancedProfiles = [];

      if (isMale) {
        final women = newProfiles.where((p) => p.sexe.toLowerCase() == 'femme').toList();
        final men = newProfiles.where((p) => p.sexe.toLowerCase() == 'homme').toList();
        int womenToTake = (newProfiles.length * 0.8).toInt();
        int menToTake = newProfiles.length - womenToTake;
        women.shuffle();
        men.shuffle();
        balancedProfiles.addAll(women.take(womenToTake));
        balancedProfiles.addAll(men.take(menToTake));
      } else {
        final women = newProfiles.where((p) => p.sexe.toLowerCase() == 'femme').toList();
        final men = newProfiles.where((p) => p.sexe.toLowerCase() == 'homme').toList();
        int womenToTake = (newProfiles.length * 0.7).toInt();
        int menToTake = newProfiles.length - womenToTake;
        women.shuffle();
        men.shuffle();
        balancedProfiles.addAll(women.take(womenToTake));
        balancedProfiles.addAll(men.take(menToTake));
      }

      balancedProfiles.shuffle();

      if (isLoadMore) {
        _profiles.addAll(balancedProfiles);
        setState(() => _isLoadingMore = false);
      } else {
        _profiles = balancedProfiles;
        setState(() => _isLoading = false);
      }

    } catch (e) {
      print('Erreur chargement profils: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<List<String>> _getLikedUserIds() async {
    final snapshot = await firestore
        .collection('dating_likes')
        .where('fromUserId', isEqualTo: _currentUserId)
        .get();
    return snapshot.docs.map((doc) => doc['toUserId'] as String).toList();
  }

  Future<List<String>> _getBlockedUserIds() async {
    final snapshot = await firestore
        .collection('dating_blocks')
        .where('blockerUserId', isEqualTo: _currentUserId)
        .get();
    return snapshot.docs.map((doc) => doc['blockedUserId'] as String).toList();
  }

  void _handleSwipeLeft() {
    if (_isLoadingMore || _isSwiping || _currentIndex >= _profiles.length) return;

    _isSwiping = true;
    final profile = _profiles[_currentIndex];

    _nextProfile();
    _recordSwipeAction(profile.userId, 'left').catchError((e) => print('Erreur: $e'));

    Future.delayed(Duration(milliseconds: 300), () {
      _isSwiping = false;
    });
  }

  void _handleSwipeRight() {
    if (_isLoadingMore || _isSwiping || _currentIndex >= _profiles.length) return;

    // Vérifier la limite de likes
    if (_remainingLikes != -1 && _remainingLikes <= 0) {
      _showUpgradeDialog();
      return;
    }

    _isSwiping = true;
    final profile = _profiles[_currentIndex];

    // Incrémenter le compteur de likes
    _likeCount++;

    // Sauvegarder le profil liké dans l'historique local
    _history.add(profile);

    _nextProfile();
    _processLike(profile);
    _checkAndLoadMore();

    // Afficher le modal après 3 likes
    if (_likeCount >= _likeCountThreshold) {
      _likeCount = 0;
      _showLikedProfilesPremiumDialog();
    }

    Future.delayed(Duration(milliseconds: 300), () {
      _isSwiping = false;
    });
  }

  void _handleSuperLike() {
    if (_isLoadingMore || _isSwiping || _currentIndex >= _profiles.length) return;

    if (_remainingSuperLikes <= 0) {
      _showUpgradeDialog();
      return;
    }

    _isSwiping = true;
    final profile = _profiles[_currentIndex];

    _nextProfile();
    _processSuperLike(profile);
    _checkAndLoadMore();

    Future.delayed(Duration(milliseconds: 300), () {
      _isSwiping = false;
    });
  }

  Future<void> _processLike(DatingProfile profile) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final likeId = firestore.collection('dating_likes').doc().id;

      await firestore.collection('dating_likes').doc(likeId).set({
        'id': likeId,
        'fromUserId': _currentUserId,
        'toUserId': profile.userId,
        'createdAt': now,
      });

      if (_remainingLikes != -1) {
        setState(() {
          _remainingLikes--;
          _saveRemainingLikes();
        });
      }

      _updateUserPoints(_currentUserId!, 5, 'Like envoyé');
      _recordSwipeAction(profile.userId, 'right');

      await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: profile.userId)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update({'likesCount': FieldValue.increment(1)});
        }
      });

      final mutualLike = await firestore
          .collection('dating_likes')
          .where('fromUserId', isEqualTo: profile.userId)
          .where('toUserId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (mutualLike.docs.isNotEmpty) {
        await _updateUserPoints(_currentUserId!, 50, 'Match réalisé !');
        await _updateUserPoints(profile.userId, 50, 'Match réalisé !');
        await _createConnection(profile.userId);
        await _sendNotification(
          toUserId: profile.userId,
          message: "✨ Vous avez un nouveau match avec @${_getCurrentUserPseudo()} !",
          type: 'match',
        );
        _showMatchDialog(profile);
      } else {
        await _sendNotification(
          toUserId: profile.userId,
          message: "❤️ @${_getCurrentUserPseudo()} vous a liké !",
          type: 'like',
        );
        _showSuccessMessage('Vous avez liké ${profile.pseudo} (+5 points)', Colors.green);
      }

    } catch (e) {
      print('Erreur like: $e');
      _showSuccessMessage('Erreur lors du like', Colors.red);
    }
  }

  Future<void> _processSuperLike(DatingProfile profile) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;
    const superLikePrice = 20;

    if (_subscriptionPlan != 'gold' && currentCoins < superLikePrice) {
      _showInsufficientCoinsDialog();
      return;
    }

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      if (_subscriptionPlan != 'gold') {
        await firestore.collection('Users').doc(_currentUserId).update({
          'coinsBalance': FieldValue.increment(-superLikePrice),
          'totalCoinsSpent': FieldValue.increment(superLikePrice),
        });
      }

      final coupId = firestore.collection('dating_coup_de_coeurs').doc().id;
      await firestore.collection('dating_coup_de_coeurs').doc(coupId).set({
        'id': coupId,
        'fromUserId': _currentUserId,
        'toUserId': profile.userId,
        'createdAt': now,
      });

      setState(() => _remainingSuperLikes--);
      _updateUserPoints(_currentUserId!, 20, 'Super like envoyé');

      await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: profile.userId)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update({'coupsDeCoeurCount': FieldValue.increment(1)});
        }
      });

      await _sendNotification(
        toUserId: profile.userId,
        message: "⭐ @${_getCurrentUserPseudo()} vous a envoyé un super like !",
        type: 'super_like',
      );

      _showSuccessMessage('✨ Super like envoyé à ${profile.pseudo} (+20 points)', Colors.amber);

    } catch (e) {
      print('Erreur super like: $e');
    }
  }

  void _showLikedProfilesPremiumDialog() {
    final isPremium = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite,
                  size: 50,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '❤️ ${_history.length} profils likés !',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                isPremium
                    ? 'Vous pouvez voir tous vos likes dans votre liste.'
                    : 'Voir qui vous a liké et vos likes est réservé aux membres AfroLove Plus et Gold.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 24),
              if (!isPremium) ...[
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DatingSubscriptionPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text('Voir les offres'),
                ),
                SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(isPremium ? 'Fermer' : 'Continuer à swiper'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPremiumChatDialog(DatingProfile profile) {
    final isPremium = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');

    if (!isPremium) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Discuter en privé', style: TextStyle(color: Colors.red)),
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
      return;
    }

    // Accès au chat pour les premium
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DatingChatPage(
          connectionId: '',
          otherUserId: profile.userId,
          otherUserName: profile.pseudo,
          otherUserImage: profile.imageUrl,
        ),
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Limite de likes atteinte', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 50, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'Vous avez atteint votre limite de likes gratuits.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Passez à AfroLove Plus ou Gold pour des likes illimités !',
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BuyCoinsPage()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: Text('Acheter des pièces'),
          ),
        ],
      ),
    );
  }

  void _showMatchDialog(DatingProfile profile) {
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
                'C\'est un match !',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red.shade700),
              ),
              SizedBox(height: 8),
              Text(
                'Vous et ${profile.pseudo} vous êtes likés mutuellement.',
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
                        _showPremiumChatDialog(profile);
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

  Future<void> _updateUserPoints(String userId, int points, String reason) async {
    await firestore.collection('Users').doc(userId).update({
      'totalPoints': FieldValue.increment(points),
    });
  }

  Future<void> _recordSwipeAction(String targetUserId, String direction) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final actionId = firestore.collection('dating_swipe_actions').doc().id;
    await firestore.collection('dating_swipe_actions').doc(actionId).set({
      'id': actionId,
      'userId': _currentUserId,
      'targetUserId': targetUserId,
      'direction': direction,
      'createdAt': now,
    });
  }

  Future<void> _createConnection(String otherUserId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final connectionId = firestore.collection('dating_connections').doc().id;

    await firestore.collection('dating_connections').doc(connectionId).set({
      'id': connectionId,
      'userId1': _currentUserId,
      'userId2': otherUserId,
      'createdAt': now,
      'isActive': true,
    });
  }

  Future<void> _sendNotification({
    required String toUserId,
    required String message,
    required String type,
  }) async {
    final now = DateTime.now().microsecondsSinceEpoch;
    final currentUser = await _getCurrentUser();

    final notificationId = firestore.collection('Notifications').doc().id;
    await firestore.collection('Notifications').doc(notificationId).set({
      'id': notificationId,
      'titre': type == 'match' ? 'Nouveau match ! 🎉' : type == 'super_like' ? 'Super like ! ⭐' : 'Nouveau like ❤️',
      'media_url': currentUser?.imageUrl ?? '',
      'type': 'DATING_${type.toUpperCase()}',
      'description': message,
      'users_id_view': [],
      'user_id': _currentUserId,
      'receiver_id': toUserId,
      'createdAt': now,
      'updatedAt': now,
      'status': 'VALIDE',
    });

    final toUserDoc = await firestore.collection('Users').doc(toUserId).get();
    final toUser = UserData.fromJson(toUserDoc.data() ?? {});

    if (toUser.oneIgnalUserid != null && toUser.oneIgnalUserid!.isNotEmpty) {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      await authProvider.sendNotification(
        userIds: [toUser.oneIgnalUserid!],
        smallImage: currentUser?.imageUrl ?? '',
        send_user_id: _currentUserId!,
        recever_user_id: toUserId,
        message: message,
        type_notif: 'DATING_${type.toUpperCase()}',
        post_id: '',
        post_type: '',
        chat_id: '',
      );
    }
  }

  Future<UserData?> _getCurrentUser() async {
    final doc = await firestore.collection('Users').doc(_currentUserId).get();
    if (doc.exists) return UserData.fromJson(doc.data()!);
    return null;
  }

  String _getCurrentUserPseudo() {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return authProvider.loginUserData.pseudo ?? 'Utilisateur';
  }

  void _showSuccessMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _nextProfile() {
    setState(() {
      _currentIndex++;
      _dragOffset = Offset.zero;
      _rotationAngle = 0.0;
      _opacity = 1.0;
    });
  }

  void _checkAndLoadMore() {
    if (_profiles.length - _currentIndex <= 3 && _hasMore && !_isLoadingMore) {
      _loadProfiles(isLoadMore: true);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isLoadingMore || _isSwiping) return;

    setState(() {
      _dragOffset = details.delta;
      _rotationAngle = _dragOffset.dx / 500;
      _opacity = 1.0 - (_dragOffset.dx.abs() / 500).clamp(0.0, 1.0);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isLoadingMore || _isSwiping) {
      setState(() {
        _dragOffset = Offset.zero;
        _rotationAngle = 0.0;
        _opacity = 1.0;
      });
      return;
    }

    if (_dragOffset.dx.abs() > 100) {
      if (_dragOffset.dx > 0) {
        _handleSwipeRight();
      } else {
        _handleSwipeLeft();
      }
    }

    setState(() {
      _dragOffset = Offset.zero;
      _rotationAngle = 0.0;
      _opacity = 1.0;
    });
  }

  void _goToCreatorsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DatingCreatorPostsPage(),
      ),
    );
  }

  void _goToMyProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DatingProfileDetailPage(profile: _currentUserProfile!),
      ),
    );
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void _applyFilters() {
    _loadProfiles();
    setState(() {
      _showFilters = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null || _isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Chargement des profils...'),
            ],
          ),
        ),
      );
    }

    if (_profiles.isEmpty || _currentIndex >= _profiles.length) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
              SizedBox(height: 16),
              Text(
                'Plus de profils à découvrir',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
              ),
              SizedBox(height: 8),
              Text('Revenez plus tard pour de nouveaux profils', style: TextStyle(color: Colors.grey.shade500)),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _hasMore = true;
                  _loadProfiles();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Actualiser'),
              ),
            ],
          ),
        ),
      );
    }

    final currentProfile = _profiles[_currentIndex];
    final hasSubscription = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.favorite, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('AfroLove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        centerTitle: false,
        actions: [
          // Compteur de likes
          Container(
            margin: EdgeInsets.only(right: 8),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  _remainingLikes == -1 ? '∞' : '$_remainingLikes',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.star, size: 14, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  '$_remainingSuperLikes',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Filtres
          GestureDetector(
            onTap: _toggleFilters,
            child: Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Filtres', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
          // Créateurs
          GestureDetector(
            onTap: _goToCreatorsPage,
            child: Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Créateurs', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
          // Mon profil
          GestureDetector(
            onTap: _goToMyProfile,
            child: Container(
              margin: EdgeInsets.only(right: 16),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Moi', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Carte de profil suivante
          if (_currentIndex + 1 < _profiles.length)
            _buildProfileCard(_profiles[_currentIndex + 1], isNext: true),

          // Carte principale avec animation
          Transform.translate(
            offset: _dragOffset,
            child: Transform.rotate(
              angle: _rotationAngle,
              child: Opacity(
                opacity: _opacity,
                child: GestureDetector(
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DatingProfileDetailPage(profile: currentProfile),
                      ),
                    );
                  },
                  child: _buildProfileCard(currentProfile, isNext: false),
                ),
              ),
            ),
          ),

          // Messages incitatifs
          Positioned(
            top: 12,
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              opacity: _showMessage ? 1.0 : 0.0,
              duration: Duration(milliseconds: 500),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _motivationalMessages[_currentMessageIndex]['color'].withOpacity(0.85),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_motivationalMessages[_currentMessageIndex]['icon'], color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _motivationalMessages[_currentMessageIndex]['text'],
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Filtres panel
          if (_showFilters)
            Positioned(
              top: 60,
              left: 20,
              right: 20,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Filtres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedGenderFilter,
                        decoration: InputDecoration(labelText: 'Genre', border: OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'tous', child: Text('Tous')),
                          DropdownMenuItem(value: 'femme', child: Text('Femmes')),
                          DropdownMenuItem(value: 'homme', child: Text('Hommes')),
                        ],
                        onChanged: (value) => setState(() => _selectedGenderFilter = value!),
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedPopularityFilter,
                        decoration: InputDecoration(labelText: 'Popularité', border: OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'tous', child: Text('Tous')),
                          DropdownMenuItem(value: 'populaire', child: Text('Les plus populaires')),
                          DropdownMenuItem(value: 'moins_populaire', child: Text('Moins populaires')),
                        ],
                        onChanged: (value) => setState(() => _selectedPopularityFilter = value!),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'Âge min', border: OutlineInputBorder()),
                              onChanged: (value) => _minAge = int.tryParse(value) ?? 18,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'Âge max', border: OutlineInputBorder()),
                              onChanged: (value) => _maxAge = int.tryParse(value) ?? 99,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _showFilters = false),
                              child: Text('Annuler'),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _applyFilters,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: Text('Appliquer'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Indicateur de chargement
          if (_isLoadingMore)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 8),
                      Text('Chargement de nouveaux profils...', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          // Indicateur de swipe
          if (_dragOffset.dx != 0)
            Positioned(
              top: 100,
              left: _dragOffset.dx > 0 ? 40 : null,
              right: _dragOffset.dx < 0 ? 40 : null,
              child: Transform.rotate(
                angle: _dragOffset.dx > 0 ? -0.3 : 0.3,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _dragOffset.dx > 0 ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    _dragOffset.dx > 0 ? 'LIKE' : 'PASS',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: Offset(0, -2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.close,
              color: Colors.red,
              onPressed: _handleSwipeLeft,
              size: 28,
            ),
            _buildActionButton(
              icon: Icons.star,
              color: Colors.amber,
              onPressed: _handleSuperLike,
              size: 32,
            ),
            _buildActionButton(
              icon: Icons.favorite,
              color: Colors.green,
              onPressed: _handleSwipeRight,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(DatingProfile profile, {required bool isNext}) {
    final hasSubscription = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                profile.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade200,
                  child: Icon(Icons.person, size: 80, color: Colors.grey.shade400),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${profile.pseudo}, ${profile.age}',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      if (profile.isVerified)
                        Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.verified, size: 20, color: Colors.blue),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.white70),
                      SizedBox(width: 4),
                      Text('${profile.ville}, ${profile.pays}', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    profile.bio.length > 100 ? '${profile.bio.substring(0, 100)}...' : profile.bio,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!profile.isProfileComplete) ...[
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                      child: Text('Profil incomplet', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: profile.centresInteret.take(3).map((interet) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                        child: Text(interet, style: TextStyle(color: Colors.white, fontSize: 12)),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 12),
                  // Bouton Discuter en privé
                  GestureDetector(
                    onTap: () => _showPremiumChatDialog(profile),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: hasSubscription ? Colors.red : Colors.amber,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasSubscription ? Icons.chat : Icons.lock,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            hasSubscription ? 'Discuter en privé' : 'Discuter en privé (Premium)',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onPressed, double size = 28}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Icon(icon, size: size, color: Colors.white),
      ),
    );
  }
}