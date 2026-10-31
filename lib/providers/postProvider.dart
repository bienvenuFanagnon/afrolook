import 'package:afrotok/services/read_meter.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/canal_mapper.dart';
import 'package:afrotok/services/api/post_mapper.dart';
import 'package:afrotok/services/api/posts_api.dart';
import 'package:afrotok/services/api/publications_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/user/userService.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // uniquement updateMessage : les MESSAGES des chats restent sur Firebase
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chatmodels/message.dart';

import '../pages/component/consoleWidget.dart';
import '../pages/userPosts/postColorsWidget.dart';
import '../pages/widgetGlobal.dart';
import '../services/auth/authService.dart';
import 'authProvider.dart';



class PostProvider extends ChangeNotifier {
  late AuthService authService = AuthService();
  late UserService userService = UserService();
  late Chat chat = Chat();
  late Post postSelected = Post();
  List<Post> listConstposts = [];


  List<Post> videos = [];
  List<Post> listvideos = [];
  List<PostComment> listConstpostsComment = [];

  List<Message> usermessageList =[];



  List<UserServiceData> _userServices = [];
  String? _lastServiceCursor;
  bool _hasMoreServices = true;
  bool _isLoadingServices = false;
  String? _selectedCategory;
  String? _selectedCountry;
  String? _selectedCity;
  String _searchQuery = '';

  List<UserServiceData> get userServices => _userServices;
  bool get hasMoreServices => _hasMoreServices;
  bool get isLoadingServices => _isLoadingServices;
  String? get selectedCategory => _selectedCategory;
  String? get selectedCountry => _selectedCountry;
  String? get selectedCity => _selectedCity;


  // Nouvelles variables pour les suggestions
  List<Post> _suggestedPosts = [];
  bool _isLoadingSuggestions = false;
  bool _suggestionsLoaded = false; // pour éviter plusieurs chargements

  // Getters
  List<Post> get suggestedPosts => _suggestedPosts;
  bool get isLoadingSuggestions => _isLoadingSuggestions;
  static bool _globalSuggestionsLoaded = false; // partagé entre instances

  // Constructeur – lance le chargement non bloquant
  PostProvider() {
    _initSuggestions();
  }


  void _initSuggestions() {
    if (!_globalSuggestionsLoaded) {
      Future.microtask(() => _loadSuggestedPosts());
    }
  }

  // Méthode principale de chargement (modifiée pour gérer IMAGE et VIDEO)
Future<void> _loadSuggestedPosts() async {
    if (_isLoadingSuggestions || _suggestionsLoaded) return;
    _isLoadingSuggestions = true;
    notifyListeners();
    try {
      // Suggestions = découverte du serveur (publications non vues d'autres créateurs) ; aucun retour à Firebase en cas d'erreur.
      _suggestedPosts = await _discoveryPosts(10);
      _suggestionsLoaded = true;
    } catch (e) {
      printVm('Erreur chargement suggestions : $e');
    } finally {
      _isLoadingSuggestions = false;
      notifyListeners();
    }
  }

  /// Publications de découverte (niveau 3 du serveur : non vues, pays proche en premier).
  Future<List<Post>> _discoveryPosts(int limit) async {
    final r = await ApiGateway.instance.client.get('/feed', query: {'tier': 3, 'limit': limit});
    final rows = ((r as Map)['data'] as List? ?? const []).whereType<Map>();
    return rows.map((m) => postFromApi(Map<String, dynamic>.from(m))).where((p) => p.id != null).toList();
  }


  Future<List<UserServiceData>> getUserServices({
    bool loadMore = false,
    int limit = 6,
    String? category,
    String? country,
    String? city,
    String searchQuery = '',
    bool fromUserCountry = false, // Nouveau paramètre optionnel
  }) async {
    if (_isLoadingServices) return _userServices;

    _isLoadingServices = true;
    notifyListeners(); // Notifier immédiatement pour afficher le loader

    if (!loadMore) {
      _userServices = [];
      _lastServiceCursor = null;
      _hasMoreServices = true;

      // Mettre à jour les filtres seulement si de nouvelles valeurs sont fournies
      if (category != null) _selectedCategory = category.isNotEmpty ? category : null;
      if (country != null) _selectedCountry = country.isNotEmpty ? country : null;
      if (city != null) _selectedCity = city.isNotEmpty ? city : null;
      if (searchQuery.isNotEmpty) _searchQuery = searchQuery;
    }

    try {
      final page = await PubApi.services(
        category: _selectedCategory,
        country: _selectedCountry,
        city: _selectedCity,
        q: _searchQuery,
        cursor: loadMore ? _lastServiceCursor : null,
        limit: limit,
      );
      _lastServiceCursor = page.next;
      if (loadMore) {
        _userServices.addAll(page.items);
      } else {
        _userServices = page.items;
      }
      _hasMoreServices = page.next != null && page.items.isNotEmpty;
    } catch (e) {
      printVm('❌ Erreur critique chargement services: $e');

      // En cas d'erreur, réinitialiser pour permettre une nouvelle tentative
      if (!loadMore) {
        _userServices = [];
      }
      _hasMoreServices = false;

      // Afficher un message d'erreur (vous pouvez utiliser un SnackBar ou un dialog)
      // Vous pouvez ajouter un mécanisme de retry ici
    } finally {
      _isLoadingServices = false;
      notifyListeners(); // Important: notifier la fin du chargement
    }

    return _userServices;
  }


  // Future<List<UserServiceData>> getUserServices({
  //   bool loadMore = false,
  //   int limit = 6,
  //   String? category,
  //   String? country,
  //   String? city,
  //   String searchQuery = '',
  // }) async
  // {
  //   if (_isLoadingServices) return _userServices;
  //
  //   _isLoadingServices = true;
  //
  //   if (!loadMore) {
  //     _userServices = [];
  //     _lastServiceCursor = null;
  //     _hasMoreServices = true;
  //     _selectedCategory = category;
  //     _selectedCountry = country;
  //     _selectedCity = city;
  //     _searchQuery = searchQuery;
  //   }
  //
  //   try {
  //     CollectionReference servicesCollection =
  //     FirebaseFirestore.instance.collection('UserServices');
  //
  //     Query query = servicesCollection
  //         .where("disponible", isEqualTo: true);
  //
  //     // Appliquer les filtres
  //     if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
  //       query = query.where("category", isEqualTo: _selectedCategory);
  //     }
  //
  //     if (_selectedCountry != null && _selectedCountry!.isNotEmpty) {
  //       query = query.where("country", isEqualTo: _selectedCountry);
  //     }
  //
  //     if (_selectedCity != null && _selectedCity!.isNotEmpty) {
  //       query = query.where("city", isEqualTo: _selectedCity);
  //     }
  //
  //     query = query.orderBy('createdAt', descending: true).limit(limit);
  //
  //     if (_lastServiceDocument != null) {
  //       query = query.startAfterDocument(_lastServiceDocument!);
  //     }
  //
  //     QuerySnapshot querySnapshot = await query.getM('postProvider.dart:418');
  //
  //     if (querySnapshot.docs.isEmpty) {
  //       _hasMoreServices = false;
  //     } else {
  //       _lastServiceDocument = querySnapshot.docs.last;
  //
  //       List<UserServiceData> newServices = [];
  //
  //       for (var doc in querySnapshot.docs) {
  //         UserServiceData service = UserServiceData.fromJson(
  //             doc.data() as Map<String, dynamic>
  //         );
  //
  //         // Récupérer les données utilisateur
  //         try {
  //           DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
  //               .collection('Users')
  //               .doc(service.userId)
  //               .getM('postProvider.dart:437');
  //
  //           if (userSnapshot.exists) {
  //             UserData user = UserData.fromJson(
  //                 userSnapshot.data() as Map<String, dynamic>
  //             );
  //             service.user = user;
  //           }
  //         } catch (e) {
  //           printVm('Erreur récupération user: $e');
  //         }
  //
  //         newServices.add(service);
  //       }
  //
  //       // Filtrage côté client pour la recherche texte
  //       if (_searchQuery.isNotEmpty) {
  //         newServices = newServices.where((service) {
  //           final titleLower = service.titre?.toLowerCase() ?? '';
  //           final descriptionLower = service.description?.toLowerCase() ?? '';
  //           final categoryLower = service.category?.toLowerCase() ?? '';
  //           final cityLower = service.city?.toLowerCase() ?? '';
  //           final countryLower = service.country?.toLowerCase() ?? '';
  //           final searchLower = _searchQuery.toLowerCase();
  //
  //           return titleLower.contains(searchLower) ||
  //               descriptionLower.contains(searchLower) ||
  //               categoryLower.contains(searchLower) ||
  //               cityLower.contains(searchLower) ||
  //               countryLower.contains(searchLower);
  //         }).toList();
  //       }
  //
  //       if (loadMore) {
  //         _userServices.addAll(newServices);
  //       } else {
  //         _userServices = newServices;
  //       }
  //
  //       _hasMoreServices = newServices.length == limit;
  //     }
  //   } catch (e) {
  //     printVm('Erreur chargement services: $e');
  //   }
  //
  //   _isLoadingServices = false;
  //   notifyListeners();
  //   return _userServices;
  // }



  Future<List<String>> getServiceCities() async {
    try {
      return await PubApi.serviceCities();
    } catch (e) {
      printVm('Erreur récupération villes : $e');
      return [];
    }
  }

  void resetServicePagination() {
    _lastServiceCursor = null;
    _hasMoreServices = true;
    _isLoadingServices = false;
    _selectedCategory = null;
    _selectedCountry = null;
    _selectedCity = null;
    _searchQuery = '';
    _userServices = [];
    notifyListeners();
  }

  
  /// Profil d'une personne, lu une seule fois (null si introuvable).

Future<void> interactWithPostAndIncrementSolde(String postId, String userId, String interactionType, String currentUserId) async {
    // La monétisation (gains par vue, j'aime, commentaire) est calculée par le serveur : rien à écrire ici.
  }

  /// Transactions de la personne connectée (100 dernières, lues depuis l'API ; l'écran relit pour se rafraîchir).
  Stream<List<TransactionSolde>> getTransactionsSoldes(String user_id) async* {
    final page = await PubApi.transactions(user_id, limit: 100);
    yield page.items;
  }





  // NOUVELLE MÉTHODE : Récupérer tous les canaux où l'utilisateur est impliqué
  // Méthode pour récupérer seulement les canaux administrés


  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }


  Color colorFromHex(String? hexString) {
    if (hexString == null) return Colors.transparent;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

Stream<List<Post>> getPostsImages2(int limite, String tabBarType) async* {
    // Une page de découverte du serveur (images et textes) ; en cas d'erreur la liste reste vide (aucun retour à Firebase).
    try {
      final posts = (await _discoveryPosts(limite)).where((p) => p.dataType == PostDataType.IMAGE.name || p.dataType == PostDataType.TEXT.name).toList();
      listConstposts = posts;
      yield posts;
    } catch (e) {
      printVm('❌ API découverte (images) en échec : $e');
      yield <Post>[];
    }
  }

  bool isLoading=false;


  bool isReload=false;
Future<List<Post>> getPostsImagesById(String post_id) async {
    try {
      final p = await PostsApi.get(post_id);
      return p == null ? <Post>[] : [p];
    } catch (e) {
      printVm('❌ API publication $post_id en échec : $e');
      return <Post>[];
    }
  }
















  Future<List<UserServiceData>> getUserServiceById(String id) async {
    final s = await PubApi.service(id);
    return s == null || s.disponible == false ? <UserServiceData>[] : [s];
  }

  Future<List<Canal>> getCanauxHome() async {
    try {
      return await PubApi.topCanaux(myId: FirebaseAuth.instance.currentUser?.uid);
    } catch (e) {
      printVm('❌ API canaux (accueil) en échec : $e');
      return [];
    }
  }



  Future<bool> updateUserService(UserServiceData data, BuildContext context) async {
    try {
      await UsersApi.saveService(data.toJson(), id: data.id);
      return true;
    } catch (e) {
      printVm('erreur update service : ${PubApi.message(e)}');
      return false;
    }
  }
  Future<bool> updateCanal(Canal data, BuildContext context) async {
    // Date de dernière publication et compteur de publications d'un canal : tenus par le serveur à la création de la publication.
    return true;
  }




  Future<List<EntrepriseData>> getEntreprise(String userId) async {
    try {
      return await PubApi.businessesOf(userId);
    } catch (e) {
      printVm('❌ API entreprises en échec : $e');
      return [];
    }
  }
Stream<List<Post>> getPostsVideos(int limite) async* {
    // Une page de découverte du serveur (vidéos) ; en cas d'erreur la liste reste vide (aucun retour à Firebase).
    try {
      final posts = (await _discoveryPosts(limite < 20 ? 20 : limite)).where((p) => p.dataType == PostDataType.VIDEO.name).toList();
      videos = posts;
      yield posts;
    } catch (e) {
      printVm('❌ API découverte (vidéos) en échec : $e');
      yield <Post>[];
    }
  }

Future<List<Post>> getPostsVideosById(String post_id) async {
    try {
      final p = await PostsApi.get(post_id);
      videos = p == null ? <Post>[] : [p];
      return videos;
    } catch (e) {
      printVm('❌ API publication $post_id en échec : $e');
      return <Post>[];
    }
  }

  Future<List<Post>> getPostsVideosByPost(List<Post> posts) async {



    return posts;

  }



Future<bool> updateVuePost(Post post, BuildContext context) async {
    // Les vues sont comptées par le serveur (POST /posts/{id}/view) : plus d'écriture de la publication par l'application.
    return true;
  }
Future<bool> updateReplyPost(Post post, BuildContext context) async {
    // Plus d'écriture de la publication par l'application (voir lacunes_api_publications.md : remontée d'une publication).
    return true;
  }


Future<bool> updatePost(Post post, UserData userAction, BuildContext context) async {
    // Plus d'écriture de la publication ni des points par l'application : j'aime, favoris, vues et gains passent par l'API.
    return true;
  }
  Future<bool> updateMessage(Message message) async {
    try{



      await FirebaseFirestore.instance
          .collection('Messages')
          .doc(message.id)
          .update(message.toJson());
      //printVm("user update : ${user!.toJson()}");
      return true;
    }catch(e){
      printVm("erreur update message : ${e}");
      return false;
    }
  }


Future<bool> newComment(PostComment comment) async {
    lastCommentError = null;
    try {
      // 10 commentaires gratuits par publication, puis 1 pièce (erreur 402 insufficient_coins : voir [lastCommentError]).
      final sent = await CommentsApi.send(
        comment.post_id!,
        body: (comment.message ?? '').isEmpty ? null : comment.message,
        sticker: comment.media == null ? null : {'id': comment.media!['stickerId'], 'source': comment.media!['type'] == 'user_sticker' ? 'mine' : 'pack'},
      );
      final created = sent.comment;
      comment.id = created.id;
      comment.createdAt = created.createdAt;
      comment.updatedAt = created.updatedAt;
      notifyListeners();
      return true;
    } catch (e) {
      lastCommentError = e;
      printVm('erreur comment : $e');
      return false;
    }
  }

  /// Dernière erreur d'envoi de commentaire (ApiException : [ApiException.isInsufficientCoins] → proposer de recharger).
  Object? lastCommentError;

Future<bool> updateComment(PostComment comment) async {
    // Les nouvelles réponses (identifiant créé par l'application, donc plus court qu'un identifiant du serveur) sont envoyées à l'API.
    try {
      for (final r in List<ResponsePostComment>.of(comment.responseComments ?? const [])) {
        if ((r.id ?? '').length == 26) continue;
        final sent = await CommentsApi.send(comment.post_id!, body: r.message, parentId: comment.id);
        r.id = sent.reply.id;
      }
      notifyListeners();
      return true;
    } catch (e) {
      lastCommentError = e;
      printVm('erreur comment : $e');
      return false;
    }
  }

// Dans PostProvider

// Dans PostProvider
}
