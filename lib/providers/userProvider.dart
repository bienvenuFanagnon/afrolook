import 'package:afrotok/services/read_meter.dart';
import 'dart:io';
import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
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
// Ajouter cette méthode dans la classe UserProvider
  Future<List<UserData>> searchUsersByPseudo(String query) async {
    if (query.isEmpty) return [];
    try {
      return (await UsersApi.searchUsers(query, limit: 10)).map(userSummaryFromApi).toList();
    } catch (e) {
      printVm('Erreur recherche créateur: $e');
      return [];
    }
  }
  Future<bool> updateUser(UserData user) async {
    try {
      await UsersApi.updateMe(userUpdateBody(user));
      return true;
    } catch (e) {
      printVm("erreur update profil : ${e}");
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

      QuerySnapshot querySnapshot = await query.getM('userProvider.dart:144');

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
      printVm('Error loading infos: $e');
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
      printVm('Error incrementing views: $e');
    }
  }

  Future<void> toggleLike(String infoId, String userId) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('Informations').doc(infoId);
      final likeDoc = await FirebaseFirestore.instance
          .collection('InformationLikes')
          .doc('${infoId}_$userId')
          .getM('userProvider.dart:190');

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
      printVm('Error toggling like: $e');
    }
  }

  Future<bool> isLiked(String infoId, String userId) async {
    try {
      final likeDoc = await FirebaseFirestore.instance
          .collection('InformationLikes')
          .doc('${infoId}_$userId')
          .getM('userProvider.dart:219');
      return likeDoc.exists;
    } catch (e) {
      printVm('Error checking like: $e');
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
      printVm('Error deleting info: $e');
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
      printVm('Error toggling featured: $e');
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
        .getM('userProvider.dart:273');

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
        .getM('userProvider.dart:315');

    // listInfos = querySnapshotPost.docs.map((doc) =>
    //     Information.fromJson(doc.data() as Map<String, dynamic>)).toList();
    // //  UserData userData=UserData();



    return listInfos;

  }
  Future<bool> getUsersProfile(String currentUserId,BuildContext context) async {
    listUsers = [];
    try {
      listUsers = (await UsersApi.suggestions(limit: 6)).map(userSummaryFromApi).where((u) => u.id != currentUserId).take(3).toList();
      listUserAnnonces = listUsers;
      return true;
    } catch (e) {
      printVm("erreur ${e}");
      return false;
    }
  }
  Future<bool> getUsers(String currentUserId,BuildContext context) async {
    listUsers = [];
    try {
      listUsers = (await UsersApi.suggestions(limit: 30)).map(userSummaryFromApi).where((u) => u.id != currentUserId).toList();
      return true;
    } catch (e) {
      printVm("erreur ${e}");
      return false;
    }
  }
  Future<List<UserData>> updateTopUsersPopularity(AppDefaultData appData) async {
    // La popularité est calculée par le serveur : l'application ne l'écrit plus, elle lit seulement le classement.
    return getTopAfrolookeur();
  }

  Future<List<UserData>> getTopAfrolookeur() async {
    try {
      listAllUsers = (await UsersApi.topUsers(limit: 10)).map(userSummaryFromApi).toList();
      return listAllUsers;
    } catch (e) {
      printVm("erreur ${e}");
      listAllUsers = [];
      return [];
    }
  }
  Future<List<UserData>> getUserAbonnes(String userId) async {
    try {
      final out = <UserData>[];
      String? cursor;
      do {
        final page = await UsersApi.followers(userId, cursor: cursor, limit: 100);
        out.addAll(page.items.map(userSummaryFromApi));
        cursor = page.next;
      } while (cursor != null && out.length < 1000);
      return out;
    } catch (e) {
      printVm("Erreur getUserAbonnes: $e");
      return [];
    }
  }

  Future<List<UserData>> getUsersBatch(List<String> userIds) async {
    final users = <UserData>[];
    try {
      for (var i = 0; i < userIds.length; i += 50) {
        final rows = await UsersApi.lookup(userIds.sublist(i, i + 50 < userIds.length ? i + 50 : userIds.length));
        users.addAll(rows.map(userFromApi));
      }
      users.sort((a, b) => b.followersCount.compareTo(a.followersCount));
    } catch (e) {
      printVm('❌ Erreur getUsersBatch: $e');
    }
    return users;
  }
  Stream<List<UserData>> streamProfileUsers(String currentUserId, BuildContext context, int limit) async* {
    try {
      final rows = (await UsersApi.suggestions(limit: limit + 1)).map(userSummaryFromApi).where((u) => u.id != currentUserId).toList()..shuffle();
      yield rows.take(limit).toList();
    } catch (e) {
      printVm("erreur ${e}");
      yield <UserData>[];
    }
  }

  Future<List<UserData>> getProfileUsers(String currentUserId,BuildContext context,int limit) async {
    listUsers = [];
    try {
      listUsers = (await UsersApi.suggestions(limit: limit + 1)).map(userSummaryFromApi).where((u) => u.id != currentUserId).take(limit).toList();
    } catch (e) {
      printVm("erreur ");
    }
    return listUsers;
  }

  Future<List<UserData>> getUsersFilter(String filter,userId) async {
    if (filter.isEmpty) return [];
    try {
      listUsers = (await UsersApi.searchUsers(filter, limit: 50)).map(userSummaryFromApi).where((u) => u.id != userId).toList();
    } catch (e) {
      printVm("erreur ${e}");
    }
    return listUsers.where((user) => (user.pseudo ?? '').toLowerCase().contains(filter.toLowerCase())).toList();
  }

  Stream<UserData> getStreamUser(String user_id) async* {
    // L'API n'a pas de temps réel : le profil est relu toutes les 30 s.
    while (true) {
      try {
        yield userFromApi(await UsersApi.publicProfile(user_id));
      } catch (e) {
        printVm("erreur ${e}");
      }
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }
  Stream<Chat> getStreamChat(String chat_id) async* {

    // Définissez la requête
    var chatsStream = FirebaseFirestore.instance.collection('Chats').where("id",isEqualTo:chat_id ).snapshotsM('userProvider.dart:795');

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
    try {
      String? cursor;
      do {
        final page = await UsersApi.following(userId, cursor: cursor, limit: 100);
        otherAbonnes.addAll(page.items.map((j) => UserAbonnes(id: '${j['id']}', compteUserId: '${j['id']}', abonneUserId: userId)));
        cursor = page.next;
      } while (cursor != null && otherAbonnes.length < 1000);
    } catch (e) {
      printVm("erreur ${e}");
    }
    notifyListeners();
    return otherAbonnes.isNotEmpty;
  }

  Future<bool> getUserEntreprise(String userId) async {

    late bool haveData=false;

    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('Entreprises');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where("userId",isEqualTo: userId!).getM('userProvider.dart:841')
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
    QuerySnapshot querySnapshotMessage = await messageCollect.where("chat_id",isEqualTo:chat.id!).getM('userProvider.dart:870');
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
    bool resp = false;
    try {
      // Les règles (doublon, blocage, 7 jours après un refus, plafond quotidien) sont appliquées par le serveur.
      final r = await UsersApi.invite(invitation.receiverId ?? '', message: invitation.message);
      invitation.id = (r['id'] ?? invitation.id) as String?;
      resp = true;
    } catch (e) {
      printVm("erreur invitation : ${UsersApi.message(e)}");
      lastInvitationError = UsersApi.message(e);
    }
    notifyListeners();
    return resp;
  }

  /// Dernier message d'erreur (français) renvoyé par l'API pour une invitation refusée.
  String? lastInvitationError;

  Future<bool> sendAbonnementRequest(UserAbonnes abonnes,UserData user,BuildContext context) async {
    bool resp = false;
    try {
      final already = await UsersApi.follow(user.id!);
      if (!already) user.abonnes = (user.abonnes ?? 0) + 1;
      resp = true;
    } catch (e) {
      printVm("erreur abonnement : ${UsersApi.message(e)}");
    }
    notifyListeners();
    return resp;
  }

  Future<bool> acceptInvitation(Invitation invitation) async {
    bool resp = false;
    try {
      await UsersApi.acceptInvitation(invitation.id!); // le serveur crée l'amitié une seule fois et notifie l'expéditeur
      invitation.status = InvitationStatus.ACCEPTER.name;
      invitation.updatedAt = DateTime.now().millisecondsSinceEpoch;
      resp = true;
    } catch (e) {
      printVm(e);
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
    bool resp = false;
    try {
      await UsersApi.refuseInvitation(invitation.id!);
      invitation.status = InvitationStatus.REFUSER.name;
      invitation.updatedAt = DateTime.now().millisecondsSinceEpoch;
      resp = true;
    } catch (e) {
      printVm(e);
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
        'last_time_active': DateTime.now().millisecondsSinceEpoch,
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
