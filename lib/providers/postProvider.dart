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

import '../services/auth/authService.dart';
import 'authProvider.dart';



class PostProvider extends ChangeNotifier {
  late AuthService authService = AuthService();
  late UserService userService = UserService();
  late Chat chat = Chat();
  List<Post> listConstposts = [];


  List<Post> videos = [];
  List<PostComment> listConstpostsComment = [];

  List<Message> usermessageList =[];

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Stream<List<Post>> getPostsImagesByUser(String userId) async* {
    var postStream = FirebaseFirestore.instance.collection('Posts')
        .where("user_id",isEqualTo:'${userId}')
        .where("type",isEqualTo:'${PostType.POST.name}')
        .where("dataType",isEqualTo:'${PostDataType.IMAGE.name}')

        .orderBy('created_at', descending: true)

        .snapshots();
    List<Post> posts = [];
    listConstposts =[];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {

      for (var post in snapshot.docs) {
        //  print("post : ${jsonDecode(post.toString())}");
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
    listConstposts =[];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {

      for (var post in snapshot.docs) {
        //  print("post : ${jsonDecode(post.toString())}");
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
    listConstposts =[];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {

      for (var post in snapshot.docs) {
        //  print("post : ${jsonDecode(post.toString())}");
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
    listConstposts =[];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {

      for (var post in snapshot.docs) {
        //  print("post : ${jsonDecode(post.toString())}");
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
    listConstposts =[];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {

      for (var post in snapshot.docs) {
        //  print("post : ${jsonDecode(post.toString())}");
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
  //  .limit(7)

        .snapshots();
    List<NotificationData> notifications = [];
    listConstposts =[];
    //  UserData userData=UserData();

    await for (var snapshot in postStream) {
      notifications=[];

      for (var post in snapshot.docs) {
        //  print("post : ${jsonDecode(post.toString())}");
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
    listConstposts =[];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {

      for (var post in snapshot.docs) {
        //  print("post : ${jsonDecode(post.toString())}");
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
    listConstposts =[];

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
    QuerySnapshot querySnapshotPost = await postCollect

       // .where("status",isEqualTo:'${PostStatus.VALIDE.name}')
        .where(
        Filter.or(
          Filter( "dataType",isEqualTo:'${PostDataType.IMAGE.name}'),
          Filter( "dataType",isEqualTo:'${PostDataType.TEXT.name}'),

        )

       )
        .orderBy('created_at', descending: true)
        .limit(limite)

        .get();

    List<Post> postList = querySnapshotPost.docs.map((doc) =>
        Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


      for (Post p in postList) {
      //  print("post : ${jsonDecode(post.toString())}");



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
    //listConstposts.shuffle();
    listConstposts.shuffle();

    return listConstposts;

  }

  Future<List<Post>>
  getPostsImagesById(String post_id) async {


    List<Post> posts = [];
    listConstposts =[];

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
    QuerySnapshot querySnapshotPost = await postCollect

   .where("id",isEqualTo:'${post_id}')


        .get();

    List<Post> postList = querySnapshotPost.docs.map((doc) =>
        Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


    for (Post p in postList) {
      //  print("post : ${jsonDecode(post.toString())}");



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


  Future<List<Post>> getPostsVideos() async {

    List<Post> posts = [];
    videos =[];
    //  UserData userData=UserData();

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
    QuerySnapshot querySnapshotPost = await postCollect.where("dataType",isEqualTo:'${PostDataType.VIDEO.name}')
       // .where("status",isNotEqualTo:'${PostStatus.SIGNALER.name}')
        .orderBy('created_at', descending: true)
        .get();

    List<Post> postList = querySnapshotPost.docs.map((doc) =>
        Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


    for (Post p in postList) {
      //  print("post : ${jsonDecode(post.toString())}");



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
      //  print("post : ${jsonDecode(post.toString())}");



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



      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(post.id)
          .update(post.toJson());

      return true;
    }catch(e){
      print("erreur update post : ${e}");
      return false;
    }
  }
  Future<bool> updatePost(Post post,UserData userAction,BuildContext context) async {
    try{



      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(post.id)
          .update(post.toJson());
      late UserAuthProvider authProvider =
      Provider.of<UserAuthProvider>(context, listen: false);
      authProvider.loginUserData!.pointContribution=authProvider.loginUserData!.pointContribution!+1;
      await firestore.collection('Users').doc( authProvider.loginUserData!.id).update( authProvider.loginUserData!.toJson());
     // post.user!.pointContribution=post.user!.pointContribution!+1;
     // print("user avant 2 : ${post.user!.toJson()}");
      await firestore.collection('Users').doc( userAction!.id).update( userAction!.toJson());
      //print("user apres 2 : ${userAction!.toJson()}");
      return true;
    }catch(e){
      print("erreur update post : ${e}");
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
        //  print("post : ${jsonDecode(post.toString())}");
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
        //  print("post : ${jsonDecode(post.toString())}");
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
      print("erreur comment : ${e}");
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
      print("erreur comment : ${e}");
      return false;
    }
  }



}
