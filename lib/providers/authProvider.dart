import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:afrotok/models/chatmodels/message.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:deeplynks/deeplynks_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'package:cloud_functions/cloud_functions.dart';
class UserAuthProvider extends ChangeNotifier {
  late AuthService authService = AuthService();
  late List<UserPhoneNumber> listNumbers = [];
  late UserData loginUserData = UserData();
  late UserData registerUser = UserData();
  late String registerText = "";
  late String? token = '';
  late String? cinetPayToken = '102325650865f879a7b10492.83921456';
  late String? transfertApiPasswordToken = 'Bbienvenu@_4';
  late String? transfertGeneratePayToken = '';
  late String? cinetSiteId = '5870078';
  // late String? userId = "";
  late int app_version_code = 113;
  late String loginText = "";
  late UserService userService = UserService();
  final _deeplynks = Deeplynks();
  //List<Pays>? listPays=[];

  late AppDefaultData appDefaultData = AppDefaultData();

  late List<UserGlobalTag> listUserGlobalTag = [];
  late List<String> listUserGlobalTagString = [];
  late List<UserPseudo> listPseudo = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseFunctions functions = FirebaseFunctions.instance;
  initializeData() {
    registerUser = UserData();
  }

  UserData? _userData;
  List<UserData> _availableUsers = [];

  UserData? get userData => _userData;
  List<UserData> get availableUsers => _availableUsers;
  String? get userId => _auth.currentUser?.uid;

  Future<void> checkAndCleanViewedPosts(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();

      if (userDoc.exists) {
        final userData = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
        final viewedPostIds = userData.viewedPostIds ?? [];

        if (viewedPostIds.length >= 1000) {
          // Garder seulement les 100 derniers posts vus (ou vider complètement)
          final List<String> recentViewedIds = viewedPostIds.length > 100
              ? viewedPostIds.sublist(viewedPostIds.length - 100)
              : [];

          await FirebaseFirestore.instance.collection('Users').doc(userId).update({
            'viewedPostIds': recentViewedIds,
          });

          // Mettre à jour localement
          loginUserData.viewedPostIds = recentViewedIds;

          print("🔄 Nettoyage automatique: viewedPostIds réduit à ${recentViewedIds.length} éléments");
        }
      }
    } catch (e) {
      print('❌ Erreur nettoyage viewedPosts: $e');
    }
  }
  Future<void> fetchUserData() async {
    if (_auth.currentUser != null) {
      final userDoc = await _firestore.collection('Users').doc(_auth.currentUser!.uid).get();
      if (userDoc.exists) {
        _userData = UserData.fromJson(userDoc.data()!);
      }
    }
    await _fetchAvailableUsers();
    notifyListeners();
  }

  Future<void> _fetchAvailableUsers() async {
    try {
      final usersSnapshot = await _firestore.collection('Users').get();
      _availableUsers = usersSnapshot.docs
          .map((doc) => UserData.fromJson(doc.data()))
          .where((user) => user.id != _auth.currentUser?.uid)
          .toList();
    } catch (e) {
      print("Erreur lors du chargement des utilisateurs: $e");
    }
  }

  void _showPaymentRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Solde insuffisant', style: TextStyle(color: Colors.white)),
        content: Text('Vous avez besoin de 100 FCFA pour participer au live.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Color(0xFFF9A825))),
          ),
        ],
      ),
    );
  }
  Future<bool> incrementAppGain(double amount) async {
    try {
      // Récupérer le document unique AppDefaultData
      DocumentReference appRef = _firestore.collection('AppData').doc(appDefaultData.id!);
      // Remplace 'APP_ID' par l'ID du document AppDefaultData dans Firestore

      await appRef.update({
        'solde_gain': FieldValue.increment(amount),
      });

      print("✅ Solde gain de l'application mis à jour avec succès");
      return true;
    } catch (e) {
      print("Erreur lors de l'ajout au solde_gain de l'application: $e");
      return false;
    }
  }

  Future<bool> deductFromBalance(BuildContext context, double amount) async {
    _userData = loginUserData;
    if (_userData == null || _userData!.votre_solde_principal! < amount) {
      _showPaymentRequiredDialog(context);
      return false;
    }

    try {
      await _firestore.collection('Users').doc(_userData!.id).update({
        'votre_solde_principal': FieldValue.increment(-amount),
      });

      _userData!.votre_solde_principal = _userData!.votre_solde_principal! - amount;

      await _firestore.collection('TransactionSoldes').add({
        'user_id': _userData!.id,
        'montant': amount,
        'type': TypeTransaction.DEPENSE.name,
        'description': 'Participation à un live',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'statut': StatutTransaction.VALIDER.name,
      });

      notifyListeners();
      return true;
    } catch (e) {
      print("Erreur lors de la déduction du solde: $e");
      return false;
    }
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


  Future<List<UserData>> verifierEtSupprimerStories(List<UserData> users) async {
    int maintenant = DateTime.now().millisecondsSinceEpoch;
    List<UserData> usersRestants = [];

    for (UserData user in users) {
      // Sélectionner les stories expirées
      List<WhatsappStory> storiesExpirees = user.stories
          ?.where((story) => (maintenant - story.createdAt!) > 86400000)
          .toList() ?? [];

      // Supprimer chaque story expirée directement depuis Firestore
      for (WhatsappStory story in storiesExpirees) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.id)
            .update({
          'stories': FieldValue.arrayRemove([story.toJson()])
        });
        // Retirer localement pour la suite
        user.stories?.remove(story);
      }

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

  Future<bool> supprimerStories(UserData user, int index) async {
    if (index >= 0 && index < (user.stories?.length ?? 0)) {
      var story = user.stories![index];

      try {
        // Supprime le fichier si besoin
        if (story.media != null && story.media!.isNotEmpty && story.media!.length > 5) {
          // await deleteFileFromUrl(story.media!);
        }

        // Supprimer directement l'objet story dans Firestore
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.id)
            .update({
          'stories': FieldValue.arrayRemove([story.toJson()])
        });

        // Supprimer localement pour garder les données à jour
        user.stories?.removeAt(index);

        print('Élément supprimé à l\'index $index');
        return true;
      } catch (e) {
        print('Erreur lors de la suppression: $e');
        return false;
      }
    } else {
      print('Index invalide');
      return false;
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
        // 'popularite': _calculatePopularity(loginUserData!),
        // 'compteTarif': loginUserData!.popularite! * 80,
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


      //
      // await FirebaseFirestore.instance
      //     .collection('Users')
      //     .doc(user.id)
      //     .update(user.toJson());
      // printVm("user update : ${user!.toJson()}");
      return true;
    }catch(e){
      printVm("erreur update post : ${e}");
      return false;
    }
  }
  Future<bool> updateUserCountryCode(UserData user) async {
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

  Future<void> sendPushNotificationToUsers({
    required UserData sender,
    required String message,
    required String typeNotif,
    String? postId,
    String? postType,
    String? chatId,
    String? smallImage,
    bool isChannel = false,       // Indique si c’est un canal
    String? channelTitle,         // Titre du canal si applicable
  }) async {
    try {
      // 🔹 Étape 1 : Déterminer les cibles selon le rôle
      List<UserData> targets = [];

      if (sender.role == UserRole.ADM.name) {
        // Admin → tous les utilisateurs
        targets = await getAllUsers();
      } else {
        // Utilisateur simple → seulement ses abonnés
        if (sender.userAbonnesIds != null && sender.userAbonnesIds!.isNotEmpty) {
          targets = await getUsersByIds(sender.userAbonnesIds!);
        } else {
          print("⚠️ L'utilisateur ${sender.pseudo} n’a aucun abonné.");
          return;
        }
      }

      if (targets.isEmpty) {
        print("📭 Aucun utilisateur cible trouvé.");
        return;
      }

      // 🔹 Étape 2 : Filtrer les utilisateurs éligibles
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      const oneHour = 60 * 60 * 1000;

      final List<String> validUserIds = [];

      for (final user in targets) {
        final lastNotif = user.lastNotificationTime ?? 0;
        final timeSinceLast = currentTime - lastNotif;

        final canReceive = sender.role == 'ADM' || timeSinceLast >= oneHour;

        if (canReceive &&
            user.oneIgnalUserid != null &&
            user.oneIgnalUserid!.isNotEmpty &&
            user.oneIgnalUserid!.length > 5) {
          validUserIds.add(user.oneIgnalUserid!);

          // Mettre à jour la date de dernière notification
          await updateUserLastNotifTime(user.id!, currentTime);
        }
      }

      if (validUserIds.isEmpty) {
        print("📭 Aucun utilisateur éligible à recevoir la notification.");
        return;
      }

      // 🔹 Étape 3 : Déterminer l'appName dynamiquement
      String appName;
      if (isChannel && channelTitle != null && channelTitle.isNotEmpty) {
        appName = "#$channelTitle";   // Notification venant d’un canal
      } else {
        appName = "@${sender.pseudo}"; // Notification venant d’un utilisateur
      }

      // 🔹 Étape 4 : Envoi via OneSignal
      await sendNotification(
        appName: appName,
        userIds: validUserIds,
        smallImage: smallImage ?? "",
        send_user_id: sender.id!,
        recever_user_id: "", // multiple, donc vide
        message: message,
        type_notif: typeNotif,
        post_id: postId ?? "",
        post_type: postType ?? "",
        chat_id: chatId ?? "",
      );

      print("✅ Notification envoyée à ${validUserIds.length} utilisateurs !");
    } catch (e) {
      print("❌ Erreur lors de l’envoi de la notification : $e");
    }
  }


  Future<void> updateUserLastNotifTime(String userId, int time) async {
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .update({'lastNotificationTime': time});
    } catch (e) {
      print("⚠️ Erreur maj lastNotificationTime : $e");
    }
  }
// Récupère tous les utilisateurs (réservé à l'admin)
  Future<List<UserData>> getAllUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('Users').get();
    return snapshot.docs.map((doc) => UserData.fromJson(doc.data())).toList();
  }

// Récupère uniquement les utilisateurs dont l’ID est dans la liste
  Future<List<UserData>> getUsersByIds(List<String> ids) async {
    // ⚠️ Firebase limite les requêtes whereIn à 10 éléments max
    final List<UserData> users = [];

    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      users.addAll(snapshot.docs.map((doc) => UserData.fromJson(doc.data())));
    }

    return users;
  }



  Future<void> sendSingleNotification({
    required UserData sender,
    required UserData receiver,
    required String message,
    required String typeNotif,
    String? postId,
    String? postType,
    String? chatId,
    String? smallImage,
  }) async {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    const oneHour = 60 * 60 * 1000;
    final lastNotif = receiver.lastNotificationTime ?? 0;
    final canReceive = sender.role == 'ADM' || (currentTime - lastNotif) >= oneHour;

    if (!canReceive) {
      print("🚫 ${receiver.pseudo} a déjà reçu une notif il y a moins d’une heure");
      return;
    }

    if (receiver.oneIgnalUserid == null || receiver.oneIgnalUserid!.length < 5) {
      print("⚠️ Pas d’ID OneSignal valide pour ${receiver.pseudo}");
      return;
    }

    await sendNotification(
      appName: "#${sender.pseudo}",
      userIds: [receiver.oneIgnalUserid!],
      smallImage: smallImage ?? "",
      send_user_id: sender.id!,
      recever_user_id: receiver.id!,
      message: message,
      type_notif: typeNotif,
      post_id: postId ?? "",
      post_type: postType ?? "",
      chat_id: chatId ?? "",
    );

    await updateUserLastNotifTime(receiver.id!, currentTime);
    print("✅ Notification envoyée à ${receiver.pseudo}");
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
      addPointsForAction(UserAction.abonne);
      addPointsForOtherUserAction(updateUserData.id!, UserAction.autre);
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
  Future<void> sendNotification({  String? appName, // ✅ paramètre optionnel
    required List<String> userIds, required String smallImage,required String send_user_id, required String recever_user_id,required String message,required String type_notif,required String post_id,required String post_type,required String chat_id}) async {
    final String usedAppName = appName ?? "AfroLook"; // valeur par défaut

    String oneSignalUrl = '';
    String applogo = '';
    String oneSignalAppId = ''; // Replace with your app ID
    String oneSignalAuthorization = ''; // Replace with your authorization key
    getAppData().then((app_datas) async {

        printVm(
            'app  data*** ');
        // printVm(appDefaultData.toJson());
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

          "headings": {"en": usedAppName},
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

          _showUpdateModal(context);
          // showModalBottomSheet(
          //   context: context,
          //   builder: (BuildContext context) {
          //     return Container(
          //       height: 300,
          //       child: Center(
          //         child: Padding(
          //           padding: const EdgeInsets.all(20.0),
          //           child: Column(
          //             mainAxisAlignment: MainAxisAlignment.center,
          //             crossAxisAlignment: CrossAxisAlignment.center,
          //             children: [
          //               Icon(Icons.info, color: Colors.red),
          //               Text(
          //                 'Nouvelle mise à jour disponible!',
          //                 style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
          //               ),
          //               SizedBox(height: 10.0),
          //               Text(
          //                 'Une nouvelle version de l\'application est disponible. Veuillez télécharger la mise à jour pour profiter des dernières fonctionnalités et améliorations.',
          //                 style: TextStyle(fontSize: 16.0),
          //               ),
          //               SizedBox(height: 20.0),
          //               ElevatedButton(
          //                 style: ElevatedButton.styleFrom(
          //                   backgroundColor: Colors.green,
          //                 ),
          //                 onPressed: () {
          //                   _launchUrl(Uri.parse('${appDefaultData.app_link}'));
          //                 },
          //                 child: Row(
          //                   mainAxisAlignment: MainAxisAlignment.center,
          //                   children: [
          //                     Icon(Ionicons.ios_logo_google_playstore, color: Colors.white),
          //                     SizedBox(width: 5),
          //                     Text(
          //                       'Télécharger sur le play store',
          //                       style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          //                     ),
          //                   ],
          //                 ),
          //               ),
          //             ],
          //           ),
          //         ),
          //       ),
          //     );
          //   },
          // );
        }

      }else{
        onSuccess();

      }

    });
  }
  void _showUpdateModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false, // ❌ Empêche de fermer en cliquant dehors
      enableDrag: false,    // ❌ Empêche de glisser pour fermer
      backgroundColor: Colors.transparent, // Pour avoir un fond arrondi stylé
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.yellow.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barre décorative verte
              Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),

              // Icône principale 🟡
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade600,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.yellow.withOpacity(0.4),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: Colors.black,
                  size: 45,
                ),
              ),
              const SizedBox(height: 20),

              // Titre 💚
              Text(
                'Mise à jour disponible !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.greenAccent.shade400,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Description 🖤
              Text(
                'Une nouvelle version d’AfroLook est disponible.\n\n'
                    'Téléchargez-la maintenant pour profiter des dernières fonctionnalités, d’une meilleure sécurité et d’une expérience encore plus fluide !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 25),

              // Bouton principal 💛
              ElevatedButton.icon(
                onPressed: () {
                  _launchUrl(Uri.parse('${appDefaultData.app_link}'));
                },
                icon: const Icon(Icons.play_arrow, color: Colors.black),
                label: const Text(
                  'Mettre à jour sur Play Store',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
              const SizedBox(height: 10),

              // Bouton secondaire (désactivé ou non selon ton besoin)
              TextButton(
                onPressed: () {
                  // 👇 Si tu veux le rendre 100% obligatoire, commente cette ligne :
                  // Navigator.of(context).pop();
                },
                child: Text(
                  'Plus tard',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> initiateDeposit(double amount, UserData userdata) async {
    try {
      // Appelez cette fonction avant d'appeler initiateDeposit
      await debugAuthentication();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('initiateAfrolookDeposit');

      final result = await callable.call(<String, dynamic>{
        'amount': amount,
        'userId': user.uid, // Utiliser l'UID de l'utilisateur connecté
      }).timeout(const Duration(seconds: 30));

      // Vérification de la réponse
      if (result.data != null &&
          result.data is Map<String, dynamic> &&
          result.data['payment_url'] != null) {

        return {
          'payment_url': result.data['payment_url'],
          'transaction_id': result.data['transaction_id'],
          'deposit_number': result.data['deposit_number'],
          'success': true,
        };
      } else {
        throw Exception('Réponse invalide de la fonction cloud');
      }

    } on FirebaseAuthException catch (e) {
      throw Exception('Erreur d\'authentification: ${e.message}');
    } on FirebaseFunctionsException catch (e) {
      // Gestion spécifique des erreurs Firebase Functions
      final code = e.code;
      final message = e.message ?? 'Erreur inconnue';

      switch (code) {
        case 'invalid-argument':
          throw Exception('Montant invalide: $message');
        case 'unauthenticated':
          throw Exception('Vous devez être connecté pour effectuer un dépôt');
        case 'not-found':
          throw Exception('Utilisateur non trouvé');
        case 'internal':
          throw Exception('Erreur interne du serveur: $message');
        default:
          throw Exception('Erreur lors du dépôt: $message');
      }
    } catch (e) {
      throw Exception('Erreur lors de l\'initialisation du dépôt: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> initiateDeposit3(double amount, UserData userdata) async {
    try {

      // Pour les tests en développement, vous pouvez utiliser l'émulateur
      // functions.useFunctionsEmulator('localhost', 5001);
      final user = FirebaseAuth.instance.currentUser;
      printVm('Erreur Firebase user : ${user!.uid!}');
      printVm('Erreur Firebase userdata: ${userdata.id}');
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }
      final functions = FirebaseFunctions.instance;

      // printVm('Erreur Firebase user : ${user.uid}');
      // printVm('Erreur Firebase userdata: ${userdata.id}');
      final callable = functions.httpsCallable('initiateAfrolookDeposit');

      // Appel de la fonction avec timeout
      final result = await callable.call(<String, dynamic>{
        'amount': amount,
        'userId': user.uid,
      }).timeout(const Duration(seconds: 30));

      // Vérification de la réponse
      if (result.data != null &&
          result.data is Map<String, dynamic> &&
          result.data['payment_url'] != null) {

        return {
          'payment_url': result.data['payment_url'],
          'transaction_id': result.data['transaction_id'],
          'deposit_number': result.data['deposit_number'],
          'success': true,
        };
      } else {
        throw Exception('Réponse invalide de la fonction cloud');
      }

    } on FirebaseFunctionsException catch (e) {
      // Gestion spécifique des erreurs Firebase Functions
      final code = e.code;
      final message = e.message ?? 'Erreur inconnue';
      final details = e.details ?? '';
      printVm('Erreur Firebase: ${e.code}');
      printVm('Erreur Firebase: ${e.message}');
      printVm('Erreur Firebase: ${e.details}');
      switch (code) {
        case 'invalid-argument':
          throw Exception('Montant invalide: $message');
        case 'unauthenticated':
          throw Exception('Vous devez être connecté pour effectuer un dépôt');
        case 'not-found':
          throw Exception('Utilisateur non trouvé');
        case 'internal':
          throw Exception('Erreur interne du serveur: $message');
        default:
          throw Exception('Erreur lors du dépôt: $message');
      }

    } on FirebaseException catch (e) {
      // Erreurs Firebase générales
      throw Exception('Erreur Firebase: ${e.message}');

    } catch (e) {
      // Erreurs générales
      throw Exception('Erreur lors de l\'initialisation du dépôt: ${e.toString()}');
    }
  }

  Future<void> debugAuthentication() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      print('=== DEBUG AUTHENTICATION ===');
      print('Current User: ${user?.uid}');
      print('Email: ${user?.email}');
      print('Is Anonymous: ${user?.isAnonymous}');

      if (user != null) {
        // Vérifier le token d'authentification
        final idTokenResult = await user.getIdTokenResult(true);
        print('Token expiration: ${idTokenResult.expirationTime}');
        print('Token issued at: ${idTokenResult.issuedAtTime}');
        print('Token claims: ${idTokenResult.claims}');
        print('Token valid: ${idTokenResult.expirationTime!.isAfter(DateTime.now())}');

        // Vérifier les providers d'authentification
        for (final provider in user.providerData) {
          print('Provider: ${provider.providerId}, UID: ${provider.uid}');
        }
      }

      // Vérifier la configuration Firebase
      final app = Firebase.app();
      print('Firebase App: ${app.name}');
      print('Firebase Options: ${app.options.projectId}');

    } catch (e) {
      print('Error in debugAuthentication: $e');
    }
  }

  Stream<UserData> getUserStream() {
    final uid = loginUserData.id;
    if (uid == null) throw Exception("User ID manquant");
    return FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .snapshots()
        .map((doc) => UserData.fromJson(doc.data()!));
  }

  /// Retourne directement le Stream des données AppDefaultData
  Stream<AppDefaultData> getAppDataStream() {
    const documentId = "XgkSxKc10vWsJJ2uBraT"; // ID du document Firestore

    return FirebaseFirestore.instance
        .collection("AppData")
        .doc(documentId)
        .snapshots()
        .map((documentSnapshot) {
      if (documentSnapshot.exists) {
        final data = documentSnapshot.data() as Map<String, dynamic>;
        data['id'] = documentSnapshot.id;
        return AppDefaultData.fromJson(data);
      } else {
        // Retourner des données par défaut si le document n'existe pas
        return AppDefaultData();
      }
    });
  }



}

Future<void> addPointsForAction(UserAction action) async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;

  // 1. Récupérer l'utilisateur connecté
  final currentUser = auth.currentUser;
  if (currentUser == null) {
    throw Exception("Aucun utilisateur connecté");
  }

  final userRef = db.collection("Users").doc(currentUser.uid);
  final appRef = db.collection("AppData").doc("XgkSxKc10vWsJJ2uBraT");

  // 2. Récupérer points pour l'action
  int pointsToAdd = ActionPoints.getPoints(action);

  // 3. Récupérer les données actuelles
  final userSnapshot = await userRef.get();
  final appSnapshot = await appRef.get();

  int oldUserPoints = (userSnapshot.data() as Map?)?["totalPoints"] ?? 0;
  int oldAppPoints = (appSnapshot.data() as Map?)?["appTotalPoints"] ?? 0;

  // 4. Calculer nouvelles valeurs
  int newUserPoints = oldUserPoints + pointsToAdd;
  int newAppPoints = oldAppPoints + pointsToAdd;

  double newPopularity = newAppPoints == 0
      ? 0
      : (newUserPoints / newAppPoints) * 100;

  // 5. Mise à jour Firestore
  await userRef.update({
    "totalPoints": newUserPoints,
    "popularite": newPopularity,
  });

  await appRef.update({
    "appTotalPoints": newAppPoints,
  });
}

Future<void> addPointsForOtherUserAction(String userid,UserAction action) async {
  final FirebaseFirestore db = FirebaseFirestore.instance;



  final userRef = db.collection("Users").doc(userid);
  final appRef = db.collection("AppData").doc("XgkSxKc10vWsJJ2uBraT");

  // 2. Récupérer points pour l'action
  int pointsToAdd = ActionPoints.getPoints(action);

  // 3. Récupérer les données actuelles
  final userSnapshot = await userRef.get();
  final appSnapshot = await appRef.get();

  int oldUserPoints = (userSnapshot.data() as Map?)?["totalPoints"] ?? 0;
  int oldAppPoints = (appSnapshot.data() as Map?)?["appTotalPoints"] ?? 0;

  // 4. Calculer nouvelles valeurs
  int newUserPoints = oldUserPoints + pointsToAdd;
  int newAppPoints = oldAppPoints + pointsToAdd;

  double newPopularity = newAppPoints == 0
      ? 0
      : (newUserPoints / newAppPoints) * 100;

  // 5. Mise à jour Firestore
  await userRef.update({
    "totalPoints": newUserPoints,
    "popularite": newPopularity,
  });

  await appRef.update({
    "appTotalPoints": newAppPoints,
  });
}
