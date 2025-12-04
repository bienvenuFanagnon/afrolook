import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/chroniqueProvider.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';

import 'package:afrotok/pages/userPosts/postWidgets/postHomeWidget.dart';
import 'package:afrotok/pages/challenge/postChallengeWidget.dart';

import '../../../services/postService/feed_interaction_service.dart';
import '../../../services/postService/local_viewed_posts_service.dart';
import '../../../services/postService/mixed_feed_service.dart';
import '../../chronique/chroniqueform.dart';
import '../../postComments.dart';
import '../../userPosts/postWidgets/postWidgetPage.dart';
import 'chronique_section.dart';
import 'home_components/loading_components.dart';
import 'home_components/special_sections_component.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/chroniqueProvider.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';
import 'package:afrotok/providers/mixed_feed_service_provider.dart';

import 'package:afrotok/pages/userPosts/postWidgets/postHomeWidget.dart';
import 'package:afrotok/pages/challenge/postChallengeWidget.dart';

import '../../../services/postService/feed_interaction_service.dart';
import '../../../services/postService/local_viewed_posts_service.dart';
import '../../../services/postService/mixed_feed_service.dart';
import 'chronique_section.dart';
import 'home_components/loading_components.dart';
import 'home_components/special_sections_component.dart';

// 🔥 ENUM POUR LES FILTRES
enum FeedFilter {
  ALL('Tout', '🌍', null),
  CHALLENGE('Look Challenge', '🏆', 'challenge'),
  SUBSCRIPTIONS('Abonnements', '📨', 'subscriptions'),
  VIRAL('Viral', '🔥', 'viral'),
  LOW_SCORE('Faible score', '📉', 'low_score');

  final String label;
  final String emoji;
  final String? value;

  const FeedFilter(this.label, this.emoji, this.value);
}

class UnifiedHomeOptimized extends StatefulWidget {
  const UnifiedHomeOptimized({super.key});

  @override
  State<UnifiedHomeOptimized> createState() => _UnifiedHomeOptimizedState();
}

class _UnifiedHomeOptimizedState extends State<UnifiedHomeOptimized> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _filterScrollController = ScrollController();

  // 🔥 ÉTATS LOCAUX POUR L'AFFICHAGE
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  int _userLastVisitTime = 0;
  bool _isRefreshing = false;

  // 🔥 CONTENU ACTUEL À AFFICHER
  List<dynamic> _currentContent = [];
// Ajoutez cette variable en haut de votre classe
  final Set<String> _alreadyViewedPosts = Set<String>();
  // 🔥 GESTION VISIBILITÉ
  final Map<String, Timer> _visibilityTimers = {};

  // 🔥 VARIABLES POUR LES CHRONIQUES
  final Map<String, Uint8List> _videoThumbnails = {};
  final Map<String, bool> _userVerificationStatus = {};
  final Map<String, UserData> _userDataCache = {};
  bool _isLoadingChroniques = false;
  Map<String, List<Chronique>> _groupedChroniques = {};

  // 🔥 POUR SUIVRE L'ÉTAT DES POSTS
  bool _hasDisplayedImmediatePosts = false;
  bool _isInitialLoadComplete = false;
  Timer? _backgroundLoadTimer;

  // 🔥 POUR ÉVITER LES DOUBLONS
  final Set<String> _displayedPostIds = Set();
  final Set<String> _displayedChroniqueIds = Set();

  // 🔥 FILTRES
  FeedFilter _currentFilter = FeedFilter.ALL;
  final List<FeedFilter> _availableFilters = FeedFilter.values;

  @override
  void initState() {
    super.initState();
    _initializePage();
    _scrollController.addListener(_scrollListener);
  }

  // 🔥 INITIALISATION COMPLÈTE
  Future<void> _initializePage() async {
    final mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);

    try {
      print('🎯 UnifiedHomeOptimized - Initialisation complète...');

      await _loadUserLastVisitTime();

      // 🔥 ÉTAPE 1: CHARGER LE CONTENU GLOBAL (chroniques, articles, canaux)
      await _loadGlobalContentImmediately(mixedFeedProvider);

      // 🔥 ÉTAPE 2: AFFICHER CHRONIQUES + POSTS IMMÉDIATS
      _displayInitialContent(mixedFeedProvider);

      // 🔥 ÉTAPE 3: PRÉPARER ET CHARGER LE CONTENU MIXTE PROGRESSIVEMENT
      _prepareAndLoadMixedContent(mixedFeedProvider);

    } catch (e) {
      print('❌ Erreur initialisation page: $e');
      setState(() => _hasError = true);
    }
  }

  // 🔥 CHARGEMENT IMMÉDIAT DU CONTENU GLOBAL
  Future<void> _loadGlobalContentImmediately(MixedFeedServiceProvider provider) async {
    try {
      print('🌍 Chargement immédiat du contenu global...');
      await provider.loadGlobalContent();
      print('✅ Contenu global chargé');
    } catch (e) {
      print('❌ Erreur chargement global: $e');
    }
  }

  // 🔥 AFFICHER LE CONTENU INITIAL (CHRONIQUES + POSTS IMMÉDIATS)
  void _displayInitialContent(MixedFeedServiceProvider provider) {
    if (_hasDisplayedImmediatePosts) return;

    print('🚀 Construction du contenu initial...');

    final initialContent = <dynamic>[];

    // 🔥 ÉTAPE 1: AJOUTER LES CHRONIQUES EN PREMIÈRE POSITION
    final chroniques = provider.mixedFeedService?.chroniques ?? [];
    if (chroniques.isNotEmpty) {
      initialContent.add(ContentSection(
        type: ContentMixtType.CHRONIQUES,
        data: chroniques,
      ));
      print('✅ Chroniques ajoutées en première position: ${chroniques.length}');

      // Précharger les données des chroniques
      _preloadChroniqueData(chroniques);
    }

    // 🔥 ÉTAPE 2: AJOUTER LES POSTS IMMÉDIATS
    final immediatePosts = provider.immediatePosts;
    if (immediatePosts.isNotEmpty) {
      for (final post in immediatePosts) {
        if (post.id != null && !_displayedPostIds.contains(post.id!)) {
          initialContent.add(ContentSection(
            type: ContentMixtType.POST,
            data: post,
          ));
          _displayedPostIds.add(post.id!);
        }
      }
      print('✅ Posts immédiats ajoutés: ${immediatePosts.length}');
    }

    // 🔥 ÉTAPE 3: AJOUTER ARTICLES ET CANAUX SI DISPONIBLES
    final articles = provider.mixedFeedService?.articles ?? [];
    if (articles.isNotEmpty) {
      initialContent.add(ContentSection(
        type: ContentMixtType.ARTICLES,
        data: articles,
      ));
      print('✅ Articles ajoutés: ${articles.length}');
    }

    final canaux = provider.mixedFeedService?.canaux ?? [];
    if (canaux.isNotEmpty) {
      initialContent.add(ContentSection(
        type: ContentMixtType.CANAUX,
        data: canaux,
      ));
      print('✅ Canaux ajoutés: ${canaux.length}');
    }

    setState(() {
      _currentContent = initialContent;
      _hasDisplayedImmediatePosts = true;
    });

    print('🎯 Contenu initial affiché: ${initialContent.length} éléments');
  }

  // 🔥 PRÉPARER ET CHARGER LE CONTENU MIXTE
  void _prepareAndLoadMixedContent(MixedFeedServiceProvider provider) {
    WidgetsBinding.instance?.addPostFrameCallback((_) async {
      try {
        print('🧠 Début du chargement du contenu mixte...');

        // Attendre un peu pour laisser l'UI s'afficher
        await Future.delayed(Duration(milliseconds: 300));

        // 🔥 CHARGER LE CONTENU MIXTE DISPONIBLE
        await _loadAvailableMixedContent(provider);

        // 🔥 CONTINUER LE CHARGEMENT EN BACKGROUND
        _continueLoadingInBackground(provider);

      } catch (e) {
        print('❌ Erreur chargement contenu mixte: $e');
        setState(() {
          _isInitialLoadComplete = true;
        });
      }
    });
  }

  // 🔥 CHARGER LE CONTENU MIXTE DISPONIBLE
  Future<void> _loadAvailableMixedContent(MixedFeedServiceProvider provider) async {
    try {
      if (provider.isReady) {
        print('🚀 Chargement du contenu mixte disponible...');

        final mixedContent = await provider.loadMixedContent(loadMore: false);

        if (mixedContent.isNotEmpty) {
          print('✅ Contenu mixte chargé: ${mixedContent.length} éléments');
          _mergeMixedContent(mixedContent, provider);
        } else {
          print('⏳ Aucun contenu mixte disponible pour le moment');
        }
      } else {
        print('⏳ Service pas encore prêt, attente...');
        // Réessayer après 1 seconde
        await Future.delayed(Duration(seconds: 1));
        await _loadAvailableMixedContent(provider);
      }
    } catch (e) {
      print('❌ Erreur chargement contenu mixte: $e');
    }
  }

  // 🔥 FUSIONNER INTELLIGEMMENT LE CONTENU MIXTE
  void _mergeMixedContent(List<dynamic> newMixedContent, MixedFeedServiceProvider provider) {
    print('🎯 Fusion du contenu mixte...');

    final mergedContent = List<dynamic>.from(_currentContent);
    int newItemsCount = 0;

    for (final section in newMixedContent) {
      if (section is ContentSection) {
        switch (section.type) {
          case ContentMixtType.POST:
            final post = section.data as Post;
            if (post.id != null && !_displayedPostIds.contains(post.id!)) {
              mergedContent.add(section);
              _displayedPostIds.add(post.id!);
              newItemsCount++;
            }
            break;

          case ContentMixtType.CHRONIQUES:
          // Les chroniques sont déjà en première position, on évite les doublons
            final chroniques = section.data as List<Chronique>;
            final newChroniques = chroniques.where((c) =>
            c.id != null && !_displayedChroniqueIds.contains(c.id!)).toList();

            if (newChroniques.isNotEmpty) {
              // On pourrait ajouter une nouvelle section chroniques plus bas
              // ou mettre à jour la section existante
              print('📝 Nouvelles chroniques disponibles: ${newChroniques.length}');
            }
            break;

          case ContentMixtType.ARTICLES:
          case ContentMixtType.CANAUX:
          // Vérifier si on a déjà ce type de section
            final hasSimilarSection = mergedContent.any((existing) =>
            existing is ContentSection && existing.type == section.type);

            if (!hasSimilarSection) {
              mergedContent.add(section);
              newItemsCount++;
            }
            break;
        }
      }
    }

    if (newItemsCount > 0) {
      setState(() {
        _currentContent = mergedContent;
      });
      print('✅ Fusion réussie: +$newItemsCount nouveaux éléments (Total: ${mergedContent.length})');
    } else {
      print('ℹ️ Aucun nouvel élément à ajouter');
    }
  }

  // 🔥 CONTINUER LE CHARGEMENT EN BACKGROUND
  void _continueLoadingInBackground(MixedFeedServiceProvider provider) {
    int checkCount = 0;
    const int maxChecks = 8;

    _backgroundLoadTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!mounted || checkCount >= maxChecks) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isInitialLoadComplete = true;
          });
        }
        print('✅ Chargement background terminé après $checkCount vérifications');
        return;
      }

      checkCount++;

      try {
        if (provider.hasMore && provider.isReady) {
          final previousLength = _currentContent.length;
          final newMixedContent = await provider.loadMixedContent(loadMore: true);

          if (newMixedContent.length > previousLength) {
            final newItems = newMixedContent.skip(previousLength).toList();

            print('🆕 Nouveaux éléments en background: +${newItems.length}');

            // Fusionner les nouveaux éléments
            final mergedContent = List<dynamic>.from(_currentContent);
            int addedCount = 0;

            for (final section in newItems) {
              if (section is ContentSection && section.type == ContentMixtType.POST) {
                final post = section.data as Post;
                if (post.id != null && !_displayedPostIds.contains(post.id!)) {
                  mergedContent.add(section);
                  _displayedPostIds.add(post.id!);
                  addedCount++;
                }
              }
            }

            if (addedCount > 0) {
              setState(() {
                _currentContent = mergedContent;
              });
              print('✅ Background: +$addedCount posts ajoutés');
            }
          }
        }

        // Arrêter si on a assez de contenu
        if (_currentContent.length >= 20 || !provider.hasMore) {
          timer.cancel();
          setState(() {
            _isInitialLoadComplete = true;
          });
          print('🎯 Chargement optimal atteint: ${_currentContent.length} éléments');
        }

      } catch (e) {
        print('❌ Erreur chargement background: $e');
        timer.cancel();
        setState(() {
          _isInitialLoadComplete = true;
        });
      }
    });
  }

  // 🔥 PRÉCHARGER LES DONNÉES DES CHRONIQUES
  void _preloadChroniqueData(List<Chronique> chroniques) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChroniqueData(chroniques);
    });
  }

  // 🔥 CHANGEMENT DE FILTRE
  Future<void> _onFilterChanged(FeedFilter newFilter) async {
    if (_currentFilter == newFilter) return;

    print('🎯 Changement de filtre: ${_currentFilter.label} → ${newFilter.label}');

    setState(() {
      _currentFilter = newFilter;
      _isLoading = true;
    });

    try {
      List<ContentSection> filteredContent = [];

      if (newFilter == FeedFilter.ALL) {
        // 🔥 FILTRE "TOUT" : RECONSTRUIRE LE CONTENU COMPLET
        final mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);

        // Réinitialiser les ensembles de contrôle
        _displayedPostIds.clear();
        _displayedChroniqueIds.clear();

        // Reconstruire le contenu initial
        final initialContent = <dynamic>[];

        // Chroniques
        final chroniques = mixedFeedProvider.mixedFeedService?.chroniques ?? [];
        if (chroniques.isNotEmpty) {
          initialContent.add(ContentSection(
            type: ContentMixtType.CHRONIQUES,
            data: chroniques,
          ));
        }

        // Posts immédiats
        final immediatePosts = mixedFeedProvider.immediatePosts;
        for (final post in immediatePosts) {
          if (post.id != null) {
            initialContent.add(ContentSection(
              type: ContentMixtType.POST,
              data: post,
            ));
            _displayedPostIds.add(post.id!);
          }
        }

        filteredContent = initialContent.cast<ContentSection>();

      } else {
        // 🔥 AUTRES FILTRES : Charger depuis Firebase
        filteredContent = await _loadFilteredPosts(newFilter);
      }

      setState(() {
        _currentContent = filteredContent;
        _isLoading = false;
      });

      print('✅ Filtre appliqué: ${filteredContent.length} éléments');

    } catch (e) {
      print('❌ Erreur application filtre: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  // 🔥 CHARGER LES POSTS FILTRÉS
  Future<List<ContentSection>> _loadFilteredPosts(FeedFilter filter) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null) return [];

    try {
      Query query = FirebaseFirestore.instance.collection('Posts');

      switch (filter) {
        case FeedFilter.SUBSCRIPTIONS:
          final userDoc = await FirebaseFirestore.instance.collection('Users').doc(currentUserId).get();
          final newPostsFromSubscriptions = List<String>.from(userDoc.data()?['newPostsFromSubscriptions'] ?? []);

          if (newPostsFromSubscriptions.isEmpty) return [];
          query = query.where('id', whereIn: newPostsFromSubscriptions.take(10));
          break;

        case FeedFilter.VIRAL:
          query = query.orderBy('feedScore', descending: true);
          break;

        case FeedFilter.CHALLENGE:
          query = query.where('type', isEqualTo: PostType.CHALLENGEPARTICIPATION.name);
          break;

        case FeedFilter.LOW_SCORE:
          query = query.orderBy('feedScore', descending: false);
          break;

        case FeedFilter.ALL:
        default:
          query = query.orderBy('created_at', descending: true);
          break;
      }

      query = query.limit(10);

      final snapshot = await query.get();

      final posts = snapshot.docs.map((doc) {
        try {
          return Post.fromJson(doc.data() as Map<String, dynamic>);
        } catch (e) {
          print('❌ Erreur parsing post ${doc.id}: $e');
          return null;
        }
      }).where((post) => post != null).cast<Post>().toList();

      // 🔥 CONTRÔLE DES DOUBLONS
      final uniquePosts = <Post>[];
      final seenIds = Set<String>();

      for (final post in posts) {
        if (post.id != null && !seenIds.contains(post.id!)) {
          uniquePosts.add(post);
          seenIds.add(post.id!);
        }
      }

      return uniquePosts.map((post) => ContentSection(
        type: ContentMixtType.POST,
        data: post,
      )).toList();

    } catch (e) {
      print('❌ Erreur chargement posts filtrés: $e');
      return [];
    }
  }

  // 🔥 CHARGEMENT SUPPLÉMENTAIRE
  Future<void> _loadMoreContent() async {
    if (_isLoadingMore) return;

    if (_currentFilter != FeedFilter.ALL) {
      await _loadMoreFilteredContent();
      return;
    }

    final mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);
    if (!mixedFeedProvider.hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final newContent = await mixedFeedProvider.loadMixedContent(loadMore: true);

      if (newContent.isNotEmpty) {
        // 🔥 FILTRER LES DOUBLONS
        final uniqueNewContent = <dynamic>[];
        for (final section in newContent) {
          if (section is ContentSection && section.type == ContentMixtType.POST) {
            final post = section.data as Post;
            if (post.id != null && !_displayedPostIds.contains(post.id!)) {
              uniqueNewContent.add(section);
              _displayedPostIds.add(post.id!);
            }
          } else {
            uniqueNewContent.add(section);
          }
        }

        if (uniqueNewContent.isNotEmpty) {
          setState(() {
            _currentContent.addAll(uniqueNewContent);
          });
          print('📥 Chargement supplémentaire: +${uniqueNewContent.length} éléments uniques');
        }
      }

    } catch (e) {
      print('❌ Erreur chargement supplémentaire: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  // 🔥 CHARGEMENT SUPPLÉMENTAIRE FILTRÉ
  Future<void> _loadMoreFilteredContent() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final morePosts = await _loadFilteredPosts(_currentFilter);

      if (morePosts.isNotEmpty) {
        // 🔥 FILTRER LES DOUBLONS
        final uniquePosts = <ContentSection>[];
        for (final section in morePosts) {
          final post = section.data as Post;
          if (post.id != null && !_displayedPostIds.contains(post.id!)) {
            uniquePosts.add(section);
            _displayedPostIds.add(post.id!);
          }
        }

        if (uniquePosts.isNotEmpty) {
          setState(() {
            _currentContent.addAll(uniquePosts);
          });
          print('📥 Chargement filtré supplémentaire: +${uniquePosts.length} éléments');
        }
      }

    } catch (e) {
      print('❌ Erreur chargement filtré supplémentaire: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  // 🔥 WIDGET DES FILTRES
  Widget _buildFilterChips() {
    return Container(
      height: 50,
      child: ListView.builder(
        controller: _filterScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _availableFilters.length,
        itemBuilder: (context, index) {
          final filter = _availableFilters[index];
          final isSelected = _currentFilter == filter;

          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 16 : 8,
              right: index == _availableFilters.length - 1 ? 16 : 0,
            ),
            child: FilterChip(
              label: Text('${filter.emoji} ${filter.label}'),
              selected: isSelected,
              onSelected: (selected) => _onFilterChanged(filter),
              backgroundColor: Colors.grey[800],
              selectedColor: Colors.green,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[300],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  // 🔥 CHARGEMENT DU TEMPS DE DERNIÈRE VISITE
  Future<void> _loadUserLastVisitTime() async {
    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final currentUser = authProvider.loginUserData;

      if (currentUser.lastFeedVisitTime != null) {
        _userLastVisitTime = currentUser.lastFeedVisitTime!;
      } else {
        _userLastVisitTime = DateTime.now().microsecondsSinceEpoch - Duration(hours: 1).inMicroseconds;
      }

      print('👤 Dernière visite: ${DateTime.fromMicrosecondsSinceEpoch(_userLastVisitTime)}');

    } catch (e) {
      print('❌ Erreur chargement dernière visite: $e');
      _userLastVisitTime = DateTime.now().microsecondsSinceEpoch - Duration(hours: 1).inMicroseconds;
    }
  }

  // 🔥 REFRESH COMPLET
  Future<void> _refreshData() async {
    print('🔄 Refresh manuel...');

    if (_isLoading || _isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _hasError = false;
    });

    try {
      _backgroundLoadTimer?.cancel();

      final mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);

      // Réinitialiser complètement
      await mixedFeedProvider.reset();
      _displayedPostIds.clear();
      _displayedChroniqueIds.clear();
      _hasDisplayedImmediatePosts = false;
      _isInitialLoadComplete = false;

      // Relancer l'initialisation
      await _initializePage();

      setState(() {
        _currentFilter = FeedFilter.ALL;
      });

      print('🆕 Refresh terminé');

    } catch (e) {
      print('❌ Erreur refresh: $e');
      setState(() => _hasError = true);
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      _loadMoreContent();
    }
  }

  // 🔥 CONSTRUCTION DES SECTIONS DE CONTENU
  Widget _buildContentSection(ContentSection section) {
    switch (section.type) {
      case ContentMixtType.POST:
        final post = section.data as Post;
        return _buildPostItem(post);

      case ContentMixtType.CHRONIQUES:
        final chroniques = section.data as List<Chronique>;
        return _buildChroniquesSection(chroniques);

      case ContentMixtType.ARTICLES:
        final articles = section.data as List<ArticleData>;
        return _buildArticlesSection(articles);

      case ContentMixtType.CANAUX:
        final canaux = section.data as List<Canal>;
        return _buildCanauxSection(canaux);

      default:
        return SizedBox.shrink();
    }
  }

  // 🔥 SECTION CHRONIQUES
  Widget _buildChroniquesSection(List<Chronique> chroniques) {
    if (!_isLoadingChroniques && _groupedChroniques.isEmpty && chroniques.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadChroniqueData(chroniques);
      });
    }

    return ChroniqueSectionComponent(
      videoThumbnails: _videoThumbnails,
      userVerificationStatus: _userVerificationStatus,
      userDataCache: _userDataCache,
      isLoadingChroniques: _isLoadingChroniques,
      groupedChroniques: _groupedChroniques,
    );
  }

  // 🔥 SECTION ARTICLES
  Widget _buildArticlesSection(List<ArticleData> articles) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return SpecialSectionsComponent.buildBoosterSection(
      articles: articles,
      context: context,
      width: width,
      height: height,
    );
  }

  // 🔥 SECTION CANAUX
  Widget _buildCanauxSection(List<Canal> canaux) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return SpecialSectionsComponent.buildCanalSection(
      canaux: canaux,
      context: context,
      width: width,
      height: height,
    );
  }

  // 🔥 WIDGET POST INDIVIDUEL
  Widget _buildPostItem(Post post) {
    final screenHeight = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    final isNewForUser = post.createdAt != null && post.createdAt! > _userLastVisitTime;

    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: (info) => _handlePostVisibility(post, info),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
          // border: isNewForUser ? Border.all(color: Colors.green, width: 2) : null,
        ),
        child: Stack(
          children: [
            post.type == PostType.CHALLENGEPARTICIPATION.name
                ? LookChallengePostWidget(
              post: post,
              height: screenHeight,
              width: width,
              onLiked: () => _onPostLiked(post),
              onCommented: () => _onPostCommented(post),
              onShared: () => _onPostShared(post),
              onLoved: () => _onPostLoved(post),
            )
                : HomePostUsersWidget(
              post: post,
              color: Colors.blue,
              height: screenHeight * 0.6,
              width: width,
              isDegrade: true,
              onLiked: () => _onPostLiked(post),
              onCommented: () => _onPostCommented(post),
              onShared: () => _onPostShared(post),
              onLoved: () => _onPostLoved(post),
            ),

            // if (isNewForUser)
            //   Positioned(
            //     top: 10,
            //     right: 10,
            //     child: Container(
            //       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            //       decoration: BoxDecoration(
            //         color: Colors.green,
            //         borderRadius: BorderRadius.circular(10),
            //       ),
            //       child: Row(
            //         mainAxisSize: MainAxisSize.min,
            //         children: [
            //           Icon(Icons.fiber_new, color: Colors.white, size: 14),
            //           SizedBox(width: 4),
            //           Text(
            //             'Nouveau',
            //             style: TextStyle(
            //               color: Colors.white,
            //               fontSize: 10,
            //               fontWeight: FontWeight.bold,
            //             ),
            //           ),
            //         ],
            //       ),
            //     ),
            //   ),

            if (post.createdAt != null)
              Positioned(
                bottom: 5,
                left: 5,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_formatPostDate(post.createdAt!)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 🔥 BODY PRINCIPAL
  Widget _buildBody(double width, double height) {
    print('🎯 Build avec: ${_currentContent.length} éléments - Filtre: ${_currentFilter.label}');

    if (_currentContent.isEmpty && (_isLoading || !_hasDisplayedImmediatePosts)) {
      return LoadingComponents.buildShimmerEffect();
    }

    if (_hasError && _currentContent.isEmpty) {
      return _buildErrorWidget();
    }

    if (_currentContent.isEmpty && _isInitialLoadComplete) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildFilterChips(),
        SizedBox(height: 8),
        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refreshData,
                backgroundColor: Colors.black,
                color: Colors.white,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          if (index == _currentContent.length) {
                            return _buildLoadingMore();
                          }
                          final section = _currentContent[index] as ContentSection;
                          return _buildContentSection(section);
                        },
                        childCount: _currentContent.length + (_shouldShowLoadingMore() ? 1 : 0),
                      ),
                    ),

                    if (!_shouldShowLoadingMore() && _currentContent.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildEndOfFeed(),
                      ),
                  ],
                ),
              ),

              if (_isRefreshing)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    color: Colors.black.withOpacity(0.8),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Actualisation...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 🔥 DÉTERMINER SI ON DOIT AFFICHER "CHARGEMENT SUPPLEMENTAIRE"
  bool _shouldShowLoadingMore() {
    if (_currentFilter != FeedFilter.ALL) {
      return true;
    }

    final mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);
    return mixedFeedProvider.hasMore && _isInitialLoadComplete;
  }

  // 🔥 MARQUER UN POST COMME VU
  void _handlePostVisibility2(Post post, VisibilityInfo info) {
    final postId = post.id!;
    _visibilityTimers[postId]?.cancel();

    if (info.visibleFraction > 0.8) {
      _visibilityTimers[postId] = Timer(Duration(seconds: 2), () {
        if (mounted && info.visibleFraction > 0.7) {
          _markPostAsSeen(post);
        }
      });
    } else if (info.visibleFraction < 0.3) {
      _visibilityTimers.remove(postId);
    }
  }



  void _handlePostVisibility(Post post, VisibilityInfo info) {
    final postId = post.id!;

    // // 🔥 VÉRIFIER SI DÉJÀ VU
    // if (_alreadyViewedPosts.contains(postId)) {
    //   return; // Déjà compté, on ne fait rien
    // }

    if (info.visibleFraction > 0.5) {
      _markPostAsSeen(post);
    }
  }
  Future<void> _markPostAsSeen(Post post) async {
    final currentUserId = _getUserId();
    // if (currentUserId.isEmpty || post.id == null) return;

    try {
      // // Évite double comptage local
      if (_alreadyViewedPosts.contains(post.id)) return;
      _alreadyViewedPosts.add(post.id!);

      // 🔥 Incrémente Firebase
       incrementPostViews(post.id!, currentUserId);

      // 🔥 Met à jour l'UI instantanément
      if (mounted) {
        setState(() {
          post.vues = (post.vues ?? 0) + 1;

          // post.users_vue_id ??= [];
          // if (!post.users_vue_id!.contains(currentUserId)) {
          //   post.users_vue_id!.add(currentUserId);
          // }
        });
      }

    } catch (e) {
      print("❌ Erreur lors de l'ajout d'une vue : $e");
    }
  }
  Future<void> incrementPostViews(String postId, String userId) async {
    final postRef = FirebaseFirestore.instance.collection('Posts').doc(postId);
    print('Pste vue vue vue encours');
    await postRef.update({
      "vues": FieldValue.increment(1),
      "users_vue_id": FieldValue.arrayUnion([userId]),
      // "last_view_at": FieldValue.serverTimestamp(),
    });

    print('Pste vue vue vue validé');
  }
  // 🔥 MÉTHODES POUR LES CHRONIQUES
  Future<void> _loadChroniqueData(List<Chronique> chroniques) async {
    if (_isLoadingChroniques) return;
    setState(() => _isLoadingChroniques = true);
    try {
      _groupedChroniques = _groupChroniquesByUser(chroniques);
      await _loadUserVerificationStatus(chroniques);
      await _loadUserData(chroniques);
      await _generateVideoThumbnails(chroniques);
    } catch (e) {
      print('❌ Erreur chargement données chroniques: $e');
    } finally {
      setState(() => _isLoadingChroniques = false);
    }
  }

  Future<void> _loadUserVerificationStatus(List<Chronique> chroniques) async {
    try {
      final userIds = chroniques.map((c) => c.userId).toSet();
      for (final userId in userIds) {
        if (!_userVerificationStatus.containsKey(userId)) {
          final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
          final isVerified = userDoc.data()?['isVerify'] ?? false;
          _userVerificationStatus[userId] = isVerified;
        }
      }
    } catch (e) {
      print('❌ Erreur chargement statut vérification: $e');
    }
  }

  Future<void> _loadUserData(List<Chronique> chroniques) async {
    try {
      final userIds = chroniques.map((c) => c.userId).toSet();
      for (final userId in userIds) {
        if (!_userDataCache.containsKey(userId)) {
          final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
          if (userDoc.exists) {
            final userData = UserData.fromJson(userDoc.data()!);
            _userDataCache[userId] = userData;
          }
        }
      }
    } catch (e) {
      print('❌ Erreur chargement données utilisateurs: $e');
    }
  }

  Future<void> _generateVideoThumbnails(List<Chronique> chroniques) async {
    try {
      final videoChroniques = chroniques.where((c) => c.type == ChroniqueType.VIDEO).toList();

      for (final chronique in videoChroniques) {
        if (chronique.mediaUrl != null && !_videoThumbnails.containsKey(chronique.id)) {
          // Générer le thumbnail
          final thumbnail = await _generateThumbnail(chronique.mediaUrl!);
          if (thumbnail != null) {
            _videoThumbnails[chronique.id!] = thumbnail;
          }
        }
      }
    } catch (e) {
      print('❌ Erreur génération thumbnails: $e');
    }
  }
  Future<Uint8List?> _generateThumbnail(String videoUrl) async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: 1000, // capture à 1 seconde, pour avoir un autre frame que le premier
      );
      return uint8list;
    } catch (e) {
      debugPrint("Erreur génération thumbnail: $e");
      return null;
    }
  }

  Map<String, List<Chronique>> _groupChroniquesByUser(List<Chronique> chroniques) {
    final grouped = <String, List<Chronique>>{};
    for (final chronique in chroniques) {
      grouped[chronique.userId] = [...grouped[chronique.userId] ?? [], chronique];
    }
    return grouped;
  }

  // 🔥 WIDGETS D'ÉTAT
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 64),
          SizedBox(height: 20),
          Text('Erreur de chargement', style: TextStyle(color: Colors.white, fontSize: 18)),
          SizedBox(height: 10),
          Text('Impossible de charger le contenu', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: Icon(Icons.refresh),
            label: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, color: Colors.grey, size: 64),
          SizedBox(height: 20),
          Text('Aucun contenu disponible', style: TextStyle(color: Colors.grey, fontSize: 16)),
          SizedBox(height: 10),
          Text('Le chargement semble avoir échoué', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: Text('Recommencer'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMore() {
    if (!_isLoadingMore) return SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text('Chargement de plus de contenu...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildEndOfFeed() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.flag, color: Colors.green, size: 40),
            SizedBox(height: 10),
            SizedBox(
                height: 30,
                width: 30,
                child: CircularProgressIndicator())
          ],
        ),
      ),
    );
  }

  // 🔥 MÉTHODES UTILITAIRES
  String _formatPostDate(int microSinceEpoch) {
    try {
      final date = DateTime.fromMicrosecondsSinceEpoch(microSinceEpoch);
      final now = DateTime.now();
      final difference = now.difference(date);
      if (difference.inMinutes < 1) return 'À l\'instant';
      if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes}min';
      if (difference.inHours < 24) return 'Il y a ${difference.inHours}h';
      if (difference.inDays < 7) return 'Il y a ${difference.inDays}j';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Date inconnue';
    }
  }

  String _getUserId() {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return authProvider.loginUserData.id ?? '';
  }

  void _onPostLiked(Post post) {
    FeedInteractionService.onPostLiked(post, _getUserId());
  }

  void _onPostCommented(Post post) {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => PostComments(post: post),
    //   ),
    // );
    // FeedInteractionService.onPostCommented(post, _getUserId());
  }

  void _onPostShared(Post post) {
    FeedInteractionService.onPostShared(post, _getUserId());
  }

  void _onPostLoved(Post post) {
    FeedInteractionService.onPostLoved(post, _getUserId());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filterScrollController.dispose();
    _backgroundLoadTimer?.cancel();
    _visibilityTimers.forEach((key, timer) => timer.cancel());
    _visibilityTimers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        title: Text('Découvrir 🚀', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed: _isRefreshing ? null : _refreshData,
                tooltip: 'Rafraîchir',
              ),
              if (_isRefreshing)
                Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle))),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'reset') {
                Provider.of<MixedFeedServiceProvider>(context, listen: false).reset();
                _refreshData();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(value: 'reset', child: Text('Réinitialiser le feed')),
            ],
          ),
        ],
      ),
      body: _buildBody(width, height),
    );
  }
}