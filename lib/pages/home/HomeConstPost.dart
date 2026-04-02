import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/canaux/listCanal.dart';
import 'package:afrotok/pages/challenge/postChallengeWidget.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/home/unitePostPage/chronique_section.dart';
import 'package:flutter/material.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:skeletonizer/skeletonizer.dart';

import '../../services/utils/abonnement_utils.dart';
import '../UserServices/ServiceWidget.dart';

import '../admin/AfrolookPub/advertisementCarouselWidget.dart';
import '../afroshop/marketPlace/acceuil/home_afroshop.dart';
import '../afroshop/marketPlace/component.dart';

import '../auth/authTest/Screens/updateUserData.dart';
import '../chronique/chroniqueform.dart';
import '../component/showUserDetails.dart';
import '../../providers/afroshop/authAfroshopProvider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/authProvider.dart';
import 'package:shimmer/shimmer.dart';
import '../dating/widgets/top_dating_profiles_widget.dart';
import '../listeUserLikepage.dart';
import '../postDetailsVideo.dart';
import '../pronostics/pronostics_carousel_widget.dart';
import '../pub/banner_ad_widget.dart';
import '../pub/native_ad_widget.dart';
import '../pub/rewarded_interstitial_ad_widget.dart';
import '../user/userAbonnementPage.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../providers/mixed_feed_service_provider.dart';
import 'dart:typed_data';

import '../userPosts/youTube_video_card.dart';


// Constantes de couleur
const Color primaryGreen = Color(0xFF25D366);
const Color darkBackground = Color(0xFF121212);
const Color lightBackground = Color(0xFF1E1E1E);
const Color textColor = Colors.white;
const Color accentYellow = Color(0xFFFFD700);

class HomeConstPostPage extends StatefulWidget {
  final String type;
  final String? sortType;
  final bool isVideoPage; // Nouvelle variable avec défaut false


  HomeConstPostPage({super.key, required this.type, this.sortType,    this.isVideoPage = false, // valeur par défaut
  });

  @override
  State<HomeConstPostPage> createState() => _HomeConstPostPageState();
}

class _HomeConstPostPageState extends State<HomeConstPostPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Providers
  late UserAuthProvider authProvider;
  late UserShopAuthProvider authProviderShop;
  late CategorieProduitProvider categorieProduitProvider;
  late UserProvider userProvider;
  late PostProvider postProvider;
  late MixedFeedServiceProvider mixedFeedProvider;
   String HAS_SEEN_VIDEO_PAGE_KEY = 'has_seen_video_quality_page';

  // Contrôleurs
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();

  // Variables d'état pour les posts
  List<Post> _posts = [];
  bool _isLoadingPosts = true;
  bool _hasErrorPosts = false;
  bool _isLoadingMorePosts = false;
  bool _hasMorePosts = true;
  bool _isLoadingBackground = false;

  // Système hybride de chargement
  DocumentSnapshot? _lastCountryDocument;
  DocumentSnapshot? _lastAllDocument;
  DocumentSnapshot? _lastOtherDocument;
  Set<String> _loadedPostIds = Set();
  int _totalPostsLoaded = 0;
  int _backgroundPostsLoaded = 0; // Compteur des posts chargés en background
  final int _initialLimit = 4; // Premier chargement: 4 posts
  final int _backgroundLoadLimit = 5; // Chargement background: 5 posts
  final int _manualLoadLimit = 5; // Chargement manuel: 5 posts
  final int _maxBackgroundPosts = 20; // MAX posts en background
  final int _maxTotalPosts = 1000; // Limite totale
  Timer? _backgroundLoadTimer;
  bool _useBackgroundLoading = true; // Active/désactive le chargement background

  // Filtrage par pays
  String? _selectedCountryCode;
  String _currentFilter = 'MIXED'; // 'ALL', 'COUNTRY', 'MIXED', 'CUSTOM'
  // String _currentFilter = 'ALL'; // 'ALL', 'COUNTRY', 'MIXED', 'CUSTOM'
  bool _isFirstLoad = true;


  // Données supplémentaires - chargement séparé
  List<ArticleData> _articles = [];
  bool _isLoadingArticles = false;

  List<Canal> _canaux = [];
  bool _isLoadingCanaux = false;

  List<UserData> _suggestedUsers = [];
  bool _isLoadingSuggestedUsers = false;
  Timer? _stayTimer;
  bool _isPageVisible = true;
  bool _isSupportDialogShowing = false;
  String? _lastPopupDateKey = 'last_support_ad_popup_date';
  // Chroniques
  List<Chronique> _chroniques = [];
  bool _isLoadingChroniques = false;
  Map<String, List<Chronique>> _groupedChroniques = {};
  final Map<String, Uint8List> _videoThumbnails = {};
  final Map<String, bool> _userVerificationStatus = {};
  final Map<String, UserData> _userDataCache = {};

  // Gestion de visibilité
  final Map<String, Timer> _visibilityTimers = {};
  final Map<String, bool> _postsViewedInSession = {};

  // Animation
  late AnimationController _starController;
  late AnimationController _unlikeController;

  // Utilitaires
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late SharedPreferences _prefs;
  final String _lastViewDatePrefix = 'last_view_date_';

// 🔥 NOUVELLE MÉTHODE
  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }
  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
    checkAndRedirectToVideoPage(context);
    // Initialisation des providers
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    authProviderShop = Provider.of<UserShopAuthProvider>(context, listen: false);
    categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);

    // Configuration initiale
    _initializeAnimations();
    _setupScrollController();
    _setupLifecycleObservers();
    _initializeData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStayTimer();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _visibilityTimers.forEach((key, timer) => timer.cancel());
    _backgroundLoadTimer?.cancel();
    _starController.dispose();
    _unlikeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (_isPageVisible != isCurrent) {
      _isPageVisible = isCurrent;
      if (_isPageVisible) {
        _startStayTimer();
      } else {
        _stopStayTimer();
      }
    }
  }
  Future<bool> _shouldStartTimer() async {
    if (_isUserPremium()) {
      print('⏱️ [Timer] Utilisateur premium → timer non démarré');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastPopupDateStr = prefs.getString(_lastPopupDateKey!);
    if (lastPopupDateStr != null) {
      final lastDate = DateTime.parse(lastPopupDateStr);
      final diffDays = DateTime.now().difference(lastDate).inDays;
      print('⏱️ [Timer] Dernière popup: $lastPopupDateStr, différence jours: $diffDays');
      if (diffDays < 2) {
        print('⏱️ [Timer] Délai de 2 jours non écoulé → timer non démarré');
        return false;
      }
    }

    print('⏱️ [Timer] Conditions OK : non premium et cooldown passé');
    return true;
  }
  void _startStayTimer() async {
    print('⏱️ [Timer] Démarrage demandé...');

    bool shouldStart = await _shouldStartTimer();
    if (!shouldStart) return;

    _stopStayTimer();
    _stayTimer = Timer(const Duration(seconds: 5), () {
      print('⏱️ [Timer] Timer déclenché après 5 secondes');
      _checkAndShowSupportPopup();
    });
    print('⏱️ [Timer] Timer démarré (10s)');
  }
  void _stopStayTimer() {
    if (_stayTimer != null && _stayTimer!.isActive) {
      _stayTimer!.cancel();
      print('⏱️ [Timer] Timer annulé');
    }
  }

  bool _isUserPremium() {
    final user = authProvider.loginUserData;
    if (user == null) {
      print('🔍 [Premium] Utilisateur null');
      return false;
    }
    final isPremium = AbonnementUtils.isPremiumActive(user.abonnement);
    print('🔍 [Premium] Abonnement utilisateur: ${user.abonnement} => isPremium = $isPremium');
    return isPremium;
  }

  Future<void> _checkAndShowSupportPopup() async {
    print('🔔 [Popup] Vérification des conditions...');
    if (!_isPageVisible) {
      print('🔔 [Popup] Page non visible → annulé');
      return;
    }
    if (_isSupportDialogShowing) {
      print('🔔 [Popup] Popup déjà en cours d\'affichage → annulé');
      return;
    }
    if (_isUserPremium()) {
      print('🔔 [Popup] Utilisateur premium → pas de popup');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastPopupDateStr = prefs.getString(_lastPopupDateKey!);
    print('🔔 [Popup] Dernière date enregistrée: $lastPopupDateStr');

    if (lastPopupDateStr != null) {
      final lastDate = DateTime.parse(lastPopupDateStr);
      final diffDays = DateTime.now().difference(lastDate).inDays;
      print('🔔 [Popup] Différence en jours: $diffDays');
      if (diffDays < 2) {
        print('🔔 [Popup] Cooldown actif (moins de 2 jours) → popup ignoré');
        return;
      }
    }

    // Enregistrer la date actuelle
    final nowStr = DateTime.now().toIso8601String();
    await prefs.setString(_lastPopupDateKey!, nowStr);
    print('🔔 [Popup] Date enregistrée: $nowStr');

    print('🔔 [Popup] Affichage du popup...');
    _showSupportDialog();
  }
  void _showSupportDialog() {
    _isSupportDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: darkBackground,
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        title: Row(
          children: [
            Icon(Icons.volunteer_activism, color: primaryGreen, size: 24),
            const SizedBox(width: 8),
            const Text('Soutenez Afrolook !', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chers membres, Afrolook grandit grâce à vous ! 🌍\n\n'
                  'Chaque publicité que vous regardez nous rapporte un petit revenu. Cela nous permet de :\n'
                  '• Améliorer l\'application et ajouter de nouvelles fonctionnalités\n'
                  '• Maintenir des serveurs stables pour une expérience fluide\n'
                  '• Continuer à vous offrir du contenu de qualité gratuitement\n'
                  '• Rémunérer les créateurs de contenu que vous aimez !\n\n'
                  'Ce n\'est pas obligatoire, mais votre soutien est précieux. Merci d\'avance ! 🙏',
              style: TextStyle(color: textColor, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: lightBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentYellow),
              ),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium, color: accentYellow, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Devenez Premium',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '200 F/mois 😊 • Plus aucune publicité',
                          style: TextStyle(color: accentYellow, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'Soutenez directement les créateurs de contenu !',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _isSupportDialogShowing = false;
            },
            child: const Text('Fermer', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _isSupportDialogShowing = false;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) =>  AbonnementScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentYellow,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('S\'abonner', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _isSupportDialogShowing = false;
              _showInterstitialAd();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Regarder la pub', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  void _showInterstitialAd() {
    _interstitialAdKey.currentState?.showAd();
    // Optional: show a thank‑you snackbar after ad dismisses
    // We'll do that inside the widget's callback in the build method.
  }
  void _setupScrollController() {
    _scrollController.addListener(_scrollListener);
  }

  void _setupLifecycleObservers() {
    WidgetsBinding.instance.addObserver(this);
    SystemChannels.lifecycle.setMessageHandler((message) {
      _handleAppLifecycle(message);
      return Future.value(message);
    });
  }

  void _initializeAnimations() {
    _starController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _unlikeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
  }

  void _initializeData() async {
    // 1. Détecter le pays de l'utilisateur
    _selectedCountryCode = authProvider.loginUserData.countryData?['countryCode']?.toUpperCase();
    print('Pays utilisateur détecté: ${_selectedCountryCode}');

    // 2. Par défaut: mode "Tous les pays"
    _currentFilter = 'MIXED';
    // _currentFilter = 'ALL';
    _isFirstLoad = true;
    _useBackgroundLoading = true; // Activer le chargement background initial
    _backgroundPostsLoaded = 0; // Réinitialiser le compteur

    // 3. Réinitialiser et charger les posts initiaux (3 posts)
    _resetPagination();
    await _loadInitialPosts();

    // 4. Démarrer le chargement background (si activé)
    _startBackgroundLoading();

    // 5. Charger les autres données EN PARALLÈLE (non bloquant)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllAdditionalDataInParallel();
    });
  }

  void _resetPagination() {
    _posts.clear();
    _loadedPostIds.clear();
    _lastCountryDocument = null;
    _lastAllDocument = null;
    _lastOtherDocument = null;
    _totalPostsLoaded = 0;
    _backgroundPostsLoaded = 0;
    _hasMorePosts = true;
    _isLoadingMorePosts = false;
    _isLoadingBackground = false;
  }

  // ===========================================================================
  // SYSTÈME HYBRIDE DE CHARGEMENT (Background + Manuel)
  // ===========================================================================

  void _startBackgroundLoading() {
    if (!_useBackgroundLoading) return;

    // Arrêter tout timer existant
    _backgroundLoadTimer?.cancel();

    print('🚀 Démarrage du chargement background (max: $_maxBackgroundPosts posts)');

    // Démarrer un nouveau timer pour le chargement background
    _backgroundLoadTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      // Conditions pour charger en background :
      // 1. Background activé
      // 2. Pas déjà en cours de chargement background
      // 3. Pas de chargement manuel en cours
      // 4. Il reste des posts à charger
      // 5. On n'a pas dépassé la limite de background
      // 6. L'utilisateur ne scroll pas activement
      if (_useBackgroundLoading &&
          !_isLoadingBackground &&
          !_isLoadingMorePosts &&
          _hasMorePosts &&
          _backgroundPostsLoaded < _maxBackgroundPosts &&
          _totalPostsLoaded < _maxTotalPosts &&
          !_isUserScrolling()) {

        await _loadBackgroundPosts();
      }

      // Arrêter le timer si :
      // 1. On a atteint la limite de background
      // 2. Il n'y a plus de posts à charger
      // 3. Le background est désactivé
      if (_backgroundPostsLoaded >= _maxBackgroundPosts ||
          !_hasMorePosts ||
          !_useBackgroundLoading) {
        print('⏹️ Arrêt du chargement background (posts background: $_backgroundPostsLoaded)');
        timer.cancel();
        _useBackgroundLoading = false; // Passer en mode manuel
      }
    });
  }

  bool _isUserScrolling() {
    return _scrollController.position.isScrollingNotifier.value;
  }

  Future<void> _loadBackgroundPosts() async {
    if (_isLoadingBackground ||
        !_hasMorePosts ||
        _backgroundPostsLoaded >= _maxBackgroundPosts ||
        _totalPostsLoaded >= _maxTotalPosts) {
      return;
    }

    print('🔄 Chargement background... ($_backgroundPostsLoaded/$_maxBackgroundPosts)');

    setState(() {
      _isLoadingBackground = true;
    });

    try {
      Set<String> loadedIds = Set.from(_loadedPostIds);
      List<Post> newPosts = [];

      await _loadMorePostsByFilter(loadedIds, newPosts, _backgroundLoadLimit);

      // Ajouter les nouveaux posts à la liste
      if (newPosts.isNotEmpty) {
        setState(() {
          _posts.addAll(newPosts);
          _loadedPostIds.addAll(newPosts.map((p) => p.id!));
          _totalPostsLoaded += newPosts.length;
          _backgroundPostsLoaded += newPosts.length;
        });

        print('✅ ${newPosts.length} posts chargés en background (total: $_totalPostsLoaded, background: $_backgroundPostsLoaded)');
      }

      // Vérifier s'il reste des posts à charger
      _hasMorePosts = newPosts.length >= (_backgroundLoadLimit ~/ 2);

      // Si on atteint la limite de background, désactiver
      if (_backgroundPostsLoaded >= _maxBackgroundPosts) {
        _useBackgroundLoading = false;
        print('📊 Passage en mode chargement manuel (limite background atteinte)');
      }

    } catch (e) {
      print('❌ Erreur chargement background: $e');
    } finally {
      setState(() {
        _isLoadingBackground = false;
      });
    }
  }

  // ===========================================================================
  // MODAL DE FILTRE PAR PAYS - VERSION AMÉLIORÉE
  // ===========================================================================

  void _showCountryFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final TextEditingController searchController = TextEditingController();
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Fonction pour mettre à jour la recherche
            void updateSearch(String query) {
              searchQuery = query.toLowerCase();
              setModalState(() {});
            }

            // Filtrer les pays
            List<AfricanCountry> filteredCountries = AfricanCountry.allCountries
                .where((country) {
              if (searchQuery.isEmpty) return true;
              return country.name.toLowerCase().contains(searchQuery) ||
                  country.code.toLowerCase().contains(searchQuery) ||
                  country.name?.toLowerCase().contains(searchQuery) == true;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: darkBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Poignée
                  Container(
                    height: 4,
                    width: 40,
                    margin: EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Titre et bouton fermer
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '🌍 Filtrer par pays',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey[400], size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Barre de recherche AMÉLIORÉE
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: Icon(Icons.search, color: Colors.grey[500], size: 20),
                          ),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              onChanged: updateSearch,
                              style: TextStyle(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Rechercher un pays...',
                                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          if (searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.clear, size: 18, color: Colors.grey[500]),
                              onPressed: () {
                                searchController.clear();
                                updateSearch('');
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Options rapides sur UNE SEULE LIGNE
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Option "Tous les pays"
                          _buildQuickFilterOption(
                            icon: Icons.public,
                            label: 'Tous',
                            isSelected: _currentFilter == 'ALL',
                            color: primaryGreen,
                            onTap: () async {
                              Navigator.pop(context);
                              await _applyFilter(filterType: 'ALL', countryCode: null);
                            },
                          ),
                          SizedBox(width: 8),

                          // Option "Mon pays"
                          if (_selectedCountryCode != null)
                            _buildQuickFilterOption(
                              icon: null,
                              label: 'Mon pays',
                              flag: _getCountryFlag(_selectedCountryCode!),
                              isSelected: _currentFilter == 'COUNTRY',
                              color: Colors.blue,
                              onTap: () async {
                                Navigator.pop(context);
                                await _applyFilter(filterType: 'COUNTRY', countryCode: _selectedCountryCode);
                              },
                            ),

                          if (_selectedCountryCode != null) SizedBox(width: 8),

                          // Option "Mix"
                          if (_selectedCountryCode != null)
                            _buildQuickFilterOption(
                              icon: Icons.blender,
                              label: 'Mix',
                              isSelected: _currentFilter == 'MIXED',
                              color: Colors.purple,
                              onTap: () async {
                                Navigator.pop(context);
                                await _applyFilter(filterType: 'MIXED', countryCode: _selectedCountryCode);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Séparateur
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Colors.grey[800], thickness: 1),
                  ),

                  // Titre liste pays
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Choisir un pays',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${filteredCountries.length} pays',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),

                  // Liste des pays avec recherche fonctionnelle
                  Expanded(
                    child: _buildCountryList(filteredCountries, searchQuery),
                  ),

                  // Bouton fermer
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Fermer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickFilterOption({
    IconData? icon,
    required String label,
    String? flag,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flag != null)
              Text(flag, style: TextStyle(fontSize: 16))
            else if (icon != null)
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[400]),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[300],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isSelected) SizedBox(width: 4),
            if (isSelected)
              Icon(Icons.check, size: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryList(List<AfricanCountry> countries, String searchQuery) {
    if (countries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.grey[600], size: 48),
            SizedBox(height: 12),
            Text(
              searchQuery.isEmpty ? 'Chargement...' : 'Aucun pays trouvé',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
            if (searchQuery.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Essayez une autre recherche',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: countries.length,
      itemBuilder: (context, index) {
        final country = countries[index];
        final isCurrentCountry = _selectedCountryCode?.toUpperCase() == country.code.toUpperCase();
        final isSelected = _currentFilter == 'CUSTOM' &&
            _selectedCountryCode?.toUpperCase() == country.code.toUpperCase();

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                Navigator.pop(context);
                await _applyFilter(
                  filterType: 'CUSTOM',
                  countryCode: country.code.toUpperCase(),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange.withOpacity(0.2) : Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.orange : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          country.flag,
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  country.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrentCountry)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Votre pays',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            country.code.toUpperCase(),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: Colors.orange, size: 22),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getCountryFlag(String countryCode) {
    try {
      final country = AfricanCountry.allCountries.firstWhere(
            (c) => c.code.toUpperCase() == countryCode.toUpperCase(),
        orElse: () => AfricanCountry(
          code: countryCode,
          name: countryCode,
          flag: '🏳️',
        ),
      );
      return country.flag;
    } catch (e) {
      return '🏳️';
    }
  }

  Future<void> _applyFilter({
    required String filterType,
    String? countryCode,
  }) async
  {
    // Arrêter le chargement background pendant le changement de filtre
    _backgroundLoadTimer?.cancel();

    setState(() {
      _currentFilter = filterType;
      if (countryCode != null) {
        _selectedCountryCode = countryCode.toUpperCase();
      }
      _isLoadingPosts = true;
      _isFirstLoad = true;
      _useBackgroundLoading = true; // Réactiver le background pour le nouveau filtre
      _backgroundPostsLoaded = 0; // Réinitialiser le compteur
    });

    // Réinitialiser la pagination
    _resetPagination();

    // Charger les posts initiaux (3 posts)
    await _loadInitialPosts();

    // Redémarrer le chargement background
    _startBackgroundLoading();

    setState(() {
      _isLoadingPosts = false;
    });

    print('✅ Filtre appliqué: $_currentFilter - Pays: $_selectedCountryCode');
  }

  // ===========================================================================
  // CHARGEMENT DES POSTS
  // ===========================================================================

  Future<void> _loadInitialPosts() async {
    try {
      if (authProvider.loginUserData.countryData?["countryCode"] == null&&authProvider.loginUserData.countryData?["country"] == null) {

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UpdateUserData(title: "Mise à jour d'adresse"),
          ),
        );

      }

        setState(() {
        _isLoadingPosts = true;
        _hasErrorPosts = false;
      });

      Set<String> loadedIds = Set();
      List<Post> newPosts = [];

      // Premier chargement: 3 posts seulement
      int limit = _initialLimit;
printVm("_currentFilter data: ${_currentFilter}");
      switch (_currentFilter) {
        case 'ALL':
          await _loadAllCountriesMixed(loadedIds, newPosts, limit);
          break;

        case 'COUNTRY':
          if (_selectedCountryCode != null) {
            await _loadCountrySpecificPosts(
              loadedIds,
              newPosts,
              _selectedCountryCode!,
              isInitialLoad: true,
              limit: limit,
            );

            // Compléter avec posts ALL si pas assez
            if (newPosts.length < limit) {
              await _loadAllCountriesPosts(
                loadedIds,
                newPosts,
                isInitialLoad: true,
                limit: limit - newPosts.length,
              );
            }
          }
          break;

        case 'MIXED':
          if (_selectedCountryCode != null) {
            await _loadMixedPostsSmart(loadedIds, newPosts, _selectedCountryCode!, limit);
          }
          break;

        case 'CUSTOM':
          if (_selectedCountryCode != null) {
            await _loadCountrySpecificPosts(
              loadedIds,
              newPosts,
              _selectedCountryCode!,
              isInitialLoad: true,
              limit: limit,
            );
          }
          break;
      }

      // Mettre à jour la liste des posts
      setState(() {
        _posts = newPosts;
        _loadedPostIds.addAll(loadedIds);
        _totalPostsLoaded = newPosts.length;
        _isFirstLoad = false;
      });

      print('✅ ${newPosts.length} posts chargés avec filtre: $_currentFilter');

    } catch (e) {
      print('❌ Erreur chargement posts: $e');
      setState(() {
        _hasErrorPosts = true;
      });
    } finally {
      setState(() {
        _isLoadingPosts = false;
      });
    }
  }

  // ===========================================================================
  // ALGORITHMES DE CHARGEMENT SPÉCIFIQUES
  // ===========================================================================

  Future<void> _loadAllCountriesMixed(Set<String> loadedIds, List<Post> newPosts, int limit) async {
    print('🌍 Chargement mode "Tous les pays" - limite: $limit');

    int attempts = 0;
    int maxAttempts = 3;

    while (newPosts.length < limit && attempts < maxAttempts) {
      // 1. Posts ALL (60%)
      if (newPosts.length < limit) {
        int needed = (limit * 0.6).ceil();
        await _loadAllCountriesPosts(
          loadedIds,
          newPosts,
          isInitialLoad: attempts == 0,
          limit: needed,
        );
      }

      // 2. Autres pays (40%)
      if (_selectedCountryCode != null && newPosts.length < limit) {
        int needed = limit - newPosts.length;
        await _loadOtherCountriesPosts(
          loadedIds,
          newPosts,
          excludeCountry: _selectedCountryCode!,
          isInitialLoad: attempts == 0,
          limit: needed,
        );
      }

      attempts++;
    }

    // Mélanger pour variété
    if (newPosts.length > 1) {
      newPosts.shuffle();
    }
  }

  Future<void> _loadMixedPostsSmart(Set<String> loadedIds, List<Post> newPosts, String userCountryCode, int limit) async {
    print('🔄 Chargement mode "Mix intelligent" - limite: $limit');

    // 1. Posts du pays utilisateur (40%)
    int countryPostsNeeded = (limit * 0.4).ceil();
    await _loadCountrySpecificPosts(
      loadedIds,
      newPosts,
      userCountryCode,
      isInitialLoad: true,
      limit: countryPostsNeeded,
    );

    // 2. Posts ALL (40%)
    // int allPostsNeeded = (limit * 0.4).ceil();
    // await _loadAllCountriesPosts(
    //   loadedIds,
    //   newPosts,
    //   isInitialLoad: true,
    //   limit: allPostsNeeded,
    // );

    // 3. Posts autres pays (60%)
    int otherPostsNeeded = limit - newPosts.length;
    if (otherPostsNeeded > 0) {
      await _loadOtherCountriesPosts(
        loadedIds,
        newPosts,
        excludeCountry: userCountryCode,
        isInitialLoad: true,
        limit: otherPostsNeeded,
      );
    }
  }

  Future<void> _loadCountrySpecificPosts(
      Set<String> loadedIds,
      List<Post> newPosts,
      String countryCode, {
        bool isInitialLoad = false,
        int limit = 5,
      }) async
  {
    if (limit <= 0) return;

    try {
      print('🎯 Chargement posts pays: $countryCode - limite: $limit');

      Query query = _firestore.collection('Posts');

      // Essayer différents noms de champs
      try {
        query = query.where("available_countries", arrayContains: countryCode);
      } catch (e) {
        try {
          query = query.where("availableCountries", arrayContains: countryCode);
        } catch (e2) {
          query = query.where("country", isEqualTo: countryCode);
        }
      }

      // 🔥 AJOUT : filtre vidéo si nécessaire
      if (widget.isVideoPage) {
        query = query.where("dataType", isEqualTo: PostDataType.VIDEO.name);
      }
// 🔹 Filtrer uniquement les posts non publicitaires
//       query = query.where("isAdvertisement", isEqualTo: false);
      query = query.orderBy("created_at", descending: true);

      if (!isInitialLoad && _lastCountryDocument != null) {
        query = query.startAfterDocument(_lastCountryDocument!);
      }

      query = query.limit(limit * 2);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastCountryDocument = snapshot.docs.last;
      }

      int added = 0;
      for (var doc in snapshot.docs) {
        if (added >= limit) break;

        try {
          final post = Post.fromJson(doc.data() as Map<String, dynamic>);
          post.id = doc.id;

          // ❌ Ignorer les pubs
          if (post.isAdvertisement == true) continue;

          if (!loadedIds.contains(post.id) && !_loadedPostIds.contains(post.id)) {
            post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
            loadedIds.add(post.id!);
            added++;

            // Séparer récents et anciens
            final now = DateTime.now().millisecondsSinceEpoch;
            final postTime = post.createdAt ?? 0;
            final differenceInHours = (now - postTime) ~/ (1000 * 60 * 60);

            if (differenceInHours < 24) {
              // Post récent (<24h) -> reste en tête
              newPosts.insert(0, post);
            } else {
              // Post ancien -> ajouter à la fin
              newPosts.add(post);
            }
          }
        } catch (e) {
          print('Erreur parsing post: $e');
        }
      }

// 🔀 Mélange séparé après ajout de tous les posts
      final now = DateTime.now().millisecondsSinceEpoch;
      List<Post> recentPosts = [];
      List<Post> oldPosts = [];

      for (var p in newPosts) {
        final pTime = p.createdAt ?? 0;
        final diffHours = (now - pTime) ~/ (1000 * 60 * 60);

        if (diffHours < 24) {
          recentPosts.add(p);
        } else {
          oldPosts.add(p);
        }
      }

// Mélanger chaque groupe
      recentPosts.shuffle();
      oldPosts.shuffle();

// Recomposer la liste finale
      newPosts
        ..clear()
        ..addAll(recentPosts)
        ..addAll(oldPosts);
      // for (var doc in snapshot.docs) {
      //   if (added >= limit) break;
      //
      //   try {
      //     final post = Post.fromJson(doc.data() as Map<String, dynamic>);
      //     post.id = doc.id;
      //
      //     if (!loadedIds.contains(post.id) && !_loadedPostIds.contains(post.id)) {
      //       post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
      //       newPosts.add(post);
      //       loadedIds.add(post.id!);
      //       added++;
      //       newPosts.shuffle();
      //
      //     }
      //   } catch (e) {
      //     print('Erreur parsing post: $e');
      //   }
      // }

      print('✅ $added posts du pays $countryCode ajoutés');

    } catch (e) {
      print('❌ Erreur chargement pays $countryCode: $e');
    }
  }

  Future<void> _loadAllCountriesPosts(
      Set<String> loadedIds,
      List<Post> newPosts, {
        bool isInitialLoad = false,
        int limit = 5,
      }) async {
    if (limit <= 0) return;

    try {
      print('🌐 Chargement posts ALL - limite: $limit');

      Query query = _firestore.collection('Posts')
          // .where("isAdvertisement", isEqualTo: false) // jamais récupérer les pubs
          .orderBy("created_at", descending: true);
      if (widget.isVideoPage) {
        query = query.where("dataType", isEqualTo: PostDataType.VIDEO.name);
      }
      if (!isInitialLoad && _lastAllDocument != null) {
        query = query.startAfterDocument(_lastAllDocument!);
      }

      query = query.limit(limit * 2);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastAllDocument = snapshot.docs.last;
      }

      int added = 0;

      for (var doc in snapshot.docs) {
        if (added >= limit) break;

        try {
          final post = Post.fromJson(doc.data() as Map<String, dynamic>);
          post.id = doc.id;

          // ❌ Ne pas ajouter si déjà chargé
          if (loadedIds.contains(post.id) || _loadedPostIds.contains(post.id)) continue;

          // ❌ Ne jamais ajouter une pub même si le champ manquait
          if (post.isAdvertisement == true) continue;

          post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
          loadedIds.add(post.id!);
          added++;

          // 🔹 Séparer récents et anciens
          final now = DateTime.now().millisecondsSinceEpoch;
          final postTime = post.createdAt ?? 0;
          final differenceInHours = (now - postTime) ~/ (1000 * 60 * 60);

          if (differenceInHours < 24) {
            newPosts.insert(0, post); // récent <24h en tête
          } else {
            newPosts.add(post); // ancien
          }

        } catch (e) {
          print('Erreur parsing post: $e');
        }
      }

      // 🔀 Mélange séparé des récents et anciens
      final now = DateTime.now().millisecondsSinceEpoch;
      List<Post> recentPosts = [];
      List<Post> oldPosts = [];

      for (var p in newPosts) {
        final pTime = p.createdAt ?? 0;
        final diffHours = (now - pTime) ~/ (1000 * 60 * 60);

        if (diffHours < 24) {
          recentPosts.add(p);
        } else {
          oldPosts.add(p);
        }
      }

      recentPosts.shuffle();
      oldPosts.shuffle();

      newPosts
        ..clear()
        ..addAll(recentPosts)
        ..addAll(oldPosts);

      print('✅ $added posts ALL ajoutés');

    } catch (e) {
      print('❌ Erreur chargement posts ALL: $e');
    }
  }
  Future<void> _loadOtherCountriesPosts(
      Set<String> loadedIds,
      List<Post> newPosts, {
        required String excludeCountry,
        bool isInitialLoad = false,
        int limit = 5,
      })
  async {
    if (limit <= 0) return;

    try {
      print('🌍 Chargement autres pays (exclure: $excludeCountry) - limite: $limit');

      // 🔹 Base query
      Query query = _firestore.collection('Posts')
          .orderBy("created_at", descending: true);
          // .where("isAdvertisement", isEqualTo: false); // jamais récupérer les pubs
      if (widget.isVideoPage) {
        query = query.where("dataType", isEqualTo: PostDataType.VIDEO.name);
      }
      if (!isInitialLoad && _lastOtherDocument != null) {
        query = query.startAfterDocument(_lastOtherDocument!);
      }

      query = query.limit(limit * 4);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastOtherDocument = snapshot.docs.last;
      }

      int added = 0;

      for (var doc in snapshot.docs) {
        if (added >= limit) break;

        try {
          final post = Post.fromJson(doc.data() as Map<String, dynamic>);
          post.id = doc.id;

          // ❌ Ne pas ajouter si déjà chargé
          if (loadedIds.contains(post.id) || _loadedPostIds.contains(post.id)) continue;

          // ❌ Ne jamais ajouter une pub même si le champ manquait
          if (post.isAdvertisement == true) continue;

          // ❌ Filtrer le pays exclu
          if (post.availableCountries.contains(excludeCountry)) continue;

          post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
          loadedIds.add(post.id!);
          added++;

          // 🔹 Séparer récents et anciens
          final now = DateTime.now().millisecondsSinceEpoch;
          final postTime = post.createdAt ?? 0;
          final differenceInHours = (now - postTime) ~/ (1000 * 60 * 60);

          if (differenceInHours < 24) {
            newPosts.insert(0, post); // récent <24h en tête
          } else {
            newPosts.add(post); // ancien
          }

        } catch (e) {
          print('Erreur parsing post: $e');
        }
      }

      // 🔀 Mélange séparé des récents et anciens
      final now = DateTime.now().millisecondsSinceEpoch;
      List<Post> recentPosts = [];
      List<Post> oldPosts = [];

      for (var p in newPosts) {
        final pTime = p.createdAt ?? 0;
        final diffHours = (now - pTime) ~/ (1000 * 60 * 60);

        if (diffHours < 24) {
          recentPosts.add(p);
        } else {
          oldPosts.add(p);
        }
      }

      recentPosts.shuffle();
      oldPosts.shuffle();

      newPosts
        ..clear()
        ..addAll(recentPosts)
        ..addAll(oldPosts);

      print('✅ $added posts autres pays ajoutés');

    } catch (e) {
      print('❌ Erreur chargement autres pays: $e');
    }
  }
  // Future<void> _loadOtherCountriesPosts(
  //     Set<String> loadedIds,
  //     List<Post> newPosts, {
  //       required String excludeCountry,
  //       bool isInitialLoad = false,
  //       int limit = 5,
  //     }) async
  // {
  //   if (limit <= 0) return;
  //
  //   try {
  //     print('🌍 Chargement autres pays (exclure: $excludeCountry) - limite: $limit');
  //
  //     Query query = _firestore.collection('Posts')
  //         .orderBy("created_at", descending: true);
  //
  //     if (!isInitialLoad && _lastOtherDocument != null) {
  //       query = query.startAfterDocument(_lastOtherDocument!);
  //     }
  //
  //     query = query.limit(limit * 4);
  //
  //     final snapshot = await query.get();
  //
  //     if (snapshot.docs.isNotEmpty) {
  //       _lastOtherDocument = snapshot.docs.last;
  //     }
  //
  //     int added = 0;
  //     for (var doc in snapshot.docs) {
  //       if (added >= limit) break;
  //
  //       try {
  //         final post = Post.fromJson(doc.data() as Map<String, dynamic>);
  //         post.id = doc.id;
  //
  //         if (loadedIds.contains(post.id) || _loadedPostIds.contains(post.id)) {
  //           continue;
  //         }
  //
  //         // Filtrer manuellement
  //         bool isExcluded = false;
  //
  //         // if (post.availableCountries.contains(excludeCountry)) {
  //         //   isExcluded = true;
  //         // }
  //         //
  //         // if (post.availableCountries.contains("ALL")) {
  //         //   isExcluded = true;
  //         // }
  //         //
  //         // if (post.availableCountries.isEmpty) {
  //         //   isExcluded = true;
  //         // }
  //
  //         if (!isExcluded) {
  //           post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
  //           newPosts.add(post);
  //           loadedIds.add(post.id!);
  //           added++;
  //           newPosts.shuffle();
  //
  //         }
  //       } catch (e) {
  //         print('Erreur parsing post: $e');
  //       }
  //     }
  //
  //     print('✅ $added posts autres pays ajoutés');
  //
  //   } catch (e) {
  //     print('❌ Erreur chargement autres pays: $e');
  //   }
  // }

  // ===========================================================================
  // PAGINATION - CHARGEMENT MANUEL (Après les 20 posts background)
  // ===========================================================================

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMorePosts &&
        !_isLoadingBackground &&
        _hasMorePosts &&
        _totalPostsLoaded < _maxTotalPosts &&
        !_useBackgroundLoading) { // Seulement en mode manuel
      _loadMorePostsManually();
    }
  }

  Future<void> _loadMorePostsManually() async {
    if (_isLoadingMorePosts || _isLoadingBackground || !_hasMorePosts || _totalPostsLoaded >= _maxTotalPosts) {
      return;
    }

    setState(() {
      _isLoadingMorePosts = true;
    });

    try {
      Set<String> loadedIds = Set.from(_loadedPostIds);
      List<Post> newPosts = [];

      await _loadMorePostsByFilter(loadedIds, newPosts, _manualLoadLimit);

      // Ajouter les nouveaux posts
      if (newPosts.isNotEmpty) {
        setState(() {
          _posts.addAll(newPosts);
          _loadedPostIds.addAll(newPosts.map((p) => p.id!));
          _totalPostsLoaded += newPosts.length;
        });

        print('📱 ${newPosts.length} posts chargés manuellement (total: $_totalPostsLoaded)');
      }

      _hasMorePosts = newPosts.length >= (_manualLoadLimit ~/ 2);

    } catch (e) {
      print('❌ Erreur chargement manuel: $e');
      _hasMorePosts = false;
    } finally {
      setState(() {
        _isLoadingMorePosts = false;
      });
    }
  }

  Future<void> _loadMorePostsByFilter(Set<String> loadedIds, List<Post> newPosts, int limit) async {
    switch (_currentFilter) {
      case 'ALL':
        await _loadMoreAllCountriesMixed(loadedIds, newPosts, limit);
        break;

      case 'COUNTRY':
        if (_selectedCountryCode != null) {
          await _loadMoreCountrySpecific(loadedIds, newPosts, _selectedCountryCode!, limit);
        }
        break;

      case 'MIXED':
        if (_selectedCountryCode != null) {
          await _loadMoreMixed(loadedIds, newPosts, _selectedCountryCode!, limit);
        }
        break;

      case 'CUSTOM':
        if (_selectedCountryCode != null) {
          await _loadMoreCountrySpecific(loadedIds, newPosts, _selectedCountryCode!, limit);
        }
        break;
    }
  }

  Future<int> _loadMoreAllCountriesMixed(Set<String> loadedIds, List<Post> newPosts, int limit) async {
    int added = 0;
    int attempts = 0;

    while (added < limit && attempts < 2) {
      int needed = limit - added;
      await _loadAllCountriesPosts(
        loadedIds,
        newPosts,
        isInitialLoad: false,
        limit: needed,
      );

      if (_selectedCountryCode != null && added < limit) {
        needed = limit - added;
        await _loadOtherCountriesPosts(
          loadedIds,
          newPosts,
          excludeCountry: _selectedCountryCode!,
          isInitialLoad: false,
          limit: needed,
        );
      }

      added = newPosts.length;
      attempts++;
    }

    return added;
  }

  Future<int> _loadMoreCountrySpecific(Set<String> loadedIds, List<Post> newPosts, String countryCode, int limit) async {
    await _loadCountrySpecificPosts(
      loadedIds,
      newPosts,
      countryCode,
      isInitialLoad: false,
      limit: limit,
    );

    int added = newPosts.length;

    if (added < limit) {
      int needed = limit - added;
      await _loadAllCountriesPosts(
        loadedIds,
        newPosts,
        isInitialLoad: false,
        limit: needed,
      );
      added = newPosts.length;
    }

    return added;
  }

  Future<int> _loadMoreMixed(Set<String> loadedIds, List<Post> newPosts, String countryCode, int limit) async {
    int countryNeeded = (limit * 0.4).ceil();
    await _loadCountrySpecificPosts(
      loadedIds,
      newPosts,
      countryCode,
      isInitialLoad: false,
      limit: countryNeeded,
    );

    int allNeeded = (limit * 0.4).ceil();
    await _loadAllCountriesPosts(
      loadedIds,
      newPosts,
      isInitialLoad: false,
      limit: allNeeded,
    );

    int otherNeeded = limit - newPosts.length;
    if (otherNeeded > 0) {
      await _loadOtherCountriesPosts(
        loadedIds,
        newPosts,
        excludeCountry: countryCode,
        isInitialLoad: false,
        limit: otherNeeded,
      );
    }

    return newPosts.length;
  }

  // ===========================================================================
  // CHARGEMENT DES DONNÉES SUPPLÉMENTAIRES (SÉPARÉ)
  // ===========================================================================

  Future<void> _loadAllAdditionalDataInParallel() async {
    // Charger tout en parallèle sans bloquer
    _loadSuggestedUsersInBackground();
    _loadArticlesInBackground();
    _loadCanauxInBackground();
    _loadChroniquesInBackground();
  }

  Future<void> _loadSuggestedUsersInBackground() async {
    if (_isLoadingSuggestedUsers) return;

    setState(() {
      _isLoadingSuggestedUsers = true;
    });

    try {
      final users = await userProvider.getProfileUsers(
        authProvider.loginUserData.id!,
        context,
        8, // Limité à 8 pour la performance
      );

      setState(() {
        _suggestedUsers = users..shuffle();
      });
    } catch (e) {
      print('Error loading suggested users: $e');
    } finally {
      setState(() {
        _isLoadingSuggestedUsers = false;
      });
    }
  }

  Future<void> _loadArticlesInBackground() async {
    if (_isLoadingArticles) return;

    setState(() {
      _isLoadingArticles = true;
    });

    try {
      final articleResults = await categorieProduitProvider.getArticleBooster(
          _selectedCountryCode?.toUpperCase() ?? 'TG'
      );

      setState(() {
        _articles = articleResults;
      });
    } catch (e) {
      print('Error loading articles: $e');
    } finally {
      setState(() {
        _isLoadingArticles = false;
      });
    }
  }

  Future<void> _loadCanauxInBackground() async {
    if (_isLoadingCanaux) return;

    setState(() {
      _isLoadingCanaux = true;
    });

    try {
      final canalResults = await postProvider.getCanauxHome();

      setState(() {
        _canaux = canalResults..shuffle();
      });
    } catch (e) {
      print('Error loading canaux: $e');
    } finally {
      setState(() {
        _isLoadingCanaux = false;
      });
    }
  }

  Future<void> _loadChroniquesInBackground() async {
    if (_isLoadingChroniques) return;

    setState(() {
      _isLoadingChroniques = true;
    });

    try {
      final snapshot = await _firestore.collection('chroniques')
          .orderBy('createdAt', descending: true)
          .limit(6)
          .get();

      final now = DateTime.now();
      final List<Chronique> validChroniques = [];

      for (final doc in snapshot.docs) {
        try {
          final chronique = Chronique.fromMap(doc.data(), doc.id);
          if (!chronique.isExpired) {
            validChroniques.add(chronique);
          }
        } catch (e) {
          print('❌ Erreur parsing chronique: $e');
        }
      }

      setState(() {
        _chroniques = validChroniques;
      });

      // Charger les données utilisateurs en arrière-plan
      if (validChroniques.isNotEmpty) {
        _loadChroniqueUserDataInBackground(validChroniques);
      }

    } catch (e) {
      print('❌ Erreur chargement chroniques: $e');
    } finally {
      setState(() {
        _isLoadingChroniques = false;
      });
    }
  }

  Future<void> _loadChroniqueUserDataInBackground(List<Chronique> chroniques) async {
    try {
      final userIds = chroniques.map((c) => c.userId).toSet();

      for (final userId in userIds) {
        if (!_userDataCache.containsKey(userId)) {
          final userDoc = await _firestore.collection('Users').doc(userId).get();
          if (userDoc.exists) {
            final userData = UserData.fromJson(userDoc.data()!);
            _userDataCache[userId] = userData;
            _userVerificationStatus[userId] = userData.isVerify ?? false;
          }
        }
      }

      // Mettre à jour l'UI si nécessaire
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Erreur chargement données chroniques: $e');
    }
  }

  // ===========================================================================
  // WIDGETS PRINCIPAUX
  // ===========================================================================

// Clé pour stocker dans SharedPreferences

// Fonction pour vérifier et rediriger
  Future<void> checkAndRedirectToVideoPage(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    bool hasSeen = prefs.getBool(HAS_SEEN_VIDEO_PAGE_KEY) ?? false;

    if (!hasSeen) {
      // Marquer comme vu immédiatement
      await prefs.setBool(HAS_SEEN_VIDEO_PAGE_KEY, true);

      // Rediriger vers la page des vidéos
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HomeConstPostPage(isVideoPage: true, type: '',)),
      );
    }
  }
  Widget _buildPostWidget(Post post, double width, double height) {
    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: (VisibilityInfo info) {
        _handleVisibilityChanged(post, info);
      },
      child: Container(

        child: Stack(
          children: [
            // Badge de disponibilité


            // Contenu du post
            post.type == PostType.PRONOSTIC.name
                ? SizedBox.shrink()
                : post.type == PostType.CHALLENGEPARTICIPATION.name
                ? LookChallengePostWidget(post: post, height: height, width: width)
                : (post.type == PostType.POST.name && post.dataType == PostDataType.VIDEO.name)
                ? YouTubeVideoCard(
              post: post,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoYoutubePageDetails(initialPost: post),
                  ),
                );
              },
            )
                : HomePostUsersWidget(
              post: post,
              color: _getRandomColor(),
              height: height * 0.6,
              width: width,
              isDegrade: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityBadge(Post post) {
    String badgeText = '';
    Color badgeColor = Colors.grey;

    if (post.availableCountries.contains('ALL')) {
      badgeText = '🌍 ALL';
      badgeColor = Colors.green;
    } else if (_selectedCountryCode != null &&
        post.availableCountries.contains(_selectedCountryCode!)) {
      badgeText = '📍 ${_selectedCountryCode}';
      badgeColor = Colors.blue;
    } else {
      badgeText = '🌐 MULTI';
      badgeColor = Colors.orange;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRandomColor() {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  // ===========================================================================
  // FILTRES CHIPS (Pour le contenu principal)
  // ===========================================================================

  Widget _buildFilterChips() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: '🌍 Tous',
              isSelected: _currentFilter == 'ALL',
              color: primaryGreen,
              onTap: () => _applyFilter(filterType: 'ALL', countryCode: null),
            ),
            SizedBox(width: 8),
            if (_selectedCountryCode != null)
              _buildFilterChip(
                label: '📍Mon pays ${_selectedCountryCode}',
                isSelected: _currentFilter == 'COUNTRY',
                color: Colors.blue,
                onTap: () => _applyFilter(filterType: 'COUNTRY', countryCode: _selectedCountryCode),
              ),
            if (_selectedCountryCode != null) SizedBox(width: 8),
            if (_selectedCountryCode != null)
              _buildFilterChip(
                label: '🔄 Mix',
                isSelected: _currentFilter == 'MIXED',
                color: Colors.purple,
                onTap: () => _applyFilter(filterType: 'MIXED', countryCode: _selectedCountryCode),
              ),
            SizedBox(width: 8),
            _buildFilterChip(
              label: '⚙️ Autre',
              isSelected: _currentFilter == 'CUSTOM',
              color: Colors.orange,
              onTap: _showCountryFilterModal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[300],
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION CHRONIQUES
  // ===========================================================================

  Widget _buildChroniquesSection() {
    if (_isLoadingChroniques) {
      return _buildLoadingSection('📝 Chroniques récentes');
    }

    if (_chroniques.isEmpty) {
      return SizedBox.shrink();
    }

    return ChroniqueSectionComponent(
      videoThumbnails: _videoThumbnails,
      userVerificationStatus: _userVerificationStatus,
      userDataCache: _userDataCache,
      isLoadingChroniques: _isLoadingChroniques,
      groupedChroniques: _groupChroniquesByUser(_chroniques),
    );
  }

  Map<String, List<Chronique>> _groupChroniquesByUser(List<Chronique> chroniques) {
    final grouped = <String, List<Chronique>>{};
    for (final chronique in chroniques) {
      grouped[chronique.userId] = [...grouped[chronique.userId] ?? [], chronique];
    }
    return grouped;
  }

  // ===========================================================================
  // SECTION PROFILS UTILISATEURS
  // ===========================================================================

  Widget _buildProfilesSection() {
    if (_isLoadingSuggestedUsers) {
      return _buildLoadingSection('👑 Profils à découvrir');
    }

    if (_suggestedUsers.isEmpty) {
      return SizedBox.shrink();
    }

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '👑 Profils à découvrir',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFF8B0000)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UsersListPage(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Voir tout', style: TextStyle(color: Colors.white, fontSize: 11)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: height * 0.25,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _suggestedUsers.length,
            itemBuilder: (context, index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              width: width * 0.35,
              child: _buildProfileCard(_suggestedUsers[index], width, height),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(UserData user, double width, double height) {
    return Container(
      decoration: BoxDecoration(
        color: darkBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showUserDetails(user),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: width * 0.4,
                  height: height * 0.18,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      fit: BoxFit.cover,
                      imageUrl: user.imageUrl ?? '',
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: Center(child: CircularProgressIndicator(color: primaryGreen)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: Icon(Icons.person, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: width * 0.4,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '@${user.pseudo?.replaceAll("@", "") ?? "user"}',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (user.isVerify ?? false)
                            Icon(Icons.verified, color: primaryGreen, size: 12),
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.group, size: 9, color: accentYellow),
                              SizedBox(width: 2),
                              Text(
                                _formatNumber(user.userAbonnesIds?.length ?? 0),
                                style: TextStyle(
                                  color: accentYellow,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            height: 30,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ElevatedButton(
              onPressed: () => _showUserDetails(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: darkBackground,
                padding: EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'S\'abonner',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(UserData user) async {
    final users = await authProvider.getUserById(user.id!);
    if (users.isNotEmpty && mounted) {
      // Utiliser votre fonction showUserDetailsModalDialog
     double  width = MediaQuery.of(context).size.width;
     double height = MediaQuery.of(context).size.height;
      showUserDetailsModalDialog(users.first, width, height, context);
    }
  }

  // ===========================================================================
  // SECTION ARTICLES
  // ===========================================================================

  Widget _buildArticlesSection() {
    if (_isLoadingArticles) {
      return _buildLoadingSection('🔥 Produits Boostés');
    }

    if (_articles.isEmpty) {
      return SizedBox.shrink();
    }

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🔥 Produits Boostés',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (context) => HomeAfroshopPage(title: ''))),
                  child: Row(
                    children: [
                      Text('Boutiques', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: primaryGreen, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: height * 0.22,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _articles.length,
              itemBuilder: (context, index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                width: width * 0.55,
                child: ProductWidget(
                  article: _articles[index],
                  width: width * 0.55,
                  height: height * 0.22,
                  isOtherPage: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION CANAUX
  // ===========================================================================

  Widget _buildCanauxSection() {
    if (_isLoadingCanaux) {
      return _buildLoadingSection('📺 Afrolook Canal');
    }

    if (_canaux.isEmpty) {
      return SizedBox.shrink();
    }

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('📺 Afrolook Canal',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false))),
                  child: Row(
                    children: [
                      Text('Voir plus', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: primaryGreen, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: height * 0.16,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _canaux.length,
              itemBuilder: (context, index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                width: width * 0.28,
                child: channelWidget(
                  _canaux[index],
                  height * 0.25,
                  width * 0.28,
                  context,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection(String title) {
    return Container(
        margin: EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
    color: darkBackground,
    borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Padding(
    padding: EdgeInsets.all(12),
    child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    Text(
    title,
    style: TextStyle(
    color: textColor,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    ),
    ),
    SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(
    strokeWidth: 2,
    color: primaryGreen,
    ),
    ),
    ],
    ),
    ),
    SizedBox(height: 8),
    ],
    ));
  }

  // ===========================================================================
  // CONTENU PRINCIPAL
  // ===========================================================================

  Widget _buildContent() {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    if (_isLoadingPosts && _posts.isEmpty) {
      return _buildLoadingShimmer(width, height);
    }

    if (_hasErrorPosts && _posts.isEmpty) {
      return _buildErrorWidget();
    }

    if (_posts.isEmpty) {
      return _buildEmptyWidget();
    }

    List<Widget> contentWidgets = [];

    // 1. Filtres
    contentWidgets.add(_buildFilterChips());
    contentWidgets.add(SizedBox(height: 8));

    // 2. Chroniques (si chargées)
    final chroniquesSection = _buildChroniquesSection();
    if (chroniquesSection is! SizedBox) {
      contentWidgets.add(chroniquesSection);
    }

    // 3. Profils utilisateurs (si chargés)
    final profilesSection = _buildProfilesSection();
    if (profilesSection is! SizedBox) {
      contentWidgets.add(profilesSection);
      contentWidgets.add(SizedBox(height: 16));
    }

    // 4. Posts avec bannières
    int postIndex = 0;
    for (int i = 0; i < _posts.length; i++) {
      final post = _posts[i];
      if (postIndex == 0) {
        contentWidgets.add( const PronosticsCarouselWidget(),);
        // contentWidgets.add(_buildAdAdvertisement(key: 'ad_after_first'));
      }
      // Ajouter le post
      contentWidgets.add(
        GestureDetector(
          onTap: () => _navigateToPostDetails(post),
          child: _buildPostWidget(post, width, height),
        ),
      );

      postIndex++;

      // 🔴 AJOUT DES BANNIÈRES ADMOB
      // Après le PREMIER post (postIndex == 1)
      if (postIndex == 2) {
        contentWidgets.add(_buildAdAdvertisement(key: 'ad_after_first'));
        contentWidgets.add(_buildAdBanner(key: 'ad_list_post$postIndex'));
      }
// Top dating : après le premier post, puis tous les 5 posts
      //AJOUT DES BANNIÈRES ADMOB
      if (postIndex == 2) {
        // contentWidgets.add(_buildAdBanner(key: 'ad_$postIndex'));

        // contentWidgets.add(TopDatingProfilesWidget());
      } else if (postIndex > 1 && (postIndex - 1) % 5 == 0) {
        contentWidgets.add(TopDatingProfilesWidget());
      }
      // AdMOb Ensuite, tous les 3 posts (après le 4ème, 7ème, 10ème...)
      // if (postIndex > 1 && (postIndex - 1) % 3 == 0) {
      //   // contentWidgets.add(_buildAdAdvertisement(key: 'ad_after_first'));
      //
      //   contentWidgets.add(TopDatingProfilesWidget());
      //   // contentWidgets.add(_buildAdBanner(key: 'ad_${postIndex}'));
      // }

      // Garder vos sections spéciales existantes
      if (postIndex % 3 == 0) {
        if (postIndex % 6 == 3) {
          final articlesSection = _buildArticlesSection();
          if (articlesSection is! SizedBox) {
            contentWidgets.add(articlesSection);
            contentWidgets.add(_buildAdBanner(key: 'ad_after_first'));

          }
        } else if (postIndex % 6 == 0) {
          final canauxSection = _buildCanauxSection();
          if (canauxSection is! SizedBox) {
            contentWidgets.add(canauxSection);
          }
        }
      }
    }
    // 5. Indicateurs de chargement/fin
    if (_isLoadingMorePosts) {
      contentWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: primaryGreen),
                SizedBox(height: 10),
                Text('Chargement de plus de posts...', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    } else if (_isLoadingBackground && _useBackgroundLoading) {
      contentWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Column(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey[500],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Préparation de plus de contenu... ($_backgroundPostsLoaded/$_maxBackgroundPosts)',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (!_hasMorePosts) {
      contentWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.flag, color: Colors.green, size: 36),
                SizedBox(height: 10),
                Text(
                  _getEndMessage(),
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Text(
                  'Revenez plus tard pour de nouveaux contenus',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (!_useBackgroundLoading) {
      // Bouton "Charger plus" quand le background est désactivé
      contentWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              children: [
                Text(
                  'Chargement automatique terminé',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _loadMorePostsManually,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  child: Text(
                    'Charger 5 posts de plus',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) => contentWidgets[index],
            childCount: contentWidgets.length,
          ),
        ),
      ],
    );
  }
// 🎯 Widget pour afficher une bannière AdMob
  Widget _buildAdBanner({required String key}) {
    // return SizedBox.shrink();

    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: NativeAdWidget(
        key: ValueKey(key),
        templateType: TemplateType.medium, // ou TemplateType.small

        onAdLoaded: () {
          print('✅ Native Ad Afrolook chargée: $key');
        },
      ),
      // child: BannerAdWidget(
      //   onAdLoaded: () {
      //     print('✅ Bannière Afrolook chargée: $key');
      //   },
      // ),
    );
  }
  Widget _buildAdAdvertisement({required String key}) {
    // return SizedBox.shrink();
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return  AdvertisementCarouselWidget(
      height: height,
      width: width,
      autoPlayDuration: Duration(seconds: 5),
      showIndicators: true,
    );
  }
  String _getEndMessage() {
    switch (_currentFilter) {
      case 'ALL':
        return 'Vous avez vu tous les contenus disponibles';
      case 'COUNTRY':
        return 'Fin des contenus en ${_selectedCountryCode ?? "ce pays"}';
      case 'MIXED':
        return 'Fin des contenus pour le mix actuel';
      case 'CUSTOM':
        return 'Fin des contenus pour ${_selectedCountryCode ?? "ce pays"}';
      default:
        return 'Fin des contenus';
    }
  }

  // ===========================================================================
  // WIDGETS D'ÉTAT
  // ===========================================================================

  Widget _buildLoadingShimmer(double width, double height) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            height: 100,
            margin: EdgeInsets.all(8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  width: width * 0.2,
                  margin: EdgeInsets.all(4),
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[800]!,
                    highlightColor: Colors.grey[700]!,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              return Container(
                margin: EdgeInsets.all(8),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    height: 350,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
            childCount: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 40),
          SizedBox(height: 12),
          Text('Erreur de chargement', style: TextStyle(color: Colors.white, fontSize: 14)),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: _refreshData,
            child: Text('Réessayer', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.feed, color: Colors.grey, size: 40),
          SizedBox(height: 12),
          Text(
            _getEmptyMessage(),
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: _refreshData,
            child: Text('Actualiser', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage() {
    switch (_currentFilter) {
      case 'ALL':
        return 'Aucun contenu disponible pour tous les pays';
      case 'COUNTRY':
        return 'Aucun contenu disponible en ${_selectedCountryCode ?? "ce pays"}';
      case 'MIXED':
        return 'Aucun contenu disponible pour le moment';
      case 'CUSTOM':
        return 'Aucun contenu disponible pour ${_selectedCountryCode ?? "ce pays"}';
      default:
        return 'Aucun contenu disponible';
    }
  }

  String _getFilterDescription() {
    switch (_currentFilter) {
      case 'ALL':
        return '🌍 Tous les pays';
      case 'COUNTRY':
        return '📍 ${_selectedCountryCode ?? "Mon pays"}';
      case 'MIXED':
        return '🔄 Mix intelligent';
      case 'CUSTOM':
        return '⚙️ ${_selectedCountryCode ?? "Pays spécifique"}';
      default:
        return 'Filtrer par pays';
    }
  }

  Widget _getFilterIcon() {
    switch (_currentFilter) {
      case 'ALL':
        return Icon(Icons.public, color: Colors.white, size: 18);
      case 'COUNTRY':
      case 'CUSTOM':
        return Text(
          _getCountryFlag(_selectedCountryCode ?? ''),
          style: TextStyle(fontSize: 16),
        );
      case 'MIXED':
        return Icon(Icons.blender, color: Colors.white, size: 18);
      default:
        return Icon(Icons.filter_alt, color: Colors.white, size: 18);
    }
  }

  // ===========================================================================
  // MÉTHODES UTILITAIRES
  // ===========================================================================

  bool _checkIfPostSeen(Post post) {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return false;

    if (_postsViewedInSession.containsKey(post.id)) {
      return _postsViewedInSession[post.id]!;
    }

    if (authProvider.loginUserData.viewedPostIds?.contains(post.id!) ?? false) {
      return true;
    }

    if (post.users_vue_id?.contains(currentUserId) ?? false) {
      return true;
    }

    return false;
  }

  void _handleVisibilityChanged(Post post, VisibilityInfo info) {
    final postId = post.id!;
    _visibilityTimers[postId]?.cancel();

    if (info.visibleFraction > 0.5) {
      _visibilityTimers[postId] = Timer(Duration(milliseconds: 500), () {
        if (mounted && info.visibleFraction > 0.5) {
          _recordPostView(post);
        }
      });
    } else {
      _visibilityTimers.remove(postId);
    }
  }
  // 🔥 NOUVELLE MÉTHODE UTILITAIRE
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
  Future<void> _recordPostView3(Post post) async {

  }
  Future<void> _recordPostView(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    String viewKey = '${_lastViewDatePrefix}${currentUserId}_${post.id}';

    String? lastViewDateStr = _prefs.getString(viewKey);

    // ✅ 1. GESTION DES VUES (inchangée)
    if (lastViewDateStr != null) {
      DateTime lastViewDate = DateTime.parse(lastViewDateStr);
      DateTime now = DateTime.now();

      int difference = now.difference(lastViewDate).inDays;

      // ❌ Si moins de 2 jours -> ne pas compter la vue
      if (difference < 2) {
        print(
            '⏭️ Post ${post.id} déjà vu il y a $difference jour(s) par $currentUserId - Vue NON comptée');

        if (!post.users_vue_id!.contains(currentUserId)) {
          setState(() {
            post.users_vue_id!.add(currentUserId);
            post.hasBeenSeenByCurrentUser = true;
          });
        }

        // ✅ Même si la vue n'est pas comptée, on vérifie l'interaction par session
        await _checkAndIncrementInteraction(post);
        return;
      }
    }

    try {
      // 🔥 Sauvegarder la date actuelle pour les vues
      await _prefs.setString(viewKey, DateTime.now().toIso8601String());

      setState(() {
        post.hasBeenSeenByCurrentUser = true;
        post.vues = (post.vues ?? 0) + 1;
        post.users_vue_id ??= [];
        if (!post.users_vue_id!.contains(currentUserId)) {
          post.users_vue_id!.add(currentUserId);
        }
      });

      final batch = _firestore.batch();

      final postRef = _firestore.collection('Posts').doc(post.id);
      batch.update(postRef, {
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      final userRef = _firestore.collection('Users').doc(currentUserId);
      batch.update(userRef, {
        'viewedPostIds': FieldValue.arrayUnion([post.id!]),
      });

      await batch.commit();

      authProvider.loginUserData.viewedPostIds ??= [];
      if (!authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
        authProvider.loginUserData.viewedPostIds!.add(post.id!);
      }

      print('✅ Vue comptée pour post ${post.id} par $currentUserId');

      // ✅ 2. GESTION DE L'INTERACTION (par session)
      await _checkAndIncrementInteraction(post);

    } catch (e) {
      print('Error recording post view: $e');
    }
  }

// ✅ Nouvelle fonction dédiée à l'interaction (session uniquement)
  Future<void> _checkAndIncrementInteraction(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    // Clé de session pour l'interaction
    String interactionKey = 'session_interaction_${currentUserId}_${post.id}';

    // Vérifier si déjà interagi dans cette session
    bool alreadyInteracted = _prefs.getBool(interactionKey) ?? false;

    if (!alreadyInteracted) {
      // Incrémenter l'interaction UNE SEULE FOIS par session
      await authProvider.incrementPostTotalInteractions(postId: post.id!);
      await _prefs.setBool(interactionKey, true);
      print('✅ Total interactions +1 pour le post ${post.id} (première vue de la session)');
    } else {
      print('⏭️ Interaction déjà comptée dans cette session pour le post ${post.id}');
    }
  }

  Future<void> _recordPostView4(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    // 🔥 Vérification avec SharedPreferences (une fois par jour)
    String todayDate = _getTodayDateString();
    String viewKey = '${_lastViewDatePrefix}${currentUserId}_${post.id}';

    // Récupérer la dernière date de vue pour ce post par cet utilisateur
    String? lastViewDate = _prefs.getString(viewKey);

    // Si déjà vu aujourd'hui, NE PAS COMPTER la vue
    if (lastViewDate == todayDate) {
      print('⏭️ Post ${post.id} déjà vu aujourd\'hui par $currentUserId - Vue NON comptée');

      // ✅ On met quand même à jour l'UI locale pour montrer que le post est vu
      if (!post.users_vue_id!.contains(currentUserId)) {
        setState(() {
          post.users_vue_id!.add(currentUserId);
          post.hasBeenSeenByCurrentUser = true;
        });
      }
      return; // On ne compte pas la vue
    }


    // ✅ SUPPRIMER la vérification _postsViewedInSession qui empêcherait
    // de compter la vue si l'utilisateur a déjà vu le post dans une session précédente
    // On garde seulement la vérification SharedPreferences (une fois par jour)

    try {
      // 🔥 Sauvegarder la date dans SharedPreferences
      await _prefs.setString(viewKey, todayDate);

      // Mise à jour locale de l'UI
      setState(() {
        post.hasBeenSeenByCurrentUser = true;
        post.vues = (post.vues ?? 0) + 1;
        post.users_vue_id ??= [];
        if (!post.users_vue_id!.contains(currentUserId)) {
          post.users_vue_id!.add(currentUserId);
        }
      });

      // Mise à jour Firestore avec batch pour atomicité
      final batch = _firestore.batch();

      // 1. Incrémenter les vues du post
      final postRef = _firestore.collection('Posts').doc(post.id);
      batch.update(postRef, {
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      // 2. Ajouter l'ID du post à l'historique de l'utilisateur
      final userRef = _firestore.collection('Users').doc(currentUserId);
      batch.update(userRef, {
        'viewedPostIds': FieldValue.arrayUnion([post.id!]),
      });

      await batch.commit();

      // Mettre à jour le provider local
      authProvider.loginUserData.viewedPostIds ??= [];
      if (!authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
        authProvider.loginUserData.viewedPostIds!.add(post.id!);
      }

      print('✅ Vue comptée pour post ${post.id} par $currentUserId le $todayDate');

    } catch (e) {
      print('Error recording post view: $e');
    }
  }
  Future<void> _recordPostView2(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    if (_postsViewedInSession.containsKey(post.id!)) {
      return;
    }

    try {
      _postsViewedInSession[post.id!] = true;

      setState(() {
        post.hasBeenSeenByCurrentUser = true;
        post.vues = (post.vues ?? 0) + 1;
        post.users_vue_id ??= [];
        if (!post.users_vue_id!.contains(currentUserId)) {
          post.users_vue_id!.add(currentUserId);
        }
      });

      final batch = _firestore.batch();
      final postRef = _firestore.collection('Posts').doc(post.id);
      batch.update(postRef, {
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      final userRef = _firestore.collection('Users').doc(currentUserId);
      batch.update(userRef, {
        'viewedPostIds': FieldValue.arrayUnion([post.id!]),
      });

      await batch.commit();

      authProvider.loginUserData.viewedPostIds ??= [];
      if (!authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
        authProvider.loginUserData.viewedPostIds!.add(post.id!);
      }

    } catch (e) {
      print('Error recording post view: $e');
      _postsViewedInSession.remove(post.id!);
    }
  }

  void _navigateToPostDetails(Post post) {
    _recordPostView(post);
    // Naviguer vers la page de détails du post
  }

  Future<void> _refreshData() async {
    // Arrêter le chargement background pendant le refresh
    _backgroundLoadTimer?.cancel();

    setState(() {
      _isLoadingPosts = true;
      _isFirstLoad = true;
      _useBackgroundLoading = true; // Réactiver le background
      _backgroundPostsLoaded = 0; // Réinitialiser le compteur
    });

    _resetPagination();
    await _loadInitialPosts();

    // Redémarrer le chargement background
    _startBackgroundLoading();

    setState(() {
      _isLoadingPosts = false;
    });
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  void _handleAppLifecycle(String? message) {
    if (message?.contains('resume') == true) {
      _setUserOnline();
    } else {
      _setUserOffline();
    }
  }

  void _setUserOnline() {
    if (authProvider.loginUserData != null) {
      authProvider.loginUserData!.isConnected = true;
      userProvider.changeState(
          user: authProvider.loginUserData,
          state: UserState.ONLINE.name
      );
    }
  }

  void _setUserOffline() {
    if (authProvider.loginUserData != null) {
      authProvider.loginUserData!.isConnected = false;
      userProvider.changeState(
          user: authProvider.loginUserData,
          state: UserState.OFFLINE.name
      );
    }
  }

  Color _getFilterBorderColor() {
    switch (_currentFilter) {
      case 'ALL':
        return primaryGreen;
      case 'COUNTRY':
        return Colors.blue;
      case 'MIXED':
        return Colors.purple;
      case 'CUSTOM':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================
  final GlobalKey<InterstitialAdWidgetState> _interstitialAdKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: darkBackground,

        appBar: AppBar(
          automaticallyImplyLeading: widget.isVideoPage,
          iconTheme: IconThemeData(color: Colors.amber),
          backgroundColor: Colors.black,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isVideoPage ? 'Afrolook vidéos' : 'Découvrir',
                style: TextStyle(
                  fontSize: 18,
                  color: widget.isVideoPage ? primaryGreen : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!widget.isVideoPage)
                SizedBox(height: 2),
              if (!widget.isVideoPage)
                Text(
                  _getFilterDescription(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                ),
            ],
          ),
          elevation: 0,
          actions: [
            // Bouton filtre avec icône personnalisée
            InkWell(
              onTap: _showCountryFilterModal,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                margin: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _getFilterBorderColor(),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: _getFilterIcon(),
                ),
              ),
            ),
            // Bouton rafraîchir
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _refreshData,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
            SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                _buildContent(),
                InterstitialAdWidget(
                  key: _interstitialAdKey,
                  onAdDismissed: () {
                    // Show a thank‑you message after the ad is dismissed
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Merci d\'avoir regardé la publicité ! Votre soutien est précieux.',
                          style: TextStyle(color: Colors.green),
                        ),
                        backgroundColor: darkBackground,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),      ),
    );
  }
}

