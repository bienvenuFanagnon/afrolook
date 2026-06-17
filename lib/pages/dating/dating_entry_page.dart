// lib/pages/dating/dating_swipe_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'buy_coins_page.dart';
import 'dating_chat_page.dart';
import 'dating_connections_page.dart';
import 'dating_creator_posts_tab.dart';
import 'dating_explore_page.dart';
import 'dating_likes_list_page.dart';
import 'dating_notifications_page.dart';
import 'dating_profile_detail_page.dart';
import 'dating_profile_setup_page.dart';
import 'dating_map_page.dart';
import 'dating_subscription_page.dart';

/// Observateur de navigation global au module Dating : permet à
/// [DatingSwipePage] de détecter son retour au premier plan (après avoir
/// poussé la page d'abonnement, un profil, etc.) et de recharger les
/// quotas (likes/super likes/swipes) depuis Firestore.
final RouteObserver<PageRoute> datingRouteObserver = RouteObserver<PageRoute>();

class DatingSwipePage extends StatefulWidget {
  const DatingSwipePage({Key? key}) : super(key: key);

  @override
  State<DatingSwipePage> createState() => _DatingSwipePageState();
}

class _DatingSwipePageState extends State<DatingSwipePage> with TickerProviderStateMixin, RouteAware {
  // ---------- Cache de session (persistance de la position du deck) ----------
  // Quand l'utilisateur quitte la page de swipe (chat, profil détail, etc.)
  // puis y revient, une nouvelle instance de cette page peut être créée :
  // sans ce cache statique, le deck serait rechargé et `_currentIndex`
  // repartirait de zéro, donnant l'impression que tout "recommence à zéro".
  // On restaure donc la position exacte là où l'utilisateur s'était arrêté.
  static String? _cachedUserId;
  static List<DatingProfile>? _cachedProfiles;
  static int _cachedCurrentIndex = 0;
  static Set<String> _cachedLoadedProfileIds = {};
  static Set<String> _cachedExcludedUserIds = {};
  static Set<String> _cachedPassedUserIds = {};
  static bool _cachedExcludeInteracted = true;
  static bool _cachedFiltersRelaxed = false;
  static bool _cachedHasMore = true;
  static DocumentSnapshot? _cachedLastDocument;

  /// Sauvegarde l'état courant du deck dans le cache statique afin de
  /// pouvoir reprendre exactement là où l'utilisateur s'était arrêté.
  void _saveDeckCache() {
    _cachedUserId = _currentUserId;
    _cachedProfiles = List<DatingProfile>.from(_profiles);
    _cachedCurrentIndex = _currentIndex;
    _cachedLoadedProfileIds = Set<String>.from(_loadedProfileIds);
    _cachedExcludedUserIds = Set<String>.from(_excludedUserIds);
    _cachedPassedUserIds = Set<String>.from(_passedUserIds);
    _cachedExcludeInteracted = _excludeInteracted;
    _cachedFiltersRelaxed = _filtersRelaxed;
    _cachedHasMore = _hasMore;
    _cachedLastDocument = _lastDocument;
  }

  /// Restaure le deck depuis le cache statique si disponible pour cet
  /// utilisateur. Retourne `true` si la restauration a eu lieu (dans ce cas,
  /// le rechargement initial des profils peut être évité).
  bool _restoreDeckCache() {
    if (_cachedUserId != _currentUserId || _cachedProfiles == null || _cachedProfiles!.isEmpty) {
      return false;
    }
    _profiles = List<DatingProfile>.from(_cachedProfiles!);
    _currentIndex = _cachedCurrentIndex.clamp(0, _profiles.length);
    _loadedProfileIds
      ..clear()
      ..addAll(_cachedLoadedProfileIds);
    _excludedUserIds = Set<String>.from(_cachedExcludedUserIds);
    _passedUserIds = Set<String>.from(_cachedPassedUserIds);
    _excludeInteracted = _cachedExcludeInteracted;
    _filtersRelaxed = _cachedFiltersRelaxed;
    _hasMore = _cachedHasMore;
    _lastDocument = _cachedLastDocument;
    return true;
  }

  // Swipe data
  List<DatingProfile> _profiles = [];
  List<DatingProfile> _history = [];
  int _currentIndex = 0;
  int _likeCount = 0;
  int _likeCountThreshold = 6;
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
  int _remainingSwipes = -1;
  int _lastResetDate = 0;
  String? _subscriptionPlan;
  String? _userSubscriptionDocId;
  int _unreadNotificationsCount = 0;

  // ---------- Rewind (Plus/Gold) ----------
  /// Type du dernier swipe effectué ('pass', 'like', 'superlike'), pour pouvoir
  /// l'annuler (rewind) et restaurer les quotas correspondants.
  String? _lastSwipeType;

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

  // Animation programmée (fly-off au relâchement / clic sur les boutons d'action,
  // et retour élastique si le swipe n'a pas atteint le seuil de décision)
  late AnimationController _cardAnimController;
  Offset _animFrom = Offset.zero;
  Offset _animTo = Offset.zero;
  double _animRotFrom = 0.0;
  double _animRotTo = 0.0;
  double _animOpacityFrom = 1.0;
  double _animOpacityTo = 1.0;
  bool _animIsExit = false;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  static const int _batchSize = 100; // Charger 100 profils par lot
  static const int _maxReloadAttempts = 3; // Limite de tentatives de rechargement (anti-boucle infinie)
  int _reloadAttempts = 0;

  /// Identifiants des profils déjà likés ou matchés par l'utilisateur courant.
  /// Tant que `_excludeInteracted` est vrai, ces profils sont écartés en
  /// priorité afin de mettre en avant les profils non encore explorés.
  Set<String> _excludedUserIds = {};
  bool _excludeInteracted = true;

  /// Identifiants des profils "passés" (swipe gauche) — ces profils ne sont
  /// JAMAIS réaffichés, ni après un restart de cycle, ni en mode élargissement
  /// des filtres. Persisté dans Firestore (collection dating_passes).
  Set<String> _passedUserIds = {};

  /// Vrai quand le deck est véritablement épuisé : même en réincluant les
  /// likés et en élargissant les filtres, aucun profil n'est disponible.
  bool _deckExhausted = false;

  /// Si le nombre de profils correspondant aux critères de recherche
  /// (tranche d'âge / pays) est trop faible, on élargit automatiquement la
  /// recherche (on ignore ces filtres) pour éviter de boucler indéfiniment
  /// sur une poignée de profils.
  bool _filtersRelaxed = false;

  /// Identifiants de tous les profils déjà chargés dans `_profiles` (toutes
  /// pages confondues), pour éviter d'ajouter des doublons lors d'un
  /// "load more" ou d'un recyclage de cycle.
  final Set<String> _loadedProfileIds = {};

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250))
      ..addListener(_onCardAnimTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      _currentUserId = authProvider.loginUserData.id;
      _listenUnreadNotifications();
      _loadUserSubscription();
      _loadCurrentUserProfile();
      _maybeShowHowItWorksModal();
    });
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    datingRouteObserver.unsubscribe(this);
    super.dispose();
  }
  bool _wasActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      datingRouteObserver.subscribe(this, route);
    }
    final isActive = route?.isCurrent ?? false;
    if (isActive && !_wasActive) {
      _refreshData();
    }
    _wasActive = isActive;
  }

  /// Appelé automatiquement par [datingRouteObserver] quand une page poussée
  /// par-dessus celle-ci (abonnement, profil détail, achat de pièces...) est
  /// dépilée et que cette page revient au premier plan : on recharge alors
  /// les quotas (likes/super likes/swipes), qui peuvent avoir changé.
  @override
  void didPopNext() {
    super.didPopNext();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await _loadUserSubscription();
    // Si vous voulez aussi recharger les profils (ex : après un achat), décommentez la ligne ci-dessous
    // await _loadProfiles(reset: true);
  }

  /// Affiche le modal "Comment ça marche" une fois par mois maximum
  /// (et dès la première visite).
  Future<void> _maybeShowHowItWorksModal() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('dating_how_it_works_last_shown') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const oneMonthMs = 30 * 24 * 60 * 60 * 1000;
    if (now - last < oneMonthMs) return;
    await prefs.setInt('dating_how_it_works_last_shown', now);
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _showHowItWorksDialog();
    });
  }

  void _showHowItWorksDialog() {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.of(context).surface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.datingHowItWorksTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.of(context).textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _howItWorksSection(Icons.swipe, t.datingHowItWorksSwipeTitle, t.datingHowItWorksSwipeDesc),
                _howItWorksSection(Icons.star, t.datingHowItWorksLikeTitle, t.datingHowItWorksLikeDesc),
                _howItWorksSection(Icons.map, t.datingHowItWorksMapTitle, t.datingHowItWorksMapDesc),
                _howItWorksSection(Icons.workspace_premium, t.datingHowItWorksSubscriptionsTitle, t.datingHowItWorksSubscriptionsDesc),
                _howItWorksSection(Icons.rocket_launch, t.datingHowItWorksBoostTitle, t.datingHowItWorksBoostDesc),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(
                      t.datingHowItWorksGotIt,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _howItWorksSection(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.red.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.of(context).textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12, color: AppColors.of(context).textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  /// Vérifie à l'arrivée sur la page si l'utilisateur a de nouveaux matchs
  /// ou likes non encore consultés, et affiche un modal pour l'en informer.
  Future<void> _checkNewActivity() async {
    if (_currentUserId == null) return;
    try {
      final matchSnap = await firestore
          .collection('Notifications')
          .where('receiver_id', isEqualTo: _currentUserId)
          .where('type', isEqualTo: 'DATING_MATCH')
          .where('is_open', isEqualTo: false)
          .get();

      final likeSnap = await firestore
          .collection('Notifications')
          .where('receiver_id', isEqualTo: _currentUserId)
          .where('type', whereIn: ['DATING_LIKE', 'DATING_SUPER_LIKE'])
          .where('is_open', isEqualTo: false)
          .get();

      final matchCount = matchSnap.docs.length;
      final likeCount = likeSnap.docs.length;

      if ((matchCount > 0 || likeCount > 0) && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showNewActivityDialog(matchCount, likeCount);
        });
      }
    } catch (e) {
      print('❌ Erreur _checkNewActivity: $e');
    }
  }

  /// Modal annonçant les nouveaux matchs/likes en attente avec accès direct.
  void _showNewActivityDialog(int matchCount, int likeCount) {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.of(context).surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.red.shade400, Colors.pink.shade400]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                t.datingNewActivityTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.of(context).textPrimary),
              ),
              const SizedBox(height: 8),
              if (matchCount > 0)
                Text(
                  t.datingNewActivityMatches(matchCount),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.of(context).textSecondary),
                ),
              if (likeCount > 0)
                Text(
                  t.datingNewActivityLikes(likeCount),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.of(context).textSecondary),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t.datingMaybeLater),
                    ),
                  ),
                  if (matchCount > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DatingConnectionsPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text(t.datingViewMatches, style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ] else if (likeCount > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DatingLikesListPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink.shade400,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text(t.datingViewLikes, style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Quota quotidien de profils que l'on peut parcourir, selon le plan.
  int _defaultSwipesForPlan(String? plan) {
    switch (plan) {
      case 'plus':
        return 50;
      case 'gold':
        return -1; // illimité
      default:
        return 15; // gratuit
    }
  }

  /// Quota quotidien de likes, selon le plan (utilisé en repli si le document
  /// `subscription_plans` ne contient pas (encore) le champ `defaultLikes`).
  int _defaultLikesForPlan(String? plan) {
    switch (plan) {
      case 'plus':
        return 20;
      case 'gold':
        return 50;
      default:
        return 5; // gratuit
    }
  }

  /// Quota quotidien de super likes, selon le plan (repli si champ absent).
  int _defaultSuperLikesForPlan(String? plan) {
    switch (plan) {
      case 'plus':
        return 5;
      case 'gold':
        return 20;
      default:
        return 1; // gratuit
    }
  }

  // ---------- Gestion de l'abonnement et réinitialisation quotidienne ----------
  Future<void> _loadUserSubscription() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await firestore
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .get();

      final nowDateTime = DateTime.now();
      final todayStart = DateTime(nowDateTime.year, nowDateTime.month, nowDateTime.day).millisecondsSinceEpoch;
      final nowMillis = nowDateTime.millisecondsSinceEpoch;

      if (snapshot.docs.isNotEmpty) {
        // En cas de doublons d'abonnements actifs (anciens bugs de migration),
        // ne garder que le plus récent (createdAt le plus élevé) et désactiver
        // les autres, pour éviter de lire un document obsolète/incohérent.
        var docs = snapshot.docs;
        if (docs.length > 1) {
          docs = [...docs]..sort((a, b) {
            final aCreated = a.data()['createdAt'] as int? ?? 0;
            final bCreated = b.data()['createdAt'] as int? ?? 0;
            return bCreated.compareTo(aCreated);
          });
          for (var i = 1; i < docs.length; i++) {
            await firestore.collection('user_dating_subscriptions').doc(docs[i].id).update({'isActive': false});
            print('🧹 Doublon d\'abonnement actif désactivé: ${docs[i].id}');
          }
        }
        final subscription = docs.first;
        final subscriptionData = subscription.data();
        _userSubscriptionDocId = subscription.id;
        _subscriptionPlan = subscriptionData['planCode'];

        // Limites du plan : catalogue local (lib/pages/dating/dating_subscription_page.dart),
        // toujours à jour, contrairement à l'ancienne collection Firestore
        // `subscription_plans` qui pouvait contenir des valeurs obsolètes.
        final defaultLikes = _defaultLikesForPlan(_subscriptionPlan);
        final defaultSuperLikes = _defaultSuperLikesForPlan(_subscriptionPlan);
        final defaultSwipes = _defaultSwipesForPlan(_subscriptionPlan);

        // Vérifier la date de dernière réinitialisation
        final lastReset = subscriptionData['lastResetDate'] as int? ?? 0;

        // Si le plan a changé depuis le dernier chargement (mise à jour
        // d'abonnement) sans qu'une réinitialisation quotidienne ait eu
        // lieu, on applique immédiatement les nouvelles limites du plan.
        final storedPlanCode = subscriptionData['quotaPlanCode'] as String?;
        final planChanged = storedPlanCode != null && storedPlanCode != _subscriptionPlan;

        if (lastReset < todayStart || planChanged) {
          _remainingLikes = defaultLikes;
          _remainingSuperLikes = defaultSuperLikes;
          _remainingSwipes = defaultSwipes;
          _lastResetDate = todayStart;
          await firestore
              .collection('user_dating_subscriptions')
              .doc(_userSubscriptionDocId)
              .update({
            'remainingLikes': _remainingLikes,
            'remainingSuperLikes': _remainingSuperLikes,
            'remainingSwipes': _remainingSwipes,
            'lastResetDate': todayStart,
            'quotaPlanCode': _subscriptionPlan,
            'updatedAt': nowMillis,
          });
          print('🔄 Réinitialisation des quotas (plan=$_subscriptionPlan): likes=$_remainingLikes, super likes=$_remainingSuperLikes, swipes=$_remainingSwipes');
        } else {
          _remainingLikes = subscriptionData['remainingLikes'] ?? defaultLikes;
          _remainingSuperLikes = subscriptionData['remainingSuperLikes'] ?? defaultSuperLikes;
          _remainingSwipes = subscriptionData['remainingSwipes'] ?? defaultSwipes;
          _lastResetDate = lastReset;
        }

        // Vérifier expiration (plans payants)
        final endAt = subscriptionData['endAt'] as int?;
        if (endAt != null && endAt <= nowMillis) {
          await firestore
              .collection('user_dating_subscriptions')
              .doc(_userSubscriptionDocId)
              .update({'isActive': false});
          _subscriptionPlan = 'gratuit';
          _remainingLikes = _defaultLikesForPlan('gratuit');
          _remainingSuperLikes = _defaultSuperLikesForPlan('gratuit');
          _remainingSwipes = _defaultSwipesForPlan('gratuit');
          _lastResetDate = todayStart;
          // Créer un nouveau document d'abonnement gratuit actif, pour que les prochains
          // décréments/sauvegardes (_decrementRemaining, _saveRemainingLikes) écrivent
          // bien sur un document actif et non sur l'ancien abonnement désactivé.
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
            'remainingSwipes': _remainingSwipes,
            'lastResetDate': todayStart,
            'quotaPlanCode': 'gratuit',
            'createdAt': nowMillis,
            'updatedAt': nowMillis,
          });
          print('⚠️ Abonnement expiré, passage en gratuit');
        }
      } else {
        // Aucun abonnement -> mode gratuit
        _remainingLikes = _defaultLikesForPlan('gratuit');
        _remainingSuperLikes = _defaultSuperLikesForPlan('gratuit');
        _subscriptionPlan = 'gratuit';
        _remainingSwipes = _defaultSwipesForPlan('gratuit');
        _lastResetDate = todayStart;
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
          'remainingSwipes': _remainingSwipes,
          'lastResetDate': todayStart,
          'quotaPlanCode': 'gratuit',
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

  /// Formate le temps restant avant le prochain reset quotidien des swipes (lastResetDate + 24h).
  String _formatTimeUntilNextReset() {
    final nextReset = _lastResetDate + (24 * 60 * 60 * 1000);
    final remainingMs = nextReset - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) return '0h00';
    final remainingMinutes = (remainingMs / 60000).ceil();
    final hours = remainingMinutes ~/ 60;
    final minutes = remainingMinutes % 60;
    return '${hours}h${minutes.toString().padLeft(2, '0')}';
  }

  /// Décrémente atomiquement (côté Firestore) le compteur de likes ou super likes restants.
  /// Évite que deux sessions concurrentes (ou un crash entre setState et écriture) ne fassent
  /// perdre ou dupliquer des likes en écrasant la valeur absolue stockée.
  Future<void> _decrementRemaining(String field) async {
    if (_currentUserId == null || _userSubscriptionDocId == null) return;
    try {
      await firestore
          .collection('user_dating_subscriptions')
          .doc(_userSubscriptionDocId)
          .update({
        field: FieldValue.increment(-1),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('❌ Erreur décrément $field: $e');
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
  /// Charge les identifiants des profils déjà likés ou matchés par
  /// l'utilisateur courant, pour les écarter en priorité des suggestions
  /// et privilégier les profils non encore explorés.
  Future<void> _loadExcludedUserIds() async {
    if (_currentUserId == null) return;
    try {
      final interactedIds = <String>{};
      final passedIds = <String>{};

      final results = await Future.wait([
        firestore.collection('dating_likes').where('fromUserId', isEqualTo: _currentUserId).get(),
        firestore.collection('dating_connections').where('userId1', isEqualTo: _currentUserId).get(),
        firestore.collection('dating_connections').where('userId2', isEqualTo: _currentUserId).get(),
        firestore.collection('dating_passes').where('fromUserId', isEqualTo: _currentUserId).get(),
      ]);

      for (var doc in results[0].docs) {
        final toId = doc['toUserId'];
        if (toId is String) interactedIds.add(toId);
      }
      for (var doc in results[1].docs) {
        final id = doc['userId2'];
        if (id is String) interactedIds.add(id);
      }
      for (var doc in results[2].docs) {
        final id = doc['userId1'];
        if (id is String) interactedIds.add(id);
      }
      for (var doc in results[3].docs) {
        final toId = doc['toUserId'];
        if (toId is String) passedIds.add(toId);
      }

      _excludedUserIds = interactedIds;
      _passedUserIds = passedIds;
    } catch (e) {
      print('❌ Erreur chargement profils déjà explorés: $e');
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
        if (_restoreDeckCache()) {
          if (mounted) setState(() => _isLoading = false);
          WidgetsBinding.instance.addPostFrameCallback((_) => _precacheUpcomingPhotos());
        } else {
          await _loadExcludedUserIds();
          await _loadProfiles();
        }
        _checkNewActivity();
        _maybeShowProfileCompletionPrompt();
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

  /// Si le profil de l'utilisateur n'a pas de géolocalisation et/ou moins de
  /// 2 photos, propose (une fois par session) de compléter son profil afin
  /// d'améliorer la pertinence des suggestions (proximité, taux de match...).
  bool _profileCompletionPromptShown = false;
  void _maybeShowProfileCompletionPrompt() {
    if (_profileCompletionPromptShown || !mounted || _currentUserProfile == null) return;

    final missingLocation = _currentUserProfile!.latitude == null || _currentUserProfile!.longitude == null;
    final missingPhotos = _currentUserProfile!.photosUrls.length < 2;

    if (!missingLocation && !missingPhotos) return;

    _profileCompletionPromptShown = true;
    final t = AppLocalizations.of(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.of(context).surface,
          title: Row(
            children: [
              Icon(Icons.person_pin_circle, color: AppColors.of(context).primary),
              const SizedBox(width: 8),
              Expanded(child: Text(t.datingCompleteProfileTitle, style: TextStyle(color: AppColors.of(context).textPrimary))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (missingLocation)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_off, size: 18, color: AppColors.of(context).textSecondary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t.datingMissingLocationMessage, style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 13))),
                    ],
                  ),
                ),
              if (missingPhotos)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 18, color: AppColors.of(context).textSecondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t.datingMissingPhotosMessage, style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 13))),
                  ],
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.datingLaterButton),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DatingProfileSetupPage(profile: _currentUserProfile)),
                ).then((_) => _loadCurrentUserProfile());
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(t.datingUpdateProfileButton, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    });
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

      // Une page incomplète signifie qu'on a atteint la fin de la collection
      // côté Firestore : plus rien de nouveau à charger pour ces critères.
      _hasMore = snapshot.docs.length >= _batchSize;

      if (snapshot.docs.isEmpty) {
        if (!isLoadMore && _profiles.isEmpty && _reloadAttempts < _maxReloadAttempts) {
          _reloadAttempts++;
          _hasMore = true;
          _lastDocument = null;
          await _loadProfiles();
        } else if (isLoadMore && _profiles.isNotEmpty) {
          // Plus rien de nouveau côté serveur : on arrête juste le
          // préchargement en arrière-plan, sans toucher au deck affiché ni
          // à _currentIndex (le recyclage se fera dans _nextProfile via
          // _restartDiscoveryCycle quand le deck sera réellement épuisé).
          _hasMore = false;
          if (mounted) setState(() => _isLoadingMore = false);
        } else {
          if (mounted) {
            setState(() {
              if (isLoadMore) _isLoadingMore = false;
              else _isLoading = false;
            });
          }
        }
        return;
      }

      _lastDocument = snapshot.docs.last;

      List<DatingProfile> allProfiles = snapshot.docs
          .map((doc) => DatingProfile.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      print('📊 ${allProfiles.length} profils avant');

      // Exclure l'utilisateur lui-même
      allProfiles = allProfiles.where((p) => p.userId != _currentUserId).toList();

      // Filtre par tranche d'âge recherchée par l'utilisateur courant
      // (ignoré si les critères ont été élargis faute de résultats suffisants)
      final ageMin = _currentUserProfile!.rechercheAgeMin;
      final ageMax = _currentUserProfile!.rechercheAgeMax;
      if (!_filtersRelaxed && ageMin > 0 && ageMax > 0) {
        allProfiles = allProfiles.where((p) => p.age >= ageMin && p.age <= ageMax).toList();
      }

      // Filtre par pays recherché par l'utilisateur courant
      // (ignoré si les critères ont été élargis faute de résultats suffisants)
      final recherchePays = _currentUserProfile!.recherchePays;
      if (!_filtersRelaxed && recherchePays.isNotEmpty && recherchePays.toLowerCase() != 'tous') {
        allProfiles = allProfiles.where((p) => p.pays == recherchePays).toList();
      }

      // Les profils "passés" (swipe gauche) ne sont JAMAIS réaffichés,
      // quel que soit l'état du cycle ou l'élargissement des filtres.
      if (_passedUserIds.isNotEmpty) {
        allProfiles = allProfiles.where((p) => !_passedUserIds.contains(p.userId)).toList();
      }

      // Mettre en avant les profils non encore explorés (ni likés, ni matchés).
      // Si plus aucun profil inexploré n'est disponible (toute la liste a déjà
      // été explorée), on désactive ce filtre pour recommencer le cycle et
      // s'assurer qu'il reste toujours des profils à parcourir.
      if (_excludeInteracted && _excludedUserIds.isNotEmpty) {
        final unexplored = allProfiles.where((p) => !_excludedUserIds.contains(p.userId)).toList();
        if (unexplored.isEmpty && allProfiles.isNotEmpty) {
          // Cycle épuisé : on remet les profils déjà likés/matchés plutôt
          // que de relancer une requête (évite un écran vide / un rechargement lent).
          _excludeInteracted = false;
        } else {
          allProfiles = unexplored;
        }
      }

      print('📊 ${allProfiles.length} profils après exclusion de soi-même et filtres');

      // Pour un "load more", écarter les profils déjà présents dans le deck
      // (toutes pages confondues) pour éviter les doublons.
      if (isLoadMore) {
        allProfiles = allProfiles.where((p) => !_loadedProfileIds.contains(p.userId)).toList();
        print('📊 ${allProfiles.length} profils après déduplication (load more)');
      }

      if (isLoadMore && allProfiles.isEmpty) {
        if (_hasMore && _reloadAttempts < _maxReloadAttempts) {
          _reloadAttempts++;
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) await _loadProfiles(isLoadMore: true);
          return;
        }
        // Plus rien de nouveau à charger : on arrête le préchargement en
        // arrière-plan sans toucher au deck affiché ni à _currentIndex.
        _hasMore = false;
        if (mounted) setState(() => _isLoadingMore = false);
        return;
      }

      if (allProfiles.isEmpty) {
        if (!isLoadMore && _profiles.isEmpty && _reloadAttempts < _maxReloadAttempts) {
          _reloadAttempts++;
          await _loadProfiles();
        } else {
          _hasMore = false;
          if (mounted) setState(() => _isLoading = false);
        }
        return;
      }

      // Réinitialiser le compteur de tentatives dès qu'on obtient des profils
      _reloadAttempts = 0;

      // Trier par score de recommandation (intérêts communs, tranche d'âge
      // recherchée, vérification, popularité, proximité géographique) pour
      // séparer les groupes : les profils les plus pertinents pour l'utilisateur
      // courant remontent en priorité.
      final sorted = List<DatingProfile>.from(allProfiles);
      sorted.sort((a, b) => _currentUserProfile!
          .recommendationScore(b)
          .compareTo(_currentUserProfile!.recommendationScore(a)));

      final total = sorted.length;
      final highCount = (total * 0.4).toInt();   // 40% les plus recommandés
      final midCount = (total * 0.3).toInt();    // 30% moyennement recommandés

      List<DatingProfile> high = sorted.take(highCount).toList();
      List<DatingProfile> mid = sorted.skip(highCount).take(midCount).toList();
      List<DatingProfile> low = sorted.skip(highCount + midCount).toList();

      // On garde un léger mélange à l'intérieur de chaque groupe pour varier
      // les découvertes tout en conservant la priorité de recommandation.
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

      // Anti-répétition : évite d'enchaîner plusieurs profils consécutifs de
      // la même ville/pays (le shuffle par groupe peut sinon les regrouper).
      _avoidConsecutiveSameLocation(mixed);

      if (isLoadMore) {
        _profiles.addAll(mixed);
        _loadedProfileIds.addAll(mixed.map((p) => p.userId));
        if (mounted) setState(() => _isLoadingMore = false);
      } else {
        _profiles = mixed;
        _loadedProfileIds
          ..clear()
          ..addAll(mixed.map((p) => p.userId));
        _currentIndex = 0;
        if (mounted) setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _precacheUpcomingPhotos());
      }
      _saveDeckCache();

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

  /// Réordonne [profiles] en place pour éviter d'avoir deux profils
  /// consécutifs de la même ville/pays : si c'est le cas, échange le profil
  /// suivant avec le prochain profil d'une autre localisation trouvé plus loin.
  void _avoidConsecutiveSameLocation(List<DatingProfile> profiles) {
    for (int i = 1; i < profiles.length; i++) {
      final prev = profiles[i - 1];
      final current = profiles[i];
      final samePays = prev.pays.isNotEmpty && prev.pays == current.pays;
      final sameVille = prev.ville.isNotEmpty && prev.ville == current.ville;
      if (samePays && sameVille) {
        for (int j = i + 1; j < profiles.length; j++) {
          final candidate = profiles[j];
          final candidateSamePays = prev.pays.isNotEmpty && prev.pays == candidate.pays;
          final candidateSameVille = prev.ville.isNotEmpty && prev.ville == candidate.ville;
          if (!(candidateSamePays && candidateSameVille)) {
            profiles[i] = candidate;
            profiles[j] = current;
            break;
          }
        }
      }
    }
  }

  Future<void> _loadMoreProfiles() async {
    if (_isLoadingMore || !_hasMore) return;
    await _loadProfiles(isLoadMore: true);
  }

  /// Le deck local est épuisé (l'utilisateur a swipé tous les profils
  /// chargés) : relance une recherche complète pour trouver de nouveaux profils.
  /// Les profils "passés" (swipe gauche) ne sont JAMAIS réaffichés.
  /// Si vraiment aucun profil n'est trouvable, affiche l'écran "Tu as tout vu !".
  Future<void> _restartDiscoveryCycle() async {
    if (_isLoading) return;

    // Étape 1 : on tente d'abord en excluant les likés + matchés (tout frais)
    _excludeInteracted = true;
    _hasMore = true;
    _lastDocument = null;
    _reloadAttempts = 0;
    _loadedProfileIds.clear();
    await _loadProfiles();

    if (_profiles.isNotEmpty) {
      // Des profils frais trouvés → on peut élargir silencieusement si peu
      if (!_filtersRelaxed && _profiles.length <= 6 && mounted) {
        _filtersRelaxed = true;
        _hasMore = true;
        _lastDocument = null;
        _loadedProfileIds.clear();
        await _loadProfiles();
        if (mounted) {
          final t = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.datingExpandedSearchCriteria)),
          );
        }
      }
      return;
    }

    // Étape 2 : aucun profil inexploré → réinclure les likés/matchés
    _excludeInteracted = false;
    _hasMore = true;
    _lastDocument = null;
    _reloadAttempts = 0;
    _loadedProfileIds.clear();
    await _loadProfiles();

    if (_profiles.isNotEmpty) {
      if (!_filtersRelaxed && _profiles.length <= 6 && mounted) {
        _filtersRelaxed = true;
        _hasMore = true;
        _lastDocument = null;
        _loadedProfileIds.clear();
        await _loadProfiles();
        if (mounted) {
          final t = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.datingExpandedSearchCriteria)),
          );
        }
      }
      return;
    }

    // Étape 3 : toujours vide → élargir les filtres et retenter
    if (!_filtersRelaxed) {
      _filtersRelaxed = true;
      _hasMore = true;
      _lastDocument = null;
      _reloadAttempts = 0;
      _loadedProfileIds.clear();
      await _loadProfiles();
    }

    // Étape 4 : deck vraiment épuisé
    if (_profiles.isEmpty && mounted) {
      setState(() => _deckExhausted = true);
    }
  }

  /// Précharge la prochaine page côté Firestore pendant que l'utilisateur
  /// approche de la fin du deck déjà chargé. Ne touche ni `_profiles` (sauf
  /// pour y ajouter de nouveaux profils) ni `_currentIndex`.
  void _checkAndLoadMore() {
    if (_hasMore && _profiles.length - _currentIndex <= 5 && !_isLoadingMore && mounted) {
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
    _maybeReinsertBoostedProfile();
    _saveDeckCache();

    if (_currentIndex >= _profiles.length) {
      // Deck épuisé : relancer un cycle de découverte plutôt que de rester
      // bloqué (ou de remélanger les 2-3 mêmes profils à chaque swipe).
      _restartDiscoveryCycle();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadMore();
      _precacheUpcomingPhotos();
    });
  }

  /// Précharge les photos des prochaines cartes (courante + suivante) pour
  /// éviter tout flash/transparence pendant le chargement réseau lors du swipe.
  void _precacheUpcomingPhotos() {
    for (final index in [_currentIndex, _currentIndex + 1, _currentIndex + 2]) {
      if (index < 0 || index >= _profiles.length) continue;
      final url = _displayImageUrlFor(_profiles[index]);
      if (url.isEmpty) continue;
      precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {});
    }
  }

  int _swipesSinceLastBoostInsert = 0;
  static const int _boostReinsertEvery = 8;

  /// Réinjecte périodiquement un profil "boosté" un peu plus loin dans la
  /// file, pour qu'il revienne régulièrement en visibilité au fil du swipe
  /// (et pas seulement une fois en tête de liste au chargement).
  void _maybeReinsertBoostedProfile() {
    _swipesSinceLastBoostInsert++;
    if (_swipesSinceLastBoostInsert < _boostReinsertEvery) return;
    _swipesSinceLastBoostInsert = 0;

    final boosted = _profiles.where((p) => p.isBoosted).toList();
    if (boosted.isEmpty) return;
    boosted.shuffle();

    // Évite de réinjecter un profil déjà visible dans les toutes prochaines cartes.
    final upcomingIds = _profiles
        .skip(_currentIndex)
        .take(3)
        .map((p) => p.userId)
        .toSet();
    final candidate = boosted.firstWhere(
      (p) => !upcomingIds.contains(p.userId),
      orElse: () => boosted.first,
    );
    if (upcomingIds.contains(candidate.userId)) return;

    final insertPos = (_currentIndex + 3).clamp(0, _profiles.length);
    setState(() {
      _profiles.insert(insertPos, candidate);
    });
  }

  int _mapPromoCounter = 0; // Compteur pour proposer périodiquement la carte
  static const int _mapPromoThreshold = 15;

  /// Vérifie si l'utilisateur peut encore parcourir des profils aujourd'hui.
  /// Le quota dépend du plan (`_remainingSwipes`, -1 = illimité, ex. Gold).
  /// Affiche un dialogue d'incitation à l'abonnement si le quota est épuisé.
  bool _canSwipe() {
    if (_remainingSwipes != -1 && _remainingSwipes <= 0) {
      _showUpgradeDialog(type: 'swipe');
      return false;
    }
    return true;
  }

  /// Décrémente le quota de profils parcourus (si limité) et déclenche
  /// éventuellement le modal de découverte de la carte.
  void _consumeSwipe() {
    if (_remainingSwipes != -1) {
      setState(() => _remainingSwipes--);
      _decrementRemaining('remainingSwipes');
    }
    _mapPromoCounter++;
    if (_mapPromoCounter >= _mapPromoThreshold) {
      _mapPromoCounter = 0;
      Future.delayed(const Duration(milliseconds: 400), _showMapDiscoveryDialog);
    }
  }

  /// Annule le dernier swipe (rewind) : remet le profil précédent à l'écran et
  /// restaure le quota consommé (swipe + like/super like le cas échéant).
  /// Réservé aux abonnements Plus/Gold, et limité à un rewind par swipe.
  void _rewindLastSwipe() {
    final t = AppLocalizations.of(context);
    final isPremium = _subscriptionPlan == 'plus' || _subscriptionPlan == 'gold';
    if (!isPremium) {
      _showUpgradeDialog(type: 'rewind');
      return;
    }
    if (_lastSwipeType == null || _currentIndex == 0) {
      _showSuccessMessage(t.datingNothingToRewind, Colors.orange);
      return;
    }

    setState(() {
      _currentIndex--;
      if (_remainingSwipes != -1) _remainingSwipes++;
      if (_lastSwipeType == 'like' && _remainingLikes != -1) _remainingLikes++;
      if (_lastSwipeType == 'superlike') _remainingSuperLikes++;
    });

    if (_remainingSwipes != -1) _adjustRemaining('remainingSwipes', 1);
    if (_lastSwipeType == 'like' && _remainingLikes != -1) _adjustRemaining('remainingLikes', 1);
    if (_lastSwipeType == 'superlike') _adjustRemaining('remainingSuperLikes', 1);

    _lastSwipeType = null;
    _showSuccessMessage(t.datingRewindSuccess, Colors.green);
  }

  /// Ajuste atomiquement (côté Firestore) un compteur de quota restant (+1 pour
  /// le rewind, -1 pour la consommation normale via [_decrementRemaining]).
  Future<void> _adjustRemaining(String field, int delta) async {
    if (_currentUserId == null || _userSubscriptionDocId == null) return;
    try {
      await firestore
          .collection('user_dating_subscriptions')
          .doc(_userSubscriptionDocId)
          .update({
        field: FieldValue.increment(delta),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('❌ Erreur ajustement $field: $e');
    }
  }

  static const int _boostDurationMs = 30 * 60 * 1000; // 30 minutes
  static const int _boostCostCoins = 100;

  /// Boost longue durée : visibilité accrue + badge "Boosté" sur le profil
  /// pendant N jours, à choisir par l'utilisateur, en pièces.
  static const Map<int, int> _longBoostPricesCoins = {
    1: 300,
    7: 1500,
    21: 3500,
    30: 4500,
    90: 11000,
    180: 19000,
  };

  /// Affiche le modal "Booster mon profil" : boost gratuit quotidien pour Gold,
  /// ou achat à l'unité (100 pièces) pour les autres, pendant 30 minutes.
  Future<void> _showBoostDialog() async {
    if (_currentUserId == null || _currentUserProfile == null) return;
    final t = AppLocalizations.of(context);

    if (_currentUserProfile!.isBoosted) {
      _showSuccessMessage(t.datingBoostActive, Colors.amber);
      return;
    }

    final docSnapshot = await firestore
        .collection('dating_profiles')
        .where('userId', isEqualTo: _currentUserId)
        .limit(1)
        .get();
    if (docSnapshot.docs.isEmpty || !mounted) return;
    final profileDoc = docSnapshot.docs.first;

    final nowDateTime = DateTime.now();
    final todayStart = DateTime(nowDateTime.year, nowDateTime.month, nowDateTime.day).millisecondsSinceEpoch;
    final lastFreeBoost = profileDoc.data()['lastFreeBoostDate'] as int? ?? 0;
    final isGold = _subscriptionPlan == 'gold';
    final canUseFreeBoost = isGold && lastFreeBoost < todayStart;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.of(context).surface,
        title: Row(
          children: [
            const Icon(Icons.rocket_launch, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text(t.datingBoostTitle, style: TextStyle(color: AppColors.of(context).textPrimary))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.datingBoostDescription, style: TextStyle(color: AppColors.of(context).textSecondary)),
              const SizedBox(height: 8),
              if (canUseFreeBoost)
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _activateBoost(profileDoc.reference, todayStart, free: true);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    child: Text(t.datingBoostUseFree),
                  ),
                )
              else if (isGold)
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    child: Text(t.datingBoostFreeToday),
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _activateBoost(profileDoc.reference, todayStart, free: false);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
                  child: Text(t.datingBoostBuy.replaceAll('{price}', '$_boostCostCoins')),
                ),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.rocket_launch, color: Colors.deepOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.datingLongBoostTitle,
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.of(context).textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(t.datingLongBoostDescription, style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              ..._longBoostPricesCoins.entries.map((entry) {
                final days = entry.key;
                final price = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _activateLongBoost(profileDoc.reference, days, price);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      side: BorderSide(color: Colors.deepOrange.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_longBoostLabel(t, days), style: TextStyle(color: AppColors.of(context).textPrimary)),
                        Text('$price 🪙', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.datingCancel)),
        ],
      ),
    );
  }

  /// Libellé d'affichage pour une durée de boost longue (en jours).
  String _longBoostLabel(AppLocalizations t, int days) {
    switch (days) {
      case 1:
        return t.datingBoost1Day;
      case 7:
        return t.datingBoost1Week;
      case 21:
        return t.datingBoost3Weeks;
      case 30:
        return t.datingBoost1Month;
      case 90:
        return t.datingBoost3Months;
      case 180:
        return t.datingBoost6Months;
      default:
        return '$days j';
    }
  }

  /// Active un boost longue durée (payant) : badge "Boosté" + visibilité
  /// accrue dans le feed pendant [days] jours, pour [priceCoins] pièces.
  Future<void> _activateLongBoost(DocumentReference profileRef, int days, int priceCoins) async {
    final t = AppLocalizations.of(context);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final now = DateTime.now().millisecondsSinceEpoch;
    final boostUntil = now + days * 24 * 60 * 60 * 1000;

    try {
      final userId = authProvider.loginUserData.id;
      final userRef = firestore.collection('Users').doc(userId);
      await firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final currentBalance = userDoc.data()?['coinsBalance'] ?? 0;
        if (currentBalance < priceCoins) {
          throw Exception('insufficient_balance');
        }
        transaction.update(userRef, {
          'coinsBalance': currentBalance - priceCoins,
          'totalCoinsSpent': FieldValue.increment(priceCoins),
        });
        transaction.update(profileRef, {
          'boostUntil': boostUntil,
          'updatedAt': now,
        });
        final transactionId = firestore.collection('user_coin_transactions').doc().id;
        transaction.set(
          firestore.collection('user_coin_transactions').doc(transactionId),
          {
            'id': transactionId,
            'userId': userId,
            'type': 'spend_long_boost',
            'coinsAmount': -priceCoins,
            'xofAmount': priceCoins * 2.5,
            'referenceId': profileRef.id,
            'description': 'Boost de profil Dating ($days j)',
            'status': 'success',
            'createdAt': now,
            'updatedAt': now,
          },
        );
      });
      await authProvider.refreshUserData();

      if (mounted) {
        setState(() {
          _currentUserProfile = _currentUserProfile?.copyWith(boostUntil: boostUntil);
        });
        _showSuccessMessage(t.datingBoostActivated, Colors.amber);
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('insufficient_balance')) {
          _showInsufficientCoinsForBoostDialog(priceCoins);
        } else {
          print('❌ Erreur activation boost longue durée: $e');
        }
      }
    }
  }

  /// Active le boost (gratuit ou payant) sur le profil de l'utilisateur courant.
  Future<void> _activateBoost(DocumentReference profileRef, int todayStart, {required bool free}) async {
    final t = AppLocalizations.of(context);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final now = DateTime.now().millisecondsSinceEpoch;
    final boostUntil = now + _boostDurationMs;

    try {
      if (free) {
        await profileRef.update({
          'boostUntil': boostUntil,
          'lastFreeBoostDate': todayStart,
          'updatedAt': now,
        });
      } else {
        final userId = authProvider.loginUserData.id;
        final userRef = firestore.collection('Users').doc(userId);
        await firestore.runTransaction((transaction) async {
          final userDoc = await transaction.get(userRef);
          final currentBalance = userDoc.data()?['coinsBalance'] ?? 0;
          if (currentBalance < _boostCostCoins) {
            throw Exception('insufficient_balance');
          }
          transaction.update(userRef, {
            'coinsBalance': currentBalance - _boostCostCoins,
            'totalCoinsSpent': FieldValue.increment(_boostCostCoins),
          });
          transaction.update(profileRef, {
            'boostUntil': boostUntil,
            'updatedAt': now,
          });
          final transactionId = firestore.collection('user_coin_transactions').doc().id;
          transaction.set(
            firestore.collection('user_coin_transactions').doc(transactionId),
            {
              'id': transactionId,
              'userId': userId,
              'type': 'spend_boost',
              'coinsAmount': -_boostCostCoins,
              'xofAmount': _boostCostCoins * 2.5,
              'referenceId': profileRef.id,
              'description': 'Boost de profil Dating',
              'status': 'success',
              'createdAt': now,
              'updatedAt': now,
            },
          );
        });
        await authProvider.refreshUserData();
      }

      if (mounted) {
        setState(() {
          _currentUserProfile = _currentUserProfile?.copyWith(boostUntil: boostUntil);
        });
        _showSuccessMessage(t.datingBoostActivated, Colors.amber);
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('insufficient_balance')) {
          _showInsufficientCoinsForBoostDialog(_boostCostCoins);
        } else {
          print('❌ Erreur activation boost: $e');
        }
      }
    }
  }

  /// Modal incitant l'utilisateur à découvrir la carte des profils à proximité.
  void _showMapDiscoveryDialog() {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.of(context).surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.red.shade400, Colors.pink.shade400]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.map, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                t.datingDiscoverMapTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.of(context).textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                t.datingDiscoverMapMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.of(context).textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t.datingMaybeLater),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DatingMapPage(
                              profiles: _profiles,
                              myLatitude: _currentUserProfile?.latitude,
                              myLongitude: _currentUserProfile?.longitude,
                              subscriptionPlan: _subscriptionPlan,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(t.datingViewMap, style: const TextStyle(color: Colors.white)),
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

  // ---------- Actions de swipe ----------
  /// Retourne `true` si le swipe (pass) a bien été pris en compte — l'appelant
  /// déclenche alors l'animation de sortie de la carte vers la gauche.
  bool _handleSwipeLeft() {
    if (_isSwiping || _currentIndex >= _profiles.length) return false;
    if (!_canSwipe()) return false;
    _isSwiping = true;
    final profile = _profiles[_currentIndex];
    _lastSwipeType = 'pass';
    _consumeSwipe();
    _passProfile(profile.userId); // persister le "pass" dans Firestore
    Future.delayed(const Duration(milliseconds: 300), () => _isSwiping = false);
    return true;
  }

  /// Sauvegarde un "pass" dans Firestore et l'ajoute immédiatement au set
  /// local `_passedUserIds` pour que le profil soit exclu dès maintenant.
  Future<void> _passProfile(String profileUserId) async {
    if (_currentUserId == null || profileUserId.isEmpty) return;
    _passedUserIds.add(profileUserId); // exclusion immédiate en mémoire
    _cachedPassedUserIds.add(profileUserId); // mise à jour du cache statique
    try {
      await firestore.collection('dating_passes').add({
        'fromUserId': _currentUserId,
        'toUserId': profileUserId,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('⚠️ _passProfile error: $e');
    }
  }

  /// Retourne `true` si le like a bien été pris en compte — l'appelant
  /// déclenche alors l'animation de sortie de la carte vers la droite.
  bool _handleSwipeRight() {
    if (_isSwiping || _currentIndex >= _profiles.length) return false;
    if (_remainingLikes != -1 && _remainingLikes <= 0) {
      _showUpgradeDialog(type: 'like');
      return false;
    }
    if (!_canSwipe()) return false;
    _isSwiping = true;
    final profile = _profiles[_currentIndex];
    _likeCount++;
    _history.add(profile);
    _lastSwipeType = 'like';
    _consumeSwipe();
    if (_remainingLikes != -1) {
      setState(() => _remainingLikes--);
      _decrementRemaining('remainingLikes');
    }

    _processLike(profile);
    if (_likeCount >= _likeCountThreshold) {
      _likeCount = 0;
      _showLikedProfilesPremiumDialog();
    }
    Future.delayed(const Duration(milliseconds: 300), () => _isSwiping = false);
    return true;
  }

  /// Retourne `true` si le super like a bien été pris en compte — l'appelant
  /// déclenche alors l'animation de sortie de la carte vers le haut.
  bool _handleSuperLike() {
    if (_isSwiping || _currentIndex >= _profiles.length) return false;
    if (_remainingSuperLikes <= 0) {
      _showUpgradeDialog(type: 'superlike');
      return false;
    }
    if (!_canSwipe()) return false;
    _isSwiping = true;
    final profile = _profiles[_currentIndex];
    _lastSwipeType = 'superlike';
    _consumeSwipe();
    setState(() => _remainingSuperLikes--);
    _decrementRemaining('remainingSuperLikes');
    _processSuperLike(profile);
    Future.delayed(const Duration(milliseconds: 300), () => _isSwiping = false);
    return true;
  }

  Future<void> _processLike(DatingProfile profile) async {
    final t = AppLocalizations.of(context);
    try {
      // Vérifier si on a déjà liké ce profil pour éviter les doublons
      final existingLike = await firestore
          .collection('dating_likes')
          .where('fromUserId', isEqualTo: _currentUserId)
          .where('toUserId', isEqualTo: profile.userId)
          .limit(1)
          .get();

      if (existingLike.docs.isEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final likeId = firestore.collection('dating_likes').doc().id;
        await firestore.collection('dating_likes').doc(likeId).set({
          'id': likeId,
          'fromUserId': _currentUserId,
          'toUserId': profile.userId,
          'createdAt': now,
        });

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
      }

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
            _showSuccessMessage(t.datingAlreadyInContactWith.replaceAll('{pseudo}', profile.pseudo), Colors.orange);
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
            t.datingDoesNotMatchCriteria.replaceAll('{pseudo}', profile.pseudo),
            Colors.orange,
          );
        }
      } else {
        await _sendNotification(
          toUserId: profile.userId,
          message: "Afrolove❤️ @${_getCurrentUserPseudo()} vous a liké !",
          type: 'like',
        );
        _showSuccessMessage(t.datingYouLiked.replaceAll('{pseudo}', profile.pseudo), Colors.green);
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

  /// Vérifie si le profil 'target' correspond aux critères de recherche de 'user'
  /// (genre recherché ET tranche d'âge recherchée)
  bool _isMatching(DatingProfile user, DatingProfile target) {
    // Vérification du genre recherché ('homme', 'femme' ou 'tous')
    final rechercheSexe = user.rechercheSexe;
    if (rechercheSexe != 'tous' && rechercheSexe != target.sexe) {
      return false;
    }

    // Vérification de la tranche d'âge recherchée
    if (user.rechercheAgeMin > 0 && user.rechercheAgeMax > 0) {
      if (target.age < user.rechercheAgeMin || target.age > user.rechercheAgeMax) {
        return false;
      }
    }

    return true;
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
    final t = AppLocalizations.of(context);
    if (alreadyMatched) {
      _showSuccessMessage(t.datingAlreadyInContactWith.replaceAll('{pseudo}', profile.pseudo), Colors.orange);
      return;
    }

    // 3. Le quota a déjà été décrémenté par _handleSuperLike : envoyer le super like.
    await _sendSuperLike(profile);
  }
  Future<void> _sendSuperLike(DatingProfile profile) async {
    final t = AppLocalizations.of(context);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

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

      _showSuccessMessage(t.datingSuperLikeSentTo.replaceAll('{pseudo}', profile.pseudo), Colors.amber);
    } catch (e) {
      print('❌ Erreur super like: $e');
      _showSuccessMessage(t.datingErrorSending, Colors.red);
    }
  }

  Future<bool> _checkMatchCompatibility(DatingProfile targetProfile) async {
    final t = AppLocalizations.of(context);
    if (_currentUserProfile == null) return false;
    // L'utilisateur courant recherche-t-il bien ce profil (genre + âge) ?
    bool currentAcceptsTarget = _isMatching(_currentUserProfile!, targetProfile);
    // Ce profil recherche-t-il bien l'utilisateur courant (genre + âge) ?
    bool targetAcceptsCurrent = _isMatching(targetProfile, _currentUserProfile!);
    if (!currentAcceptsTarget) {
      _showSuccessMessage(t.datingNotSearchingThisGender, Colors.orange);
      return false;
    }
    if (!targetAcceptsCurrent) {
      _showSuccessMessage(t.datingOtherNotSearchingYourGender, Colors.orange);
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
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.info_outline, color: Colors.white, size: 20), const SizedBox(width: 12), Expanded(child: Text(t.datingNoProfilesYet))]),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Quantité ajoutée par recharge à pièces, selon le type de quota.
  int _rechargeAmount(String type) {
    switch (type) {
      case 'swipe':
        return 5;
      case 'like':
        return 5;
      case 'superlike':
        return 1;
      default:
        return 0;
    }
  }

  /// Champ Firestore correspondant au quota rechargé.
  String _rechargeField(String type) {
    switch (type) {
      case 'swipe':
        return 'remainingSwipes';
      case 'like':
        return 'remainingLikes';
      case 'superlike':
        return 'remainingSuperLikes';
      default:
        return '';
    }
  }

  /// Coût en pièces d'une recharge de quota. Les membres Gold bénéficient
  /// d'une réduction de 50 % sur ces recharges (avantage de l'abonnement).
  int _rechargeCost(String type) {
    int base;
    switch (type) {
      case 'swipe':
        base = 30;
        break;
      case 'like':
        base = 60;
        break;
      case 'superlike':
        base = 80;
        break;
      default:
        base = 0;
    }
    return _subscriptionPlan == 'gold' ? (base / 2).round() : base;
  }

  /// Recharge le quota quotidien (`type` = 'swipe'/'like'/'superlike') en
  /// échange de pièces, lorsque la limite du plan est épuisée.
  Future<void> _rechargeQuota(String type) async {
    if (_currentUserId == null) return;
    final t = AppLocalizations.of(context);
    final field = _rechargeField(type);
    if (field.isEmpty) return;

    final amount = _rechargeAmount(type);
    final cost = _rechargeCost(type);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;

    if (currentCoins < cost) {
      Navigator.pop(context);
      _showInsufficientCoinsDialog();
      return;
    }

    try {
      await firestore.collection('Users').doc(_currentUserId).update({
        'coinsBalance': FieldValue.increment(-cost),
        'totalCoinsSpent': FieldValue.increment(cost),
      });
      await _adjustRemaining(field, amount);
      setState(() {
        switch (type) {
          case 'swipe':
            _remainingSwipes += amount;
            break;
          case 'like':
            _remainingLikes += amount;
            break;
          case 'superlike':
            _remainingSuperLikes += amount;
            break;
        }
      });
      await authProvider.refreshUserData();
      if (mounted) {
        Navigator.pop(context);
        _showSuccessMessage(t.datingRechargeSuccess.replaceAll('{amount}', '$amount'), Colors.green);
      }
    } catch (e) {
      print('❌ Erreur recharge $type: $e');
    }
  }

  void _showUpgradeDialog({required String type}) {
    final t = AppLocalizations.of(context);
    // type = 'like', 'superlike', 'swipe', 'rewind', 'whoLikedMe', 'directMessage' ou 'boost'
    final isLike = type == 'like';
    final isSwipeLimit = type == 'swipe';
    final isRewind = type == 'rewind';

    showDialog(
      context: context,
      barrierDismissible: false, // Empêche la fermeture pendant le chargement
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isRewind ? t.datingRewindPremiumOnly : (isSwipeLimit ? t.datingNoMoreSwipes : (isLike ? t.datingLimitLikesReached : t.datingNoMoreSuperLikes)),
              style: TextStyle(color: isLike || isSwipeLimit || isRewind ? Colors.red : Colors.amber),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isRewind ? Icons.replay : (isSwipeLimit ? Icons.swipe : (isLike ? Icons.favorite : Icons.star)), size: 50, color: isLike || isSwipeLimit || isRewind ? Colors.red : Colors.amber),
                const SizedBox(height: 16),
                Text(
                  isRewind ? t.datingRewindPremiumOnly : (isSwipeLimit ? t.datingNoMoreSwipes : (isLike ? t.datingUsedAllFreeLikes : t.datingNoMoreFreeSuperLikesToday)),
                  textAlign: TextAlign.center,
                ),
                if (isSwipeLimit) ...[
                  const SizedBox(height: 8),
                  Text(
                    t.datingNextSwipeIn.replaceAll('{time}', _formatTimeUntilNextReset()),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ],
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
                      Text(t.datingSolutionsTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        t.datingUpgradeGoldUnlimited,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (!isRewind && _rechargeField(type).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(t.datingRechargeOr, style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _rechargeQuota(type),
                    icon: const Icon(Icons.monetization_on, color: Colors.amber),
                    label: Text(
                      '${t.datingRechargeButton.replaceAll('{cost}', '${_rechargeCost(type)}')}\n'
                      '${(isSwipeLimit ? t.datingRechargeDescriptionSwipe : (isLike ? t.datingRechargeDescriptionLike : t.datingRechargeDescriptionSuperlike)).replaceAll('{amount}', '${_rechargeAmount(type)}')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.amber),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(t.datingLaterButton),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DatingSubscriptionPage()));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(t.datingSeeOffers, style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
  /// Affiche un modal invitant l'utilisateur à recharger ses pièces lorsque
  /// son solde est insuffisant pour activer un boost de profil.
  void _showInsufficientCoinsForBoostDialog(int requiredCoins) {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.datingInsufficientBalance),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              t.datingBoostCoinsNeeded.replaceAll('{coins}', '$requiredCoins'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.datingCancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => BuyCoinsPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: Text(t.datingBuyCoins),
          ),
        ],
      ),
    );
  }

  void _showInsufficientCoinsDialog() {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.datingInsufficientBalance),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            Text(t.datingNotEnoughCoinsSuperLike, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(t.datingCoinsRequired20, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.datingCancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => BuyCoinsPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: Text(t.datingBuyCoins),
          ),
        ],
      ),
    );
  }

  void _showMatchDialog(DatingProfile profile) {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: AppColors.of(context).surface,
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
              Text(t.datingItsAMatch, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
              const SizedBox(height: 8),
              Text(t.datingMutualLikeWith.replaceAll('{pseudo}', profile.pseudo), textAlign: TextAlign.center, style: TextStyle(color: AppColors.of(context).textPrimary)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t.datingContinue),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openChat(profile);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text(t.datingChatPrivately),
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


  void _showPremiumChatDialog(DatingProfile profile) {
    final isGold = _subscriptionPlan == 'gold';
    if (!isGold) {
      final t = AppLocalizations.of(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(t.datingChatPrivately, style: const TextStyle(color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 50, color: Colors.amber),
              const SizedBox(height: 16),
              Text(t.datingPrivateMessagingGoldOnly, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(t.datingUpgradeGoldForChat, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(t.datingLaterButton)),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => DatingSubscriptionPage()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: Text(t.datingSeeOffersTitleCase),
            ),
          ],
        ),
      );
      return;
    }
    _openChat(profile);
  }

  void _showLikedProfilesPremiumDialog() {
    final t = AppLocalizations.of(context);
    final isPremium = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: AppColors.of(context).surface,
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
                t.datingLikedProfilesCount.replaceAll('{count}', '${_history.length}'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isPremium ? Colors.red.shade700 : Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Text(
                isPremium ? t.datingDiscoverLikedProfiles : t.datingLikedProfilesPremiumOnly,
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
                  label: Text(t.datingViewMyLikes.replaceAll('{count}', '${_history.length}'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  child: Text(t.datingContinueSwiping, style: TextStyle(color: Colors.grey.shade600)),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DatingSubscriptionPage()));
                  },
                  icon: const Icon(Icons.star, size: 18, color: Colors.black),
                  label: Text(t.datingUnlockPremium, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
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
                  child: Text(t.datingContinueSwiping, style: TextStyle(color: Colors.grey.shade600)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------- UI ----------
  static const double _swipeThreshold = 100.0;
  static const double _superLikeThreshold = 120.0;
  bool _hapticTriggered = false;

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isSwiping) return;
    final newOffset = _dragOffset + details.delta;
    setState(() {
      _dragOffset = newOffset;
      _rotationAngle = _dragOffset.dx / 500;
      _opacity = 1.0 - (_dragOffset.dx.abs() / 500).clamp(0.0, 1.0);
    });

    // Petit retour haptique au moment où le swipe dépasse le seuil de décision
    final crossedThreshold = _dragOffset.dx.abs() > _swipeThreshold ||
        (_dragOffset.dy < -_superLikeThreshold && _dragOffset.dy.abs() > _dragOffset.dx.abs());
    if (crossedThreshold && !_hapticTriggered) {
      _hapticTriggered = true;
      HapticFeedback.selectionClick();
    } else if (!crossedThreshold) {
      _hapticTriggered = false;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _hapticTriggered = false;

    if (_isSwiping) {
      _animateCardBack();
      return;
    }

    final size = MediaQuery.of(context).size;
    final isVerticalSuperLike = _dragOffset.dy < -_superLikeThreshold &&
        _dragOffset.dy.abs() > _dragOffset.dx.abs();

    if (isVerticalSuperLike) {
      if (_handleSuperLike()) {
        HapticFeedback.mediumImpact();
        _animateCardOff(Offset(_dragOffset.dx, -size.height * 1.2), _rotationAngle);
      } else {
        _animateCardBack();
      }
    } else if (_dragOffset.dx.abs() > _swipeThreshold) {
      final goRight = _dragOffset.dx > 0;
      final proceeded = goRight ? _handleSwipeRight() : _handleSwipeLeft();
      if (proceeded) {
        HapticFeedback.mediumImpact();
        _animateCardOff(
          Offset(goRight ? size.width * 1.5 : -size.width * 1.5, _dragOffset.dy),
          goRight ? 0.6 : -0.6,
        );
      } else {
        _animateCardBack();
      }
    } else {
      _animateCardBack();
    }
  }

  /// Anime la carte courante hors de l'écran vers [target] (avec rotation [rotation])
  /// puis passe au profil suivant une fois l'animation terminée.
  void _animateCardOff(Offset target, double rotation) {
    _animFrom = _dragOffset;
    _animTo = target;
    _animRotFrom = _rotationAngle;
    _animRotTo = rotation;
    _animOpacityFrom = _opacity;
    _animOpacityTo = 0.0;
    _animIsExit = true;
    _cardAnimController.forward(from: 0);
  }

  /// Ramène la carte courante à sa position d'origine (swipe annulé / sous le seuil).
  void _animateCardBack() {
    _animFrom = _dragOffset;
    _animTo = Offset.zero;
    _animRotFrom = _rotationAngle;
    _animRotTo = 0.0;
    _animOpacityFrom = _opacity;
    _animOpacityTo = 1.0;
    _animIsExit = false;
    _cardAnimController.forward(from: 0);
  }

  void _onCardAnimTick() {
    final t = Curves.easeOut.transform(_cardAnimController.value);
    setState(() {
      _dragOffset = Offset.lerp(_animFrom, _animTo, t)!;
      _rotationAngle = _animRotFrom + (_animRotTo - _animRotFrom) * t;
      _opacity = _animOpacityFrom + (_animOpacityTo - _animOpacityFrom) * t;
    });
    if (_cardAnimController.status == AnimationStatus.completed) {
      final wasExit = _animIsExit;
      _cardAnimController.reset();
      setState(() {
        _dragOffset = Offset.zero;
        _rotationAngle = 0.0;
        _opacity = 1.0;
      });
      if (wasExit) {
        _nextProfile();
      }
    }
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

  void _showDiscoverChoiceDialog() {
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  t.datingDiscoverChoiceTitle,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.of(context).textPrimary),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.map, color: Colors.red),
                ),
                title: Text(t.datingDiscoverChoiceMap, style: TextStyle(color: AppColors.of(context).textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text(t.datingDiscoverChoiceMapSubtitle, style: TextStyle(color: AppColors.of(context).textSecondary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DatingMapPage(
                        profiles: _profiles,
                        myLatitude: _currentUserProfile?.latitude,
                        myLongitude: _currentUserProfile?.longitude,
                        subscriptionPlan: _subscriptionPlan,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.view_list, color: Colors.red),
                ),
                title: Text(t.datingDiscoverChoiceList, style: TextStyle(color: AppColors.of(context).textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text(t.datingDiscoverChoiceListSubtitle, style: TextStyle(color: AppColors.of(context).textSecondary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DatingExplorePage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final hasSubscription = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');
    final showEmptyState = _profiles.isEmpty && !_isLoading;

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: AppBar(
        titleSpacing: 0,

        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              const Text('Afro Love', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade600, Colors.pink.shade400],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.rocket_launch,
              color: (_currentUserProfile?.isBoosted ?? false) ? Colors.amber : Colors.white,
            ),
            tooltip: t.datingBoostTitle,
            onPressed: _showBoostDialog,
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined, color: Colors.white),
            tooltip: 'Carte des profils',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DatingMapPage(
                    profiles: _profiles,
                    myLatitude: _currentUserProfile?.latitude,
                    myLongitude: _currentUserProfile?.longitude,
                    subscriptionPlan: _subscriptionPlan,
                  ),
                ),
              );
            },
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DatingSubscriptionPage()));
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Icon(Icons.style, size: 14, color: Colors.lightBlueAccent),
                  const SizedBox(width: 4),
                  Text(_remainingSwipes == -1 ? '∞' : '$_remainingSwipes', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Icon(Icons.favorite, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(_remainingLikes == -1 ? '∞' : '$_remainingLikes', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text('$_remainingSuperLikes', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  if (_subscriptionPlan != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      _subscriptionPlan == 'gold' ? Icons.diamond : (_subscriptionPlan == 'plus' ? Icons.workspace_premium : Icons.person),
                      size: 14,
                      color: _subscriptionPlan == 'gold' ? Colors.amber : Colors.white,
                    ),
                  ],
                ],
              ),
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
                  Text(t.datingFilters, style: const TextStyle(color: Colors.white, fontSize: 12)),
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
                  Icon(Icons.people_outline, size: 80, color: AppColors.of(context).textSecondary),
                  const SizedBox(height: 16),
                  Text(t.datingLoadingProfiles, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.of(context).textPrimary)),
                  const SizedBox(height: 8),
                  Text(t.datingPleaseWait, style: TextStyle(color: AppColors.of(context).textSecondary)),
                ],
              ),
            )
          else if (_deckExhausted)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.celebration, size: 80, color: Colors.amber),
                    const SizedBox(height: 16),
                    Text(
                      t.datingDeckExhaustedTitle,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.of(context).textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.datingDeckExhaustedSubtitle,
                      style: TextStyle(color: AppColors.of(context).textSecondary, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: Text(t.datingRefresh),
                      onPressed: () async {
                        if (!mounted) return;
                        setState(() {
                          _deckExhausted = false;
                          _excludeInteracted = false; // réinclure les likés
                          _filtersRelaxed = false;
                          _hasMore = true;
                          _lastDocument = null;
                          _profiles = [];
                          _currentIndex = 0;
                        });
                        await _loadProfiles();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_profiles.isEmpty || _currentIndex >= _profiles.length)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 80, color: AppColors.of(context).textSecondary),
                    const SizedBox(height: 16),
                    Text(t.datingNoMoreProfilesNow, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.of(context).textPrimary)),
                    const SizedBox(height: 8),
                    Text(t.datingComeBackLater, style: TextStyle(color: AppColors.of(context).textSecondary)),
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
                      child: Text(t.datingRefresh),
                    ),
                  ],
                ),
              )
            else
              Stack(
                children: [
                  if (_currentIndex + 1 < _profiles.length)
                    Builder(builder: (_) {
                      // La carte suivante grossit légèrement au fur et à mesure du swipe (effet Tinder)
                      final dragProgress = (_dragOffset.distance / 300).clamp(0.0, 1.0);
                      final nextScale = 0.92 + (0.08 * dragProgress);
                      return Transform.scale(
                        scale: nextScale,
                        child: _buildProfileCard(_profiles[_currentIndex + 1], isNext: true),
                      );
                    }),
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

          if (_showFilters)
            Positioned(
              top: 60,
              left: 20,
              right: 20,
              child: Card(
                elevation: 4,
                color: AppColors.of(context).surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.datingFilters, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedGenderFilter,
                        decoration: InputDecoration(labelText: t.datingGender, border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'tous', child: Text(t.datingAll)),
                          DropdownMenuItem(value: 'femme', child: Text(t.datingWomen)),
                          DropdownMenuItem(value: 'homme', child: Text(t.datingMen)),
                        ],
                        onChanged: (value) => setState(() => _selectedGenderFilter = value!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedPopularityFilter,
                        decoration: InputDecoration(labelText: t.datingPopularity, border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'tous', child: Text(t.datingAll)),
                          DropdownMenuItem(value: 'populaire', child: Text(t.datingMostPopular)),
                          DropdownMenuItem(value: 'moins_populaire', child: Text(t.datingLeastPopular)),
                        ],
                        onChanged: (value) => setState(() => _selectedPopularityFilter = value!),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: t.datingAgeMin, border: const OutlineInputBorder()),
                              onChanged: (value) => _minAge = int.tryParse(value) ?? 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: t.datingAgeMax, border: const OutlineInputBorder()),
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
                              child: Text(t.datingCancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _applyFilters,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: Text(t.datingApply),
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
                      Text(t.datingLoadingMoreProfiles, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          if (_dragOffset.dy < -_superLikeThreshold * 0.4 && _dragOffset.dy.abs() > _dragOffset.dx.abs())
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: (_dragOffset.dy.abs() / _superLikeThreshold).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Text(
                      'SUPER LIKE',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
              ),
            )
          else if (_dragOffset.dx != 0)
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
                    _dragOffset.dx > 0 ? t.datingLike : t.datingPass,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: Offset(0, -2))],
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
                icon: Icons.replay,
                color: Colors.amber,
                onPressed: _rewindLastSwipe,
                size: 22,
              ),
              _buildActionButton(
                icon: Icons.close,
                color: Colors.red,
                onPressed: () {
                  if (_handleSwipeLeft()) {
                    final w = MediaQuery.of(context).size.width;
                    _animateCardOff(Offset(-w * 1.5, 0), -0.6);
                  }
                },
                size: 28,
              ),
              _buildActionButton(
                icon: Icons.star,
                color: Colors.amber,
                onPressed: () {
                  if (_handleSuperLike()) {
                    final h = MediaQuery.of(context).size.height;
                    _animateCardOff(Offset(0, -h * 1.2), 0.0);
                  }
                },
                size: 32,
              ),
              _buildActionButton(
                icon: Icons.favorite,
                color: Colors.green,
                onPressed: () {
                  if (_handleSwipeRight()) {
                    final w = MediaQuery.of(context).size.width;
                    _animateCardOff(Offset(w * 1.5, 0), 0.6);
                  }
                },
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
              label: t.datingMeetings,
              isSelected: true,
              onTap: () {},
            ),
            _buildBottomNavItem(
              icon: Icons.explore,
              label: t.datingDiscoverNav,
              isSelected: false,
              onTap: _showDiscoverChoiceDialog,
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
                  label: t.datingProfile,
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
    final inactiveColor = AppColors.of(context).textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: isSelected ? Colors.red.shade600 : inactiveColor),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.red.shade600 : inactiveColor)),
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

  /// Optimise les URLs de médias via le CDN configuré pour l'application.
  String _cdnUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return userProvider.convertToCdnUrl(url, userProvider.appDefaultData);
  }

  /// Photo stable par profil (indépendante de _currentIndex) : sinon la photo
  /// affichée pour un même profil change brusquement quand il passe de carte
  /// "suivante" à carte "courante", donnant l'impression que la page se
  /// rafraîchit et affiche d'autres profils/images à chaque swipe.
  String _displayImageUrlFor(DatingProfile profile) {
    return _cdnUrl(profile.photosUrls.isNotEmpty
        ? profile.photosUrls[profile.userId.hashCode.abs() % profile.photosUrls.length]
        : profile.imageUrl);
  }

  Widget _buildProfileCard(DatingProfile profile, {required bool isNext}) {
    final t = AppLocalizations.of(context);
    final hasSubscription = _subscriptionPlan != null && (_subscriptionPlan == 'plus' || _subscriptionPlan == 'gold');
    final displayImageUrl = _displayImageUrlFor(profile);

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
              child: CachedNetworkImage(
                imageUrl: displayImageUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => Container(
                  color: Colors.grey.shade300,
                  child: Icon(Icons.person, size: 80, color: Colors.grey.shade400),
                ),
                errorWidget: (_, __, ___) => Container(
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
            if (profile.isBoosted)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.amber.shade600, Colors.orange.shade600]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Text(
                    t.datingBoostedBadge,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
                      child: Text(t.datingIncompleteProfile, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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