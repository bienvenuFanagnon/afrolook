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
import 'utils/abonnement_utils.dart';
import '../pages/LiveAgora/livePage.dart';
import '../pages/LiveAgora/livesAgora.dart';
import '../pages/afroshop/marketPlace/acceuil/produit_details.dart';
import '../pages/chat/group/group_chat_page.dart';
import '../pages/component/consoleWidget.dart';
import '../pages/contenuPayant/contentDetails.dart';
import '../pages/postDetails.dart';
import '../pages/postDetailsVideo.dart';
import '../pages/pronostics/pronostic_detail_page.dart';
import '../providers/authProvider.dart';
import '../providers/postProvider.dart';
import '../providers/userProvider.dart';
import '../theme/app_colors.dart';

// Types de liens supportés
enum AppLinkType {
  profil,
  contentpaie,
  live,
  post,
  article,
  service,
  group,
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
        printVm('Lien initial détecté: $initialUri');
        _handleIncomingLink(initialUri, isInitial: true);
      }
    } catch (e) {
      printVm('Erreur récupération lien initial: $e');
    }

    _isInitialized = true;
  }

  // Gestionnaire des liens entrants avec contrôle des doublons
  void _handleIncomingLink(Uri uri, {required bool isInitial}) {
    final linkString = uri.toString();

    // Contrôle spécifique pour les liens initiaux
    if (isInitial) {
      if (_initialLinkProcessed) {
        printVm('Lien initial déjà traité, ignore: $linkString');
        return;
      }
      if (_lastProcessedInitialLink == linkString) {
        printVm('Lien initial identique au précédent, ignore: $linkString');
        return;
      }
      _lastProcessedInitialLink = linkString;
      _initialLinkProcessed = true;
    }

    printVm('Lien reçu (initial: $isInitial): $uri');

    // Vérifier le domaine et le préfixe
    if (uri.host == '$domaineName' && uri.path.startsWith('/share')) {
      final segments = uri.pathSegments;

      if (segments.length >= 2) {
        final typeString = segments[1];
        final id = segments.length >= 3 ? segments[2] : null;

        final type = _parseLinkType(typeString);
        printVm("Notifier les écouteurs qu'un nouveau lien est disponible");

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
    printVm('État des liens initiaux réinitialisé');
  }

  // Parser le type de lien
  AppLinkType _parseLinkType(String typeString) {
    printVm("Lien typeString : ${typeString}");

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
      case 'group':
        return AppLinkType.group;
      default:
        return AppLinkType.unknown;
    }
  }
  // final domaineName = 'https://afrolooki.web.app';
  final domaineName = 'https://afrolookmedia.com';
  // Génération des liens de partage
  String generateLink(AppLinkType type, String id, {Map<String, String>? params}) {
    // final baseUrl = 'https://afrolookmedia.com/share';
    final baseUrl = '$domaineName/share';
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
      case AppLinkType.group:
        return 'group';
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
        return "🚀 Découvre ce profil sur AfroLook !\n"
            "💰 À partir de 100 vues, gagne jusqu'à 25 000 FCFA/mois !\n"
            "🎁 Code parrainage à l'inscription.";

      case AppLinkType.contentpaie:
        return "🔥 Vends tes contenus sur AfroLook !: "
            "💰 Formation, Vidéo virale ou Livre - gagne jusqu'à 500 000 FCFA/mois !\n"
            "⚡️ Dès 100 vues, ton talent te rapporte de l'argent !";

      case AppLinkType.live:
        return "🎥 Live en cours sur AfroLook !\n"
            "💰 Gagne jusqu'à 30 000 FCFA/mois dès 100 viewers !\n"
            "📱 Rejoins maintenant.";

      case AppLinkType.post:
        return "📱 Publication sur AfroLook !\n"
            "⚡️ 100 vues - Gagne Jusqu'à 25 000 FCFA/mois!";

      case AppLinkType.article:
        return "🛍️ Vends tes produits sur AfroLook !\n"
            "💰 Jusqu'à 500 000 FCFA/mois de chiffre d'affaires !\n"
            "📦 Mode, Beauté, Électronique, Alimentation... Tout se vend !";

      case AppLinkType.service:
        return "💼 Service sur AfroLook !\n"
            "💰 Monétise tes compétences : jusqu'à 100 000 FCFA/mois dès 100 vues !\n"
            "🚀 Opportunités et revenus garantis.";

      case AppLinkType.group:
        return "👑 Rejoins mon groupe privé sur AfroLook !\n"
            "Clique sur le lien pour rejoindre directement :";

      default:
        return "🌟 AfroLook - Le réseau social africain qui paie ton talent !\n"
            "💰 À partir de 100 vues, gagne entre 15 000 et 100 000 FCFA/mois !\n"
            "🎁 Utilise mon code de parrainage à l'inscription.";
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
      printVm('Erreur lors du partage: $e');
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
      case 'group':
        await _navigateToGroup(context, id!);
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
    final token = await authProvider.getToken();

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

      case 'group':
        await _navigateToGroup(context, id);
        break;

      default:
        await _navigateToHome(context);
    }
  }


  /// Point d'entrée public pour naviguer vers un groupe depuis l'extérieur (ex: homeScreen)
  Future<void> navigateToGroup(BuildContext context, String joinCode) =>
      _navigateToGroup(context, joinCode);

  // Navigation vers un groupe via son code d'invitation
  Future<void> _navigateToGroup(BuildContext context, String joinCode) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;

    // Afficher le modal de chargement immédiatement
    bool loadingDismissed = false;
    void dismissLoading() {
      if (!loadingDismissed && context.mounted) {
        loadingDismissed = true;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.of(context).surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.35),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Chargement du groupe…',
                    style: TextStyle(
                      color: AppColors.of(context).textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vérification du lien d\'invitation',
                    style: TextStyle(
                      color: AppColors.of(context).textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('GroupChats')
          .where('join_code', isEqualTo: joinCode)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        dismissLoading();
        if (context.mounted) _showGroupLinkDialog(context, title: 'Groupe introuvable', message: 'Ce lien d\'invitation n\'est plus valide.');
        return;
      }

      final groupDoc = snap.docs.first;
      final groupData = groupDoc.data();
      final groupId = groupDoc.id;
      groupData['id'] = groupId;

      // Code expiré
      final codeExpiresAt = groupData['join_code_expires_at'] as int?;
      if (codeExpiresAt != null && codeExpiresAt < now) {
        dismissLoading();
        if (context.mounted) _showGroupLinkDialog(context, title: 'Lien expiré', message: 'Ce lien d\'invitation de 30 jours a expiré. Demandez un nouveau code au propriétaire du groupe.');
        return;
      }

      // Groupe gelé
      if (groupData['is_frozen'] == true) {
        dismissLoading();
        if (context.mounted) _showGroupLinkDialog(context, title: groupData['name'] as String? ?? 'Groupe', message: 'Ce groupe est actuellement suspendu. Le propriétaire doit renouveler son abonnement Gold pour rouvrir les accès.');
        return;
      }

      // Vérifier que le proprio est encore actif
      final ownerId = groupData['owner_id'] as String?;
      if (ownerId != null) {
        final ownerDoc = await FirebaseFirestore.instance.collection('Users').doc(ownerId).get();
        final ownerData = ownerDoc.data();
        if (ownerData != null) {
          final ab = AfrolookAbonnement.fromJson(ownerData['abonnement'] as Map<String, dynamic>? ?? {});
          if (!ab.estPremium) {
            dismissLoading();
            if (context.mounted) _showGroupLinkDialog(context, title: groupData['name'] as String? ?? 'Groupe', message: 'Le propriétaire de ce groupe n\'a plus de plan actif. Le groupe est temporairement en lecture seule.');
            return;
          }
        }
      }

      final memberIds = (groupData['member_ids'] as List<dynamic>? ?? []).cast<String>();
      final groupName = groupData['name'] as String? ?? '';
      final groupImage = groupData['image_url'] as String?;

      dismissLoading();

      // Déjà membre → ouvrir directement
      if (memberIds.contains(myId)) {
        if (context.mounted) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => GroupChatPage(groupId: groupId, groupName: groupName, groupImageUrl: groupImage),
          ));
        }
        return;
      }

      // Pas encore membre → dialog de confirmation
      if (context.mounted) {
        _showJoinGroupDialog(context, groupData: groupData, groupId: groupId, groupName: groupName, groupImage: groupImage, myId: myId, authProvider: authProvider);
      }
    } catch (e) {
      dismissLoading();
      printVm('Erreur navigation groupe: $e');
    }
  }

  void _showJoinGroupDialog(BuildContext context, {
    required Map<String, dynamic> groupData,
    required String groupId,
    required String groupName,
    required String? groupImage,
    required String myId,
    required UserAuthProvider authProvider,
  }) {
    final colors = AppColors.of(context);
    final memberCount = groupData['member_count'] as int? ?? 0;
    final isPrivate = groupData['is_private'] == true;
    final price = (groupData['subscription_price'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            if (groupImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(groupImage, width: 40, height: 40, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.group, size: 40),
                ),
              )
            else
              Icon(Icons.group_rounded, size: 40, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(groupName, style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$memberCount membre${memberCount > 1 ? 's' : ''}', style: TextStyle(color: colors.textSecondary, fontSize: 14)),
            if (isPrivate && price > 0) ...[
              const SizedBox(height: 8),
              Text('Groupe privé · ${price.toStringAsFixed(0)} FCFA/mois', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 12),
            Text('Voulez-vous rejoindre ce groupe ?', style: TextStyle(color: colors.textPrimary, fontSize: 15)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              await _doJoinGroup(context, groupId: groupId, groupName: groupName, groupImage: groupImage, myId: myId, authProvider: authProvider, groupData: groupData);
            },
            child: const Text('Rejoindre', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _doJoinGroup(BuildContext context, {
    required String groupId,
    required String groupName,
    required String? groupImage,
    required String myId,
    required UserAuthProvider authProvider,
    Map<String, dynamic> groupData = const {},
  }) async {
    try {
      // Vérifier la limite de membres (Premium owner : 100 max, Gold : illimité)
      final ownerId = groupData['owner_id'] as String? ?? '';
      if (ownerId.isNotEmpty) {
        final ownerDoc = await FirebaseFirestore.instance.collection('Users').doc(ownerId).get();
        if (ownerDoc.exists) {
          final ownerAbJson = ownerDoc.data()?['abonnement'] as Map<String, dynamic>?;
          final ownerAb = ownerAbJson != null ? AfrolookAbonnement.fromJson(ownerAbJson) : null;
          final maxMembers = AbonnementUtils.maxGroupMembers(ownerAb);
          final currentCount = groupData['member_count'] as int?
              ?? (groupData['member_ids'] as List<dynamic>? ?? []).length;
          if (maxMembers != null && currentCount >= maxMembers) {
            if (context.mounted) {
              _showGroupLinkDialog(context,
                title: 'Groupe complet',
                message: 'Ce groupe a atteint sa limite de $maxMembers membres (plan Premium).',
              );
            }
            return;
          }
        }
      }

      // Groupe privé payant : ne pas ajouter comme membre avant paiement
      final isPrivate = groupData['is_private'] == true;
      final price = (groupData['subscription_price'] as num?)?.toDouble() ?? 0.0;
      if (isPrivate && price > 0) {
        final paidSubs = (groupData['paid_subscribers'] as Map<String, dynamic>?) ?? {};
        final expiryMs = paidSubs[myId] as int?;
        final isPaid = expiryMs != null && expiryMs > DateTime.now().millisecondsSinceEpoch;
        if (!isPaid) {
          // Rediriger vers le groupe — _checkPaidSubscription demandera le paiement
          if (context.mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => GroupChatPage(groupId: groupId, groupName: groupName, groupImageUrl: groupImage),
            ));
          }
          return;
        }
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final myPseudo = authProvider.loginUserData.pseudo ?? '';
      final myImageUrl = authProvider.loginUserData.imageUrl ?? '';

      await FirebaseFirestore.instance
          .collection('GroupChats').doc(groupId).collection('members').doc(myId)
          .set({'user_id': myId, 'pseudo': myPseudo, 'image_url': myImageUrl, 'role': 'member', 'joined_at': now});
      await FirebaseFirestore.instance.collection('GroupChats').doc(groupId).update({
        'member_ids': FieldValue.arrayUnion([myId]),
        'member_count': FieldValue.increment(1),
      });

      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => GroupChatPage(groupId: groupId, groupName: groupName, groupImageUrl: groupImage),
        ));
      }
    } catch (e) {
      printVm('Erreur rejoindre groupe: $e');
    }
  }

  void _showGroupLinkDialog(BuildContext context, {required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
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
      printVm('Erreur chargement profil: $e');
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
      printVm('Erreur chargement ContentPaie: $e');
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
      printVm('Erreur chargement live: $e');
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
          if(posts.first.type ==PostType.PRONOSTIC.name){

            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => PronosticDetailPage(postId: posts.first.id!,)
                )
            );
          }else{
            if(posts.first.dataType ==PostDataType.VIDEO.name){

              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => VideoYoutubePageDetails(initialPost: posts.first,isIn: true,)
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


        }
      });
    } catch (e) {
      printVm('Erreur chargement post: $e');
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
      printVm('Erreur chargement article: $e');
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
      printVm('Erreur chargement service: $e');
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
      printVm('Erreur récupération utilisateur: $e');
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
        printVm('Dynamic Link reçu au démarrage : $deepLink');
        onLinkCallback(deepLink);
      }
    } catch (e) {
      printVm('Erreur getInitialLink : $e');
    }

    // 2. Cas : application déjà lancée / en arrière-plan → écouter les nouveaux liens
    dynamicLinks.onLink.listen((PendingDynamicLinkData? dynamicLinkData) {
      if (dynamicLinkData != null && dynamicLinkData.link != null) {
        Uri deepLink = dynamicLinkData.link;
        printVm('Dynamic Link reçu via onLink : $deepLink');
        onLinkCallback(deepLink);
      }
    }).onError((error) {
      printVm('Erreur onLink listener : $error');
    });
  }
}
