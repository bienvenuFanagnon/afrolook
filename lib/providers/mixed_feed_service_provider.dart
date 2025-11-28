// mixed_feed_service_provider.dart
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:flutter/material.dart';
import '../services/postService/mixed_feed_service.dart';
import 'afroshop/categorie_produits_provider.dart';
import 'authProvider.dart';
import 'chroniqueProvider.dart';
import 'contenuPayantProvider.dart';

class MixedFeedServiceProvider extends ChangeNotifier {
  MixedFeedService? _mixedFeedService;
  bool _isPrepared = false;
  bool _isPreparing = false;
  String _status = 'Non initialisé';

  // 🔥 NOUVEAU: État pour les posts immédiats
  bool _areImmediatePostsLoaded = false;
  bool _isLoadingImmediatePosts = false;

  MixedFeedService? get mixedFeedService => _mixedFeedService;
  bool get isPrepared => _isPrepared;
  bool get isPreparing => _isPreparing;
  String get status => _status;

  // 🔥 GETTERS POUR POSTS IMMÉDIATS
  List<Post> get immediatePosts => _mixedFeedService?.immediatePosts ?? [];
  bool get areImmediatePostsLoaded => _areImmediatePostsLoaded;
  bool get isLoadingImmediatePosts => _isLoadingImmediatePosts;

  // 🔥 INITIALISATION DU SERVICE
  void initializeService({
    required UserAuthProvider authProvider,
    required CategorieProduitProvider categorieProvider,
    required PostProvider postProvider,
    required ChroniqueProvider chroniqueProvider,
    required ContentProvider contentProvider,
  }) {
    if (_mixedFeedService != null) return;

    _mixedFeedService = MixedFeedService(
      authProvider: authProvider,
      categorieProvider: categorieProvider,
      postProvider: postProvider,
      chroniqueProvider: chroniqueProvider,
      contentProvider: contentProvider,
    );

    _status = 'Service initialisé';
    notifyListeners();
  }

  // 🔥 CHARGEMENT DES POSTS IMMÉDIATS (à appeler depuis le Splash)
  Future<void> loadImmediatePosts() async {
    if (_isLoadingImmediatePosts || _areImmediatePostsLoaded || _mixedFeedService == null) return;

    _isLoadingImmediatePosts = true;
    _status = 'Chargement des posts immédiats...';
    notifyListeners();

    try {
      await _mixedFeedService!.loadImmediatePosts();

      _areImmediatePostsLoaded = true;
      _isLoadingImmediatePosts = false;
      _status = 'Posts immédiats prêts - ${_mixedFeedService!.immediatePosts.length} posts';

      print('✅ Provider: Posts immédiats chargés - ${_mixedFeedService!.immediatePosts.length} posts');

    } catch (e) {
      _isLoadingImmediatePosts = false;
      _status = 'Erreur chargement posts immédiats';
      print('❌ Provider: Erreur posts immédiats: $e');
    } finally {
      notifyListeners();
    }
  }

  // 🔥 PRÉPARATION DES POSTS (à appeler depuis le Splash)
  Future<void> preparePosts() async {
    if (_isPreparing || _isPrepared || _mixedFeedService == null) return;

    _isPreparing = true;
    _status = 'Préparation des posts...';
    notifyListeners();

    try {
      await _mixedFeedService!.preparePostsOnly();

      _isPrepared = true;
      _isPreparing = false;
      _status = 'Prêt - ${_mixedFeedService!.preparedPostsCount} posts';

      print('✅ Provider: Préparation terminée avec ${_mixedFeedService!.preparedPostsCount} posts');
    } catch (e) {
      _isPreparing = false;
      _status = 'Erreur de préparation';
      print('❌ Provider: Erreur préparation: $e');
    } finally {
      notifyListeners();
    }
  }

  // 🔥 CHARGEMENT DU CONTENU GLOBAL (à appeler depuis la page)
  Future<void> loadGlobalContent() async {
    if (_mixedFeedService == null) return;

    await _mixedFeedService!.loadGlobalContentFromPage();
    notifyListeners();
  }

  // 🔥 RÉINITIALISATION
  Future<void> reset() async {
    await _mixedFeedService?.reset();
    _isPrepared = false;
    _areImmediatePostsLoaded = false;
    _isLoadingImmediatePosts = false;
    _status = 'Réinitialisé';
    notifyListeners();
  }

  // 🔥 ACCÈS DIRECT AUX MÉTHODES DU SERVICE
  Future<List<dynamic>> loadMixedContent({bool loadMore = false}) async {
    if (_mixedFeedService == null) return [];
    return await _mixedFeedService!.loadMixedContent(loadMore: loadMore);
  }

  // GETTERS POUR ACCÈS DIRECT
  List<dynamic> get mixedContent => _mixedFeedService?.mixedContent ?? [];
  bool get isLoading => _mixedFeedService?.isLoading ?? false;
  bool get hasMore => _mixedFeedService?.hasMore ?? false;
  int get preparedPostsCount => _mixedFeedService?.preparedPostsCount ?? 0;
  bool get isReady => _mixedFeedService?.isReady ?? false;
}