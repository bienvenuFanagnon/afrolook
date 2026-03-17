// app_link_service.dart
import 'dart:async';
import 'package:afrotok/pages/contenuPayant/contentDetailsEbook.dart';
import 'package:afrotok/pages/home/homeScreen.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../models/model_data.dart';
import '../pages/LiveAgora/livePage.dart';
import '../pages/LiveAgora/livesAgora.dart';
import '../pages/afroshop/marketPlace/acceuil/produit_details.dart';
import '../pages/component/consoleWidget.dart';
import '../pages/contenuPayant/contentDetails.dart';
import '../pages/postDetails.dart';
import '../pages/postDetailsVideoListe.dart';
import '../providers/authProvider.dart';
import '../providers/postProvider.dart';
import '../providers/userProvider.dart';

// Types de liens supportés
enum AppLinkType {
  profil,
  contentpaie,
  live,
  post,
  article,
  service,
  unknown
}

class AppLinkService {
  static final AppLinkService _instance = AppLinkService._internal();
  factory AppLinkService() => _instance;
  AppLinkService._internal();

  late AppLinks appLinks;
  StreamSubscription<Uri>? _subscription;
  bool _isInitialized = false;
  final StreamController<PendingLink> _linkController = StreamController<PendingLink>.broadcast();

  // Variables pour contrôler les liens initiaux
  String? _lastProcessedInitialLink;
  bool _initialLinkProcessed = false;

  // Initialisation du service
  Future<void> initialize() async {
    if (_isInitialized) return;

    appLinks = AppLinks();

    // Écouter les liens entrants en temps réel
    _subscription = appLinks.uriLinkStream.listen((Uri uri) {
      _handleIncomingLink(uri, isInitial: false);
    });

    // Traiter le lien initial UNE SEULE FOIS
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        print('Lien initial détecté: $initialUri');
        _handleIncomingLink(initialUri, isInitial: true);
      }
    } catch (e) {
      print('Erreur récupération lien initial: $e');
    }

    _isInitialized = true;
  }

  // Gestionnaire des liens entrants avec contrôle des doublons
  void _handleIncomingLink(Uri uri, {required bool isInitial}) {
    final linkString = uri.toString();

    // Contrôle spécifique pour les liens initiaux
    if (isInitial) {
      if (_initialLinkProcessed) {
        print('Lien initial déjà traité, ignore: $linkString');
        return;
      }
      if (_lastProcessedInitialLink == linkString) {
        print('Lien initial identique au précédent, ignore: $linkString');
        return;
      }
      _lastProcessedInitialLink = linkString;
      _initialLinkProcessed = true;
    }

    print('Lien reçu (initial: $isInitial): $uri');

    // Vérifier le domaine et le préfixe
    if (uri.host == 'afrolooki.web.app' && uri.path.startsWith('/share')) {
      final segments = uri.pathSegments;

      if (segments.length >= 2) {
        final typeString = segments[1];
        final id = segments.length >= 3 ? segments[2] : null;

        final type = _parseLinkType(typeString);
        print("Notifier les écouteurs qu'un nouveau lien est disponible");

        // Notifier les écouteurs avec l'information "isInitial"
        _linkController.add(PendingLink(
          type: type,
          id: id,
          queryParams: uri.queryParameters,
          isInitial: isInitial, // Nouveau paramètre
        ));
      }
    }
  }

  // Gestionnaire des liens entrants

  // Parser le type de lien
  void resetInitialLinkState() {
    _initialLinkProcessed = false;
    _lastProcessedInitialLink = null;
    print('État des liens initiaux réinitialisé');
  }

  // Parser le type de lien
  AppLinkType _parseLinkType(String typeString) {
    print("Lien typeString : ${typeString}");

    switch (typeString.toLowerCase()) {
      case 'profil':
        return AppLinkType.profil;
      case 'contentpaie':
        return AppLinkType.contentpaie;
      case 'live':
        return AppLinkType.live;
      case 'post':
        return AppLinkType.post;
      case 'article':
        return AppLinkType.article;
      case 'service':
        return AppLinkType.service;
      default:
        return AppLinkType.unknown;
    }
  }
  // Génération des liens de partage
  String generateLink(AppLinkType type, String id, {Map<String, String>? params}) {
    // final baseUrl = 'https://afrolookmedia.com/share';
    final baseUrl = 'https://afrolooki.web.app/share';
    final typePath = getTypePath(type);

    var link = '$baseUrl/$typePath/$id';

    if (params != null && params.isNotEmpty) {
      final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
      link += '?$queryString';
    }

    return link;
  }

  String getTypePath(AppLinkType type) {
    switch (type) {
      case AppLinkType.profil:
        return 'profil';
      case AppLinkType.contentpaie:
        return 'contentpaie';
      case AppLinkType.live:
        return 'live';
      case AppLinkType.post:
        return 'post';
      case AppLinkType.article:
        return 'article';
      case AppLinkType.service:
        return 'service';
      default:
        return 'unknown';
    }
  }

  Future<void> shareContent({
    required AppLinkType type,
    required String id,
    String? message,
    String? mediaUrl, // image ou vidéo
    Map<String, String>? params,
  })
  async {
    final link = generateLink(type, id, params: params);

    final fullMessage = "${_getTypeMessage(type)}\n$link";
    // final fullMessage = "${_getTypeMessage(type)}: ${message ?? ''}\n\n$link";

    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      // Cas avec image/vidéo en local OU téléchargée
      // ⚠️ SharePlus partage des fichiers locaux, pas directement des URLs
      // Si ton mediaUrl est une URL, il faut le télécharger d’abord
      await Share.share(fullMessage, subject: "AfroLook");

    } else {
      // Cas simple : juste message + lien
      await Share.share(fullMessage, subject: "AfroLook");
      // await Share.share(fullMessage, subject: "AfroLook");
    }
  }


  Future<void> shareProfil({
    required AppLinkType type,
    required String id,
    String? message,
    String? mediaUrl, // image ou vidéo
    Map<String, String>? params,
  })
  async {
    final link = generateLink(type, id, params: params);

    // final fullMessage = "${_getTypeMessage(type)}\n$link";
    final fullMessage = "${message ?? ''}\n$link";

    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      // Cas avec image/vidéo en local OU téléchargée
      // ⚠️ SharePlus partage des fichiers locaux, pas directement des URLs
      // Si ton mediaUrl est une URL, il faut le télécharger d’abord
      await Share.share(fullMessage, subject: "AfroLook");

    } else {
      // Cas simple : juste message + lien
      await Share.share(fullMessage, subject: "AfroLook");
      // await Share.share(fullMessage, subject: "AfroLook");
    }
  }
  String _getTypeMessage(AppLinkType type) {
    switch (type) {
      case AppLinkType.profil:
        return "Découvre ce profil sur AfroLook ! Gagne de l'argent dès 100 vues. Utilise mon code de parrainage à l'inscription.";

      case AppLinkType.contentpaie:
        return "Contenu exclusif sur AfroLook ! Gagne de l'argent dès 100 vues. Le réseau social africain qui paie.";

      case AppLinkType.live:
        return "Live en cours sur AfroLook ! Gagne de l'argent dès 100 viewers. Rejoins maintenant.";

      case AppLinkType.post:
        return "Publication sur AfroLook ! 100 vues = argent gagné. Utilise mon code de parrainage.";

      case AppLinkType.article:
        return "Article sur AfroLook ! Gagne dès 100 lectures. Le réseau qui valorise les talents africains.";

      case AppLinkType.service:
        return "Service sur AfroLook ! Monétise tes compétences dès 100 vues. Opportunités et revenus.";

      default:
        return "AfroLook - Le réseau social africain qui paie ton talent ! Gagne de l'argent dès 100 vues. Utilise mon code de parrainage.";
    }
  }
  // Partage de lien
  Future<void> shareLink(AppLinkType type, String id,
      {String? message, Map<String, String>? params}) async {
    final link = generateLink(type, id, params: params);
    final text = message != null ? '$message\n$link' : link;

    try {
      await Share.share(text);
    } catch (e) {
      print('Erreur lors du partage: $e');
    }
  }

  // Stream pour écouter les liens entrants
  Stream<PendingLink> get linkStream => _linkController.stream;

  Future<void> handleNavigation(BuildContext context, String id,String type) async {
    printVm("Lien handleNavigation Id ${id}, type: ${type}");

    if (id == null || type ==null) {
      await _navigateToHome(context);
      return;
    }

    // 1️⃣ Vérifier l'utilisateur connecté
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    final token = await authProvider.getToken(); // fonction qui récupère le token

    if (token == null || token.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    // bool userLoaded = false;
    // if (firebaseUser != null) {
    //   userLoaded = await authProvider.getLoginUser(firebaseUser.uid);
    // }
    // printVm("Lien userLoaded $userLoaded");
    //
    // if (!userLoaded) {
    //   // Rediriger vers la page de connexion
    //   Navigator.pushReplacementNamed(context, '/login');
    //   return;
    // }

    // Toujours naviguer vers la home d'abord
    await _navigateToHome(context);


    // Puis vers la page de détail selon le type
    switch (type) {
      case 'profil':
        await _navigateToProfile(context, id!);
        break;
      case 'contentpaie':
        await _navigateToContentPaie(context, id!);
        break;
      case 'live':
        await _navigateToLive(context, id!);
        break;
      case 'post':
        await _navigateToPost(context, id!);
        break;

      default:
        await _navigateToHome(context);
    }
  }

  Future<void> handleNavigation2(BuildContext context, String id, String type) async {
    printVm("Lien handleNavigation Id $id, type: $type");

    if (id.isEmpty || type.isEmpty) {
      await _navigateToHome(context);
      return;
    }

    // Vérifier si le token existe
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final token = await authProvider.getToken(); // fonction qui récupère le token

    if (token == null || token.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Aller d'abord sur la home
    await _navigateToHome(context);

    // Puis vers la bonne page
    switch (type) {
      case 'profil':
        await _navigateToProfile(context, id);
        break;

      case 'contentpaie':
        await _navigateToContentPaie(context, id);
        break;

      case 'live':
        await _navigateToLive(context, id);
        break;

      case 'post':
        await _navigateToPost(context, id);
        break;

      default:
        await _navigateToHome(context);
    }
  }


  Future<void> _navigateToHome(BuildContext context) async {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => MyHomePage(title: "",isOpenLink: true,),),
          (route) => false,);


    // // Attendre que la navigation soit complète
    // await Future.delayed(const Duration(milliseconds: 100));
  }

  // Navigation vers le profil
  Future<void> _navigateToProfile(BuildContext context, String userId) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        // Convertir les données Firebase en objet UserData
        final userData = UserData.fromJson(userDoc.data() as Map<String, dynamic>);

        Navigator.pushNamed(
            context,
            '/profile',
            arguments: {'userId': userId, 'userData': userData}
        );
      }
    } catch (e) {
      print('Erreur chargement profil: $e');
    }
  }

  // Navigation vers ContentPaie
  Future<void> _navigateToContentPaie(BuildContext context, String contentId) async {
    try {
      final contentDoc = await FirebaseFirestore.instance
          .collection('ContentPaies')
          .doc(contentId)
          .get();

      if (contentDoc.exists) {
        // Convertir les données Firebase en objet ContentPaie
        final contentData = ContentPaie.fromJson(contentDoc.data() as Map<String, dynamic>);
        if(contentData.contentType == ContentType.EBOOK){
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EbookDetailScreen(content: contentData),
            ),
          );
        }else{
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContentDetailScreen(content: contentData),
            ),
          );
        }


      }
    } catch (e) {
      print('Erreur chargement ContentPaie: $e');
    }
  }

  // Navigation vers Live
  Future<void> _navigateToLive(BuildContext context, String liveId) async {
    final user = FirebaseAuth.instance.currentUser;

    try {
      final liveDoc = await FirebaseFirestore.instance
          .collection('lives')
          .doc(liveId)
          .get();

      if (!liveDoc.exists) {
        // Live non trouvé
        _showLiveEndedDialog(context, "Ce live n'existe plus.");
        return;
      }

      final liveData = PostLive.fromMap(liveDoc.data() as Map<String, dynamic>);

      // Vérifier si le live est encore encours
      final now = DateTime.now();
      final endTime = liveData.endTime; // Assure-toi d'avoir un champ DateTime endTime
      if (!liveData.isLive||(endTime != null && now.isAfter(endTime))) {
        _showLiveEndedDialog(context, "Ce live est terminé.");
        return;
      }

      final isHost = liveData.hostId == user?.uid;

      // Naviguer vers la page Live
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LivePage(
            liveId: liveId,
            isHost: isHost,
            hostName: liveData.hostName!,
            hostImage: liveData.hostImage!,
            isInvited: false,
            postLive: liveData,
          ),
        ),
      );
    } catch (e) {
      print('Erreur chargement live: $e');
      _showLiveEndedDialog(context, "Impossible de charger le live.");
    }
  }

// Modal simple et joli
  void _showLiveEndedDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Live"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  // Navigation vers Post
  Future<void> _navigateToPost(BuildContext context, String postId) async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    try {
      await postProvider.getPostsImagesById(postId).then((posts) {
        if (posts.isNotEmpty) {

          if(posts.first.dataType ==PostDataType.VIDEO.name){

            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => VideoTikTokPageDetails(initialPost: posts.first,isIn: true,)
                )
            );
          }else{
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => DetailsPost(post: posts.first)
                )
            );
          }

        }
      });
    } catch (e) {
      print('Erreur chargement post: $e');
    }
  }

  // Navigation vers Article
  Future<void> _navigateToArticle(BuildContext context, String articleId) async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    try {
      // Récupérer l'article depuis Firebase
      final articleDoc = await FirebaseFirestore.instance
          .collection('Articles')
          .doc(articleId)
          .get();

      if (articleDoc.exists) {
        // Convertir en objet Article (à adapter selon votre classe Article)
        // final articleData = Article.fromJson(articleDoc.data() as Map<String, dynamic>);

        // Récupérer les données de l'utilisateur
        // final userData = await _getUserData(articleData.userId);

        // Naviguer vers la page de détail de l'article
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => ArticleDetailPage(article: articleData),
        //   ),
        // );
      }
    } catch (e) {
      print('Erreur chargement article: $e');
    }
  }

  // Navigation vers Service
  Future<void> _navigateToService(BuildContext context, String serviceId) async {
    try {
      // Récupérer le service depuis Firebase
      final serviceDoc = await FirebaseFirestore.instance
          .collection('Services')
          .doc(serviceId)
          .get();

      if (serviceDoc.exists) {
        // Convertir en objet Service (à adapter selon votre classe Service)
        // final serviceData = Service.fromJson(serviceDoc.data() as Map<String, dynamic>);

        // Naviguer vers la page de détail du service
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => ServiceDetailPage(service: serviceData),
        //   ),
        // );
      }
    } catch (e) {
      print('Erreur chargement service: $e');
    }
  }

  // Méthode utilitaire pour récupérer les données utilisateur
  Future<UserData?> _getUserData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        return UserData.fromJson(userDoc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print('Erreur récupération utilisateur: $e');
    }
    return null;
  }

  // Nettoyage
  void dispose() {
    _subscription?.cancel();
    _linkController.close();
    _isInitialized = false;
    _initialLinkProcessed = false;
    _lastProcessedInitialLink = null;
  }
}

// Classe pour représenter un lien en attente
// Classe pour représenter un lien en attente (MODIFIÉE)
class PendingLink {
  final AppLinkType type;
  final String? id;
  final Map<String, String> queryParams;
  final bool isInitial; // NOUVEAU: pour identifier les liens initiaux

  PendingLink({
    required this.type,
    this.id,
    this.queryParams = const {},
    this.isInitial = false, // Par défaut false
  });
}



class DynamicLinkService {
  /// Appel à lancer au démarrage de l’app pour capter les liens
  Future<void> initDynamicLinks({required void Function(Uri) onLinkCallback}) async {
    final dynamicLinks = FirebaseDynamicLinks.instance;

    // 1. Cas : application fermée (terminated) → récupérer le lien initial
    try {
      final PendingDynamicLinkData? initialLink = await dynamicLinks.getInitialLink();
      if (initialLink != null && initialLink.link != null) {
        Uri deepLink = initialLink.link;
        print('Dynamic Link reçu au démarrage : $deepLink');
        onLinkCallback(deepLink);
      }
    } catch (e) {
      print('Erreur getInitialLink : $e');
    }

    // 2. Cas : application déjà lancée / en arrière-plan → écouter les nouveaux liens
    dynamicLinks.onLink.listen((PendingDynamicLinkData? dynamicLinkData) {
      if (dynamicLinkData != null && dynamicLinkData.link != null) {
        Uri deepLink = dynamicLinkData.link;
        print('Dynamic Link reçu via onLink : $deepLink');
        onLinkCallback(deepLink);
      }
    }).onError((error) {
      print('Erreur onLink listener : $error');
    });
  }
}
