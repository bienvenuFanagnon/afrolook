import 'dart:io';
import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/user/userService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chatmodels/message.dart';

import '../pages/component/consoleWidget.dart';
import '../services/auth/authService.dart';
import 'authProvider.dart';



class UserProvider extends ChangeNotifier {
  late AuthService authService = AuthService();
  late UserService userService = UserService();
  late Chat chat = Chat();
  late EntrepriseData entrepriseData = EntrepriseData();
  late int countFriends=0;
  late int countInvitations=0;
  late int mes_msg_non_lu=0;
  late List<UserData> listUsers = [];
  // List<Information> listInfos = [];
  List<Annonce> listAnnonces = [];
  late List<UserData> listUserAnnonces = [];
  late List<UserData> listAllUsers = [];

  late List<String> alphabet = [];
  List<Message> usermessageList =[];
  late List<UserAbonnes> otherAbonnes = [];
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

setMessageNonLu(int nbr){
  mes_msg_non_lu=nbr;
  notifyListeners();
}

  Future<bool> updateUser(UserData user) async {
    try{



      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.id)
          .update(user.toJson());
      //printVm("user update : ${user!.toJson()}");
      return true;
    }catch(e){
      printVm("erreur update post : ${e}");
      return false;
    }
  }

  Future<bool> updateEntreprise(EntrepriseData entrepriseData) async {
    try{



      await FirebaseFirestore.instance
          .collection('Entreprises')
          .doc(entrepriseData.id)
          .update(entrepriseData.toJson());
      return true;
    }catch(e){
      printVm("erreur update post : ${e}");
      return false;
    }
  }

  Future<bool> sendSimpleMessage({required Message message,required String receiver_id,required String sender_id}) async {
    bool resp=false;

    if(await userService.sendSimpleMessage( message: message, receiver_id: receiver_id, sender_id: sender_id,)){
      //registerText= ResponseText.registerSuccess;
      resp=true;
    }else{
      //registerText= ResponseText.registerErreur;
      resp=false;
    }
    notifyListeners();
    return resp;
  }

  List<Information> _listInfos = [];
  List<Information> get listInfos => _listInfos;

  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool get hasMore => _hasMore;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<List<Information>> getAllInfos({bool loadMore = false, int limit = 5}) async {
    if (_isLoading) return _listInfos;

    _isLoading = true;
    if (!loadMore) {
      _listInfos = [];
      _lastDocument = null;
      _hasMore = true;
    }

    try {
      CollectionReference infoCollection = FirebaseFirestore.instance.collection('Informations');
      Query query = infoCollection
          .where("type", isEqualTo: InfoType.APPINFO.name)
          .where("status", isEqualTo: PostStatus.VALIDE.name)
          .orderBy('is_featured', descending: true)
          .orderBy('featured_at', descending: true)
          .orderBy('created_at', descending: true)
          .limit(limit);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      QuerySnapshot querySnapshot = await query.get();

      if (querySnapshot.docs.isEmpty) {
        _hasMore = false;
      } else {
        _lastDocument = querySnapshot.docs.last;
        List<Information> newInfos = querySnapshot.docs.map((doc) {
          return Information.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        if (loadMore) {
          _listInfos.addAll(newInfos);
        } else {
          _listInfos = newInfos;
        }

        _hasMore = newInfos.length == limit;
      }
    } catch (e) {
      print('Error loading infos: $e');
    }

    _isLoading = false;
    notifyListeners();
    return _listInfos;
  }

  Future<void> incrementViews(String infoId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Informations')
          .doc(infoId)
          .update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing views: $e');
    }
  }

  Future<void> toggleLike(String infoId, String userId) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('Informations').doc(infoId);
      final likeDoc = await FirebaseFirestore.instance
          .collection('InformationLikes')
          .doc('${infoId}_$userId')
          .get();

      if (likeDoc.exists) {
        // Unlike
        await likeDoc.reference.delete();
        await docRef.update({
          'likes': FieldValue.increment(-1),
        });
      } else {
        // Like
        await likeDoc.reference.set({
          'info_id': infoId,
          'user_id': userId,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
        await docRef.update({
          'likes': FieldValue.increment(1),
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  Future<bool> isLiked(String infoId, String userId) async {
    try {
      final likeDoc = await FirebaseFirestore.instance
          .collection('InformationLikes')
          .doc('${infoId}_$userId')
          .get();
      return likeDoc.exists;
    } catch (e) {
      print('Error checking like: $e');
      return false;
    }
  }

  // Fonctions admin
  Future<void> deleteInfo(String infoId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Informations')
          .doc(infoId)
          .delete();

      _listInfos.removeWhere((info) => info.id == infoId);
      notifyListeners();
    } catch (e) {
      print('Error deleting info: $e');
      throw e;
    }
  }

  Future<void> toggleFeatured(String infoId, bool featured) async {
    try {
      await FirebaseFirestore.instance
          .collection('Informations')
          .doc(infoId)
          .update({
        'is_featured': featured,
        'featured_at': featured ? DateTime.now().millisecondsSinceEpoch : 0,
      });
    } catch (e) {
      print('Error toggling featured: $e');
      throw e;
    }
  }

  void resetPagination() {
    _lastDocument = null;
    _hasMore = true;
    _isLoading = false;
  }

  Future<List<Annonce>> getAllAnnonces() async {


    List<Annonce> annonces  =[];

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Annonces');
    QuerySnapshot querySnapshotPost = await postCollect
        .where("status",isEqualTo:'${PostStatus.VALIDE.name}')
        .orderBy('created_at', descending: true)
        .get();

 annonces = querySnapshotPost.docs.map((doc) =>
        Annonce.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();

    annonces.forEach((annonce) async {

      annonce.vues=annonce.vues!+1;
      await firestore.collection('Annonces').doc( annonce!.id).update( annonce!.toJson());
      int microsecondsSinceEpoch = 1646481600000000;

      // Conversion de la date micromilliemme en date
      DateTime date = DateTime.fromMicrosecondsSinceEpoch(annonce.createdAt!);
      DateTime now = DateTime.now();

      // Calcul du nombre de jours depuis l'époque Unix
      int daysSinceEpoch = now.difference(date).inDays;
      printVm("nombre de jour: ${daysSinceEpoch}");

      if (daysSinceEpoch>annonce.jour!) {
        //annonces.remove(annonce);
        annonce.status=PostStatus.NONVALIDE.name;
        await firestore.collection('Annonces').doc( annonce!.id).update( annonce!.toJson());
      }
    });
    listAnnonces=annonces;
    return listAnnonces;

  }

  Future<List<Information>> getGratuitInfos() async {


    // listInfos =[];

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Informations');
    QuerySnapshot querySnapshotPost = await postCollect

    .where("type",isEqualTo:'${InfoType.GRATUIT.name}')
        .where("status",isEqualTo:'${PostStatus.VALIDE.name}')
        .orderBy('created_at', descending: true)
        .get();

    // listInfos = querySnapshotPost.docs.map((doc) =>
    //     Information.fromJson(doc.data() as Map<String, dynamic>)).toList();
    // //  UserData userData=UserData();



    return listInfos;

  }
  Future<bool> getUsersProfile(String currentUserId,BuildContext context) async {
    late UserAuthProvider authProvider =
    Provider.of<UserAuthProvider>(context, listen: false);
    listUsers = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Users');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect
      // .where("id",isNotEqualTo: currentUserId)
          .orderBy('pseudo').startAt([Random().nextDouble()])
          //.orderBy('popularite', descending: true)
          .limit(3)

          .get();

      // Afficher la liste
      listUsers = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      listUsers.forEach((loginUserData) async {

        loginUserData.popularite=(loginUserData.abonnes!+loginUserData.likes!+loginUserData.jaimes!)/(authProvider.appDefaultData.nbr_abonnes!+authProvider.appDefaultData.nbr_likes!+authProvider.appDefaultData.nbr_loves!);
        loginUserData.compteTarif=loginUserData.popularite!*80;
        await firestore.collection('Users').doc( loginUserData!.id).update( loginUserData!.toJson());
        if (loginUserData.id==currentUserId) {
          listUsers.remove(loginUserData);
        }
      });

      // for(UserData user in listUsers){
      //   user.abonnes=user.userAbonnesIds==null?0:user.userAbonnesIds!.length;
      //   updateUser(user);
      //
      //
      // }

      listUserAnnonces=listUsers;
      printVm('list users ${listUsers.length}');
      hasData=true;

    }catch(e){
      printVm("erreur ${e}");
      hasData=false;
    }



    //notifyListeners();
    return hasData;
  }
  Future<bool> getUsers(String currentUserId,BuildContext context) async {
    late UserAuthProvider authProvider =
    Provider.of<UserAuthProvider>(context, listen: false);
    listUsers = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Users');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect
         // .where("id",isNotEqualTo: currentUserId)
          .orderBy('popularite', descending: true)
          .limit(30)
          .get();

      // Afficher la liste
      listUsers = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      listUsers.forEach((loginUserData) async {

        loginUserData.popularite=(loginUserData.abonnes!+loginUserData.likes!+loginUserData.jaimes!)/(authProvider.appDefaultData.nbr_abonnes!+authProvider.appDefaultData.nbr_likes!+authProvider.appDefaultData.nbr_loves!);
        loginUserData.compteTarif=loginUserData.popularite!*80;
        await firestore.collection('Users').doc( loginUserData!.id).update( loginUserData!.toJson());
        if (loginUserData.id==currentUserId) {
          listUsers.remove(loginUserData);
        }
      });




      printVm('list users ${listUsers.length}');
      hasData=true;

    }catch(e){
      printVm("erreur ${e}");
      hasData=false;
    }



    //notifyListeners();
    return hasData;
  }
  Future<List<UserData>> updateTopUsersPopularity(AppDefaultData appData) async {
    List<UserData> topUsers = [];

    try {
      // 🔥 Vérifier que appTotalPoints n'est pas nul ou zéro
      if (appData.appTotalPoints == 0) {
        print("❌ ERREUR : appTotalPoints = 0, impossible de calculer la popularité.");
        return [];
      }

      // 📌 Récupérer Top 10
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .orderBy('totalPoints', descending: true)
          .limit(10)
          .get();

      topUsers = querySnapshot.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // 📌 Mise à jour simultanée avec Batch
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (UserData user in topUsers) {
        print("user totalPoints : ${user.totalPoints}");
        int userPoints = user.totalPoints ?? 0;

        // 🧮 Calcul de popularité (0 à 1)
        double popularite = (userPoints / appData.appTotalPoints)*100;

        // Limiter à 5 chiffres après virgule
        popularite = double.parse(popularite.toStringAsFixed(2));

        // 📌 Référence Firestore
        DocumentReference userRef =
        FirebaseFirestore.instance.collection('Users').doc(user.id);
        print("user totalPoints popularite: ${popularite}");

        batch.update(userRef, {
          "popularite": popularite,
        });

        user.popularite = popularite; // mettre à jour localement aussi
      }

      // 🚀 Lancer l’update
      await batch.commit();

      print("🔥 Popularité mise à jour pour les Top 10 utilisateurs.");

      return topUsers;

    } catch (e) {
      print("❌ Erreur updateTopUsersPopularity : $e");
      return [];
    }
  }

  Future<List<UserData>> getTopAfrolookeur() async {

    listAllUsers = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Users');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect

          .orderBy('totalPoints', descending: true)
          // .orderBy('popularite', descending: true)
          .limit(10)
          .get();

      // Afficher la liste
      listAllUsers = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();


      // for(UserData user in listAllUsers){
      //   user.abonnes=user.userAbonnesIds==null?0:user.userAbonnesIds!.length;
      //   updateUser(user);
      //
      //
      // }


   //   printVm('list users ${listAllUsers.length}');
      hasData=true;
      return listAllUsers;
    }catch(e){
      printVm("erreur ${e}");
      hasData=false;
      return [];
    }

  }
  Future<List<UserData>> getUserAbonnes(String userId) async {
    try {
      // 1. Récupérer l’utilisateur
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return [];

      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

      // 2. Récupérer la liste des IDs abonnés
      List<String> abonnesIds = List<String>.from(data['userAbonnesIds'] ?? []);

      if (abonnesIds.isEmpty) return [];

      // 3. Limiter à 1000 max
      if (abonnesIds.length > 1000) {
        abonnesIds = abonnesIds.sublist(0, 1000);
      }

      // 4. Firestore limitation: IN maximum 10 (ou 30 selon config)
      // Donc on doit faire des batches
      List<UserData> abonnesList = [];

      const int batchSize = 10;
      for (var i = 0; i < abonnesIds.length; i += batchSize) {
        var batchIds = abonnesIds.skip(i).take(batchSize).toList();

        QuerySnapshot batchSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .where('id', whereIn: batchIds)
            .get();

        abonnesList.addAll(
          batchSnapshot.docs.map((doc) =>
              UserData.fromJson(doc.data() as Map<String, dynamic>)),
        );
      }

      return abonnesList;
    } catch (e) {
      print("Erreur getUserAbonnes: $e");
      return [];
    }
  }

  Future<List<UserData>> getChallengeUsers(
      List<String> userIds) async {


    List<UserData> listUsers = [];

    if (userIds.isEmpty) return listUsers; // Si la liste est vide, retourner une liste vide.

    try {
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Users');

      // Récupérer uniquement les utilisateurs correspondant aux IDs fournis
      QuerySnapshot querySnapshotUser = await userCollect
          .where('id', whereIn: userIds)
          // .limit(limit)
          .get();

      // Convertir les documents en objets UserData
      listUsers = querySnapshotUser.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      listUsers.shuffle(); // Mélanger les résultats pour un effet aléatoire

      print('Liste des utilisateurs récupérés: ${listUsers.length}');

    } catch (e) {
      print('Erreur lors de la récupération des utilisateurs : $e');
    }

    return listUsers;
  }
  Stream<List<UserData>> streamProfileUsers(
      String currentUserId,
      BuildContext context,
      int limit,
      ) {
    late UserAuthProvider authProvider =
    Provider.of<UserAuthProvider>(context, listen: false);

    alphabet = authProvider.appDefaultData.users_id!;
    alphabet.shuffle();
    alphabet = alphabet.length < 100
        ? alphabet.sublist(0, alphabet.length - 1)
        : alphabet.sublist(0, 100);

    CollectionReference userCollect =
    FirebaseFirestore.instance.collection('Users');

    return userCollect.snapshots().map((snapshot) {
      List<DocumentSnapshot> users = snapshot.docs;
      users.shuffle(); // mélanger
      List<DocumentSnapshot> usersDocs = users.take(limit).toList();

      return usersDocs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<List<UserData>> getProfileUsers(String currentUserId,BuildContext context,int limit) async {
    late UserAuthProvider authProvider =
    Provider.of<UserAuthProvider>(context, listen: false);
    listUsers = [];
    alphabet= authProvider.appDefaultData.users_id!;


    alphabet.shuffle();
    // alphabet = alphabet.sublist(0,alphabet.length>5?6:alphabet.length>2?3:alphabet.length>10?11: alphabet.length>15?16: alphabet.length>20?20: alphabet.length>25?26:alphabet.length>30?30: alphabet.length>35?36: alphabet.length>40?41:alphabet.length>50?50: alphabet.length>60?61:alphabet.length>70?70: alphabet.length>80?81: alphabet.length>90?91:alphabet.length>100?100:1);
    alphabet = alphabet.length<100?alphabet.sublist(0,alphabet.length-1):alphabet.sublist(0,100);

    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Users');
      // Get docs from collection reference
      //  QuerySnapshot querySnapshotUser = await userCollect
      //     //.where("id",isNotEqualTo: currentUserId)
      // //  .where("id",isNotEqualTo: currentUserId)
      //    //  .orderBy('pseudo').startAt([Random().nextDouble()])
      //  .orderBy('createdAt', descending: true)
      //     .where('id', whereIn: alphabet)
      //      .limit(limit)
      //      .get();

      // Générer une valeur aléatoire pour le point de départ
      // double randomStartPoint = Random().nextDouble();
      // // Récupérer les utilisateurs de manière aléatoire
      // QuerySnapshot querySnapshotUser = await userCollect
      //     // .orderBy('createdAt', descending: true)
      //     .startAt([randomStartPoint])
      //     .limit(limit)
      //     .get();

      QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('Users').get();
      List<DocumentSnapshot> users = querySnapshot.docs;
      users.shuffle(); // Mélanger la liste pour obtenir des utilisateurs aléatoires
      List<DocumentSnapshot> usersDocs= users.take(limit).toList();

      // Afficher la liste
      // listUsers = querySnapshotUser.docs.map((doc) =>
      listUsers = usersDocs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      // for(UserData user in listUsers){
      //   user.abonnes=user.userAbonnesIds==null?0:user.userAbonnesIds!.length;
      //   updateUser(user);
      //
      //
      // }


      // listUsers.shuffle();
      listUsers.shuffle();



      printVm('list users ${listUsers.length}');
      hasData=true;

    }catch(e){
      printVm("erreur ${e}");
      hasData=false;
    }



    //notifyListeners();
    return listUsers;
  }

  Future<List<UserData>> getUsersFilter(String filter,userId) async {
    //listUsers=[];
    final users = FirebaseFirestore.instance.collection('Users')
        .where('id', isNotEqualTo: userId)
        .limit(100)
        .get();

    // Afficher la liste
    users.then((snapshot) {
      snapshot.docs.forEach((doc) {
        //printVm(doc.data());
        listUsers.add(  UserData.fromJson(doc.data() as Map<String, dynamic>));

      });
    });
    return listUsers.where((user) => user.pseudo!.toLowerCase().contains(filter.toLowerCase())).toList();

  }

  Stream<UserData> getStreamUser(String user_id) async* {

    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance.collection('Users').where("id",isEqualTo:user_id ).snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    List<UserData> users = [];
    UserData userData=UserData();


    await for (var friendSnapshot in friendsStream) {

      for (var friendDoc in friendSnapshot.docs) {

          userData=UserData.fromJson(friendDoc.data());

      }
      yield userData;
    }
  }
  Stream<Chat> getStreamChat(String chat_id) async* {

    // Définissez la requête
    var chatsStream = FirebaseFirestore.instance.collection('Chats').where("id",isEqualTo:chat_id ).snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    List<Chat> chats = [];
    Chat chatData=Chat();


    await for (var chatSnapshot in chatsStream) {

      for (var friendDoc in chatSnapshot.docs) {

        chatData=Chat.fromJson(friendDoc.data());

      }
      yield chatData;
    }
  }


  Future<bool> getOtherAbonnes(String userId) async {
    otherAbonnes = [];
    bool hasData=false;
    CollectionReference userCollect =
    FirebaseFirestore.instance.collection('Abonnements');
    // Get docs from collection reference
    QuerySnapshot querySnapshotUser = await userCollect.where("abonne_user_id",isEqualTo: userId).get();
    // Afficher la liste
    List<UserAbonnes> userListAbonnes = querySnapshotUser.docs.map((doc) =>
        UserAbonnes.fromJson(doc.data() as Map<String, dynamic>)).toList();
    otherAbonnes=userListAbonnes;




    notifyListeners();
    return hasData;
  }

  Future<bool> getUserEntreprise(String userId) async {

    late bool haveData=false;

    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('Entreprises');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where("userId",isEqualTo: userId!).get()
        .then((value){

      return value;
    }).catchError((onError){

    });

    // Get data from docs and convert map to List
   List<EntrepriseData> listEntreprise = querySnapshot.docs.map((doc) =>
       EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();

    if (listEntreprise.isNotEmpty) {
      listEntreprise.first.suivi=listEntreprise.first.usersSuiviId!.length;

      entrepriseData=listEntreprise.first;
      haveData=true;
    }


    return haveData;

  }




  Future<List<Message>> getUsersMessage(Chat chat) async {
    CollectionReference messageCollect = await FirebaseFirestore.instance.collection('Messages');
    QuerySnapshot querySnapshotMessage = await messageCollect.where("chat_id",isEqualTo:chat.id!).get();
    // Afficher la liste
    List<Message> messageList = querySnapshotMessage.docs.map((doc) =>
        Message.fromJson(doc.data() as Map<String, dynamic>)).toList();
    usermessageList=messageList;
    return messageList;
  }
  Future<bool> abonne({required String compte_user_id, required String abonne_user_id}) async {

    bool resp=false;


    if(await userService.abonne(compte_user_id: compte_user_id,abonne_user_id: abonne_user_id)){

      resp=true;
    }else{


      //loginText= ResponseText.loginErreur;
      resp=false;
    }
    notifyListeners();
    return resp;
  }



  Future<bool> sendInvitation(Invitation invitation,BuildContext context) async {
    late UserAuthProvider authProvider =
    Provider.of<UserAuthProvider>(context, listen: false);
    bool resp=false;

  String id = firestore
      .collection('Invitations')
      .doc()
      .id;
    invitation.id = id;
    authProvider.loginUserData!.pointContribution=authProvider.loginUserData!.pointContribution!+1;
  try{


    await firestore.collection('Invitations').doc(id).set(invitation.toJson());
    await firestore.collection('Users').doc( authProvider.loginUserData!.id).update( authProvider.loginUserData!.toJson());
    resp=true;

}   on FirebaseException catch(error){
    resp=false;
  }

    notifyListeners();
    return resp;
  }

  Future<bool> sendAbonnementRequest(UserAbonnes abonnes,UserData user,BuildContext context) async {

    bool resp=false;
    late UserAuthProvider authProvider =
    Provider.of<UserAuthProvider>(context, listen: false);
    String id = firestore
        .collection('Abonnements')
        .doc()
        .id;
    abonnes.id = id;
    user.abonnes=user.abonnes!+1;
    authProvider.loginUserData!.pointContribution=authProvider.loginUserData!.pointContribution!+4;
    try{


      await firestore.collection('Abonnements').doc(id).set(abonnes.toJson());
      await firestore.collection('Users').doc( authProvider.loginUserData!.id).update( authProvider.loginUserData!.toJson());
      await firestore.collection('Users').doc( user.id).update( user.toJson());

      authProvider.getCurrentUser(authProvider.loginUserData!.id!);
      resp=true;

    }   on FirebaseException catch(error){
      resp=false;
    }

    notifyListeners();
    return resp;
  }

  Future<bool> acceptInvitation(Invitation invitation) async {

    bool resp=false;

    try {
      invitation.status=InvitationStatus.ACCEPTER.name;

      await  firestore.collection('Invitations').doc(invitation.id).update(invitation.toJson());
      String id = firestore
          .collection('Friends')
          .doc()
          .id;
      Friends friends=Friends();
      friends.id=id;
      friends.friendId=invitation.senderId;
      friends.currentUserId=invitation.receiverId;
      friends.createdAt=DateTime.now().millisecondsSinceEpoch;
      friends.updatedAt=DateTime.now().millisecondsSinceEpoch;





        await firestore.collection('Friends').doc(id).set(friends.toJson());

      resp=true;
    } catch (e) {

      printVm(e);
      resp=false;
    }

    notifyListeners();
    return resp;
  }

  Future<bool> updateMessage(Message message) async {
    try{



      await FirebaseFirestore.instance
          .collection('Messages')
          .doc(message.id)
          .update(message.toJson());
      //printVm("user update : ${user!.toJson()}");
      printVm(" update message");

      return true;
    }catch(e){
      printVm("erreur update message : ${e}");
      return false;
    }
  }

  Future<bool> refuserInvitation(Invitation invitation) async {

    bool resp=false;

    try {
      invitation.status=InvitationStatus.REFUSER.name;

      await  firestore.collection('Invitations').doc(invitation.id).update(invitation.toJson());


      resp=true;
    } catch (e) {

      printVm(e);
      resp=false;
    }

    notifyListeners();
    return resp;
  }

  Future<bool> changeState({required UserData user, required String state}) async {
    final String previousState = user.state ?? ''; // Sauvegarde de l'ancien state

    try {
      // // Mise à jour optimisée dans Firebase
      // final updateData = <String, dynamic>{
      //   'state': state,
      //   // 'last_time_active': FieldValue.serverTimestamp()
      // };
      //
      // await firestore.collection('Users').doc(user.id).update(updateData);
      //
      // // Mise à jour locale uniquement après succès
      // user.state = state;
      // notifyListeners();
      //
      // printVm('State utilisateur mis à jour avec succès: $state');
      return true;

    } catch (e, stackTrace) {
      printVm('Échec mise à jour state: $e');
      printVm('Stack trace: $stackTrace');

      // Garder l'ancien state en cas d'erreur
      user.state = previousState;
      notifyListeners();

      return false;
    }
  }
  Future<bool> changeStateUser({required UserData user, required String state, required bool isConnected}) async {
    final String previousState = user.state ?? ''; // Sauvegarde de l'ancien state

    try {
      // Mise à jour optimisée dans Firebase
      final updateData = <String, dynamic>{
        'state': state,
        'isConnected': isConnected,
        // 'last_time_active': FieldValue.serverTimestamp()
      };

      await firestore.collection('Users').doc(user.id).update(updateData);

      // Mise à jour locale uniquement après succès
      user.state = state;
      notifyListeners();

      printVm('State utilisateur mis à jour avec succès: $state');
      return true;

    } catch (e, stackTrace) {
      printVm('Échec mise à jour state: $e');
      printVm('Stack trace: $stackTrace');

      // Garder l'ancien state en cas d'erreur
      user.state = previousState;
      notifyListeners();

      return false;
    }
  }

}
