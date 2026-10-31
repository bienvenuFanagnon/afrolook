// recent_posts_provider.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/services/api/home_feed_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:flutter/foundation.dart';
import 'package:afrotok/models/model_data.dart';

class RecentPostsProvider extends ChangeNotifier {
  // États
  List<Post> _posts = [];
  List<Post> _filteredPosts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _cursor;   // curseur de la page suivante de l'API
  String? _error;

  // Filtrage par pays
  String? _selectedCountryCode;
  bool _showAllCountries = true;

  // Constantes
  final int _limit = 6;
  final int _postsPerCountry = 3;

  // Getters
  List<Post> get posts => _filteredPosts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  /// Message d'erreur en français (null si tout va bien) : l'écran propose « Réessayer » ([refresh]).
  String? get error => _error;
  String? get selectedCountryCode => _selectedCountryCode;
  bool get showAllCountries => _showAllCountries;

  // Initialisation avec le pays de l'utilisateur
  Future<void> initialize(String? userCountryCode) async {
    _selectedCountryCode = userCountryCode?.toLowerCase();
    _showAllCountries = _selectedCountryCode != null;

    // await _loadInitialPosts();
  }

  // Chargement initial
  Future<void> _loadInitialPosts() async {
    try {
      _isLoading = true;
      notifyListeners();

      _posts.clear();
      _cursor = null;
      _error = null;

      Set<String> loadedIds = {};
      int targetTotal = 6;

      if (_showAllCountries) {
        // Mode "Tous pays" = 3 posts tous pays + 3 posts pays utilisateur
        await _loadPostsBatch(
          queryType: 'all_countries',
          limit: 4,
          loadedIds: loadedIds,
        );

        if (_selectedCountryCode != null && loadedIds.length < targetTotal) {
          await _loadPostsBatch(
            queryType: 'user_country',
            limit: targetTotal - loadedIds.length,
            loadedIds: loadedIds,
            countryCode: _selectedCountryCode,
          );
        }
      } else {
        // Mode "Pays spécifique" = maximum posts du pays, compléter avec tous pays
        if (_selectedCountryCode != null) {
          await _loadPostsBatch(
            queryType: 'specific_country',
            limit: 3,
            loadedIds: loadedIds,
            countryCode: _selectedCountryCode,
          );
        }

        // Compléter si nécessaire
        if (loadedIds.length < targetTotal) {
          await _loadPostsBatch(
            queryType: 'all_countries',
            limit: targetTotal - loadedIds.length,
            loadedIds: loadedIds,
          );
        }
      }

      // Mélanger et limiter
      _shuffleAndLimitPosts();

      _isLoading = false;
      notifyListeners();

    } catch (e) {
      _isLoading = false;
      _error = UsersApi.message(e);
      notifyListeners();
      printVm('Error loading initial posts: $e');
    }
  }

  Future<void> _loadPostsBatch({
    required String queryType,
    required int limit,
    required Set<String> loadedIds,
    String? countryCode,
  }) async {
    if (limit <= 0) return;

    final country = (queryType == 'all_countries') ? 'ALL' : countryCode?.toUpperCase();
    final page = await HomeFeedApi.discover(country: country, cursor: _cursor, limit: (limit * 2).clamp(1, 50));
    if (queryType == 'all_countries' && _cursor == null) _cursor = page.next;
    int added = 0;
    for (final post in page.posts) {
      if (added >= limit) break;
      if (post.id == null || loadedIds.contains(post.id)) continue;
      _posts.add(post);
      loadedIds.add(post.id!);
      added++;
    }
    printVm('✅ Batch $queryType: $added posts ajoutés');
  }


  // Mélanger et limiter les posts
  void _shuffleAndLimitPosts() {
    // Mélanger les posts pour éviter l'ordre chronologique strict
    _posts.shuffle();

    // Limiter au nombre maximum (6)
    if (_posts.length > _limit) {
      _posts = _posts.sublist(0, _limit);
    }

    _filteredPosts = List.from(_posts);
  }

  // Filtrer par pays spécifique
  Future<void> filterByCountry(String? countryCode) async {
    _selectedCountryCode = countryCode?.toLowerCase();
    _showAllCountries = countryCode == null;

    await _loadInitialPosts();
  }

  // Charger plus de posts
  Future<void> loadMorePosts() async {
    if (_isLoading || !_hasMore || _cursor == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final page = await HomeFeedApi.discover(cursor: _cursor, limit: _limit);
      _cursor = page.next;
      for (final post in page.posts) {
        if (post.id == null || _posts.any((p) => p.id == post.id)) continue;
        if (_showAllCountries || isPostAvailableInSelectedCountry(post)) _posts.add(post);
      }
      _hasMore = page.next != null;
      _filteredPosts = List.from(_posts);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = UsersApi.message(e);
      notifyListeners();
      printVm('Error loading more posts: $e');
    }
  }

  // Rafraîchir les posts
  Future<void> refresh() async {
    await _loadInitialPosts();
  }

  // Vérifier si un post est visible dans le pays sélectionné
  bool isPostAvailableInSelectedCountry(Post post) {
    if (_showAllCountries) return true;
    if (_selectedCountryCode == null) return true;

    return post.isAvailableInAllCountries == true ||
        (post.availableCountries?.contains(_selectedCountryCode!.toUpperCase()) ?? false);
  }

  // Obtenir l'icône du filtre actif
  String getFilterIcon() {
    if (_showAllCountries) return '🌍';
    if (_selectedCountryCode != null) {
      // Retourner l'emoji du drapeau ou le code du pays
      return _selectedCountryCode!.toUpperCase();
    }
    return '🌍';
  }

  // Obtenir le texte du filtre actif
  String getFilterText() {
    if (_showAllCountries) return 'Tous les pays';
    if (_selectedCountryCode != null) {
      return '${_selectedCountryCode!.toUpperCase()} seulement';
    }
    return 'Tous les pays';
  }
}