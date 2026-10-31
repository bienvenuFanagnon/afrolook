import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
import 'dart:io';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/chatmodels/message.dart';
import '../../pages/component/consoleWidget.dart';



class UserService {

  late List<UserData> listUser = [];
  late Chat chat = Chat();
  late int countFriends=0;

  late List<Message> listMessage = [];
  /// Liste de personnes : l'API n'a pas (encore) de liste générale ; voir lacunes_api_utilisateurs.md (recherche).
  Future<List<UserData>> getUsers({required String userId}) async => [];

  /// Profil public d'une personne (API : GET /v1/users/{id}).
  Future<UserData> getUserData({required String userId}) async {
    try {
      return userFromApi(await UsersApi.publicProfile(userId));
    } catch (e) {
      printVm("erreur ${e}");
      return UserData();
    }
  }

  /// Recherche par numéro de téléphone : non fournie par l'API (voir lacunes_api_utilisateurs.md). Renvoie un profil vide.
  Future<UserData> getUserDataByPhone({required String phone}) async => UserData();

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
      printVm("code ${response.statusCode}");
    //  printVm("list message data ${jsonDecode(response.body)['0']}");

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
      printVm("erreur ${e}");
      return [];
    }
  }

  Future<bool> abonne({required String compte_user_id, required String abonne_user_id}) async {
    try {
      await UsersApi.follow(compte_user_id);
      return true;
    } catch (e) {
      printVm("erreur ${e}");
      return false;
    }
  }


  Future<bool> sendInvitation({required String receiver_id, required String sender_id}) async {
    try {
      await UsersApi.invite(receiver_id);
      return true;
    } catch (e) {
      printVm("erreur ${e}");
      return false;
    }
  }


  Future<bool> acceptInvitation({required String invitation_id, required String user_accepter_id}) async {
    try {
      await UsersApi.acceptInvitation(invitation_id);
      return true;
    } catch (e) {
      printVm("erreur ${e}");
      return false;
    }
  }


  Future<bool> sendSimpleMessage({required Message message,required String receiver_id,required String sender_id})async{



    try {
      Dio dio = Dio();


      FormData formData = FormData.fromMap(message.toJson());
      printVm("donnee envoyer : ${message.toJson()}");
      //formData.fields.add(MapEntry('send_by', 'sender_id'));
      formData.fields.add(MapEntry('receiver_id', receiver_id.toString()));
     // formData.fields.add(MapEntry('sendBy', sender_id.toString()));
      //formData.fields. set('key_to_modify', 'new_value');
      printVm("formData donnee envoyer : ${formData.fields}");
      final response = await dio.post(ApiConstantData.newMessage, data: formData);


      printVm("code ${response.statusCode}");
      // printVm("data create ${jsonDecode(response.data)}");

      if (response.statusCode == 200|| response.statusCode == 201){
        // Succès, le compte a été créé
        //user= User.fromJson(jsonDecode(response.body));

        return true;
      } else {
        printVm("Erreur lors de la création du compte code ${response.statusCode}");
        // Gérer les erreurs en fonction du code de statut
        return false;
      }
    } on DioError catch ( e) {
      // Erreur de connexion
      //  error = "Erreur de connexion: $e";
      printVm("erreur ${e.message}");
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

      printVm("donnee envoyer : ${message.toJson()}");
      printVm("code ${response.statusCode}");
      // printVm("data create ${jsonDecode(response.data)}");

      if (response.statusCode == 200|| response.statusCode == 201){
        // Succès, le compte a été créé
        //user= User.fromJson(jsonDecode(response.body));

        return true;
      } else {
        printVm("Erreur lors de la création du compte code ${response.statusCode}");
        // Gérer les erreurs en fonction du code de statut
        return false;
      }
    } on DioError catch ( e) {
      // Erreur de connexion
      //  error = "Erreur de connexion: $e";
      printVm("erreur ${e.message}");
      return false;
    }

  }
}