

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
//// Avec fallback non boosté (désactivé par défaut)
// final articles = await getArticleBooster(userCountryCode);
//
// // Uniquement les boostés (recommandé)
// final pureBoosted = await getPureBoostedArticles(userCountryCode);
  Future<List<ArticleData>> getArticleBooster(String userCountryCode) async {
    List<ArticleData> listArticles = [];

    // Variable pour désactiver le complément avec des produits non boostés
    final bool allowNonBoostedFallback = false; // Mettre à true si on veut autoriser le fallback

    try {
      CollectionReference articlesRef = FirebaseFirestore.instance.collection('Articles');

      // Récupérer uniquement les produits boostés ACTIFS directement depuis Firestore
      final now = DateTime.now().millisecondsSinceEpoch;

      QuerySnapshot boostedQuery = await articlesRef
          .where("disponible", isEqualTo: true)
          .where("booster", isEqualTo: 1)
          .where("isBoosted", isEqualTo: true)
          .where("boostEndDate", isGreaterThan: now) // Seulement les boosts actifs
          .get();

      List<ArticleData> activeBoostedArticles = boostedQuery.docs.map((doc) {
        final article = ArticleData.fromJson(doc.data() as Map<String, dynamic>);
        article.id = doc.id;
        return article;
      }).toList();

      print('🔥 Produits boostés actifs trouvés: ${activeBoostedArticles.length}');

      // Vérifier et mettre à jour les boosts expirés (sécurité supplémentaire)
      await _checkAndUpdateExpiredBoosts(activeBoostedArticles);

      // Séparer les articles par pays
      List<ArticleData> sameCountryArticles = [];
      List<ArticleData> otherCountryArticles = [];

      for (var article in activeBoostedArticles) {
        final articleCountryCode = article.countryData?['countryCode'] ?? 'TG';
        if (articleCountryCode == userCountryCode) {
          sameCountryArticles.add(article);
        } else {
          otherCountryArticles.add(article);
        }
      }

      print('🇹🇬 Produits même pays ($userCountryCode): ${sameCountryArticles.length}');
      print('🌍 Produits autres pays: ${otherCountryArticles.length}');

      // NOUVEL ALGORITHME - Priorité aux produits boostés uniquement
      if (sameCountryArticles.length >= 10) {
        // Cas 1: Assez de produits boostés du même pays → prendre 10 aléatoires
        listArticles = sameCountryArticles.take(10).toList();
        print('✅ Cas 1: 10+ produits même pays');

      } else if (sameCountryArticles.length >= 3) {
        // Cas 2: Entre 3 et 9 produits du même pays → prendre tous + compléter avec autres pays boostés
        listArticles = sameCountryArticles;
        final needed = 10 - listArticles.length;
        if (otherCountryArticles.isNotEmpty) {
          final additional = otherCountryArticles.take(needed).toList();
          listArticles.addAll(additional);
          print('✅ Cas 2: ${sameCountryArticles.length} produits même pays + ${additional.length} autres pays');
        }

      } else if (sameCountryArticles.length > 0) {
        // Cas 3: Moins de 3 produits du même pays → prendre tous + maximum autres pays boostés
        listArticles = sameCountryArticles;
        final needed = 10 - listArticles.length;
        if (otherCountryArticles.isNotEmpty) {
          final additional = otherCountryArticles.take(needed).toList();
          listArticles.addAll(additional);
          print('✅ Cas 3: ${sameCountryArticles.length} produits même pays + ${additional.length} autres pays');
        }

      } else if (otherCountryArticles.length >= 10) {
        // Cas 4: Aucun produit du même pays, mais assez d'autres pays → prendre 10 aléatoires
        listArticles = otherCountryArticles.take(10).toList();
        print('✅ Cas 4: 10+ produits autres pays');

      } else if (otherCountryArticles.length > 0) {
        // Cas 5: Aucun produit du même pays, quelques autres pays → prendre tous disponibles
        listArticles = otherCountryArticles.take(10).toList();
        print('✅ Cas 5: ${otherCountryArticles.length} produits autres pays seulement');

      } else {
        // Cas 6: Aucun produit boosté du tout
        print('❌ Aucun produit boosté disponible');
      }

      // COMPLÉMENT AVEC PRODUITS NON BOOSTÉS (optionnel)
      if (listArticles.length < 3 && allowNonBoostedFallback) {
        final remaining = 10 - listArticles.length;
        print('🔄 Complément avec ${remaining} produits non boostés');

        final popularArticles = await _getPopularNonBoostedArticles(remaining, userCountryCode);
        listArticles.addAll(popularArticles);

        print('✅ ${popularArticles.length} produits non boostés ajoutés');
      }

      // Mélanger final (sauf si moins de 3 produits)
      if (listArticles.length >= 3) {
        listArticles.shuffle();
      }

      print('🎯 FINAL: ${listArticles.length} produits retournés');
      print('📊 Détail: ${listArticles.where((a) => a.countryData?['countryCode'] == userCountryCode).length} même pays, '
          '${listArticles.where((a) => a.countryData?['countryCode'] != userCountryCode).length} autres pays');

      return listArticles;

    } catch (e) {
      print("❌ Erreur getArticleBooster: $e");
      return [];
    }
  }

// Vérifier et mettre à jour les boosts expirés
  Future<void> _checkAndUpdateExpiredBoosts(List<ArticleData> boostedArticles) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = FirebaseFirestore.instance.batch();
    int updatedCount = 0;

    for (var article in boostedArticles) {
      // Double vérification côté client
      if (article.boostEndDate != null && article.boostEndDate! <= now) {
        final articleRef = FirebaseFirestore.instance.collection('Articles').doc(article.id);
        batch.update(articleRef, {
          'booster': 0,
          'isBoosted': false,
          'boostEndDate': null,
          'updatedAt': now,
        });
        updatedCount++;
      }
    }

    if (updatedCount > 0) {
      try {
        await batch.commit();
        print('🔄 $updatedCount boosts expirés mis à jour');
      } catch (e) {
        print("❌ Erreur mise à jour boosts expirés: $e");
      }
    }
  }

// Récupérer des articles populaires non boostés pour compléter (SEULEMENT SI ACTIVÉ)
  Future<List<ArticleData>> _getPopularNonBoostedArticles(int limit, String userCountryCode) async {
    try {
      CollectionReference articlesRef = FirebaseFirestore.instance.collection('Articles');

      QuerySnapshot popularQuery = await articlesRef
          .where("disponible", isEqualTo: true)
          .where("booster", isEqualTo: 0) // Uniquement non boostés
          .orderBy('vues', descending: true)
          .orderBy('jaime', descending: true)
          .limit(limit * 3) // Prendre plus pour mieux filtrer
          .get();

      List<ArticleData> popularArticles = popularQuery.docs.map((doc) {
        final article = ArticleData.fromJson(doc.data() as Map<String, dynamic>);
        article.id = doc.id;
        return article;
      }).toList();

      // Prioriser les articles du même pays
      popularArticles.sort((a, b) {
        final aCountry = a.countryData?['countryCode'] ?? 'TG';
        final bCountry = b.countryData?['countryCode'] ?? 'TG';

        if (aCountry == userCountryCode && bCountry != userCountryCode) return -1;
        if (aCountry != userCountryCode && bCountry == userCountryCode) return 1;

        // Si même pays, prioriser par popularité
        final aPopularity = (a.vues ?? 0) + (a.jaime ?? 0);
        final bPopularity = (b.vues ?? 0) + (b.jaime ?? 0);
        return bPopularity.compareTo(aPopularity);
      });

      return popularArticles.take(limit).toList();

    } catch (e) {
      print("❌ Erreur _getPopularNonBoostedArticles: $e");
      return [];
    }
  }
//// Avec fallback non boosté (désactivé par défaut)
// final articles = await getArticleBooster(userCountryCode);
//
// // Uniquement les boostés (recommandé)
// final pureBoosted = await getPureBoostedArticles(userCountryCode);
// NOUVELLE FONCTION: Récupérer uniquement les produits boostés (sans fallback)
  Future<List<ArticleData>> getPureBoostedArticles(String userCountryCode) async {
    try {
      CollectionReference articlesRef = FirebaseFirestore.instance.collection('Articles');

      final now = DateTime.now().millisecondsSinceEpoch;

      QuerySnapshot boostedQuery = await articlesRef
          .where("disponible", isEqualTo: true)
          .where("booster", isEqualTo: 1)
          .where("isBoosted", isEqualTo: true)
          .where("boostEndDate", isGreaterThan: now)
          .get();

      List<ArticleData> boostedArticles = boostedQuery.docs.map((doc) {
        final article = ArticleData.fromJson(doc.data() as Map<String, dynamic>);
        article.id = doc.id;
        return article;
      }).toList();

      // Séparer par pays
      List<ArticleData> sameCountry = [];
      List<ArticleData> otherCountry = [];

      for (var article in boostedArticles) {
        final articleCountryCode = article.countryData?['countryCode'] ?? 'TG';
        if (articleCountryCode == userCountryCode) {
          sameCountry.add(article);
        } else {
          otherCountry.add(article);
        }
      }

      // Prioriser le même pays, puis les autres
      List<ArticleData> result = [];
      result.addAll(sameCountry);
      result.addAll(otherCountry);

      // Limiter à 10 maximum
      return result.take(10).toList();

    } catch (e) {
      print("❌ Erreur getPureBoostedArticles: $e");
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



