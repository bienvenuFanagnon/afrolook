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

import '../../pages/component/consoleWidget.dart';


class AuthService {
  late UserData loginUser2=UserData();
  late UserData loginUser=UserData();
  late List<UserPhoneNumber> listNumber = [];
  late List<UserPseudo> listPseudo = [];
  late List<UserGlobalTag> listUserGlobalTag = [];
  late int codeError=0;


  Future<AppDefaultData> getAppData() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    // ID statique du document
    const String staticId = "XgkSxKc10vWsJJ2uBraT";
    final DocumentReference docRef = firestore.collection('AppData').doc(staticId);

    AppDefaultData appData = AppDefaultData();

    try {
      // Vérifier si le document existe
      DocumentSnapshot snapshot = await docRef.get();

      if (snapshot.exists) {
        // Si trouvé → on récupère
        appData = AppDefaultData.fromJson(snapshot.data() as Map<String, dynamic>);
        appData.id = snapshot.id;
      } else {
        // Sinon → on crée avec l’ID statique
        appData.id = staticId;
        await docRef.set(appData.toJson());
        printVm("Nouveau AppData créé avec l’ID statique : $staticId");
      }
    } catch (e) {
      printVm("Erreur lors de la récupération ou création du document : $e");
    }

    return appData;
  }


  Future<AppDefaultData> getAppData1() async {

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
        printVm("La collection est vide");
        await firestore.collection('AppData').doc(appData.id).set(appData.toJson()).then((value) {
          printVm('new app data');
        },);


      }
    } catch (e) {
      printVm("Erreur lors de la récupération du premier document : $e");

    }
   return appData;

  }



}