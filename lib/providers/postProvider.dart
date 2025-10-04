import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/story/afroStory/repository.dart';
import 'package:afrotok/services/user/userService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_story_presenter/flutter_story_presenter.dart';

import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chatmodels/message.dart';

import '../pages/component/consoleWidget.dart';
import '../pages/userPosts/postColorsWidget.dart';
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

  Stream<List<Post>> getPostsImagesByUser(String userId) async* {
    var postStream = FirebaseFirestore.instance.collection('Posts')
        .where("user_id",isEqualTo:'${userId}')
        .where("type",isEqualTo:'${PostType.POST.name}')
        // .where("dataType",isEqualTo:'${PostDataType.IMAGE.name}')
        .where(
        Filter.or(
          Filter( "dataType",isEqualTo:'${PostDataType.IMAGE.name}'),
          Filter( "dataType",isEqualTo:'${PostDataType.TEXT.name}'),

        )

    )

        .orderBy('created_at', descending: true)

        .snapshots();
    List<Post> posts = [];
    //listConstposts =[];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {

      for (var post in snapshot.docs) {
        //  printVm("post : ${jsonDecode(post.toString())}");
        Post p=Post.fromJson(post.data());
        CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();
        // Afficher la liste


        List<UserData> userList = querySnapshotUser.docs.map((doc) =>
            UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        p.user=userList.first;
        posts.add(p);
        listConstposts=posts;


      }
      yield listConstposts;
    }
  }

  Stream<List<Post>> getChallengePostsImagesByUser(String userId) async* {
    var postStream = FirebaseFirestore.instance.collection('Posts')
        .where("user_id",isEqualTo:'${userId}')
        .where("type",isEqualTo:'${PostType.POST.name}')
    // .where("dataType",isEqualTo:'${PostDataType.IMAGE.name}')
        .where(
        "dataType",isEqualTo:'${PostDataType.IMAGE.name}'

    )

        .orderBy('created_at', descending: true)

        .snapshots();
    List<Post> posts = [];
    //listConstposts =[];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {

      for (var post in snapshot.docs) {
        //  printVm("post : ${jsonDecode(post.toString())}");
        Post p=Post.fromJson(post.data());
        CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();
        // Afficher la liste


        List<UserData> userList = querySnapshotUser.docs.map((doc) =>
            UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        p.user=userList.first;
        posts.add(p);
        listConstposts=posts;


      }
      yield listConstposts;
    }
  }

  Stream<List<Post>> getEntreprisePostsImagesByUser(String userId) async* {
    var postStream = FirebaseFirestore.instance.collection('Posts')
        .where("user_id",isEqualTo:'${userId}')
        .where("type",isEqualTo:'${PostType.PUB.name}')
        .where("dataType",isEqualTo:'${PostDataType.IMAGE.name}')
        .orderBy('created_at', descending: true)

        .snapshots();
    List<Post> posts = [];
    //listConstposts =[];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {

      for (var post in snapshot.docs) {
        //  printVm("post : ${jsonDecode(post.toString())}");
        Post p=Post.fromJson(post.data());
        CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();
        // Afficher la liste


        List<UserData> userList = querySnapshotUser.docs.map((doc) =>
            UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        if (p.type==PostType.PUB.name) {
          CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
          QuerySnapshot querySnapshotEntreprise = await entrepriseCollect.where("id",isEqualTo:'${p.entreprise_id}').get();

          List<EntrepriseData> entrepriseList = querySnapshotEntreprise.docs.map((doc) =>
              EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
          p.entrepriseData=entrepriseList.first;
        }
        p.user=userList.first;
        posts.add(p);
        listConstposts=posts;


      }
      yield listConstposts;
    }
  }

  Stream<List<Post>> getPubImagesByEntreprise(String entrepriseId) async* {
    var postStream = FirebaseFirestore.instance.collection('Posts')
        .where("entreprise_id",isEqualTo:'${entrepriseId}')
        .where("type",isEqualTo:'${PostType.PUB.name}')
        .where("dataType",isEqualTo:'${PostDataType.IMAGE.name}')
        .orderBy('created_at', descending: true)

        .snapshots();
    List<Post> posts = [];
    //listConstposts =[];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {

      for (var post in snapshot.docs) {
        //  printVm("post : ${jsonDecode(post.toString())}");
        Post p=Post.fromJson(post.data());
        CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();
        // Afficher la liste


        List<UserData> userList = querySnapshotUser.docs.map((doc) =>
            UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        if (p.type==PostType.PUB.name) {
          CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
          QuerySnapshot querySnapshotEntreprise = await entrepriseCollect.where("id",isEqualTo:'${p.entreprise_id}').get();

          List<EntrepriseData> entrepriseList = querySnapshotEntreprise.docs.map((doc) =>
              EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
          p.entrepriseData=entrepriseList.first;
        }
        p.user=userList.first;
        posts.add(p);
        listConstposts=posts;


      }
      yield listConstposts;
    }
  }
  Stream<List<Post>> getPubVideosByEntreprise(String entrepriseId) async* {
    var postStream = FirebaseFirestore.instance.collection('Posts')
        .where("entreprise_id",isEqualTo:'${entrepriseId}')
        .where("type",isEqualTo:'${PostType.PUB.name}')
        .where("dataType",isEqualTo:'${PostDataType.VIDEO.name}')
        .orderBy('created_at', descending: true)


        .snapshots();
    List<Post> posts = [];
    //listConstposts =[];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {

      for (var post in snapshot.docs) {
        //  printVm("post : ${jsonDecode(post.toString())}");
        Post p=Post.fromJson(post.data());
        CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();
        // Afficher la liste


        List<UserData> userList = querySnapshotUser.docs.map((doc) =>
            UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        if (p.type==PostType.PUB.name) {
          CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
          QuerySnapshot querySnapshotEntreprise = await entrepriseCollect.where("id",isEqualTo:'${p.entreprise_id}').get();

          List<EntrepriseData> entrepriseList = querySnapshotEntreprise.docs.map((doc) =>
              EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
          p.entrepriseData=entrepriseList.first;
        }
        p.user=userList.first;
        posts.add(p);
        listConstposts=posts;


      }
      yield listConstposts;
    }
  }



  Stream<List<Post>> getPostsVideoByUser(String userId) async* {
    var postStream = FirebaseFirestore.instance.collection('Posts')
        .where("user_id",isEqualTo:'${userId}')
        .where("type",isEqualTo:'${PostType.POST.name}')
        .where("dataType",isEqualTo:'${PostDataType.VIDEO.name}')
        .orderBy('created_at', descending: true)

        .snapshots();
    List<Post> posts = [];
    //listConstposts =[];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {

      for (var post in snapshot.docs) {
        //  printVm("post : ${jsonDecode(post.toString())}");
        Post p=Post.fromJson(post.data());
        CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();
        // Afficher la liste


        List<UserData> userList = querySnapshotUser.docs.map((doc) =>
            UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        if (p.type==PostType.PUB.name) {
          CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
          QuerySnapshot querySnapshotEntreprise = await entrepriseCollect.where("id",isEqualTo:'${p.entreprise_id}').get();

          List<EntrepriseData> entrepriseList = querySnapshotEntreprise.docs.map((doc) =>
              EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
          p.entrepriseData=entrepriseList.first;
        }
        p.user=userList.first;
        posts.add(p);
        listConstposts=posts;


      }
      yield listConstposts;
    }
  }
  Stream<List<PostMonetiser>> getListPostsMonetiser(String user_id) async* {
    var postStream = FirebaseFirestore.instance
        .collection('PostsMonetiser')
        .where("user_id", isEqualTo: user_id)
        .orderBy('solde', descending: true)
        .snapshots();

    await for (var snapshot in postStream) {
      List<PostMonetiser> postMonetiserList = [];
      StreamController<List<PostMonetiser>> controller = StreamController();

      for (var post in snapshot.docs) {
        PostMonetiser postMonetiser = PostMonetiser.fromJson(post.data());
        //  await getPostsImagesById(postMonetiser.post_id!).then(
        //   (postImages) {
        //     if (postImages.isNotEmpty) {
        //       printVm("------------------postImages.isNotEmpty -----------------");
        //       printVm('length poste  ;:${postImages.length}');
        //
        //       postMonetiser.post = postImages.first;
        //     } else {
        //       printVm("------------------postImages null -----------------");
        //
        //       postMonetiser.post = null; // Ou une valeur par défaut si nécessaire
        //     }
        //   },
        // );

        postMonetiserList.add(postMonetiser);
        controller.add(List.from(postMonetiserList)); // Émettre les posts au fur et à mesure
      }

      yield* controller.stream; // Émettre le stream mis à jour progressivement
    }
  }
  Stream<List<PostMonetiser>> getListPostsMonetiser3(String user_id) async* {
    var postStream = FirebaseFirestore.instance
        .collection('PostsMonetiser')
        .where("user_id", isEqualTo: user_id)
        .orderBy('solde', descending: true)
        .snapshots();

    await for (var snapshot in postStream) {
      List<PostMonetiser> postMonetiserList = [];
      for (var post in snapshot.docs) {
        PostMonetiser postMonetiser = PostMonetiser.fromJson(post.data());
        var postImages = await getPostsImagesById(postMonetiser.post_id!);
        if (postImages.isNotEmpty) {
          postMonetiser.post = postImages.first;
        }
        postMonetiserList.add(postMonetiser);
      }
      // Émettre la liste complète des posts
      yield postMonetiserList;
    }
  }

  Stream<PostMonetiser> getListPostsMonetiser2(String user_id) async* {
    var postStream = FirebaseFirestore.instance
        .collection('PostsMonetiser')
        .where("user_id", isEqualTo: user_id)
        .orderBy('solde', descending: true)
        // .limit(100)
        .snapshots();

    await for (var snapshot in postStream) {
      for (var post in snapshot.docs) {
        PostMonetiser postMonetiser = PostMonetiser.fromJson(post.data());
        getPostsImagesById(postMonetiser!.post_id!).then((value) {
          if(value.isNotEmpty){
            postMonetiser.post=value.first;

          }
        },);



        // Émettre chaque notification dès qu'elle est prête
        yield postMonetiser;
      }
    }
  }
  Future<void> addPostIdToAppDefaultData(String postId) async {
    if (postId.isEmpty) return;

    try {
      final appDefaultRef =
      FirebaseFirestore.instance.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT');
      // 🔹 remplace 'main' par l’ID de ton document AppDefaultData

      await appDefaultRef.update({
        'allPostIds': FieldValue.arrayUnion([postId]),
      });

      print("✅ Post $postId ajouté à AppDefaultData.allPostIds");
    } catch (e) {
      print("❌ Erreur lors de l'ajout du postId à AppDefaultData: $e");
    }
  }

  Future<PostMonetiser> getOrCreatePostMonetiser(String postId, String userId) async {
    // Référence à la collection 'PostsMonetiser'
    var collection = FirebaseFirestore.instance.collection('PostsMonetiser');

    // Rechercher le post par son ID
    var doc = await collection.doc(postId).get();

    if (doc.exists) {
      // Si le post existe, le retourner
      return PostMonetiser.fromJson(doc.data()!);
    } else {
      // Si le post n'existe pas, le créer
      PostMonetiser newPost = PostMonetiser(
        id: postId,
        user_id: userId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        solde: 0.1,
          users_comments_id: [],
          users_partage_id: [],
          users_like_id: []
      );

      // Ajouter le nouveau post à Firestore
      await collection.doc(postId).set(newPost.toJson());

      return newPost;
    }
  }


  Future<void> interactWithPostAndIncrementSolde(String postId, String userId, String interactionType,String currentUserId,) async {
    // Référence à la collection 'PostsMonetiser'
    printVm("like poste monetisation inter");
    printVm("like poste monetisation type ${interactionType}");

    var collection = FirebaseFirestore.instance.collection('PostsMonetiser');

    // Rechercher le post par son ID
    var doc = await collection
        .where("post_id", isEqualTo: postId)
        .get();

    PostMonetiser post;

    if (doc.docs.isNotEmpty) {
      // Si le post existe, le récupérer
      post = PostMonetiser.fromJson(doc.docs.first .data()!);
    } else {
      // Si le post n'existe pas, le créer avec des valeurs par défaut
      String postMId = FirebaseFirestore.instance
          .collection('PostsMonetiser')
          .doc()
          .id;
      PostMonetiser postMonetiser = PostMonetiser(
        id: postMId,
        user_id: currentUserId,
        post_id: postId,
        users_like_id: [],
        users_love_id: [],
        users_comments_id: [],
        users_partage_id: [],
        solde: 0.0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      printVm("like poste monetisation create");

      post=postMonetiser;
      await collection.doc(post.id).set(post.toJson());


    }

    bool shouldIncrement = false;

    // Vérifier le type d'interaction et mettre à jour la liste correspondante
    switch (interactionType) {
      case 'like':
        if (!(post.users_like_id?.contains(userId) ?? false)) {
          post.users_like_id?.add(userId);
          shouldIncrement = true;
        }
        break;
      case 'comment':
        if (!(post.users_comments_id?.contains(userId) ?? false)) {
          post.users_comments_id?.add(userId);
          shouldIncrement = true;
        }
        break;
      case 'share':
        if (!(post.users_partage_id?.contains(userId) ?? false)) {
          post.users_partage_id?.add(userId);
          shouldIncrement = true;
          print('nouveau partager ${post.toJson()}');

        }else{
          print('deja partager ${post.toJson()}');

        }
        break;
      default:
        print('Invalid interaction type');
        return;
    }
    print('mise à jour de post avant ${post.toJson()}');

    // Incrémenter le solde si nécessaire
    if (shouldIncrement) {
      post.solde = (post.solde ?? 0.0) + 1.1;
    }
    print('mise à jour de post money');
    print('mise à jour de post apres ${post.toJson()}');

    // Mettre à jour ou créer le post dans Firestore
    await collection.doc(post.id).update(post.toJson());

    }
  Stream<NotificationData> getListNotification(String user_id) async* {
    var postStream = FirebaseFirestore.instance
        .collection('Notifications')
        .where("receiver_id", isEqualTo: user_id)
        .orderBy('created_at', descending: true)
        .limit(100)
        .snapshots();

    await for (var snapshot in postStream) {
      for (var post in snapshot.docs) {
        NotificationData notification = NotificationData.fromJson(post.data());

        // Récupérer les infos de l'utilisateur associé
        QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
            .collection('Users')
            .where("id", isEqualTo: notification.user_id)
            .get();

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
        .snapshots();

    await for (var snapshot in postStream) {
      for (var post in snapshot.docs) {
        TransactionSolde notification = TransactionSolde.fromJson(post.data());
        //
        // // Récupérer les infos de l'utilisateur associé
        // QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
        //     .collection('Users')
        //     .where("id", isEqualTo: notification.user_id)
        //     .get();
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
        .snapshots();

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
        .snapshots();

    await for (var snapshot in postStream) {
      for (var post in snapshot.docs) {
        Canal canal = Canal.fromJson(post.data());


        // Récupérer les infos de l'utilisateur associé
        QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
            .collection('Users')
            .where("id", isEqualTo: canal.userId)
            .get();

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
        .snapshots();

    await for (var snapshot in postStream) {
      List<Canal> canals = [];

      for (var post in snapshot.docs) {
        Canal canal = Canal.fromJson(post.data());

        // Récupérer les infos de l'utilisateur associé
        QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
            .collection('Users')
            .where("id", isEqualTo: canal.userId)
            .get();

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
        .snapshots();

    await for (var snapshot in postStream) {
      for (var post in snapshot.docs) {
        Canal canal = Canal.fromJson(post.data());

        // Récupérer les infos de l'utilisateur associé
        QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
            .collection('Users')
            .where("id", isEqualTo: canal.userId)
            .get();

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


  Stream<List<NotificationData>> getListNotification2(String user_id) async* {
    var postStream = FirebaseFirestore.instance.collection('Notifications')
        .where("receiver_id",isEqualTo:'${user_id}')

        .orderBy('created_at', descending: true)
   .limit(100)

        .snapshots();
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
            .get();

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
  Stream<List<Post>> getEntreprisePostsVideoByUser(String userId) async* {
    var postStream = FirebaseFirestore.instance.collection('Posts')
        .where("user_id",isEqualTo:'${userId}')
        .where("type",isEqualTo:'${PostType.PUB.name}')
        .where("dataType",isEqualTo:'${PostDataType.VIDEO.name}')
        .orderBy('created_at', descending: true)

        .snapshots();
    List<Post> posts = [];
    //listConstposts =[];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {

      for (var post in snapshot.docs) {
        //  printVm("post : ${jsonDecode(post.toString())}");
        Post p=Post.fromJson(post.data());
        CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();
        // Afficher la liste


        List<UserData> userList = querySnapshotUser.docs.map((doc) =>
            UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        if (p.type==PostType.PUB.name) {
          CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
          QuerySnapshot querySnapshotEntreprise = await entrepriseCollect.where("id",isEqualTo:'${p.entreprise_id}').get();

          List<EntrepriseData> entrepriseList = querySnapshotEntreprise.docs.map((doc) =>
              EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
          p.entrepriseData=entrepriseList.first;
        }
        p.user=userList.first;
        posts.add(p);
        listConstposts=posts;


      }
      yield listConstposts;
    }
  }
  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }


  Future<List<Post>>
  getPostsImages(int limite) async {


    List<Post> posts = [];
    //listConstposts =[];
    DateTime afterDate = DateTime(2024, 11, 06); // Replace with your desired date

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
    QuerySnapshot querySnapshotPost = await postCollect

       // .where("status",isEqualTo:'${PostStatus.VALIDE.name}')
        .where(
        Filter.or(
          Filter( "dataType",isEqualTo:'${PostDataType.IMAGE.name}'),
          Filter( "dataType",isEqualTo:'${PostDataType.TEXT.name}'),

        )

       )
        // .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(afterDate))

        // .orderBy('created_at', descending: true)
        .orderBy('updated_at', descending: true)
    // .where('created_at', isGreaterThanOrEqualTo:  DateTime.now().microsecondsSinceEpoch)

        .limit(limite)

        .get();

    List<Post> postList = querySnapshotPost.docs.map((doc) =>
        Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();
    printVm("post length  ${postList.length}");


      for (Post p in postList) {
      //  printVm("post : ${jsonDecode(post.toString())}");

        if (p.status==PostStatus.NONVALIDE.name) {
          // posts.add(p);
        }else if (p.status==PostStatus.SUPPRIMER.name) {
          // posts.add(p);
        }   else{
          //get user
          CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
          QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();

          List<UserData> userList = querySnapshotUser.docs.map((doc) =>
              UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

//get entreprise
//         if (p.type==PostType.PUB.name) {
//           CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
//           QuerySnapshot querySnapshotEntreprise = await entrepriseCollect.where("id",isEqualTo:'${p.entreprise_id}').get();
//
//           List<EntrepriseData> entrepriseList = querySnapshotEntreprise.docs.map((doc) =>
//               EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
//           p.entrepriseData=entrepriseList.first;
//         }
          p.user=userList.first;

          posts.add(p);
        }








      }
    listConstposts=posts;
    //listConstposts.shuffle();
    notifyListeners(); // Notifie les écouteurs d'un changement

    return listConstposts;

  }

  Color colorFromHex(String? hexString) {
    if (hexString == null) return Colors.transparent;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<List<Post>> loadMorePosts(int limit, String type, DocumentSnapshot lastDoc) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('Posts')
          .where('type', isEqualTo: type)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastDoc)
          .limit(limit);

      QuerySnapshot snapshot = await query.get();

      List<Post> newPosts = snapshot.docs.map((doc) {
        return Post.fromJson(doc as Map<String,dynamic>);
      }).toList();

      return newPosts;
    } catch (e) {
      print("Erreur chargement posts: $e");
      return [];
    }
  }
  Stream<List<Post>> getPostsImages2(int limite,String tabBarType) async* {
    printVm("get canal data ");
    List<Post> posts = [];
    listConstposts = [];
    Set<String> postIdsToday = {}; // Ensemble pour les identifiants des posts du jour
    Set<String> postIdsWeek = {}; // Ensemble pour les identifiants des posts de la semaine
    Set<String> postIdsOthers = {}; // Ensemble pour les identifiants des autres posts
    DateTime afterDate = DateTime.now(); // Date de référence dynamique
    CollectionReference postCollect = FirebaseFirestore.instance.collection('Posts');
    int todayTimestamp = DateTime.now().microsecondsSinceEpoch;

    // Début de la journée actuelle (minuit)
    int startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).microsecondsSinceEpoch;

    // Fin de la journée actuelle (23:59:59)
    int endOfDay = startOfDay + Duration(hours: 23, minutes: 59, seconds: 59).inMicroseconds;

    // Début de la semaine actuelle (lundi minuit)
    int startOfWeek = startOfDay - Duration(days: DateTime.now().weekday - 1).inMicroseconds;

    // Fin de la semaine actuelle (dimanche 23:59:59)
    int endOfWeek = startOfWeek + Duration(days: 6, hours: 23, minutes: 59, seconds: 59).inMicroseconds;

    // 1. Récupérer les publications de la journée
    Query queryToday = postCollect
        .where(
      Filter.or(
        Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
        Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
      ),
    )
        .where("created_at", isGreaterThanOrEqualTo: startOfDay)
        .where("created_at", isLessThanOrEqualTo: endOfDay)
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .where("typeTabbar", isEqualTo:tabBarType )
        .where("type", isEqualTo: PostType.POST.name)
        .orderBy('created_at', descending: true)
        .limit(limite);

    // 2. Récupérer les publications de la semaine
    Query queryWeek = postCollect
        .where(
      Filter.or(
        Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
        Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
      ),
    )
        .where("created_at", isGreaterThanOrEqualTo: startOfWeek)
        .where("created_at", isLessThanOrEqualTo: endOfWeek)
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .where("typeTabbar", isEqualTo:tabBarType )

        .where("type", isEqualTo: PostType.POST.name)
        .orderBy('created_at', descending: true)
        .limit(limite);

    // 3. Récupérer les publications restantes
    Query queryOthers = postCollect
        .where(
      Filter.or(
        Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
        Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
      ),
    )
        .where("created_at", isLessThan: startOfWeek)
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .where("typeTabbar", isEqualTo:tabBarType )

        .where("type", isEqualTo: PostType.POST.name)
        .orderBy('updated_at', descending: true)
        .limit(limite);

    // Effectuer les requêtes en parallèle
    List<DocumentSnapshot> todayPosts = (await queryToday.get()).docs;
    List<DocumentSnapshot> weekPosts = (await queryWeek.get()).docs;
    List<DocumentSnapshot> otherPosts = (await queryOthers.get()).docs;

    // Traiter les documents de la journée
    for (var doc in todayPosts) {
      Post post = Post.fromJson(doc.data() as Map<String, dynamic>);
      if(post.colorDomine==null){
        if(post.images!=null&&post.images!.isNotEmpty){

          await extractColorsFromImageUrl(post!.images!.first!).then((value) {
            post.colorDomine= value['dominantColor'];
            post.colorSecondaire= value['vibrantColor'];

          },);

        }else{
          await extractColorsFromImageUrl("").then((value) {
            post.colorDomine= value['dominantColor'];
            post.colorSecondaire= value['vibrantColor'];

          },);
        }

      }

      // Vérifier si l'identifiant du post est déjà dans l'ensemble du jour
      if (postIdsToday.contains(post.id)) {
        continue; // Passer au document suivant si le post est déjà ajouté
      }

      // Ajouter l'identifiant du post à l'ensemble du jour
      postIdsToday.add(post.id!);

      // Récupérer les données utilisateur liées
      QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
          .collection('Users')
          .where("id", isEqualTo: '${post.user_id}')
          .get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) {
        return UserData.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      if (post.canal_id!.isNotEmpty) {
        QuerySnapshot querySnapshotCanal = await FirebaseFirestore.instance
            .collection('Canaux')
            .where("id", isEqualTo: '${post.canal_id}')
            .get();

        List<Canal> canalList = querySnapshotCanal.docs.map((doc) {
          return Canal.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        if (canalList.isNotEmpty) {
          post.canal = canalList.first;
        }
      }

      if (userList.isNotEmpty) {
        post.user = userList.first;
      }

      // Ajouter le post à la liste
      posts.add(post);
      listConstposts.add(post);

      // Transmettre les données partiellement récupérées
      yield posts;
    }

    // Traiter les documents de la semaine
    for (var doc in weekPosts) {
      Post post = Post.fromJson(doc.data() as Map<String, dynamic>);

      // Vérifier si l'identifiant du post est déjà dans l'ensemble du jour ou de la semaine
      if (postIdsToday.contains(post.id) || postIdsWeek.contains(post.id)) {
        continue; // Passer au document suivant si le post est déjà ajouté
      }

      // Ajouter l'identifiant du post à l'ensemble de la semaine
      postIdsWeek.add(post.id!);

      // Récupérer les données utilisateur liées
      QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
          .collection('Users')
          .where("id", isEqualTo: '${post.user_id}')
          .get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) {
        return UserData.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      if (post.canal_id!.isNotEmpty) {
        QuerySnapshot querySnapshotCanal = await FirebaseFirestore.instance
            .collection('Canaux')
            .where("id", isEqualTo: '${post.canal_id}')
            .get();

        List<Canal> canalList = querySnapshotCanal.docs.map((doc) {
          return Canal.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        if (canalList.isNotEmpty) {
          post.canal = canalList.first;
        }
      }

      if (userList.isNotEmpty) {
        post.user = userList.first;
      }

      // Ajouter le post à la liste
      posts.add(post);
      listConstposts.add(post);

      // Transmettre les données partiellement récupérées
      yield posts;
    }

    // Traiter les autres documents
    for (var doc in otherPosts) {
      Post post = Post.fromJson(doc.data() as Map<String, dynamic>);

      // Vérifier si l'identifiant du post est déjà dans l'ensemble du jour, de la semaine ou des autres
      if (postIdsToday.contains(post.id) || postIdsWeek.contains(post.id) || postIdsOthers.contains(post.id)) {
        continue; // Passer au document suivant si le post est déjà ajouté
      }

      // Ajouter l'identifiant du post à l'ensemble des autres
      postIdsOthers.add(post.id!);

      // Récupérer les données utilisateur liées
      QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
          .collection('Users')
          .where("id", isEqualTo: '${post.user_id}')
          .get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) {
        return UserData.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      if (post.canal_id!.isNotEmpty) {
        QuerySnapshot querySnapshotCanal = await FirebaseFirestore.instance
            .collection('Canaux')
            .where("id", isEqualTo: '${post.canal_id}')
            .get();

        List<Canal> canalList = querySnapshotCanal.docs.map((doc) {
          return Canal.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        if (canalList.isNotEmpty) {
          post.canal = canalList.first;
        }
      }

      if (userList.isNotEmpty) {
        post.user = userList.first;
      }

      // Ajouter le post à la liste
      posts.add(post);
      listConstposts.add(post);

      // Transmettre les données partiellement récupérées
      yield posts;
    }
  }

  Stream<List<Post>> getCanalPosts(int limite,Canal canal) async* {
    List<Post> posts = [];
    listConstposts = [];
    DateTime afterDate = DateTime(2024, 11, 06); // Date de référence
    CollectionReference postCollect = FirebaseFirestore.instance.collection('Posts');
    int todayTimestamp = DateTime.now().microsecondsSinceEpoch;

// Début de la journée actuelle (minuit)
    int startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).microsecondsSinceEpoch;

// Fin de la journée actuelle (23:59:59)
    int endOfDay = startOfDay + Duration(hours: 23, minutes: 59, seconds: 59).inMicroseconds;
    // 1. Récupérer les publications de la journée
    // Query queryToday = postCollect
    //     .where(
    //   Filter.or(
    //     Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
    //     Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
    //   ),
    // )
    // // .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
    //     .where("created_at", isGreaterThanOrEqualTo: startOfDay)
    //     .where("created_at", isLessThanOrEqualTo: endOfDay)
    //     .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
    //     .where("type", isEqualTo: PostType.POST.name)
    //     .orderBy('created_at', descending: true)
    // // .orderBy('updated_at', descending: true)
    //     .limit(limite);
    //
    //
    // Query queryPub = postCollect
    //     .where(
    //   Filter.or(
    //     Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
    //     Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
    //   ),
    // )
    //     .where("type", isEqualTo: PostType.PUB.name)
    //     .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
    //     .orderBy('created_at', descending: true)
    // // .orderBy('updated_at', descending: true)
    //     .where("type", isEqualTo: PostType.POST.name)
    //
    //     .limit(limite);

// 2. Récupérer les publications restantes
    Query queryOthers = postCollect
        .where(
      Filter.or(
        Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
        Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
      ),
    )
    // .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
    //     .where("created_at", isLessThan: startOfDay)
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .where("type", isEqualTo: PostType.POST.name)
        .where("canal_id", isEqualTo: canal.id!)

        .orderBy('created_at', descending: true)
        .limit(limite);

    // Query query = postCollect
    //     .where(
    //   Filter.or(
    //     Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
    //     Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
    //   ),
    // )
    //     .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
    //     .where("created_at", isGreaterThanOrEqualTo: startOfDay) // Pour les publications de la journée
    //     .orderBy('updated_at', descending: true)
    //     .limit(limite);

    // // Effectuer une requête pour récupérer les posts
    // Query query = postCollect
    //     .where(
    //   Filter.or(
    //     Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
    //     Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
    //   ),
    //
    // )      .where(
    //     "status", isNotEqualTo: PostStatus.SUPPRIMER.name
    //
    // )
    //     .where('created_at', isGreaterThanOrEqualTo: DateTime.now().microsecondsSinceEpoch
    // )
    //
    //     .orderBy('updated_at', descending: true)
    //     .limit(limite);

    // Effectuer les deux requêtes en parallèle
    // List<DocumentSnapshot> pubPosts = (await queryPub.get()).docs;
    // List<DocumentSnapshot> todayPosts = (await queryToday.get()).docs;
    List<DocumentSnapshot> otherPosts = (await queryOthers.get()).docs;

    // Combiner les résultats
    List<DocumentSnapshot> querySnapshotPosts = [ ...otherPosts];
    // List<DocumentSnapshot> querySnapshotPosts = [...pubPosts,...todayPosts, ...otherPosts];

    // QuerySnapshot querySnapshotPost = await query.get();

    // QuerySnapshot querySnapshotPost = await query.get();

    // List<Post> postList = querySnapshotPost.docs.map((doc) {
    //   Post post = Post.fromJson(doc.data() as Map<String, dynamic>);
    //   return post;
    // }).where((post) =>
    // post.status != PostStatus.NONVALIDE.name &&
    //     post.status != PostStatus.SUPPRIMER.name).toList();

    // Traiter les documents progressivement
    // for (var doc in querySnapshotPost.docs) {
    for (var doc in querySnapshotPosts) {
      Post post = Post.fromJson(doc.data() as Map<String, dynamic>);

      // Filtrer selon le statut
      // if (post.status != PostStatus.NONVALIDE.name &&
      //     post.status != PostStatus.SUPPRIMER.name) {
      // Récupérer les données utilisateur liées
      QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
          .collection('Users')
          .where("id", isEqualTo: '${post.user_id}')
          .get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) {
        return UserData.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      QuerySnapshot querySnapshotCanal = await FirebaseFirestore.instance
          .collection('Canaux')
          .where("id", isEqualTo: '${post.canal_id}')
          .get();

      List<Canal> canalList = querySnapshotCanal.docs.map((doc) {
        return Canal.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      if (userList.isNotEmpty) {
        post.user = userList.first;
      }
      if (canalList.isNotEmpty) {
        post.canal = canalList.first;
      }

      // Ajouter le post à la liste
      posts.add(post);
      listConstposts.add(post);
      // Transmettre les données partiellement récupérées
      yield posts;
      //}
    }
  }

  DocumentSnapshot? lastDocumentData;
  Post? lastPostData;
  bool isLoading=false;


  Stream<List<Post>> getPostsImages3(int limite,
      {required bool getLast})
  async* {
    List<Post> posts = [];
    DateTime afterDate = DateTime(2024, 11, 06); // Date de référence
    CollectionReference postCollect = FirebaseFirestore.instance.collection('Posts');
    printVm("lastDocument data");

    // printVm("lastDocument: ${lastDocument!.data()}");

    // Construct query for first 25 cities, ordered by population
    final query = postCollect.where(
    Filter.or(
    Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
    Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
    ),
    )
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        // .orderBy('updated_at', descending: true).startAfterDocument(lastDocument!)
        .limit(limite);
    if(getLast){

      query.get().then(
            (documentSnapshots) {
          // Get the last visible document
          final lastVisible = documentSnapshots.docs[documentSnapshots.size - 1];

          // Construct a new query starting at this document,
          // get the next 25 cities.
          final next = postCollect.where(
            Filter.or(
              Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
              Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
            ),
          )
              .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
              .orderBy('updated_at', descending: true)
              .startAfterDocument(lastVisible!)
              .limit(limite);

          // Use the query for pagination
          // ...
        },
        onError: (e) => print("Error completing: $e"),
      );
    }else{

      query.get().then(
            (documentSnapshots) {
          // Get the last visible document
          // final lastVisible = documentSnapshots.docs[documentSnapshots.size - 1];

          // Construct a new query starting at this document,
          // get the next 25 cities.
          final next = postCollect.where(
            Filter.or(
              Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
              Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
            ),
          )
              .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
              .orderBy('updated_at', descending: true)
              // .startAfterDocument(lastVisible!)
              .limit(limite);

          // Use the query for pagination
          // ...
        },
        onError: (e) => print("Error completing: $e"),
      );
    }

    query.get().then(
          (documentSnapshots) {
        // Get the last visible document
        final lastVisible = documentSnapshots.docs[documentSnapshots.size - 1];

        // Construct a new query starting at this document,
        // get the next 25 cities.
        final next = postCollect.where(
          Filter.or(
            Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
            Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
          ),
        )
            .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
            .orderBy('updated_at', descending: true)
            .startAfterDocument(lastVisible!)
            .limit(limite);

        // Use the query for pagination
        // ...
      },
      onError: (e) => print("Error completing: $e"),
    );

    // Effectuer une requête pour récupérer les posts
    // Query query = postCollect
    //     .where(
    //   Filter.or(
    //     Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
    //     Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
    //   ),
    // )
    //     .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
    //     .orderBy('updated_at', descending: true).startAfterDocument(lastDocument!)
    //     .limit(limite);



    // Si un dernier document est fourni, on pagine à partir de celui-ci
    // if (lastDocument != null) {
    //   query = query.startAfterDocument(lastDocument!);
    // }

    // Exécuter la requête
    QuerySnapshot querySnapshotPost = await query.get();
    lastDocumentData= querySnapshotPost.docs.last;

    // Traiter les documents récupérés
    for (var doc in querySnapshotPost.docs) {
      Post post = Post.fromJson(doc.data() as Map<String, dynamic>);

      // Récupérer les données utilisateur liées
      QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
          .collection('Users')
          .where("id", isEqualTo: '${post.user_id}')
          .get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) {
        return UserData.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      if (userList.isNotEmpty) {
        post.user = userList.first;
      }

      posts.add(post);
    }
    isLoading=false;
    // Transmettre les données récupérées
    yield posts;

    // Si des documents ont été récupérés, on donne la possibilité de charger plus
    // if (querySnapshotPost.docs.isNotEmpty) {
    //   yield* getPostsImages2(limite, lastDocument: querySnapshotPost.docs.last);
    // }
  }


  bool isReload=false;
  Future<List<Post>>
  reloadPostsImages(int limite,ScrollController _scrollController ) async {

    isReload=true;
    List<Post> posts = [];
    // //listConstposts =[];
    DateTime afterDate = DateTime(2024, 11, 06); // Replace with your desired date

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
    QuerySnapshot querySnapshotPost = await postCollect

    // .where("status",isEqualTo:'${PostStatus.VALIDE.name}')
        .where(
        Filter.or(
          Filter( "dataType",isEqualTo:'${PostDataType.IMAGE.name}'),
          Filter( "dataType",isEqualTo:'${PostDataType.TEXT.name}'),

        )

    )
    // .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(afterDate))

        .orderBy('created_at', descending: true)
    // .orderBy('updated_at', descending: true)
        .limit(limite)

        .get();

    List<Post> postList = querySnapshotPost.docs.map((doc) =>
        Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();
    printVm("post length  ${postList.length}");


    for (Post p in postList) {
      //  printVm("post : ${jsonDecode(post.toString())}");

      if (p.status==PostStatus.NONVALIDE.name) {
        // posts.add(p);
      }else if (p.status==PostStatus.SUPPRIMER.name) {
        // posts.add(p);
      }   else{
        //get user
        CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();

        List<UserData> userList = querySnapshotUser.docs.map((doc) =>
            UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

//get entreprise
//         if (p.type==PostType.PUB.name) {
//           CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
//           QuerySnapshot querySnapshotEntreprise = await entrepriseCollect.where("id",isEqualTo:'${p.entreprise_id}').get();
//
//           List<EntrepriseData> entrepriseList = querySnapshotEntreprise.docs.map((doc) =>
//               EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
//           p.entrepriseData=entrepriseList.first;
//         }
        p.user=userList.first;

        posts.add(p);
      }








    }
    listConstposts=posts;
    isReload=false;

    if(listConstposts.isNotEmpty){
      _scrollController.animateTo(
        0.0,
        duration: Duration(milliseconds: 1000),
        curve: Curves.ease,
      );
    }


    //listConstposts.shuffle();
    notifyListeners(); // Notifie les écouteurs d'un changement

    return listConstposts;

  }



  Future<List<Post>>
  getHomePostsImages(int limite) async {


    List<Post> posts = [];
    // //listConstposts =[];
    DateTime afterDate = DateTime(2024, 11, 06); // Replace with your desired date

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
    QuerySnapshot querySnapshotPost = await postCollect

    // .where("status",isEqualTo:'${PostStatus.VALIDE.name}')
        .where(
        Filter.or(
          Filter( "dataType",isEqualTo:'${PostDataType.IMAGE.name}'),
          Filter( "dataType",isEqualTo:'${PostDataType.TEXT.name}'),

        )

    )
    // .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(afterDate))

        .orderBy('created_at', descending: true)
    // .orderBy('updated_at', descending: true)
        .limit(limite)

        .get();

    List<Post> postList = querySnapshotPost.docs.map((doc) =>
        Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();
    printVm("post length  ${postList.length}");


    for (Post p in postList) {
      //  printVm("post : ${jsonDecode(post.toString())}");

      if (p.status==PostStatus.NONVALIDE.name) {
        // posts.add(p);
      }else if (p.status==PostStatus.SUPPRIMER.name) {
        // posts.add(p);
      }   else{
        //get user
        CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();

        List<UserData> userList = querySnapshotUser.docs.map((doc) =>
            UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

//get entreprise
//         if (p.type==PostType.PUB.name) {
//           CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
//           QuerySnapshot querySnapshotEntreprise = await entrepriseCollect.where("id",isEqualTo:'${p.entreprise_id}').get();
//
//           List<EntrepriseData> entrepriseList = querySnapshotEntreprise.docs.map((doc) =>
//               EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
//           p.entrepriseData=entrepriseList.first;
//         }
        p.user=userList.first;

        posts.add(p);
      }








    }
    listConstposts=posts;
    //listConstposts.shuffle();
    // notifyListeners(); // Notifie les écouteurs d'un changement

    return listConstposts;

  }

  Future<List<Post>> getPostsImagesAlready() async {
    // notifyListeners(); // Notifie les écouteurs d'un changement
    // listConstposts.insert(0, listConstposts.elementAt(0));
    // listConstposts.insert(0, listConstposts.elementAt(0));
    // listConstposts.remove(listConstposts.elementAt(0));
    if(listConstposts.isNotEmpty){
      if(listConstposts.first.id!=listConstposts.elementAt(1).id){
        listConstposts.insert(0, listConstposts.elementAt(0));

      }
    }

    return listConstposts;

  }

  Future<List<Post>>
  getPostsImagesById(String post_id) async {


    List<Post> posts = [];
    //listConstposts =[];

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
    QuerySnapshot querySnapshotPost = await postCollect

   .where("id",isEqualTo:'${post_id}')


        .get();

    List<Post> postList = querySnapshotPost.docs.map((doc) =>
        Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


    for (Post p in postList) {
      //  printVm("post : ${jsonDecode(post.toString())}");



      //get user
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      if(p.canal_id!.isNotEmpty){

        printVm("------------------post canal data 2 -----------------");

        QuerySnapshot querySnapshotCanal = await FirebaseFirestore.instance
            .collection('Canaux')
            .where("id", isEqualTo: '${p.canal_id}')
            .get();

        List<Canal> canalList = querySnapshotCanal.docs.map((doc) {
          return Canal.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();


        if (canalList.isNotEmpty) {
          printVm("------------------canalList.isNotEmpty -----------------");

          p.canal = canalList.first;
        }
      }

//get entreprise
      if (p.type==PostType.PUB.name) {
        CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
        QuerySnapshot querySnapshotEntreprise = await entrepriseCollect.where("id",isEqualTo:'${p.entreprise_id}').get();

        List<EntrepriseData> entrepriseList = querySnapshotEntreprise.docs.map((doc) =>
            EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        p.entrepriseData=entrepriseList.first;
      }

      if (userList.isNotEmpty) {
        printVm("------------------canalList.isNotEmpty -----------------");

        p.user=userList.first;
      }
      if (p.status==PostStatus.NONVALIDE.name) {
        // posts.add(p);
      }else if (p.status==PostStatus.SUPPRIMER.name) {
        // posts.add(p);
      }   else{
        posts.add(p);
      }




    }
    listConstposts=posts;

    return listConstposts;

  }

  Future<List<ArticleData>>
  getArticleById(String id) async {


    List<ArticleData> posts = [];
    //listConstposts =[];

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Articles');
    QuerySnapshot querySnapshotPost = await postCollect

        .where("id",isEqualTo:'${id}')


        .get();

    List<ArticleData> postList = querySnapshotPost.docs.map((doc) =>
        ArticleData.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


    for (ArticleData p in postList) {
      //  printVm("post : ${jsonDecode(post.toString())}");



      //get user
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();

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





  double calculatePopularity(LookChallenge lookChallenge) {
    // Définir les pondérations pour chaque paramètre
    const double weightJaime = 1.0;
    const double weightPartage = 2.0;
    const double weightVues = 0.5;

    // Récupérer les valeurs ou utiliser 0 par défaut si elles sont nulles
    int jaime = lookChallenge.jaime ?? 0;
    int partage = lookChallenge.partage ?? 0;
    int vues = lookChallenge.vues ?? 0;

    // Calculer la popularité en fonction de la formule pondérée
    double popularite = (jaime * weightJaime) +
        (partage * weightPartage) +
        (vues * weightVues);

    return popularite;
  }


  Future<List<LookChallenge>> getAllLookChallengesByChallenge(String challenge_id) async {
    List<LookChallenge> challenges = [];
    CollectionReference postCollect = FirebaseFirestore.instance.collection('LookChallenges');
    QuerySnapshot querySnapshotPost = await postCollect
        .where("challenge_id", isEqualTo: challenge_id)
        .where("disponible", isEqualTo: true)
    // .where("statut", isNotEqualTo: StatutData.TERMINER.name)
    //     .orderBy('createdAt', descending: true)
        .orderBy('popularite', descending: true)
        // .limit(10)
        .get();

    List<LookChallenge> challengesList = querySnapshotPost.docs
        .map((doc) => LookChallenge.fromJson(doc.data() as Map<String, dynamic>))
        .toList();

    // int currentTime = DateTime.now().millisecondsSinceEpoch;
    //
    // for (Challenge p in challengesList) {
    //   if (p.finishedAt! <= currentTime) {
    //     // Si la date de fin est dépassée
    //     p.statut = StatutData.TERMINER.name;
    //     await postCollect.doc(p.id).update({'statut': StatutData.TERMINER.name});
    //   } else if (p.startAt! <= currentTime && p.finishedAt! > currentTime) {
    //     // Si la date actuelle est entre dateDebut et dateFin
    //     p.statut = StatutData.ENCOURS.name;
    //     await postCollect.doc(p.id).update({'statut': StatutData.ENCOURS.name});
    //   }

    int currentTime = DateTime.now().millisecondsSinceEpoch;

    for (LookChallenge p in challengesList) {
      // Récupération du post lié
      CollectionReference postRef = FirebaseFirestore.instance.collection('Posts');
      QuerySnapshot postSnapshot = await postRef.where("id", isEqualTo: p.postChallengeId).get();
      List<Post> posts = postSnapshot.docs.map((doc) => Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
      p.post=posts.first;

      CollectionReference userRef = FirebaseFirestore.instance.collection('Users');
      QuerySnapshot userSnapshot = await userRef.where("id", isEqualTo: p.user_id).get();
      List<UserData> users = userSnapshot.docs.map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      p.post!.user=users.first;
      p.popularite=calculatePopularity(p);
      updateLookChallenge(p);

      p.user=users.first;challenges.add(p);
    }





    return challenges;
  }





  Future<List<LookChallenge>> getLookChallengeById(String id) async {
    List<LookChallenge> challenges = [];
    CollectionReference postCollect = FirebaseFirestore.instance.collection('LookChallenges');
    QuerySnapshot querySnapshotPost = await postCollect
        .where("id", isEqualTo: id)
        .where("disponible", isEqualTo: true)
        // .where("statut", isNotEqualTo: StatutData.TERMINER.name)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();

    List<LookChallenge> challengesList = querySnapshotPost.docs
        .map((doc) => LookChallenge.fromJson(doc.data() as Map<String, dynamic>))
        .toList();

    int currentTime = DateTime.now().millisecondsSinceEpoch;

    // for (Challenge p in challengesList) {
    //   // Récupération du post lié
    //   CollectionReference postRef = FirebaseFirestore.instance.collection('Posts');
    //   QuerySnapshot postSnapshot = await postRef.where("id", isEqualTo: p.postChallengeId).get();
    //   List<Post> posts = postSnapshot.docs.map((doc) => Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //
    //
    // }

    challenges=challengesList;

    return challenges;
  }



  Future<List<UserServiceData>>
  getUserServiceById(String id) async {


    List<UserServiceData> posts = [];
    //listConstposts =[];

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('UserServices');
    QuerySnapshot querySnapshotPost = await postCollect

        .where("id",isEqualTo:'${id}')
        .where("disponible",isEqualTo:true)


        .get();

    List<UserServiceData> postList = querySnapshotPost.docs.map((doc) =>
        UserServiceData.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


    for (UserServiceData p in postList) {
      //  printVm("post : ${jsonDecode(post.toString())}");



      //get user
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.userId}').get();

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
          .get();

      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          UserServiceData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      for (var article in listArticles) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.userId).get();
        UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        printVm(' UserServices user ${user.toJson()}');

        article.user = user;
      }
      listArticles.shuffle();
      listArticles.shuffle();



      print('list UserServices ${listArticles.length}');
      hasData=true;
      // teams.shuffle();




      return listArticles;
      // return teams;
    }catch(e){
      print("erreur ${e}");
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
      QuerySnapshot querySnapshotUser = await userCollect
          .orderBy('updatedAt', descending: true)
          .limit(8)
          .get();

      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          Canal.fromJson(doc.data() as Map<String, dynamic>)).toList();
      for (var article in listArticles) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.userId).get();
        UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        printVm(' UserServices user ${user.toJson()}');

        article.user = user;
      }
      listArticles.shuffle();
      listArticles.shuffle();



      print('list UserServices ${listArticles.length}');
      hasData=true;
      // teams.shuffle();




      return listArticles;
      // return teams;
    }catch(e){
      print("erreur ${e}");
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
          .get();

      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          UserServiceData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      for (var article in listArticles) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.userId).get();
        UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        printVm(' UserServices user ${user.toJson()}');

        article.user = user;
      }
      listArticles.shuffle();
      listArticles.shuffle();



      print('list UserServices ${listArticles.length}');
      hasData=true;
      // teams.shuffle();




      return listArticles;
      // return teams;
    }catch(e){
      print("erreur ${e}");
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
          .get();

      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          UserServiceData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      for (var article in listArticles) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.userId).get();
        UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        printVm(' UserServices user ${user.toJson()}');

        article.user = user;
      }
      listArticles.shuffle();



      print('list UserServices ${listArticles.length}');
      hasData=true;
      // teams.shuffle();




      return listArticles;
      // return teams;
    }catch(e){
      print("erreur ${e}");
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
      print("erreur update  : ${e}");
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
      print("erreur update  : ${e}");
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


        .get();

    List<EntrepriseData> postList = querySnapshotPost.docs.map((doc) =>
        EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


    for (EntrepriseData p in postList) {
      //  printVm("post : ${jsonDecode(post.toString())}");



      //get user
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.userId}').get();

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
  Future<List<Post>> getPostsVideos2() async {

    List<Post> posts = [];
    videos =[];
    //  UserData userData=UserData();

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
    QuerySnapshot querySnapshotPost = await postCollect.where("dataType",isEqualTo:'${PostDataType.VIDEO.name}')
       // .where("status",isNotEqualTo:'${PostStatus.SIGNALER.name}')
       //  .orderBy('updated_at', descending: true)
        .orderBy('created_at', descending: true)
        .get();

    List<Post> postList = querySnapshotPost.docs.map((doc) =>
        Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


    for (Post p in postList) {
      //  printVm("post : ${jsonDecode(post.toString())}");



      //get user
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

//get entreprise
      if (p.type==PostType.PUB.name) {
        CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
        QuerySnapshot querySnapshotEntreprise = await entrepriseCollect.where("id",isEqualTo:'${p.entreprise_id}').get();

        List<EntrepriseData> entrepriseList = querySnapshotEntreprise.docs.map((doc) =>
            EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        p.entrepriseData=entrepriseList.first;
      }


      p.user=userList.first;

      if (p.status==PostStatus.NONVALIDE.name) {
        // posts.add(p);
      }else if (p.status==PostStatus.SUPPRIMER.name) {
        // posts.add(p);
      }   else{
        posts.add(p);
      }
      videos=posts;


    }

    //posts.shuffle();


      return posts;

  }
  Stream<List<Post>> getPostsVideos(int limite) async* {
    printVm("get canal data ");
    List<Post> posts = [];
    listConstposts = [];
    Set<String> postIdsToday = {}; // Ensemble pour les identifiants des posts du jour
    Set<String> postIdsWeek = {}; // Ensemble pour les identifiants des posts de la semaine
    Set<String> postIdsOthers = {}; // Ensemble pour les identifiants des autres posts
    DateTime afterDate = DateTime.now(); // Date de référence dynamique
    CollectionReference postCollect = FirebaseFirestore.instance.collection('Posts');
    int todayTimestamp = DateTime.now().microsecondsSinceEpoch;

    // Début de la journée actuelle (minuit)
    int startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).microsecondsSinceEpoch;

    // Fin de la journée actuelle (23:59:59)
    int endOfDay = startOfDay + Duration(hours: 23, minutes: 59, seconds: 59).inMicroseconds;

    // Début de la semaine actuelle (lundi minuit)
    int startOfWeek = startOfDay - Duration(days: DateTime.now().weekday - 1).inMicroseconds;

    // Fin de la semaine actuelle (dimanche 23:59:59)
    int endOfWeek = startOfWeek + Duration(days: 6, hours: 23, minutes: 59, seconds: 59).inMicroseconds;

    // 1. Récupérer les publications de la journée
    Query queryToday = postCollect
        .where(
      "dataType", isEqualTo: '${PostDataType.VIDEO.name}',
    )
        .where("created_at", isGreaterThanOrEqualTo: startOfDay)
        .where("created_at", isLessThanOrEqualTo: endOfDay)
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .orderBy('created_at', descending: true)
        .limit(limite);

    // 2. Récupérer les publications de la semaine
    Query queryWeek = postCollect
        .where(
      "dataType", isEqualTo: '${PostDataType.VIDEO.name}',
    )
        .where("created_at", isGreaterThanOrEqualTo: startOfWeek)
        .where("created_at", isLessThanOrEqualTo: endOfWeek)
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .orderBy('created_at', descending: true)
        .limit(limite);

    // 3. Récupérer les publications restantes
    Query queryOthers = postCollect
        .where(
      "dataType", isEqualTo: '${PostDataType.VIDEO.name}',
    )
        .where("created_at", isLessThan: startOfWeek)
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .orderBy('updated_at', descending: true)
        .limit(limite);

    // Effectuer les requêtes en parallèle
    List<DocumentSnapshot> todayPosts = (await queryToday.get()).docs;
    List<DocumentSnapshot> weekPosts = (await queryWeek.get()).docs;
    List<DocumentSnapshot> otherPosts = (await queryOthers.get()).docs;

    // Traiter les documents de la journée
    for (var doc in todayPosts) {
      Post post = Post.fromJson(doc.data() as Map<String, dynamic>);

      // Vérifier si l'identifiant du post est déjà dans l'ensemble du jour
      if (postIdsToday.contains(post.id)) {
        continue; // Passer au document suivant si le post est déjà ajouté
      }

      // Ajouter l'identifiant du post à l'ensemble du jour
      postIdsToday.add(post.id!);

      // Récupérer les données utilisateur liées
      QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
          .collection('Users')
          .where("id", isEqualTo: '${post.user_id}')
          .get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) {
        return UserData.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      if (post.canal_id!.isNotEmpty) {
        QuerySnapshot querySnapshotCanal = await FirebaseFirestore.instance
            .collection('Canaux')
            .where("id", isEqualTo: '${post.canal_id}')
            .get();

        List<Canal> canalList = querySnapshotCanal.docs.map((doc) {
          return Canal.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        if (canalList.isNotEmpty) {
          post.canal = canalList.first;
        }
      }

      if (userList.isNotEmpty) {
        post.user = userList.first;
      }

      // Ajouter le post à la liste
      posts.add(post);
      listConstposts.add(post);

      // Transmettre les données partiellement récupérées
      yield posts;
    }

    // Traiter les documents de la semaine
    for (var doc in weekPosts) {
      Post post = Post.fromJson(doc.data() as Map<String, dynamic>);

      // Vérifier si l'identifiant du post est déjà dans l'ensemble du jour ou de la semaine
      if (postIdsToday.contains(post.id) || postIdsWeek.contains(post.id)) {
        continue; // Passer au document suivant si le post est déjà ajouté
      }

      // Ajouter l'identifiant du post à l'ensemble de la semaine
      postIdsWeek.add(post.id!);

      // Récupérer les données utilisateur liées
      QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
          .collection('Users')
          .where("id", isEqualTo: '${post.user_id}')
          .get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) {
        return UserData.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      if (post.canal_id!.isNotEmpty) {
        QuerySnapshot querySnapshotCanal = await FirebaseFirestore.instance
            .collection('Canaux')
            .where("id", isEqualTo: '${post.canal_id}')
            .get();

        List<Canal> canalList = querySnapshotCanal.docs.map((doc) {
          return Canal.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        if (canalList.isNotEmpty) {
          post.canal = canalList.first;
        }
      }

      if (userList.isNotEmpty) {
        post.user = userList.first;
      }

      // Ajouter le post à la liste
      posts.add(post);
      listConstposts.add(post);

      // Transmettre les données partiellement récupérées
      yield posts;
    }

    // Traiter les autres documents
    for (var doc in otherPosts) {
      Post post = Post.fromJson(doc.data() as Map<String, dynamic>);

      // Vérifier si l'identifiant du post est déjà dans l'ensemble du jour, de la semaine ou des autres
      if (postIdsToday.contains(post.id) || postIdsWeek.contains(post.id) || postIdsOthers.contains(post.id)) {
        continue; // Passer au document suivant si le post est déjà ajouté
      }

      // Ajouter l'identifiant du post à l'ensemble des autres
      postIdsOthers.add(post.id!);

      // Récupérer les données utilisateur liées
      QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
          .collection('Users')
          .where("id", isEqualTo: '${post.user_id}')
          .get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) {
        return UserData.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      if (post.canal_id!.isNotEmpty) {
        QuerySnapshot querySnapshotCanal = await FirebaseFirestore.instance
            .collection('Canaux')
            .where("id", isEqualTo: '${post.canal_id}')
            .get();

        List<Canal> canalList = querySnapshotCanal.docs.map((doc) {
          return Canal.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        if (canalList.isNotEmpty) {
          post.canal = canalList.first;
        }
      }

      if (userList.isNotEmpty) {
        post.user = userList.first;
      }

      // Ajouter le post à la liste
      posts.add(post);
      listConstposts.add(post);

      // Transmettre les données partiellement récupérées
      yield posts;
    }
  }

  Stream<List<Post>> getPostsVideos4(int limite) async* {
    List<Post> posts = [];
    listConstposts = [];
    DateTime afterDate = DateTime(2024, 11, 06); // Date de référence
    CollectionReference postCollect = FirebaseFirestore.instance.collection('Posts');
    int todayTimestamp = DateTime.now().microsecondsSinceEpoch;

// Début de la journée actuelle (minuit)
    int startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).microsecondsSinceEpoch;

// Fin de la journée actuelle (23:59:59)
    int endOfDay = startOfDay + Duration(hours: 23, minutes: 59, seconds: 59).inMicroseconds;
    // 1. Récupérer les publications de la journée
    Query queryToday = postCollect
        .where(
        "dataType", isEqualTo: '${PostDataType.VIDEO.name}'
    )
    // .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .where("created_at", isGreaterThanOrEqualTo: startOfDay)
        .where("created_at", isLessThanOrEqualTo: endOfDay)
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .orderBy('created_at', descending: true)
    // .orderBy('updated_at', descending: true)
        .limit(limite);

// 2. Récupérer les publications restantes
    Query queryOthers = postCollect
        .where(

    "dataType", isEqualTo: '${PostDataType.VIDEO.name}'

    )
    // .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .where("created_at", isLessThan: startOfDay)
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .orderBy('updated_at', descending: true)
        .limit(limite);

    // Query query = postCollect
    //     .where(
    //   Filter.or(
    //     Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
    //     Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
    //   ),
    // )
    //     .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
    //     .where("created_at", isGreaterThanOrEqualTo: startOfDay) // Pour les publications de la journée
    //     .orderBy('updated_at', descending: true)
    //     .limit(limite);

    // // Effectuer une requête pour récupérer les posts
    // Query query = postCollect
    //     .where(
    //   Filter.or(
    //     Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
    //     Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
    //   ),
    //
    // )      .where(
    //     "status", isNotEqualTo: PostStatus.SUPPRIMER.name
    //
    // )
    //     .where('created_at', isGreaterThanOrEqualTo: DateTime.now().microsecondsSinceEpoch
    // )
    //
    //     .orderBy('updated_at', descending: true)
    //     .limit(limite);

    // Effectuer les deux requêtes en parallèle
    List<DocumentSnapshot> todayPosts = (await queryToday.get()).docs;
    List<DocumentSnapshot> otherPosts = (await queryOthers.get()).docs;

    // Combiner les résultats
    List<DocumentSnapshot> querySnapshotPosts = [...todayPosts, ...otherPosts];

    // QuerySnapshot querySnapshotPost = await query.get();

    // QuerySnapshot querySnapshotPost = await query.get();

    // List<Post> postList = querySnapshotPost.docs.map((doc) {
    //   Post post = Post.fromJson(doc.data() as Map<String, dynamic>);
    //   return post;
    // }).where((post) =>
    // post.status != PostStatus.NONVALIDE.name &&
    //     post.status != PostStatus.SUPPRIMER.name).toList();

    // Traiter les documents progressivement
    // for (var doc in querySnapshotPost.docs) {
    for (var doc in querySnapshotPosts) {
      Post post = Post.fromJson(doc.data() as Map<String, dynamic>);

      // Filtrer selon le statut
      // if (post.status != PostStatus.NONVALIDE.name &&
      //     post.status != PostStatus.SUPPRIMER.name) {
      // Récupérer les données utilisateur liées
      QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
          .collection('Users')
          .where("id", isEqualTo: '${post.user_id}')
          .get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) {
        return UserData.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      if (userList.isNotEmpty) {
        post.user = userList.first;
      }

      // Ajouter le post à la liste
      posts.add(post);
      listConstposts.add(post);
      // Transmettre les données partiellement récupérées
      yield posts;
      //}
    }
  }

  Future<List<Post>> getPostsVideos3(int limite) async {
    List<Post> posts = [];
    listConstposts = [];
    DateTime afterDate = DateTime(2024, 11, 06); // Date de référence
    CollectionReference postCollect = FirebaseFirestore.instance.collection('Posts');
    int todayTimestamp = DateTime.now().microsecondsSinceEpoch;

    // Début de la journée actuelle (minuit)
    int startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).microsecondsSinceEpoch;

    // Fin de la journée actuelle (23:59:59)
    int endOfDay = startOfDay + Duration(hours: 23, minutes: 59, seconds: 59).inMicroseconds;

    // 1. Récupérer les publications de la journée
    Query queryToday = postCollect
        .where("dataType", isEqualTo: '${PostDataType.VIDEO.name}')
        .where("created_at", isGreaterThanOrEqualTo: startOfDay)
        .where("created_at", isLessThanOrEqualTo: endOfDay)
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .orderBy('created_at', descending: true)
        .limit(limite);

    // 2. Récupérer les publications restantes
    Query queryOthers = postCollect
        .where("dataType", isEqualTo: '${PostDataType.VIDEO.name}')
        .where("created_at", isLessThan: startOfDay)
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .orderBy('updated_at', descending: true)
        .limit(limite);

    // Effectuer les deux requêtes en parallèle
    List<DocumentSnapshot> todayPosts = (await queryToday.get()).docs;
    List<DocumentSnapshot> otherPosts = (await queryOthers.get()).docs;

    // Combiner les résultats
    List<DocumentSnapshot> querySnapshotPosts = [...todayPosts, ...otherPosts];

    for (var doc in querySnapshotPosts) {
      Post post = Post.fromJson(doc.data() as Map<String, dynamic>);

      // Récupérer les données utilisateur liées
      QuerySnapshot querySnapshotUser = await FirebaseFirestore.instance
          .collection('Users')
          .where("id", isEqualTo: '${post.user_id}')
          .get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) {
        return UserData.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      if (userList.isNotEmpty) {
        post.user = userList.first;
      }

      // Ajouter le post à la liste
      posts.add(post);
      listConstposts.add(post);
    }

    return posts;
  }


  Future<List<Post>> getPostsVideosById(String post_id) async {

    List<Post> posts = [];
    videos =[];
    //  UserData userData=UserData();

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
    QuerySnapshot querySnapshotPost = await postCollect
    // .where("status",isNotEqualTo:'${PostStatus.SIGNALER.name}')
     .where("id",isEqualTo:'${post_id}')
       // .orderBy('created_at', descending: true)
        .get();

    List<Post> postList = querySnapshotPost.docs.map((doc) =>
        Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


    for (Post p in postList) {
      //  printVm("post : ${jsonDecode(post.toString())}");



      //get user
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

//get entreprise
      if (p.type==PostType.PUB.name) {
        CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
        QuerySnapshot querySnapshotEntreprise = await entrepriseCollect.where("id",isEqualTo:'${p.entreprise_id}').get();

        List<EntrepriseData> entrepriseList = querySnapshotEntreprise.docs.map((doc) =>
            EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        p.entrepriseData=entrepriseList.first;
      }


      p.user=userList.first;

      if (p.status==PostStatus.NONVALIDE.name) {
        // posts.add(p);
      }else if (p.status==PostStatus.SUPPRIMER.name) {
        // posts.add(p);
      }   else{
        posts.add(p);
      }
      videos=posts;


    }

    posts.shuffle();
    //posts.shuffle();


    return posts;

  }

  Future<List<Post>> getPostsVideosByPost(List<Post> posts) async {



    return posts;

  }



  Future<bool> updateVuePost(Post post,BuildContext context) async {
    try{

      post.updatedAt=DateTime.now().microsecondsSinceEpoch;

      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(post.id)
          .update(post.toJson());

      return true;
    }catch(e){
      printVm("erreur update post : ${e}");
      return false;
    }
  }
  Future<bool> updateReplyPost(Post post,BuildContext context) async {
    try{

      post.createdAt=DateTime.now().microsecondsSinceEpoch;

      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(post.id)
          .update(post.toJson());

      return true;
    }catch(e){
      printVm("erreur update post : ${e}");
      return false;
    }
  }

  Future<bool> updateLookChallenge(LookChallenge post) async {
    try{

      // post.updatedAt=DateTime.now().microsecondsSinceEpoch;

      await FirebaseFirestore.instance
          .collection('LookChallenges')
          .doc(post.id)
          .update(post.toJson());

      return true;
    }catch(e){
      printVm("erreur update post : ${e}");
      return false;
    }
  }

  Future<bool> updatePost(Post post,UserData userAction,BuildContext context) async {
    try{


      post.updatedAt=DateTime.now().microsecondsSinceEpoch;

      // final now = DateTime.now().microsecondsSinceEpoch;
      // final difference = now - post.updatedAt!;
      //
      // int newDuration=0;
      //
      // if (difference < Duration.microsecondsPerDay) {
      //   newDuration = Duration.microsecondsPerHour;
      // } else if (difference < 3 * Duration.microsecondsPerDay) {
      //   newDuration = 12 * Duration.microsecondsPerHour;
      // } else if (difference < 7 * Duration.microsecondsPerDay) {
      //   newDuration = Duration.microsecondsPerDay;
      // } else if (difference < 14 * Duration.microsecondsPerDay) {
      //   newDuration = Duration.microsecondsPerDay + 12 * Duration.microsecondsPerHour;
      // } else {
      //   newDuration = 2 * Duration.microsecondsPerDay;
      // }
      //
      // final newTimestamp = now + newDuration;
      //
      // printVm('update poste **********************************************************************');
      // post.updatedAt=newTimestamp;
      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(post.id)
          .update(post.toJson());
      late UserAuthProvider authProvider =
      Provider.of<UserAuthProvider>(context, listen: false);
      authProvider.loginUserData!.pointContribution=authProvider.loginUserData!.pointContribution!+1;
      await firestore.collection('Users').doc( authProvider.loginUserData!.id).update( authProvider.loginUserData!.toJson());
     // post.user!.pointContribution=post.user!.pointContribution!+1;
     // printVm("user avant 2 : ${post.user!.toJson()}");
      await firestore.collection('Users').doc( userAction!.id).update( userAction!.toJson());
      //printVm("user apres 2 : ${userAction!.toJson()}");
      return true;
    }catch(e){
      printVm("erreur update post : ${e}");
      return false;
    }
  }
  Future<List<PostComment>> getPostCommentsNoStream(Post p) async{
    List<PostComment> postComment = [];
    listConstpostsComment = [];
    CollectionReference userCollect =
    FirebaseFirestore.instance.collection('PostComments');
    // Get docs from collection reference
    QuerySnapshot querySnapshotUser = await userCollect
        .where("post_id",isEqualTo:'${p.id}')
        .orderBy('created_at', descending: true)
        .get();

    // Afficher la liste
    listConstpostsComment = querySnapshotUser.docs.map((doc) =>
        PostComment.fromJson(doc.data() as Map<String, dynamic>)).toList();


    //  UserData userData=UserData();



      for (var postcmt in listConstpostsComment) {
        //  printVm("post : ${jsonDecode(post.toString())}");
        //PostComment pm=PostComment.fromJson(postcmt.data());
        CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${postcmt.user_id}').get();
        // Afficher la liste


        List<UserData> userList = querySnapshotUser.docs.map((doc) =>
            UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        postcmt.user=userList.first;
        //postComment.add(pm);
        //listConstpostsComment.add(pm);


      }
    //notifyListeners();
      return listConstpostsComment;

  }

  Future<List<PostComment>> getStoryCommentsNoStream(WhatsappStory w) async{
    List<PostComment> postComment = [];
    listConstpostsComment = [];
    CollectionReference userCollect =
    FirebaseFirestore.instance.collection('PostComments');
    // Get docs from collection reference
    QuerySnapshot querySnapshotUser = await userCollect
        .where("post_id",isEqualTo:'${w.createdAt}')
        .orderBy('created_at', descending: true)
        .get();

    // Afficher la liste
    listConstpostsComment = querySnapshotUser.docs.map((doc) =>
        PostComment.fromJson(doc.data() as Map<String, dynamic>)).toList();


    //  UserData userData=UserData();



    for (var postcmt in listConstpostsComment) {
      //  printVm("post : ${jsonDecode(post.toString())}");
      //PostComment pm=PostComment.fromJson(postcmt.data());
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${postcmt.user_id}').get();
      // Afficher la liste


      List<UserData> userList = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      postcmt.user=userList.first;
      //postComment.add(pm);
      //listConstpostsComment.add(pm);


    }
    //notifyListeners();
    return listConstpostsComment;

  }

  Future<List<PostComment>> getPostComments(Post p) async {

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('PostComments');
    QuerySnapshot querySnapshotPost = await postCollect
        .where("post_id",isEqualTo:'${p.id}')
        .orderBy('created_at', descending: true)
        .get();

    List<PostComment> commentList = querySnapshotPost.docs.map((doc) =>
        PostComment.fromJson(doc.data() as Map<String, dynamic>)).toList();
    var postStream = FirebaseFirestore.instance.collection('PostComments')
        .where("post_id",isEqualTo:'${p.id}')
        .orderBy('created_at', descending: true)
        .snapshots();
    List<PostComment> postComment = [];
    listConstpostsComment = [];
    //  UserData userData=UserData();


      for (PostComment pm in commentList) {
        //  printVm("post : ${jsonDecode(post.toString())}");
        CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${pm.user_id}').get();
        // Afficher la liste


        List<UserData> userList = querySnapshotUser.docs.map((doc) =>
            UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        pm.user=userList.first;
        postComment.add(pm);
        listConstpostsComment.add(pm);


      }
      return postComment;

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
    try{
      String cmtId = FirebaseFirestore.instance
          .collection('PostComments')
          .doc()
          .id;

      comment.id=cmtId;
      await FirebaseFirestore.instance
          .collection('PostComments')
          .doc(cmtId)
          .set(comment.toJson());
      notifyListeners();
      return true;
    }catch(e){
      printVm("erreur comment : ${e}");
      return false;
    }
  }

  Future<bool> updateComment(PostComment comment) async {
    try{

      await FirebaseFirestore.instance
          .collection('PostComments')
          .doc(comment.id)
          .update(comment.toJson());
      notifyListeners();
      return true;
    }catch(e){
      printVm("erreur comment : ${e}");
      return false;
    }
  }





}
