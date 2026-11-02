import 'package:afrotok/services/read_meter.dart';
import 'package:afrotok/services/api/api_identity.dart';
import '../services/follow_service.dart';
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:afrotok/services/abonnement_service.dart';
import 'package:afrotok/services/push_service.dart';
import 'package:afrotok/services/new_content_bus.dart';
import 'package:rxdart/rxdart.dart' as rx;
import 'package:afrotok/services/remote_config_service.dart';
import 'package:afrotok/models/chatmodels/message.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:deeplynks/deeplynks_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'package:afrotok/models/model_data.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
import 'package:afrotok/services/api/chat_api.dart';
import 'package:afrotok/services/api/chat_mapper.dart';
import 'package:afrotok/services/followers_count_service.dart';
import 'package:flutter/cupertino.dart';

import 'package:image_picker/image_picker.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pages/auth/authTest/Screens/Login/loginPageUser.dart';
import '../pages/component/consoleWidget.dart';
import '../services/auth/authService.dart';
import '../services/streak_service.dart';
import '../services/user/userService.dart';
import '../services/ad_preload_service.dart';
import '../services/ad_rotation_service.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
class UserAuthProvider extends ChangeNotifier {
  late AuthService authService = AuthService();
  late List<UserPhoneNumber> listNumbers = [];
  late UserData loginUserData = UserData();
  /// Vrai quand le dernier getLoginUser a prouvé que le profil n'existe pas (et non une simple panne réseau).
  bool loginUserNotFound = false;
  late UserData registerUser = UserData();
  late String registerText = "";
  late String? token = '';


  // late String? userId = "";
  late int app_version_code = 269;
  late String loginText = "";
  late UserService userService = UserService();
  final _deeplynks = Deeplynks();
  //List<Pays>? listPays=[];

  late AppDefaultData appDefaultData = AppDefaultData();

  late List<UserGlobalTag> listUserGlobalTag = [];
  late List<String> listUserGlobalTagString = [];
  late List<UserPseudo> listPseudo = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // final FirebaseFunctions functions = FirebaseFunctions.instance;


  // Pubs — liste en mémoire + cache SharedPreferences (rotation toutes les 3 sessions)
  static const _kAdSessionKey  = 'ad_session_count';
  static const _kAdsCacheKey   = 'ads_cache_v1';
  static const _kAdRefreshEvery = 3;

  List<Map<String, dynamic>> _advertisements = [];
  List<Map<String, dynamic>> get advertisements => _advertisements;


Future<void> loadAdvertisements() async {
    // Les annonces de la régie Afrolook Ads sont choisies par le serveur (GET /ads/app/serve) au moment de l'affichage :
    // plus de liste à charger ni de cache d'annonces côté application (voir lacunes_api_compte_boosts.md).
    _advertisements = [];
    notifyListeners();
  }

  /// Rafraîchit les données de l'utilisateur connecté depuis Firestore
  bool get isUserDataReady =>
      loginUserData.id != null && loginUserData.id!.isNotEmpty;

  /// Charge les données utilisateur depuis Firestore si elles ne sont pas encore prêtes.
  /// Opération légère — uniquement le document utilisateur, sans mise à jour Firestore.
  Future<void> ensureUserDataLoaded() async {
    if (isUserDataReady) return;
    if (_auth.currentUser == null) return;
    try {
      loginUserData = userFromBootstrap(await UsersApi.bootstrap());
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshUserData() async {
    try {
      if (loginUserData.id == null || loginUserData.id!.isEmpty) {
        printVm('❌ Impossible de rafraîchir: Aucun ID utilisateur trouvé');
        return;
      }
      // Profil, soldes, abonnements et série viennent de l'API (un seul appel).
      final updated = userFromBootstrap(await UsersApi.bootstrap());
      updated.oneIgnalUserid = loginUserData.oneIgnalUserid;
      updated.followingIds = loginUserData.followingIds;
      updated.friends = loginUserData.friends;
      loginUserData = updated;
      notifyListeners();
      printVm('✅ Données utilisateur rafraîchies avec succès');
    } catch (e) {
      printVm('❌ Erreur lors du rafraîchissement: $e');
      rethrow;
    }
  }
  /// durée par défaut = 7 jours
  static Duration postRefreshDuration = const Duration(days: 7);

  /// Permet de changer dynamiquement la durée
  static void setRefreshDuration(Duration duration) {
    postRefreshDuration = duration;
  }
Future<bool> changeStateUser({required UserData user, required String state, required bool isConnected}) async {
    // La présence reste gérée par le service de présence Firebase ; ici seul l'état local est tenu à jour.
    user.state = state;
    notifyListeners();
    return true;
  }

  /// Supprime définitivement le compte Firebase Auth + marque le document Firestore
  /// comme supprimé. Retourne null si succès, sinon un message d'erreur.
  /// Demande de suppression : accès coupé tout de suite, effacement définitif 15 jours plus tard
  /// (le support peut restaurer le compte pendant ce délai). Voir requestAccountDeletion.
  Future<String?> deleteAccount({
    required String password,
    bool acceptLoss = false,
  }) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return 'Utilisateur non connecté';

    try {
      // Ré-authentification obligatoire avant suppression Firebase
      final email = firebaseUser.email;
      if (email != null && email.isNotEmpty) {
        final credential = EmailAuthProvider.credential(email: email, password: password);
        await firebaseUser.reauthenticateWithCredential(credential);
      }

      // Le serveur vérifie les soldes, coupe l'accès et planifie l'effacement (J+15)
      try {
        await UsersApi.requestDeletion(acceptLoss: acceptLoss);
      } on ApiException catch (e) {
        if (e.status == 409 || e.status == 422) {
          return 'Il reste des soldes sur ton compte : retire-les ou coche la case de renonciation.';
        }
        return UsersApi.message(e, fallback: 'Suppression impossible pour le moment. Réessaie plus tard.');
      }

      await FirebaseAuth.instance.signOut();
      ApiIdentity.clear();
      return null; // succès
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Mot de passe incorrect. Veuillez réessayer.';
      }
      return 'Erreur : ${e.message}';
    } catch (e) {
      return 'Erreur inattendue : $e';
    }
  }

  Future<void> logout(BuildContext context) async {
    try {
      // 1️⃣ Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 2️⃣ Mettre l'utilisateur offline (backend / Firestore)
      if (loginUserData != null) {
        loginUserData!.isConnected = false;
        await changeStateUser(
          user: loginUserData,
          state: UserState.OFFLINE.name,
          isConnected: false,
        );
      }

      _closeNotificationStreams();
      // 3️⃣ Cet appareil ne reçoit plus les notifications de ce compte (avant la fermeture de session)
      final uidPush = loginUserData?.id;
      if (uidPush != null) await PushService.unregisterForUser(uidPush).timeout(const Duration(seconds: 3), onTimeout: () {});
      // 3️⃣ Supprimer token local
      await storeToken('');
      // 4️⃣ FORCER la déconnexion Firebase (la plus importante)
      await FirebaseAuth.instance.signOut();
      ApiIdentity.clear();

      // 5️⃣ Attendre que Firebase termine la déconnexion
      await Future.delayed(const Duration(milliseconds: 500));

      // 6️⃣ Vérifier que l'utilisateur est bien déconnecté
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        printVm("⚠️ Utilisateur encore connecté, tentative 2...");
        await FirebaseAuth.instance.signOut();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      printVm("✅ Déconnexion Firebase réussie");

      // 7️⃣ Fermer le dialogue
      if (context.mounted) {
        Navigator.pop(context);
      }

      // 8️⃣ Nettoyer les providers (vider les données)
      if (context.mounted) {
        //vider les providers si nécessaire
        // Provider.of<UserAuthProvider>(context, listen: false).clearUserData();
        // Provider.of<UserProvider>(context, listen: false).clearData();
      }

      // 9️⃣ Redirection propre (reset complet du stack)
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) =>  LoginPageUser()),
              (route) => false,
        );
      }

    } catch (e) {
      printVm("❌ Erreur lors de la déconnexion: $e");
      if (context.mounted) {
        Navigator.pop(context); // Fermer le dialogue en cas d'erreur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la déconnexion: $e')),
        );
      }
    }
  }  /// Fonction principale
Future<void> checkAndRefreshPostDates(String postId) async {
    // Le rafraîchissement des dates d'une publication est décidé par le serveur.
  }

  initializeData() {
    registerUser = UserData();
  }
Future<void> incrementPostTotalInteractions({
    required String postId,
    int incrementValue = 1,
    String? userId,
    String? interactionType,
  }) async {
    // Les interactions sont comptées par le serveur (vues, j'aime, commentaires, partages) : rien à écrire depuis l'application.
  }
  /// Les commissions de parrainage sont versées par le serveur (grand livre de l'API) : l'application n'écrit plus jamais un solde.
  Future<void> ajouterCommissionParrainViaUserId({String? userId, String? codeParrainage, double? montant}) async {}

  /// Les commissions de parrainage sont versées par le serveur (grand livre de l'API) : l'application n'écrit plus jamais un solde.
  Future<void> ajouterCommissionParrain({String? userId, String? codeParrainage, double? montant}) async {}

  /// Les commissions de parrainage sont versées par le serveur (grand livre de l'API) : l'application n'écrit plus jamais un solde.
  Future<void> ajouterCadeauCommissionParrain({String? userId, String? codeParrainage, double? montant}) async {}


  UserData? _userData;
  List<UserData> _availableUsers = [];

  UserData? get userData => _userData;
  List<UserData> get availableUsers => _availableUsers;
  /// Identifiant de la personne dans l'API (ULID pour les comptes créés par l'API), PAS l'uid Firebase.
  /// L'uid Firebase s'obtient par `FirebaseAuth.instance.currentUser?.uid`, seulement pour Firebase Auth / FCM.
  String? get userId => ApiIdentity.myId;

  Future<void> checkAndCleanViewedPosts(String userId) async {
    // Les publications vues sont tenues par le serveur (post_views) : rien à nettoyer côté application.
  }
  Future<void> fetchUserData() async {
    if (_auth.currentUser != null) {
      try {
        _userData = userFromBootstrap(await UsersApi.bootstrap());
      } catch (e) {
        printVm("Erreur lors du chargement du profil: $e");
      }
    }
    notifyListeners();
  }

  Future<void> _fetchAvailableUsers() async {
    // La liste complète des comptes n'est plus accessible aux clients : les écrans utilisent les suggestions et la recherche de l'API.
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
    // Le gain de l'application est tenu par le serveur (grand livre) : jamais écrit par l'application.
    return false;
  }
  Future<void> updateUserBalance(double newBalance) async {
    loginUserData.votre_solde_principal = newBalance;
    notifyListeners();
  }
  Future<bool> deductFromBalance(BuildContext context, double amount) async {
    // Les débits passent uniquement par l'API (achats avec clé d'idempotence) : l'application n'écrit plus un solde.
    return false;
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

    printVm('Generated Dynamic Link: $_linkMessage');
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

    printVm('Generated Dynamic Link: $_linkMessage');
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

    printVm('Generated Dynamic Link: $_linkMessage');
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
    // Les soldes sont créditées par le serveur uniquement (grand livre de l'API) : l'application n'écrit plus jamais un solde.
    printVm("ajouterAuSolde ignoré : les soldes ne s'écrivent plus depuis l'application.");
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
    // Les compteurs et soldes globaux de l'application appartiennent au serveur : jamais écrits par un téléphone.
  }
Future<void> updateEntreprise(EntrepriseData data) async {
    // Les entreprises (abonnement, quota, boosts) sont modifiées uniquement par le serveur (module boutique).
  }





  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }


  // Un seul abonnement Firestore par personne, partagé par tous les écrans (badges de l'accueil…) : avant, chaque reconstruction d'écran
  // créait un nouveau flux et relisait les 12 notifications. Les nouveaux écrans reçoivent aussitôt la dernière valeur connue.
  final Map<String, rx.BehaviorSubject<List<NotificationData>>> _notificationSubjects = {};
  final Map<String, StreamSubscription<List<NotificationData>>> _notificationSubs = {};

  Stream<List<NotificationData>> getListNotificationAuth(String user_id) {
    final subject = _notificationSubjects.putIfAbsent(user_id, () {
      final s = rx.BehaviorSubject<List<NotificationData>>();
      _notificationSubs[user_id] = _notificationStream(user_id).listen(s.add, onError: s.addError);
      return s;
    });
    return subject.stream;
  }

  /// « Tout marquer comme vu » : le badge de l'accueil passe à zéro immédiatement ; le serveur met ensuite la base à jour.
  void markNotificationsSeenLocally(String userId) {
    _notificationSubjects[userId]?.add(const <NotificationData>[]);
  }

  /// À la déconnexion : ferme les abonnements aux notifications.
  void _closeNotificationStreams() {
    for (final sub in _notificationSubs.values) {
      sub.cancel();
    }
    for (final s in _notificationSubjects.values) {
      s.close();
    }
    _notificationSubs.clear();
    _notificationSubjects.clear();
  }

Stream<List<NotificationData>> _notificationStream(String user_id) async* {
    // Pas de temps réel côté API : les notifications non lues sont relues toutes les 30 s tant qu'un écran écoute.
    while (true) {
      try {
        final page = await ChatApi.notifications(limit: 12, unreadOnly: true);
        yield page.items.map(notificationFromApi).toList();
      } catch (e) {
        printVm('Notifications non chargées : $e');
      }
      await Future<void>.delayed(const Duration(seconds: 30));
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

  /// Prévient les écrans (pièces, profil…) que [loginUserData] a été remplacé.
  void notifyUserDataChanged() => notifyListeners();

  Future<bool> getLoginUser(String id) async {
    await getAppData();
    bool haveData = false;
    loginUserNotFound = false;

    try {
      // Un seul appel : profil, soldes, abonnements, non lus, série, règle des pubs, rôle (ETag/304 géré par le serveur).
      loginUserData = userFromBootstrap(await UsersApi.bootstrap());
      haveData = true; // les étapes suivantes (push, amis, abonnements suivis) ne sont pas bloquantes
      loginUserData.oneIgnalUserid = OneSignal.User.pushSubscription.id;
      unawaited(PushService.registerForUser(loginUserData.id ?? '')); // jeton FCM de cet appareil
      unawaited(_loadSocialGraph());
      notifyListeners();
    } on ApiException catch (e, stack) {
      debugPrint("Erreur de chargement du profil (API): $e");
      if (e.status == 403 || e.status == 404) {
        loginUserNotFound = true; // pas de profil : à créer (POST /v1/me/register)
      }
      debugPrint("$stack");
    } catch (e, stack) {
      debugPrint("Erreur de connexion: $e");
      debugPrint("Stack trace: $stack");
    }
    return haveData;
  }

  /// Amis et comptes suivis de la personne connectée (API), chargés en arrière-plan après l'ouverture.
  Future<void> _loadSocialGraph() async {
    final uid = loginUserData.id;
    if (uid == null) return;
    try {
      final friends = <Friends>[];
      String? cursor;
      do {
        final page = await UsersApi.friends(cursor: cursor, limit: 100);
        friends.addAll(page.items.map((j) => friendFromApi(j, uid)));
        cursor = page.next;
      } while (cursor != null && friends.length < 1000);
      loginUserData.friends = friends;
      loginUserData.friendsIds = friends.map((f) => f.friendId).whereType<String>().toList();

      final following = <String>[];
      cursor = null;
      do {
        final page = await UsersApi.following(uid, cursor: cursor, limit: 100);
        following.addAll(page.items.map((j) => '${j['id']}'));
        cursor = page.next;
      } while (cursor != null && following.length < 2000);
      loginUserData.followingIds = following;

      // Invitations en attente, dans les deux sens (pour les boutons « inviter » / « invitation envoyée »)
      final sent = await UsersApi.invitations(direction: 'sent', status: 'pending', limit: 100);
      final received = await UsersApi.invitations(direction: 'received', status: 'pending', limit: 100);
      loginUserData.mesInvitationsEnvoyerId = sent.items.map((j) => '${(j['user'] as Map)['id']}').toList();
      loginUserData.mesInvitationsEnvoyer = sent.items.map((j) => invitationFromApi(j, uid, sent: true)).toList();
      loginUserData.autreInvitationsEnvoyerId = received.items.map((j) => '${(j['user'] as Map)['id']}').toList();
      loginUserData.autreInvitationsEnvoyer = received.items.map((j) => invitationFromApi(j, uid, sent: false)).toList();
      notifyListeners();
    } catch (e) {
      printVm("Amis / abonnements non chargés : $e");
    }
  }

  double _calculatePopularity(UserData user) {
    return (user.abonnes! + user.likes! + user.jaimes!) /
        (appDefaultData.nbr_abonnes! + appDefaultData.nbr_likes! + appDefaultData.nbr_loves!);
  }

  Future<void> _refreshUserData(Object? ref) async {
    final friends = loginUserData.friends;
    loginUserData = userFromBootstrap(await UsersApi.bootstrap())..friends = friends;
  }

  Future<bool> getLoginUser2(String id) async => getLoginUser(id);
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
      final cc = user.countryData?['countryCode'] ?? user.countryData?['code'];
      if (cc == null || cc.length != 2) return false;
      await UsersApi.updateMe({'country_code': cc.toUpperCase()});
      return true;
    } catch (e) {
      printVm("erreur update pays : $e");
      return false;
    }
  }


  bool isUserAbonne(List<String> abonnesIds, String userId) {
    return abonnesIds.contains(userId);
  }



  Future<List<UserData>> getUserById(String id) async {
    try {
      return [userFromApi(await UsersApi.publicProfile(id))];
    } catch (e) {
      printVm("erreur profil $id : $e");
      return [];
    }
  }

Future<List<String>> getAllUsersOneSignaUserId() async {
    // Les envois groupés sont faits par le serveur : l'application ne connaît plus les identifiants de notification des autres.
    return [];
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
  }) async {
    // Les notifications d'une nouvelle publication aux abonnés sont émises par le serveur (budget quotidien, langues, aperçus).
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
    bool isSticker = false,
    List<String> excludeUserIds = const [],
  }) async {
    // Les notifications d'interaction (j'aime, commentaire…) sont émises par le serveur : rien à envoyer depuis l'application.
    return 0;
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
  //         .getM('authProvider.dart:1963');
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
  //         .getM('authProvider.dart:1975');
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
  //           .getM('authProvider.dart:2030');
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
  //     printVm('❌ Erreur notifySubscribersOfInteraction: $e');
  //   }
  // }
// 🔹 Délai minimum entre deux pushs selon le type (0 = immédiat)


// 🔹 Fonction helper pour traiter un utilisateur


// 🔹 Fonction pour sauvegarder dans Firestore (exécution différée)


// 🔹 Fonction pour envoyer push notification (exécution différée)






// Récupère tous les utilisateurs (réservé à l'admin)
  Future<List<UserData>> getAllUsers() async {
    // La liste complète des comptes n'est plus exposée aux clients (administration : routes /admin de l'API).
    return [];
  }

// Récupère uniquement les utilisateurs dont l'ID est dans la liste
  Future<List<UserData>> getUsersByIds(List<String> ids) async {
    final users = <UserData>[];
    for (var i = 0; i < ids.length; i += 50) {
      final rows = await UsersApi.lookup(ids.sublist(i, i + 50 > ids.length ? ids.length : i + 50));
      users.addAll(rows.map(userFromApi));
    }
    return users;
  }







  Future<bool> abonner2(UserData updateUserData,BuildContext context) async => abonner(updateUserData, context);

  Future<bool> abonner(UserData updateUserData, BuildContext context) async {
    try {
      final currentUserId = loginUserData.id!;
      final creatorId = updateUserData.id!;

      // L'API crée l'abonnement, tient les compteurs, notifie le créateur (ABONNER) et applique le plafond d'abonnements.
      final bool alreadySubscribed = await FollowService.follow(creatorId);

      if (alreadySubscribed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vous êtes déjà abonné.', textAlign: TextAlign.center, style: TextStyle(color: Colors.red))),
        );
        return true;
      }

      // Mise à jour locale
      loginUserData.followingIds ??= [];
      if (!loginUserData.followingIds!.contains(creatorId)) {
        loginUserData.followingIds!.add(creatorId);
      }
      updateUserData.userAbonnesIds ??= [];
      if (!updateUserData.userAbonnesIds!.contains(currentUserId)) {
        updateUserData.userAbonnesIds!.add(currentUserId);
      }
      updateUserData.abonnes = (updateUserData.abonnes ?? 0) + 1;
      FollowersCountService.instance.invalidate(creatorId);
      notifyListeners();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Abonné, Bravo !', textAlign: TextAlign.center, style: TextStyle(color: Colors.green))),
      );
      return true;
    } catch (e) {
      printVm("Erreur lors de l'abonnement : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UsersApi.message(e, fallback: 'Erreur technique'), textAlign: TextAlign.center, style: TextStyle(color: Colors.red))),
      );
      return false;
    }
  }

  Future<bool> getUserByPhone(String phone) async {
    // La recherche par numéro de téléphone n'existe pas dans l'API (voir lacunes_api_utilisateurs.md).
    return false;
  }







  Future<bool> getCurrentUser(String currentUserId) async {
    await getAppData();
    bool hasData = false;
    try {
      final friends = loginUserData.friends;
      final following = loginUserData.followingIds;
      loginUserData = userFromBootstrap(await UsersApi.bootstrap());
      loginUserData.oneIgnalUserid = OneSignal.User.pushSubscription.id;
      if (friends != null) loginUserData.friends = friends;
      if (following != null && following.isNotEmpty) loginUserData.followingIds = following;
      hasData = true;
    } catch (e) {
      printVm("erreur chargement du profil : $e");
    }
    notifyListeners();
    return hasData;
  }

  Future<bool> getCurrentUserByPhone(String phone) async {
    // Pas de recherche par téléphone dans l'API : connexion par e-mail / Google uniquement (voir lacunes_api_utilisateurs.md).
    return false;
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
Future<void> sendNotification({  String? appName,
    required List<String> userIds, required String smallImage,required String send_user_id, required String recever_user_id,required String message,required String type_notif,required String post_id,required String post_type,required String chat_id}) async
  {
    // Les notifications sont émises par le serveur (FCM, budget quotidien, aperçus) à la suite de chaque action ; l'application n'en envoie plus.
  }


  /// Notification d'un message de chat, au format des messageries : titre « @pseudo », texte = début du message.
  /// Envoyée à l'identifiant de la personne (et non à son identifiant OneSignal) : le serveur choisit FCM, sinon OneSignal.
  /// [image] : photo envoyée dans le chat (aperçu) ; [postId]/[postType] : post partagé (aperçu du post).
Future<void> sendChatPush({
    required String receiverId,
    required String title,
    required String message,
    String? smallImage,
    String? image,
    String chatId = '',
    String postId = '',
    String postType = '',
  }) async {
    // La notification d'un message de chat est émise par le serveur (voir ChatApi.conversationSent) : rien à envoyer ici.
  }

  Future<void> checkAppVersionAndProceed(BuildContext context, Function onSuccess) async {
    // Si appDefaultData est déjà chargé en mémoire, on évite l'appel réseau.
    if (appDefaultData.id == null) {
      await getAppData();
    }
    await Future.value().then((_) async {
      printVm("code app data *** : ${appDefaultData.app_version_code}");
      // En mode debug, on ignore la vérification de version pour ne pas bloquer le dev
      if (kDebugMode || kIsWeb) { // web : toujours la dernière version, pas de store
        onSuccess();
        return;
      }
      // L'équipe d'administration n'est JAMAIS bloquée par une mise à jour obligatoire (elle doit pouvoir se connecter pour corriger la version en ligne)
      final teamRole = loginUserData.role;
      if (teamRole != null && teamRole.isNotEmpty && teamRole != UserRole.USER.name) {
        onSuccess();
        return;
      }
      // Bypass pendant la review Google Play ou Apple App Store
      final isInStoreReview = (!kIsWeb && Platform.isIOS)
          ? (appDefaultData.appleVerification ?? false)
          : (appDefaultData.googleVerification ?? false);

      if (!isInStoreReview) {
        // Mise à jour requise uniquement si la version en ligne est SUPÉRIEURE à celle de l'utilisateur
        // numéro du système de la personne (Android ou iPhone) s'il est réglé, sinon le numéro commun
        final platformVersion = (!kIsWeb && Platform.isIOS) ? appDefaultData.app_version_code_ios : appDefaultData.app_version_code_android;
        final onlineVersion = platformVersion ?? appDefaultData.app_version_code ?? app_version_code;
        if (app_version_code >= onlineVersion) {
          onSuccess();
        } else {
          _showUpdateModal(context);
        }
      } else {
        onSuccess();
      }

    });
  }
  void _showUpdateModal(BuildContext context) {
    final isIOS = !kIsWeb && Platform.isIOS;
    const iosAppStoreUrl = 'https://apps.apple.com/app/id6811423047';
    final storeUrl = isIOS
        ? (appDefaultData.ios_link?.isNotEmpty == true ? appDefaultData.ios_link! : iosAppStoreUrl)
        : (appDefaultData.app_link ?? '');
    final storeLabel = isIOS ? 'Mettre à jour sur App Store' : 'Mettre à jour sur Play Store';
    final storeIcon = isIOS ? Icons.apple : Icons.play_arrow;

    showResponsiveBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
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
                Container(
                  width: 60,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
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
                Text(
                  "Une nouvelle version d'AfroLook est disponible.\n\n"
                  "Téléchargez-la maintenant pour profiter des dernières fonctionnalités, d'une meilleure sécurité et d'une expérience encore plus fluide !",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 25),
                ElevatedButton.icon(
                  onPressed: () {
                    if (storeUrl.isNotEmpty) _launchUrl(Uri.parse(storeUrl));
                  },
                  icon: Icon(storeIcon, color: Colors.black),
                  label: Text(
                    storeLabel,
                    style: const TextStyle(
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
                TextButton(
                  onPressed: () {},
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







  Stream<UserData> getUserStream() async* {
    final uid = loginUserData.id;
    if (uid == null) throw Exception("User ID manquant");
    // Pas de temps réel côté API : profil et soldes relus toutes les 20 s tant que l'écran écoute.
    while (true) {
      try {
        yield userFromBootstrap(await UsersApi.bootstrap());
      } catch (e) {
        printVm("erreur lecture du profil : $e");
      }
      await Future<void>.delayed(const Duration(seconds: 20));
    }
  }

  /// Retourne directement le Stream des données AppDefaultData
  Stream<AppDefaultData> getAppDataStream() async* {
    // Réglages publics seulement (GET /v1/config) ; les compteurs globaux de l'administration viendront d'une route /admin (voir lacunes_api_utilisateurs.md).
    yield await authService.getAppData();
  }




  String convertToCdnUrl(String firebaseStorageUrl, AppDefaultData appConfig) {
    if (!RemoteConfigService.instance.isPageActive('cdn_active')) {
      return firebaseStorageUrl;
    }

    if (firebaseStorageUrl.isEmpty) return firebaseStorageUrl;

    try {
      if (firebaseStorageUrl.contains('firebasestorage.googleapis.com')) {
        final parts = firebaseStorageUrl.split('/o/');
        if (parts.length > 1) {
          // On récupère tout ce qui vient après le '/o/' (le chemin du fichier + les tokens)
          final fileWithParams = parts[1];
          final urfinal = "https://cdn.afrolookmedia.com/media/$fileWithParams";

          // printVm("urfinalmedia: ${urfinal}");

          // On construit l'URL finale en passant par ton domaine et le préfixe /media/
          return urfinal;
        }
      }
    } catch (e) {
      printVm('Erreur CDN URL Conversion: $e');
    }

    return firebaseStorageUrl;
  }
}

Future<void> addPointsForAction(UserAction action) async {
  // Une publication vient de réussir : retour à l'accueil et affichage en tête du fil (voir NewContentBus)
  if (action == UserAction.post) NewContentBus.instance.onPublished();
  // Les points et la popularité ne s'écrivent plus depuis l'application (le serveur les tient ; voir lacunes_api_utilisateurs.md).
}

Future<void> addPointsForOtherUserAction(String userid,UserAction action) async {
  // Voir addPointsForAction : points tenus par le serveur.
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