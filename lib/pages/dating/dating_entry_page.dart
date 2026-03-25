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
import 'dating_likes_list_page.dart';
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
  int _likeCount = 0;
  int _likeCountThreshold = 3;

  // Cache pour les IDs likés et bloqués
  Set<String> _likedUserIds = {};
  Set<String> _blockedUserIds = {};
  bool _initialLoadDone = false;

  // Pour le mélange des profils
  bool _useRecyclingMode = false;

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
  String? _userSubscriptionDocId;

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
    {'text': '💬 Discutez en privé avec AfroLove Plus 💬', 'icon': Icons.chat, 'color': Colors.blue},
    {'text': '🔥 Des profils populaires vous attendent ! Swipez ! 🔥', 'icon': Icons.whatshot, 'color': Colors.orange},
  ];

  int _currentMessageIndex = 0;
  Timer? _messageTimer;
  bool _showMessage = true;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  static const int _batchSize = 10;
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _startMessageTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      _currentUserId = authProvider.loginUserData.id;
      _listenUnreadNotifications();
      _loadUserSubscription();
      _loadCurrentUserProfile();
    });
  }
  StreamSubscription? _notifSub;

  void _listenUnreadNotifications() {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    _notifSub = FirebaseFirestore.instance
        .collection('Notifications')
        .where('receiver_id', isEqualTo: currentUserId)
        .where('type', isGreaterThanOrEqualTo: 'DATING_')
        .where('is_open', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _unreadNotificationsCount = snapshot.docs.length;
      });
    }, onError: (e) {
      print('❌ Erreur notifications temps réel: $e');
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

  Future<void> _loadUserSubscription() async {
    if (_currentUserId == null) return;

    try {
      print('📱 Chargement abonnement utilisateur: $_currentUserId');

      final snapshot = await firestore
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final subscription = snapshot.docs.first;
        _userSubscriptionDocId = subscription.id;
        _subscriptionPlan = subscription['planCode'];

        _remainingLikes = subscription['remainingLikes'] ?? 10;
        _remainingSuperLikes = subscription['remainingSuperLikes'] ?? 1;

        print('📊 Abonnement: $_subscriptionPlan, Likes restants: $_remainingLikes, Super likes: $_remainingSuperLikes');

        final endAt = subscription['endAt'] as int?;
        if (endAt != null && endAt <= DateTime.now().millisecondsSinceEpoch) {
          await firestore.collection('user_dating_subscriptions').doc(_userSubscriptionDocId).update({
            'isActive': false,
          });
          _subscriptionPlan = null;
          _remainingLikes = 10;
          _remainingSuperLikes = 1;
          print('⚠️ Abonnement expiré, passage en gratuit');
        }
      } else {
        print('📊 Aucun abonnement, mode gratuit');
        _remainingLikes = 10;
        _remainingSuperLikes = 1;
      }
      setState(() {});
    } catch (e) {
      print('❌ Erreur chargement abonnement: $e');
      _remainingLikes = 10;
      _remainingSuperLikes = 1;
    }
  }

  Future<void> _saveRemainingLikes() async {
    if (_currentUserId == null) return;

    try {
      if (_userSubscriptionDocId != null) {
        await firestore
            .collection('user_dating_subscriptions')
            .doc(_userSubscriptionDocId)
            .update({
          'remainingLikes': _remainingLikes,
          'remainingSuperLikes': _remainingSuperLikes,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
        print('💾 Likes sauvegardés: $_remainingLikes likes, $_remainingSuperLikes super likes');
      } else {
        final now = DateTime.now().millisecondsSinceEpoch;
        final newDocRef = firestore.collection('user_dating_subscriptions').doc();
        _userSubscriptionDocId = newDocRef.id;

        await newDocRef.set({
          'id': newDocRef.id,
          'userId': _currentUserId,
          'planCode': 'gratuit',
          'priceCoins': 0,
          'startAt': now,
          'endAt': now + (30 * 24 * 60 * 60 * 1000),
          'isActive': true,
          'remainingLikes': _remainingLikes,
          'remainingSuperLikes': _remainingSuperLikes,
          'createdAt': now,
          'updatedAt': now,
        });
        print('💾 Nouveau document gratuit créé avec $_remainingLikes likes');
      }
    } catch (e) {
      print('❌ Erreur sauvegarde likes: $e');
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    if (_currentUserId == null) return;

    try {
      print('📱 Chargement profil utilisateur: $_currentUserId');
      final snapshot = await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('🚀 Redirection vers création de profil');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DatingProfileSetupPage(profile: null)),
        );
        return;
      }

      _currentUserProfile = DatingProfile.fromJson(snapshot.docs.first.data());
      print('✅ Profil chargé: ${_currentUserProfile!.pseudo}');

      if (_currentUserProfile!.isProfileComplete&&_currentUserProfile!.completionPercentage==100) {


        await _loadProfiles();

      }else{
        print('⚠️ Profil incomplet, redirection vers mise à jour');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DatingProfileSetupPage(profile: _currentUserProfile)),
        );
      }

    } catch (e) {
      print('❌ Erreur chargement profil: $e');
    }
  }

  Future<void> _loadLikedUserIds() async {
    print('📥 Chargement des IDs likés...');
    final snapshot = await firestore
        .collection('dating_likes')
        .where('fromUserId', isEqualTo: _currentUserId)
        .get();
    _likedUserIds = snapshot.docs.map((doc) => doc['toUserId'] as String).toSet();
    print('📊 ${_likedUserIds.length} profils likés');
  }

  Future<void> _loadBlockedUserIds() async {
    print('📥 Chargement des IDs bloqués...');
    final snapshot = await firestore
        .collection('dating_blocks')
        .where('blockerUserId', isEqualTo: _currentUserId)
        .get();
    _blockedUserIds = snapshot.docs.map((doc) => doc['blockedUserId'] as String).toSet();
    print('📊 ${_blockedUserIds.length} profils bloqués');
  }
  void _showNoProfilesAvailable() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });

      // Afficher un message à l'utilisateur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Aucun profil disponible pour le moment. Revenez plus tard !',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }


  // Ajoute cette fonction dans votre classe _DatingSwipePageState
  Future<void> _migratePopularityScore() async {
    print('🔄 === MIGRATION DES SCORES DE POPULARITÉ ===');

    try {
      // Récupérer tous les profils
      final snapshot = await firestore
          .collection('dating_profiles')
          .get();

      print('📊 Nombre de profils à migrer: ${snapshot.docs.length}');

      int updatedCount = 0;
      int errorCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final userId = doc.data()['userId'] as String;

          // Récupérer les compteurs
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

          // Calculer le score
          final score = (likesCount.count! * 1) + (coupsCount.count! * 2) + (connectionsCount.count! * 3);

          // Mettre à jour le profil
          await doc.reference.update({
            'popularityScore': score,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

          updatedCount++;
          print('✅ ${doc.data()['pseudo']} (${doc.id}) - Score: $score (likes: ${likesCount.count}, coups: ${coupsCount.count}, connexions: ${connectionsCount.count})');

        } catch (e) {
          errorCount++;
          print('❌ Erreur pour le profil ${doc.id}: $e');
        }
      }

      print('✅ === MIGRATION TERMINÉE ===');
      print('📊 Profils mis à jour: $updatedCount');
      print('❌ Erreurs: $errorCount');

    } catch (e) {
      print('❌ Erreur lors de la migration: $e');
    }
  }

  Future<void> _loadProfiles({bool isLoadMore = false}) async {
    if (_currentUserId == null || _currentUserProfile == null) return;
    if (isLoadMore && (_isLoadingMore || !_hasMore)) return;

    print('📱 _loadProfiles - isLoadMore: $isLoadMore');
    print('📊 Profils actuels: ${_profiles.length}, Index: $_currentIndex');
    print('🎯 Mode recyclage: $_useRecyclingMode');

    setState(() {
      if (isLoadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      if (!_initialLoadDone) {
        await Future.wait([
          _loadLikedUserIds(),
          _loadBlockedUserIds(),
        ]);
        _initialLoadDone = true;
        print('✅ Cache chargé: ${_likedUserIds.length} likes, ${_blockedUserIds.length} blocages');
      }

      // // 🔧 CORRECTION: D'abord, vérifier si des profils existent sans le champ popularityScore
      // // Si oui, lancer la migration
      // final checkSnapshot = await firestore
      //     .collection('dating_profiles')
      //     .limit(1)
      //     .get();
      //
      // if (checkSnapshot.docs.isNotEmpty) {
      //   final firstProfile = checkSnapshot.docs.first.data();
      //   if (!firstProfile.containsKey('popularityScore')) {
      //     print('⚠️ Des profils n\'ont pas le champ popularityScore, lancement de la migration...');
      //     await _migratePopularityScore();
      //   }
      // }

      // Construire la requête avec orderBy
      Query query = firestore
          .collection('dating_profiles')
          .where('isActive', isEqualTo: true);

      // 🔧 CORRECTION: Utiliser orderBy seulement si on a des profils
      // Sinon, on fait une requête sans orderBy
      final countSnapshot = await firestore
          .collection('dating_profiles')
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      if (countSnapshot.count == 0) {
        print('⚠️ Aucun profil actif trouvé');
        setState(() => _isLoading = false);
        _showNoProfilesAvailable();
        return;
      }

      print('📊 Total profils actifs: ${countSnapshot.count}');

      // 🔀 DÉCIDER L'ORDRE ALÉATOIREMENT AU PREMIER CHARGEMENT
      final bool startWithPopular = DateTime.now().millisecondsSinceEpoch % 2 == 0;

      // Appliquer l'ordre selon le mode
      if (_useRecyclingMode) {
        print('🔄 Mode recyclage - Chargement des moins populaires d\'abord');
        query = query.orderBy('popularityScore', descending: false)
            .orderBy('createdAt', descending: true);
      } else if (startWithPopular && !isLoadMore) {
        print('🌟 Mode aléatoire - Commencer par les plus populaires');
        query = query.orderBy('popularityScore', descending: true)
            .orderBy('createdAt', descending: true);
      } else if (!isLoadMore) {
        print('🔄 Mode aléatoire - Commencer par les moins populaires');
        query = query.orderBy('popularityScore', descending: false)
            .orderBy('createdAt', descending: true);
      } else {
        // Chargement supplémentaire : continuer dans le même ordre
        if (_useRecyclingMode) {
          query = query.orderBy('popularityScore', descending: false)
              .orderBy('createdAt', descending: true);
        } else {
          query = query.orderBy('popularityScore', descending: true)
              .orderBy('createdAt', descending: true);
        }
      }

      // Pagination
      if (isLoadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
        print('📄 Pagination après: ${_lastDocument!.id}');
      }

      int batchSize = _batchSize * 2;
      if (_profiles.isEmpty && !isLoadMore) {
        batchSize = _batchSize * 3;
      }

      final snapshot = await query.limit(batchSize).get();
      print('📊 Profils bruts trouvés: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('⚠️ Aucun profil trouvé');
        if (_profiles.isEmpty) {
          setState(() => _isLoading = false);
          _showNoProfilesAvailable();
        } else {
          _hasMore = false;
          setState(() => _isLoading = false);
        }
        return;
      }

      _lastDocument = snapshot.docs.last;
      print('📌 _lastDocument mis à jour: ${_lastDocument!.id}');

      List<DatingProfile> allProfiles = snapshot.docs
          .map((doc) => DatingProfile.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Filtrer l'utilisateur courant, les likés et les bloqués
      final beforeFilter = allProfiles.length;
      allProfiles = allProfiles.where((p) =>
      p.userId != _currentUserId &&
          !_likedUserIds.contains(p.userId) &&
          !_blockedUserIds.contains(p.userId)
      ).toList();
      print('📊 Après filtrage (likes/blocages): ${allProfiles.length} (${beforeFilter - allProfiles.length} supprimés)');

      if (allProfiles.isEmpty) {
        print('⚠️ Aucun nouveau profil après filtrage');
        if (!isLoadMore && _profiles.isEmpty) {
          print('🔄 Activation mode recyclage...');
          _useRecyclingMode = true;
          await _loadProfiles();
        } else {
          _hasMore = false;
        }
        setState(() => _isLoading = false);
        return;
      }

      // 🔀 MÉLANGE INTELLIGENT: 5 populaires, 3 moyens, 2 moins populaires
      final sortedByScore = List<DatingProfile>.from(allProfiles);
      sortedByScore.sort((a, b) => b.popularityScore.compareTo(a.popularityScore));

      // Séparer en 3 groupes pour plus de variété
      final total = sortedByScore.length;
      final highCount = (total * 0.4).toInt();     // 40% meilleurs scores
      final midCount = (total * 0.3).toInt();      // 30% moyens
      final lowCount = total - highCount - midCount; // 30% bas

      List<DatingProfile> high = sortedByScore.take(highCount).toList();
      List<DatingProfile> mid = sortedByScore.skip(highCount).take(midCount).toList();
      List<DatingProfile> low = sortedByScore.skip(highCount + midCount).toList();

      print('📊 Répartition: ${high.length} populaires, ${mid.length} moyens, ${low.length} moins populaires');

      // Mélanger chaque groupe
      high.shuffle();
      mid.shuffle();
      low.shuffle();

      // 🔀 ALTERNANCE: 5 populaires, 3 moyens, 2 moins populaires
      List<DatingProfile> mixedProfiles = [];
      int highIndex = 0, midIndex = 0, lowIndex = 0;

      while (highIndex < high.length || midIndex < mid.length || lowIndex < low.length) {
        // Ajouter 5 populaires
        for (int i = 0; i < 5 && highIndex < high.length; i++) {
          mixedProfiles.add(high[highIndex++]);
        }
        // Ajouter 3 moyens
        for (int i = 0; i < 3 && midIndex < mid.length; i++) {
          mixedProfiles.add(mid[midIndex++]);
        }
        // Ajouter 2 moins populaires
        for (int i = 0; i < 2 && lowIndex < low.length; i++) {
          mixedProfiles.add(low[lowIndex++]);
        }
      }

      print('📊 Mélange final: ${mixedProfiles.length} profils');

      if (isLoadMore) {
        _profiles.addAll(mixedProfiles);
        print('📦 Ajout de ${mixedProfiles.length} profils (total: ${_profiles.length})');
        setState(() => _isLoadingMore = false);
      } else {
        _profiles = mixedProfiles;
        _currentIndex = 0;
        print('🎯 Premier chargement: ${_profiles.length} profils');
        setState(() => _isLoading = false);

        // Préchargement
        if (_profiles.length < _batchSize * 2) {
          print('🔄 Démarrage du chargement en arrière-plan...');
          _loadMoreProfiles();
        }
      }

    } catch (e) {
      print('❌ Erreur chargement profils: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }
  Future<void> _loadProfiles2({bool isLoadMore = false}) async {
    if (_currentUserId == null || _currentUserProfile == null) return;
    if (isLoadMore && (_isLoadingMore || !_hasMore)) return;

    print('📱 _loadProfiles - isLoadMore: $isLoadMore');
    print('📊 Profils actuels: ${_profiles.length}, Index: $_currentIndex');
    print('🎯 Mode recyclage: $_useRecyclingMode');

    setState(() {
      if (isLoadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      if (!_initialLoadDone) {
        await Future.wait([
          _loadLikedUserIds(),
          _loadBlockedUserIds(),
        ]);
        _initialLoadDone = true;
      }

      final isMale = _currentUserProfile!.sexe.toLowerCase() == 'homme';
      print('👤 Utilisateur: ${_currentUserProfile!.sexe} (isMale: $isMale)');

      // Déterminer le filtre de genre à appliquer
      String? genderFilter;
      if (_selectedGenderFilter == 'tous') {
        genderFilter = null;
        print('📊 Filtre par défaut: basé sur le genre de l\'utilisateur');
      } else {
        genderFilter = _selectedGenderFilter;
        print('🎯 Filtre personnalisé: $genderFilter');
      }

      // Construire la requête de base (sans filtre de genre)
      Query query = firestore
          .collection('dating_profiles')
          .where('isActive', isEqualTo: true);

      // Appliquer l'ordre selon le mode
      if (_useRecyclingMode) {
        print('🔄 Mode recyclage - Chargement des moins populaires');
        query = query.orderBy('popularityScore', descending: false)
            .orderBy('createdAt', descending: true);
      } else {
        print('🌟 Mode normal - Chargement des plus populaires');
        query = query.orderBy('popularityScore', descending: true)
            .orderBy('createdAt', descending: true);
      }

      // Pagination
      if (isLoadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
        print('📄 Pagination après: ${_lastDocument!.id}');
      }

      int batchSize = _batchSize * 3;
      if (_profiles.isEmpty && !isLoadMore) {
        batchSize = _batchSize * 4;
      }

      final snapshot = await query.limit(batchSize).get();
      print('📊 Profils bruts trouvés: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('⚠️ Aucun profil trouvé');
        if (_profiles.isEmpty) {
          setState(() => _isLoading = false);
          _showNoProfilesAvailable();
        } else {
          _hasMore = false;
          setState(() => _isLoading = false);
        }
        return;
      }

      _lastDocument = snapshot.docs.last;
      print('📌 _lastDocument mis à jour: ${_lastDocument!.id}');

      List<DatingProfile> allProfiles = snapshot.docs
          .map((doc) => DatingProfile.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Filtrer l'utilisateur courant, les likés et les bloqués
      final beforeFilter = allProfiles.length;
      allProfiles = allProfiles.where((p) =>
      p.userId != _currentUserId &&
          !_likedUserIds.contains(p.userId) &&
          !_blockedUserIds.contains(p.userId)
      ).toList();
      print('📊 Après filtrage (likes/blocages): ${allProfiles.length} (${beforeFilter - allProfiles.length} supprimés)');

      if (allProfiles.isEmpty) {
        print('⚠️ Aucun nouveau profil après filtrage');
        if (!isLoadMore && _profiles.isEmpty) {
          print('🔄 Activation mode recyclage...');
          _useRecyclingMode = true;
          await _loadProfiles();
        } else {
          _hasMore = false;
        }
        setState(() => _isLoading = false);
        return;
      }

      // Séparer par genre
      final women = allProfiles.where((p) => p.sexe.toLowerCase() == 'femme').toList();
      final men = allProfiles.where((p) => p.sexe.toLowerCase() == 'homme').toList();

      print('👩 Femmes disponibles: ${women.length}');
      print('👨 Hommes disponibles: ${men.length}');

      // Trier chaque liste par popularité
      women.sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
      men.sort((a, b) => b.popularityScore.compareTo(a.popularityScore));

      // Déterminer les pourcentages selon le genre de l'utilisateur
      List<DatingProfile> selectedProfiles = [];
      int womenToTake, menToTake;

      if (isMale) {
        // Homme: 80% femmes, 20% hommes
        womenToTake = (allProfiles.length * 0.8).toInt();
        menToTake = allProfiles.length - womenToTake;
        print('📊 Objectif (Homme): $womenToTake femmes, $menToTake hommes');
      } else {
        // Femme: 60% femmes, 40% hommes
        womenToTake = (allProfiles.length * 0.6).toInt();
        menToTake = allProfiles.length - womenToTake;
        print('📊 Objectif (Femme): $womenToTake femmes, $menToTake homens');
      }

      // Ajuster si pas assez de profils d'un genre
      if (women.length < womenToTake) {
        womenToTake = women.length;
        menToTake = allProfiles.length - womenToTake;
        print('📊 Ajustement: pas assez de femmes, prend $womenToTake femmes, $menToTake hommes');
      }
      if (men.length < menToTake) {
        menToTake = men.length;
        womenToTake = allProfiles.length - menToTake;
        print('📊 Ajustement: pas assez d\'hommes, prend $womenToTake femmes, $menToTake hommes');
      }

      // Prendre les meilleurs profils selon le score
      selectedProfiles.addAll(women.take(womenToTake));
      selectedProfiles.addAll(men.take(menToTake));

      // Mélanger pour alterner les genres
      selectedProfiles.shuffle();
      print('📊 Profils sélectionnés: ${selectedProfiles.length}');

      // Appliquer l'algorithme de mélange 3 populaires / 2 moins populaires
      final sortedByScore = List<DatingProfile>.from(selectedProfiles);
      sortedByScore.sort((a, b) => b.popularityScore.compareTo(a.popularityScore));

      final popularCount = (sortedByScore.length * 0.6).toInt();
      final lessPopularCount = sortedByScore.length - popularCount;

      List<DatingProfile> popular = sortedByScore.take(popularCount).toList();
      List<DatingProfile> lessPopular = sortedByScore.skip(popularCount).toList();

      popular.shuffle();
      lessPopular.shuffle();

      List<DatingProfile> mixedProfiles = [];
      int popularIndex = 0, lessIndex = 0;

      while (popularIndex < popular.length || lessIndex < lessPopular.length) {
        for (int i = 0; i < 3 && popularIndex < popular.length; i++) {
          mixedProfiles.add(popular[popularIndex++]);
        }
        for (int i = 0; i < 2 && lessIndex < lessPopular.length; i++) {
          mixedProfiles.add(lessPopular[lessIndex++]);
        }
      }

      print('📊 Mélange final: ${mixedProfiles.length} profils');

      if (isLoadMore) {
        _profiles.addAll(mixedProfiles);
        print('📦 Ajout de ${mixedProfiles.length} profils (total: ${_profiles.length})');
        setState(() => _isLoadingMore = false);
      } else {
        _profiles = mixedProfiles;
        _currentIndex = 0;
        print('🎯 Premier chargement: ${_profiles.length} profils');
        setState(() => _isLoading = false);

        if (_profiles.length < _batchSize) {
          print('🔄 Démarrage du chargement en arrière-plan...');
          _loadMoreProfiles();
        }
      }

    } catch (e) {
      print('❌ Erreur chargement profils: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreProfiles() async {
    if (!_hasMore || _isLoadingMore) {
      print('⚠️ Chargement annulé: hasMore=$_hasMore, isLoadingMore=$_isLoadingMore');
      return;
    }
    print('📦 Lancement du chargement de plus de profils...');
    await _loadProfiles(isLoadMore: true);
  }

  Future<void> _resetAndReload() async {
    print('🔄 === RÉINITIALISATION ET RECYCLAGE ===');

    if (!_useRecyclingMode) {
      _useRecyclingMode = true;
      print('🔄 Activation du mode recyclage (moins populaires d\'abord)');
    } else {
      _useRecyclingMode = false;
      print('🔄 Retour au mode normal');
    }

    _hasMore = true;
    _lastDocument = null;
    _profiles = [];
    _currentIndex = 0;
    await _loadProfiles();
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

      print('📊 Mise à jour score pour $userId: $score points');

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

  void _handleSwipeLeft() {
    if (_isLoadingMore || _isSwiping || _currentIndex >= _profiles.length) return;

    _isSwiping = true;
    print('👈 Swipe gauche - Profil: ${_profiles[_currentIndex].pseudo}');

    final profile = _profiles[_currentIndex];
    _nextProfile();
    _recordSwipeAction(profile.userId, 'left').catchError((e) => print('Erreur: $e'));

    Future.delayed(Duration(milliseconds: 300), () {
      _isSwiping = false;
    });
  }

  void _handleSwipeRight() {
    if (_isLoadingMore || _isSwiping || _currentIndex >= _profiles.length) return;

    if (_remainingLikes != -1 && _remainingLikes <= 0) {
      _showUpgradeDialog();
      return;
    }

    _isSwiping = true;
    final profile = _profiles[_currentIndex];
    print('👉 Swipe droit - Profil: ${profile.pseudo}');

    _likeCount++;
    _history.add(profile);
    _nextProfile();
    _processLike(profile);
    _checkAndLoadMore();

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
    print('⭐ Super like - Profil: ${profile.pseudo}');

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
        });
        await _saveRemainingLikes();
      }

      await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: profile.userId)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update({'likesCount': FieldValue.increment(1)});
        }
      });

      await _updatePopularityScore(profile.userId);

      final mutualLike = await firestore
          .collection('dating_likes')
          .where('fromUserId', isEqualTo: profile.userId)
          .where('toUserId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (mutualLike.docs.isNotEmpty) {
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
      print('❌ Erreur like: $e');
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

      setState(() {
        _remainingSuperLikes--;
      });
      await _saveRemainingLikes();

      await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: profile.userId)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update({'coupsDeCoeurCount': FieldValue.increment(1)});
        }
      });

      await _updatePopularityScore(profile.userId);

      await _sendNotification(
        toUserId: profile.userId,
        message: "⭐ @${_getCurrentUserPseudo()} vous a envoyé un super like !",
        type: 'super_like',
      );

      _showSuccessMessage('✨ Super like envoyé à ${profile.pseudo} (+20 points)', Colors.amber);

    } catch (e) {
      print('❌ Erreur super like: $e');
    }
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
              // Icône animée
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPremium
                        ? [Colors.red.shade400, Colors.pink.shade400]
                        : [Colors.grey.shade300, Colors.grey.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isPremium ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isPremium ? Icons.favorite : Icons.lock,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),

              // Titre
              Text(
                isPremium ? '❤️ ${_history.length} profils likés !' : '❤️ ${_history.length} profils likés',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isPremium ? Colors.red.shade700 : Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 12),

              // Message
              Text(
                isPremium
                    ? 'Découvrez tous les profils que vous avez likés'
                    : 'Voir les profils que vous avez likés est réservé aux membres AfroLove Plus et Gold.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isPremium ? Colors.grey.shade600 : Colors.grey.shade500,
                ),
              ),
              SizedBox(height: 20),

              if (isPremium) ...[
                // Bouton pour voir les likes
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Naviguer vers la page des likes
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DatingLikesListPage()),
                    );
                  },
                  icon: Icon(Icons.visibility, size: 18, color: Colors.white),
                  label: Text(
                    'Voir mes ${_history.length} likes',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    minimumSize: Size(double.infinity, 48),
                  ),
                ),
                SizedBox(height: 12),

                // Bouton pour continuer à swiper
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    minimumSize: Size(double.infinity, 44),
                  ),
                  child: Text(
                    'Continuer à swiper',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ] else ...[
                // Bouton pour voir les offres
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DatingSubscriptionPage()),
                    );
                  },
                  icon: Icon(Icons.star, size: 18, color: Colors.black),
                  label: Text(
                    'Débloquer Premium',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    minimumSize: Size(double.infinity, 48),
                  ),
                ),
                SizedBox(height: 12),

                // Bouton pour continuer
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    minimumSize: Size(double.infinity, 44),
                  ),
                  child: Text(
                    'Continuer à swiper',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  void _showPremiumChatDialog(DatingProfile profile) {
    // final isPremium = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');
    final isPremium = _subscriptionPlan != null && (_subscriptionPlan == 'gold');

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
                'La messagerie privée est réservée aux membres AfroLove Gold.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Passez à l\'abonnement Premium Gold pour discuter avec vos matchs !',
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
    final isPremium = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');

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
                        if (isPremium) {
                          _openChat(profile);
                        } else {
                          _showPremiumChatDialog(profile);
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

  void _openChat(DatingProfile profile) async {
    final connection = await _getOrCreateConnection(profile.userId);
    if (connection != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DatingChatPage(
            connectionId: connection.id,
            otherUserId: profile.userId,
            otherUserName: profile.pseudo,
            otherUserImage: profile.imageUrl,
          ),
        ),
      );
    }
  }

  Future<DatingConnection?> _getOrCreateConnection(String otherUserId) async {
    if (_currentUserId == null) return null;

    try {
      final snapshot = await firestore
          .collection('dating_connections')
          .where('userId1', isEqualTo: _currentUserId)
          .where('userId2', isEqualTo: otherUserId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return DatingConnection.fromJson(snapshot.docs.first.data());
      }

      final snapshot2 = await firestore
          .collection('dating_connections')
          .where('userId1', isEqualTo: otherUserId)
          .where('userId2', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (snapshot2.docs.isNotEmpty) {
        return DatingConnection.fromJson(snapshot2.docs.first.data());
      }

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
    if (doc.exists) return UserData.fromJson(doc.data() as Map<String, dynamic>);
    return null;
  }

  String _getCurrentUserPseudo() {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return authProvider.loginUserData.pseudo ?? 'Utilisateur';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadMore();
    });
  }

  void _checkAndLoadMore() {
    final remainingProfiles = _profiles.length - _currentIndex;
    if (remainingProfiles <= 5 && _hasMore && !_isLoadingMore) {
      print('🔄 Chargement en arrière-plan déclenché (restants: $remainingProfiles)');
      _loadMoreProfiles();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isLoadingMore || _isSwiping) return;

    final newDragOffset = _dragOffset + details.delta;
    setState(() {
      _dragOffset = newDragOffset;
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
    if (_currentUserProfile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DatingProfileDetailPage(profile: _currentUserProfile!),
        ),
      );
    }
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
    final hasSubscription = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');
    final showEmptyState = _profiles.isEmpty && !_isLoading;

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
          GestureDetector(
            onTap: _goToMyProfile,
            child: Stack(
              children: [
                Container(
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
                      Text(
                        'Moi',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                /// 🔔 BADGE
                if (_unreadNotificationsCount > 0)
                  Positioned(
                    right: 2,
                    top: -5,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.yellow, // ✅ fond jaune
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white, // petit contour propre
                          width: 1.5,
                        ),
                      ),
                      constraints: BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        _unreadNotificationsCount > 99
                            ? '99+'
                            : '$_unreadNotificationsCount',
                        style: TextStyle(
                          color: Colors.white, // ✅ texte blanc
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement des profils...'),
                ],
              ),
            )
          else if (showEmptyState)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
                  SizedBox(height: 16),
                  Text(
                    'Chargement des profils...',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 8),
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
                    SizedBox(height: 16),
                    Text(
                      'Plus de profils pour le moment',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                    SizedBox(height: 8),
                    Text('Revenez plus tard', style: TextStyle(color: Colors.grey.shade500)),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _hasMore = true;
                          _lastDocument = null;
                          _profiles = [];
                          _currentIndex = 0;
                        });
                        await _loadProfiles();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text('Actualiser'),
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
            _buildActionButton(icon: Icons.close, color: Colors.red, onPressed: _handleSwipeLeft, size: 28),
            _buildActionButton(icon: Icons.star, color: Colors.amber, onPressed: _handleSuperLike, size: 32),
            _buildActionButton(icon: Icons.favorite, color: Colors.green, onPressed: _handleSwipeRight, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(DatingProfile profile, {required bool isNext}) {
    final hasSubscription = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');

    final randomIndex = (profile.userId.hashCode + _currentIndex) % profile.photosUrls.length;
    final displayImageUrl = profile.photosUrls.isNotEmpty
        ? profile.photosUrls[randomIndex]
        : profile.imageUrl;

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
                displayImageUrl,
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