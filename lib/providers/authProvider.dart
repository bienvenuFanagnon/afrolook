import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'package:afrotok/models/model_data.dart';
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt_decrypt_plus/cipher/cipher.dart';
import 'package:flutter/cupertino.dart';

import 'package:image_picker/image_picker.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:openai_client/openai_client.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth/authService.dart';
import '../services/user/userService.dart';

class UserAuthProvider extends ChangeNotifier {
  late AuthService authService = AuthService();
  late List<UserPhoneNumber> listNumbers = [];
  late String registerText = "";
  late String? token = '';
  late int? userId = 0;
  late String loginText = "";
  late UserService userService = UserService();

  //List<Pays>? listPays=[];
  late UserData loginUserData2 = UserData();
  late UserData loginUserData = UserData();
  late UserData registerUser = UserData();
  late AppDefaultData appDefaultData = AppDefaultData();

  late List<UserGlobalTag> listUserGlobalTag = [];
  late List<String> listUserGlobalTagString = [];
  late List<UserPseudo> listPseudo = [];
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  initializeData() {
    registerUser = UserData();
  }

  Future<void> storeIsFirst(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirst', value);
  }

  Future<bool?> getIsFirst() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // token = prefs.getString('token');
    // print("get token : ${token}");
    //notifyListeners();
    return prefs.getBool('isFirst');
  }

  Future<void> storeToken(String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', value);
  }

  Future<String?> getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    // print("get token : ${token}");
    //notifyListeners();
    return prefs.getString('token');
  }

  Future<List<Invitation>> userInvitaionRecu() async {
    return loginUserData.mesInvitationsEnvoyer!;
  }

  deleteToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<List<Friends>> getUserFriends() async {
    // notifyListeners();
    return loginUserData.friends!;
  }


  Future<void> getAppData() async {
    appDefaultData = await authService.getAppData();
    // print("app data : ${appDefaultData.toJson()}");

  }

  Future<void> updateAppData(AppDefaultData appDefaultData) async {
    print("app data : ${appDefaultData!.toJson()}");

    await firestore.collection('AppData').doc(appDefaultData!.id).update(
        appDefaultData!.toJson());
  }

  Future<bool> register(UserData user, File imageFile) async {
    bool resp = false;
    registerText = "";
    if (await authService.register(user, imageFile)) {
      //registerText= ResponseText.registerSuccess;
      resp = true;
    } else {
      //registerText= ResponseText.registerErreur;
      resp = false;
    }
    notifyListeners();
    return resp;
  }

  Future<bool> getPseudo(String pseudo) async {
    listPseudo = [];
    bool isvalide = true;

    registerText = "";
    await authService.getPseudos().then(
          (value) {
        listPseudo = value;
        value.forEach((element) {
          if (pseudo == element.name) {
            isvalide = false;
            /*
            SnackBar snackBar = SnackBar(
              content: Text('le numéro existe déjà',style: TextStyle(color: Colors.red),),
            );
            ScaffoldMessenger.of(context).showSnackBar(snackBar);

             */
          }
        });
      },
    );

    notifyListeners();
    return isvalide;
  }

  Future<List<UserGlobalTag>> getUserGlobalTags() async {
    listUserGlobalTag = [];
    listUserGlobalTagString = [];
    bool isvalide = true;

    registerText = "";
    await authService.getUserGlobalTags().then(
          (value) {
        listUserGlobalTag = value;

        listUserGlobalTag.forEach((element) {
          listUserGlobalTagString.add(element.titre!);
        });
      },
    );

    notifyListeners();
    return listUserGlobalTag;
  }

  Future<bool> listNumber(String telephoneController) async {
    bool isvalide = true;
    listNumbers = [];

    registerText = "";
    await authService.listPhoneNumber().then(
          (value) {
        listNumbers = value;

        value.forEach((element) {
          if (telephoneController == element.completNumber) {
            isvalide = false;
            /*
            SnackBar snackBar = SnackBar(
              content: Text('le numéro existe déjà',style: TextStyle(color: Colors.red),),
            );
            ScaffoldMessenger.of(context).showSnackBar(snackBar);

             */
          }
        });
      },
    );

    notifyListeners();
    return isvalide;
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  Stream<List<NotificationData>> getListNotificationAuth() async* {
    var postStream = FirebaseFirestore.instance.collection('Notifications')

        .orderBy('created_at', descending: true)

        .snapshots();
    List<NotificationData> notifications = [];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {
      notifications = [];

      for (var post in snapshot.docs) {
        //  print("post : ${jsonDecode(post.toString())}");
        NotificationData notification = NotificationData.fromJson(post.data());
        // listConstposts=posts;

        if (!isIn(notification.users_id_view!, loginUserData.id!)) {
          notifications.add(notification);
        }
      }
      yield notifications;
    }
  }


  Future<bool> getUserByToken({required String token}) async {
    // loginUserData=User();

    bool resp = false;
    loginText = "";
    if (await authService.loginUserByToken(token: token)) {
      await getAppData();
      loginUserData = authService.loginUser;
      loginUserData.popularite =
          (loginUserData.abonnes! + loginUserData.likes! +
              loginUserData.jaimes!) /
              (appDefaultData.nbr_abonnes! + appDefaultData.nbr_likes! +
                  appDefaultData.nbr_loves!);
      loginUserData.compteTarif = loginUserData.popularite! * 80;
      await firestore.collection('Users').doc(loginUserData!.id).update(
          loginUserData!.toJson());
      var friendsStream = FirebaseFirestore.instance.collection('Friends');
      QuerySnapshot friendSnapshot = await friendsStream.where(Filter.or(
        Filter('current_user_id', isEqualTo: loginUserData.id!),
        Filter('friend_id', isEqualTo: loginUserData.id!),

      )).get();

      loginUserData.friends = friendSnapshot.docs.map((doc) =>
          Friends.fromJson(doc.data() as Map<String, dynamic>)).toList();

      resp = true;
    } else {
      resp = false;
    }
    notifyListeners();
    return resp;
  }

  Future<bool> getLoginUser(String id) async {
    await getAppData();
    late List<UserData> list = [];
    late bool haveData = false;

    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('Users');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where(
        "id", isEqualTo: id!).get()
        .then((value) {
      print(value);
      return value;
    }).catchError((onError) {

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

    if (list.isNotEmpty) {
      loginUserData = list.first;
      print("OneSignal=====");


      print("OneSignal id : ${OneSignal.User.pushSubscription.id}");
      print("OneSignal token : ${OneSignal.User.pushSubscription.token}");

      loginUserData.oneIgnalUserid = OneSignal.User.pushSubscription.id;

      loginUserData.popularite =
          (loginUserData.abonnes! + loginUserData.likes! +
              loginUserData.jaimes!) /
              (appDefaultData.nbr_abonnes! + appDefaultData.nbr_likes! +
                  appDefaultData.nbr_loves!);
      loginUserData.compteTarif = loginUserData.popularite! * 80;
      await firestore.collection('Users').doc(loginUserData!.id).update(
          loginUserData!.toJson());
      var friendsStream = FirebaseFirestore.instance.collection('Friends');
      QuerySnapshot friendSnapshot = await friendsStream.where(Filter.or(
        Filter('current_user_id', isEqualTo: loginUserData.id!),
        Filter('friend_id', isEqualTo: loginUserData.id!),

      )).get();

      loginUserData.friends = friendSnapshot.docs.map((doc) =>
          Friends.fromJson(doc.data() as Map<String, dynamic>)).toList();
      haveData = true;
    }


    return haveData;
  }
  Future<List<UserData>> getUserById(String id) async {
    //await getAppData();
    late List<UserData> list = [];
    late bool haveData = false;

    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('Users');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where(
        "id", isEqualTo: id!).get()
        .then((value) {
      print(value);
      return value;
    }).catchError((onError) {

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();



    return list;
  }

  Future<List<String>> getAllUsersOneSignaUserId() async {
    late List<UserData> list = [];

    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('Users');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.get().then((value) {
      return value;
    }).catchError((onError) {});

    // Get data from docs and convert map to List
    list = querySnapshot.docs
        .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
    late List<String> listOSUserid = [];

    for (UserData u in list) {
      if (u.oneIgnalUserid!=null&&u.oneIgnalUserid!.length>5) {
        listOSUserid.add(u.oneIgnalUserid!);
        print("onesignaluser size : ${listOSUserid.length}");

      }
    }

    return listOSUserid;
  }


  Future<bool> getUserByPhone(String phone) async {
    //   await getAppData();
    late List<UserData> list = [];
    late bool haveData = false;

    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('Users');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where(
        "numero_de_telephone", isEqualTo: phone!).get()
        .then((value) {
      print(value);
      return value;
    }).catchError((onError) {

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

    if (list.isNotEmpty) {
      loginUserData = list.first;

      haveData = true;
    }


    return haveData;
  }

  Future<List<UserIACompte>> getUserIa(String user_id) async {
    //   await getAppData();
    late List<UserIACompte> list = [];
    late bool haveData = false;

    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('User_Ia_Compte');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where(
        "userId", isEqualTo: user_id!).get()
        .then((value) {
      print(value);
      return value;
    }).catchError((onError) {

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        UserIACompte.fromJson(doc.data() as Map<String, dynamic>)).toList();

    if (list.isNotEmpty) {
      return list;
    } else {
      return [];
    }
  }

  Future<bool> createUserIaCompte(UserIACompte iaCompte) async {
    try {
      String cmtId = FirebaseFirestore.instance
          .collection('User_Ia_Compte')
          .doc()
          .id;

      iaCompte.id = cmtId;
      await FirebaseFirestore.instance
          .collection('User_Ia_Compte')
          .doc(cmtId)
          .set(iaCompte.toJson());
      notifyListeners();
      return true;
    } catch (e) {
      print("erreur comment : ${e}");
      return false;
    }
  }
  String encrypt(String pwd){
    Cipher cipher = Cipher(secretKey: "afroshop_secret_key.com");
    String encryptTxt = cipher.xorEncode("${pwd}");
    print("password");
    print(encryptTxt);
    return encryptTxt;
  }
  String decrypt(String pwd_crypted){
    Cipher cipher = Cipher(secretKey: "afroshop_secret_key.com");

    String decryptTxt = cipher.xorDecode(pwd_crypted);
   // print(encryptTxt);
    print(decryptTxt);
    return decryptTxt;
  }


  Future<bool> getCurrentUser(String currentUserId) async {
    await getAppData();
    //listUsers = [];
    bool hasData = false;


    await userService.getUserData(userId: currentUserId).then((value) async {
      loginUserData = value;
      loginUserData.popularite =
          (loginUserData.abonnes! + loginUserData.likes! +
              loginUserData.jaimes!) /
              (appDefaultData.nbr_abonnes! + appDefaultData.nbr_likes! +
                  appDefaultData.nbr_loves!);
      loginUserData.compteTarif = loginUserData.popularite! * 80;
      await firestore.collection('Users').doc(loginUserData!.id).update(
          loginUserData!.toJson());
      var friendsStream = FirebaseFirestore.instance.collection('Friends');
      QuerySnapshot friendSnapshot = await friendsStream.where(Filter.or(
        Filter('current_user_id', isEqualTo: loginUserData.id!),
        Filter('friend_id', isEqualTo: loginUserData.id!),

      )).get();

      loginUserData.friends = friendSnapshot.docs.map((doc) =>
          Friends.fromJson(doc.data() as Map<String, dynamic>)).toList();
      hasData = true;
    },);


    notifyListeners();
    return hasData;
  }

  // Create the configuration


// Create a new client
  String oneSignalUrl = 'https://api.onesignal.com/notifications';
  String applogo =
      "https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/logoapp%2Fafrolook_logo.png?alt=media&token=dae50f81-4ea1-489f-86f3-e08766654980";
  String oneSignalAppId =
      'b1b8e6b8-b9f4-4c48-b5ac-6ccae1423c98'; // Replace with your app ID
  String oneSignalAuthorization =
      'YjEwNmY0MGQtODFhYi00ODBkLWIzZjgtZTVlYTFkMjQxZDA0'; // Replace with your authorization key

  // CHANGE THIS parameter to true if you want to test GDPR privacy consent
  Future<void> sendNotification(List<String> userIds, String message, String smallImage) async {
    print(
        'state current user data  ================================================');
    print("urlimage ; ${smallImage}");

    print(OneSignal.User.pushSubscription.id);

    final body = {
      'contents': {'en': message},
      'app_id': oneSignalAppId,

      "include_player_ids":
      // "include_subscription_ids":
      userIds, //tokenIdList Is the List of All the Token Id to to Whom notification must be sent.

      // android_accent_color reprsent the color of the heading text in the notifiction
      "android_accent_color": "FF9976D2",

      "small_icon":smallImage.length>5?smallImage: applogo,

      "large_icon": smallImage.length>5?smallImage: applogo,

      "headings": {"en": "Afrolook"},
      //"included_segments": ["Active Users", "Inactive Users"],
      "data": {"foo": "bar"},
      'name': 'Afrolook',
    };

    final response = await http.post(
      Uri.parse(oneSignalUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': "Basic $oneSignalAuthorization",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully!');
      print('sending notification: ${response.body}');
    } else {
      print('Error sending notification: ${response.statusCode}');
      print('Error sending notification: ${response.body}');
    }
  }
}
