import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';

/// Compte « boutique » (ancien système UsersShop). L'API n'a pas de comptes boutique séparés : les entreprises de l'API
/// (`/shop/businesses`) les remplacent. Il ne reste ici que le stockage local du jeton et du premier lancement ; les recherches de
/// clients boutique renvoient des listes vides (voir lacunes_api_argent_creations.md).
class UserShopAuthProvider extends ChangeNotifier {
  late String registerText = "";
  late String? token;
  late String loginText = "";

  late UserShopData loginData = UserShopData();

  late String? error = null;
  initialisation() {}

  Future<void> storeToken(String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', value);
    printVm('token saved : ${value}');
  }

  Future<void> isFirst(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first', value);
  }

  Future<String?> getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<bool?> getIfIsFirst() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_first');
  }

  deleteToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<bool> createUser(UserData data) async => false;

  Future<List<UserShopData>> getUserByPhone(String phone) async => [];

  Future<List<UserShopData>> getAllClient(String phone) async => [];

  Future<List<UserShopData>> getSearchClient(String nom, String phone) async => [];

  Future<List<UserShopData>> getAfroshopUserById(String id) async => [];
}
