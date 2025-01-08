

import 'dart:io';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;





class UserShopAuthProvider extends ChangeNotifier {

  late String  registerText="";
  late String?  token;
  late String  loginText="";

  late UserShopData loginData=UserShopData();

  late String? error=null;
  initialisation(){
  //  registerUser=User();
  }




  Future<void> storeToken(String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', value);
    print('token saved : ${value}');
  }

  Future<void> isFirst(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first', value);
  }
  Future<String?> getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return  prefs.getString('token');
  }

  Future<bool?> getIfIsFirst() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    print('is_first:');

    return  prefs.getBool('is_first');
  }

  deleteToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

  }








  Future<bool> createUser(UserData data) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    String id = firestore
        .collection('UsersShop')
        .doc()
        .id;
    data.id=id;

    try{
      final DocumentReference<Map<String, dynamic>> docRef = FirebaseFirestore.instance.collection('UsersShop').doc(data.id);
      docRef.set(data.toJson());


      //  await firestore.collection('Matches').doc(id).set(data.toJson());
      print("///////////-- SAVE soccer data  --///////////////");
      return true;
    }catch(error){
      return false;

    }
  }

  Future<List<UserShopData>> getUserByPhone(String phone) async {
    late List<UserShopData> list= [];


    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('UsersShop');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where("phone",isEqualTo: phone!).get()
        .then((value){
      print("user by phone");

      print(value);      return value;
    }).catchError((onError){

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        UserShopData.fromJson(doc.data() as Map<String, dynamic>)).toList();


    return list;

  }

  Future<List<UserShopData>> getAllClient(String phone) async {
    late List<UserShopData> list= [];


    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('UsersShop');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where("phone",isNotEqualTo: phone!).get()
        .then((value){
      print("user by phone");

      print(value);      return value;
    }).catchError((onError){

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        UserShopData.fromJson(doc.data() as Map<String, dynamic>)).toList();


    return list;

  }

  Future<List<UserShopData>> getSearchClient(String nom,String phone) async {
    late List<UserShopData> list= [];
    late List<UserShopData> listClients= [];


    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('UsersShop');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where("phone",isNotEqualTo: phone!)

        .get()
        .then((value){
      print("user by phone");

      print(value);      return value;
    }).catchError((onError){

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        UserShopData.fromJson(doc.data() as Map<String, dynamic>)).toList();
    list.forEach((element) {
      if (element.nom!.toLowerCase().contains(nom.toLowerCase())) {
        listClients.add(element);
      }
    });


    return listClients;

  }

  Future<List<UserShopData>> getAfroshopUserById(String id) async {
    late List<UserShopData> list= [];


    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('UsersShop');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where("id",isEqualTo: id!).get()
        .then((value){
      print("user by phone");

      print(value);      return value;
    }).catchError((onError){

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        UserShopData.fromJson(doc.data() as Map<String, dynamic>)).toList();


    return list;

  }






}



