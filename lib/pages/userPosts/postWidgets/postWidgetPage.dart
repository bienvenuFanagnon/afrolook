import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import 'package:afrotok/pages/user/monetisation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hashtagable_v3/widgets/hashtag_text.dart';

import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../../models/model_data.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/locale_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'translatable_description.dart';

import '../../../providers/coin_gift_provider.dart';
import '../../../providers/sound_provider.dart';
import '../../../services/linkService.dart';
import '../../../services/utils/abonnement_utils.dart';
import '../../../widgets/user_badge_widget.dart';
import '../../coins/coin_gift_dialog.dart';
import '../../coins/coin_recharge_screen.dart';
import '../../coins/post_gifts_list.dart';
import '../../component/consoleWidget.dart';
import '../../home/homeWidget.dart';
import '../../home/user_presence_widget.dart';
import '../../paiement/newDepot.dart';
import '../../postComments.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../canaux/detailsCanal.dart';

import '../../component/showUserDetails.dart';
import '../../postComments.dart';
import '../../postDetails.dart';
import '../../postDetailsVideo.dart';
import '../../pub/native_ad_widget.dart';
import '../../pub/rewarded_ad_widget.dart';
import '../../widgetGlobal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../youTube_video_card.dart';
import 'audioPostWidget.dart';
import '../../../services/postService/post_view_service.dart';



class HomePostUsersWidget extends StatefulWidget {
  late Post post;
  late Color? color;
  final double height;
  final double width;
   late int index;
  final bool isDegrade;
  bool isPreview;
  final Function(Post, VisibilityInfo)? onVisibilityChanged;

  // 🔥 NOUVEAUX CALLBACKS POUR LES INTERACTIONS
  final VoidCallback? onLiked;
  final VoidCallback? onCommented;
  final VoidCallback? onShared;
  final VoidCallback? onLoved;
  final VoidCallback? onViewed;
  // Session 13 : pays du filtre actif (HomeConstPost._selectedCountryCode), utilisé pour
  // afficher en priorité ce pays dans le badge pays du post (s'il y figure).
  final String? currentFilterCountry;

  HomePostUsersWidget({
    required this.post,
    this.color,
    this.isDegrade = false,
    required this.height,
    required this.width,
    Key? key,
    this.isPreview = true,
    this.onVisibilityChanged,
    this.onLiked,
    this.onCommented,
    this.onShared,
    this.onLoved,
    this.onViewed,
    this.index=0,
    this.currentFilterCountry,
  }) : super(key: key);

  @override
  _HomePostUsersWidgetState createState() => _HomePostUsersWidgetState();
}

class _HomePostUsersWidgetState extends State<HomePostUsersWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _isExpanded = false;
  bool _isSharing = false;
  String? _translatedDescription;
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  late UserProvider userProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool _isFavorite = false;
  bool _isProcessingFavorite = false;
  Random random = Random();
  bool _isLoading = false;
  bool _isProcessingFollow = false;
  final GlobalKey<RewardedAdWidgetState> _rewardedAdKey = GlobalKey();
  bool _showRewardedAd = false;
  bool _isSupporting = false;
  bool? _hasSeenSupportModal; // null = pas encore chargé
  // Variables pour stocker les données récupérées individuellement
  UserData? _currentUser;
  Canal? _currentCanal;
  bool _isLoadingUser = false;
  bool _isLoadingCanal = false;

  // Variables pour la thumbnail vidéo
  String? _videoThumbnailPath;
  bool _isGeneratingThumbnail = false;
  bool get _shouldShowAd {
    // Affiche la pub pour les indices 2, 5, 8, 11... (1-indexé)
    // Exemple : index 0 -> 1er post -> pas de pub
    //          index 2 -> 3ème post -> pub
    return (widget.index + 1) % 2 == 0;
  }
  // CONFIGURATION - Paiement pour abonnés existants
  final bool _requirePaymentForExistingSubscribers = false;
  // Dans _HomePostUsersWidgetState
  Widget _buildEventBadge(Post post) {


    if (post.typeTabbar != 'EVENEMENT' || post.eventDate == null) return SizedBox.shrink();
    printVm("eventDate : ${post.eventDate!}");
    final eventDateTime = DateTime.fromMillisecondsSinceEpoch(post.eventDate!);
    final now = DateTime.now();
    final difference = eventDateTime.difference(now).inDays;

    final colors = AppColors.of(context);
    String badgeText = '';
    Color badgeColor = colors.danger;

    if (difference < 0) {
      badgeText = '📅 PASSÉ';
      badgeColor = colors.textSecondary;
    } else if (difference == 0) {
      badgeText = '🔴 AUJOURD\'HUI';
      badgeColor = colors.danger;
    } else if (difference == 1) {
      badgeText = '⭐ DEMAIN';
      badgeColor = colors.warning;
    } else if (difference <= 7) {
      badgeText = '📅 DANS $difference JOURS';
      badgeColor = colors.danger;
    } else {
      badgeText = '📅 À VENIR';
      badgeColor = colors.info;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
        ],
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }


  // Vérifier si l'utilisateur a déjà soutenu ce post aujourd'hui
  Future<bool> _hasSupportedToday(String postId, String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + Duration(days: 1).inMilliseconds;

    final query = await firestore
        .collection('post_supports')
        .where('postId', isEqualTo: postId)
        .where('userId', isEqualTo: userId)
        .where('supportedAt', isGreaterThanOrEqualTo: startOfDay)
        .where('supportedAt', isLessThan: endOfDay)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

// Enregistrer le soutien
  Future<void> _recordSupport(String postId, String userId) async {
    final support = PostSupport(
      id: firestore.collection('post_supports').doc().id,
      postId: postId,
      userId: userId,
      supportedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await firestore.collection('post_supports').doc(support.id).set(support.toJson());
  }

  Future<void> recordUniquePostView() async {

     String userId = authProvider.loginUserData.id!;
     String postId = widget.post.id!;
    try {
      final postRef = FirebaseFirestore.instance.collection('Posts').doc(postId);

      final postDoc = await postRef.get();

      if (!postDoc.exists) return;

      List usersViewed = postDoc.data()?['users_vue_id'] ?? [];

      // Vérifier si l'utilisateur a déjà vu
      if (usersViewed.contains(userId)) {
        print("⏭️ L'utilisateur a déjà vu ce post");
        return;
      }

      // Enregistrer la vue
      await postRef.update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([userId]),
      });

      PostViewService.recordAuthorView(widget.post, userId);
      print("✅ Vue enregistrée pour $userId");

    } catch (e) {
      print("Erreur enregistrement vue : $e");
    }
  }

// Nettoyer les ressources audio quand le widget est détruit
  // 🔥 S'assurer d'avoir authProvider et appDefaultData
  late AppDefaultData appDefaultData;
  @override
  void initState() {
    super.initState();
    print("index du post: ${widget.index}");
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    appDefaultData = authProvider.appDefaultData;
    _loadUserData();
    _loadCanalData();
    _generateVideoThumbnail();

    _checkIfFavorite();
    _loadSupportModalSeen();
  }


  // Méthode utilitaire pour optimiser les URLs d'images
  String _optimizeUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final appDefaultData = authProvider.appDefaultData;

    return authProvider.convertToCdnUrl(url, appDefaultData);
  }

  Future<void> _loadSupportModalSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = authProvider.loginUserData.id;
    final key = 'has_seen_support_modal_$userId';
    setState(() {
      _hasSeenSupportModal = prefs.getBool(key) ?? false;
    });
  }

  Future<void> _markSupportModalSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = authProvider.loginUserData.id;
    await prefs.setBool('has_seen_support_modal_$userId', true);
    setState(() {
      _hasSeenSupportModal = true;
    });
  }

  void _showSupportModal() {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colors.surface,
        title: Row(
          children: [
            Icon(Icons.volunteer_activism, color: colors.supportAccent),
            SizedBox(width: 8),
            Text(l10n.postSupportCreator, style: TextStyle(color: colors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.postSupportWatchAdInfo,
              style: TextStyle(color: colors.textSecondary),
            ),
            SizedBox(height: 12),
            Text(
              l10n.postSupportEarnings,
              style: TextStyle(color: colors.textPrimary),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.monetization_on, color: colors.supportAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.postSupportCoinsConvert,
                      style: TextStyle(color: colors.textPrimary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.postSupportLater, style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _markSupportModalSeen();
              _startSupportAd();
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.supportAccent),
            child: Text(l10n.postSupportWatchAdButton, style: TextStyle(color: colors.onAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSupportAd() async {
    // if (_isSupporting) return;
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == widget.post.user_id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).postSupportCannotSelf), backgroundColor: AppColors.of(context).warning),
      );
      return;
    }

    // Vérifier la limite quotidienne
    final hasSupported = await _hasSupportedToday(widget.post.id!, currentUserId!);
    if (hasSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).postSupportAlreadyToday),
          backgroundColor: AppColors.of(context).warning,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_hasSeenSupportModal == null) await _loadSupportModalSeen();
    if (_hasSeenSupportModal == false) {
      _showSupportModal();
      return;
    }
    _startSupportAd();
  }
  void _startSupportAd() {
    setState(() {
      _isSupporting = true;
      _showRewardedAd = true;
    });
    // Attendre que le widget soit monté puis lancer la pub
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_rewardedAdKey.currentState != null) {
        _rewardedAdKey.currentState!.showAd();

      } else {
        setState(() {
          _isSupporting = false;
          _showRewardedAd = false;
        });
      }
    });
  }

  Future<void> _onSupportAdRewarded() async {
    final currentUserId = authProvider.loginUserData.id;
    final postId = widget.post.id!;
    final creatorId = widget.post.user_id!;

    // Incrémenter le compteur de pub sur le post
    final postRef = firestore.collection('Posts').doc(postId);
    await postRef.update({
      'adSupportCount': FieldValue.increment(1),
    });

    // Créditer le créateur (10 pièces)
    final creatorRef = firestore.collection('Users').doc(creatorId);
    await creatorRef.update({
      'totalCoinsEarnedFromAdSupport': FieldValue.increment(1),
    });

    // Incrémenter le compteur du spectateur
    final viewerRef = firestore.collection('Users').doc(currentUserId);
    await viewerRef.update({
      'totalAdViewsSupported': FieldValue.increment(1),
    });

    // Enregistrer le soutien (pour la limite quotidienne)
    await _recordSupport(postId, currentUserId!);

    // ✅ ENVOYER LA NOTIFICATION AU CRÉATEUR
    await _sendSupportNotification(creatorId, currentUserId!, postId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).postSupportThanks),
        backgroundColor: AppColors.of(context).primary,
        duration: Duration(seconds: 2),
      ),
    );
    // Mettre à jour l'état local
    setState(() {
      widget.post.adSupportCount = (widget.post.adSupportCount ?? 0) + 1;
      _isSupporting = false;
      _showRewardedAd = false;
    });

  }
  Widget _buildSupportButton(bool hasAccess) {
    final colors = AppColors.of(context);
    final isOwner = authProvider.loginUserData.id == widget.post.user_id;

    return Container(
      constraints: BoxConstraints(minWidth: 60),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasAccess
              ? colors.supportAccent.withOpacity(0.5)
              : colors.textSecondary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          // onTap: hasAccess && !_isSupporting && !isOwner ? _handleSupportAd : null,
          onTap: _handleGift,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSupporting)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.supportAccent,
                    ),
                  )
                else
                  Icon(
                    Icons.volunteer_activism,
                    size: 14,
                    color: hasAccess
                        ? colors.supportAccent
                        : colors.textSecondary.withOpacity(0.3),
                  ),
                SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context).postSupportCreator,
                  style: TextStyle(
                    fontSize: 12,
                    color: hasAccess
                        ? colors.supportAccent
                        : colors.textSecondary.withOpacity(0.3),
                  ),
                ),
                if ((widget.post.adSupportCount ?? 0) > 0) ...[
                  SizedBox(width: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.supportAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formatCount(widget.post.adSupportCount ?? 0),
                      style: TextStyle(fontSize: 10, color: colors.supportAccent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  @override
  void dispose() {
    MediaPlaybackManager.unregisterMedia(widget.post.id ?? '');
    super.dispose();
  }

  void _checkIfFavorite() {
    final userId = authProvider.loginUserData.id!;
    setState(() {
      _isFavorite = widget.post.users_favorite_id?.contains(userId) ?? false;
    });
  }

  Future<void> _toggleFavorite() async {
    if (_isProcessingFavorite) return;

    final userId = authProvider.loginUserData.id!;
    final postId = widget.post.id!;

    setState(() {
      _isProcessingFavorite = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      if (_isFavorite) {
        // Retirer des favoris
        await _removeFromFavorites(userId, postId, firestore);
      } else {
        // Ajouter aux favoris
        await _addToFavorites(userId, postId, firestore);
      }

      // Mettre à jour l'état local
      setState(() {
        _isFavorite = !_isFavorite;
        if (_isFavorite) {
          widget.post.favoritesCount = (widget.post.favoritesCount ?? 0) + 1;
          widget.post.users_favorite_id?.add(userId);
        } else {
          widget.post.favoritesCount = (widget.post.favoritesCount ?? 0) - 1;
          widget.post.users_favorite_id?.remove(userId);
        }
      });

      // Notifier le parent si nécessaire
      if (_isFavorite) {
        widget.onLoved?.call(); // Utiliser le callback existant pour l'amour
      }

      // Afficher un feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite
                ? '✅ Post ajouté aux favoris'
                : '🗑️ Post retiré des favoris',
            style: TextStyle(color: AppColors.of(context).onPrimary),
          ),
          backgroundColor: _isFavorite ? AppColors.of(context).primary : AppColors.of(context).surfaceVariant,
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      print('Erreur toggle favori: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Erreur lors de la modification',
            style: TextStyle(color: AppColors.of(context).onPrimary),
          ),
          backgroundColor: AppColors.of(context).danger,
        ),
      );
    } finally {
      setState(() {
        _isProcessingFavorite = false;
      });
    }
  }

  Future<void> _addToFavorites(String userId, String postId, FirebaseFirestore firestore) async {
    // Mettre à jour le post
    await firestore.collection('Posts').doc(postId).update({
      'users_favorite_id': FieldValue.arrayUnion([userId]),
      'favorites_count': FieldValue.increment(1),
      'popularity': FieldValue.increment(2), // Bonus de popularité pour favoris
      'updatedAt': DateTime.now().microsecondsSinceEpoch,
    });

    // Mettre à jour l'utilisateur
    await firestore.collection('Users').doc(userId).update({
      'favoritePostsIds': FieldValue.arrayUnion([postId]),
      'updatedAt': DateTime.now().microsecondsSinceEpoch,
    });

    // Créer une notification pour l'auteur du post
    if (widget.post.user_id != userId) {
      await _createFavoriteNotification(userId);
    }
    authProvider. incrementPostTotalInteractions(postId: widget.post.id!);

    authProvider. notifySubscribersOfInteraction(
      actionUserId: authProvider.loginUserData.id!,
      postOwnerId: widget.post.user_id!,
      postId: widget.post.id!,
      actionType: 'favorite',
      postDescription: widget.post.description,
      postImageUrl: widget.post.images?.first,
      postDataType: widget.post.dataType,
    );
    // Ajouter des points pour l'action
    addPointsForAction(UserAction.favorite);
    addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);
  }

  Future<void> _removeFromFavorites(String userId, String postId, FirebaseFirestore firestore) async {
    // Mettre à jour le post
    await firestore.collection('Posts').doc(postId).update({
      'users_favorite_id': FieldValue.arrayRemove([userId]),
      'favorites_count': FieldValue.increment(-1),
      'popularity': FieldValue.increment(-2),
      'updatedAt': DateTime.now().microsecondsSinceEpoch,
    });

    // Mettre à jour l'utilisateur
    await firestore.collection('Users').doc(userId).update({
      'favoritePostsIds': FieldValue.arrayRemove([postId]),
      'updatedAt': DateTime.now().microsecondsSinceEpoch,
    });
  }

  Future<void> _createFavoriteNotification(String userId) async {
    try {
      final notification = NotificationData(
        id: firestore.collection('Notifications').doc().id,
        titre: "Favoris ❤️",
        media_url: authProvider.loginUserData.imageUrl,
        type: NotificationType.FAVORITE.name,
        description: "@${authProvider.loginUserData.pseudo!} a ajouté votre post à ses favoris",
        users_id_view: [],
        user_id: userId,
        receiver_id: widget.post.user_id!,
        post_id: widget.post.id!,
        post_data_type: widget.post.dataType ?? PostDataType.IMAGE.name,
        updatedAt: DateTime.now().microsecondsSinceEpoch,
        createdAt: DateTime.now().microsecondsSinceEpoch,
        status: PostStatus.VALIDE.name,
      );

      await firestore.collection('Notifications').doc(notification.id).set(notification.toJson());

      // Notification push
      if (currentUser != null && currentUser!.oneIgnalUserid != null) {
        await authProvider.sendNotification(
          userIds: [currentUser!.oneIgnalUserid!],
          smallImage: authProvider.loginUserData.imageUrl!,
          send_user_id: userId,
          recever_user_id: widget.post.user_id!,
          message: "❤️ @${authProvider.loginUserData.pseudo!} a ajouté votre post à ses favoris",
          type_notif: NotificationType.FAVORITE.name,
          post_id: widget.post.id!,
          post_type: widget.post.dataType ?? PostDataType.IMAGE.name,
          chat_id: '',
        );
      }
    } catch (e) {
      print('Erreur création notification favori: $e');
    }
  }
  Future<void> _loadUserData() async {
    if (widget.post.user_id == null) return;

    setState(() {
      _isLoadingUser = true;
    });

    try {
      final userDoc = await firestore.collection('Users').doc(widget.post.user_id!).get();
      if (userDoc.exists) {
        setState(() {
          _currentUser = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
          widget.post.user = _currentUser;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement de l\'utilisateur: $e');
    } finally {
      setState(() {
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _loadCanalData() async {
    if (widget.post.canal_id == null || widget.post.canal_id!.isEmpty) return;

    setState(() {
      _isLoadingCanal = true;
    });

    try {
      final canalDoc = await firestore.collection('Canaux').doc(widget.post.canal_id!).get();
      if (canalDoc.exists) {
        final canalData = canalDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentCanal = Canal.fromJson(canalData);
          widget.post.canal = _currentCanal;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement du canal: $e');
    } finally {
      setState(() {
        _isLoadingCanal = false;
      });
    }
  }

  UserData? get currentUser {
    return widget.post.user ?? _currentUser;
  }

  Canal? get currentCanal {
    return widget.post.canal ?? _currentCanal;
  }

  // Vérifier si l'utilisateur a accès au contenu
  bool _hasAccessToContent() {
    if (currentCanal != null) {
      final isPrivate = currentCanal!.isPrivate == true;
      final isSubscribed = currentCanal!.usersSuiviId?.contains(authProvider.loginUserData.id) ?? false;
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
      final isCurrentUser = authProvider.loginUserData.id == widget.post.user_id;

      // Accès autorisé si :
      // - Le canal n'est pas privé
      // - OU l'utilisateur est abonné
      // - OU c'est un admin
      if (!isPrivate || isSubscribed || isAdmin|| isCurrentUser) {
        return true;
      }

      // Sinon, accès refusé
      return false;
    }

    // Si ce n'est pas un post de canal → accès libre
    return true;
  }

  // Vérifier si c'est un post de canal privé non accessible
  bool _isLockedContent() {
    if (currentCanal != null) {
      final isPrivate = currentCanal!.isPrivate == true;
      final isSubscribed = currentCanal!.usersSuiviId?.contains(authProvider.loginUserData.id) ?? false;
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
      final isCurrentUser = authProvider.loginUserData.id == widget.post.user_id;

      // Le contenu est verrouillé uniquement si :
      // - Le canal est privé
      // - L'utilisateur n'est pas abonné
      // - Et ce n'est pas un administrateur
      return isPrivate && !isSubscribed && !isAdmin&& !isCurrentUser;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    if (_isLoadingUser || _isLoadingCanal) {
      return _buildSkeletonLoader();
    }

    final isLocked = _isLockedContent();
    final hasAccess = _hasAccessToContent();

    return Container(
      color: colors.background,
      child: Column(
        children: [
          // Ligne de séparation supérieure
          Container(
            height: 0.5,
            color: colors.divider,
          ),

          // Contenu du post
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête du post
                _buildPostHeader(w, h),
                SizedBox(height: 8),

                // Contenu texte (avec limitation si contenu verrouillé)
                _buildPostContent(isLocked),
                SizedBox(height: 12),

                // Médias (images/vidéos) - verrouillés si pas d'accès

              if (widget.post.dataType == PostDataType.AUDIO.name)
    AudioPostCard(post: widget.post, isLocked: isLocked),
        if (widget.post.dataType == PostDataType.AUDIO.name)

    SizedBox(height: 12),

                if ((widget.post.images?.isNotEmpty ?? false)&&widget.post.dataType != PostDataType.AUDIO.name)
                  _buildMediaContent(h, isLocked),

                if (_isVideoPost(widget.post))
                  _buildVideoContent(h, isLocked),



                // Bouton d'abonnement si contenu verrouillé
                if (isLocked) _buildSubscribeButton(),

                // Actions du post
                SizedBox(height: 12),
                _buildPostActions(hasAccess),
                PostGiftsList(
                  postId: widget.post.id!,
                  compactLevel: CompactLevel.light,
                  maxDisplayItems: 10,
                ),
                // 🆕 AFFICHAGE DE LA PUB APRÈS LE POST SI CONDITION REMPLIE
                if (_shouldShowAd) ...[
                  const SizedBox(height: 12),
                  MrecAdWidget(  // ou AdaptiveAdWidget(useBanner: false)
                    onAdLoaded: () {
                      print('✅ Pub MREC affichée après le post ${widget.index}');
                    },
                    showLessAdsButton: false, // désactive le bouton "moins de pub" si tu veux
                  ),
                  const SizedBox(height: 8),
                ],

                if (_showRewardedAd)
                  RewardedAdWidget(
                    key: _rewardedAdKey,
                    onUserEarnedReward:(amount, name) async {
                      await _onSupportAdRewarded();
                    },
                    onAdDismissed: () {
                      setState(() {
                        _showRewardedAd = false;
                        _isSupporting = false;
                      });
                    },
                    child: SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
  Future<void> _sendSupportNotification(String creatorId, String supporterId, String postId) async {
    final now = DateTime.now().microsecondsSinceEpoch;
    final supporter = authProvider.loginUserData;
    final supporterName = supporter.pseudo ?? 'Un utilisateur';

    // Message incitatif avec le potentiel de gain
    final description = "@$supporterName a soutenu votre post en regardant une publicité ! (+1 pièces) 💰 Chaque soutien vous rapproche des 100€ (≈65 000 FCFA) par mois. Continuez à créer, on vous soutient !";

    // 1. Créer la notification dans Firestore
    final notificationId = firestore.collection('Notifications').doc().id;
    final notification = NotificationData(
      id: notificationId,
      titre: "Soutien 💪 + pièces",
      media_url: supporter.imageUrl ?? '',
      type: NotificationType.POST.name,
      description: description,
      users_id_view: [],
      user_id: supporterId,
      receiver_id: creatorId,
      post_id: postId,
      post_data_type: widget.post.dataType ?? PostDataType.IMAGE.name,
      updatedAt: now,
      createdAt: now,
      status: PostStatus.VALIDE.name,
    );
    await firestore.collection('Notifications').doc(notificationId).set(notification.toJson());

    // 2. Récupérer le token OneSignal du créateur
    final creatorDoc = await firestore.collection('Users').doc(creatorId).get();
    final creatorToken = creatorDoc.data()?['oneIgnalUserid'] as String?;
    if (creatorToken != null && creatorToken.isNotEmpty) {
      await authProvider.sendNotification(
        userIds: [creatorToken],
        smallImage: supporter.imageUrl ?? '',
        send_user_id: supporterId,
        recever_user_id: creatorId,
        message: "💪 @$supporterName vous a soutenu en regardant une vidéo ! + pièces 🎉 Continuez avec du contenu de qualité pour obtenir plus de soutiens !",        type_notif: NotificationType.SUPPORT.name,
        post_id: postId,
        post_type: widget.post.dataType ?? PostDataType.IMAGE.name,
        chat_id: '',
      );
    }
  }
  Widget _buildSkeletonLoader() {
    final colors = AppColors.of(context);
    return Container(
      color: colors.background,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: colors.shimmerBase),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 14, color: colors.shimmerBase),
                    SizedBox(height: 4),
                    Container(width: 80, height: 12, color: colors.shimmerBase),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(width: double.infinity, height: 16, color: colors.shimmerBase),
          SizedBox(height: 4),
          Container(width: double.infinity, height: 16, color: colors.shimmerBase),
          SizedBox(height: 8),
          Container(
            height: 200,
            width: double.infinity,
            color: colors.shimmerBase,
          ),
        ],
      ),
    );
  }
  Widget _buildPostHeader(double w, double h) {
    final colors = AppColors.of(context);
    final currentUserId = authProvider.loginUserData.id;
    final isCanalPost = currentCanal != null;
    final postOwner = isCanalPost ? currentCanal! : currentUser!;
    final isCurrentUser = currentUserId == currentUser?.id;

    // Vérifier si déjà abonné
    final isAbonne = isCanalPost
        ? currentCanal?.usersSuiviId?.contains(currentUserId) ?? false
        : currentUser?.userAbonnesIds?.contains(currentUserId) ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar avec détection de présence
        GestureDetector(
          onTap: () {
            if (isCanalPost) {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => CanalDetails(canal: currentCanal!),
              ));
            } else {
              showUserDetailsModalDialog(currentUser!, w, h, context);
            }
          },
          // 🔥 Bordure verte : ronde pour un utilisateur, carrée pour un canal
          child: isCanalPost
              ? Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(10),
                    color: colors.primary,
                    border: Border.all(color: colors.primary, width: 2),
                    image: _getProfileImage() != null
                        ? DecorationImage(image: _getProfileImage()!, fit: BoxFit.cover)
                        : null,
                  ),
                  child: _getProfileImage() == null
                      ? Icon(Icons.group, color: colors.onPrimary, size: 20)
                      : null,
                )
              : CircleAvatar(
                  radius: 25,
                  backgroundColor: colors.primary,
                  child: CircleAvatar(
                    radius: 23,
                    backgroundColor: colors.primary,
                    backgroundImage: _getProfileImage(),
                    child: _getProfileImage() == null
                        ? Icon(Icons.person, color: colors.onPrimary, size: 20)
                        : null,
                  ),
                ),
        ),
        SizedBox(width: 12),

        // Informations utilisateur et menu
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          _getDisplayName(),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(width: 4),
                        UserBadgeWidget(user: widget.post.user, size: 14)
                      ],
                    ),
                  ),

                  // Bouton S'abonner ou menu
                  if (!isCurrentUser && !isAbonne)
                    _buildFollowButton(isCanalPost, postOwner, isAbonne),
                  SizedBox(width: 5),
                  _buildCountryBadge(widget.post)
                ],
              ),
              SizedBox(height: 2),
              Text(
                _getFollowerCount(),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildPostHeader2(double w, double h) {
    final colors = AppColors.of(context);
    final currentUserId = authProvider.loginUserData.id;
    final isCanalPost = currentCanal != null;
    final postOwner = isCanalPost ? currentCanal! : currentUser!;
    final isCurrentUser = currentUserId == currentUser?.id;

    // Vérifier si déjà abonné
    final isAbonne = isCanalPost
        ? currentCanal?.usersSuiviId?.contains(currentUserId) ?? false
        : currentUser?.userAbonnesIds?.contains(currentUserId) ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        GestureDetector(
          onTap: () {
            if (isCanalPost) {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => CanalDetails(canal: currentCanal!),
              ));
            } else {
              showUserDetailsModalDialog(currentUser!, w, h, context);
            }
          },
          child: Stack(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: colors.primary,
                backgroundImage: _getProfileImage(),
                child: _getProfileImage() == null
                    ? Icon(
                  isCanalPost ? Icons.group : Icons.person,
                  color: colors.onPrimary,
                  size: 20,
                )
                    : null,
              ),
              if (_isVerified())
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: colors.background,
                      shape: BoxShape.circle,
                    ),
                    child:  Icon(Icons.verified, color: colors.info, size: 20),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: 12),

        // Informations utilisateur et menu
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          _getDisplayName(),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(width: 4),
                        // if (_isVerified())
                          UserBadgeWidget(user: widget.post.user, size: 14)
                      ],
                    ),
                  ),

                  // Bouton S'abonner ou menu
                  if (!isCurrentUser && !isAbonne)
                    _buildFollowButton(isCanalPost, postOwner, isAbonne),
                  SizedBox(width: 5),
                  _buildCountryBadge(widget.post)
                  // GestureDetector(
                  //   onTap: () => _showPostMenu(widget.post),
                  //   child: Icon(
                  //     Icons.more_horiz,
                  //     color: _afroTextSecondary,
                  //     size: 20,
                  //   ),
                  // ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                _getFollowerCount(),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildCountryBadge(Post post) {
    final colors = AppColors.of(context);
    final isAllCountries = post.isAvailableInAllCountries == true;
    var countryCodes = post.availableCountries ?? [];

    // Session 13 : si le pays du filtre actif figure dans la liste, le placer en premier
    // (sans ajouter/retirer d'éléments) pour que le badge affiche prioritairement ce pays.
    final filterCountry = widget.currentFilterCountry?.toUpperCase();
    if (filterCountry != null && countryCodes.length > 1) {
      final idx = countryCodes.indexWhere((c) => c.toUpperCase() == filterCountry);
      if (idx > 0) {
        countryCodes = [
          countryCodes[idx],
          ...countryCodes.where((c) => c.toUpperCase() != filterCountry),
        ];
      }
    }

    // Déterminer le contenu du badge
    String displayText = '';
    String flagEmoji = '🌍';
    int countryCount = 1;

    if (isAllCountries) {
      displayText = 'Tous';
      flagEmoji = '🌍';
    } else if (countryCodes.isNotEmpty) {
      // Prendre le premier pays comme indicateur
      final firstCountryCode = countryCodes.first.toUpperCase();

      // Chercher l'emoji du drapeau
      final country = AfricanCountry.allCountries.firstWhere(
            (c) => c.code == firstCountryCode,
        orElse: () => AfricanCountry(
            code: firstCountryCode,
            name: firstCountryCode,
            flag: '🏳️'
        ),
      );
      flagEmoji = country.flag;
      countryCount = countryCodes.length;

      // Afficher le code du pays ou "+X" pour multiples
      if (countryCount == 1) {
        displayText = firstCountryCode;
      } else {
        displayText = '+${countryCount - 1}';
      }
    }

    // Choisir la couleur selon le type
    Color backgroundColor;
    Color textColor;
    IconData? icon;

    if (isAllCountries) {
      backgroundColor = colors.accent.withOpacity(0.9);
      textColor = colors.onAccent;
      icon = Icons.public;
    } else if (countryCodes.isNotEmpty) {
      backgroundColor = colors.danger.withOpacity(0.9);
      textColor = Colors.white;
    } else {
      // Par défaut : gris
      backgroundColor = Colors.grey[800]!.withOpacity(0.9);
      textColor = Colors.white;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icône/drapeau
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(
                flagEmoji,
                style: TextStyle(fontSize: 10),
              ),
            ),
          ),

          SizedBox(width: 6),

          // Texte
          Text(
            displayText,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),

          // Indicateur multi-pays
          if (countryCodes.length > 1) ...[
            SizedBox(width: 2),
            Icon(
              Icons.add,
              color: textColor,
              size: 10,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFollowButton(bool isCanalPost, dynamic postOwner, bool isAbonne) {
    final colors = AppColors.of(context);
    return Container(
      height: 28,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isCanalPost && (postOwner as Canal).isPrivate == true
              ? colors.accent
              : colors.primary,
          foregroundColor: isCanalPost && (postOwner as Canal).isPrivate == true
              ? colors.onAccent
              : colors.onPrimary,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _isProcessingFollow ? null : () async {
          setState(() {
            _isProcessingFollow = true;
          });

          try {
            if (isCanalPost) {
              // Navigation vers la page du canal pour l'abonnement
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CanalDetails(canal: postOwner),
                ),
              );

              // Recharger les données si nécessaire
              if (result != null) {
                await _loadCanalData();
              }
            } else {
              // Abonnement à l'utilisateur
              await authProvider.abonner(postOwner as UserData, context);
              // Recharger les données utilisateur
              await _loadUserData();
            }
          } catch (e) {
            print('Erreur lors de l\'abonnement: $e');
          } finally {
            if (mounted) {
              setState(() {
                _isProcessingFollow = false;
              });
            }
          }
        },
        child: _isProcessingFollow
            ? SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isCanalPost && (postOwner as Canal).isPrivate == true
                ? colors.onAccent
                : colors.onPrimary,
          ),
        )
            : Text(
          isCanalPost && (postOwner as Canal).isPrivate == true
              ? 'S\'abonner'
              : 'Suivre',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _generateVideoThumbnail() async {
    if (!_isVideoPost(widget.post) || widget.post.url_media == null) return;

    setState(() {
      _isGeneratingThumbnail = true;
    });

    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video:_optimizeUrl(widget.post.url_media!)  ,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: 1000,
      );

      if (thumbnailPath != null && File(thumbnailPath).existsSync()) {
        setState(() {
          _videoThumbnailPath = thumbnailPath;
          _isGeneratingThumbnail = false;
        });
      }
    } catch (e) {
      print('Erreur génération thumbnail: $e');
      setState(() {
        _isGeneratingThumbnail = false;
      });
    }
  }

  Widget _buildPostContent(bool isLocked) {
    final colors = AppColors.of(context);
    final text = widget.post.description ?? "";

    if (isLocked) {
      // Contenu verrouillé - afficher seulement 2 lignes
      final words = text.split(' ');
      final limitedText = words.length > 20
          ? words.take(20).join(' ') + '...'
          : text;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            limitedText,
            style: TextStyle(
              fontSize: 15,
              color: colors.textSecondary, // Texte grisé pour contenu verrouillé
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lock, color: colors.accent, size: 16),
              SizedBox(width: 4),
              Text(
                'Contenu réservé aux abonnés',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Contenu déverrouillé - afficher normalement
    final fullText = _translatedDescription ?? text;
    final words = fullText.split(' ');
    final isLong = words.length > 50;
    final displayedText = _isExpanded || !isLong
        ? fullText
        : words.take(50).join(' ') + '...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailsPost(post: widget.post),
            ),
          ),
          child: HashTagText(
            text: displayedText,
            decoratedStyle: TextStyle(
              fontSize: 15,
              color: colors.info,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            basicStyle: TextStyle(
              fontSize: 15,
              color: colors.textPrimary,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            onTap: (text) {
              // Gestion des hashtags
            },
          ),
        ),
        if (widget.post.id != null)
          TranslatableDescription(
            postId: widget.post.id!,
            text: text,
            targetLang: Provider.of<LocaleProvider>(context, listen: false).locale.languageCode,
            onToggle: (translated) => setState(() => _translatedDescription = translated),
          ),
        SizedBox(height: 5,),
        if (isLong)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _isExpanded ? "Voir moins" : "Voir plus",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.info,
                    ),
                  ),
                ),
              ),
              _buildSupportButton(true),
              // SizedBox(width: 3,),
              //
              // buildTotalVues(
              //   totalCount: widget.post.vues ?? 0,
              //   color: Colors.yellow,
              //   showLabel: false,
              // ),
            ],
          ),
        if (!isLong)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildSupportButton(true),
              // SizedBox(width: 3,),
              //
              // buildTotalVues(
              //   totalCount: widget.post.vues ?? 0,
              //   color: Colors.yellow,
              //   showLabel: false,
              // ),
            ],
          ),
        _buildEventBadge(widget.post)
      ],
    );
  }

  Widget _buildMediaContent(double h, bool isLocked) {
    final colors = AppColors.of(context);
    final images = widget.post.images!;
    final imageCount = images.length;

    // Définir la hauteur en fonction du nombre d'images
    double contentHeight;
    if (imageCount == 1) {
      contentHeight = h * 0.4; // Hauteur normale pour 1 image
    } else if (imageCount == 2) {
      contentHeight = h * 0.4; // Même hauteur pour 2 images
    } else if (imageCount == 3) {
      contentHeight = h * 0.4; // Même hauteur pour 3 images
    } else {
      contentHeight = h * 0.4; // Même hauteur pour 4+ images
    }

    return Container(
      height: contentHeight, // 🔥 HAUTEUR EXPLICITE POUR ÉVITER L'ERREUR
      child: Stack(
        children: [
          // Conteneur principal pour le grid d'images
          Container(
            width: double.infinity,
            height: contentHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colors.shimmerBase,
            ),
            child: Opacity(
              opacity: isLocked ? 0.15 : 1.0,
              child: _buildImageGrid(contentHeight, imageCount),
            ),
          ),

          // Overlay pour contenu verrouillé
          if (isLocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, color: colors.accent, size: 50),
                      SizedBox(height: 8),
                      Text(
                        'Contenu verrouillé',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Abonnez-vous pour voir ce contenu',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Badge indiquant le nombre d'images (si plus de 1)
          if (imageCount > 1 && !isLocked)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      '$imageCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

// 🔥 MÉTHODE MODIFIÉE POUR PRENDRE LA HAUTEUR EN PARAMÈTRE
  Widget _buildImageGrid(double height, int imageCount) {
    final images = widget.post.images!;

    if (imageCount == 1) {
      // 1 image : pleine largeur
      return _buildSingleImage(images[0], height);
    } else if (imageCount == 2) {
      // 2 images : côte à côte
      return _buildTwoImages(images, height);
    } else if (imageCount == 3) {
      // 3 images : 1 grande + 2 petites
      return _buildThreeImages(images, height);
    } else {
      // 4+ images : grid 2x2 avec indicateur
      return _buildMultipleImages(images, height);
    }
  }

  Widget _buildSingleImage(String url, double height) {
    final colors = AppColors.of(context);
    final imageUrl = _optimizeUrl(url);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsPost(post: widget.post),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: height,
          placeholder: (context, url) => Container(
            color: colors.shimmerBase,
          ),
          errorWidget: (context, url, error) => Container(
            color: colors.shimmerBase,
            child: Icon(Icons.broken_image, color: colors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoImages(List<String> images, double height) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsPost(post: widget.post),
          ),
        );
      },
      child: Row(
        children: [
          // Première image - moitié gauche
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: CachedNetworkImage(
                  imageUrl:_optimizeUrl( images[0])
               ,
                  fit: BoxFit.cover,
                  height: height,
                  placeholder: (context, url) => Container(
                    color: colors.shimmerBase,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: colors.shimmerBase,
                    child: Icon(Icons.broken_image, color: colors.textSecondary),
                  ),
                ),
              ),
            ),
          ),

          // Deuxième image - moitié droite
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: CachedNetworkImage(
                  imageUrl: _optimizeUrl( images[1]),
                  fit: BoxFit.cover,
                  height: height,
                  placeholder: (context, url) => Container(
                    color: colors.shimmerBase,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: colors.shimmerBase,
                    child: Icon(Icons.broken_image, color: colors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeImages(List<String> images, double height) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsPost(post: widget.post),
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Première image - 2/3 de la largeur
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.only(right: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: CachedNetworkImage(
                  imageUrl: _optimizeUrl( images[0]),
                  fit: BoxFit.cover,
                  height: height,
                  placeholder: (context, url) => Container(
                    color: colors.shimmerBase,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: colors.shimmerBase,
                    child: Icon(Icons.broken_image, color: colors.textSecondary),
                  ),
                ),
              ),
            ),
          ),

          // Deuxième et troisième images - 1/3 de la largeur, divisées verticalement
          Expanded(
            flex: 1,
            child: Container(
              height: height,
              padding: EdgeInsets.only(left: 2),
              child: Column(
                children: [
                  // Deuxième image - moitié supérieure
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(16),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: _optimizeUrl( images[1]),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            color: colors.shimmerBase,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colors.shimmerBase,
                            child: Icon(Icons.broken_image, color: colors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Troisième image - moitié inférieure
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(16),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: _optimizeUrl( images[2]),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            color: colors.shimmerBase,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colors.shimmerBase,
                            child: Icon(Icons.broken_image, color: colors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleImages(List<String> images, double height) {
    final colors = AppColors.of(context);
    final displayedImages = images.take(4).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth / 2).toInt();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsPost(post: widget.post),
          ),
        );
      },
      child: Container(
        height: height,
        child: GridView.builder(
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: displayedImages.length,
          itemBuilder: (context, index) {
            final optimizedUrl = _optimizeUrl(displayedImages[index]);

            BorderRadius borderRadius;
            if (displayedImages.length == 4) {
              switch (index) {
                case 0:
                  borderRadius = BorderRadius.only(topLeft: Radius.circular(16));
                  break;
                case 1:
                  borderRadius = BorderRadius.only(topRight: Radius.circular(16));
                  break;
                case 2:
                  borderRadius = BorderRadius.only(bottomLeft: Radius.circular(16));
                  break;
                case 3:
                  borderRadius = BorderRadius.only(bottomRight: Radius.circular(16));
                  break;
                default:
                  borderRadius = BorderRadius.circular(0);
              }
            } else {
              borderRadius = BorderRadius.circular(0);
            }

            bool hasOverlay = index == 3 && images.length > 4;

            return Stack(
              children: [
                ClipRRect(
                  borderRadius: borderRadius,
                  child: CachedNetworkImage(
                    imageUrl: optimizedUrl,  // 🔥 URL OPTIMISÉE
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Container(
                      color: colors.shimmerBase,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colors.shimmerBase,
                      child: Icon(Icons.broken_image, color: colors.textSecondary),
                    ),
                  ),
                ),
                if (hasOverlay)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.6),
                      child: Center(
                        child: Text(
                          '+${images.length - 4}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
  Widget _buildVideoContent(double h, bool isLocked) {
    final colors = AppColors.of(context);
    return Stack(
      children: [
        // Thumbnail vidéo ou fallback
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _isGeneratingThumbnail
              ? Center(
            child: CircularProgressIndicator(color: colors.info),
          )
              : (_videoThumbnailPath != null &&
              File(_videoThumbnailPath!).existsSync())
              ? GestureDetector(
            onTap: () {
              if(widget.post.dataType==PostDataType.VIDEO.name){
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoYoutubePageDetails(initialPost: widget.post),
                  ),
                );
              }else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsPost(post: widget.post),
                  ),
                );
              }
            },
            child: Opacity(
              opacity: isLocked ? 0.6 : 1.0, // réduit la visibilité si verrouillé
              child: Image.file(
                File(_videoThumbnailPath!),
                fit: BoxFit.cover,
                width: double.infinity,
                height: h * 0.4,
              ),
            ),
          )
              : _buildFallbackThumbnail(),
        ),

        // Overlay verrouillage
        if (isLocked)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, color: colors.accent, size: 50),
                    SizedBox(height: 8),
                    Text(
                      'Vidéo verrouillée',
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Abonnez-vous pour voir cette vidéo',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Overlay play si déverrouillé
        if (!isLocked)
          Positioned.fill(
            child: Center(
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
              ),
            ),
          ),

        // Badge vidéo en haut à gauche
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text(
                  'Vidéo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackThumbnail() {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.shimmerBase,
            colors.shimmerHighlight,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam,
              color: colors.textSecondary.withOpacity(0.7),
              size: 50,
            ),
            SizedBox(height: 8),
            Text(
              'Vidéo',
              style: TextStyle(
                color: colors.textSecondary.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribeButton() {
    final colors = AppColors.of(context);
    final isCanalPost = currentCanal != null;
    final isPrivate = currentCanal?.isPrivate == true;
    final subscriptionPrice = currentCanal?.subscriptionPrice ?? 0;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 12),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        onPressed: () {
          if (isCanalPost) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CanalDetails(canal: currentCanal!),
              ),
            );
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_open, size: 18),
            SizedBox(width: 8),
            Text(
              isPrivate
                  ? 'S\'ABONNER - ${subscriptionPrice.toInt()} FCFA'
                  : 'SUIVRE LE CANAL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostActions(bool hasAccess) {
    final colors = AppColors.of(context);
    final isLiked = isIn(widget.post.users_love_id ?? [], authProvider.loginUserData.id!);

    return Container(
      margin: EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Commentaire
          _buildActionButton(
            icon: FontAwesome.comment_o,
            count: widget.post.comments ?? 0,
            color: colors.textSecondary,
            onPressed: hasAccess ? () {
              _showCommentsModal(widget.post);

              recordUniquePostView();
              // 🔥 APPEL DU CALLBACK
              widget.onCommented?.call();
            } : null,
          ),

          // Vues
          _buildActionButton(
            icon:  Icons.bar_chart,
            count: widget.post.totalInteractions ?? 0,
            color: colors.textSecondary,
            onPressed: hasAccess ? () {
              _handleRepost();
              recordUniquePostView();
              // 🔥 APPEL DU CALLBACK
              widget.onViewed?.call();
            } : null,
          ),

          // Like
          _buildActionButton(
            // icon: isLiked ? FontAwesome.heart : FontAwesome.heart_o,
            icon:  FontAwesome.heart_o,
            count: widget.post.loves ?? 0,
            color: isLiked ? colors.danger : colors.textSecondary,
            onPressed: hasAccess ? () {
              _handleLike();
              recordUniquePostView();
              // 🔥 APPEL DU CALLBACK
              widget.onLiked?.call();
            } : null,
          ),
          // FAVORIS (NOUVEAU)
          _buildFavoriteButton(hasAccess),

          // Cadeau
          _buildActionButton(
            icon: FontAwesome.gift,
            count: widget.post.totalGiftCoinsSentOnThisPost ?? 0,
            color: colors.textSecondary,
            onPressed: hasAccess ? () {
              recordUniquePostView();
              _handleGift();
              // 🔥 APPEL DU CALLBACK (optionnel pour cadeau)
            } : null,
          ),

          // Partager
          _isSharing
              ? SizedBox(
            width: 40, // Ajustez selon la taille de vos boutons
            height: 40,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2, color: colors.textSecondary),
            ),
          )
              : _buildActionButton(
            icon: Icons.share,
            count: widget.post.partage ?? 0,
            color: colors.textSecondary,
            onPressed: hasAccess ? () {
              _handleShare();
              recordUniquePostView();
              // Le callback est déjà appelé dans _handleShare ou ici
            } : null,
          ),
        ],
      ),
    );
  }
  Widget _buildFavoriteButton(bool hasAccess) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: hasAccess && !_isProcessingFavorite ? _toggleFavorite : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              if (_isProcessingFavorite)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textSecondary.withOpacity(_isFavorite ? 1.0 : 0.3),
                  ),
                )
              else
                Icon(
                  _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                  color: hasAccess
                      ? colors.textSecondary
                      : colors.textSecondary.withOpacity(0.3),
                ).animate(target: _isFavorite ? 1 : 0).scaleXY(begin: 1.0, end: 1.2, duration: 150.ms, curve: Curves.easeOut).then().scaleXY(begin: 1.2, end: 1.0, duration: 150.ms),
              SizedBox(width: 6),
              Text(
                _formatCount(widget.post.favoritesCount ?? 0),
                style: TextStyle(
                  color: hasAccess
                      ? colors.textSecondary
                      : colors.textSecondary.withOpacity(0.3),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildActionButton({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: onPressed != null ? color : color.withOpacity(0.3),
                  ),
                )
              else
                Icon(icon, size: 18, color: onPressed != null ? color : color.withOpacity(0.3)),
              SizedBox(width: 6),
              Text(
                _formatCount(count),
                style: TextStyle(
                  color: onPressed != null ? color : color.withOpacity(0.3),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // Méthodes utilitaires
// Dans _getProfileImage()
  ImageProvider? _getProfileImage() {
    String? imageUrl;

    if (currentCanal != null && currentCanal!.urlImage != null) {
      imageUrl = currentCanal!.urlImage;
    } else if (currentUser != null && currentUser!.imageUrl != null) {
      imageUrl = currentUser!.imageUrl;
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final optimizedUrl = _optimizeUrl(imageUrl); // 100px suffisant pour un avatar
      return NetworkImage(optimizedUrl);
    }

    return null;
  }

  String _getFollowerCount() {
    if (currentCanal != null) {
      return "${currentCanal!.usersSuiviId?.length ?? 0} abonné(s)";
    } else if (currentUser != null) {
      return "${currentUser!.userAbonnesIds?.length ?? 0} abonné(s)";
    }
    return "0 abonné(s)";
  }

  bool _isVerified() {
    if (currentCanal != null) return currentCanal!.isVerify ?? false;
    if (currentUser != null) return currentUser!.isVerify ?? false;
    return false;
  }

  String _getDisplayName() {
    String name;

    if (currentCanal != null) {
      name = '#${currentCanal!.titre}';
    } else if (currentUser != null) {
      name = '@${currentUser!.pseudo}';
    } else {
      name = 'Utilisateur';
    }

    const maxLength = 20;
    if (name.length > maxLength) {
      name = name.substring(0, maxLength) + '...';
    }

    return name;
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  bool _isVideoPost(Post post) {
    return post.dataType == PostDataType.VIDEO.name ||
        (post.url_media ?? '').contains('.mp4') ||
        (post.url_media ?? '').contains('.mov') ||
        (post.url_media ?? '').contains('.avi') ||
        (post.url_media ?? '').contains('.webm') ||
        (post.url_media ?? '').contains('.mkv') ||
        (post.description ?? '').toLowerCase().contains('#video');
  }

  // Méthodes de gestion des actions
  void _showCommentsModal(Post post) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Commentaires',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PostComments(post: post),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostMenu(Post post) {
    final colors = AppColors.of(context);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.user_id != authProvider.loginUserData.id)
              _buildMenuOption(
                Icons.flag,
                "Signaler",
                colors.textPrimary,
                    () async {
                  post.status = PostStatus.SIGNALER.name;
                  final value = await postProvider.updateVuePost(post, context);
                  Navigator.pop(context);

                  final snackBar = SnackBar(
                    content: Text(
                      value ? 'Post signalé !' : 'Échec du signalement !',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: value ? AppColors.of(context).primary : AppColors.of(context).danger),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
              ),

            if (post.user!.id == authProvider.loginUserData.id ||
                authProvider.loginUserData.role == UserRole.ADM.name)
              _buildMenuOption(
                Icons.delete,
                "Supprimer",
                colors.danger,
                    () async {
                  if (authProvider.loginUserData.role == UserRole.ADM.name) {
                    await _deletePost(post);
                  } else {
                    post.status = PostStatus.SUPPRIMER.name;
                    await _deletePost(post);
                  }
                  Navigator.pop(context);

                  final snackBar = SnackBar(
                    content: Text(
                      'Post supprimé !',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.of(context).primary),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
              ),

            SizedBox(height: 8),
            Container(height: 0.5, color: colors.divider),
            SizedBox(height: 8),

            _buildMenuOption(Icons.cancel, "Annuler", colors.textSecondary, () {
              Navigator.pop(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(
      IconData icon, String text, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 12),
              Text(text, style: TextStyle(color: color, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 MÉTHODE LIKE AVEC CALLBACK
  Future<void> _handleLike2() async {
    try {
      if (!isIn(widget.post.users_love_id!, authProvider.loginUserData.id!)) {
        setState(() {
          widget.post.loves = widget.post.loves! + 1;
          widget.post.users_love_id!.add(authProvider.loginUserData.id!);
        });

        await firestore.collection('Posts').doc(widget.post.id).update({
          'loves': FieldValue.increment(1),
          'users_love_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(1),
        });
        addPointsForAction(UserAction.like);
        addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);
        if (currentUser != null && currentUser!.oneIgnalUserid != null) {
          await authProvider.sendNotification(
            userIds: [currentUser!.oneIgnalUserid!],
            smallImage: authProvider.loginUserData.imageUrl!,
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: widget.post.user_id!,
            message: "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look",
            type_notif: NotificationType.POST.name,
            post_id: widget.post.id!,
            post_type: PostDataType.IMAGE.name,
            chat_id: '',
          );
        }



        // 🔥 APPEL DU CALLBACK LOVE
        widget.onLoved?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+ de points ajoutés à votre compte',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.of(context).primary),
            ),
          ),
        );
      }
    } catch (e) {
      print("Erreur like: $e");
    }
  }
  Future<void> _handleLike() async {
    try {
      // Vérifier si l'utilisateur a déjà liké
      // if (isIn(widget.post.users_love_id!, authProvider.loginUserData.id!)) {
      //   return;
      // }

      // 🔥 Vérifier d'abord si l'utilisateur a assez de pièces pour le like
      final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
      final hasEnoughCoins = (coinProvider.giftCoinsBalance >= 2);

      if (!hasEnoughCoins) {
        _showInsufficientCoinsForLikeDialog();
        return;
      }

      // 🔥 Envoyer le like avec les pièces
      final success = await coinProvider.sendLikeWithCoins(
        senderId: authProvider.loginUserData.id!,
        receiverId: widget.post.user_id!,
        post: widget.post,
        context: context,
      );

      if (!success) {
        _showInsufficientCoinsForLikeDialog();
        return;
      }

      // Mettre à jour l'UI
      setState(() {
        widget.post.loves = (widget.post.loves ?? 0) + 1;
        widget.post.users_love_id ??= [];
        widget.post.users_love_id!.add(authProvider.loginUserData.id!);
      });

      if (!isIn(widget.post.users_love_id!, authProvider.loginUserData.id!)) {
        // Ajouter des points pour l'action (système existant)
        addPointsForAction(UserAction.like);
        addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);

        // Envoyer les notifications (comme avant)
        await _sendLikeNotifications();

        // 🔥 APPEL DU CALLBACK LOVE
        widget.onLoved?.call();
      }


      //
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('❤️ Like envoyé ! Le créateur a reçu 1 pièce.'),
      //     backgroundColor: Colors.green,
      //     duration: Duration(seconds: 2),
      //   ),
      // );
    } catch (e) {
      print("Erreur like: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Erreur: $e'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    }
  }

// Nouveau dialog pour solde de pièces insuffisant pour le like
  void _showInsufficientCoinsForLikeDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final dc = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: dc.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '💡 Soutenez le créateur !',
            style: TextStyle(color: dc.accent, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chaque like que vous envoyez offre 1 pièce au créateur du post !',
                style: TextStyle(color: dc.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dc.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dc.accent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Le like coûte 2 pièces :\n• Pour soutenir le créateur',
                        style: TextStyle(color: dc.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Rechargez votre compte pour continuer à soutenir vos créateurs préférés !',
                style: TextStyle(color: dc.textSecondary, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: dc.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CoinRechargeScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: dc.accent,
                foregroundColor: dc.onAccent,
              ),
              child: const Text('Recharger', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

// Extraire la logique des notifications dans une méthode séparée
  Future<void> _sendLikeNotifications() async {
    final currentTimeMicroseconds = DateTime.now().microsecondsSinceEpoch;
    final userDoc = await firestore.collection('Users').doc(widget.post.user_id!).get();

    if (userDoc.exists) {
      final userData = userDoc.data();
      final lastNotificationTime = userData?['lastNotificationTime'] ?? 0;
      const twentyMinutesMicroseconds = 20 * 60 * 1000 * 1000;
      final timeSinceLastNotification = currentTimeMicroseconds - lastNotificationTime;

      if (timeSinceLastNotification >= twentyMinutesMicroseconds || lastNotificationTime == 0) {
        // Notification Firebase
        final notificationId = firestore.collection('Notifications').doc().id;
        final notification = NotificationData(
          id: notificationId,
          titre: "Like ❤️ + 1 pièce",
          media_url: authProvider.loginUserData.imageUrl,
          type: NotificationType.POST.name,
          description: "@${authProvider.loginUserData.pseudo!} a aimé votre post et vous a offert 1 pièce !",
          users_id_view: [],
          user_id: authProvider.loginUserData.id!,
          receiver_id: widget.post.user_id!,
          post_id: widget.post.id!,
          post_data_type: widget.post.dataType ?? PostDataType.IMAGE.name,
          updatedAt: currentTimeMicroseconds,
          createdAt: currentTimeMicroseconds,
          status: PostStatus.VALIDE.name,
        );
        await firestore.collection('Notifications').doc(notificationId).set(notification.toJson());

        // Push notification
        if (currentUser != null && currentUser!.oneIgnalUserid != null) {
          await authProvider.sendNotification(
            userIds: [currentUser!.oneIgnalUserid!],
            smallImage: authProvider.loginUserData.imageUrl!,
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: widget.post.user_id!,
            message: "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look et vous a offert 1 pièce !",
            type_notif: NotificationType.POST.name,
            post_id: widget.post.id!,
            post_type: PostDataType.IMAGE.name,
            chat_id: '',
          );
        }

        await firestore.collection('Users').doc(widget.post.user_id!).update({
          'lastNotificationTime': currentTimeMicroseconds
        });
      }
    }

    authProvider.incrementPostTotalInteractions(postId: widget.post.id!);
    authProvider.notifySubscribersOfInteraction(
      actionUserId: authProvider.loginUserData.id!,
      postOwnerId: widget.post.user_id!,
      postId: widget.post.id!,
      actionType: 'like',
      postDescription: widget.post.description,
      postImageUrl: widget.post.images?.first,
      postDataType: widget.post.dataType,
    );
  }
  Future<void> _handleLike3() async {
    try {
      if (!isIn(widget.post.users_love_id!, authProvider.loginUserData.id!)) {
        setState(() {
          widget.post.loves = widget.post.loves! + 1;
          widget.post.users_love_id!.add(authProvider.loginUserData.id!);
        });

        await firestore.collection('Posts').doc(widget.post.id).update({
          'loves': FieldValue.increment(1),
          'users_love_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(1),
        });

        addPointsForAction(UserAction.like);
        addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);

        // ✅ TIMESTAMP ACTUEL EN MICROSECONDES
        final currentTimeMicroseconds = DateTime.now().microsecondsSinceEpoch;

        // ✅ RÉCUPÉRER L'UTILISATEUR CIBLE
        final userDoc = await firestore.collection('Users').doc(widget.post.user_id!).get();

        if (userDoc.exists) {
          final userData = userDoc.data();

          // ✅ Récupérer le dernier timestamp de notification (push + firebase)
          // On utilise un seul champ pour contrôler les deux
          final lastNotificationTime = userData?['lastNotificationTime'] ?? 0;

          // 20 minutes en microsecondes = 20 * 60 * 1000 * 1000
          const twentyMinutesMicroseconds = 20 * 60 * 1000 * 1000;
          final timeSinceLastNotification = currentTimeMicroseconds - lastNotificationTime;

          // ✅ VÉRIFICATION SI 20 MINUTES SE SONT ÉCOULÉES
          if (timeSinceLastNotification >= twentyMinutesMicroseconds || lastNotificationTime == 0) {

            // =====================================================
            // ✅ 1. ENREGISTRER LA NOTIFICATION DANS FIREBASE
            // =====================================================
            final notificationId = firestore.collection('Notifications').doc().id;

            final notification = NotificationData(
              id: notificationId,
              titre: "Like ❤️",
              media_url: authProvider.loginUserData.imageUrl,
              type: NotificationType.POST.name,
              description: "@${authProvider.loginUserData.pseudo!} a aimé votre post",
              users_id_view: [],
              user_id: authProvider.loginUserData.id!,
              receiver_id: widget.post.user_id!,
              post_id: widget.post.id!,
              post_data_type: widget.post.dataType ?? PostDataType.IMAGE.name,
              updatedAt: currentTimeMicroseconds,
              createdAt: currentTimeMicroseconds,
              status: PostStatus.VALIDE.name,
            );

            // Sauvegarder la notification
            await firestore.collection('Notifications').doc(notificationId).set(notification.toJson());
            print("✅ Notification Firebase enregistrée (contrôle 20 minutes respecté)");

            // =====================================================
            // ✅ 2. ENVOYER LA PUSH NOTIFICATION
            // =====================================================
            if (currentUser != null && currentUser!.oneIgnalUserid != null) {
              await authProvider.sendNotification(
                userIds: [currentUser!.oneIgnalUserid!],
                smallImage: authProvider.loginUserData.imageUrl!,
                send_user_id: authProvider.loginUserData.id!,
                recever_user_id: widget.post.user_id!,
                message: "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look",
                type_notif: NotificationType.POST.name,
                post_id: widget.post.id!,
                post_type: PostDataType.IMAGE.name,
                chat_id: '',
              );
              print("✅ Push notification envoyée");
            }

            // =====================================================
            // ✅ 3. METTRE À JOUR LE TIMESTAMP
            // =====================================================
            await firestore.collection('Users').doc(widget.post.user_id!).update({
              'lastNotificationTime': currentTimeMicroseconds // Un seul champ pour tout
            });

          }
          else {
            // ⏱️ LIMITE ATTEINTE - NI NOTIFICATION NI PUSH
            final minutesPassed = (timeSinceLastNotification / (60 * 1000 * 1000)).toStringAsFixed(1);
            final minutesRemaining = ((twentyMinutesMicroseconds - timeSinceLastNotification) / (60 * 1000 * 1000)).toStringAsFixed(1);

            print("⏱️ Notification limitée - Dernière notification il y a $minutesPassed minutes");
            print("⏱️ Prochaine notification possible dans $minutesRemaining minutes");

            // Optionnel: Afficher un message à l'utilisateur
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '👍 Like ajouté (notification dans ${minutesRemaining} min)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.of(context).warning),
                ),
                backgroundColor: AppColors.of(context).warning,
                duration: Duration(seconds: 2),
              ),
            );
          }
          authProvider. incrementPostTotalInteractions(postId: widget.post.id!);

          authProvider. notifySubscribersOfInteraction(
            actionUserId: authProvider.loginUserData.id!,
            postOwnerId: widget.post.user_id!,
            postId: widget.post.id!,
            actionType: 'like',
            postDescription: widget.post.description,
            postImageUrl: widget.post.images?.first,
            postDataType: widget.post.dataType,
          );
        }

        // 🔥 APPEL DU CALLBACK LOVE
        widget.onLoved?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+ de points ajoutés à votre compte',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.of(context).primary),
            ),
          ),
        );
      }
    } catch (e) {
      print("Erreur like: $e");
    }
  }

  void _handleRepost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsPost(post: widget.post),
      ),
    );
  }

  void _handleGift2() {
    _showGiftDialog(widget.post);
  }



// 2. Modifier la méthode _handleGift
  void _handleGift() {
    showDialog(
      context: context,
      builder: (context) => CoinGiftDialog(
        receiverId: widget.post.user_id!,
        receiverName: widget.post.user?.pseudo ?? 'Créateur',
        receiverAvatar: widget.post.user?.imageUrl ?? '',
        post: widget.post,
        onGiftSuccess: () async {
          // Mettre à jour l'affichage local du compteur de cadeaux
          setState(() {
            widget.post.users_cadeau_id ??= [];
            if (!widget.post.users_cadeau_id!.contains(authProvider.loginUserData.id!)) {
              widget.post.users_cadeau_id!.add(authProvider.loginUserData.id!);
            }
          });

          // Rafraîchir le provider pour mettre à jour le solde
          final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
          await coinProvider.refreshBalance(authProvider.loginUserData.id!);

          // Afficher un snackbar de confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🎁 Cadeau envoyé avec succès !'),
              backgroundColor: AppColors.of(context).primary,
              duration: const Duration(seconds: 2),
            ),
          );

          // 🔥 Appeler le callback parent si existant
          // widget.onGiftSuccess?.call();
        },
      ),
    );
  }

  // 🔥 MÉTHODE SHARE AVEC CALLBACK

  void _handleShare() async {
    // Activer le mode chargement
    setState(() { _isSharing = true; });

    try {
      // 1. GESTION DU THUMBNAIL POUR LES VIDÉOS
      if (widget.post.dataType == "VIDEO" &&
          (widget.post.thumbnail == null || widget.post.thumbnail!.isEmpty)) {

        // On attend la fin de la génération avant de continuer
        await checkAndGenerateThumbnail(
          postId: widget.post.id!,
          videoUrl: widget.post.url_media!,
          currentThumbnail: widget.post.thumbnail,
        );
      }

      // 2. PRÉPARATION DU PARTAGE
      String shareImageUrl = "";
      if (widget.post.dataType == "VIDEO") {
        shareImageUrl = widget.post.thumbnail ?? "";
      } else {
        shareImageUrl = (widget.post.images?.isNotEmpty ?? false) ? widget.post.images!.first : "";
      }

      final AppLinkService _appLinkService = AppLinkService();
      await _appLinkService.shareContent(
        type: AppLinkType.post,
        id: widget.post.id!,
        message: widget.post.description ?? "",
        mediaUrl: shareImageUrl,
      );

      // 3. MISE À JOUR FIREBASE & UI (Code existant)
      setState(() {
        widget.post.partage = (widget.post.partage ?? 0) + 1;
        widget.post.users_partage_id!.add(authProvider.loginUserData.id!);
      });

      await firestore.collection('Posts').doc(widget.post.id).update({
        'partage': FieldValue.increment(1),
        'users_partage_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
      });

      authProvider.checkAndRefreshPostDates(widget.post.id!);

      if (!isIn(widget.post.users_partage_id!, authProvider.loginUserData.id!)) {

        addPointsForAction(UserAction.partagePost);
        addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);
        // 🔥 APPEL DU CALLBACK LOVE
        widget.onShared?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+ de points ajoutés à votre compte',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.of(context).primary),
            ),
          ),
        );
      }

    } catch (e) {
      print("Erreur partage: $e");
    } finally {
      // Désactiver le chargement même en cas d'erreur
      if (mounted) {
        setState(() { _isSharing = false; });
      }
    }
  }
  // Méthode pour supprimer un post
  Future<void> _deletePost(Post post) async {
    final firestore = FirebaseFirestore.instance;
    final appDefaultRef = firestore.collection('AppData').doc(appId);

    try {
      // 🔹 Supprimer le post de Firestore
      await firestore.collection('Posts').doc(post.id).delete();
      print('✅ Post ${post.id} supprimé de Firestore');

      // 🔹 Retirer l'ID de allPostIds
      await appDefaultRef.update({
        'allPostIds': FieldValue.arrayRemove([post.id]),
      });
      print('✅ ID ${post.id} retiré de allPostIds');
    } catch (e) {
      print('❌ Erreur lors de la suppression du post ${post.id}: $e');
      throw e;
    }
  }

  int _selectedGiftIndex = 0;
  //Méthode pour afficher le dialogue de cadeau (simplifiée)
  List<double> giftPrices = [
    10, 25, 50, 100, 200, 300, 500, 700, 1500, 2000,
    2500, 5000, 7000, 10000, 15000, 20000, 30000,
    50000, 75000, 100000
  ];

  List<String> giftIcons = [
    '🌹','❤️','👑','💎','🏎️','⭐','🍫','🧰','🌵','🍕',
    '🍦','💻','🚗','🏠','🛩️','🛥️','🏰','💎','🏎️','🚗'
  ];
  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final dc = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: dc.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: dc.accent, width: 2),
          ),
          title: Text(
            'Solde Insuffisant',
            style: TextStyle(
              color: dc.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Votre solde est insuffisant pour effectuer cette action. Veuillez recharger votre compte.',
            style: TextStyle(color: dc.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: dc.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(builder: (context) => DepositScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: dc.primary,
              ),
              child: Text('Recharger', style: TextStyle(color: dc.onPrimary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendGiftFcfa(double amount) async {
    try {
      setState(() => _isLoading = true);

      final firestore = FirebaseFirestore.instance;
      await authProvider.getAppData();
      // Récupérer l'utilisateur expéditeur à jour
      final senderSnap = await firestore.collection('Users').doc(authProvider.loginUserData.id).get();
      if (!senderSnap.exists) {
        throw Exception("Utilisateur expéditeur introuvable");
      }
      final senderData = senderSnap.data() as Map<String, dynamic>;
      final double senderBalance = (senderData['votre_solde_principal'] ?? 0.0).toDouble();

      // Vérifier le solde
      if (senderBalance >= amount) {
        final double gainDestinataire = amount * 0.7;
        // final double gainApplication = amount * 0.3;

        // Débiter l'expéditeur
        await firestore.collection('Users').doc(authProvider.loginUserData.id).update({
          'votre_solde_principal': FieldValue.increment(-amount),
        });

        // Créditer le destinataire
        await firestore.collection('Users').doc(widget.post.user!.id).update({
          'votre_solde_principal': FieldValue.increment(gainDestinataire),
        });

        // Créditer l'application
        String appDataId = authProvider.appDefaultData.id!;


        if(widget.post.user!.codeParrain!=null){

          if(authProvider.loginUserData!.codeParrain!=null){
            final double gainApplication = amount * 0.25;

            await firestore.collection('AppData').doc(appDataId).update({
              'solde_gain': FieldValue.increment(gainApplication),
            });
            authProvider.ajouterCadeauCommissionParrain(codeParrainage: authProvider.loginUserData!.codeParrain!, montant: amount);
            authProvider.ajouterCadeauCommissionParrain(codeParrainage: widget.post.user!.codeParrain!, montant: amount);

          }
          else{
            final double gainApplication = amount * 0.25;

            await firestore.collection('AppData').doc(appDataId).update({
              'solde_gain': FieldValue.increment(gainApplication),
            });
            authProvider.ajouterCommissionParrain(codeParrainage: widget.post.user!.codeParrain!, montant: amount);

          }

        }else{
          if(authProvider.loginUserData!.codeParrain!=null){
            final double gainApplication = amount * 0.25;

            await firestore.collection('AppData').doc(appDataId).update({
              'solde_gain': FieldValue.increment(gainApplication),
            });
            authProvider.ajouterCommissionParrain(codeParrainage: authProvider.loginUserData!.codeParrain!, montant: amount);

          }
          else{
            final double gainApplication = amount * 0.3;

            await firestore.collection('AppData').doc(appDataId).update({
              'solde_gain': FieldValue.increment(gainApplication),
            });

          }
        }

        // Ajouter l'expéditeur à la liste des cadeaux du post
        await firestore.collection('Posts').doc(widget.post.id).update({
          'users_cadeau_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(5), // pondération pour un commentaire
        });

        // Créer les transactions
        await _createTransaction(TypeTransaction.DEPENSE.name, amount, "Cadeau envoyé à @${widget.post.user!.pseudo}",authProvider.loginUserData.id!);
        await _createTransaction(TypeTransaction.GAIN.name, gainDestinataire, "Cadeau reçu de @${authProvider.loginUserData.pseudo}",widget.post.user_id!);
        addPointsForAction(UserAction.cadeau);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.of(context).primary,
            content: Text(
              '🎁 Cadeau de ${amount.toInt()} FCFA envoyé avec succès!',
              style: TextStyle(color: AppColors.of(context).onPrimary),
            ),
          ),
        );
        await authProvider.sendNotification(
          userIds: [widget.post.user!.oneIgnalUserid!],
          smallImage: "", // pas besoin de montrer l'image de l'expéditeur
          send_user_id: "", // pas besoin de l'expéditeur
          recever_user_id: "${widget.post.user_id!}",
          message: "🎁 Vous avez reçu un cadeau de ${amount.toInt()} FCFA !",
          type_notif: NotificationType.POST.name,
          post_id: "${widget.post!.id!}",
          post_type: PostDataType.IMAGE.name,
          chat_id: '',
        );
      } else {
        _showInsufficientBalanceDialog();
      }
    } catch (e) {
      print("Erreur envoi cadeau: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.of(context).danger,
          content: Text(
              "Erreur lors de l'envoi du cadeau",
          style: TextStyle(color: AppColors.of(context).onPrimary),
        ),
      ),
    );
    } finally {
    setState(() => _isLoading = false);
    }
  }
  void _showGiftDialog(Post post) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final dc = AppColors.of(ctx);
        final height = MediaQuery.of(ctx).size.height * 0.6;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: dc.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: dc.accent, width: 2),
              ),
              child: Container(
                height: height,
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Envoyer un Cadeau',
                      style: TextStyle(
                        color: dc.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Choisissez le montant en FCFA',
                      style: TextStyle(color: dc.textSecondary),
                    ),
                    SizedBox(height: 12),
                    // -----------------------------
                    // Expanded pour GridView scrollable
                    Expanded(
                      child: GridView.builder(
                        physics: BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: giftPrices.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => setState(() => _selectedGiftIndex = index),
                            child: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _selectedGiftIndex == index
                                    ? dc.primary
                                    : dc.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedGiftIndex == index
                                      ? dc.accent
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    giftIcons[index],
                                    style: TextStyle(fontSize: 24),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    '${giftPrices[index].toInt()} FCFA',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: dc.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Votre solde: ${authProvider.loginUserData.votre_solde_principal?.toInt() ?? 0} FCFA',
                      style: TextStyle(
                        color: dc.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Annuler', style: TextStyle(color: dc.textSecondary)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _sendGiftFcfa(giftPrices[_selectedGiftIndex]);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dc.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Envoyer',
                            style: TextStyle(color: dc.onPrimary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  Future<void> _createTransaction(String type, double montant, String description,String userid) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      final transaction = TransactionSolde()
        ..id = firestore.collection('TransactionSoldes').doc().id
        ..user_id =userid
        ..type = type
        ..statut = StatutTransaction.VALIDER.name
        ..description = description
        ..montant = montant
        ..methode_paiement = "cadeau"
        ..createdAt = DateTime.now().millisecondsSinceEpoch
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;

      await firestore.collection('TransactionSoldes').doc(transaction.id).set(transaction.toJson());
    } catch (e) {
      print("Erreur création transaction: $e");
    }
  }

  // Méthodes existantes conservées (simplifiées pour l'exemple)
  void showRepublishDialog(Post post, UserData userSendCadeau, AppDefaultData appdata, BuildContext context) {
    // Implémentation existante conservée
    showDialog(
      context: context,
      builder: (context) {
        final dialogColors = AppColors.of(context);
        return AlertDialog(
          backgroundColor: dialogColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "✨ Republier",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dialogColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          content: Text(
            "🔝 Cette action mettra votre post en première position.\n\n💰 1 PC sera retiré de votre compte principal.",
            textAlign: TextAlign.center,
            style: TextStyle(color: dialogColors.textSecondary, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("❌ Fermer", style: TextStyle(color: dialogColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                // Logique existante
              },
              child: Text("🚀 Republier", style: TextStyle(color: dialogColors.info)),
            ),
          ],
        );
      },
    );
  }

// Méthodes utilitaires globales
  bool isIn(List<String> list, String value) {
    return list.contains(value);
  }

  bool isUserAbonne(List<String> abonnesIds, String userId) {
    return abonnesIds.contains(userId);
  }
}
void showInsufficientBalanceDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      final dialogColors = AppColors.of(context);
      return AlertDialog(
        backgroundColor: dialogColors.surface,
        title: Text("Solde insuffisant", style: TextStyle(color: dialogColors.textPrimary)),
        content: Text("Votre solde principal est insuffisant.", style: TextStyle(color: dialogColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Fermer", style: TextStyle(color: dialogColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => MonetisationPage()));
            },
            child: Text("Recharger", style: TextStyle(color: dialogColors.info)),
          ),
        ],
      );
    },
  );
}





