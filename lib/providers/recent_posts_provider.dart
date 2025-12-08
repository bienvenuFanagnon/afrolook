// recent_posts_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:afrotok/models/model_data.dart';

class RecentPostsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // États
  List<Post> _posts = [];
  List<Post> _filteredPosts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

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
      _lastDocument = null;

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
      notifyListeners();
      print('Error loading initial posts: $e');
    }
  }

  Future<void> _loadPostsBatch({
    required String queryType,
    required int limit,
    required Set<String> loadedIds,
    String? countryCode,
  }) async {
    if (limit <= 0) return;

    try {
      Query query = _firestore.collection('Posts')
          .orderBy('created_at', descending: true)
          .limit(limit * 2); // Prendre plus pour compenser les filtres

      // Appliquer les filtres spécifiques
      switch (queryType) {
        case 'all_countries':
        // Chercher les deux formats possibles
          query = query.where('is_available_in_all_countries', isEqualTo: true);
          break;
        case 'specific_country':
        case 'user_country':
          if (countryCode != null) {
            // Posts disponibles pour ce pays (tous formats)
            query = query.where('available_countries', arrayContains: countryCode.toUpperCase());
          }
          break;
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty && _lastDocument == null) {
        _lastDocument = snapshot.docs.last;
      }

      int added = 0;
      for (var doc in snapshot.docs) {
        if (added >= limit) break;

        try {
          final post = Post.fromJson(doc.data() as Map<String, dynamic>);
          post.id = doc.id;

          if (!loadedIds.contains(post.id)) {
            // Normaliser le pays
            if (queryType == 'all_countries') {
              // post.isAvailableInAllCountries = true;
            }

            _posts.add(post);
            loadedIds.add(post.id!);
            added++;
          }
        } catch (e) {
          print('Error parsing post ${doc.id}: $e');
        }
      }

      print('✅ Batch $queryType: $added posts ajoutés');

    } catch (e) {
      print('❌ Error batch $queryType: $e');
    }
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
    if (_isLoading || !_hasMore || _lastDocument == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      Query query = _firestore.collection('Posts')

          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_limit);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;

        for (var doc in snapshot.docs) {
          try {
            final post = Post.fromJson(doc.data() as Map<String, dynamic>);
            post.id = doc.id;

            // Appliquer le filtre actuel
            if (_showAllCountries) {
              // Inclure tous les posts
              if (!_posts.any((p) => p.id == post.id)) {
                _posts.add(post);
              }
            } else if (_selectedCountryCode != null) {
              // Vérifier si le post est disponible dans le pays sélectionné
              final isAvailable = post.isAvailableInAllCountries == true ||
                  (post.availableCountries?.contains(_selectedCountryCode!.toUpperCase()) ?? false);

              if (isAvailable && !_posts.any((p) => p.id == post.id)) {
                _posts.add(post);
              }
            }
          } catch (e) {
            print('Error parsing post ${doc.id}: $e');
          }
        }
      }

      _hasMore = snapshot.docs.length == _limit;
      _filteredPosts = List.from(_posts);

      _isLoading = false;
      notifyListeners();

    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error loading more posts: $e');
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