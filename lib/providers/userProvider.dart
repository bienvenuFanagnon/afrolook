import 'dart:io';
import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/admin_complements_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
import 'package:afrotok/services/api/shop_api.dart';
import 'package:afrotok/services/user/userService.dart';
// Firestore conservé ici uniquement pour les MESSAGES et le document de chat (getStreamChat, updateMessage) : décision du propriétaire.
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
    // Les entreprises sont modifiées par le serveur (module boutique : PATCH /shop/businesses/{id}) ; rien à écrire ici.
    return true;
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

  bool _hasMore = true;
  bool get hasMore => _hasMore;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Dernière erreur de chargement des informations (message en français) ; null si tout va bien. L'écran propose « Réessayer ».
  String? infosError;
  int _infosPage = 0;
  final Set<String> _likedInfoIds = {};

  /// Informations de l'application (API : GET /infos). `loadMore` : page suivante. Ordre décidé par le serveur
  /// (mises en avant d'abord, puis les plus récentes).
  Future<List<Information>> getAllInfos({bool loadMore = false, int limit = 5}) async {
    if (_isLoading) return _listInfos;

    _isLoading = true;
    infosError = null;
    if (!loadMore) {
      _infosPage = 0;
      _hasMore = true;
    }
    notifyListeners();

    try {
      final r = await AdminComplementsApi.infos(type: 'APPINFO', page: _infosPage + 1, limit: limit);
      final fresh = r.items.map(Information.fromJson).toList();
      for (final m in r.items) {
        final id = '${m['id']}';
        m['is_liked'] == true ? _likedInfoIds.add(id) : _likedInfoIds.remove(id);
      }
      _infosPage += 1;
      _listInfos = loadMore ? [..._listInfos, ...fresh] : fresh;
      _hasMore = r.hasMore;
    } catch (e) {
      infosError = AdminComplementsApi.message(e);
      printVm('Error loading infos: $e');
    }

    _isLoading = false;
    notifyListeners();
    return _listInfos;
  }

  Future<void> incrementViews(String infoId) async {
    try {
      await AdminComplementsApi.viewInfo(infoId);
    } catch (e) {
      printVm('Error incrementing views: $e');
    }
  }

  /// Bascule le j'aime (le serveur compte une seule fois par personne). Lève l'erreur pour que l'écran l'annonce.
  Future<void> toggleLike(String infoId, String userId) async {
    final liked = !_likedInfoIds.contains(infoId);
    final likes = await AdminComplementsApi.setInfoLike(infoId, liked);
    liked ? _likedInfoIds.add(infoId) : _likedInfoIds.remove(infoId);
    final i = _listInfos.indexWhere((x) => x.id == infoId);
    if (i >= 0) _listInfos[i].likes = likes;
  }

  Future<bool> isLiked(String infoId, String userId) async => _likedInfoIds.contains(infoId);

  // Fonctions admin (droit « content.moderate » : sinon le serveur répond « introuvable »)
  Future<void> deleteInfo(String infoId) async {
    await AdminComplementsApi.deleteInfo(infoId);
    _listInfos.removeWhere((info) => info.id == infoId);
    notifyListeners();
  }

  Future<void> toggleFeatured(String infoId, bool featured) async {
    await AdminComplementsApi.setInfoFeatured(infoId, featured);
    await getAllInfos();
  }

  void resetPagination() {
    _infosPage = 0;
    _hasMore = true;
    _isLoading = false;
  }

  /// Annonces valides (API : GET /annonces) : le serveur compte une vue par lecture et retire celles dont la durée est dépassée.
  Future<List<Annonce>> getAllAnnonces() async {
    try {
      listAnnonces = (await AdminComplementsApi.annonces()).map(Annonce.fromJson).toList();
    } catch (e) {
      printVm('Error loading annonces: $e');
      listAnnonces = [];
    }
    return listAnnonces;
  }

  /// Informations gratuites (API : GET /infos?type=GRATUIT). Retourne la liste affichée par les écrans qui l'utilisaient.
  Future<List<Information>> getGratuitInfos() async {
    try {
      return (await AdminComplementsApi.infos(type: 'GRATUIT', limit: 50)).items.map(Information.fromJson).toList();
    } catch (e) {
      printVm('Error loading infos gratuites: $e');
      return [];
    }
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
    // Entreprise de la personne (API boutique). La liste ne sait filtrer que « les miennes » : pour un autre compte, voir lacunes.
    try {
      final list = await ShopApi.businesses(mine: true);
      final found = list.where((e) => e.userId == userId).toList();
      if (found.isNotEmpty) {
        found.first.suivi = found.first.usersSuiviId?.length ?? found.first.suivi ?? 0;
        entrepriseData = found.first;
        return true;
      }
    } catch (e) {
      printVm('erreur entreprise : $e');
    }
    return false;
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
    // La présence est écrite par le service de présence Firebase ; ici seul l'état local est tenu à jour.
    user.state = state;
    notifyListeners();
    return true;
  }

}
