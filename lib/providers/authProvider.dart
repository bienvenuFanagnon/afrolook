import 'dart:async';
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
  late int app_version_code = 169;
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
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseFunctions functions = FirebaseFunctions.instance;

  /// Rafraîchit les données de l'utilisateur connecté depuis Firestore
  Future<void> refreshUserData() async {
    try {
      // Vérifier si l'utilisateur est connecté
      if (loginUserData.id == null || loginUserData.id!.isEmpty) {
        print('❌ Impossible de rafraîchir: Aucun ID utilisateur trouvé');
        return;
      }


      // Récupérer les données fraîches depuis Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(loginUserData.id!)
          .get();

      if (!userDoc.exists) {
        print('❌ Utilisateur non trouvé dans Firestore');
        return;
      }

      // Mettre à jour les données locales
      final updatedData = UserData.fromJson(userDoc.data()!);

      // Conserver certaines données non modifiées dans Firestore
      updatedData.oneIgnalUserid = loginUserData.oneIgnalUserid;

      // Mettre à jour l'objet principal
      loginUserData = updatedData;

      // Notifier les listeners du changement
      notifyListeners();

      print('✅ Données utilisateur rafraîchies avec succès');

    } catch (e) {
      print('❌ Erreur lors du rafraîchissement: $e');
      rethrow;
    } finally {
    }
  }
  /// durée par défaut = 7 jours
  static Duration postRefreshDuration = const Duration(days: 7);

  /// Permet de changer dynamiquement la durée
  static void setRefreshDuration(Duration duration) {
    postRefreshDuration = duration;
  }
  Future<bool> changeStateUser({required UserData user, required String state, required bool isConnected}) async {
    final String previousState = user.state ?? ''; // Sauvegarde de l'ancien state

    try {
      // Mise à jour optimisée dans Firebase
      final updateData = <String, dynamic>{
        'state': state,
        'isConnected': isConnected,
        // 'last_time_active': FieldValue.serverTimestamp()
      };

      await firestore.collection('Users').doc(user.id).update(updateData);

      // Mise à jour locale uniquement après succès
      user.state = state;
      notifyListeners();

      printVm('State utilisateur mis à jour avec succès: $state');
      return true;

    } catch (e, stackTrace) {
      printVm('Échec mise à jour state: $e');
      printVm('Stack trace: $stackTrace');

      // Garder l'ancien state en cas d'erreur
      user.state = previousState;
      notifyListeners();

      return false;
    }
  }

  Future<void> logout(BuildContext context) async {
    try {
      // 1️⃣ Déconnexion Firebase (OBLIGATOIRE)
      await FirebaseAuth.instance.signOut();

      print("✅ Firebase déconnecté");

      // 2️⃣ Mettre l'utilisateur offline (backend / Firestore)
      if (loginUserData != null) {
        loginUserData!.isConnected = false;

        await changeStateUser(
          user: loginUserData,
          state: UserState.OFFLINE.name,
          isConnected: false,
        );
      }

      // 3️⃣ Supprimer token local (Laravel ou autre)
      await storeToken('');

      // 4️⃣ Nettoyer données locales (optionnel mais recommandé)
      // await authProvider.clearAll();

      // 5️⃣ Redirection propre (reset stack)
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          "/login",
              (route) => false,
        );
      }

    } catch (e) {
      print("❌ Erreur lors de la déconnexion: $e");
    }
  }
  /// Fonction principale
   Future<void> checkAndRefreshPostDates(String postId) async {
    try {
      print("✅ Post checkAndRefreshPostDates $postId encours de changement de date");

      final doc = await _firestore
          .collection('Posts')
          .doc(postId)
          .get();

      if (!doc.exists) return;

      final data = doc.data()!;
      final int? updatedAt = data['updated_at'];
      print("✅ Post checkAndRefreshPostDates updatedAt $updatedAt");

      if (updatedAt == null) return;

      final now = DateTime.now().microsecondsSinceEpoch;

      final age = now - updatedAt;

      if (age >= postRefreshDuration.inMicroseconds) {

        await _firestore
            .collection('Posts')
            .doc(postId)
            .update({
          // 'created_at': now,
          'updated_at': now,
        });

        print("✅ Post checkAndRefreshPostDates $postId rafraîchi automatiquement");
      }

    } catch (e) {
      print("❌ checkAndRefreshPostDates error: $e");
    }
  }

  initializeData() {
    registerUser = UserData();
  }
  Future<void> incrementPostTotalInteractions({
    required String postId,
    int incrementValue = 1,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(postId)
          .update({
        'totalInteractions': FieldValue.increment(incrementValue),
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });

      print("✅ totalInteractions +$incrementValue pour le post $postId");

    } catch (e) {
      print("❌ Erreur incrementPostTotalInteractions: $e");
    }
  }
  Future<void> ajouterCommissionParrainViaUserId({
    required String userId,
    required double montant,
  }) async {
    final firestore = FirebaseFirestore.instance;

    // 1️⃣ Récupérer l'utilisateur via son ID
    final userDoc = await firestore.collection('Users').doc(userId).get();

    if (!userDoc.exists) {
      print("⚠️ Utilisateur introuvable avec cet ID");
      return;
    }

    final userData = userDoc.data();
    if (userData == null || userData['code_parrain'] == null || userData['code_parrain'] == "") {
      print("⚠️ Cet utilisateur n'a pas de parrain");
      return;
    }

    final String codeParrain = userData['code_parrain'];

    // 2️⃣ Récupérer le parrain via son code
    final query = await firestore
        .collection('Users')
        .where('code_parrainage', isEqualTo: codeParrain)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      print("⚠️ Aucun parrain trouvé avec ce code");
      await firestore.collection('AppData').doc(appDefaultData.id).update({
        'solde_gain': FieldValue.increment(montant * 0.025),
      });
      return;
    }

    final DocumentSnapshot parrainDoc = query.docs.first;
    final DocumentReference parrainRef = parrainDoc.reference;
    final String parrainId = parrainDoc.id;

    // 3️⃣ Calcul des 5%
    final double commission = montant * 0.025;

    // 4️⃣ Incrémentation du solde du parrain
    await parrainRef.update({
      "votre_solde_principal": FieldValue.increment(commission),
      "updatedAt": FieldValue.serverTimestamp(),
    });

    // 5️⃣ Enregistrement de la transaction GAIN
    final transactionRef = firestore.collection("TransactionSoldes").doc();

    await transactionRef.set({
      "id": transactionRef.id,
      "user_id": parrainId,
      "type": "GAIN",
      "statut": "VALIDER",
      "description": "Commission de parrainage (5%) d'un filleul",
      "montant": commission,
      "montant_total": commission,
      "numero_depot": null,
      "methode_paiement": "COMMISSION",
      "frais": 0,
      "frais_operateur": 0,
      "frais_gain": 0,
      "id_transaction_paygate": null,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
    });

    print("✅ Commission de $commission FCFA ajoutée au parrain et transaction créée.");
  }

  Future<void> ajouterCommissionParrain({
    required String codeParrainage,
    required double montant,
  }) async
  {
    final firestore = FirebaseFirestore.instance;

    // 1️⃣ Récupérer le parrain via son code
    final query = await firestore
        .collection('Users')
        .where('code_parrainage', isEqualTo: codeParrainage)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      print("⚠️ Aucun parrain trouvé avec ce code");
      return;
    }

    final DocumentSnapshot parrainDoc = query.docs.first;
    final DocumentReference parrainRef = parrainDoc.reference;
    final String parrainId = parrainDoc.id;

    // 2️⃣ Calcul des 5%
    final double commission = montant * 0.05;

    // 3️⃣ Incrémentation du solde du parrain
    await parrainRef.update({
      "votre_solde_principal": FieldValue.increment(commission),
      "updatedAt": FieldValue.serverTimestamp(),
    });

    // 4️⃣ Enregistrement de la transaction GAIN
    final transactionRef =
    firestore.collection("TransactionSoldes").doc();

    await transactionRef.set({
      "id": transactionRef.id,
      "user_id": parrainId,
      "type": "GAIN", // 👌 Type correct pour commission
      "statut": "VALIDER",
      "description": "Commission de parrainage (5%) sur dépôt filleul",
      "montant": commission,
      "montant_total": commission,
      // Tu peux mettre null si pas utilisé
      "numero_depot": null,
      "methode_paiement": "COMMISSION",
      "frais": 0,
      "frais_operateur": 0,
      "frais_gain": 0,
      "id_transaction_paygate": null,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
    });

    print("✅ Commission de $commission FCFA ajoutée et transaction créée.");
  }

  Future<void> ajouterCadeauCommissionParrain({
    required String codeParrainage,
    required double montant,
  }) async
  {
    final firestore = FirebaseFirestore.instance;

    // 1️⃣ Récupérer le parrain via son code
    final query = await firestore
        .collection('Users')
        .where('code_parrainage', isEqualTo: codeParrainage)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      print("⚠️ Aucun parrain trouvé avec ce code");
      return;
    }

    final DocumentSnapshot parrainDoc = query.docs.first;
    final DocumentReference parrainRef = parrainDoc.reference;
    final String parrainId = parrainDoc.id;

    // 2️⃣ Calcul des 5%
    final double commission = montant * 0.025;

    // 3️⃣ Incrémentation du solde du parrain
    await parrainRef.update({
      "votre_solde_principal": FieldValue.increment(commission),
      // "updatedAt": FieldValue.serverTimestamp(),
    });

    // 4️⃣ Enregistrement de la transaction GAIN
    final transactionRef =
    firestore.collection("TransactionSoldes").doc();

    await transactionRef.set({
      "id": transactionRef.id,
      "user_id": parrainId,
      "type": "GAIN", // 👌 Type correct pour commission
      "statut": "VALIDER",
      "description": "Commission de parrainage (5%) sur dépôt filleul",
      "montant": commission,
      "montant_total": commission,
      // Tu peux mettre null si pas utilisé
      "numero_depot": null,
      "methode_paiement": "COMMISSION",
      "frais": 0,
      "frais_operateur": 0,
      "frais_gain": 0,
      "id_transaction_paygate": null,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
    });

    print("✅ Commission de $commission FCFA ajoutée et transaction créée.");
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

  Stream<List<NotificationData>> getListNotificationAuth2(String user_id) async* {
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
  Stream<List<NotificationData>> getListNotificationAuth(String user_id) async* {
    var postStream = FirebaseFirestore.instance
        .collection('Notifications')
        .where("receiver_id", isEqualTo: user_id)
        .orderBy('created_at', descending: true)
        .limit(12)                              // 🔥 Limite à 12 résultats
        .snapshots();

    await for (var snapshot in postStream) {
      List<NotificationData> notifications = [];

      for (var post in snapshot.docs) {
        NotificationData notification = NotificationData.fromJson(post.data());

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
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.id)
          .update({
        "countryData": user.countryData, // ✅ uniquement ce champ
      });

      printVm("countryData update : ${user.countryData}");
      return true;
    } catch (e) {
      printVm("erreur update countryData : $e");
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
  Future<void> sendPushToSpecificUsers({
    required List<String> userIds,
    required UserData sender,
    required String message,
    required String typeNotif,
    String? postId,
    String? postType,
    String? chatId,
    String? smallImage,
  }) async
  {
    try {
      if (userIds.isEmpty) {
        print("📭 Aucun utilisateur cible.");
        return;
      }

      // 🔹 Nettoyage des doublons
      final targetUserIds = userIds.toSet().toList();

      final appName = "@${sender.pseudo}";

      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final notifTime = DateTime.now().microsecondsSinceEpoch;
      final oneHour = 60 * 60 * 1000;

      final List<String> validOneSignalIds = [];

      const batchSize = 100;

      for (var i = 0; i < targetUserIds.length; i += batchSize) {
        final end = i + batchSize > targetUserIds.length
            ? targetUserIds.length
            : i + batchSize;

        final batchIds = targetUserIds.sublist(i, end);

        final usersBatch = await getUsersByIds(batchIds);

        final batchResults = await Future.wait(
          usersBatch.map((user) => _processUserNotification(
            user: user,
            sender: sender,
            appName: appName,
            isChannel: false,
            canal: null,
            truncatedMessage: message,
            postId: postId,
            postType: postType,
            notifTime: notifTime,
            currentTime: currentTime,
            oneHour: oneHour,
            smallImage: smallImage,
          )),
        );

        for (final result in batchResults) {
          if (result.isValid) {
            validOneSignalIds.add(result.oneSignalId);
          }
        }
      }

      // 🔥 Envoi direct push
      if (validOneSignalIds.isNotEmpty) {
        await _sendPushNotificationNow(
          appName: appName,
          userIds: validOneSignalIds,
          smallImage: smallImage ?? sender.imageUrl ?? "",
          senderId: sender.id!,
          message: message,
          typeNotif: typeNotif,
          postId: postId,
          postType: postType,
          chatId: chatId,
        );
      }

      print("✅ Push envoyée à ${targetUserIds.length} utilisateurs !");
    } catch (e) {
      print("❌ Erreur envoi push : $e");
    }
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
    bool isChannel = false,
    String? channelTitle,
    Canal? canal,
  })
  async {
    try {
      // Déterminer le type de cible
      String targetType = "subscribers";
      List<String>? specificUserIds;

      if (sender.role == UserRole.ADM.name) {
        targetType = "all";
      } else if (isChannel && canal != null) {
        targetType = "channel";
      }

      // ✅ Appel à la fonction cloud - tout est géré côté serveur
      final result = await FirebaseFunctions.instance
          .httpsCallable('sendBulkNotification')
          .call({
        'senderId': sender.id,
        'message': message,
        'typeNotif': typeNotif,
        'postId': postId,
        'postType': postType,
        'chatId': chatId,
        'smallImage': smallImage,
        'isChannel': isChannel,
        'channelTitle': channelTitle,
        'canalId': canal?.id,
        'targetType': targetType,
        'specificUserIds': specificUserIds,
      });

      print('✅ Notifications traitées: ${result.data}');

      // Afficher les stats
      final data = result.data as Map;
      print('📊 Statistiques:');
      print('   - Notifications enregistrées: ${data['notificationsSaved']}');
      print('   - Push notifications envoyées: ${data['pushSent']}');
      print('   - Push limitées (1h): ${data['pushLimited']}');

    } catch (e) {
      print('❌ Erreur: $e');
    }
  }  Future<void> sendPushNotificationToUsersPronostic({
    required UserData sender,
    required String message,
    required String typeNotif,
    String? postId,
    String? postType,
    String? chatId,
    String? smallImage,
    bool isChannel = false,
    String? channelTitle,
    Canal? canal,
  })
  async {
    try {
      // Déterminer le type de cible
      String targetType = "all";
      List<String>? specificUserIds;

      // if (sender.role == UserRole.ADM.name) {
      //   targetType = "all";
      // } else if (isChannel && canal != null) {
      //   targetType = "channel";
      // }

      // ✅ Appel à la fonction cloud - tout est géré côté serveur
      final result = await FirebaseFunctions.instance
          .httpsCallable('sendBulkNotification')
          .call({
        'senderId': sender.id,
        'message': message,
        'typeNotif': typeNotif,
        'postId': postId,
        'postType': postType,
        'chatId': chatId,
        'smallImage': smallImage,
        'isChannel': isChannel,
        'channelTitle': channelTitle,
        'canalId': canal?.id,
        'targetType': targetType,
        'specificUserIds': specificUserIds,
      });

      print('✅ Notifications traitées: ${result.data}');

      // Afficher les stats
      final data = result.data as Map;
      print('📊 Statistiques:');
      print('   - Notifications enregistrées: ${data['notificationsSaved']}');
      print('   - Push notifications envoyées: ${data['pushSent']}');
      print('   - Push limitées (1h): ${data['pushLimited']}');

    } catch (e) {
      print('❌ Erreur: $e');
    }
  }
  Future<void> incrementCreatorCoins(String creatorId) async {
    try {
      final creatorRef = _firestore.collection('Users').doc(creatorId);
      await creatorRef.update({
        'totalCoinsEarnedFromAdSupport': FieldValue.increment(1),
      });
      print('✅ +10 pièces pour créateur: $creatorId');
    } catch (e) {
      print('❌ Erreur: $e');
    }
  }
  Future<void> sendPushNotificationToUsers2({
    required UserData sender,
    required String message,
    required String typeNotif,
    String? postId,
    String? postType,
    String? chatId,
    String? smallImage,
    bool isChannel = false,
    String? channelTitle,
    Canal? canal,
  })
  async {
    try {
      // 🔹 Étape 1 : Préparer les IDs cibles
      List<String> targetUserIds = [];

      if (sender.role == UserRole.ADM.name) {
        final allUsers = await getAllUsers();
        targetUserIds = allUsers.map((u) => u.id!).toList();
      } else {
        if (sender.userAbonnesIds != null && sender.userAbonnesIds!.isNotEmpty) {
          targetUserIds.addAll(sender.userAbonnesIds!);
        }

        if (isChannel && canal != null) {
          if (canal.usersSuiviId != null) {
            targetUserIds.addAll(canal.usersSuiviId!);
          }
          if (canal.subscribersId != null) {
            targetUserIds.addAll(canal.subscribersId!);
          }
        }
      }

      // Éliminer les doublons
      targetUserIds = targetUserIds.toSet().toList();

      if (targetUserIds.isEmpty) {
        print("📭 Aucun utilisateur cible trouvé.");
        return;
      }

      // 🔹 Étape 2 : Séparer les opérations Firestore et Push
      final appName = isChannel && channelTitle != null && channelTitle.isNotEmpty
          ? "#$channelTitle"
          : "@${sender.pseudo}";

      final truncatedMessage = message.length > 200
          ? message.substring(0, 200)
          : message;

      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final notifTime = DateTime.now().microsecondsSinceEpoch;
      final oneHour = 60 * 60 * 1000;

      // 🔹 Étape 3 : Traiter en parallèle
      final List<String> validOneSignalIds = [];

      // Récupérer les utilisateurs par lots
      const batchSize = 100;
      for (var i = 0; i < targetUserIds.length; i += batchSize) {
        final end = i + batchSize > targetUserIds.length
            ? targetUserIds.length
            : i + batchSize;
        final batchIds = targetUserIds.sublist(i, end);

        final usersBatch = await getUsersByIds(batchIds);

        // Traiter ce lot
        final batchResults = await Future.wait(
            usersBatch.map((user) => _processUserNotification(
              user: user,
              sender: sender,
              appName: appName,
              isChannel: isChannel,
              canal: canal,
              truncatedMessage: truncatedMessage,
              postId: postId,
              postType: postType,
              notifTime: notifTime,
              currentTime: currentTime,
              oneHour: oneHour,
              smallImage: smallImage,
            ))
        );

        // Collecter les IDs OneSignal valides
        for (final result in batchResults) {
          if (result.isValid) {
            validOneSignalIds.add(result.oneSignalId);
          }
        }
      }

      // 🔹 Étape 4 : Envoyer la push notification sans attendre Firestore
      if (validOneSignalIds.isNotEmpty) {
        unawaited(_sendPushNotificationNow(
          appName: appName,
          userIds: validOneSignalIds,
          smallImage: smallImage ?? sender.imageUrl ?? "",
          senderId: sender.id!,
          message: message,
          typeNotif: typeNotif,
          postId: postId,
          postType: postType,
          chatId: chatId,
        ));
      }

      print("✅ Notifications traitées pour ${targetUserIds.length} utilisateurs !");

    } catch (e) {
      print("❌ Erreur lors de l’envoi de la notification : $e");
    }
  }
  Future<int> notifySubscribersOfInteraction({
    required String actionUserId,
    required String postOwnerId,
    required String postId,
    required String actionType,
    String? postDescription,
    String? commentaireMessage,
    String? postImageUrl,
    String? postDataType,
  }) async {
    int notifiedCount = 0;
    try {
      print('🔔 [notifySubscribers] Début pour action $actionType, post $postId');

      // 1. Récupérer les infos du post (pour le canal)
      final postDoc = await FirebaseFirestore.instance
          .collection('Posts')
          .doc(postId)
          .get();

      if (!postDoc.exists) {
        print('❌ [notifySubscribers] Post $postId introuvable');
        return 0;
      }

      final postData = postDoc.data()!;
      final canalId = postData['canal_id'] as String?;

      // 2. Infos de l'utilisateur qui agit
      final actionUserDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(actionUserId)
          .get();

      if (!actionUserDoc.exists) {
        print('❌ [notifySubscribers] Utilisateur action $actionUserId introuvable');
        return 0;
      }

      final actionUserData = actionUserDoc.data()!;
      final actionUserPseudo = actionUserData['pseudo'] ?? 'Utilisateur';
      final actionUserImage = actionUserData['imageUrl'] ?? '';

      // 3. Récupérer les abonnés de l'utilisateur acteur (ses followers)
      final List<String> followerIds = List<String>.from(actionUserData['userAbonnesIds'] ?? []);
      print('📢 [notifySubscribers] Utilisateur $actionUserPseudo a ${followerIds.length} abonnés');

      if (followerIds.isEmpty) {
        print('⚠️ [notifySubscribers] Aucun abonné pour l\'utilisateur acteur, arrêt');
        return 0;
      }

      // 4. Récupérer le nom du propriétaire du post pour le message
      String ownerName = '';
      if (canalId != null && canalId.isNotEmpty) {
        final canalDoc = await FirebaseFirestore.instance
            .collection('Canaux')
            .doc(canalId)
            .get();
        if (canalDoc.exists) {
          ownerName = '#${canalDoc.data()!['titre'] ?? "Canal"}';
        } else {
          ownerName = 'un canal';
        }
      } else {
        final postOwnerDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(postOwnerId)
            .get();
        if (postOwnerDoc.exists) {
          ownerName = '@${postOwnerDoc.data()!['pseudo'] ?? 'Utilisateur'}';
        } else {
          ownerName = 'quelqu\'un';
        }
      }

      // 5. Message selon le type d'action
      String actionMessage = "a aimé";
      String actionTitle = "Like ❤️";
      String finalPostDataType = postDataType ?? 'IMAGE';

      switch (actionType) {
        case 'comment':
          actionTitle = "Commentaire 💬";
          String shortMsg = commentaireMessage ?? '';
          if (shortMsg.length > 50) shortMsg = shortMsg.substring(0, 50) + '...';
          actionMessage = "a commenté : \"$shortMsg\"";
          finalPostDataType = 'COMMENT';
          break;
        case 'favorite':
          actionTitle = "Favoris ⭐";
          actionMessage = "a ajouté en favoris";
          break;
        case 'share':
          actionTitle = "Partage 🔄";
          actionMessage = "a partagé";
          break;
        default:
          actionTitle = "Like ❤️";
          actionMessage = "a aimé";
          break;
      }

      // 6. Troncature de la description
      String finalDescription = postDescription ?? '';
      if (finalDescription.length > 100) finalDescription = finalDescription.substring(0, 100) + '...';

      String imageUrl = postImageUrl ?? actionUserImage;
      final currentTime = DateTime.now().microsecondsSinceEpoch;
      const twentyMinutesMicros = 20 * 60 * 1000 * 1000; // 20 minutes en microsecondes

      // 7. Traiter les abonnés par lots (max 30 pour 'whereIn')
      for (int i = 0; i < followerIds.length; i += 30) {
        final end = (i + 30) > followerIds.length ? followerIds.length : i + 30;
        final batchIds = followerIds.sublist(i, end);

        final usersBatch = await FirebaseFirestore.instance
            .collection('Users')
            .where('id', whereIn: batchIds)
            .get();

        final List<String> oneSignalIds = [];

        for (var userDoc in usersBatch.docs) {
          final userId = userDoc.id;
          // Ne pas notifier l'utilisateur qui a fait l'action
          if (userId == actionUserId) continue;

          final userData = userDoc.data();
          final lastNotifTime = userData['lastNotificationTime'] as int? ?? 0;

          // ✅ Vérifier le délai de 20 minutes
          if (currentTime - lastNotifTime < twentyMinutesMicros && lastNotifTime != 0) {
            print('⏭️ [notifySubscribers] Utilisateur $userId déjà notifié il y a moins de 20 min, ignoré');
            continue;
          }

          // Créer la notification Firestore
          final notifId = FirebaseFirestore.instance.collection('Notifications').doc().id;
          final description = "@$actionUserPseudo $actionMessage  le post de $ownerName : \"$finalDescription\"";
if(actionType == 'comment'){
  final notification = NotificationData(
    id: notifId,
    titre: actionTitle,
    media_url: imageUrl,
    type: NotificationType.POST.name,
    description: description,
    users_id_view: [],
    user_id: actionUserId,
    receiver_id: userId,
    post_id: postId,
    post_data_type: finalPostDataType,
    createdAt: currentTime,
    updatedAt: currentTime,
    status: PostStatus.VALIDE.name,
  );

  await FirebaseFirestore.instance
      .collection('Notifications')
      .doc(notifId)
      .set(notification.toJson());

}

          // Mettre à jour le timestamp de la dernière notification
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(userId)
              .update({'lastNotificationTime': currentTime});

          notifiedCount++;

          // Préparer les push notifications
          final oneSignalId = userData['oneIgnalUserid'] as String?;
          if (oneSignalId != null && oneSignalId.length > 5) {
            oneSignalIds.add(oneSignalId);
          }
        }

        // Envoyer les push notifications (en arrière‑plan)
        if (oneSignalIds.isNotEmpty) {
          final pushMessage = "@$actionUserPseudo $actionMessage le post de $ownerName";

          unawaited(sendNotification(
            appName: actionTitle,
            userIds: oneSignalIds,
            smallImage: imageUrl,
            send_user_id: actionUserId,
            recever_user_id: '',
            message: pushMessage,
            type_notif: NotificationType.POST.name,
            post_id: postId,
            post_type: finalPostDataType,
            chat_id: '',
          ));
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('✅ [notifySubscribers] Terminé : $notifiedCount abonnés notifiés pour $actionType (sur ${followerIds.length} followers)');
      return notifiedCount;
    } catch (e) {
      print('❌ [notifySubscribers] Erreur: $e');
      return notifiedCount;
    }
  }

  // Future<void> notifySubscribersOfInteraction({
  //   required String actionUserId,      // L'utilisateur qui fait l'action
  //   required String postOwnerId,       // Le propriétaire du post
  //   required String postId,            // Le post concerné
  //   required String actionType,        // like, comment, favorite, share
  //   String? postDescription,
  //   String? postImageUrl,
  //   String? postDataType,
  // })
  // async {
  //   try {
  //     // ✅ 1. Récupérer les infos de l'utilisateur qui fait l'action
  //     final actionUserDoc = await FirebaseFirestore.instance
  //         .collection('Users')
  //         .doc(actionUserId)
  //         .get();
  //
  //     if (!actionUserDoc.exists) return;
  //
  //     final actionUserData = actionUserDoc.data()!;
  //     final actionUserPseudo = actionUserData['pseudo'] ?? 'Utilisateur';
  //     final actionUserImage = actionUserData['imageUrl'] ?? '';
  //
  //     // ✅ 2. Récupérer les infos du propriétaire du post
  //     final postOwnerDoc = await FirebaseFirestore.instance
  //         .collection('Users')
  //         .doc(postOwnerId)
  //         .get();
  //
  //     if (!postOwnerDoc.exists) return;
  //
  //     final postOwnerData = postOwnerDoc.data()!;
  //     final postOwnerPseudo = postOwnerData['pseudo'] ?? 'Utilisateur';
  //
  //     // ✅ 3. Récupérer les abonnés du propriétaire
  //     List<String> subscriberIds = [];
  //     if (postOwnerData['userAbonnesIds'] != null) {
  //       subscriberIds = List<String>.from(postOwnerData['userAbonnesIds']);
  //     }
  //
  //     if (subscriberIds.isEmpty) return;
  //
  //     // ✅ 4. Messages selon le type d'action
  //     String actionMessage = "a aimé";
  //     String actionTitle = "Like ❤️";
  //
  //     switch (actionType) {
  //       case 'comment':
  //         actionMessage = "a commenté";
  //         actionTitle = "Commentaire 💬";
  //         break;
  //       case 'favorite':
  //         actionMessage = "a ajouté en favoris";
  //         actionTitle = "Favoris ⭐";
  //         break;
  //       case 'share':
  //         actionMessage = "a partagé";
  //         actionTitle = "Partage 🔄";
  //         break;
  //     }
  //
  //     // ✅ 5. Préparer la description du post
  //     String finalDescription = postDescription ?? '';
  //     if (finalDescription.length > 100) {
  //       finalDescription = finalDescription.substring(0, 100) + '...';
  //     }
  //
  //     // ✅ 6. Image à utiliser
  //     String imageUrl = postImageUrl ?? actionUserImage;
  //
  //     // ✅ 7. Timestamp actuel
  //     final currentTime = DateTime.now().microsecondsSinceEpoch;
  //     const twentyMinutes = 20 * 60 * 1000 * 1000; // 20 minutes en microsecondes
  //
  //     // ✅ 8. Traiter les abonnés par lots (Firestore 'in' limit: 30)
  //     for (int i = 0; i < subscriberIds.length; i += 30) {
  //       final end = i + 30 > subscriberIds.length ? subscriberIds.length : i + 30;
  //       final batchIds = subscriberIds.sublist(i, end);
  //
  //       final usersBatch = await FirebaseFirestore.instance
  //           .collection('Users')
  //           .where('id', whereIn: batchIds)
  //           .get();
  //
  //       final List<String> oneSignalIds = [];
  //       final List<String> oneSignalUserIds = []; // Pour stocker les IDs des users avec OneSignal
  //
  //       for (var userDoc in usersBatch.docs) {
  //         final userData = userDoc.data();
  //         final lastNotifTime = userData['lastNotificationTime'] ?? 0;
  //
  //         // ✅ Vérifier le délai de 20 minutes
  //         if (currentTime - lastNotifTime >= twentyMinutes || lastNotifTime == 0) {
  //
  //           // ✅ Créer la notification Firebase
  //           final notifId = FirebaseFirestore.instance
  //               .collection('Notifications')
  //               .doc()
  //               .id;
  //
  //           final notification = {
  //             'id': notifId,
  //             'titre': actionTitle,
  //             'media_url': imageUrl,
  //             'type': actionType.toUpperCase(),
  //             'description': "@$actionUserPseudo $actionMessage le post de @$postOwnerPseudo : \"$finalDescription\"",
  //             'users_id_view': [],
  //             'user_id': actionUserId,
  //             'receiver_id': userDoc.id,
  //             'post_id': postId,
  //             'post_data_type': postDataType ?? 'IMAGE',
  //             'createdAt': currentTime,
  //             'updatedAt': currentTime,
  //             'status': 'VALIDE',
  //           };
  //
  //           // ✅ Sauvegarder la notification
  //           await FirebaseFirestore.instance
  //               .collection('Notifications')
  //               .doc(notifId)
  //               .set(notification);
  //
  //           // ✅ Mettre à jour le timestamp
  //           await FirebaseFirestore.instance
  //               .collection('Users')
  //               .doc(userDoc.id)
  //               .update({'lastNotificationTime': currentTime});
  //
  //           // ✅ Collecter pour la push notification
  //           if (userData['oneIgnalUserid'] != null &&
  //               (userData['oneIgnalUserid'] as String).length > 5) {
  //             oneSignalIds.add(userData['oneIgnalUserid']);
  //             oneSignalUserIds.add(userDoc.id);
  //           }
  //         }
  //       }
  //
  //       // ✅ Envoyer les push notifications avec votre fonction existante
  //       if (oneSignalIds.isNotEmpty) {
  //         final pushMessage = "@$actionUserPseudo $actionMessage le post de @$postOwnerPseudo";
  //
  //         // Utiliser votre sendNotification existante
  //         await sendNotification(
  //           appName: actionTitle,
  //           userIds: oneSignalIds,
  //           smallImage: imageUrl,
  //           send_user_id: actionUserId,
  //           recever_user_id: '', // Pas de receveur unique car multiple
  //           message: pushMessage,
  //           type_notif: actionType.toUpperCase(),
  //           post_id: postId,
  //           post_type: postDataType ?? 'IMAGE',
  //           chat_id: '',
  //         );
  //       }
  //
  //       // Petite pause entre les lots
  //       await Future.delayed(const Duration(milliseconds: 100));
  //     }
  //
  //   } catch (e) {
  //     print('❌ Erreur notifySubscribersOfInteraction: $e');
  //   }
  // }
// 🔹 Fonction helper pour traiter un utilisateur
  Future<_UserNotificationResult> _processUserNotification({
    required UserData user,
    required UserData sender,
    required String appName,
    required bool isChannel,
    required Canal? canal,
    required String truncatedMessage,
    required String? postId,
    required String? postType,
    required int notifTime,
    required int currentTime,
    required int oneHour,
    required String? smallImage,
  })
  async {
    try {
      final lastNotif = user.lastNotificationTime ?? 0;
      final timeSinceLast = currentTime - lastNotif;
      final canReceive = sender.role == 'ADM' || timeSinceLast >= oneHour;

      // 1. Enregistrer dans Firestore (sans attendre la fin)
      unawaited(_saveToFirestore(
        sender: sender,
        user: user,
        appName: appName,
        isChannel: isChannel,
        canal: canal,
        truncatedMessage: truncatedMessage,
        postId: postId,
        postType: postType,
        notifTime: notifTime,
        smallImage: smallImage,
      ));

      // 2. Vérifier si on peut envoyer une push
      if (canReceive &&
          user.oneIgnalUserid != null &&
          user.oneIgnalUserid!.isNotEmpty &&
          user.oneIgnalUserid!.length > 5) {

        // Mettre à jour le lastNotificationTime
        unawaited(updateUserLastNotifTime(user.id!, currentTime));

        return _UserNotificationResult(
          isValid: true,
          oneSignalId: user.oneIgnalUserid!,
        );
      }

      return _UserNotificationResult(isValid: false, oneSignalId: '');

    } catch (e) {
      print("❌ Erreur traitement utilisateur ${user.id}: $e");
      return _UserNotificationResult(isValid: false, oneSignalId: '');
    }
  }

// 🔹 Fonction pour sauvegarder dans Firestore (exécution différée)
  Future<void> _saveToFirestore({
    required UserData sender,
    required UserData user,
    required String appName,
    required bool isChannel,
    required Canal? canal,
    required String truncatedMessage,
    required String? postId,
    required String? postType,
    required int notifTime,
    required String? smallImage,
  })
  async {
    try {
      final firestore = FirebaseFirestore.instance;
      final notifId = firestore.collection('Notifications').doc().id;

      final notification = NotificationData(
        id: notifId,
        titre: "$appName a posté",
        media_url: isChannel ? canal?.urlImage : smallImage ?? sender.imageUrl,
        type: NotificationType.POST.name,
        description: isChannel ? "a posté: $truncatedMessage" : "$appName a posté: $truncatedMessage",
        user_id: sender.id,
        receiver_id: user.id,
        post_id: postId ?? "",
        post_data_type: postType ?? "",
        createdAt: notifTime,
        updatedAt: notifTime,
        status: PostStatus.VALIDE.name,
        canal_id: isChannel ? canal?.id : null,
      );

      await firestore.collection('Notifications').doc(notifId).set(notification.toJson());

    } catch (e) {
      print("❌ Erreur Firestore pour utilisateur ${user.id}: $e");
    }
  }

// 🔹 Fonction pour envoyer push notification (exécution différée)
  Future<void> _sendPushNotificationNow({
    required String appName,
    required List<String> userIds,
    required String smallImage,
    required String senderId,
    required String message,
    required String typeNotif,
    String? postId,
    String? postType,
    String? chatId,
  })
  async {
    try {
      await sendNotification(
        appName: appName,
        userIds: userIds,
        smallImage: smallImage,
        send_user_id: senderId,
        recever_user_id: "",
        message: message,
        type_notif: typeNotif,
        post_id: postId ?? "",
        post_type: postType ?? "",
        chat_id: chatId ?? "",
      );

      print("✅ Push notifications envoyées à ${userIds.length} utilisateurs");

    } catch (e) {
      print("❌ Erreur push notification: $e");
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
        // 'updatedAt': DateTime.now().microsecondsSinceEpoch,
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
    required List<String> userIds, required String smallImage,required String send_user_id, required String recever_user_id,required String message,required String type_notif,required String post_id,required String post_type,required String chat_id}) async
  {
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
        return WillPopScope(
          onWillPop: () async {
            // Retourne false pour empêcher la fermeture
            return false;
          },
          child: Container(
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
// 🔹 Classe pour stocker les résultats
class _UserNotificationResult {
  final bool isValid;
  final String oneSignalId;

  _UserNotificationResult({
    required this.isValid,
    required this.oneSignalId,
  });
}