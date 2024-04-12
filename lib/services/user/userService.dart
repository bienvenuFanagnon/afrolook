import 'dart:io';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/chatmodels/message.dart';



class UserService {

  late List<UserData> listUser = [];
  late Chat chat = Chat();
  late int countFriends=0;

  late List<Message> listMessage = [];
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Future<List<UserData>> getUsers(
      {required String userId}) async {
    //error=null;
    listUser = [];
    try {

      // Obtenir la liste des utilisateurs
      final users = FirebaseFirestore.instance.collection('Users').where('id', isNotEqualTo: userId).get();

      // Afficher la liste
      users.then((snapshot) {
        snapshot.docs.forEach((doc) {
          print(doc.data());
          listUser.add(  UserData.fromJson(doc.data() as Map<String, dynamic>))
        ;
        });
      });



        return listUser;

    } catch (e) {
      // Erreur de connexion
      // error = "Erreur de connexion: $e";
      print("erreur ${e}");
      return [];
    }
  }

  Future<UserData> getUserData(
      {required String userId}) async {
    //error=null;
    UserData userData=UserData();
    try {

      //  utilisateurs connecte

      CollectionReference userCollect =
      FirebaseFirestore.instance.collection('Users');
      // Get docs from collection reference
      QuerySnapshot querySnapshotUser = await userCollect.where("id",isEqualTo: userId!).get();
      // Afficher la liste
      List<UserData> userList = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
    userData=userList.first;

      ///////mes invitation/////
      CollectionReference collectionRef =
      FirebaseFirestore.instance.collection('Invitations');
      // Get docs from collection reference
      QuerySnapshot querySnapshotInv = await collectionRef.where("sender_id",isEqualTo: userId!).get();

      List<Invitation> inviteList = querySnapshotInv.docs.map((doc) =>
          Invitation.fromJson(doc.data() as Map<String, dynamic>)).toList();
      userData.mesInvitationsEnvoyer=inviteList;

      ///////autre invitation/////
      CollectionReference collectionRefAutreInv =
      FirebaseFirestore.instance.collection('Invitations');
      // Get docs from collection reference
      QuerySnapshot querySnapshotAutreInv = await collectionRefAutreInv.where("receiver_id",isEqualTo: userId!).get();

      List<Invitation> autreinviteList = querySnapshotInv.docs.map((doc) =>
          Invitation.fromJson(doc.data() as Map<String, dynamic>)).toList();
      userData.autreInvitationsEnvoyer=autreinviteList;

      //////////abonnement////////////////

      CollectionReference userCollectAbonnes =
      FirebaseFirestore.instance.collection('Abonnements');
      // Get docs from collection reference
      QuerySnapshot querySnapshotAbone = await userCollectAbonnes.where("compte_user_id",isEqualTo: userId).get();
      // Afficher la liste
      List<UserAbonnes> userListAbonnes = querySnapshotAbone.docs.map((doc) =>
          UserAbonnes.fromJson(doc.data() as Map<String, dynamic>)).toList();

      userData.userAbonnes=userListAbonnes;




      return userData;

    } catch (e) {
      // Erreur de connexion
      // error = "Erreur de connexion: $e";
      print("erreur ${e}");
      return UserData();
    }
  }


  Future<List<Message>> getMessageByChat(
      {required int chatId}) async {
    //error=null;
    try {
      final response = await http.post(
        Uri.parse(ApiConstantData.listUserInvitation),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'chat_id': chatId,
        }),
      );
      print("code ${response.statusCode}");
    //  print("list message data ${jsonDecode(response.body)['0']}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        listMessage = [];
        List m = jsonDecode(response.body)['0'] as List;
        listMessage =  m.map((ms) => Message.fromJson(ms)).toList();



        return listMessage;
      } else {
        // Gérer les erreurs en fonction du code de statut
        //error = "Erreur lors de la création du compte";
        return [];
      }
    } catch (e) {
      // Erreur de connexion
      // error = "Erreur de connexion: $e";
      print("erreur ${e}");
      return [];
    }
  }

  Future<bool> abonne({required String compte_user_id, required String abonne_user_id})async{
    //error=null;
    try {
      final response = await http.post(
        Uri.parse(ApiConstantData.abonner),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'compte_user_id': compte_user_id,
          'abonne_user_id': abonne_user_id,
        }),
      );
      print("code ${response.statusCode}");
      //print("abonnee user data ${jsonDecode(response.body)}");

      if (response.statusCode == 200|| response.statusCode == 201){


        return true;



      } else {
        // Gérer les erreurs en fonction du code de statut
        //error = "Erreur lors de la création du compte";
        return false;
      }
    } catch (e) {
      // Erreur de connexion
      // error = "Erreur de connexion: $e";
      print("erreur ${e}");
      return false;
    }

  }
  Future<bool> sendInvitation({required String receiver_id, required String sender_id})async{
    //error=null;
    try {
      final response = await http.post(
        Uri.parse(ApiConstantData.newInvitation),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'receiver_id': receiver_id,
          'sender_id': sender_id,
        }),
      );
      print("code ${response.statusCode}");
     // print("invitation user data ${jsonDecode(response.body)}");

      if (response.statusCode == 200|| response.statusCode == 201){


        return true;



      } else {
        // Gérer les erreurs en fonction du code de statut
        //error = "Erreur lors de la création du compte";
        return false;
      }
    } catch (e) {
      // Erreur de connexion
      // error = "Erreur de connexion: $e";
      print("erreur ${e}");
      return false;
    }

  }



  Future<bool> acceptInvitation({required String invitation_id, required String user_accepter_id})async{
    //error=null;
    try {
      final response = await http.post(
        Uri.parse(ApiConstantData.acceptInvitation),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'invitation_id': invitation_id,
          'user_accepter_id': user_accepter_id,
        }),
      );
      print("code ${response.statusCode}");
     // print("invitation user data ${jsonDecode(response.body)}");

      if (response.statusCode == 200|| response.statusCode == 201){


        return true;



      } else {
        // Gérer les erreurs en fonction du code de statut
        //error = "Erreur lors de la création du compte";
        return false;
      }
    } catch (e) {
      // Erreur de connexion
      // error = "Erreur de connexion: $e";
      print("erreur ${e}");
      return false;
    }

  }



  Future<bool> sendSimpleMessage({required Message message,required String receiver_id,required String sender_id})async{



    try {
      Dio dio = Dio();


      FormData formData = FormData.fromMap(message.toJson());
      print("donnee envoyer : ${message.toJson()}");
      //formData.fields.add(MapEntry('send_by', 'sender_id'));
      formData.fields.add(MapEntry('receiver_id', receiver_id.toString()));
     // formData.fields.add(MapEntry('sendBy', sender_id.toString()));
      //formData.fields. set('key_to_modify', 'new_value');
      print("formData donnee envoyer : ${formData.fields}");
      final response = await dio.post(ApiConstantData.newMessage, data: formData);


      print("code ${response.statusCode}");
      // print("data create ${jsonDecode(response.data)}");

      if (response.statusCode == 200|| response.statusCode == 201){
        // Succès, le compte a été créé
        //user= User.fromJson(jsonDecode(response.body));

        return true;
      } else {
        print("Erreur lors de la création du compte code ${response.statusCode}");
        // Gérer les erreurs en fonction du code de statut
        return false;
      }
    } on DioError catch ( e) {
      // Erreur de connexion
      //  error = "Erreur de connexion: $e";
      print("erreur ${e.message}");
      return false;
    }

  }
  Future<bool> sendFileMessage({required Message message, required File file,required int receiver_id})async{



    try {
      Dio dio = Dio();

      FormData formData = FormData.fromMap({
        "message": message.message,
        "send_by": message.sendBy,
        "receiver_id": receiver_id,
        "reply_message":message.replyMessage.toJson(),
        "reaction": message.reaction.toJson(),
        "message_type": message.messageType,
        "voice_message_duration": message.voiceMessageDuration,
        "status": message.status
      });
      /*
      FormData formData = FormData.fromMap({
        'pseudo': user.pseudo,
        'nom': user.nom,
        'prenom': user.prenom,
        'numero_de_telephone': user.numeroDeTelephone,
        'adresse': user.adresse,
        'code_parrainage': user.codeParrainage,
        'user_pays':{
          "name": user.userPays!.name,
          "place_name": user.userPays!.placeName,
          "subAdministrativeArea": user.userPays!.subAdministrativeArea!,
        },
        'latitude': user.latitude,
        'longitude': user.longitude,
        'apropos': user.apropos,
        'password': user.password,
        'genre_id': user.genreId,
        'role_id': user.roleId,
        // 'user_global_tags': user.userGlobalTags!,

      });
      user.userGlobalTags!.forEach((element) {
        formData.fields.add(MapEntry("user_global_tags[]", element.toString()));
      });

       */

      formData.files.add(MapEntry('message', await MultipartFile.fromFile(file.path)));
      // formData.fields.add(json.decode(json.encode(user.toJson())));

      // Envoyez les données à l'API
      //Response response = await dio.post(apiUrl, data: formData);
      //  final response3 = await request.send();
      final response = await dio.post(ApiConstantData.register, data: formData);

      print("donnee envoyer : ${message.toJson()}");
      print("code ${response.statusCode}");
      // print("data create ${jsonDecode(response.data)}");

      if (response.statusCode == 200|| response.statusCode == 201){
        // Succès, le compte a été créé
        //user= User.fromJson(jsonDecode(response.body));

        return true;
      } else {
        print("Erreur lors de la création du compte code ${response.statusCode}");
        // Gérer les erreurs en fonction du code de statut
        return false;
      }
    } on DioError catch ( e) {
      // Erreur de connexion
      //  error = "Erreur de connexion: $e";
      print("erreur ${e.message}");
      return false;
    }

  }
}