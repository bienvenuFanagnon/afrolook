import 'dart:convert';
import 'dart:io';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/user/userService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chatmodels/message.dart';

import '../pages/component/consoleWidget.dart';
import '../services/auth/authService.dart';
import 'authProvider.dart';



class PostProvider extends ChangeNotifier {
  late AuthService authService = AuthService();
  late UserService userService = UserService();
  late Chat chat = Chat();
  late Post postSelected = Post();
  List<Post> listConstposts = [];


  List<Post> videos = [];
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
  Stream<List<NotificationData>> getListNotificatio(String user_id) async* {
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

  Stream<List<Post>> getPostsImages2(int limite) async* {
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
      Filter.or(
        Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
        Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
      ),
    )
        // .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .where("created_at", isGreaterThanOrEqualTo: startOfDay)
        .where("created_at", isLessThanOrEqualTo: endOfDay)
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .orderBy('created_at', descending: true)
        // .orderBy('updated_at', descending: true)
        .limit(limite);


    Query queryPub = postCollect
        .where(
      Filter.or(
        Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
        Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
      ),
    )
    .where("type", isEqualTo: PostType.PUB.name)
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .orderBy('created_at', descending: true)
    // .orderBy('updated_at', descending: true)
        .limit(limite);

// 2. Récupérer les publications restantes
    Query queryOthers = postCollect
        .where(
      Filter.or(
        Filter("dataType", isEqualTo: '${PostDataType.IMAGE.name}'),
        Filter("dataType", isEqualTo: '${PostDataType.TEXT.name}'),
      ),
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
    List<DocumentSnapshot> pubPosts = (await queryPub.get()).docs;
    List<DocumentSnapshot> todayPosts = (await queryToday.get()).docs;
    List<DocumentSnapshot> otherPosts = (await queryOthers.get()).docs;

    // Combiner les résultats
    List<DocumentSnapshot> querySnapshotPosts = [...pubPosts,...todayPosts, ...otherPosts];

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
    notifyListeners(); // Notifie les écouteurs d'un changement

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
  Future<bool> updatePost(Post post,UserData userAction,BuildContext context) async {
    try{


      post.updatedAt=DateTime.now().microsecondsSinceEpoch;
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
