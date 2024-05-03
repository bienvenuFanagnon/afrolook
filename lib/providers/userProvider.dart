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
  List<Information> listInfos = [];
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
      //print("user update : ${user!.toJson()}");
      return true;
    }catch(e){
      print("erreur update post : ${e}");
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
      print("erreur update post : ${e}");
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
  Future<List<Information>> getAllInfos() async {


    listInfos =[];

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Informations');
    QuerySnapshot querySnapshotPost = await postCollect

        .where("type",isEqualTo:'${InfoType.APPINFO.name}')
        .where("status",isEqualTo:'${PostStatus.VALIDE.name}')
        .orderBy('created_at', descending: true)
        .get();

    listInfos = querySnapshotPost.docs.map((doc) =>
        Information.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();



    return listInfos;

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
      print("nombre de jour: ${daysSinceEpoch}");

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


    listInfos =[];

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Informations');
    QuerySnapshot querySnapshotPost = await postCollect

    .where("type",isEqualTo:'${InfoType.GRATUIT.name}')
        .where("status",isEqualTo:'${PostStatus.VALIDE.name}')
        .orderBy('created_at', descending: true)
        .get();

    listInfos = querySnapshotPost.docs.map((doc) =>
        Information.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();



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



      listUserAnnonces=listUsers;
      print('list users ${listUsers.length}');
      hasData=true;

    }catch(e){
      print("erreur ${e}");
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




      print('list users ${listUsers.length}');
      hasData=true;

    }catch(e){
      print("erreur ${e}");
      hasData=false;
    }



    //notifyListeners();
    return hasData;
  }

  Future<List<UserData>> getAllUsers() async {

    listAllUsers = [];
    bool hasData=false;
    try{
      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Users');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect
      // .where("id",isNotEqualTo: currentUserId)
          .orderBy('point_contribution', descending: true)
          .limit(10)
          .get();

      // Afficher la liste
      listAllUsers = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();





      print('list users ${listAllUsers.length}');
      hasData=true;
      return listAllUsers;
    }catch(e){
      print("erreur ${e}");
      hasData=false;
      return [];
    }

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
      QuerySnapshot querySnapshotUser = await userCollect
         //.where("id",isNotEqualTo: currentUserId)
     //  .where("id",isNotEqualTo: currentUserId)
        //  .orderBy('pseudo').startAt([Random().nextDouble()])
      .orderBy('createdAt', descending: true)
        //  .where('id', whereIn: alphabet)
          .limit(limit)
          .get();

      // Afficher la liste
      listUsers = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();


      listUsers.shuffle();
      listUsers.shuffle();



      print('list users ${listUsers.length}');
      hasData=true;

    }catch(e){
      print("erreur ${e}");
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
        //print(doc.data());
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

      print(e);
      resp=false;
    }

    notifyListeners();
    return resp;
  }
  Future<bool> refuserInvitation(Invitation invitation) async {

    bool resp=false;

    try {
      invitation.status=InvitationStatus.REFUSER.name;

      await  firestore.collection('Invitations').doc(invitation.id).update(invitation.toJson());


      resp=true;
    } catch (e) {

      print(e);
      resp=false;
    }

    notifyListeners();
    return resp;
  }

  Future<bool> changeState({required UserData user,required String state}) async {

    bool resp=false;

    try {
      user.state=state;
      print('update user state: $state');

      await firestore.collection('Users').doc(user.id).update(user.toJson());


      resp=true;
    } catch (e) {

      print(e);
      resp=false;
    }

    notifyListeners();
    return resp;
  }

}
