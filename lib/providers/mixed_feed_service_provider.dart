// mixed_feed_service_provider.dart
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

  MixedFeedService? get mixedFeedService => _mixedFeedService;
  bool get isPrepared => _isPrepared;
  bool get isPreparing => _isPreparing;
  String get status => _status;

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