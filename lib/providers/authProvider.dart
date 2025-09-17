import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:afrotok/models/chatmodels/message.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:deeplynks/deeplynks_service.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import 'package:image_picker/image_picker.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pages/component/consoleWidget.dart';
import '../pages/story/afroStory/repository.dart';
import '../services/auth/authService.dart';
import '../services/user/userService.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class UserAuthProvider extends ChangeNotifier {
  late AuthService authService = AuthService();
  late List<UserPhoneNumber> listNumbers = [];
  late String registerText = "";
  late String? token = '';
  late String? cinetPayToken = '102325650865f879a7b10492.83921456';
  late String? transfertApiPasswordToken = 'Bbienvenu@_4';
  late String? transfertGeneratePayToken = '';
  late String? cinetSiteId = '5870078';
  late int? userId = 0;
  late int app_version_code = 76;
  late String loginText = "";
  late UserService userService = UserService();
  final _deeplynks = Deeplynks();
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

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  String? _linkMessage;
  bool _isCreatingLink = false;

  Future<void> createLink3(bool short) async {
    FirebaseDynamicLinks dynamicLinks = FirebaseDynamicLinks.instance;

    final String _testString =
        'To test: long press link and then copy and click from a non-browser '
        "app. Make sure this isn't being tested on iOS simulator and iOS xcode "
        'is properly setup. Look at firebase_dynamic_links/README.md for more '
        'details.';

    final String DynamicLink = 'https://afrotok.page.link/post';
    final String Link = 'https://flutterfiretests.page.link/MEGs';
    // setState(() {
    //   _isCreatingLink = true;
    // });

    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://afrotok.page.link',
      longDynamicLink: Uri.parse(
        'https://afrotok.page.link?efr=0&ibi=com.afrotok.afrotok&apn=com.afrotok.afrotok&imv=0&amv=0&link=https%3A%2F%2Fexample%2Fhelloworld&ofl=https://ofl-example.com',
      ),
      link: Uri.parse(DynamicLink),
      androidParameters: const AndroidParameters(
        packageName: 'com.afrotok.afrotok',
        minimumVersion: 0,
      ),
      // iosParameters: const IOSParameters(
      //   bundleId: 'com.afrotok.afrotok',
      //   minimumVersion: '0',
      // ),
    );

    Uri url;
    if (short) {
      final ShortDynamicLink shortLink =
      await dynamicLinks.buildShortLink(parameters);
      url = shortLink.shortUrl;
    } else {
      url = await dynamicLinks.buildLink(parameters);
    }
    _linkMessage = url.toString();
    _isCreatingLink = false;
  //   setState(() {
  //     _linkMessage = url.toString();
  //     _isCreatingLink = false;
  //   });

    printVm('***********dynamicLinks Link 1:**************');

    printVm('***********Deeplynks Link 1: $_linkMessage');

  }
  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }
  Future<String> createLink(bool short, Post post) async {
    FirebaseDynamicLinks dynamicLinks = FirebaseDynamicLinks.instance;

    final String DynamicLink = 'https://afrotok.page.link/post';
    final String appLogo="https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/logoapp%2Fafrolook_logo.png?alt=media&token=dae50f81-4ea1-489f-86f3-e08766654980";

    // Paramètres que vous souhaitez ajouter à l'URL du lien dynamique
    final Uri link = Uri.parse(
        'https://afrotok.page.link/post?postId=${post.id}&postImage=${post.images!.isEmpty?appLogo:post.images!.first}&postType=${PostType.POST.name}'
    );

    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://afrotok.page.link',
      link: link,
      androidParameters: const AndroidParameters(
        packageName: 'com.afrotok.afrotok',
        minimumVersion: 0,
      ),
      iosParameters: const IOSParameters(
        bundleId: 'com.afrotok.afrotok',
        minimumVersion: '0',
      ),
      socialMetaTagParameters: SocialMetaTagParameters(
        title: 'Afrolook media ♠☺♥',  // Titre de la publication
        description: post.description,  // Description de la publication
        imageUrl: Uri.parse(post.images!.isEmpty?appLogo:post.images!.first),  // URL de l'image du post
      ),
    );

    Uri url;
    if (short) {
      final ShortDynamicLink shortLink =
      await dynamicLinks.buildShortLink(parameters);
      url = shortLink.shortUrl;
    } else {
      url = await dynamicLinks.buildLink(parameters);
    }

    _linkMessage = url.toString();
    _isCreatingLink = false;

    print('Generated Dynamic Link: $_linkMessage');
    return url.toString();
  }

  Future<String> createChallengeLink(bool short, LookChallenge lookChallenge) async {
    FirebaseDynamicLinks dynamicLinks = FirebaseDynamicLinks.instance;

    final String DynamicLink = 'https://afrotok.page.link/post';
    final String appLogo="https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/logoapp%2Fafrolook_logo.png?alt=media&token=dae50f81-4ea1-489f-86f3-e08766654980";

    // Paramètres que vous souhaitez ajouter à l'URL du lien dynamique
    final Uri link = Uri.parse(
        'https://afrotok.page.link/post?postId=${lookChallenge.id}&postImage=${lookChallenge.post!.images!.isEmpty?appLogo:lookChallenge.post!.images!.first}&postType=${PostType.CHALLENGE.name}'
    );

    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://afrotok.page.link',
      link: link,
      androidParameters: const AndroidParameters(
        packageName: 'com.afrotok.afrotok',
        minimumVersion: 0,
      ),
      iosParameters: const IOSParameters(
        bundleId: 'com.afrotok.afrotok',
        minimumVersion: '0',
      ),
      socialMetaTagParameters: SocialMetaTagParameters(
        title: 'Afrolook Challenge 🏆🔥🎁',  // Titre de la publication
        description: lookChallenge.post!.description,  // Description de la publication
        imageUrl: Uri.parse(lookChallenge.post!.images!.isEmpty?appLogo:lookChallenge.post!.images!.first),  // URL de l'image du post
      ),
    );

    Uri url;
    if (short) {
      final ShortDynamicLink shortLink =
      await dynamicLinks.buildShortLink(parameters);
      url = shortLink.shortUrl;
    } else {
      url = await dynamicLinks.buildLink(parameters);
    }

    _linkMessage = url.toString();
    _isCreatingLink = false;

    print('Generated Dynamic Link: $_linkMessage');
    return url.toString();
  }

  Future<String> createArticleLink(bool short, ArticleData article) async {
    FirebaseDynamicLinks dynamicLinks = FirebaseDynamicLinks.instance;

    final String DynamicLink = 'https://afrotok.page.link/post';
    final String appLogo="https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/logoapp%2Fafrolook_logo.png?alt=media&token=dae50f81-4ea1-489f-86f3-e08766654980";

    // Paramètres que vous souhaitez ajouter à l'URL du lien dynamique
    final Uri link = Uri.parse(
        'https://afrotok.page.link/post?postId=${article.id}&postImage=${article.images!.isEmpty?appLogo:article.images!.first}&postType=${PostType.ARTICLE.name}'
    );

    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://afrotok.page.link',
      link: link,
      androidParameters: const AndroidParameters(
        packageName: 'com.afrotok.afrotok',
        minimumVersion: 0,
      ),
      iosParameters: const IOSParameters(
        bundleId: 'com.afrotok.afrotok',
        minimumVersion: '0',
      ),
      socialMetaTagParameters: SocialMetaTagParameters(
        title: 'Marché Afrolook (Afroshop) 🛒',  // Titre de la publication
        description: "${article.titre}:\n ${article.description}",  // Description de la publication
        imageUrl: Uri.parse(article.images!.isEmpty?appLogo:article.images!.first),  // URL de l'image du post
      ),
    );

    Uri url;
    if (short) {
      final ShortDynamicLink shortLink =
      await dynamicLinks.buildShortLink(parameters);
      url = shortLink.shortUrl;
    } else {
      url = await dynamicLinks.buildLink(parameters);
    }

    _linkMessage = url.toString();
    _isCreatingLink = false;

    print('Generated Dynamic Link: $_linkMessage');
    return url.toString();
  }

  Future<String> createServiceLink(bool short, UserServiceData article) async {
    FirebaseDynamicLinks dynamicLinks = FirebaseDynamicLinks.instance;

    final String DynamicLink = 'https://afrotok.page.link/post';
    final String appLogo="https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/logoapp%2Fafrolook_logo.png?alt=media&token=dae50f81-4ea1-489f-86f3-e08766654980";

    // Paramètres que vous souhaitez ajouter à l'URL du lien dynamique
    final Uri link = Uri.parse(
        'https://afrotok.page.link/post?postId=${article.id}&postImage=${article.imageCourverture==null?appLogo:article.imageCourverture}&postType=${PostType.SERVICE.name}'
    );

    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://afrotok.page.link',
      link: link,
      androidParameters: const AndroidParameters(
        packageName: 'com.afrotok.afrotok',
        minimumVersion: 0,
      ),
      iosParameters: const IOSParameters(
        bundleId: 'com.afrotok.afrotok',
        minimumVersion: '0',
      ),
      socialMetaTagParameters: SocialMetaTagParameters(
        title: 'Marché Afrolook (Afroshop) 🛒',  // Titre de la publication
        description: "${article.titre}:\n ${article.description}",  // Description de la publication
        imageUrl: Uri.parse(article.imageCourverture==null?appLogo:article.imageCourverture!),  // URL de l'image du post
      ),
    );

    Uri url;
    if (short) {
      final ShortDynamicLink shortLink =
      await dynamicLinks.buildShortLink(parameters);
      url = shortLink.shortUrl;
    } else {
      url = await dynamicLinks.buildLink(parameters);
    }

    _linkMessage = url.toString();
    _isCreatingLink = false;

    print('Generated Dynamic Link: $_linkMessage');
    return url.toString();
  }


  Future<void> createLink2(Post post) async {
    printVm('***********Deeplynks Link 1:**************');

    final link = await _deeplynks.createLink(jsonEncode({
      'referredBy': '12345',
      'referralCode': 'WELCOME50',
      'postId': post.id,
      'description': post.description,
      'urlImage': post.images!.isNotEmpty?post.images!.first!:'',
    }));

    printVm('***********Deeplynks Link 2:**************');
    printVm('Deeplynks Link: $link');

    log('Deeplynks Link: $link');
  }

  Future<void> storeIsFirst(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirst', value);
  }

  Future<bool?> getIsFirst() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // token = prefs.getString('token');
    // printVm("get token : ${token}");
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
    // printVm("get token : ${token}");
    //notifyListeners();
    return prefs.getString('token');
  }
  Future<void> ajouterAuSolde(String userId, double montant) async {
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .update({'votre_solde': FieldValue.increment(montant)});
      print('Montant ajouté avec succès.');
    } catch (e) {
      print("Erreur lors de l'ajout du montant : $e");
    }
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
    // printVm("app data : ${appDefaultData.toJson()}");

  }

  Future<void> updateAppData(AppDefaultData appDefaultData) async {
    printVm("app data : ${appDefaultData!.toJson()}");

    await firestore.collection('AppData').doc(appDefaultData!.id).update(
        appDefaultData!.toJson());
  }
  Future<void> updateEntreprise(EntrepriseData data) async {
    printVm("entreprise  data : ${data!.toJson()}");

    await firestore.collection('Entreprises').doc(data!.id).update(
        data!.toJson());
  }





  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  Stream<List<NotificationData>> getListNotificationAuth(String user_id) async* {
    var postStream = FirebaseFirestore.instance.collection('Notifications')
        .where("receiver_id",isEqualTo:'${user_id}')

        .orderBy('created_at', descending: true)

        .snapshots();
    List<NotificationData> notifications = [];
    //  UserData userData=UserData();
    await for (var snapshot in postStream) {
      notifications = [];

      for (var post in snapshot.docs) {
        //  printVm("post : ${jsonDecode(post.toString())}");
        NotificationData notification = NotificationData.fromJson(post.data());
        // listConstposts=posts;

        if (!isIn(notification.users_id_view!, loginUserData.id!)) {
          notifications.add(notification);
        }
      }
      yield notifications;
    }
  }

  String timeAgo(int timestamp) {
    final now = DateTime.now();
    final difference = now.difference(DateTime.fromMillisecondsSinceEpoch(timestamp));

    if (difference.inMinutes < 1) {
      return "à l'instant";
    } else if (difference.inMinutes == 1) {
      return "il y a 1 minute";
    } else if (difference.inMinutes < 60) {
      return "il y a ${difference.inMinutes} minutes";
    } else if (difference.inHours == 1) {
      return "il y a 1 heure";
    } else if (difference.inHours < 24) {
      return "il y a ${difference.inHours} heures";
    } else if (difference.inDays == 1) {
      return "il y a 1 jour";
    } else {
      return "il y a ${difference.inDays} jours";
    }
  }

  List<WhatsappStory> getStoriesWithTimeAgo(List<WhatsappStory> stories) {
    return stories.map((story) {
      story.when = timeAgo(story.createdAt!);
      return story;
    }).toList();
  }

  Future<List<UserData>> getUsersStorie(String currentUserId, int limit) async {
    List<UserData> listUsers = [];

    try {
      CollectionReference userCollect = FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshot = await userCollect.where('stories', isNotEqualTo: []).get();
      List<DocumentSnapshot> users = querySnapshot.docs;

      // Séparer l'utilisateur courant des autres utilisateurs
      DocumentSnapshot? currentUserDoc;
      users.removeWhere((doc) {
        if (doc.id == currentUserId) {
          currentUserDoc = doc;
          return true;
        }
        return false;
      });

      // Mélanger la liste des autres utilisateurs
      users.shuffle();
      List<DocumentSnapshot> usersDocs = users.take(limit).toList();

      // Ajouter l'utilisateur courant au début de la liste
      if (currentUserDoc != null) {
        usersDocs.insert(0, currentUserDoc!);
      }

      listUsers = usersDocs.map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      List<UserData> usersRestants = await verifierEtSupprimerStories(listUsers);

      listUsers = usersRestants;

      print('list users stories ${listUsers.length}');
      return listUsers;

    } catch (e) {
      print("erreur $e");
      return [];
    }
  }

  void ajouterStory(UserData user, WhatsappStory story) {
    user.stories ??= [];
    user.stories!.add(story);
  }
  Future<bool> deleteFileFromUrl(String fileUrl) async {
    try {
      // Obtenez une instance de FirebaseStorage
      final FirebaseStorage storage = FirebaseStorage.instance;

      // Vérifiez et extrayez le chemin du fichier de l'URL
      final Uri uri = Uri.parse(fileUrl);
      final String filePath = Uri.decodeComponent(uri.pathSegments.last); // Extraire le nom du fichier

      // Référence au fichier
      final Reference ref = storage.ref().child(filePath);

      // Supprimez le fichier
      await ref.delete();
      print('Fichier supprimé avec succès.');

      return true;
    } catch (e) {
      print('Erreur lors de la suppression du fichier : $e');
      return false;
    }
  }


  Future<bool> deleteFileFromUrl2(String fileUrl) async {
    try {
      // Obtenez une instance de FirebaseStorage
      final FirebaseStorage storage = FirebaseStorage.instance;

      // Extrayez le chemin du fichier à partir de l'URL
      final Uri uri = Uri.parse(fileUrl);
      final String filePath = uri.pathSegments.skip(1).join('/'); // Ignore 'v0/b/<bucket>'

      // Référence au fichier
      final Reference ref = storage.ref(filePath);

      // Supprimez le fichier
      await ref.delete();
      print('Fichier supprimé avec succès.');

      return true;
    } catch (e) {
      print('Erreur lors de la suppression du fichier : $e');

      return false;

    }
  }
  Future<List<UserData>> verifierEtSupprimerStories(List<UserData> users) async {
    int maintenant = DateTime.now().millisecondsSinceEpoch;
    List<UserData> usersRestants = [];

    for (UserData user in users) {
      user.stories?.removeWhere((story) {
        // bool estExpiree = (maintenant - story['createdAt']) > 120000; // 2 minutes en millisecondes
        bool estExpiree = (maintenant - story.createdAt!) > 86400000; // 24 heurs en millisecondes
        if (estExpiree && story.media != null && story.media!.isNotEmpty) {
          deleteFileFromUrl(story.media!).then((value) async {
            if (value) {
              await updateUser(user);
            }
          });
        }
        return estExpiree;
      });

      if (user.stories != null && user.stories!.isNotEmpty) {
        usersRestants.add(user);
      }
    }

    return usersRestants;
  }
  // void verifierEtSupprimerStories(UserData user) {
  //   int maintenant = DateTime.now().millisecondsSinceEpoch;
  //   user.stories?.removeWhere((story) {
  //     bool estExpiree = (maintenant - story['createdAt']) > 86400000; // 24 heures en millisecondes
  //     // bool estExpiree = (maintenant - story['createdAt']) > 120000; // 24 heures en millisecondes
  //     if (estExpiree && story['media'] != null && story['media'].isNotEmpty) {
  //       deleteFileFromUrl(story['media']).then((value) async {
  //         if(value){
  //           await updateUser(user);
  //         }
  //
  //       },);
  //       // Supprimer le fichier média associé
  //       // Vous pouvez ajouter ici le code pour supprimer le fichier média
  //     }
  //     return estExpiree;
  //   });
  // }

  Future<bool> supprimerStories(UserData user,int index) async {
    int maintenant = DateTime.now().millisecondsSinceEpoch;

    if (index >= 0 && index < user.stories!.length) {
      var map=user.stories?.elementAt(index);
      if(map!.media!.length>5){
        await deleteFileFromUrl(map!.media!).then((value) async {
          if(value){
            user.stories?.removeAt(index);
            await updateUser(user);
          // Supprime l'élément à l'index donné

          }

        },);

      }else{
        user.stories?.removeAt(index);
        await updateUser(user);
      }
      print('Élément supprimé à l\'index $index');
      return true;
    } else {
      return false;
      print('Index invalide');
    }
  }
  Future<bool> getLoginUser(String id) async {
    await getAppData();
    bool haveData = false;

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where("id", isEqualTo: id)
          .limit(1)
          .get();

      if (userSnapshot.docs.isEmpty) return false;

      // 1. Chargement des données utilisateur
      final userDoc = userSnapshot.docs.first;
      loginUserData = UserData.fromJson(userDoc.data()..['id'] = userDoc.id);

      // 2. Mise à jour sélective des champs sans toucher aux stories
      final updateData = <String, dynamic>{
        'oneIgnalUserid': OneSignal.User.pushSubscription.id,
        'popularite': _calculatePopularity(loginUserData!),
        'compteTarif': loginUserData!.popularite! * 80,
        'last_time_active': DateTime.now().millisecondsSinceEpoch,
      };

      // 3. Update ciblé pour ne pas écraser les stories
      await userDoc.reference.update(updateData);

      // 4. Chargement des amis séparément
      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('Friends')
          .where(Filter.or(
        Filter('current_user_id', isEqualTo: id),
        Filter('friend_id', isEqualTo: id),
      ))
          .get();

      loginUserData!.friends = friendsSnapshot.docs
          .map((doc) => Friends.fromJson(doc.data()))
          .toList();

      haveData = true;

      // 5. Rafraîchissement des données locales
      await _refreshUserData(userDoc.reference);

    } catch (e, stack) {
      debugPrint("Erreur de connexion: $e");
      debugPrint("Stack trace: $stack");
      haveData = false;
    }

    return haveData;
  }

  double _calculatePopularity(UserData user) {
    return (user.abonnes! + user.likes! + user.jaimes!) /
        (appDefaultData.nbr_abonnes! + appDefaultData.nbr_likes! + appDefaultData.nbr_loves!);
  }

  Future<void> _refreshUserData(DocumentReference ref) async {
    final updatedDoc = await ref.get();
    loginUserData = UserData.fromJson(updatedDoc.data() as Map<String, dynamic>)
      ..friends = loginUserData?.friends;
  }

  Future<bool> getLoginUser2(String id) async {
    await getAppData();
    late List<UserData> list = [];
    late bool haveData = false;

    CollectionReference collectionRef =
    FirebaseFirestore.instance.collection('Users');
    // Get docs from collection reference
    QuerySnapshot querySnapshot = await collectionRef.where(
        "id", isEqualTo: id!).get()
        .then((value) {
      printVm(value);
      return value;
    }).catchError((onError) {

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

    if (list.isNotEmpty) {
      loginUserData = list.first;
      printVm("OneSignal=====");
//       loginUserData.abonnes=loginUserData.userAbonnesIds==null?0:loginUserData.userAbonnesIds!.length;
// updateUser(loginUserData);

    //  printVm("OneSignal id : ${OneSignal.User.pushSubscription.id}");
    //  printVm("OneSignal token : ${OneSignal.User.pushSubscription.token}");

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
  Future<bool> updateUser(UserData user) async {
    try{



      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.id)
          .update(user.toJson());
      printVm("user update : ${user!.toJson()}");
      return true;
    }catch(e){
      printVm("erreur update post : ${e}");
      return false;
    }
  }

  Future<bool> updateTransactionSolde(TransactionSolde trans) async {
    try{



      await FirebaseFirestore.instance
          .collection('TransactionSoldes')
          .doc(trans.id)
          .update(trans.toJson());
      printVm("trans update : ${trans!.toJson()}");
      return true;
    }catch(e){
      printVm("erreur update post : ${e}");
      return false;
    }
  }

  bool isUserAbonne(List<String> abonnesIds, String userId) {
    return abonnesIds.contains(userId);
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
      printVm(value);
      return value;
    }).catchError((onError) {

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
    // for(UserData user in list){
    //   user.abonnes=user.userAbonnesIds==null?0:user.userAbonnesIds!.length;
    //   updateUser(user);
    //
    //
    // }



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
        printVm("onesignaluser size : ${listOSUserid.length}");

          // u.abonnes=u.userAbonnesIds==null?0:u.userAbonnesIds!.length;
          // updateUser(u);




      }
    }

    return listOSUserid;
  }
  Future<bool> updateNotif(NotificationData notif) async {
    try{



      await FirebaseFirestore.instance
          .collection('Notifications')
          .doc(notif.id)
          .update(notif.toJson());
      //printVm("notif update : ${notif!.toJson()}");
      return true;
    }catch(e){
      printVm("erreur update Invitations : ${e}");
      return false;
    }
  }
  Future<bool> abonner2(UserData updateUserData,BuildContext context) async {
    try{
      late UserProvider userProvider =
      Provider.of<UserProvider>(context, listen: false);
      await getUserById(updateUserData.id!).then(
              (users) async {
            if(users.isNotEmpty)
              updateUserData=users.first;
            if (!isUserAbonne(updateUserData.userAbonnesIds!,loginUserData.id!)) {

              UserAbonnes userAbonne = UserAbonnes();
              userAbonne.compteUserId=loginUserData.id;
              userAbonne.abonneUserId=updateUserData.id;

              userAbonne.createdAt  = DateTime.now().millisecondsSinceEpoch;
              userAbonne.updatedAt  = DateTime.now().millisecondsSinceEpoch;
              await  userProvider.sendAbonnementRequest(userAbonne,updateUserData,context).then((value) async {
                if (value) {


                  // await userProvider.getUsers(loginUserData!.id!);
                  loginUserData.userAbonnes!.add(userAbonne);
                  await getCurrentUser(loginUserData!.id!);

                  // users.first.abonnes=users.first.abonnes!+1;
                  updateUserData.userAbonnesIds!.add(loginUserData.id!);
                  // updateUserData.userAbonnesIds!.add(loginUserData.id!);

                  // updateUserData= users.first;

                  updateUserData.abonnes=updateUserData.userAbonnesIds!.length;
                  // updateUserData.abonnes= updateUserData.abonnes!+1;
                  // updateUserData= users.first;

                  await updateUser(updateUserData).then((value) async {
                    if (updateUserData.oneIgnalUserid!=null&&updateUserData.oneIgnalUserid!.length>5) {
                      await sendNotification(
                      userIds: [updateUserData.oneIgnalUserid!],
                      smallImage: "${loginUserData.imageUrl!}",
                      send_user_id: "${loginUserData.id!}",
                      recever_user_id: "${updateUserData.id!}",
                      message: "📢 @${loginUserData.pseudo!} s'est abonné(e) à votre compte !",
                      type_notif: NotificationType.ABONNER.name,
                      post_id: "",
                      post_type: "", chat_id: ''
                      );

                      NotificationData notif=NotificationData();
                      notif.id=firestore
                          .collection('Notifications')
                          .doc()
                          .id;
                      notif.titre="Nouveau Abonnement ✅";
                      notif.media_url=loginUserData.imageUrl;
                      notif.type=NotificationType.ABONNER.name;
                      notif.description="@${loginUserData.pseudo!} s'est abonné(e) à votre compte";
                      notif.users_id_view=[];
                      notif.user_id=loginUserData.id;
                      notif.receiver_id="";
                      notif.post_id="";
                      notif.post_data_type=PostDataType.IMAGE.name!;
                      notif.updatedAt =
                          DateTime.now().microsecondsSinceEpoch;
                      notif.createdAt =
                          DateTime.now().microsecondsSinceEpoch;
                      notif.status = PostStatus.VALIDE.name;

                      // users.add(pseudo.toJson());

                      await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());


                    }
                    SnackBar snackBar = SnackBar(
                      content: Text('abonné, Bravo ! Vous avez gagné 4 points.',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(snackBar);

                  },);


                }  else{
                  SnackBar snackBar = SnackBar(
                    content: Text('une erreur',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);

                }
              },);


     
            }else{
              SnackBar snackBar = SnackBar(
                content: Text('Vous êtes déjà abonné.',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
              );
              ScaffoldMessenger.of(context).showSnackBar(snackBar);
            }

          }


      );
      return true;
    }catch(e){
      printVm("erreur update Invitations : ${e}");
      return false;
    }
  }

  Future<bool> abonner(UserData updateUserData, BuildContext context) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = loginUserData.id!;

      // Vérification client-side de l'abonnement
      if (isUserAbonne(updateUserData.userAbonnesIds!, currentUserId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Vous êtes déjà abonné.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red))),
        );
        return true;
      }

      // Création de la relation d'abonnement
      final userAbonne = UserAbonnes()
        ..compteUserId = currentUserId
        ..abonneUserId = updateUserData.id
        ..createdAt = DateTime.now().millisecondsSinceEpoch
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;

      // Envoi de la demande d'abonnement
      final success = await userProvider.sendAbonnementRequest(
          userAbonne, updateUserData, context);

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur lors de l\'abonnement',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red))),
        );
        return false;
      }

      // Mise à jour atomique dans Firestore
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(updateUserData.id)
          .update({
        'userAbonnesIds': FieldValue.arrayUnion([currentUserId]),
        'abonnes': FieldValue.increment(1),
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });

      // Mise à jour locale
      loginUserData.userAbonnes!.add(userAbonne);
      updateUserData.userAbonnesIds!.add(currentUserId);
      updateUserData.abonnes = (updateUserData.abonnes ?? 0) + 1;

      // Envoi de notification
      if (updateUserData.oneIgnalUserid != null &&
          updateUserData.oneIgnalUserid!.length > 5) {
        await sendNotification(
          userIds: [updateUserData.oneIgnalUserid!],
          smallImage: loginUserData.imageUrl!,
          send_user_id: currentUserId,
          recever_user_id: updateUserData.id!,
          message: "📢 @${loginUserData.pseudo!} s'est abonné(e) à votre compte !",
          type_notif: NotificationType.ABONNER.name,
          post_id: '',
          post_type: '',
          chat_id: '',
        );

        final notif = NotificationData()
          ..id = FirebaseFirestore.instance.collection('Notifications').doc().id
          ..titre = "Nouvel Abonnement ✅"
          ..media_url = loginUserData.imageUrl
          ..type = NotificationType.ABONNER.name
          ..description = "@${loginUserData.pseudo!} s'est abonné(e) à votre compte"
          ..user_id = currentUserId
          ..updatedAt = DateTime.now().microsecondsSinceEpoch
          ..createdAt = DateTime.now().microsecondsSinceEpoch
          ..status = PostStatus.VALIDE.name;

        await FirebaseFirestore.instance
            .collection('Notifications')
            .doc(notif.id)
            .set(notif.toJson());
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Abonné, Bravo ! Vous avez gagné 4 points.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.green)),
        ),
      );

      return true;
    } catch (e) {
      print("Erreur lors de l'abonnement : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur technique',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red))),
      );
      return false;
    }
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
      printVm(value);
      return value;
    }).catchError((onError) {

    });

    // Get data from docs and convert map to List
    list = querySnapshot.docs.map((doc) =>
        UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

    if (list.isNotEmpty) {
      for(UserData user in list){
        // user.abonnes=user.userAbonnesIds==null?0:user.userAbonnesIds!.length;
        // updateUserData(user);


      }
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
      printVm(value);
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
      printVm("erreur comment : ${e}");
      return false;
    }
  }



  Future<bool> getCurrentUser(String currentUserId) async {
    await getAppData();
    //listUsers = [];
    bool hasData = false;


    await userService.getUserData(userId: currentUserId).then((value) async {
      loginUserData = value;
      // loginUserData.abonnes=loginUserData.userAbonnesIds==null?0:loginUserData.userAbonnesIds!.length;

      loginUserData.popularite =
          (loginUserData.abonnes! + loginUserData.likes! +
              loginUserData.jaimes!) /
              (appDefaultData.nbr_abonnes! + appDefaultData.nbr_likes! +
                  appDefaultData.nbr_loves!);
      loginUserData.oneIgnalUserid = OneSignal.User.pushSubscription.id;



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

  Future<bool> getCurrentUserByPhone(String phone) async {
    await getAppData();
    //listUsers = [];
    bool hasData = false;


    await userService.getUserDataByPhone(phone: phone).then((value) async {

      loginUserData = value;
      // loginUserData.abonnes=loginUserData.userAbonnesIds==null?0:loginUserData.userAbonnesIds!.length;

      loginUserData.popularite =
          (loginUserData.abonnes! + loginUserData.likes! +
              loginUserData.jaimes!) /
              (appDefaultData.nbr_abonnes! + appDefaultData.nbr_likes! +
                  appDefaultData.nbr_loves!);
      loginUserData.oneIgnalUserid = OneSignal.User.pushSubscription.id;

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
  Future<String?> generateText({
    required List<Message> ancienMessages,
    required String message,
    required String regle,
    required UserData user,
    required UserIACompte ia,
  }) async
  {
    List<Content> historique = [];

    // Ajouter les messages historiques avec leur rôle (par exemple, utilisateur ou assistant)
    // for (Message msg in ancienMessages) {
    //   historique.add(Content.text(msg.message!));
    // }

    // Ajouter les 10 derniers messages seulement si l'historique dépasse 10
    int startIndex = ancienMessages.length > 10 ? ancienMessages.length - 10 : 0;
    for (int i = startIndex; i < ancienMessages.length; i++) {
      historique.add(Content.text(ancienMessages[i].message!));
    }

    try {
      // Initialisation du modèle avec des instructions adaptées
      final model = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
        apiKey: appDefaultData.geminiapiKey!,
        systemInstruction: Content.system(
          "${regle}. Prenez en compte le genre de la personne avec qui vous discutez : actuellement, vous discutez avec ${user.genre == "Homme" ? 'un homme' : 'une femme'}.",
        ),
      );

      // Préparation du message actuel à ajouter à l'historique
      final prompt = Content.text(message);
      historique.add(prompt);

      // Initialisation de la conversation avec l'historique complet
      model.startChat(history: historique);

      // Génération de la réponse
      final response = await model.generateContent([prompt]);
      if (response != null) {
        printVm("Data token: ${response.usageMetadata!.totalTokenCount!}");

        // Mise à jour des jetons restants pour l'utilisateur IA
        ia.jetons = ia.jetons! - response.usageMetadata!.totalTokenCount!;
        await firestore.collection('User_Ia_Compte').doc(ia.id!).update(ia.toJson());

        return response.text; // Retourne le texte généré
      } else {
        return null; // Si aucune réponse n'est générée
      }
    } catch (error) {
      // Gestion des erreurs
      printVm("Erreur lors de la génération du texte : $error");
      return ""; // Ou une autre valeur par défaut
    }
  }




  Future<String?> generateText2({required List<Message> ancien_messages,required String message,required String regle,required UserData user,required UserIACompte ia}) async {
    List<Content> contents=[];
    for(Message message in ancien_messages){
      contents.add(Content.text(message.message!));


    }

    try {
      //final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
      // final model = GenerativeModel(model: 'gemini-1.5-pro-latest', apiKey: apiKey,systemInstruction: Content.system("${regle}. prenez en compte le genre de la personne avec qui vous discuter et actuellement vous discuter avec ${user.genre=="Homme"?'un homme':'une femme'} "));
      final model = GenerativeModel(model: 'gemini-2.0-flash-exp', apiKey: appDefaultData.geminiapiKey!,systemInstruction: Content.system("${regle}. prenez en compte le genre de la personne avec qui vous discuter et actuellement vous discuter avec ${user.genre=="Homme"?'un homme':'une femme'} "));
      //final prompt = "pour chaque question voici les regle a respecter "${regle}" voici la question "${message}"";
      final prompt = "${message}";
      final content = [Content.text(prompt)];
      model.startChat(history: contents);
      final response = await model.generateContent(content);
      printVm("Data token: ${response!.usageMetadata!.totalTokenCount!}");
      ia.jetons=ia.jetons!-response!.usageMetadata!.totalTokenCount!;
      await firestore.collection('User_Ia_Compte').doc(ia.id!).update( ia.toJson());


      return response!.text;
    } catch (error) {
      // Handle the error here
      printVm("Error generating story: $error");
      return ""; // Or return a default value
    }
  }

  // Create the configuration


// // Create a new client
//   String oneSignalUrl = 'https://api.onesignal.com/notifications';
//   String applogo =
//       "https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/logoapp%2Fafrolook_logo.png?alt=media&token=dae50f81-4ea1-489f-86f3-e08766654980";
//   String oneSignalAppId =
//       'b1b8e6b8-b9f4-4c48-b5ac-6ccae1423c98'; // Replace with your app ID
//   String oneSignalAuthorization =
//       'YjEwNmY0MGQtODFhYi00ODBkLWIzZjgtZTVlYTFkMjQxZDA0'; // Replace with your authorization key

  // CHANGE THIS parameter to true if you want to test GDPR privacy consent
  Future<void> sendNotification({required List<String> userIds, required String smallImage,required String send_user_id, required String recever_user_id,required String message,required String type_notif,required String post_id,required String post_type,required String chat_id}) async {

    String oneSignalUrl = '';
    String applogo = '';
    String oneSignalAppId = ''; // Replace with your app ID
    String oneSignalAuthorization = ''; // Replace with your authorization key
    getAppData().then((app_datas) async {

        printVm(
            'app  data*** ');
        printVm(appDefaultData.toJson());
        oneSignalUrl = appDefaultData.one_signal_app_url;
        applogo = appDefaultData.app_logo;
        oneSignalAppId = appDefaultData.one_signal_app_id; // Replace with your app ID
        oneSignalAuthorization = appDefaultData.one_signal_api_key; // Replace with your authorization key
        printVm(
            'one signal url*** ');
        printVm(oneSignalUrl);
        printVm(
            'state current user data  ================================================');

        printVm(OneSignal.User.pushSubscription.id);
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
          // "custom_data": {"order_id": 123, "currency": "USD", "amount": 25},
          "data": {"send_user_id": "${send_user_id}","recever_user_id": "${recever_user_id}", "type_notif": "${type_notif}", "post_id": "${post_id}","post_type": "${post_type}","chat_id": "${chat_id}"},
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
          printVm('Notification sent successfully!');
          printVm('sending notification: ${response.body}');
        } else {
          printVm('Error sending notification: ${response.statusCode}');
          printVm('Error sending notification: ${response.body}');
        }
        // final body = {
        //   'contents': {'en': message},
        //   'app_id': oneSignalAppId,
        //
        //   "include_player_ids":
        //   // "include_subscription_ids":
        //   userIds, //tokenIdList Is the List of All the Token Id to to Whom notification must be sent.
        //
        //   // android_accent_color reprsent the color of the heading text in the notifiction
        //   "android_accent_color": "FF9976D2",
        //
        //   "small_icon": applogo,
        //
        //   "large_icon": applogo,
        //
        //   "headings": {"en": "konami"},
        //   //"included_segments": ["Active Users", "Inactive Users"],
        //   "data": {"foo": "bar"},
        //   'name': 'konami',
        //   'custom_data': {'order_id': 123, 'Prix': '500 fcfa'},
        // };
        //
        // final response = await http.post(
        //   Uri.parse(oneSignalUrl),
        //   headers: {
        //     'Content-Type': 'application/json',
        //     'Authorization': "Basic $oneSignalAuthorization",
        //   },
        //   body: jsonEncode(body),
        // );
        //
        // if (response.statusCode == 200) {
        //   printVm('Notification sent successfully!');
        //   printVm('sending notification: ${response.body}');
        //   return true;
        // } else {
        //   printVm('Error sending notification: ${response.statusCode}');
        //   printVm('Error sending notification: ${response.body}');
        //   return false;
        //
        // }

    },);


    //printVm(OneSignal.User.pushSubscription.id);


  }


  // import 'dart:convert';
  // import 'package:http/http.dart' as http;


  Future<String?> generateToken() async {
    final url = Uri.parse('https://client.cinetpay.com/v1/auth/login');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'apikey': '${cinetPayToken}',  // Remplace par ta clé API
        'password': '${transfertApiPasswordToken}',  // Remplace par ton mot de passe API
        'lang': 'fr',  // ou 'en' pour anglais
      },
    );

    if (response.statusCode == 200) {
      // La requête a réussi, tu peux récupérer le token ici
      var responseBody = json.decode(response.body);
      print('Token généré : ${responseBody}');
      transfertGeneratePayToken=responseBody['data']['token'];
      return transfertGeneratePayToken;

    } else {
      print('Erreur: ${response.statusCode}');
      print('Détails : ${response.body}');
      return null;
    }
  }

  Future<bool> ajouterContactCinetPay(
      String token, String prefix, String phone, String name, String surname, String email)
  async {
    final url = Uri.parse('https://client.cinetpay.com/v1/transfer/contact');

    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    final body = jsonEncode([
      {
        "prefix": prefix,
        "phone": phone,
        "name": name,
        "surname": surname,
        "email": email
      }
    ]);

    print('Donnee envoyer ${jsonEncode(body)}');
    print('Donnee token envoyer:  ${transfertGeneratePayToken}');


    try {
      final response = await http.post(
        url,
        headers: headers,
        body: {
          'token': transfertGeneratePayToken,
          'data': jsonEncode(body),
          'lang': 'fr' // ou 'en' selon la langue souhaitée
        },
      );

      if (response.statusCode == 200) {
        // Si la requête est réussie
        print('Numero ajouter : Code de statut ${response.statusCode}');

        return true;
      } else {
        // Si la requête échoue
        print('Erreur d enregistrement du numero: Code de statut ${response.statusCode}');
        print('Erreur d enregistrement du numero: data ${response.body}');
        return false;
      }
    } catch (e) {
      // Gestion des erreurs de la requête HTTP
      print('Une erreur est survenue: $e');
      return false;
    }
  }
  Future<void> checkAppVersionAndProceed(BuildContext context, Function onSuccess) async {
    await getAppData().then((appdata) async {
      print("code app data *** : ${appDefaultData.app_version_code}");
      if (!appDefaultData.googleVerification!) {
        if (app_version_code == appDefaultData.app_version_code) {
          onSuccess();
        } else {
          showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return Container(
                height: 300,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.info, color: Colors.red),
                        Text(
                          'Nouvelle mise à jour disponible!',
                          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10.0),
                        Text(
                          'Une nouvelle version de l\'application est disponible. Veuillez télécharger la mise à jour pour profiter des dernières fonctionnalités et améliorations.',
                          style: TextStyle(fontSize: 16.0),
                        ),
                        SizedBox(height: 20.0),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () {
                            _launchUrl(Uri.parse('${appDefaultData.app_link}'));
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Ionicons.ios_logo_google_playstore, color: Colors.white),
                              SizedBox(width: 5),
                              Text(
                                'Télécharger sur le play store',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

      }else{
        onSuccess();

      }

    });
  }

}
