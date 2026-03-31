// lib/pages/dating/dating_swipe_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../pub/rewarded_ad_widget.dart';
import '../pub/rewarded_interstitial_ad_widget.dart';
import 'buy_coins_page.dart';
import 'dating_chat_page.dart';
import 'dating_creator_posts_tab.dart';
import 'dating_explore_page.dart';
import 'dating_likes_list_page.dart';
import 'dating_notifications_page.dart';
import 'dating_profile_detail_page.dart';
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
  int _likeCount = 0;
  int _likeCountThreshold = 3;
// Ajouter dans les variables d'état
  bool _isLoadingAd = false;  // Pour afficher le chargement
  // Pour le recyclage
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  // Loading states
  bool _isLoading = true;
  bool _isLoadingMore = false;

  // User data
  String? _currentUserId;
  DatingProfile? _currentUserProfile;
  int _remainingLikes = 0;
  int _remainingSuperLikes = 0;
  String? _subscriptionPlan;
  String? _userSubscriptionDocId;
  int _unreadNotificationsCount = 0;

  // Filters
  String _selectedGenderFilter = 'tous';
  String _selectedPopularityFilter = 'tous';
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
    {'text': '💬 Discutez en privé avec AfroLove Gold 💬', 'icon': Icons.chat, 'color': Colors.blue},
    {'text': '🔥 Des profils populaires vous attendent ! Swipez ! 🔥', 'icon': Icons.whatshot, 'color': Colors.orange},
  ];
  int _currentMessageIndex = 0;
  Timer? _messageTimer;
  bool _showMessage = true;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  static const int _batchSize = 50; // Charger 50 profils par lot
  final GlobalKey<RewardedAdWidgetState> _rewardedAdKey = GlobalKey();
  bool _showRewardedAd = false;
  String? _pendingRewardType; // 'likes' ou 'superlikes'

  final GlobalKey<InterstitialAdWidgetState> _adKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    _startMessageTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      _currentUserId = authProvider.loginUserData.id;
      _listenUnreadNotifications();
      _initializeSubscriptionPlansIfNeeded();
      _loadUserSubscription();
      _loadCurrentUserProfile();
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }
  bool _wasActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = ModalRoute.of(context)?.isCurrent ?? false;
    if (isActive && !_wasActive) {
      _refreshData();
    }
    _wasActive = isActive;
  }

  Future<void> _addBonusLikes(int amount) async {
    setState(() {
      if (_remainingLikes != -1) {
        _remainingLikes += amount;
      }
    });
    await _saveRemainingLikes();
    _showSuccessMessage('+$amount likes offerts ! ❤️', Colors.green);
  }

  Future<void> _addBonusSuperLikes(int amount) async {
    setState(() {
      if (_remainingSuperLikes != -1) {
        _remainingSuperLikes += amount;
      }
    });
    await _saveRemainingLikes();
    _showSuccessMessage('+$amount super likes offerts ! ⭐', Colors.amber);
  }
  Future<void> _refreshData() async {
    await _loadUserSubscription();
    // Si vous voulez aussi recharger les profils (ex : après un achat), décommentez la ligne ci-dessous
    // await _loadProfiles(reset: true);
  }
  void _startMessageTimer() {
    _messageTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        setState(() => _showMessage = false);
        Future.delayed(const Duration(milliseconds: 500), () {
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

  void _listenUnreadNotifications() {
    if (_currentUserId == null) {
      print('⚠️ _listenUnreadNotifications: currentUserId is null');
      return;
    }

    final datingTypes = [
      'DATING_LIKE',
      'DATING_MATCH',
      'DATING_SUPER_LIKE',
      'DATING_MESSAGE',
    ];

    print('🔔 Listening for unread dating notifications for user: $_currentUserId');
    print('📋 Types recherchés: $datingTypes');

    firestore
        .collection('Notifications')
        .where('receiver_id', isEqualTo: _currentUserId)
        .where('type', whereIn: datingTypes)
        .where('is_open', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      print('📬 Snapshot reçu: ${snapshot.docs.length} documents');
      for (var doc in snapshot.docs) {
        print('   - ${doc.id} | type: ${doc['type']} | is_open: ${doc['is_open']}');
      }
      if (mounted) setState(() => _unreadNotificationsCount = snapshot.docs.length);
    }, onError: (e) {
      print('❌ Erreur dans le stream des notifications: $e');
    });
  }
  // ---------- Initialisation des plans d'abonnement (si inexistants) ----------
  Future<void> _initializeSubscriptionPlansIfNeeded() async {
    final snapshot = await firestore.collection('subscription_plans').limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final plans = [
      {
        'code': 'gratuit',
        'name': 'Gratuit',
        'description': 'Fonctionnalités de base',
        'priceCoins': 0,
        'durationInDays': 30,
        'features': ['10 likes par jour', '1 super like par jour', 'Profils recommandés'],
        'isActive': true,
        'defaultLikes': 10,
        'defaultSuperLikes': 1,
        'createdAt': now,
        'updatedAt': now,
      },
      {
        'code': 'plus',
        'name': 'AfroLove Plus',
        'description': 'Plus de fonctionnalités',
        'priceCoins': 500,
        'durationInDays': 30,
        'features': ['50 likes par jour', '2 super likes par jour', 'Voir qui vous a liké', 'Message prioritaire', 'Badge exclusif'],
        'isActive': true,
        'defaultLikes': 50,
        'defaultSuperLikes': 2,
        'createdAt': now,
        'updatedAt': now,
      },
      {
        'code': 'gold',
        'name': 'AfroLove Gold',
        'description': 'Expérience ultime',
        'priceCoins': 1500,
        'durationInDays': 30,
        'features': ['Likes illimités', '5 super likes par jour', 'Voir qui vous a liké', 'Message prioritaire', 'Badge Gold', 'Profil mis en avant', 'Boost quotidien'],
        'isActive': true,
        'defaultLikes': -1,
        'defaultSuperLikes': 5,
        'createdAt': now,
        'updatedAt': now,
      },
    ];
    final batch = firestore.batch();
    for (var plan in plans) {
      final docRef = firestore.collection('subscription_plans').doc();
      batch.set(docRef, plan);
    }
    await batch.commit();
    print('✅ Plans d\'abonnement créés');
  }

  // ---------- Gestion de l'abonnement et réinitialisation quotidienne ----------
  Future<void> _loadUserSubscription() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await firestore
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      final nowDateTime = DateTime.now();
      final todayStart = DateTime(nowDateTime.year, nowDateTime.month, nowDateTime.day).millisecondsSinceEpoch;
      final nowMillis = nowDateTime.millisecondsSinceEpoch;

      if (snapshot.docs.isNotEmpty) {
        final subscription = snapshot.docs.first;
        _userSubscriptionDocId = subscription.id;
        _subscriptionPlan = subscription['planCode'];

        // Récupérer les limites du plan depuis subscription_plans
        final planSnapshot = await firestore
            .collection('subscription_plans')
            .where('code', isEqualTo: _subscriptionPlan)
            .limit(1)
            .get();

        int defaultLikes = 10, defaultSuperLikes = 1;
        if (planSnapshot.docs.isNotEmpty) {
          defaultLikes = planSnapshot.docs.first['defaultLikes'] ?? 10;
          defaultSuperLikes = planSnapshot.docs.first['defaultSuperLikes'] ?? 1;
        }

        // Vérifier la date de dernière réinitialisation
        final lastReset = subscription['lastResetDate'] as int? ?? 0;

        if (lastReset < todayStart) {
          _remainingLikes = defaultLikes;
          _remainingSuperLikes = defaultSuperLikes;
          await firestore
              .collection('user_dating_subscriptions')
              .doc(_userSubscriptionDocId)
              .update({
            'remainingLikes': _remainingLikes,
            'remainingSuperLikes': _remainingSuperLikes,
            'lastResetDate': todayStart,
            'updatedAt': nowMillis,
          });
          print('🔄 Réinitialisation quotidienne: likes=$_remainingLikes, super likes=$_remainingSuperLikes');
        } else {
          _remainingLikes = subscription['remainingLikes'] ?? defaultLikes;
          _remainingSuperLikes = subscription['remainingSuperLikes'] ?? defaultSuperLikes;
        }

        // Vérifier expiration (plans payants)
        final endAt = subscription['endAt'] as int?;
        if (endAt != null && endAt <= nowMillis) {
          await firestore
              .collection('user_dating_subscriptions')
              .doc(_userSubscriptionDocId)
              .update({'isActive': false});
          _subscriptionPlan = null;
          // Passer au plan gratuit
          final freePlan = await firestore
              .collection('subscription_plans')
              .where('code', isEqualTo: 'gratuit')
              .limit(1)
              .get();
          if (freePlan.docs.isNotEmpty) {
            _remainingLikes = freePlan.docs.first['defaultLikes'] ?? 10;
            _remainingSuperLikes = freePlan.docs.first['defaultSuperLikes'] ?? 1;
          } else {
            _remainingLikes = 10;
            _remainingSuperLikes = 1;
          }
          print('⚠️ Abonnement expiré, passage en gratuit');
        }
      } else {
        // Aucun abonnement -> mode gratuit
        final freePlan = await firestore
            .collection('subscription_plans')
            .where('code', isEqualTo: 'gratuit')
            .limit(1)
            .get();
        if (freePlan.docs.isNotEmpty) {
          _remainingLikes = freePlan.docs.first['defaultLikes'] ?? 10;
          _remainingSuperLikes = freePlan.docs.first['defaultSuperLikes'] ?? 1;
        } else {
          _remainingLikes = 10;
          _remainingSuperLikes = 1;
        }
        final newDocRef = firestore.collection('user_dating_subscriptions').doc();
        _userSubscriptionDocId = newDocRef.id;
        await newDocRef.set({
          'id': newDocRef.id,
          'userId': _currentUserId,
          'planCode': 'gratuit',
          'priceCoins': 0,
          'startAt': nowMillis,
          'endAt': nowMillis + (30 * 24 * 60 * 60 * 1000),
          'isActive': true,
          'remainingLikes': _remainingLikes,
          'remainingSuperLikes': _remainingSuperLikes,
          'lastResetDate': todayStart,
          'createdAt': nowMillis,
          'updatedAt': nowMillis,
        });
        print('💾 Nouveau document gratuit créé avec $_remainingLikes likes');
      }
      if (mounted) setState(() {});
    } catch (e) {
      print('❌ Erreur chargement abonnement: $e');
      _remainingLikes = 10;
      _remainingSuperLikes = 1;
    }
  }

  Future<void> _saveRemainingLikes() async {
    if (_currentUserId == null || _userSubscriptionDocId == null) return;
    try {
      await firestore
          .collection('user_dating_subscriptions')
          .doc(_userSubscriptionDocId)
          .update({
        'remainingLikes': _remainingLikes,
        'remainingSuperLikes': _remainingSuperLikes,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      print('💾 Likes sauvegardés: $_remainingLikes likes, $_remainingSuperLikes super likes');
    } catch (e) {
      print('❌ Erreur sauvegarde likes: $e');
    }
  }

  // ---------- Chargement du profil utilisateur et des profils à swiper ----------
  Future<void> _loadCurrentUserProfile() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DatingProfileSetupPage(profile: null)),
          );
        }
        return;
      }

      _currentUserProfile = DatingProfile.fromJson(snapshot.docs.first.data());

      if (_currentUserProfile!.isProfileComplete && _currentUserProfile!.completionPercentage == 100) {
        await _loadProfiles();
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DatingProfileSetupPage(profile: _currentUserProfile)),
          );
        }
      }
    } catch (e) {
      print('❌ Erreur chargement profil: $e');
    }
  }

  Future<void> _loadProfilesOld({bool isLoadMore = false}) async {
    if (_currentUserId == null || _currentUserProfile == null) return;
    if (isLoadMore && (_isLoadingMore || !_hasMore)) return;

    if (mounted) {
      setState(() {
        if (isLoadMore) _isLoadingMore = true;
        else _isLoading = true;
      });
    }

    try {
      // Construction de la requête – tri par popularité puis par ID (ordre unique)
      Query query = firestore
          .collection('dating_profiles')
          .where('isActive', isEqualTo: true)
          .orderBy('popularityScore', descending: true)
          .orderBy(FieldPath.documentId);

      if (isLoadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.limit(_batchSize).get();

      if (snapshot.docs.isEmpty) {
        if (_profiles.isEmpty) {
          // Plus de profils dans la base, on réinitialise pour recycler
          _hasMore = true;
          _lastDocument = null;
          await _loadProfiles();
        } else {
          _hasMore = false;
        }
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _lastDocument = snapshot.docs.last;

      List<DatingProfile> allProfiles = snapshot.docs
          .map((doc) => DatingProfile.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // On ne filtre pas les profils déjà likés ou bloqués
      // On exclut juste l'utilisateur lui-même (ne pas se voir soi-même)
      allProfiles = allProfiles.where((p) => p.userId != _currentUserId).toList();

      print('📊 ${allProfiles.length} profils après exclusion de soi-même');

      // Si on est en mode chargement supplémentaire et qu'on n'a aucun profil après exclusion,
      // on recharge immédiatement la page suivante
      if (isLoadMore && allProfiles.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) await _loadProfiles(isLoadMore: true);
        if (mounted) setState(() => _isLoadingMore = false);
        return;
      }

      if (allProfiles.isEmpty) {
        if (!isLoadMore && _profiles.isEmpty) {
          // Premier chargement sans résultat – on recharge
          await _loadProfiles();
        } else {
          _hasMore = false;
        }
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Trier par score pour séparer les groupes
      final sorted = List<DatingProfile>.from(allProfiles);
      sorted.sort((a, b) => b.popularityScore.compareTo(a.popularityScore));

      final total = sorted.length;
      final highCount = (total * 0.4).toInt();   // 40% meilleurs scores
      final midCount = (total * 0.3).toInt();    // 30% moyens
      final lowCount = total - highCount - midCount; // 30% moins populaires

      List<DatingProfile> high = sorted.take(highCount).toList();
      List<DatingProfile> mid = sorted.skip(highCount).take(midCount).toList();
      List<DatingProfile> low = sorted.skip(highCount + midCount).toList();

      high.shuffle();
      mid.shuffle();
      low.shuffle();

      // Mélange 5 populaires, 3 moyens, 2 moins populaires (répété)
      List<DatingProfile> mixed = [];
      int hi = 0, mi = 0, lo = 0;
      while (hi < high.length || mi < mid.length || lo < low.length) {
        for (int i = 0; i < 5 && hi < high.length; i++) mixed.add(high[hi++]);
        for (int i = 0; i < 3 && mi < mid.length; i++) mixed.add(mid[mi++]);
        for (int i = 0; i < 2 && lo < low.length; i++) mixed.add(low[lo++]);
      }

      if (isLoadMore) {
        _profiles.addAll(mixed);
        if (mounted) setState(() => _isLoadingMore = false);
      } else {
        _profiles = mixed;
        _currentIndex = 0;
        if (mounted) setState(() => _isLoading = false);
      }

      // Préchargement si besoin
      if (!isLoadMore && _profiles.length < 10 && _hasMore && mounted) {
        _loadMoreProfiles();
      }
    } catch (e) {
      print('❌ Erreur chargement profils: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }
  Future<void> _loadProfiles({bool isLoadMore = false}) async {
    if (_currentUserId == null || _currentUserProfile == null) return;
    if (isLoadMore && (_isLoadingMore || !_hasMore)) return;

    if (mounted) {
      setState(() {
        if (isLoadMore) _isLoadingMore = true;
        else _isLoading = true;
      });
    }

    try {
      print('Sexe de recherche : ${_currentUserProfile!.rechercheSexe}');

      // Construction de la requête de base
      Query query = firestore
          .collection('dating_profiles')
          .where('isActive', isEqualTo: true);

      // Filtre par sexe selon les préférences de l'utilisateur
      if (_currentUserProfile!.rechercheSexe != 'tous') {
        query = query.where('sexe', isEqualTo: _currentUserProfile!.rechercheSexe);
      }

      // query = query
      //     .orderBy('popularityScore', descending: true)
      //     .orderBy(FieldPath.documentId);

      if (isLoadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.limit(_batchSize).get();

      if (snapshot.docs.isEmpty) {
        if (_profiles.isEmpty) {
          _hasMore = true;
          _lastDocument = null;
          await _loadProfiles();
        } else {
          _hasMore = false;
        }
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _lastDocument = snapshot.docs.last;

      List<DatingProfile> allProfiles = snapshot.docs
          .map((doc) => DatingProfile.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      print('📊 ${allProfiles.length} profils avant');

      // Exclure l'utilisateur lui-même
      allProfiles = allProfiles.where((p) => p.userId != _currentUserId).toList();

      print('📊 ${allProfiles.length} profils après exclusion de soi-même');

      if (isLoadMore && allProfiles.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) await _loadProfiles(isLoadMore: true);
        if (mounted) setState(() => _isLoadingMore = false);
        return;
      }

      if (allProfiles.isEmpty) {
        if (!isLoadMore && _profiles.isEmpty) {
          await _loadProfiles();
        } else {
          _hasMore = false;
        }
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Trier par score pour séparer les groupes
      final sorted = List<DatingProfile>.from(allProfiles);
      sorted.sort((a, b) => b.popularityScore.compareTo(a.popularityScore));

      final total = sorted.length;
      final highCount = (total * 0.4).toInt();   // 40% meilleurs scores
      final midCount = (total * 0.3).toInt();    // 30% moyens
      final lowCount = total - highCount - midCount; // 30% moins populaires

      List<DatingProfile> high = sorted.take(highCount).toList();
      List<DatingProfile> mid = sorted.skip(highCount).take(midCount).toList();
      List<DatingProfile> low = sorted.skip(highCount + midCount).toList();

      high.shuffle();
      mid.shuffle();
      low.shuffle();

      // Mélange 5 populaires, 3 moyens, 2 moins populaires (répété)
      List<DatingProfile> mixed = [];
      int hi = 0, mi = 0, lo = 0;
      while (hi < high.length || mi < mid.length || lo < low.length) {
        for (int i = 0; i < 5 && hi < high.length; i++) mixed.add(high[hi++]);
        for (int i = 0; i < 3 && mi < mid.length; i++) mixed.add(mid[mi++]);
        for (int i = 0; i < 2 && lo < low.length; i++) mixed.add(low[lo++]);
      }

      if (isLoadMore) {
        _profiles.addAll(mixed);
        if (mounted) setState(() => _isLoadingMore = false);
      } else {
        _profiles = mixed;
        _currentIndex = 0;
        if (mounted) setState(() => _isLoading = false);
      }

      // Préchargement si besoin
      if (!isLoadMore && _profiles.length < 10 && _hasMore && mounted) {
        _loadMoreProfiles();
      }
    } catch (e) {
      print('❌ Erreur chargement profils: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }
  Future<void> _loadMoreProfiles() async {
    if (!_hasMore || _isLoadingMore) return;
    await _loadProfiles(isLoadMore: true);
  }

  void _checkAndLoadMore() {
    if (_profiles.length - _currentIndex <= 5 && _hasMore && !_isLoadingMore && mounted) {
      _loadMoreProfiles();
    }
  }

  void _nextProfile() {
    setState(() {
      _currentIndex++;
      _dragOffset = Offset.zero;
      _rotationAngle = 0.0;
      _opacity = 1.0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndLoadMore());
  }
  int _swipeCounter = 0; // Compteur pour suivre le nombre de swipes
  void _checkAndShowSwipeAd() {
    // 1. Définir le seuil selon le plan d'abonnement
    int nbrpost = 5; // Par défaut pour le mode gratuit
    bool isFreeUser = (_subscriptionPlan == 'gratuit' || _subscriptionPlan == null);
    bool isPlusUser = (_subscriptionPlan == 'plus');

    if (isFreeUser) {
      nbrpost = 5; // Pub tous les 5 swipes pour les gratuits
    } else if (isPlusUser) {
      nbrpost = 12; // Pub tous les 12 swipes pour le plan Plus
    } else {
      // Si l'utilisateur est Gold, on arrête tout ici (pas de pub)
      return;
    }

    // 2. Incrémenter le compteur à chaque swipe
    _swipeCounter++;

    // 3. Vérifier si le seuil est atteint
    if (_swipeCounter >= nbrpost) {
      print('📢 [AD] Seuil de $nbrpost swipes atteint pour le plan $_subscriptionPlan');

      _adKey.currentState?.showAd();
      _swipeCounter = 0;
    }
  }  // ---------- Actions de swipe ----------
  void _handleSwipeLeft() {
    if (_isSwiping || _currentIndex >= _profiles.length) return;
    _isSwiping = true;
    _checkAndShowSwipeAd();
    _nextProfile();
    Future.delayed(const Duration(milliseconds: 300), () => _isSwiping = false);
  }

  void _handleSwipeRight() {
    if (_isSwiping || _currentIndex >= _profiles.length) return;
    if (_remainingLikes != -1 && _remainingLikes <= 0) {
      _showUpgradeDialog(type: 'like');
      return;
    }
    _isSwiping = true;
    final profile = _profiles[_currentIndex];
    _likeCount++;
    _history.add(profile);
    _checkAndShowSwipeAd();

    _nextProfile();
    _processLike(profile);
    _checkAndLoadMore();
    if (_likeCount >= _likeCountThreshold) {
      _likeCount = 0;
      _showLikedProfilesPremiumDialog();
    }
    Future.delayed(const Duration(milliseconds: 300), () => _isSwiping = false);
  }

  void _handleSuperLike() {
    if (_isSwiping || _currentIndex >= _profiles.length) return;
    if (_remainingSuperLikes <= 0) {
      _showUpgradeDialog(type: 'superlike');
      return;
    }
    _isSwiping = true;
    final profile = _profiles[_currentIndex];
    _nextProfile();
    _processSuperLike(profile);
    _checkAndLoadMore();
    Future.delayed(const Duration(milliseconds: 300), () => _isSwiping = false);
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
        setState(() => _remainingLikes--);
        await _saveRemainingLikes();
      }

      // Incrémenter le compteur de likes du profil cible
      await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: profile.userId)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update({'likesCount': FieldValue.increment(1)});
        }
      });

      // Mettre à jour le score de popularité
      await _updatePopularityScore(profile.userId);

      // Vérifier s'il y a un like mutuel
      final mutualLike = await firestore
          .collection('dating_likes')
          .where('fromUserId', isEqualTo: profile.userId)
          .where('toUserId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (mutualLike.docs.isNotEmpty) {
        // Récupérer le profil de l'utilisateur courant pour vérifier la compatibilité
        final currentProfile = await _getCurrentUserDatingProfile();
        if (currentProfile == null) {
          print('Profil courant non trouvé');
          return;
        }

        // Vérifier la compatibilité des recherches
        final bool currentMatches = _isMatching(currentProfile, profile);
        final bool otherMatches = _isMatching(profile, currentProfile);

        if (currentMatches && otherMatches) {
          // Vérifier si une connexion existe déjà
          final existingConnection = await _checkExistingConnection(profile.userId);
          if (existingConnection != null) {
            // Connexion déjà existante
            _showSuccessMessage('💞 Vous êtes déjà en contact avec ${profile.pseudo}', Colors.orange);
            return;
          }

          // Créer la connexion
          final connection = await _getOrCreateConnection(profile.userId);
          if (connection != null) {
            await _sendNotification(
              toUserId: profile.userId,
              message: "Afrolove✨ Vous avez un nouveau match avec @${_getCurrentUserPseudo()} !",
              type: 'match',
            );
            _showMatchDialog(profile);
          }
        } else {
          // Incompatibilité de recherche
          _showSuccessMessage(
            '💔 ${profile.pseudo} ne correspond pas à vos critères de recherche',
            Colors.orange,
          );
        }
      } else {
        await _sendNotification(
          toUserId: profile.userId,
          message: "Afrolove❤️ @${_getCurrentUserPseudo()} vous a liké !",
          type: 'like',
        );
        _showSuccessMessage('Vous avez liké ${profile.pseudo}', Colors.green);
      }
    } catch (e) {
      print('❌ Erreur like: $e');
    }
  }

  /// Récupère le profil dating de l'utilisateur courant
  Future<DatingProfile?> _getCurrentUserDatingProfile() async {
    try {
      final snapshot = await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: _currentUserId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return DatingProfile.fromJson(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('❌ Erreur récupération profil courant: $e');
      return null;
    }
  }

  /// Vérifie si le profil 'user' correspond aux critères de recherche de 'target'
  bool _isMatching(DatingProfile user, DatingProfile target) {
    final rechercheSexe = user.rechercheSexe;
    final sexeCible = target.sexe;
    // rechercheSexe peut être 'homme', 'femme', ou 'tous'
    if (rechercheSexe == 'tous') return true;
    if (rechercheSexe == sexeCible) return true;
    return false;
  }

  /// Vérifie si une connexion existe déjà entre l'utilisateur courant et l'autre
  Future<DatingConnection?> _checkExistingConnection(String otherUserId) async {
    try {
      final snapshot = await firestore
          .collection('dating_connections')
          .where('userId1', isEqualTo: _currentUserId)
          .where('userId2', isEqualTo: otherUserId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return DatingConnection.fromJson(snapshot.docs.first.data());

      final snapshot2 = await firestore
          .collection('dating_connections')
          .where('userId1', isEqualTo: otherUserId)
          .where('userId2', isEqualTo: _currentUserId)
          .limit(1)
          .get();
      if (snapshot2.docs.isNotEmpty) return DatingConnection.fromJson(snapshot2.docs.first.data());

      return null;
    } catch (e) {
      print('❌ Erreur vérification connexion: $e');
      return null;
    }
  }

// Modification de _getOrCreateConnection pour ne plus créer de connexion si elle existe déjà
  Future<DatingConnection?> _getOrCreateConnection(String otherUserId) async {
    if (_currentUserId == null) return null;
    try {
      // Vérifier d'abord si une connexion existe déjà
      final existing = await _checkExistingConnection(otherUserId);
      if (existing != null) return existing;

      final now = DateTime.now().millisecondsSinceEpoch;
      final connectionId = firestore.collection('dating_connections').doc().id;
      final connection = DatingConnection(
        id: connectionId,
        userId1: _currentUserId!,
        userId2: otherUserId,
        createdAt: now,
        isActive: true,
      );
      await firestore.collection('dating_connections').doc(connectionId).set(connection.toJson());
      return connection;
    } catch (e) {
      print('❌ Erreur création connexion: $e');
      return null;
    }
  }
  Future<void> _processSuperLike(DatingProfile profile) async {
    if (_currentUserId == null) return;

    // 1. Vérifier la compatibilité des genres
    final isCompatible = await _checkMatchCompatibility(profile);
    if (!isCompatible) return;

    // 2. Vérifier si un match existe déjà
    final alreadyMatched = await _matchAlreadyExists(profile.userId);
    if (alreadyMatched) {
      _showSuccessMessage('Vous êtes déjà en contact avec ${profile.pseudo}', Colors.orange);
      return;
    }

    const superLikePrice = 20;

    // 3. S'il reste des super likes gratuits
    if (_remainingSuperLikes > 0) {
      await _sendSuperLike(profile, useCoins: false);
      return;
    }

    // 4. Sinon, proposition d'achat avec pièces
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;

    if (currentCoins < superLikePrice) {
      _showInsufficientCoinsDialog();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('✨ Coup de cœur payant ✨'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 50, color: Colors.amber),
            const SizedBox(height: 16),
            const Text('Vous n\'avez plus de coups de cœur gratuits aujourd\'hui.'),
            const SizedBox(height: 8),
            Text(
              'Envoyer un coup de cœur coûte $superLikePrice pièces.',
              style: const TextStyle(color: Colors.amber),
            ),
            const SizedBox(height: 8),
            Text('Votre solde : $currentCoins pièces', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Acheter et envoyer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _sendSuperLike(profile, useCoins: true, priceCoins: superLikePrice);
  }
  Future<void> _sendSuperLike(DatingProfile profile, {required bool useCoins, int priceCoins = 0}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      if (useCoins) {
        // Déduire les pièces
        await firestore.collection('Users').doc(_currentUserId).update({
          'coinsBalance': FieldValue.increment(-priceCoins),
          'totalCoinsSpent': FieldValue.increment(priceCoins),
        });
        // Ne pas modifier _remainingSuperLikes (achat exceptionnel)
      } else {
        // Utiliser un super like gratuit
        setState(() => _remainingSuperLikes--);
        await _saveRemainingLikes();
      }

      final coupId = firestore.collection('dating_coup_de_coeurs').doc().id;
      await firestore.collection('dating_coup_de_coeurs').doc(coupId).set({
        'id': coupId,
        'fromUserId': _currentUserId,
        'toUserId': profile.userId,
        'createdAt': now,
      });

      // Incrémenter le compteur de coups de cœur du profil cible
      await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: profile.userId)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update({'coupsDeCoeurCount': FieldValue.increment(1)});
        }
      });

      // Mettre à jour le score de popularité
      await _updatePopularityScore(profile.userId);

      // Envoyer la notification
      await _sendNotification(
        toUserId: profile.userId,
        message: "Afrolove⭐ @${_getCurrentUserPseudo()} vous a envoyé un super like !",
        type: 'super_like',
      );

      _showSuccessMessage('✨ Super like envoyé à ${profile.pseudo}', Colors.amber);
    } catch (e) {
      print('❌ Erreur super like: $e');
      _showSuccessMessage('Erreur lors de l\'envoi', Colors.red);
    }
  }

  Future<bool> _checkMatchCompatibility(DatingProfile targetProfile) async {
    if (_currentUserProfile == null) return false;
    // Check if current user's search preferences match target's gender
    bool currentAcceptsTarget = _currentUserProfile!.rechercheSexe.toLowerCase() == 'tous' ||
        _currentUserProfile!.rechercheSexe.toLowerCase() == targetProfile.sexe.toLowerCase();
    // Check if target's search preferences match current user's gender
    bool targetAcceptsCurrent = targetProfile.rechercheSexe == 'tous' ||
        targetProfile.rechercheSexe.toLowerCase() == _currentUserProfile!.sexe.toLowerCase();
    if (!currentAcceptsTarget) {
      _showSuccessMessage('Vous ne recherchez pas ce genre de personnes.', Colors.orange);
      return false;
    }
    if (!targetAcceptsCurrent) {
      _showSuccessMessage('Cette personne ne recherche pas votre genre.', Colors.orange);
      return false;
    }
    return true;
  }

  Future<bool> _matchAlreadyExists(String otherUserId) async {
    if (_currentUserId == null) return false;
    final snapshot = await firestore
        .collection('dating_connections')
        .where('userId1', isEqualTo: _currentUserId)
        .where('userId2', isEqualTo: otherUserId)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) return true;
    final snapshot2 = await firestore
        .collection('dating_connections')
        .where('userId1', isEqualTo: otherUserId)
        .where('userId2', isEqualTo: _currentUserId)
        .limit(1)
        .get();
    return snapshot2.docs.isNotEmpty;
  }
  Future<void> _updatePopularityScore(String userId) async {
    try {
      final likes = await firestore.collection('dating_likes').where('toUserId', isEqualTo: userId).count().get();
      final coups = await firestore.collection('dating_coup_de_coeurs').where('toUserId', isEqualTo: userId).count().get();
      final conn = await firestore.collection('dating_connections').where('userId1', isEqualTo: userId).count().get();
      final score = (likes.count! * 1) + (coups.count! * 2) + (conn.count! * 3);
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
    await _updatePopularityScore(_currentUserId!);
    await _updatePopularityScore(otherUserId);
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
      'media_url': _currentUserProfile?.imageUrl ?? '',
      'type': 'DATING_${type.toUpperCase()}',
      'description': message,
      'users_id_view': [],
      'user_id': _currentUserId,
      'receiver_id': toUserId,
      'createdAt': now,
      'updatedAt': now,
      'is_open': false,
      'status': 'VALIDE',
    });

    final toUserDoc = await firestore.collection('Users').doc(toUserId).get();
    final toUser = UserData.fromJson(toUserDoc.data() ?? {});
    if (toUser.oneIgnalUserid != null && toUser.oneIgnalUserid!.isNotEmpty) {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      await authProvider.sendNotification(
        userIds: [toUser.oneIgnalUserid!],
        smallImage: _currentUserProfile?.imageUrl ?? '',
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
    return doc.exists ? UserData.fromJson(doc.data() as Map<String, dynamic>) : null;
  }


  String _getCurrentUserPseudo() {
    return _currentUserProfile?.pseudo ?? 'Utilisateur';
  }
  void _showSuccessMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 20), const SizedBox(width: 12), Expanded(child: Text(message))]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showNoProfilesAvailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [Icon(Icons.info_outline, color: Colors.white, size: 20), SizedBox(width: 12), Expanded(child: Text('Aucun profil disponible pour le moment. Revenez plus tard !'))]),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showUpgradeDialog({required String type}) {
    // type = 'like' ou 'superlike'
    final isLike = type == 'like';
    final planGratuit = _subscriptionPlan == 'gratuit';
    final planPlus = _subscriptionPlan == 'plus';

    int bonusLikes = 0;
    int bonusSuperLikes = 0;
    if (isLike) {
      bonusLikes = planGratuit ? 5 : (planPlus ? 10 : 0);
    } else {
      bonusSuperLikes = planGratuit ? 1 : (planPlus ? 2 : 0);
    }

    final bonusText = isLike ? '+$bonusLikes likes' : '+$bonusSuperLikes super like(s)';

    showDialog(
      context: context,
      barrierDismissible: false, // Empêche la fermeture pendant le chargement
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isLike ? 'Limite de likes atteinte' : 'Plus de super likes',
              style: TextStyle(color: isLike ? Colors.red : Colors.amber),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoadingAd)
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Chargement de la publicité...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Icon(isLike ? Icons.favorite : Icons.star, size: 50, color: isLike ? Colors.red : Colors.amber),
                  const SizedBox(height: 16),
                  Text(
                    isLike
                        ? 'Vous avez utilisé tous vos likes gratuits du jour.'
                        : 'Vous n’avez plus de super likes gratuits aujourd’hui.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Column(
                      children: [
                        const Text('⚡ Solutions :', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (bonusLikes > 0 || bonusSuperLikes > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '🎁 Regardez une publicité pour obtenir $bonusText immédiatement !',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                            ),
                          ),
                        const Text(
                          '✨ Ou passez à AfroLove Gold pour des likes illimités et des super likes quotidiens.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (!_isLoadingAd) ...[
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Plus tard'),
                ),
                if (bonusLikes > 0 || bonusSuperLikes > 0)
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Afficher le chargement
                      setDialogState(() {
                        _isLoadingAd = true;
                      });

                      // Attendre que le widget de pub soit monté et prêt
                      await Future.delayed(Duration(milliseconds: 100));

                      // Fermer le dialogue
                      Navigator.pop(context);

                      // Lancer la pub avec attente de chargement
                      _pendingRewardType = isLike ? 'likes' : 'superlikes';
                      setState(() {
                        _showRewardedAd = true;
                      });

                      // Attendre que la pub soit prête
                      bool isReady = false;
                      int attempts = 0;
                      while (!isReady && attempts < 30) {
                        await Future.delayed(Duration(milliseconds: 100));
                        if (_rewardedAdKey.currentState != null) {
                          isReady = await _rewardedAdKey.currentState!.isAdReady();
                        }
                        attempts++;
                      }

                      if (isReady) {
                        _rewardedAdKey.currentState!.showAd();
                      } else {
                        setState(() {
                          _showRewardedAd = false;
                          _isLoadingAd = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Publicité non disponible, réessayez'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    icon: const Icon(Icons.play_circle_filled),
                    label: Text('REGARDER LA PUB ($bonusText)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DatingSubscriptionPage()));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('VOIR LES OFFRES', style: TextStyle(color: Colors.white)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Solde insuffisant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Vous n\'avez pas assez de pièces pour envoyer un super like.', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('20 pièces requis', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => BuyCoinsPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Acheter des pièces'),
          ),
        ],
      ),
    );
  }

  void _showMatchDialog(DatingProfile profile) {
    final isGold = _subscriptionPlan == 'gold';
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.red.shade400, Colors.pink.shade400]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text('C\'est un match ! 🎉', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
              const SizedBox(height: 8),
              Text('Vous et ${profile.pseudo} vous êtes likés mutuellement.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Continuer'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openChat(profile);

                        // if (isGold) {
                        //   _openChat(profile);
                        // } else {
                        //   _showPremiumChatDialog(profile);
                        // }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text( 'Discuter en privé'),
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

  void _openChat(DatingProfile profile) async {
    final connection = await _getOrCreateConnection(profile.userId);
    if (connection != null && mounted) {

      if (_subscriptionPlan == 'gratuit') {
        _adKey.currentState?.showAd(); // On lance la pub pour les gratuits
      }
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (_) => DatingChatPage(
      //       connectionId: connection.id,
      //       otherUserId: profile.userId,
      //       otherUserName: profile.pseudo,
      //       otherUserImage: profile.imageUrl,
      //     ),
      //   ),
      // );
    }
  }


  void _showPremiumChatDialog(DatingProfile profile) {
    final isGold = _subscriptionPlan == 'gold';
    if (!isGold) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Discuter en privé', style: TextStyle(color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 50, color: Colors.amber),
              const SizedBox(height: 16),
              const Text('La messagerie privée est réservée aux membres AfroLove Gold.', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Passez à l\'abonnement Premium Gold pour discuter avec vos matchs !', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Plus tard')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => DatingSubscriptionPage()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text('Voir les offres'),
            ),
          ],
        ),
      );
      return;
    }
    _openChat(profile);
  }

  void _showLikedProfilesPremiumDialog() {
    final isPremium = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Colors.white,
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPremium ? [Colors.red.shade400, Colors.pink.shade400] : [Colors.grey.shade300, Colors.grey.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(isPremium ? Icons.favorite : Icons.lock, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                isPremium ? '❤️ ${_history.length} profils likés !' : '❤️ ${_history.length} profils likés',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isPremium ? Colors.red.shade700 : Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Text(
                isPremium ? 'Découvrez tous les profils que vous avez likés' : 'Voir les profils que vous avez likés est réservé aux membres AfroLove Plus et Gold.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: isPremium ? Colors.grey.shade600 : Colors.grey.shade500),
              ),
              const SizedBox(height: 20),
              if (isPremium) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DatingLikesListPage()));
                  },
                  icon: const Icon(Icons.visibility, size: 18, color: Colors.white),
                  label: Text('Voir mes ${_history.length} likes', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child:  Text('Continuer à swiper', style: TextStyle(color: Colors.grey.shade600)),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DatingSubscriptionPage()));
                  },
                  icon: const Icon(Icons.star, size: 18, color: Colors.black),
                  label: const Text('Débloquer Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child:  Text('Continuer à swiper', style: TextStyle(color: Colors.grey.shade600)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------- UI ----------
  void _onPanUpdate(DragUpdateDetails details) {
    if (_isSwiping) return;
    final newOffset = _dragOffset + details.delta;
    setState(() {
      _dragOffset = newOffset;
      _rotationAngle = _dragOffset.dx / 500;
      _opacity = 1.0 - (_dragOffset.dx.abs() / 500).clamp(0.0, 1.0);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isSwiping) {
      setState(() {
        _dragOffset = Offset.zero;
        _rotationAngle = 0.0;
        _opacity = 1.0;
      });
      return;
    }
    if (_dragOffset.dx.abs() > 100) {
      if (_dragOffset.dx > 0) _handleSwipeRight();
      else _handleSwipeLeft();
    }
    setState(() {
      _dragOffset = Offset.zero;
      _rotationAngle = 0.0;
      _opacity = 1.0;
    });
  }

  void _toggleFilters() => setState(() => _showFilters = !_showFilters);

  void _applyFilters() {
    _loadProfiles();
    setState(() => _showFilters = false);
  }

  // Navigation bottom
  void _goToCreatorsPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DatingCreatorPostsPage()));
  }

  void _goToMyProfile() {
    if (_currentUserProfile != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DatingProfileDetailPage(profile: _currentUserProfile!)));
    }
  }

  void _goToNotifications() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DatingNotificationsPage()));
  }
  void _showGoldIncentiveMessage() {
    // On nettoie les anciens messages pour éviter les superpositions
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8), // Durée étendue à 8 secondes
        backgroundColor: Colors.black.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: Colors.amber, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        content: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Afrolove Gold ✨",
                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    "Vous ne profitez pas encore des avantages Gold. Passez au plan Gold pour supprimer les publicités !",
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Bouton pour fermer manuellement le message
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ],
        ),
        action: SnackBarAction(
          label: "VOIR L'OFFRE",
          textColor: Colors.amber,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DatingSubscriptionPage()),
            );
          },
        ),
      ),
    );
  }  @override
  Widget build(BuildContext context) {
    final hasSubscription = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');
    final showEmptyState = _profiles.isEmpty && !_isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.favorite, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            const Text('AfroLove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(_remainingLikes == -1 ? '∞' : '$_remainingLikes', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Icon(Icons.star, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text('$_remainingSuperLikes', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _toggleFilters,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  const Text('Filtres', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (showEmptyState)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                   Text('Chargement des profils...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                   Text('Veuillez patienter', style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            )
          else if (_profiles.isEmpty || _currentIndex >= _profiles.length)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                     Text('Plus de profils pour le moment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                     Text('Revenez plus tard', style: TextStyle(color: Colors.grey.shade500)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        _hasMore = true;
                        _lastDocument = null;
                        _profiles = [];
                        _currentIndex = 0;
                        await _loadProfiles();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Actualiser'),
                    ),
                  ],
                ),
              )
            else
              Stack(
                children: [
                  if (_currentIndex + 1 < _profiles.length)
                    _buildProfileCard(_profiles[_currentIndex + 1], isNext: true),
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
                                builder: (_) => DatingProfileDetailPage(profile: _profiles[_currentIndex]),
                              ),
                            );
                          },
                          child: _buildProfileCard(_profiles[_currentIndex], isNext: false),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

          Positioned(
            top: 12,
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              opacity: _showMessage ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _motivationalMessages[_currentMessageIndex]['color'].withOpacity(0.85),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_motivationalMessages[_currentMessageIndex]['icon'], color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _motivationalMessages[_currentMessageIndex]['text'],
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_showFilters)
            Positioned(
              top: 60,
              left: 20,
              right: 20,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Filtres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedGenderFilter,
                        decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'tous', child: Text('Tous')),
                          DropdownMenuItem(value: 'femme', child: Text('Femmes')),
                          DropdownMenuItem(value: 'homme', child: Text('Hommes')),
                        ],
                        onChanged: (value) => setState(() => _selectedGenderFilter = value!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedPopularityFilter,
                        decoration: const InputDecoration(labelText: 'Popularité', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'tous', child: Text('Tous')),
                          DropdownMenuItem(value: 'populaire', child: Text('Les plus populaires')),
                          DropdownMenuItem(value: 'moins_populaire', child: Text('Moins populaires')),
                        ],
                        onChanged: (value) => setState(() => _selectedPopularityFilter = value!),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Âge min', border: OutlineInputBorder()),
                              onChanged: (value) => _minAge = int.tryParse(value) ?? 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Âge max', border: OutlineInputBorder()),
                              onChanged: (value) => _maxAge = int.tryParse(value) ?? 99,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _showFilters = false),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _applyFilters,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Appliquer'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_isLoadingMore)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: 8),
                      const Text('Chargement de nouveaux profils...', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          if (_dragOffset.dx != 0)
            Positioned(
              top: 100,
              left: _dragOffset.dx > 0 ? 40 : null,
              right: _dragOffset.dx < 0 ? 40 : null,
              child: Transform.rotate(
                angle: _dragOffset.dx > 0 ? -0.3 : 0.3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _dragOffset.dx > 0 ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    _dragOffset.dx > 0 ? 'LIKE' : 'PASS',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),


          if (_showRewardedAd)
            RewardedAdWidget(
              key: _rewardedAdKey,
              onUserEarnedReward: (reward) {
                if (_pendingRewardType == 'likes') {
                  int bonus = (_subscriptionPlan == 'gratuit') ? 5 : 10;
                  _addBonusLikes(bonus);
                } else if (_pendingRewardType == 'superlikes') {
                  int bonus = (_subscriptionPlan == 'gratuit') ? 1 : 2;
                  _addBonusSuperLikes(bonus);
                }
                setState(() {
                  _showRewardedAd = false;
                  _pendingRewardType = null;
                  _isLoadingAd = false;
                });
              },
              onAdDismissed: () {
                setState(() {
                  _showRewardedAd = false;
                  _pendingRewardType = null;
                  _isLoadingAd = false;
                });
              },
              child: const SizedBox.shrink(),
            ),

          InterstitialAdWidget(
            key: _adKey,
            onAdDismissed: () {
              // Action après la pub (ex: retour à l'accueil)
              // _nextProfile();

              if((_subscriptionPlan != 'gold')){
                _showGoldIncentiveMessage();
              }


            },
          ),
          // Le widget AD invisible
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
          // Les trois boutons d'action (croix, étoile, cœur)
          Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
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
        // Bottom navigation bar (Rencontres, Créateurs, Profil)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBottomNavItem(
              icon: Icons.favorite,
              label: 'Rencontres',
              isSelected: true,
              onTap: () {},
            ),
            _buildBottomNavItem(
              icon: Icons.explore,
              label: 'Explorer',
              isSelected: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DatingExplorePage()),
                );
              },
            ),
            // _buildBottomNavItem(
            //   icon: Icons.people,
            //   label: 'Créateurs',
            //   isSelected: false,
            //   onTap: _goToCreatorsPage,
            // ),
            Stack(
              children: [
                _buildBottomNavItem(
                  icon: Icons.person,
                  label: 'Profil',
                  isSelected: false,
                  onTap: _goToMyProfile,
                ),
                if (_unreadNotificationsCount > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        _unreadNotificationsCount > 99 ? '99+' : '$_unreadNotificationsCount',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        ]
      ),
    ),
    ),

    );
  }

  Widget _buildBottomNavItem({required IconData icon, required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: isSelected ? Colors.red : Colors.grey),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.red : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onPressed, double size = 28}) {
    final isDisabled = (icon == Icons.favorite && _remainingLikes == 0 && _subscriptionPlan != 'gold') ||
        (icon == Icons.star && _remainingSuperLikes == 0 && _subscriptionPlan != 'gold');
    return GestureDetector(
      onTap: isDisabled ? null : onPressed,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Icon(icon, size: size, color: Colors.white),
      ),
    );
  }

  Widget _buildProfileCard(DatingProfile profile, {required bool isNext}) {
    final hasSubscription = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');
    final randomIndex = (profile.userId.hashCode + _currentIndex) % profile.photosUrls.length;
    final displayImageUrl = profile.photosUrls.isNotEmpty ? profile.photosUrls[randomIndex] : profile.imageUrl;

    return Container(
      margin: const EdgeInsets.all(16),
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
                displayImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
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
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      if (profile.isVerified)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(Icons.verified, size: 20, color: Colors.blue),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text('${profile.ville}, ${profile.pays}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.bio.length > 100 ? '${profile.bio.substring(0, 100)}...' : profile.bio,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!profile.isProfileComplete) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                      child: const Text('Profil incomplet', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: profile.centresInteret.take(3).map((interet) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                        child: Text(interet, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _showPremiumChatDialog(profile),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          const SizedBox(width: 8),
                          Text(
                            hasSubscription ? 'Discuter en privé' : 'Discuter en privé (Premium)',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
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
}