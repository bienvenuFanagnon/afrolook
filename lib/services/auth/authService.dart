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


class AuthService {
  late UserData loginUser2=UserData();
  late UserData loginUser=UserData();
  late List<UserPhoneNumber> listNumber = [];
  late List<UserPseudo> listPseudo = [];
  late List<UserGlobalTag> listUserGlobalTag = [];
  late int codeError=0;


  Future<bool> loginUserByToken({required String token})async{
    print("le token sender: ${token}");
    try {
      final response = await http.post(
        Uri.parse('${ApiConstantData.onlyUserByToken}'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'user_token': token
        } ),

      );
      print("token code ${response.statusCode}");
      print("token user data ${jsonDecode(response.body)}");
      //print("token user ${jsonDecode(response.body)['user']}");

      if (response.statusCode == 200|| response.statusCode == 201){
        loginUser=UserData();
        // Succès, le compte a été créé
        print('userId');
        loginUser= UserData.fromJson(jsonDecode(response.body)['0']);
        //print('userIde : ${loginUser.id}');

        return true;
      } else {

        return false;
      }
    } catch (e) {
      print("erreur ${e}");
      return false;
    }

  }

  Future<bool> login({required String telephone, required String password})async{
    //error=null;
    try {
      final response = await http.post(
        Uri.parse(ApiConstantData.login),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'numero_de_telephone': telephone,
          'password': password,
        }),
      );
      codeError=response.statusCode;
      print("code ${response.statusCode}");
      print("login user data ${jsonDecode(response.body)}");

      if (response.statusCode == 200|| response.statusCode == 201){
        loginUser=UserData();
        // Succès, le compte a été créé

        loginUser= UserData.fromJson(jsonDecode(response.body)['user']);

        String token = jsonDecode(response.body)['access_token'];
        print("token ${jsonDecode(response.body)['access_token']}");
        //loginUser.token=token;


        // Obtenez les SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        //error=null;
        // Enregistrez le token d'authentification
        //prefs.setString('${ApiConstantData.token}', token);
        prefs.setString('token', token);

        return true;



      } else {
        // Gérer les erreurs en fonction du code de statut
        //error = "Erreur lors de la création du compte";
        return false;
      }
    } catch (e) {
      // Erreur de connexion
     // error = "Erreur de connexion: $e";
      print("code ${codeError}");
      print("erreur ${e}");
      return false;
    }

  }
  Future<List<UserPseudo>> getPseudos()async{
    //error=null;
    listPseudo = [];
    try {
      final response = await http.get(
        Uri.parse(ApiConstantData.listPseudo),
        headers: {"Content-Type": "application/json"},
      );


      if (response.statusCode == 200|| response.statusCode == 201){
        List pseudos = jsonDecode(response.body)['0'] as List;
        listPseudo =  pseudos.map((objet) => UserPseudo.fromJson(objet)).toList();




        return listPseudo;



      } else {
        // Gérer les erreurs en fonction du code de statut
        //error = "Erreur lors de la création du compte";
        return [];
      }
    } catch (e) {
      print("erreur ${e}");
      // Erreur de connexion
      // error = "Erreur de connexion: $e";
      return [];
    }

  }

  Future<List<UserGlobalTag>> getUserGlobalTags()async{
    //error=null;
    listUserGlobalTag = [];
    try {
      final response = await http.get(
        Uri.parse(ApiConstantData.lisUserTags),
        headers: {"Content-Type": "application/json"},
      );
      print("code ${response.statusCode}");
     // print("login tags data ${jsonDecode(response.body)['0']}");

      if (response.statusCode == 200|| response.statusCode == 201){
        List list = jsonDecode(response.body)['0'] as List;
        listUserGlobalTag =  list.map((objet) => UserGlobalTag.fromJson(objet)).toList();
        //print("login tags ${listUserGlobalTag.first.titre}");



        return listUserGlobalTag;



      } else {
        // Gérer les erreurs en fonction du code de statut
        //error = "Erreur lors de la création du compte";
        return [];
      }
    } catch (e) {
      print("erreur ${e}");
      // Erreur de connexion
      // error = "Erreur de connexion: $e";
      return [];
    }

  }

  Future<List<UserPhoneNumber>> listPhoneNumber()async{
    //error=null;
    listNumber = [];
    try {
      final response = await http.get(
        Uri.parse(ApiConstantData.listNumber),
        headers: {"Content-Type": "application/json"},
      );
      print("code ${response.statusCode}");
      //print("login phone data ${jsonDecode(response.body)['0']}");

      if (response.statusCode == 200|| response.statusCode == 201){
       List Numbers = jsonDecode(response.body)['0'] as List;
       listNumber =  Numbers.map((number) => UserPhoneNumber.fromJson(number)).toList();
        ///print("login phone number ${listNumber.first.completNumber}");



        return listNumber;



      } else {
        // Gérer les erreurs en fonction du code de statut
        //error = "Erreur lors de la création du compte";
        return [];
      }
    } catch (e) {
      print("erreur ${e}");
      // Erreur de connexion
      // error = "Erreur de connexion: $e";
      return [];
    }

  }
  Future<bool> register(UserData user,File imageFile)async{



    try {
      Dio dio = Dio();


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
        //'genre_id': user.genreId,
        //'role_id': user.roleId,
       // 'user_global_tags': user.userGlobalTags!,

      });
      user.userGlobalTags!.forEach((element) {
        formData.fields.add(MapEntry("user_global_tags[]", element.toString()));
      });

      formData.files.add(MapEntry('image', await MultipartFile.fromFile(imageFile.path)));
     // formData.fields.add(json.decode(json.encode(user.toJson())));

      // Envoyez les données à l'API
      //Response response = await dio.post(apiUrl, data: formData);
    //  final response3 = await request.send();
      final response = await dio.post(ApiConstantData.register, data: formData);

     // print("donnee envoyer : ${user.toJson()}");
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


  Future<AppDefaultData> getAppData() async {

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference collection =
    FirebaseFirestore.instance.collection('AppData');
    AppDefaultData appData=AppDefaultData();
    try {
      // Obtenir les documents de la collection
      QuerySnapshot querySnapshot = await collection.get();

      // Vérifier s'il y a des documents
      if (querySnapshot.docs.isNotEmpty) {
        // Récupérer le premier document
        DocumentSnapshot premierDocument = querySnapshot.docs.first;
appData=AppDefaultData.fromJson(premierDocument.data() as Map<String, dynamic>);

      } else {
        AppDefaultData appData=AppDefaultData();
        String id = firestore
            .collection('AppData')
            .doc()
            .id;
        appData.id =id;
        print("La collection est vide");
        await firestore.collection('AppData').doc(appData.id).set(appData.toJson()).then((value) {
          print('new app data');
        },);


      }
    } catch (e) {
      print("Erreur lors de la récupération du premier document : $e");

    }
   return appData;

  }



}