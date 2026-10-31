import 'package:afrotok/services/read_meter.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/canal_mapper.dart';
import 'package:afrotok/services/api/post_mapper.dart';
import 'package:afrotok/services/api/posts_api.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/user/userService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  final FirebaseFirestore firestore = FirebaseFirestore.instance;


  List<UserServiceData> _userServices = [];
  DocumentSnapshot? _lastServiceDocument;
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
      _lastServiceDocument = null;
      _hasMoreServices = true;

      // Mettre à jour les filtres seulement si de nouvelles valeurs sont fournies
      if (category != null) _selectedCategory = category.isNotEmpty ? category : null;
      if (country != null) _selectedCountry = country.isNotEmpty ? country : null;
      if (city != null) _selectedCity = city.isNotEmpty ? city : null;
      if (searchQuery.isNotEmpty) _searchQuery = searchQuery;
    }

    try {
      CollectionReference servicesCollection =
      FirebaseFirestore.instance.collection('UserServices');

      // Construction de la requête de base
      Query query = servicesCollection
          .where("disponible", isEqualTo: true);

      // IMPORTANT: Vérifier que les champs existent avant d'appliquer les filtres
      // pour éviter les erreurs "needs an index"

      // Appliquer les filtres avec gestion d'erreurs
      try {
        if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
          query = query.where("category", isEqualTo: _selectedCategory);
        }
      } catch (e) {
        printVm('⚠️ Erreur filtre catégorie (peut-être besoin d\'index): $e');
        // Continuer sans ce filtre
      }

      try {
        if (_selectedCountry != null && _selectedCountry!.isNotEmpty) {
          query = query.where("country", isEqualTo: _selectedCountry);
        }
      } catch (e) {
        printVm('⚠️ Erreur filtre pays (peut-être besoin d\'index): $e');
        // Continuer sans ce filtre
      }

      try {
        if (_selectedCity != null && _selectedCity!.isNotEmpty) {
          query = query.where("city", isEqualTo: _selectedCity);
        }
      } catch (e) {
        printVm('⚠️ Erreur filtre ville (peut-être besoin d\'index): $e');
        // Continuer sans ce filtre
      }

      // Trier par date de création
      query = query.orderBy('createdAt', descending: true).limit(limit);

      // Pagination
      if (loadMore && _lastServiceDocument != null) {
        query = query.startAfterDocument(_lastServiceDocument!);
      }

      // Exécuter la requête
      QuerySnapshot querySnapshot = await query.getM('postProvider.dart:271');

      if (querySnapshot.docs.isEmpty) {
        _hasMoreServices = false;
      } else {
        _lastServiceDocument = querySnapshot.docs.last;

        List<UserServiceData> newServices = [];

        // Traiter chaque document
        for (var doc in querySnapshot.docs) {
          try {
            UserServiceData service = UserServiceData.fromJson(
                doc.data() as Map<String, dynamic>
            );

            // Ajouter l'ID du document
            service.id = doc.id;

            // Récupérer les données utilisateur de manière asynchrone mais sans bloquer
            try {
              DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
                  .collection('Users')
                  .doc(service.userId)
                  .getM('postProvider.dart:295');

              if (userSnapshot.exists) {
                UserData user = UserData.fromJson(
                    userSnapshot.data() as Map<String, dynamic>
                );
                service.user = user;
              }
            } catch (e) {
              printVm('❌ Erreur récupération user pour service ${service.id}: $e');
              // Créer un utilisateur minimal pour éviter les nulls
              service.user = UserData(
                // id: service.userId,
                pseudo: 'Utilisateur',
              );
            }

            newServices.add(service);
          } catch (e) {
            printVm('❌ Erreur parsing service: $e');
            continue; // Ignorer ce service et passer au suivant
          }
        }

        // Filtrage côté client pour la recherche texte (plus flexible)
        if (_searchQuery.isNotEmpty) {
          final searchLower = _searchQuery.toLowerCase().trim();
          newServices = newServices.where((service) {
            final titleLower = service.titre?.toLowerCase() ?? '';
            final descriptionLower = service.description?.toLowerCase() ?? '';
            final categoryLower = service.category?.toLowerCase() ?? '';
            final cityLower = service.city?.toLowerCase() ?? '';
            final countryLower = service.country?.toLowerCase() ?? '';
            final userPseudo = service.user?.pseudo?.toLowerCase() ?? '';

            return titleLower.contains(searchLower) ||
                descriptionLower.contains(searchLower) ||
                categoryLower.contains(searchLower) ||
                cityLower.contains(searchLower) ||
                countryLower.contains(searchLower) ||
                userPseudo.contains(searchLower);
          }).toList();
        }

        // Ajouter les nouveaux services à la liste
        if (loadMore) {
          _userServices.addAll(newServices);
        } else {
          _userServices = newServices;
        }

        // Déterminer s'il y a plus de services à charger
        _hasMoreServices = newServices.length == limit;
      }
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
  //     _lastServiceDocument = null;
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

  Future<List<UserServiceData>> getUserServiceById2(String id) async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('UserServices')
          .where("id", isEqualTo: id)
          .getM('postProvider.dart:492');

      List<UserServiceData> services = querySnapshot.docs.map((doc) =>
          UserServiceData.fromJson(doc.data() as Map<String, dynamic>)).toList();

      for (var service in services) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .doc(service.userId)
            .getM('postProvider.dart:501');

        if (userSnapshot.exists) {
          UserData user = UserData.fromJson(
              userSnapshot.data() as Map<String, dynamic>
          );
          service.user = user;
        }
      }

      return services;
    } catch (e) {
      printVm('Erreur récupération service: $e');
      return [];
    }
  }

  Future<bool> updateUserService2(UserServiceData service, BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('UserServices')
          .doc(service.id)
          .update(service.toJson());
      return true;
    } catch (e) {
      printVm('Erreur mise à jour service: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Future<List<String>> getServiceCities() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('UserServices')
          .where("disponible", isEqualTo: true)
          .where("city", isNotEqualTo: null)
          .where("city", isNotEqualTo: "")
          .getM('postProvider.dart:544');

      Set<String> cities = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['city'] != null) {
          cities.add(data['city']);
        }
      }

      return cities.toList()..sort();
    } catch (e) {
      printVm('Erreur récupération villes: $e');
      return [];
    }
  }

  void resetServicePagination() {
    _lastServiceDocument = null;
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
  Future<UserData?> _readUserOnce(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('Users').doc(userId).getM('postProvider.dart:576');
    final data = doc.data();
    return data == null ? null : UserData.fromJson(data);
  }

Future<void> interactWithPostAndIncrementSolde(String postId, String userId, String interactionType, String currentUserId) async {
    // La monétisation (gains par vue, j'aime, commentaire) est calculée par le serveur : rien à écrire ici.
  }
  Stream<NotificationData> getListNotification(String user_id) async* {
    var postStream = FirebaseFirestore.instance
        .collection('Notifications')
        .where("receiver_id", isEqualTo: user_id)
        .orderBy('created_at', descending: true)
        .limit(100)
        .snapshotsM('postProvider.dart:1005');

    await for (var snapshot in postStream) {
      for (var post in snapshot.docs) {
        NotificationData notification = NotificationData.fromJson(post.data());

        // Récupérer les infos de l'utilisateur associé
        QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
            .collection('Users')
            .where("id", isEqualTo: notification.user_id)
            .getM('postProvider.dart:1015');

        List<UserData> userList = querySnapshotUser.docs.map((doc) {
          return UserData.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        if (userList.isNotEmpty) {
          notification.userData = userList.first;
        }

        // Émettre chaque notification dès qu'elle est prête
        yield notification;
      }
    }
  }

  Stream<TransactionSolde> getTransactionsSoldes2(String user_id) async* {
    var postStream = FirebaseFirestore.instance
        .collection('TransactionSoldes')
        .where("user_id", isEqualTo: user_id)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshotsM('postProvider.dart:1037');

    await for (var snapshot in postStream) {
      for (var post in snapshot.docs) {
        TransactionSolde notification = TransactionSolde.fromJson(post.data());
        //
        // // Récupérer les infos de l'utilisateur associé
        // QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
        //     .collection('Users')
        //     .where("id", isEqualTo: notification.user_id)
        //     .getM('postProvider.dart:1047');
        //
        // List<UserData> userList = querySnapshotUser.docs.map((doc) {
        //   return UserData.fromJson(doc.data() as Map<String, dynamic>);
        // }).toList();
        //
        // if (userList.isNotEmpty) {
        //   notification.userData = userList.first;
        // }

        // Émettre chaque notification dès qu'elle est prête
        yield notification;
      }
    }
  }
  Stream<List<TransactionSolde>> getTransactionsSoldes(String user_id) async* {
    var postStream = FirebaseFirestore.instance
        .collection('TransactionSoldes')
        .where("user_id", isEqualTo: user_id)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshotsM('postProvider.dart:1068');

    List<TransactionSolde> transactions = [];

    await for (var snapshot in postStream) {
      for (var post in snapshot.docs) {
        TransactionSolde transaction = TransactionSolde.fromJson(post.data());
        transactions.add(transaction); // Ajouter la transaction à la liste
      }
      // Émettre la liste complète des transactions après chaque récupération de snapshot
      yield transactions;
    }
  }


  Stream<Canal> getCanaux2() async* {
    var postStream =  FirebaseFirestore.instance
        .collection('Canaux')
        .orderBy('updated_at', descending: true)
        .limit(100)
        .snapshotsM('postProvider.dart:1088');

    await for (var snapshot in postStream) {
      for (var post in snapshot.docs) {
        Canal canal = Canal.fromJson(post.data());


        // Récupérer les infos de l'utilisateur associé
        QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
            .collection('Users')
            .where("id", isEqualTo: canal.userId)
            .getM('postProvider.dart:1099');

        List<UserData> userList = querySnapshotUser.docs.map((doc) {
          return UserData.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        if (userList.isNotEmpty) {
          canal.user = userList.first;
        }

        // Émettre chaque notification dès qu'elle est prête
        yield canal;
      }
    }
  }

  Stream<List<Canal>> getCanaux() async* {
    var postStream = FirebaseFirestore.instance
        .collection('Canaux')
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshotsM('postProvider.dart:1120');

    await for (var snapshot in postStream) {
      List<Canal> canals = [];

      for (var post in snapshot.docs) {
        Canal canal = Canal.fromJson(post.data());

        // Récupérer les infos de l'utilisateur associé
        QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
            .collection('Users')
            .where("id", isEqualTo: canal.userId)
            .getM('postProvider.dart:1132');

        List<UserData> userList = querySnapshotUser.docs.map((doc) {
          return UserData.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        if (userList.isNotEmpty) {
          canal.user = userList.first;
        }

        canals.add(canal);
      }
      printVm('canals tailles: ${canals.length}');

      yield canals; // Émettre toute la liste au lieu d'un seul canal
    }
  }

  Stream<Canal> getCanauxByUser(String user_id) async* {
    var postStream =  FirebaseFirestore.instance
        .collection('Canaux')
        .where("userId", isEqualTo: user_id)
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshotsM('postProvider.dart:1156');

    await for (var snapshot in postStream) {
      for (var post in snapshot.docs) {
        Canal canal = Canal.fromJson(post.data());

        // Récupérer les infos de l'utilisateur associé
        QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
            .collection('Users')
            .where("id", isEqualTo: canal.userId)
            .getM('postProvider.dart:1166');

        List<UserData> userList = querySnapshotUser.docs.map((doc) {
          return UserData.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        if (userList.isNotEmpty) {
          canal.user = userList.first;
        }

        // Émettre chaque notification dès qu'elle est prête
        yield canal;
      }
    }
  }

  // NOUVELLE MÉTHODE : Récupérer tous les canaux où l'utilisateur est impliqué
  // Méthode pour récupérer seulement les canaux administrés
  Stream<Canal> getAdminCanaux(String userId) async* {
    try {
      final adminStream = firestore
          .collection('Canaux')
          .where("adminIds", arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .limit(100)
          .snapshotsM('postProvider.dart:1191');

      await for (var snapshot in adminStream) {
        for (var doc in snapshot.docs) {
          final canalData = doc.data() as Map<String, dynamic>;

          // Vérifier que l'utilisateur n'est pas le créateur
          if (canalData['userId'] != userId) {
            Canal canal = Canal.fromJson(canalData);
            canal.id = doc.id;

            // Récupérer les infos du créateur
            try {
              final creatorDoc = await firestore
                  .collection('Users')
                  .doc(canal.userId)
                  .getM('postProvider.dart:1207');

              if (creatorDoc.exists) {
                canal.user = UserData.fromJson(creatorDoc.data()!);
              }
            } catch (e) {
              printVm('Erreur récupération créateur: $e');
            }

            yield canal;
          }
        }
      }
    } catch (e) {
      printVm("Erreur récupération canaux admin: $e");
      throw e;
    }
  }


  Stream<List<NotificationData>> getListNotification2(String user_id) async* {
    var postStream = FirebaseFirestore.instance.collection('Notifications')
        .where("receiver_id",isEqualTo:'${user_id}')

        .orderBy('created_at', descending: true)
   .limit(100)

        .snapshotsM('postProvider.dart:1234');
    List<NotificationData> notifications = [];
    // //listConstposts =[];
    //  UserData userData=UserData();

    await for (var snapshot in postStream) {
      notifications=[];

      for (var post in snapshot.docs) {
        //  printVm("post : ${jsonDecode(post.toString())}");
        NotificationData notification=NotificationData.fromJson(post.data());
        QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
            .collection('Users')
            .where("id", isEqualTo: '${notification.user_id}')
            .getM('postProvider.dart:1248');

        List<UserData> userList = querySnapshotUser.docs.map((doc) {
          return UserData.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        if (userList.isNotEmpty) {
          notification.userData = userList.first;
        }
        notifications.add(notification);
      // listConstposts=posts;


      }
      yield notifications;
    }
  }
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

  Future<List<ArticleData>>
  getArticleById(String id) async {


    List<ArticleData> posts = [];
    //listConstposts =[];

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Articles');
    QuerySnapshot querySnapshotPost = await postCollect

        .where("id",isEqualTo:'${id}')


        .getM('postProvider.dart:2270');

    List<ArticleData> postList = querySnapshotPost.docs.map((doc) =>
        ArticleData.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


    for (ArticleData p in postList) {
      //  printVm("post : ${jsonDecode(post.toString())}");



      //get user
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').getM('postProvider.dart:2284');

      List<UserData> userList = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

//get entreprise


      p.user=userList.first;
      if (p.disponible==PostStatus.NONVALIDE.name) {
        // posts.add(p);
      }else if (p.disponible==PostStatus.SUPPRIMER.name) {
        // posts.add(p);
      }   else{
        posts.add(p);
      }




    }

    return posts;

  }















  Future<List<UserServiceData>>
  getUserServiceById(String id) async {


    List<UserServiceData> posts = [];
    //listConstposts =[];

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('UserServices');
    QuerySnapshot querySnapshotPost = await postCollect

        .where("id",isEqualTo:'${id}')
        .where("disponible",isEqualTo:true)


        .getM('postProvider.dart:2338');

    List<UserServiceData> postList = querySnapshotPost.docs.map((doc) =>
        UserServiceData.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


    for (UserServiceData p in postList) {
      //  printVm("post : ${jsonDecode(post.toString())}");



      //get user
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.userId}').getM('postProvider.dart:2352');

      List<UserData> userList = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

//get entreprise


      p.user=userList.first;
      if (p.disponible==PostStatus.NONVALIDE.name) {
        // posts.add(p);
      }else if (p.disponible==PostStatus.SUPPRIMER.name) {
        // posts.add(p);
      }   else{
        posts.add(p);
      }




    }

    return posts;

  }
  Future<List<UserServiceData>> getAllUserService() async {

    List<UserServiceData>  listArticles = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('UserServices');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect
          .where("disponible",isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(150)
          .getM('postProvider.dart:2389');

      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          UserServiceData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      for (var article in listArticles) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.userId).getM('postProvider.dart:2395');
        UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        // printVm(' UserServices user ${user.toJson()}');

        article.user = user;
      }
      listArticles.shuffle();
      listArticles.shuffle();



      printVm('list UserServices ${listArticles.length}');
      hasData=true;
      // teams.shuffle();




      return listArticles;
      // return teams;
    }catch(e){
      printVm("erreur ${e}");
      hasData=false;
      return [];
    }

  }

  Future<List<Canal>> getCanauxHome() async {

    List<Canal>  listArticles = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Canaux');
      // Get docs from collection reference
      // orderBy('canalScore') exclut les canaux sans ce champ — on trie client-side
      QuerySnapshot querySnapshotUser = await userCollect
          .limit(20)
          .getM('postProvider.dart:2434');

      // Tri client-side par canalScore (descend) — les canaux sans ce champ passent en dernier
      listArticles = querySnapshotUser.docs.map((doc) =>
          Canal.fromJson(doc.data() as Map<String, dynamic>)).toList();
      listArticles.sort((a, b) {
        final sa = (a.toJson()['canalScore'] as num?)?.toDouble() ?? 0.0;
        final sb = (b.toJson()['canalScore'] as num?)?.toDouble() ?? 0.0;
        return sb.compareTo(sa);
      });
      listArticles = listArticles.take(8).toList();
      for (var article in listArticles) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.userId).getM('postProvider.dart:2446');
        UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        article.user = user;
      }

      printVm('list UserServices ${listArticles.length}');
      hasData=true;




      return listArticles;
      // return teams;
    }catch(e){
      printVm("erreur ${e}");
      hasData=false;
      return [];
    }

  }

  Future<List<UserServiceData>> getAllUserServiceHome() async {

    List<UserServiceData>  listArticles = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('UserServices');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect
          .where("disponible",isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .getM('postProvider.dart:2479');

      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          UserServiceData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      for (var article in listArticles) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.userId).getM('postProvider.dart:2485');
        UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        // printVm(' UserServices user ${user.toJson()}');

        article.user = user;
      }
      listArticles.shuffle();
      listArticles.shuffle();



      printVm('list UserServices ${listArticles.length}');
      hasData=true;
      // teams.shuffle();




      return listArticles;
      // return teams;
    }catch(e){
      printVm("erreur ${e}");
      hasData=false;
      return [];
    }

  }
  Future<List<UserServiceData>> getAllOnlyUserService(String userId) async {

    List<UserServiceData>  listArticles = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('UserServices');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect
          .where("disponible",isEqualTo: true)
          .where("userId",isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(150)
          .getM('postProvider.dart:2525');

      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          UserServiceData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      for (var article in listArticles) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.userId).getM('postProvider.dart:2531');
        UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        // printVm(' UserServices user ${user.toJson()}');

        article.user = user;
      }
      listArticles.shuffle();



      printVm('list UserServices ${listArticles.length}');
      hasData=true;
      // teams.shuffle();




      return listArticles;
      // return teams;
    }catch(e){
      printVm("erreur ${e}");
      hasData=false;
      return [];
    }

  }


  Future<bool> updateUserService(UserServiceData data,BuildContext context) async {
    try{



      await FirebaseFirestore.instance
          .collection('UserServices')
          .doc(data.id)
          .update(data.toJson());

      return true;
    }catch(e){
      printVm("erreur update  : ${e}");
      return false;
    }
  }
  Future<bool> updateCanal(Canal data,BuildContext context) async {
    try{



      await FirebaseFirestore.instance
          .collection('Canaux')
          .doc(data.id)
          .update(data.toJson());

      return true;
    }catch(e){
      printVm("erreur update  : ${e}");
      return false;
    }
  }




  Future<List<EntrepriseData>>
  getEntreprise(String userId) async {


    List<EntrepriseData> posts = [];
    //listConstposts =[];

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Entreprises');
    QuerySnapshot querySnapshotPost = await postCollect

        .where("userId",isEqualTo:'${userId}')


        .getM('postProvider.dart:2608');

    List<EntrepriseData> postList = querySnapshotPost.docs.map((doc) =>
        EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


    for (EntrepriseData p in postList) {
      //  printVm("post : ${jsonDecode(post.toString())}");



      //get user
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.userId}').getM('postProvider.dart:2622');

      List<UserData> userList = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

//get entreprise

      //
      // p.user=userList.first;
      // if (p.disponible==PostStatus.NONVALIDE.name) {
      //   // posts.add(p);
      // }else if (p.disponible==PostStatus.SUPPRIMER.name) {
      //   // posts.add(p);
      // }   else{
      //   posts.add(p);
      // }

      printVm("Entrprise : ${p.titre}");
      posts.add(p);




    }

    return posts;

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
  Future<List<Canal>> getCanauxLimited(int limit) async {
    // Nouvelle API (si le module « channels » est activé dans Remote Config) ; en cas d'erreur on retombe sur Firebase.
    if (ApiGateway.instance.useApi('channels')) {
      try {
        final r = await ApiGateway.instance.client.get('/channels', query: {'limit': limit > 50 ? 50 : limit});
        final list = (ApiClient.data(r) as List).cast<Map<String, dynamic>>();
        return list.map(canalFromApi).toList();
      } catch (e) {
        printVm('❌ API CANAUX EN ÉCHEC — aucun retour à Firebase : $e');
        return [];
      }
    }
    try {
      QuerySnapshot snapshot = await firestore
          .collection('Canaux')
          .orderBy('updatedAt', descending: true)
          // .orderBy('createdAt', descending: true)
          .limit(limit)
          .getM('postProvider.dart:3459');

      return snapshot.docs.map((doc) {
        return Canal.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      printVm('Erreur getCanauxLimited: $e');
      return [];
    }
  }

// Dans PostProvider
}
