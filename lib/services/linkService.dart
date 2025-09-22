// app_link_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../models/model_data.dart';
import '../pages/LiveAgora/livesAgora.dart';
import '../pages/afroshop/marketPlace/acceuil/produit_details.dart';
import '../pages/component/consoleWidget.dart';
import '../pages/postDetails.dart';
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
    final baseUrl = 'https://afrolooki.web.app/share';
    final typePath = _getTypePath(type);

    var link = '$baseUrl/$typePath/$id';

    if (params != null && params.isNotEmpty) {
      final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
      link += '?$queryString';
    }

    return link;
  }

  String _getTypePath(AppLinkType type) {
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

  // Traitement de la navigation
  Future<void> handleNavigation(BuildContext context, PendingLink link) async {
    printVm("Lien handleNavigation PendingLink ${link.type}, isInitial: ${link.isInitial}");

    if (link.id == null || link.type == AppLinkType.unknown) {
      await _navigateToHome(context);
      return;
    }

    // 1️⃣ Vérifier l'utilisateur connecté
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    bool userLoaded = false;
    if (firebaseUser != null) {
      userLoaded = await authProvider.getLoginUser(firebaseUser.uid);
    }
    printVm("Lien userLoaded $userLoaded");

    if (!userLoaded) {
      // Rediriger vers la page de connexion
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Toujours naviguer vers la home d'abord
    await _navigateToHome(context);

    // Réinitialiser l'état après navigation réussie (surtout pour les liens initiaux)
    if (link.isInitial) {
      resetInitialLinkState();
    }

    // Puis vers la page de détail selon le type
    switch (link.type) {
      case AppLinkType.profil:
        await _navigateToProfile(context, link.id!);
        break;
      case AppLinkType.contentpaie:
        await _navigateToContentPaie(context, link.id!);
        break;
      case AppLinkType.live:
        await _navigateToLive(context, link.id!, link.queryParams);
        break;
      case AppLinkType.post:
        await _navigateToPost(context, link.id!);
        break;
      case AppLinkType.article:
        await _navigateToArticle(context, link.id!);
        break;
      case AppLinkType.service:
        await _navigateToService(context, link.id!);
        break;
      default:
        await _navigateToHome(context);
    }
  }
  // Navigation vers la home
  Future<void> _navigateToHome(BuildContext context) async {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
          (route) => false,
    );

    // Attendre que la navigation soit complète
    await Future.delayed(const Duration(milliseconds: 100));
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
          .collection('contentPaie')
          .doc(contentId)
          .get();

      if (contentDoc.exists) {
        // Convertir les données Firebase en objet ContentPaie
        final contentData = ContentPaie.fromJson(contentDoc.data() as Map<String, dynamic>);

        // Naviguer vers la page ContentPaie (à adapter selon votre route)
        Navigator.pushNamed(
            context,
            '/contentpaie',
            arguments: {'contentData': contentData}
        );
      }
    } catch (e) {
      print('Erreur chargement ContentPaie: $e');
    }
  }

  // Navigation vers Live
  Future<void> _navigateToLive(BuildContext context, String liveId,
      Map<String, String> queryParams) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final liveDoc = await FirebaseFirestore.instance
          .collection('lives')
          .doc(liveId)
          .get();

      if (liveDoc.exists) {
        // Convertir les données Firebase en objet PostLive
        final liveData = PostLive.fromMap(liveDoc.data() as Map<String, dynamic>);
        final isHost = liveData.hostId == user?.uid;
        final isInvited = queryParams['invited'] == 'true';

        // Naviguer vers la page Live
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LivePage(
              liveId: liveId,
              isHost: isHost,
              hostName: liveData.hostName!,
              hostImage: liveData.hostImage!,
              isInvited: isHost?false:true,
              postLive: liveData,
            ),
          ),
        );
      }
    } catch (e) {
      print('Erreur chargement live: $e');
    }
  }

  // Navigation vers Post
  Future<void> _navigateToPost(BuildContext context, String postId) async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    try {
      await postProvider.getPostsImagesById(postId).then((posts) {
        if (posts.isNotEmpty) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => DetailsPost(post: posts.first)
              )
          );
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
