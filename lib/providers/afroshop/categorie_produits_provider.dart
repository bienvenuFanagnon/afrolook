

import 'dart:io';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import 'package:provider/provider.dart';


import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/model_data.dart';

import 'authAfroshopProvider.dart';



class CategorieProduitProvider extends ChangeNotifier {

  List<Categorie> listCategorie = [];
  List<ArticleData> listArticles = [];





  Future<List<Categorie>> getCategories() async {

    listCategorie = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Categories');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect
      // .where("id",isNotEqualTo: currentUserId)
       .orderBy('createdAt', descending: false)
      //   .limit(10)
          .get();

      // Afficher la liste
      listCategorie = querySnapshotUser.docs.map((doc) =>
          Categorie.fromJson(doc.data() as Map<String, dynamic>)).toList();





      print('list categorie ${listCategorie.length}');
      hasData=true;
      // listCategorie.shuffle();

      List<List<Categorie>> matchs = [];



      return listCategorie;
      // return teams;
    }catch(e){
      print("erreur ${e}");
      hasData=false;
      return [];
    }

  }

  Stream<ArticleData> getAllArticlesStream() async* {
    var articleStream = FirebaseFirestore.instance
        .collection('Articles')
        .where("disponible", isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();

    await for (var snapshot in articleStream) {
      for (var doc in snapshot.docs) {
        ArticleData article = ArticleData.fromJson(doc.data() as Map<String, dynamic>);

        // Récupérer les infos de l'utilisateur associé
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.user_id).get();
        UserData user = UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        article.user = user;

        // Émettre chaque article dès qu'il est prêt
        yield article;
      }
    }
  }
  Future<List<ArticleData>> getAllArticlesByUser(String user_id) async {

    listArticles = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Articles');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect
          .where("disponible",isEqualTo: true)
          .where("user_id",isEqualTo: user_id)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          ArticleData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      for (var article in listArticles) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.user_id).get();
        UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        printVm(' article user ${user.toJson()}');

        article.user = user;
      }
      listArticles.shuffle();



      print('list article ${listArticles.length}');
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


  Future<List<ArticleData>> getArticleBooster() async {

    listArticles = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Articles');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect
          .where("disponible",isEqualTo: true)
          .orderBy('createdAt', descending: true)
        .limit(10)
          .get();

      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          ArticleData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      for (var article in listArticles) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.user_id).get();
        UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        // printVm(' article user ${user.toJson()}');

        article.user = user;
      }
      listArticles.shuffle();



      print('list article ${listArticles.length}');
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

  Future<List<ArticleData>> getAnnoncesArticles() async {

    listArticles = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Articles');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect
       .where("disponible",isEqualTo: true)
       .where("dispo_annonce_afrolook",isEqualTo: true)
          .orderBy('createdAt', descending: true)
      //   .limit(10)
          .get();

      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          ArticleData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      for (var article in listArticles) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.user_id).get();
        UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        printVm(' article user ${user.toJson()}');

        article.user = user;
      }
      listArticles.shuffle();



      print('list article ${listArticles.length}');
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

  Future<List<ArticleData>> getSearhArticles(String titre,int item_selected,String categorie_id) async {

    listArticles = [];
    List<ArticleData> listArticlesSearch=[];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Articles');
      QuerySnapshot querySnapshotUser ;
      // Get docs from collection reference
      if (item_selected==-1) {
         querySnapshotUser = await userCollect
             .where("disponible",isEqualTo: true)

         // .where("titre",isNotEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)
        //   .limit(10)
            .get();
      } else{
         querySnapshotUser = await userCollect
             .where("disponible",isEqualTo: true)

             .where("categorie_id",isEqualTo: categorie_id)
           // .orderBy('createdAt', descending: true)
        //   .limit(10)
            .get();
      }


      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          ArticleData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      listArticles.forEach((element) async {

        if (element.titre!.toLowerCase().contains(titre.toLowerCase())) {

            DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(element.user_id).get();
            UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
            printVm(' article user ${user.toJson()}');

            element.user = user;

          listArticlesSearch.add(element);
        }

      });

    //  listArticles.shuffle();



      print('list article ${listArticlesSearch.length}');
      hasData=true;
      // teams.shuffle();




      return listArticlesSearch;
      // return teams;
    }catch(e){
      print("erreur ${e}");
      hasData=false;
      return [];
    }

  }

  Future<List<ArticleData>> getSearhArticlesByEntreprise(String titre,int item_selected,String categorie_id,String user_id) async {

    listArticles = [];
    List<ArticleData> listArticlesSearch=[];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Articles');
      QuerySnapshot querySnapshotUser ;
      // Get docs from collection reference
      if (item_selected==-1) {
        querySnapshotUser = await userCollect
            .where("user_id",isEqualTo: user_id)
            .where("disponible",isEqualTo: true)

        // .where("titre",isNotEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)
        //   .limit(10)
            .get();
      } else{
        querySnapshotUser = await userCollect
            .where("disponible",isEqualTo: true)

            .where("user_id",isEqualTo: user_id)
            .where("categorie_id",isEqualTo: categorie_id)
        // .orderBy('createdAt', descending: true)
        //   .limit(10)
            .get();
      }


      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          ArticleData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      listArticles.forEach((element) async {
        if (element.titre!.toLowerCase().contains(titre.toLowerCase())) {

            DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(element.user_id).get();
            UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
            printVm(' article user ${user.toJson()}');

            element.user = user;

          listArticlesSearch.add(element);
        }

      });

      //  listArticles.shuffle();



      print('list article ${listArticlesSearch.length}');
      hasData=true;
      // teams.shuffle();




      return listArticlesSearch;
      // return teams;
    }catch(e){
      print("erreur ${e}");
      hasData=false;
      return [];
    }

  }
  Stream<ArticleData> getArticlesByCategorieStream(String categorie_id) async* {
    var articleStream = FirebaseFirestore.instance
        .collection('Articles')
        .where("disponible", isEqualTo: true)
        .where("categorie_id", isEqualTo: categorie_id)
        .orderBy('createdAt', descending: true)
        .snapshots();

    await for (var snapshot in articleStream) {
      for (var doc in snapshot.docs) {
        ArticleData article = ArticleData.fromJson(doc.data() as Map<String, dynamic>);

        // Récupérer les infos de l'utilisateur associé
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.user_id).get();
        UserData user = UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        article.user = user;

        // Émettre chaque article dès qu'il est prêt
        yield article;
      }
    }
  }
  Future<List<ArticleData>> getArticlesByCategorie2(String categorie_id) async {

    listArticles = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Articles');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect
          .where("disponible",isEqualTo: true)

          .where("categorie_id",isEqualTo: categorie_id)
          .orderBy('createdAt', descending: true)
      //   .limit(10)
          .get();

      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          ArticleData.fromJson(doc.data() as Map<String, dynamic>)).toList();

      print('list article ${listArticles.length}');
      hasData=true;
      // teams.shuffle();

      for (var article in listArticles) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.user_id).get();
        UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        printVm(' article user ${user.toJson()}');

        article.user = user;
      }


      return listArticles;
      // return teams;
    }catch(e){
      print("erreur ${e}");
      hasData=false;
      return [];
    }

  }

  Future<List<ArticleData>> getArticlesByCategorieByUser(String categorie_id,String user_id) async {

    listArticles = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Articles');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect
          .where("disponible",isEqualTo: true)
          .where("user_id",isEqualTo: user_id)

          .where("categorie_id",isEqualTo: categorie_id)
          .orderBy('createdAt', descending: true)
      //   .limit(10)
          .get();

      // Afficher la liste
      listArticles = querySnapshotUser.docs.map((doc) =>
          ArticleData.fromJson(doc.data() as Map<String, dynamic>)).toList();

      print('list article ${listArticles.length}');
      hasData=true;
      // teams.shuffle();

      for (var article in listArticles) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.user_id).get();
        UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
        printVm(' article user ${user.toJson()}');

        article.user = user;
      }


      return listArticles;
      // return teams;
    }catch(e){
      print("erreur ${e}");
      hasData=false;
      return [];
    }

  }


  Future<bool> updateArticle(ArticleData data,BuildContext context) async {
    try{



      await FirebaseFirestore.instance
          .collection('Articles')
          .doc(data.id)
          .update(data.toJson());

      return true;
    }catch(e){
      print("erreur update  : ${e}");
      return false;
    }
  }


  Future<List<ArticleData>> getArticleById(String id) async {
    late List<ArticleData> list= [];


    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('Articles');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef
       // .where("disponible",isEqualTo: true)

        .where("id",isEqualTo: id!).get()
        .then((value){
      print("ArticleData by id");

      print(value);      return value;
    }).catchError((onError){

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        ArticleData.fromJson(doc.data() as Map<String, dynamic>)).toList();
    for (var article in list) {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('Users').doc(article.user_id).get();
      UserData user=UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);
      printVm(' article user ${user.toJson()}');

      article.user = user;
    }

    return list;

  }



  Future<bool> getCodeCommande(String code,CommandeCode cmdcode) async {
   List<CommandeCode>  listcode= [];
   bool existe=true;
   try{
     CollectionReference userCollect =
     FirebaseFirestore.instance.collection('CommandeCodes');
     // Get docs from collection reference
     QuerySnapshot querySnapshotUser = await userCollect

         .get();

     // Afficher la liste
     listcode = querySnapshotUser.docs.map((doc) =>
         CommandeCode.fromJson(doc.data() as Map<String, dynamic>)).toList();
     existe=listcode.any((element) {
       if (element==code) {
         return true;

       }  else{
         final DocumentReference<Map<String, dynamic>> docRef = FirebaseFirestore.instance.collection('CommandeCodes').doc(cmdcode.id);
         docRef.set(cmdcode.toJson());
         return false;

       }
     },);



     print('list code ${listcode.length}');



     return existe;
     // return teams;
   }catch(e){
     print("erreur ${e}");
     return existe;
   }
  }

  Future<List<Commande>> getClientCommande(String user_id,BuildContext context) async {
    late UserShopAuthProvider authProvider =
    Provider.of<UserShopAuthProvider>(context, listen: false);
    late List<Commande> list= [];


    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('Commandes');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where("user_client_id",isEqualTo: user_id!)
      //  .where("article_id",isEqualTo: article_id!)
        .get()
        .then((value){
      print("Commandes by id");

      print(value);      return value;
    }).catchError((onError){

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        Commande.fromJson(doc.data() as Map<String, dynamic>)).toList();
 for(Commande cmd in list) {
   await getArticleById(cmd.article_id!).then((value) {
     if (value.isNotEmpty) {
       cmd.article=value.first;

     }
   },);
   await authProvider.getAfroshopUserById(cmd.user_client_id!).then((value) {
     if (value.isNotEmpty) {
       cmd.user_client=value.first;

     }
   },);
   await authProvider.getAfroshopUserById(cmd.user_magasin_id!).then((value) {
     if (value.isNotEmpty) {
       cmd.user_magasin=value.first;

     }
   },);

 }


    return list;

  }

  Future<List<Commande>> getMagasinCommande(String user_id,BuildContext context) async {
    late UserShopAuthProvider authProvider =
    Provider.of<UserShopAuthProvider>(context, listen: false);
    late List<Commande> list= [];


    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('Commandes');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where("user_magasin_id",isEqualTo: user_id!)
    //  .where("article_id",isEqualTo: article_id!)
        .get()
        .then((value){
      print("Commandes by id");

      print(value);      return value;
    }).catchError((onError){

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        Commande.fromJson(doc.data() as Map<String, dynamic>)).toList();
    for(Commande cmd in list) {
      await getArticleById(cmd.article_id!).then((value) {
        if (value.isNotEmpty) {
          cmd.article=value.first;

        }
      },);
      await authProvider.getAfroshopUserById(cmd.user_client_id!).then((value) {
        if (value.isNotEmpty) {
          cmd.user_client=value.first;

        }
      },);
      await authProvider.getAfroshopUserById(cmd.user_magasin_id!).then((value) {
        if (value.isNotEmpty) {
          cmd.user_magasin=value.first;

        }
      },);

    }


    return list;

  }


  Future<List<Commande>> getClientCommandeByCode(String code,BuildContext context) async {
    late UserShopAuthProvider authProvider =
    Provider.of<UserShopAuthProvider>(context, listen: false);
    late List<Commande> list= [];


    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('Commandes');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where("code",isEqualTo: code!)
    //  .where("article_id",isEqualTo: article_id!)
        .get()
        .then((value){
      print("Commandes by id");

      print(value);      return value;
    }).catchError((onError){

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        Commande.fromJson(doc.data() as Map<String, dynamic>)).toList();
    for(Commande cmd in list) {
      await getArticleById(cmd.article_id!).then((value) {
        if (value.isNotEmpty) {
          cmd.article=value.first;

        }
      },);
      await authProvider.getAfroshopUserById(cmd.user_client_id!).then((value) {
        if (value.isNotEmpty) {
          cmd.user_client=value.first;

        }
      },);
      await authProvider.getAfroshopUserById(cmd.user_magasin_id!).then((value) {
        if (value.isNotEmpty) {
          cmd.user_magasin=value.first;

        }
      },);

    }


    return list;

  }

  Future<bool> updateCommande(Commande data,BuildContext context) async {
    try{



      await FirebaseFirestore.instance
          .collection('Commandes')
          .doc(data.id)
          .update(data.toJson());

      return true;
    }catch(e){
      print("erreur update  : ${e}");
      return false;
    }
  }

  Future<bool> createArticle(ArticleData data) async {
    data.disponible=true;


    try{
      final DocumentReference<Map<String, dynamic>> docRef = FirebaseFirestore.instance.collection('Articles').doc(data.id);
      docRef.set(data.toJson());


      //  await firestore.collection('Matches').doc(id).set(data.toJson());
      print("///////////-- SAVE articles data  --///////////////");
      return true;

    } catch(error){
      return false;

    }
  }

  Future<List<Commande>> getCommandeById(String user_id, String article_id) async {
    late List<Commande> list= [];


    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('Commandes');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where("user_client_id",isEqualTo: user_id!).
    where("article_id",isEqualTo: article_id!)
        .get()
        .then((value){
      print("Commandes by id");

      print(value);      return value;
    }).catchError((onError){

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        Commande.fromJson(doc.data() as Map<String, dynamic>)).toList();


    return list;

  }
  Future<List<Commande>> getCommandeByCode(String code) async {
    late List<Commande> list= [];


    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('Commandes');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where("code",isEqualTo: code!).get()
        .then((value){
      print("Commandes by code");

      print(value);      return value;
    }).catchError((onError){

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        Commande.fromJson(doc.data() as Map<String, dynamic>)).toList();


    return list;

  }
  Future<bool> createCommande(Commande data) async {


    try{
      final DocumentReference<Map<String, dynamic>> docRef = FirebaseFirestore.instance.collection('Commandes').doc(data.id);
      docRef.set(data.toJson());


      //  await firestore.collection('Matches').doc(id).set(data.toJson());
      print("///////////-- SAVE commande data  --///////////////");
      return true;

    } catch(error){
      return false;

    }
  }





}



