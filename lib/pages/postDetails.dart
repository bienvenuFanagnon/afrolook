import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:afrotok/services/ad_config_service.dart';
import 'package:afrotok/pages/user/userPubs/user_create_advertisement_page.dart';

import 'package:afrotok/pages/challenge/challengeDetails.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/home/homeWidget.dart';
import 'package:afrotok/pages/paiement/depotPaiment.dart';
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:afrotok/pages/postDetailsVideo.dart';
import 'package:afrotok/pages/post_video_format_tel_details.dart';
import 'package:afrotok/pages/pronostics/pronostic_detail_page.dart';
import 'package:afrotok/pages/pub/banner_ad_widget.dart';
import 'package:afrotok/pages/pub/native_ad_widget.dart';
import 'package:afrotok/pages/pub/rewarded_ad_widget.dart';

import 'package:afrotok/pages/userPosts/postWidgets/postMenu.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postUserWidget.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postWidgetPage.dart';
import 'package:afrotok/pages/widgetGlobal.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afrotok/models/model_data.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_linkify/flutter_linkify.dart';


import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import 'userPosts/postWidgets/translatable_description.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/authProvider.dart';
import '../providers/coin_gift_provider.dart';
import '../services/linkService.dart';
import '../services/postService/feed_interaction_service.dart';
import '../services/postService/post_view_service.dart';
import '../services/utils/abonnement_utils.dart';
import '../widgets/user_badge_widget.dart';
import 'UserServices/deviceService.dart';
import 'canaux/detailsCanal.dart';

import 'coins/coin_gift_dialog.dart';
import 'coins/coin_recharge_screen.dart';
import 'coins/post_gifts_list.dart';
import '../widgets/gifts/quick_gift_bar.dart';
import '../widgets/chat/post_share_sheet.dart';

// Couleurs migrées vers AppColors (_colors.*) dans _DetailsPostState

class DetailsPost extends StatefulWidget {
  final Post post;

  DetailsPost({Key? key, required this.post}) : super(key: key);

  @override
  _DetailsPostState createState() => _DetailsPostState();
}

class _DetailsPostState extends State<DetailsPost>
    with SingleTickerProviderStateMixin {
  late AppColors _colors;
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  // Variables pour les favoris
  bool _isFavorite = false;
  bool _isProcessingFavorite = false;
  bool _isLoading = false;
  int _selectedGiftIndex = 0;
  int _selectedRepostPrice = 25;
  bool _isExpanded = false;
  String? _translatedDescription;

  // Suggestions
  Timer? _suggestionModalTimer;
  bool _hasSeenSuggestionsModal = false;

  // Variables pour le vote
  bool _hasVoted = false;
  bool _isVoting = false;
  List<String> _votersList = [];

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Stream pour les mises à jour en temps réel
  late Stream<DocumentSnapshot> _postStream;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Challenge? _challenge;
  bool _loadingChallenge = false;

  // 🔥 NOUVELLE VARIABLE POUR LE CAROUSEL AUTO
  late PageController _carouselController;
  int _currentImageIndex = 0;
  Timer? _carouselTimer;
  // Méthode pour vérifier si le post est en favoris
  Future<void> _checkIfFavorite() async {
    try {
      final postDoc =
          await firestore.collection('Posts').doc(widget.post.id).get();
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        final favorites = List<String>.from(data['users_favorite_id'] ?? []);
        setState(() {
          _isFavorite = favorites.contains(authProvider.loginUserData.id);
        });
      }
    } catch (e) {
      printVm('Erreur lors de la vérification des favoris: $e');
    }
  }

  // Modifications à apporter à DetailsPost (ajouter ces méthodes et widgets)

// 1. Ajouter dans l'état de _DetailsPostState :

// Variables pour la publicité
  Advertisement? _advertisement;
  bool _isLoadingAd = false;
  bool _isAd = false;

  // Section "Booster ce post" — pour le propriétaire d'un post non-pub
  Advertisement? _ownerAdForPost;
  bool _isLoadingOwnerAd = false;
  bool _ownerAdLoaded = false;
  late SharedPreferences _prefs;
  final String _lastViewDatePrefix = 'last_view_date_';
  bool _isSharing = false;

  // Support par publicité
  final GlobalKey<RewardedAdWidgetState> _rewardedAdKey = GlobalKey();
  bool _showRewardedAd = false;
  bool _isSupporting = false;
  bool? _hasSeenSupportModal;

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


// Nouvelle méthode pour obtenir les suggestions filtrées (exclut le post courant)
  List<Post> getFilteredSuggestions() {
    final allSuggestions = postProvider.suggestedPosts;
    // Exclure le post actuel
    return allSuggestions.where((p) => p.id != widget.post.id).toList();
  }

  // Widget d'affichage des suggestions (modifié)
  Widget _buildSuggestedPosts() {
    final suggestions = getFilteredSuggestions();
    final isLoading = postProvider.isLoadingSuggestions;

    if (isLoading && suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: _colors.accent),
        ),
      );
    }

    if (suggestions.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Suggestions',
            style: TextStyle(
              color: _colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: suggestions.length + 1, // +1 pour la pub
          itemBuilder: (context, index) {
            final int postIndex = index > 3 ? index - 1 : index;
            if (postIndex >= suggestions.length) return SizedBox.shrink();

            final post = suggestions[postIndex];
            final bool isLastItem = index == suggestions.length;

            return Column(
              children: [
                InkWell(
                  onTap: () => _onSuggestedPostSelected(post),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: _colors.surfaceVariant,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Miniature (image ou vidéo)
                                (post.dataType == PostDataType.VIDEO.name && post.thumbnail != null && post.thumbnail!.isNotEmpty)
                                    ? CachedNetworkImage(
                                  imageUrl:_optimizeImageUrl( post.thumbnail!),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(color: _colors.accent),
                                  ),
                                  errorWidget: (context, url, error) => Icon(Icons.video_library, color: _colors.textSecondary, size: 40),
                                )
                                    : (post.images != null && post.images!.isNotEmpty)
                                    ? CachedNetworkImage(
                                  imageUrl: _optimizeImageUrl( post.images!.first),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(color: _colors.accent),
                                  ),
                                  errorWidget: (context, url, error) => Icon(Icons.image, color: _colors.textSecondary, size: 40),
                                )
                                    : Icon(Icons.image, color: _colors.textSecondary, size: 40),

                                // Badge vidéo (seulement si c'est une vidéo)
                                if (post.dataType == PostDataType.VIDEO.name)
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.play_arrow, color: Colors.white, size: 14),
                                          SizedBox(width: 2),
                                          Text(
                                            'VIDEO',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.description ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: _colors.textPrimary, fontSize: 14),
                              ),

                              SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.bar_chart, size: 12, color: _colors.info),
                                  SizedBox(width: 4),
                                  Text(
                                    '${post.totalInteractions ?? 0}',
                                    style: TextStyle(color: _colors.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLastItem) Divider(color: _colors.divider),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: (50 * index).ms).slideX(begin: 0.05, end: 0);
          },
        ),
      ],
    );
  }

// Navigation vers un post suggéré
  void _onSuggestedPostSelected(Post newPost) {
    if(newPost.dataType==PostDataType.VIDEO.name){
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoYoutubePageDetails(initialPost: newPost,isIn: true,),
        ),
      );
    }else{
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DetailsPost(post: newPost),
        ),
      );
    }

  }

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

  Future<void> _recordSupport(String postId, String userId) async {
    final support = PostSupport(
      id: firestore.collection('post_supports').doc().id,
      postId: postId,
      userId: userId,
      supportedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await firestore.collection('post_supports').doc(support.id).set(support.toJson());
  }


  Future<void> _handleSupportAd() async {
    // if (_isSupporting) return;
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == widget.post.user_id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vous ne pouvez pas soutenir votre propre post'), backgroundColor: _colors.warning),
      );
      return;
    }

    // Vérifier la limite quotidienne
    final hasSupported = await _hasSupportedToday(widget.post.id!, currentUserId!);
    if (hasSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vous avez déjà soutenu ce post aujourd\'hui. Revenez demain !'),
          backgroundColor: _colors.warning,
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
    // Attendre que le widget soit monté
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_rewardedAdKey.currentState != null) {
        _rewardedAdKey.currentState!.showAd();

        // bool ready = await _rewardedAdKey.currentState!.waitForAdReady();
        // if (ready) {
        //   _rewardedAdKey.currentState!.showAd();
        // } else {
        //   setState(() {
        //     _isSupporting = false;
        //     _showRewardedAd = false;
        //   });
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     const SnackBar(content: Text('Publicité non disponible'), backgroundColor: Colors.red),
        //   );
        // }
      } else {
        setState(() {
          _isSupporting = false;
          _showRewardedAd = false;
        });
      }
    });
  }

  void _showSupportModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _colors.surfaceVariant,
        title: Row(
          children: [
            Icon(Icons.volunteer_activism, color: _colors.accent),
            SizedBox(width: 8),
            Text('Soutenir le créateur', style: TextStyle(color: _colors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'En regardant cette publicité, vous offrez pièces au créateur de ce post.',
              style: TextStyle(color: _colors.textSecondary),
            ),
            SizedBox(height: 12),
            Text(
              'Cela l’encourage à produire plus de contenu et peut lui rapporter jusqu’à 100€ (environ 65 000 FCFA) par mois !',
              style: TextStyle(color: _colors.textPrimary),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _colors.success.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.monetization_on, color: _colors.accent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '💰 Les pièces récoltées peuvent être converties en argent réel.',
                      style: TextStyle(color: _colors.textPrimary, fontSize: 12),
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
            child: Text('Plus tard', style: TextStyle(color: _colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _markSupportModalSeen();
              _startSupportAd();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _colors.accent),
            child: Text('Regarder la pub', style: TextStyle(color: _colors.onAccent)),
          ),
        ],
      ),
    );
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

    // Créditer le créateur (pièces)
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

    // Envoyer une notification au créateur
    await _sendSupportNotification(creatorId, currentUserId, postId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 Merci ! Le créateur a reçu des pièces.'),
        backgroundColor: _colors.success,
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
  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> _loadSuggestionsModalPreference() async {
    _prefs = await SharedPreferences.getInstance();

    final userId = authProvider.loginUserData?.id;
    printVm('🔍 _loadSuggestionsModalPreference - userId: $userId');
    if (userId == null) {
      printVm('⚠️ userId est null, impossible de charger la préférence');
      return;
    }
    final key = 'has_seen_suggestions_modal_video_$userId';
    _hasSeenSuggestionsModal = _prefs.getBool(key) ?? false;
    printVm('📖 Clé lue: $key, valeur: $_hasSeenSuggestionsModal');
    setState(() {});
  }

  Future<void> _markSuggestionsModalSeen() async {
    final userId = authProvider.loginUserData?.id;
    printVm('🔍 _markSuggestionsModalSeen - userId: $userId');
    if (userId == null) {
      printVm('⚠️ userId est null, impossible de sauvegarder');
      return;
    }
    final key = 'has_seen_suggestions_modal_video_$userId';
    await _prefs.setBool(key, true);
    printVm('💾 Clé sauvegardée: $key = true');
    setState(() {
      _hasSeenSuggestionsModal = true;
    });
  }

  // ==================== SUGGESTIONS MODAL ====================

  void _startSuggestionModalTimer() {
    _suggestionModalTimer?.cancel();
    if (_hasSeenSuggestionsModal) return;
    _suggestionModalTimer = Timer(Duration(seconds: 5), () {
      if (mounted && !_hasSeenSuggestionsModal) {
        _showSuggestionsModal();
      }
    });
  }

  void _showSuggestionsModal() {
    final suggestions = postProvider.suggestedPosts
        .where((p) => p.id != widget.post.id)
        .take(10) // 10 suggestions
        .toList();

    if (suggestions.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _colors.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lightbulb, color: _colors.accent),
            SizedBox(width: 8),
            Text(
              'Découvrez d’autres posts',
              style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold,fontSize: 13),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vous pouvez faire défiler vers le bas pour voir d’autres vidéos tendance du moment !',
                style: TextStyle(color: _colors.textSecondary),
              ),
              SizedBox(height: 16),
              Text(
                'Suggestions pour vous :',
                style: TextStyle(color: _colors.accent, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (int i = 0; i < suggestions.length; i++)
                        Column(
                          children: [
                            // if (i == 3) // 4ème élément (index 3)
                              // _buildAdMrec(key: 'ad_suggestion_modal'),
                            _buildSuggestionItem(suggestions[i]),
                            if (i != suggestions.length - 1) SizedBox(height: 12),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: _colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markSuggestionsModalSeen();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _colors.primary),
            child: Text('J’ai compris', style: TextStyle(color: _colors.onPrimary)),
          ),
        ],
      ),
    );
  }
  Widget _buildSuggestionItem(Post post) {
    return GestureDetector(
      onTap: () {
        _onSuggestedPostSelected(post);
      },
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  color: _colors.surfaceVariant,
                  child: post.dataType == PostDataType.VIDEO.name && post.thumbnail != null
                      ? CachedNetworkImage(imageUrl:_optimizeImageUrl( post.thumbnail!), fit: BoxFit.cover)
                      : (post.images != null && post.images!.isNotEmpty
                      ? CachedNetworkImage(imageUrl:_optimizeImageUrl( post.images!.first), fit: BoxFit.cover)
                      : Icon(Icons.videocam, color: _colors.textSecondary)),
                ),
                if (post.dataType == PostDataType.VIDEO.name)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(Icons.play_arrow, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.description ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _colors.textPrimary),
                ),
                Row(
                  children: [
                    Icon(Icons.bar_chart, size: 12, color: _colors.textSecondary),
                    SizedBox(width: 2),
                    Text(
                      _formatCount(post.totalInteractions ?? 0),
                      style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.favorite, size: 12, color: _colors.danger),
                    SizedBox(width: 2),
                    Text(
                      _formatCount(post.loves ?? 0),
                      style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
  Widget _buildAdMrec({required String key}) {
    // return SizedBox.shrink();

    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: MrecAdWidget(
        key: ValueKey(key),
        // templateType: TemplateType.medium, // ou TemplateType.small

        onAdLoaded: () {
          authProvider.incrementCreatorCoins(postId: widget.post.id!, creatorId: widget.post.user_id!, currentUserId:authProvider.loginUserData.id!);
          printVm('✅ Native Ad Afrolook chargée: $key');
        },
      ),
      // child: BannerAdWidget(
      //   onAdLoaded: () {
      //
      //     printVm('✅ Bannière Afrolook chargée: $key');


    //   },
      // ),
    );
  }

  Future<void> _sendSupportNotification(String creatorId, String supporterId, String postId) async {
    final now = DateTime.now().microsecondsSinceEpoch;
    final supporter = authProvider.loginUserData;
    final supporterName = supporter.pseudo ?? 'Un utilisateur';

    final description = "@$supporterName a soutenu votre post en regardant une publicité ! (+ pièces) 💰 Chaque soutien vous rapproche des 100€ (≈65 000 FCFA) par mois. Continuez à créer, on vous soutient !";

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
    printVm("💪 @$supporterName a soutenu votre post ! + pièces. Gagnez jusqu'à 100€/mois !");
  }
// 3. Ajouter la méthode de chargement :
  Future<void> _loadAdvertisement() async {
    if (widget.post.advertisementId == null) return;

    setState(() => _isLoadingAd = true);

    try {
      final adDoc = await firestore
          .collection('Advertisements')
          .doc(widget.post.advertisementId)
          .get();

      if (adDoc.exists) {
        setState(() {
          _advertisement =
              Advertisement.fromJson(adDoc.data() as Map<String, dynamic>);
        });
      }
    } catch (e) {
      printVm('Erreur chargement publicité: $e');
    } finally {
      setState(() => _isLoadingAd = false);
    }
  }

  // Charge la pub liée à ce post (pour le propriétaire d'un post non-pub)
  Future<void> _loadOwnerAd() async {
    if (_ownerAdLoaded) return;
    setState(() => _isLoadingOwnerAd = true);
    try {
      final snap = await firestore
          .collection('Advertisements')
          .where('postId', isEqualTo: widget.post.id)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        setState(() => _ownerAdForPost = Advertisement.fromJson(snap.docs.first.data()));
      }
    } catch (_) {}
    setState(() {
      _isLoadingOwnerAd = false;
      _ownerAdLoaded = true;
    });
  }

// 4. Ajouter ce widget dans la partie supérieure de la page (après l'en-tête) :

  Widget _buildAdvertisementHeader() {
    if (!_isAd || _advertisement == null) return const SizedBox.shrink();

    final ad = _advertisement!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _colors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.accent, width: 1),
      ),
      child: Row(
        // mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Badge SPONSORISÉ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _colors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                Icon(Icons.verified, color: _colors.onAccent, size: 14),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context).postDetailSponsored,
                  style: TextStyle(
                    color: _colors.onAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Bouton d'action (compact)
          InkWell(
            onTap: () async {
              if (ad.actionUrl != null && ad.actionUrl!.isNotEmpty) {
                final url = Uri.parse(ad.actionUrl!);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }
              _recordAdClick(ad, widget.post);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE21221), Color(0xFFFF5252)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ad.actionType == 'download'
                        ? Icons.download
                        : ad.actionType == 'visit'
                        ? Icons.language
                        : Icons.info,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ad.getActionButtonText().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SECTION BOOSTER CE POST (propriétaire uniquement) ───────────────────────

  Widget _buildBoostSection() {
    final isOwner = authProvider.loginUserData.id == widget.post.user_id;
    if (!isOwner) return const SizedBox.shrink();

    if (_isLoadingOwnerAd) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _colors.primary))),
      );
    }

    final ad = _ownerAdForPost;

    // Annulée ou rejetée : message admin
    if (ad != null && (ad.status == 'cancelled' || ad.status == 'rejected')) {
      return _buildBoostCard(
        icon: Icons.block,
        iconColor: _colors.danger,
        title: ad.status == 'rejected' ? 'Publicité rejetée' : 'Publicité annulée',
        subtitle: ad.rejectionReason != null && ad.rejectionReason!.isNotEmpty
            ? 'Motif : ${ad.rejectionReason}'
            : 'Contactez l\'administrateur pour renouveler cette publicité.',
        child: null,
      );
    }

    // En attente
    if (ad != null && ad.status == 'pending') {
      return _buildBoostCard(
        icon: Icons.hourglass_empty,
        iconColor: _colors.warning,
        title: 'Publicité en attente',
        subtitle: 'Votre publicité est en cours de validation par l\'administration.',
        child: null,
      );
    }

    // Active ou expirée : stats + renouveler
    if (ad != null && (ad.status == 'active' || ad.status == 'expired')) {
      final isExpired = ad.status == 'expired' ||
          (ad.endDate != null && ad.endDate! <= DateTime.now().microsecondsSinceEpoch);
      return _buildBoostCard(
        icon: isExpired ? Icons.timer_off : Icons.campaign,
        iconColor: isExpired ? _colors.textSecondary : _colors.primary,
        title: isExpired ? 'Publicité expirée' : 'Publicité active',
        subtitle: null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Stats
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _colors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _colors.border),
            ),
            child: Row(children: [
              _boostStat(Icons.remove_red_eye, '${ad.views ?? 0}', 'Vues', _colors.info),
              Container(width: 0.5, height: 36, color: _colors.border),
              _boostStat(Icons.ads_click, '${ad.clicks ?? 0}', 'Clics', _colors.warning),
              Container(width: 0.5, height: 36, color: _colors.border),
              _boostStat(Icons.trending_up, '${ad.ctr.toStringAsFixed(1)}%', 'CTR', _colors.primary),
            ]),
          ),
          if (ad.endDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                isExpired
                    ? 'Expirée le ${_formatBoostDate(ad.endDate!)}'
                    : 'Fin le ${_formatBoostDate(ad.endDate!)}',
                style: TextStyle(
                    color: isExpired ? _colors.danger : _colors.textSecondary, fontSize: 12),
              ),
            ),
          // Bouton renouveler
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showBoostRenewalDialog(ad),
              icon: const Icon(Icons.update, size: 16),
              label: const Text('Renouveler la publicité'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _colors.primary,
                foregroundColor: _colors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ]),
      );
    }

    // Aucune pub : bouton booster
    return _buildBoostCard(
      icon: Icons.rocket_launch,
      iconColor: _colors.accent,
      title: 'Booster ce post',
      subtitle: 'Transformez ce post en publicité et touchez plus d\'utilisateurs en Afrique.',
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _navigateToCreateAd(),
          icon: const Icon(Icons.add_box_outlined, size: 16),
          label: const Text('Créer une publicité'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _colors.accent,
            foregroundColor: _colors.onAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildBoostCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String? subtitle,
    required Widget? child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _colors.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: _colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ]),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
        ],
        if (child != null) ...[const SizedBox(height: 12), child],
      ]),
    );
  }

  Widget _boostStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(label, style: TextStyle(color: _colors.textSecondary, fontSize: 9)),
        ]),
      ),
    );
  }

  String _formatBoostDate(int microseconds) {
    return DateFormat('dd/MM/yyyy')
        .format(DateTime.fromMicrosecondsSinceEpoch(microseconds));
  }

  void _navigateToCreateAd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserCreateAdvertisementPage(existingPost: widget.post),
      ),
    ).then((_) {
      // Recharger après retour
      _ownerAdLoaded = false;
      _loadOwnerAd();
    });
  }

  void _showBoostRenewalDialog(Advertisement ad) {
    const extensionOptions = [2, 4, 12, 24, 52];
    int? selectedWeeks;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: _colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.update, color: _colors.primary, size: 22),
            const SizedBox(width: 10),
            Text('Renouveler la publicité',
                style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold)),
          ]),
          content: FutureBuilder<List<AdDuration>>(
            future: AdConfigService.getDurations(),
            builder: (_, snap) {
              final durations = snap.data ?? AdConfigService.defaults;
              final priceMap = AdConfigService.toMap(durations);
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Choisissez la durée', style: TextStyle(color: _colors.textSecondary, fontSize: 13)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: durations.map((d) {
                    final sel = selectedWeeks == d.weeks;
                    return GestureDetector(
                      onTap: () => setD(() => selectedWeeks = d.weeks),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? _colors.primary.withOpacity(0.12) : _colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? _colors.primary : _colors.border, width: sel ? 1.5 : 0.5),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(d.label,
                              style: TextStyle(
                                  color: sel ? _colors.primary : _colors.textPrimary,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13)),
                          Text('${priceMap[d.weeks] ?? d.price} FCFA',
                              style: TextStyle(color: _colors.textSecondary, fontSize: 11)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                if (selectedWeeks != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Solde actuel : ${authProvider.loginUserData.votre_solde_principal?.toStringAsFixed(0) ?? 0} FCFA',
                      style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ]);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: _colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: selectedWeeks != null
                  ? () {
                      Navigator.pop(ctx);
                      _renewBoostAd(ad, selectedWeeks!);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _colors.primary, foregroundColor: _colors.onPrimary),
              child: const Text('Renouveler'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renewBoostAd(Advertisement ad, int weeks) async {
    final durations = await AdConfigService.getDurations();
    final priceMap = AdConfigService.toMap(durations);
    final price = priceMap[weeks] ?? 0;
    final balance = authProvider.loginUserData.votre_solde_principal ?? 0;
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    if (!isAdmin && balance < price) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Solde insuffisant ($balance FCFA). Vous avez besoin de $price FCFA.'),
        backgroundColor: _colors.danger,
      ));
      return;
    }

    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      final newEndDate = (ad.isExpired || ad.endDate == null || ad.endDate! <= now)
          ? now + weeks * 7 * 24 * 60 * 60 * 1000000
          : ad.endDate! + weeks * 7 * 24 * 60 * 60 * 1000000;

      if (!isAdmin) {
        await firestore.collection('Users').doc(authProvider.loginUserData.id).update({
          'votre_solde_principal': FieldValue.increment(-price.toDouble()),
        });
        authProvider.loginUserData.votre_solde_principal = balance - price;
        // Log transaction
        final tx = TransactionSolde()
          ..id = firestore.collection('TransactionSoldes').doc().id
          ..user_id = authProvider.loginUserData.id
          ..type = TypeTransaction.DEPENSE.name
          ..statut = StatutTransaction.VALIDER.name
          ..description = 'Renouvellement publicité ${AdConfigService.labelFor(weeks, durations)}'
          ..montant = price.toDouble()
          ..methode_paiement = 'solde'
          ..createdAt = DateTime.now().millisecondsSinceEpoch
          ..updatedAt = DateTime.now().millisecondsSinceEpoch;
        await firestore.collection('TransactionSoldes').doc(tx.id).set(tx.toJson());
      }

      await firestore.collection('Advertisements').doc(ad.id).update({
        'endDate': newEndDate,
        'status': 'pending',
        'renewalCount': FieldValue.increment(1),
        'updatedAt': now,
        'pricePaid': FieldValue.increment(price),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Demande de renouvellement envoyée — en attente de validation'),
          backgroundColor: _colors.primary,
        ));
        _ownerAdLoaded = false;
        _loadOwnerAd();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: _colors.danger,
        ));
      }
    }
  }

  // Méthode utilitaire pour optimiser les URLs
  String _optimizeImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final appDefaultData = authProvider.appDefaultData;

    return authProvider.convertToCdnUrl(url, appDefaultData);
  }

// 6. Modifier la méthode build pour inclure ces nouveaux widgets
// Dans le build de DetailsPost, après _buildUserHeader et avant _buildPostContent :

// Ajouter :
//   if (_isLoadingAd) {
//   return Center(
//   child: Padding(
//   padding: EdgeInsets.all(20),
//   child: CircularProgressIndicator(color: Color(0xFFFFD600)),
//   ),
//   );
//   }

// // Ajouter dans le Column :
//   _buildAdvertisementHeader(),
//   _buildAdvertisementActionButton(),
  // Vérifier si l'utilisateur a accès au contenu
  bool _hasAccessToContent() {
    // Si c'est un post de canal privé
    if (widget.post.canal != null) {
      final isPrivate = widget.post.canal!.isPrivate == true;
      final isSubscribed = widget.post.canal!.usersSuiviId
              ?.contains(authProvider.loginUserData.id) ??
          false;
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
      final isCurrentUser =
          authProvider.loginUserData.id == widget.post.user_id;

      // Accès autorisé si :
      // - Le canal n’est pas privé
      // - OU l’utilisateur est abonné
      // - OU c’est un admin
      if (!isPrivate || isSubscribed || isAdmin || isCurrentUser) {
        return true;
      }

      // Sinon, accès refusé
      return false;
    }

    // Si ce n’est pas un post de canal → accès libre
    return true;
  }

  // Vérifier si c'est un post de canal privé non accessible
  bool _isLockedContent() {
    if (widget.post.canal != null) {
      final isPrivate = widget.post.canal!.isPrivate == true;
      final isSubscribed = widget.post.canal!.usersSuiviId
              ?.contains(authProvider.loginUserData.id) ??
          false;
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
      final isCurrentUser =
          authProvider.loginUserData.id == widget.post.user_id;

      // Le contenu est verrouillé uniquement si :
      // - Le canal est privé
      // - L'utilisateur n'est pas abonné
      // - Et ce n'est pas un administrateur
      return isPrivate && !isSubscribed && !isAdmin && !isCurrentUser;
    }
    return false;
  }

// ========== GESTION AUDIO ==========
  final Map<String, File> _cachedAudioFiles = {};
  final Map<String, AudioPlayer> _activePlayers = {};
  String? _currentlyPlayingAudioId;
  bool _isAudioPlaying = false;
  Duration _currentAudioPosition = Duration.zero;
  Duration _currentAudioDuration = Duration.zero;
  bool _isAudioLoading = false;

// Initialiser le lecteur audio
  void _initAudioPlayer(String postId) {
    if (!_activePlayers.containsKey(postId)) {
      final player = AudioPlayer();

      player.onDurationChanged.listen((duration) {
        if (mounted && _currentlyPlayingAudioId == postId) {
          setState(() {
            _currentAudioDuration = duration;
          });
        }
      });

      player.onPositionChanged.listen((position) {
        if (mounted && _currentlyPlayingAudioId == postId) {
          setState(() {
            _currentAudioPosition = position;
          });
        }
      });

      player.onPlayerComplete.listen((event) {
        if (mounted && _currentlyPlayingAudioId == postId) {
          setState(() {
            _isAudioPlaying = false;
            _currentlyPlayingAudioId = null;
            _currentAudioPosition = Duration.zero;
          });
        }
      });

      _activePlayers[postId] = player;
    }
  }

// Précharger l'audio en cache
  Future<File?> _precacheAudio(String audioUrl, String postId) async {
    if (_cachedAudioFiles.containsKey(postId)) {
      return _cachedAudioFiles[postId];
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'audio_$postId.${_getAudioExtension(audioUrl)}';
      final file = File('${tempDir.path}/$fileName');

      if (await file.exists()) {
        _cachedAudioFiles[postId] = file;
        return file;
      }

      final storageRef = FirebaseStorage.instance.refFromURL(audioUrl);
      final maxSize = 10 * 1024 * 1024; // 10 MB
      final data = await storageRef.getData(maxSize);

      if (data != null) {
        await file.writeAsBytes(data);
        _cachedAudioFiles[postId] = file;
        return file;
      }
    } catch (e) {
      printVm('Erreur préchargement audio $postId: $e');
    }

    return null;
  }

  String _getAudioExtension(String url) {
    if (url.contains('.mp3')) return 'mp3';
    if (url.contains('.m4a')) return 'm4a';
    if (url.contains('.aac')) return 'aac';
    if (url.contains('.opus')) return 'opus';
    if (url.contains('.webm')) return 'webm';
    return 'm4a';
  }

// Lire l'audio
  Future<void> _playAudio(String postId, String audioUrl) async {
    try {
      _initAudioPlayer(postId);
      final player = _activePlayers[postId]!;

      if (_currentlyPlayingAudioId == postId && _isAudioPlaying) {
        await player.pause();
        setState(() {
          _isAudioPlaying = false;
        });
      } else if (_currentlyPlayingAudioId == postId && !_isAudioPlaying) {
        await player.resume();
        setState(() {
          _isAudioPlaying = true;
        });
      } else {
        if (_currentlyPlayingAudioId != null &&
            _activePlayers.containsKey(_currentlyPlayingAudioId)) {
          await _activePlayers[_currentlyPlayingAudioId]!.stop();
        }

        setState(() {
          _currentlyPlayingAudioId = postId;
          _currentAudioPosition = Duration.zero;
          _currentAudioDuration = Duration.zero;
          _isAudioLoading = true;
        });

        if (_cachedAudioFiles.containsKey(postId)) {
          await player.play(DeviceFileSource(_cachedAudioFiles[postId]!.path));
        } else {
          await player.play(UrlSource(audioUrl));
        }

        setState(() {
          _isAudioPlaying = true;
          _isAudioLoading = false;
        });
      }
    } catch (e) {
      printVm('Erreur lecture audio: $e');
      _showAudioError();
      setState(() {
        _isAudioLoading = false;
      });
    }
  }

  void _seekAudio(double value, String postId) {
    if (_activePlayers.containsKey(postId)) {
      _activePlayers[postId]!.seek(Duration(seconds: value.toInt()));
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Set<String> _clickedInSession = {};
  Future<void> _recordAdClick(Advertisement ad, Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || ad.id == null) return;

    // Éviter les doubles comptages dans la même session
    final clickKey = '${ad.id}_$currentUserId';
    if (_clickedInSession.contains(clickKey)) return;

    _clickedInSession.add(clickKey);

    try {
      final adRef = _firestore.collection('Advertisements').doc(ad.id);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await _firestore.runTransaction((transaction) async {
        final adDoc = await transaction.get(adRef);
        if (!adDoc.exists) return;

        final currentAd = Advertisement.fromJson(adDoc.data()!);

        final clickIncr = Random().nextInt(3) + 1;
        Map<String, dynamic> updates = {
          'clicks': FieldValue.increment(clickIncr),
          'updatedAt': DateTime.now().microsecondsSinceEpoch,
        };

        if (currentAd.dailyStats != null) {
          updates['dailyStats.$today.clicks'] = FieldValue.increment(clickIncr);
        }

        final hasClicked =
            currentAd.clickersIds?.contains(currentUserId) ?? false;
        if (!hasClicked) {
          updates['uniqueClicks'] = FieldValue.increment(1);
          updates['clickersIds'] = FieldValue.arrayUnion([currentUserId]);
        }

        transaction.update(adRef, updates);
      });

      // Mettre à jour l'objet local
      // ad.clicks = (ad.clicks ?? 0) + 1;

      // Notifier le parent
      // widget.onAdClicked?.call(post, ad);

      printVm('✅ Clic enregistré pour la pub: ${ad.id}');
    } catch (e) {
      printVm('❌ Erreur lors de l\'enregistrement du clic: $e');
      _clickedInSession.remove(clickKey);
    }
  }

  Widget _buildAudioContent(Post post, bool isLocked) {
    final audioUrl = post.url_media ?? '';
    final postId = post.id!;
    final isCurrentlyPlaying =
        _currentlyPlayingAudioId == postId && _isAudioPlaying;
    final duration = _currentlyPlayingAudioId == postId
        ? _currentAudioDuration
        : Duration.zero;
    final position = _currentlyPlayingAudioId == postId
        ? _currentAudioPosition
        : Duration.zero;

    // Image de couverture (si disponible)
    final coverImage = post.images != null && post.images!.isNotEmpty
        ? post.images!.first
        : null;

    // Précharger l'audio
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheAudio(audioUrl, postId);
    });

    return GestureDetector(
      onTap: coverImage != null
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImage(singleImageUrl: coverImage),
                ),
              );
            }
          : null,
      child: Container(
        width: double.infinity,
        height: 380, // Hauteur fixe pour un meilleur rendu
        margin: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 3,
              offset: Offset(0, 5),
            ),
          ],
          border: _isLookChallenge
              ? Border.all(color: _colors.primary.withOpacity(0.5), width: 2)
              : null,
        ),
        child: Stack(
          children: [
            // Image de fond (si disponible)
            if (coverImage != null)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image(
                    image: CachedNetworkImageProvider(_optimizeImageUrl(coverImage) ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Overlay dégradé pour meilleure lisibilité
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.8),
                      Colors.black,
                    ],
                    stops: [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Overlay verrouillage
            if (isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, color: _colors.accent, size: 60),
                        SizedBox(height: 20),
                        Text(
                          AppLocalizations.of(context).postDetailAudioLocked,
                          style: TextStyle(
                            color: _colors.accent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            AppLocalizations.of(context).postDetailSubscribeToListen,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (!isLocked)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                        Colors.black,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête avec badge audio
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _colors.accent.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _colors.accent.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.audiotrack,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'AUDIO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      // Titre ou description
                      if (post.description != null)
                        Text(
                          post.description!,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      SizedBox(height: 20),

                      // Contrôles de lecture
                      Row(
                        children: [
                          // Bouton Play/Pause avec effet de glow
                          GestureDetector(
                            onTap: () => _playAudio(postId, audioUrl),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: _colors.accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _colors.accent.withOpacity(0.4),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: _isAudioLoading &&
                                      _currentlyPlayingAudioId == postId
                                  ? Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      isCurrentlyPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                            ),
                          ),

                          SizedBox(width: 20),

                          // Barre de progression
                          Expanded(
                            child: Column(
                              children: [
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 4,
                                    thumbShape: RoundSliderThumbShape(
                                        enabledThumbRadius: 8),
                                    overlayShape: RoundSliderOverlayShape(
                                        overlayRadius: 16),
                                  ),
                                  child: Slider(
                                    value: position.inSeconds.toDouble(),
                                    min: 0,
                                    max: duration.inSeconds > 0
                                        ? duration.inSeconds.toDouble()
                                        : 1.0,
                                    onChanged: (value) =>
                                        _seekAudio(value, postId),
                                    activeColor: _colors.accent,
                                    inactiveColor:
                                        Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(position),
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(duration),
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      // Vagues audio animées
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(40, (index) {
                          final height = 4.0 + (index % 8) * 3.0;
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            width: 3,
                            height: isCurrentlyPlaying && index % 3 == 0
                                ? height * 1.5
                                : height,
                            margin: EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: isCurrentlyPlaying && index % 3 == 0
                                  ? _colors.accent
                                  : Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),

                      // Indication de clic sur l'image
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          AppLocalizations.of(context).postDetailClickImageToEnlarge,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAudioError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur lors de la lecture audio'),
        backgroundColor: _colors.danger,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }


  @override
  void initState() {
    super.initState();
    _initSharedPreferences();

    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    // 🔥 INITIALISATION DU CAROUSEL
    _carouselController = PageController();

    // Démarrer le carousel auto si plusieurs images
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCarouselAutoPlay();
    });
    _startSuggestionModalTimer();
    if (widget.post!=null&&widget.post.type == PostType.PRONOSTIC.name) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PronosticDetailPage(postId: widget.post.id!),));
    } else if(widget.post!=null&&widget.post.type == PostDataType.VIDEO .name){
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.post.isPortrait == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailsVideoFormatTel(
                initialPost: widget.post,
                isIn: true, // important pour éviter une nouvelle redirection
              ),
            ),
          );

        }else{
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VideoYoutubePageDetails(
                initialPost: widget.post,
                isIn: true, // important pour éviter une nouvelle redirection
              ),
            ),
          );

        }
      });

    }
    _loadSupportModalSeen();
    _isAd = widget.post.isAdvertisement == true;
    if (_isAd && widget.post.advertisementId != null) {
      _loadAdvertisement();
    }
    // Section boost : si le post appartient à l'utilisateur connecté
    if (authProvider.loginUserData.id == widget.post.user_id) {
      _loadOwnerAd();
    }
    _checkIfFavorite();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuggestionsModalPreference();
    });

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadPostRelations();

    // Initialiser le stream pour les mises à jour en temps réel
    _postStream = firestore.collection('Posts').doc(widget.post.id).snapshots();

    // Charger le challenge si c'est un look challenge
    if (_isLookChallenge && widget.post.challenge_id != null) {
      _loadChallengeData();
    }
    // Vérifier si l'utilisateur a déjà voté
    _checkIfUserHasVoted();

    // Incrémenter les vues
    _incrementViews();

  }

  // 🔥 DÉMARRER LE CAROUSEL AUTO
  void _startCarouselAutoPlay() {
    _stopCarouselAutoPlay(); // Arrêter l'existant

    final images = widget.post.images ?? [];
    if (images.length > 1) {
      _carouselTimer = Timer.periodic(Duration(seconds: 2), (timer) {
        if (mounted && _carouselController.hasClients) {
          final nextPage = (_currentImageIndex + 1) % images.length;
          _carouselController.animateToPage(
            nextPage,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

// 🔥 ARRÊTER LE CAROUSEL AUTO
  void _stopCarouselAutoPlay() {
    _carouselTimer?.cancel();
    _carouselTimer = null;
  }

  Widget _buildSupportButton() {
    final hasAccess = _hasAccessToContent();
    final isOwner = authProvider.loginUserData.id == widget.post.user_id;
    if (isOwner || !hasAccess) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: QuickGiftBar(
        receiverId: widget.post.user_id!,
        receiverName: widget.post.user?.pseudo ?? 'Créateur',
        receiverAvatar: widget.post.user?.imageUrl ?? '',
        post: widget.post,
        giftCount: widget.post.totalGiftCoinsSentOnThisPost ?? 0,
      ),
    );
  }
  @override
  void dispose() {
    _suggestionModalTimer?.cancel();

    _animationController.dispose();
    for (var player in _activePlayers.values) {
      player.dispose();
    }
    _activePlayers.clear();

    // 🔥 NETTOYER LE CAROUSEL
    _stopCarouselAutoPlay();
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    if (_isProcessingFavorite || !_hasAccessToContent()) return;

    final userId = authProvider.loginUserData.id!;
    final postId = widget.post.id!;

    setState(() {
      _isProcessingFavorite = true;
    });

    try {
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
      await authProvider. incrementPostTotalInteractions(postId: widget.post.id!);

      authProvider. notifySubscribersOfInteraction(
        actionUserId: authProvider.loginUserData.id!,
        postOwnerId: widget.post.user_id!,
        postId: widget.post.id!,
        actionType: 'favorite',
        postDescription: widget.post.description,
        postImageUrl: widget.post.images?.first,
        postDataType: widget.post.dataType,
      );
      // Afficher un feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite
                ? '✅ Post ajouté aux favoris'
                : '🗑️ Post retiré des favoris',
            style: TextStyle(color: _colors.onPrimary),
          ),
          backgroundColor: _isFavorite ? _colors.primary : _colors.textSecondary,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      printVm('Erreur toggle favori: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Erreur lors de la modification',
            style: TextStyle(color: _colors.onPrimary),
          ),
          backgroundColor: _colors.danger,
        ),
      );
    } finally {
      setState(() {
        _isProcessingFavorite = false;
      });
    }
  }

  Future<void> _addToFavorites(
      String userId, String postId, FirebaseFirestore firestore) async {
    // Mettre à jour le post
    await firestore.collection('Posts').doc(postId).update({
      'users_favorite_id': FieldValue.arrayUnion([userId]),
      'favorites_count': FieldValue.increment(1),
      'popularity': FieldValue.increment(2),
      'updatedAt': DateTime.now().microsecondsSinceEpoch,
    });

    // Mettre à jour l'utilisateur
    await firestore.collection('Users').doc(userId).update({
      'favoritePostsIds': FieldValue.arrayUnion([postId]),
      'updatedAt': DateTime.now().microsecondsSinceEpoch,
    });

    // Créer une notification pour l'auteur du post
    if (widget.post.user_id != userId && widget.post.user != null) {
      await _createFavoriteNotification(userId);
    }

    // Ajouter des points pour l'action
    addPointsForAction(UserAction.favorite);
    addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);
  }

  Future<void> _removeFromFavorites(
      String userId, String postId, FirebaseFirestore firestore) async {
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
        description:
            "@${authProvider.loginUserData.pseudo!} a ajouté votre post à ses favoris",
        users_id_view: [],
        user_id: userId,
        receiver_id: widget.post.user_id!,
        post_id: widget.post.id!,
        post_data_type: widget.post.dataType ?? PostDataType.IMAGE.name,
        updatedAt: DateTime.now().microsecondsSinceEpoch,
        createdAt: DateTime.now().microsecondsSinceEpoch,
        status: PostStatus.VALIDE.name,
      );

      await firestore
          .collection('Notifications')
          .doc(notification.id)
          .set(notification.toJson());

      // Notification push
      if (widget.post.user != null &&
          widget.post.user!.oneIgnalUserid != null) {
        await authProvider.sendNotification(
          userIds: [widget.post.user!.oneIgnalUserid!],
          smallImage: authProvider.loginUserData.imageUrl!,
          send_user_id: userId,
          recever_user_id: widget.post.user_id!,
          message:
              "❤️ @${authProvider.loginUserData.pseudo!} a ajouté votre post à ses favoris",
          type_notif: NotificationType.FAVORITE.name,
          post_id: widget.post.id!,
          post_type: widget.post.dataType ?? PostDataType.IMAGE.name,
          chat_id: '',
        );
      }
    } catch (e) {
      printVm('Erreur création notification favori: $e');
    }
  }

  // Vérifier si c'est un Look Challenge
  bool get _isLookChallenge {
    return widget.post.type == 'CHALLENGEPARTICIPATION';
  }

  Future<void> _loadPostRelations() async {
    try {
      // Vérifier qu'on a des IDs
      final post = widget.post;
      if (post.user_id == null || post.canal_id == null) return;

      // Récupérer l'utilisateur
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(post.user_id)
          .get();

      if (userDoc.exists) {
        post.user = UserData.fromJson(userDoc.data()!);
      }

      // Récupérer le canal
      final canalDoc = await FirebaseFirestore.instance
          .collection('Canaux')
          .doc(post.canal_id)
          .get();

      if (canalDoc.exists) {
        post.canal = Canal.fromJson(canalDoc.data()!);
      }

      // Rebuild UI avec les données chargées
      if (mounted) setState(() {});
    } catch (e, stack) {
      debugPrint('❌ Erreur récupération user/canal: $e\n$stack');
    }
  }

  Future<void> _checkIfUserHasVoted() async {
    try {
      final postDoc =
          await firestore.collection('Posts').doc(widget.post.id).get();
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        final voters = List<String>.from(data['users_votes_ids'] ?? []);
        setState(() {
          _hasVoted = voters.contains(authProvider.loginUserData.id);
          _votersList = voters;
        });
      }
    } catch (e) {
      printVm('Erreur lors de la vérification du vote: $e');
    }
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _incrementViews() async {
    try {
      if (authProvider.loginUserData == null ||
          widget.post == null ||
          widget.post.id == null) return;

      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) return;

      widget.post.users_vue_id ??= [];

      // 🔥 Vérifier si l'utilisateur a déjà vu le post
      if (widget.post.users_vue_id!.contains(currentUserId)) {
        printVm('⏭️ Vue déjà enregistrée pour cet utilisateur');
        return;
      }
      authProvider. incrementPostTotalInteractions(postId: widget.post.id!);

      // ✅ Mise à jour locale
      setState(() {
        widget.post.vues = (widget.post.vues ?? 0) + 1;
        widget.post.users_vue_id!.add(currentUserId);
      });

      // ✅ Mise à jour Firestore
      await firestore.collection('Posts').doc(widget.post.id).update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
        'popularity': FieldValue.increment(2),
      });

      PostViewService.recordAuthorView(widget.post, currentUserId);
      printVm('✅ Vue unique enregistrée pour ${widget.post.id}');
    } catch (e) {
      printVm("Erreur incrémentation vues: $e");
    }
  }

  Future<void> _incrementViewsOnly() async {
    try {
      if (authProvider.loginUserData == null ||
          widget.post == null ||
          widget.post.id == null) return;

      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) return;

      widget.post.users_vue_id ??= [];

      String viewKey =
          '${_lastViewDatePrefix}${currentUserId}_${widget.post.id}';
      String? lastViewDateStr = _prefs.getString(viewKey);

      if (lastViewDateStr != null) {
        DateTime lastViewDate = DateTime.parse(lastViewDateStr);
        DateTime now = DateTime.now();

        int difference = now.difference(lastViewDate).inDays;

        // ❌ Si moins de 2 jours -> ne pas compter
        if (difference < 2) {
          printVm(
              '⏭️ Post ${widget.post.id} déjà vu il y a $difference jour(s) - Vue NON comptée');

          if (!widget.post.users_vue_id!.contains(currentUserId)) {
            setState(() {
              widget.post.users_vue_id!.add(currentUserId);
            });
          }

          return;
        }
      }

      // 🔥 Sauvegarder la nouvelle date
      await _prefs.setString(viewKey, DateTime.now().toIso8601String());

      // ✅ Mise à jour locale
      setState(() {
        widget.post.vues = (widget.post.vues ?? 0) + 1;
        if (!widget.post.users_vue_id!.contains(currentUserId)) {
          widget.post.users_vue_id!.add(currentUserId);
        }
      });

      // ✅ Mise à jour Firestore
      await firestore.collection('Posts').doc(widget.post.id).update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
        'popularity': FieldValue.increment(2),
      });

      PostViewService.recordAuthorView(widget.post, currentUserId);
      printVm('✅ Vue enregistrée pour ${widget.post.id}');
    } catch (e) {
      printVm("Erreur incrémentation vues: $e");
    }
  }

  // FONCTIONNALITÉ DE VOTE
  Future<void> _loadChallengeData() async {
    if (widget.post.challenge_id == null) return;

    setState(() {
      _loadingChallenge = true;
    });

    try {
      final challengeDoc = await firestore
          .collection('Challenges')
          .doc(widget.post.challenge_id)
          .get();
      if (challengeDoc.exists) {
        setState(() {
          _challenge = Challenge.fromJson(challengeDoc.data()!)
            ..id = challengeDoc.id;
        });
      }
    } catch (e) {
      printVm('Erreur chargement challenge: $e');
    } finally {
      setState(() {
        _loadingChallenge = false;
      });
    }
  }

  Future<void> _voteForLook() async {
    if (_hasVoted || _isVoting) return;

    final user = _auth.currentUser;
    if (user == null) {
      _showError(
          'CONNECTEZ-VOUS POUR POUVOIR VOTER\nVotre vote compte pour élire le gagnant !');
      return;
    }

    setState(() {
      _isVoting = true;
    });

    try {
      // Si c'est un look challenge, recharger les données d'abord
      if (_isLookChallenge && widget.post.challenge_id != null) {
        await _reloadChallengeData();

        // Vérifier à nouveau après rechargement
        if (_challenge == null) {
          _showError(
              'Impossible de charger les données du challenge. Veuillez réessayer.');
          return;
        }

        final now = DateTime.now().microsecondsSinceEpoch;

        // Vérifier si le challenge est terminé
        if (_challenge!.isTermine || now > (_challenge!.finishedAt ?? 0)) {
          _showError('CE CHALLENGE EST TERMINÉ\nMerci pour votre intérêt !');
          return;
        }

        if (_challenge!.aVote(user.uid)) {
          _showError(
              'VOUS AVEZ DÉJÀ VOTÉ DANS CE CHALLENGE\nMerci pour votre participation !');
          return;
        }

        if (!_challenge!.isEnCours) {
          _showError(
              'CE CHALLENGE N\'EST PLUS ACTIF\nLe vote n\'est pas possible actuellement.');
          return;
        }

        // Vérifier le solde si vote payant
        if (!_challenge!.voteGratuit!) {
          final solde = await _getSoldeUtilisateur(user.uid);
          if (solde < _challenge!.prixVote!) {
            _showSoldeInsuffisant(_challenge!.prixVote! - solde.toInt());
            return;
          }
        }

        // Afficher la confirmation de vote
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _colors.surfaceVariant,
            title: Text('Confirmer votre vote',
                style: TextStyle(color: _colors.textPrimary)),
            content: Text(
              !_challenge!.voteGratuit!
                  ? 'Êtes-vous sûr de vouloir voter pour ce look ?\n\nCe vote vous coûtera ${_challenge!.prixVote} FCFA.'
                  : 'Voulez-vous vraiment voter pour ce look ?\n\nVotre vote est gratuit et ne peut être changé.',
              style: TextStyle(color: _colors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _isVoting = false;
                  });
                },
                child: Text('ANNULER', style: TextStyle(color: _colors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _processVoteWithChallenge(user.uid);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _colors.success),
                child: Text('CONFIRMER MON VOTE',
                    style: TextStyle(color: _colors.onPrimary)),
              ),
            ],
          ),
        );
      } else {
        // Vote normal (sans challenge)
        await _processVoteNormal(user.uid);
      }
    } catch (e) {
      printVm("Erreur lors de la préparation du vote: $e");
      _showError('Erreur lors de la préparation du vote: $e');
    }
  }

  Future<void> _reloadChallengeData() async {
    try {
      if (widget.post.challenge_id == null) return;

      if (mounted) {
        setState(() {
          _loadingChallenge = true;
        });
      }

      final challengeDoc = await firestore
          .collection('Challenges')
          .doc(widget.post.challenge_id)
          .get();

      if (challengeDoc.exists) {
        if (mounted) {
          setState(() {
            _challenge = Challenge.fromJson(challengeDoc.data()!)
              ..id = challengeDoc.id;
          });
        }
      } else {
        printVm('Challenge non trouvé: ${widget.post.challenge_id}');
        if (mounted) {
          setState(() {
            _challenge = null;
          });
        }
      }
    } catch (e) {
      printVm('Erreur rechargement challenge: $e');
      if (mounted) {
        setState(() {
          _challenge = null;
        });
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _loadingChallenge = false;
        });
      }
    }
  }

  Future<void> _processVoteWithChallenge(String userId) async {
    try {
      await _reloadChallengeData();

      if (_challenge == null) {
        throw Exception('Données du challenge non disponibles');
      }

      // Récupérer l'ID unique de l'appareil
      final String deviceId = await DeviceInfoService.getDeviceId();
      printVm("Vérification appareil pour vote: $deviceId");

      // Vérifier si l'appareil a déjà voté (uniquement si ID valide)
      if (DeviceInfoService.isDeviceIdValid(deviceId) &&
          _challenge!.aVoteAvecAppareil(deviceId)) {
        throw Exception(
            '🚨 VIOLATION DÉTECTÉE: Cet appareil a déjà été utilisé pour voter dans ce challenge. L\'utilisation de comptes multiples est strictement interdite.');
      }

      await firestore.runTransaction((transaction) async {
        final challengeRef =
            firestore.collection('Challenges').doc(_challenge!.id!);
        final challengeDoc = await transaction.get(challengeRef);

        if (!challengeDoc.exists) throw Exception('Challenge non trouvé');

        final currentChallenge = Challenge.fromJson(challengeDoc.data()!);

        if (!currentChallenge.isEnCours) {
          throw Exception('Le challenge n\'est plus actif');
        }

        if (currentChallenge.aVote(userId)) {
          throw Exception('Vous avez déjà voté dans ce challenge');
        }

        // Vérification supplémentaire de l'appareil dans la transaction
        if (DeviceInfoService.isDeviceIdValid(deviceId) &&
            currentChallenge.aVoteAvecAppareil(deviceId)) {
          throw Exception(
              '🚨 VIOLATION DÉTECTÉE: Cet appareil a déjà été utilisé pour voter. Utilisation de comptes multiples interdite.');
        }

        final postRef = firestore.collection('Posts').doc(widget.post.id);
        final postDoc = await transaction.get(postRef);

        if (!postDoc.exists) throw Exception('Post non trouvé');

        if (!_challenge!.voteGratuit!) {
          await _debiterUtilisateur(userId, _challenge!.prixVote!,
              'Vote pour le challenge ${_challenge!.titre}');
        }

        // Mettre à jour le post
        transaction.update(postRef, {
          'votes_challenge': FieldValue.increment(1),
          'users_votes_ids': FieldValue.arrayUnion([userId]),
          'popularity': FieldValue.increment(3),
        });

        // Préparer les updates pour le challenge
        final challengeUpdates = {
          'users_votants_ids': FieldValue.arrayUnion([userId]),
          'total_votes': FieldValue.increment(1),
          'updated_at': DateTime.now().microsecondsSinceEpoch
        };

        // Ajouter l'ID appareil uniquement s'il est valide
        if (DeviceInfoService.isDeviceIdValid(deviceId)) {
          challengeUpdates['devices_votants_ids'] =
              FieldValue.arrayUnion([deviceId]);
        }

        transaction.update(challengeRef, challengeUpdates);
      });

      // Succès du vote
      if (mounted) {
        setState(() {
          _hasVoted = true;
          _votersList.add(userId);
          widget.post.votesChallenge = (widget.post.votesChallenge ?? 0) + 1;
        });
      }

      addPointsForAction(UserAction.voteChallenge);
      addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);

      // Notification
      await authProvider.sendNotification(
        userIds: [widget.post.user!.oneIgnalUserid!],
        smallImage: authProvider.loginUserData.imageUrl!,
        send_user_id: authProvider.loginUserData.id!,
        recever_user_id: widget.post.user_id!,
        message:
            "🎉 @${authProvider.loginUserData.pseudo!} a voté pour votre look dans le challenge ${_challenge!.titre}!",
        type_notif: NotificationType.POST.name,
        post_id: widget.post.id!,
        post_type: PostDataType.IMAGE.name,
        chat_id: '',
      );

      postProvider.interactWithPostAndIncrementSolde(widget.post.id!,
          authProvider.loginUserData.id!, "vote_look", widget.post.user_id!);

      _showSuccess(
          '✅ VOTE ENREGISTRÉ !\nMerci d\'avoir participé à l\'élection du gagnant.');
      _envoyerNotificationVote(
          userVotant: authProvider.loginUserData!,
          userVote: widget.post!.user!);
    } catch (e) {
      printVm("Erreur lors du vote avec challenge: $e");

      // Message d'erreur spécifique pour les violations
      if (e.toString().contains('VIOLATION DÉTECTÉE')) {
        _showError('''🚨 FRAUDE DÉTECTÉE

Cet appareil a déjà été utilisé pour voter dans ce challenge.

Pour garantir l'équité du concours, chaque appareil ne peut voter qu'une seule fois, quel que soit le compte utilisé.

📞 Contactez le support si vous pensez qu'il s'agit d'une erreur.''');
      } else {
        _showError(
            '❌ ERREUR LORS DU VOTE: ${e.toString()}\nVeuillez réessayer.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  Future<void> _processVoteWithChallenge2(String userId) async {
    try {
      await _reloadChallengeData();

      if (_challenge == null) {
        throw Exception('Données du challenge non disponibles');
      }

      await firestore.runTransaction((transaction) async {
        final challengeRef =
            firestore.collection('Challenges').doc(_challenge!.id!);
        final challengeDoc = await transaction.get(challengeRef);

        if (!challengeDoc.exists) throw Exception('Challenge non trouvé');

        final currentChallenge = Challenge.fromJson(challengeDoc.data()!);

        if (!currentChallenge.isEnCours) {
          throw Exception('Le challenge n\'est plus actif');
        }

        if (currentChallenge.aVote(userId)) {
          throw Exception('Vous avez déjà voté dans ce challenge');
        }

        final postRef = firestore.collection('Posts').doc(widget.post.id);
        final postDoc = await transaction.get(postRef);

        if (!postDoc.exists) throw Exception('Post non trouvé');

        if (!_challenge!.voteGratuit!) {
          await _debiterUtilisateur(userId, _challenge!.prixVote!,
              'Vote pour le challenge ${_challenge!.titre}');
        }

        transaction.update(postRef, {
          'votes_challenge': FieldValue.increment(1),
          'users_votes_ids': FieldValue.arrayUnion([userId]),
          'popularity': FieldValue.increment(3),
        });

        transaction.update(challengeRef, {
          'users_votants_ids': FieldValue.arrayUnion([userId]),
          'total_votes': FieldValue.increment(1),
          'updated_at': DateTime.now().microsecondsSinceEpoch
        });
      });

      if (mounted) {
        setState(() {
          _hasVoted = true;
          _votersList.add(userId);
          widget.post.votesChallenge = (widget.post.votesChallenge ?? 0) + 1;
        });
      }
      addPointsForAction(UserAction.voteChallenge);
      addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);

      await authProvider.sendNotification(
        userIds: [widget.post.user!.oneIgnalUserid!],
        smallImage: authProvider.loginUserData.imageUrl!,
        send_user_id: authProvider.loginUserData.id!,
        recever_user_id: widget.post.user_id!,
        message:
            "🎉 @${authProvider.loginUserData.pseudo!} a voté pour votre look dans le challenge ${_challenge!.titre}!",
        type_notif: NotificationType.POST.name,
        post_id: widget.post.id!,
        post_type: PostDataType.IMAGE.name,
        chat_id: '',
      );

      postProvider.interactWithPostAndIncrementSolde(widget.post.id!,
          authProvider.loginUserData.id!, "vote_look", widget.post.user_id!);

      _showSuccess(
          'VOTE ENREGISTRÉ !\nMerci d\'avoir participé à l\'élection du gagnant.');
      _envoyerNotificationVote(
          userVotant: authProvider.loginUserData!,
          userVote: widget.post!.user!);
    } catch (e) {
      printVm("Erreur lors du vote avec challenge: $e");
      _showError('ERREUR LORS DU VOTE: ${e.toString()}\nVeuillez réessayer.');
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  Future<void> _envoyerNotificationVote({
    required UserData userVotant,
    required UserData userVote,
  }) async {
    try {
      final userIds = await authProvider.getAllUsersOneSignaUserId();

      if (userIds.isEmpty) {
        debugPrint("⚠️ Aucun utilisateur à notifier.");
        return;
      }

      final message = "👏 ${userVotant.pseudo} a voté pour ${userVote.pseudo}!";

      await authProvider.sendNotification(
        userIds: userIds,
        smallImage: userVotant.imageUrl ?? '',
        send_user_id: userVotant.id!,
        recever_user_id: userVote.id ?? "",
        message: message,
        type_notif: 'VOTE',
        post_id: '',
        post_type: '',
        chat_id: '',
      );

      debugPrint("✅ Notification envoyée: $message");
    } catch (e, stack) {
      debugPrint("❌ Erreur envoi notification vote: $e\n$stack");
    }
  }

  Future<void> _processVoteNormal(String userId) async {
    try {
      await firestore.collection('Posts').doc(widget.post.id).update({
        'votes_challenge': FieldValue.increment(1),
        'users_votes_ids': FieldValue.arrayUnion([userId]),
        'popularity': FieldValue.increment(3),
      });

      if (mounted) {
        setState(() {
          _hasVoted = true;
          _votersList.add(userId);
          widget.post.votesChallenge = (widget.post.votesChallenge ?? 0) + 1;
        });
      }

      await authProvider.sendNotification(
        userIds: [widget.post.user!.oneIgnalUserid!],
        smallImage: authProvider.loginUserData.imageUrl!,
        send_user_id: authProvider.loginUserData.id!,
        recever_user_id: widget.post.user_id!,
        message:
            "🎉 @${authProvider.loginUserData.pseudo!} a voté pour votre look !",
        type_notif: NotificationType.POST.name,
        post_id: widget.post.id!,
        post_type: PostDataType.IMAGE.name,
        chat_id: '',
      );

      await postProvider.interactWithPostAndIncrementSolde(widget.post.id!,
          authProvider.loginUserData.id!, "vote_look", widget.post.user_id!);

      _showSuccess('🎉 Vote enregistré !');
    } catch (e) {
      printVm("Erreur lors du vote normal: $e");
      _showError('Erreur lors du vote: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  Future<double> _getSoldeUtilisateur(String userId) async {
    final doc = await firestore.collection('Users').doc(userId).get();
    return (doc.data()?['votre_solde_principal'] ?? 0).toDouble();
  }

  Future<void> _debiterUtilisateur(
      String userId, int montant, String raison) async {
    await firestore
        .collection('Users')
        .doc(userId)
        .update({'votre_solde_principal': FieldValue.increment(-montant)});
    String appDataId = authProvider.appDefaultData.id!;

    await firestore.collection('AppData').doc(appDataId).set(
        {'solde_gain': FieldValue.increment(montant)}, SetOptions(merge: true));
    await _createTransaction(
        TypeTransaction.DEPENSE.name, montant.toDouble(), raison, userId);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: _colors.onPrimary)),
        backgroundColor: _colors.danger,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: _colors.onPrimary)),
        backgroundColor: _colors.success,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showSoldeInsuffisant(int montantManquant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _colors.surfaceVariant,
        title:
            Text('SOLDE INSUFFISANT', style: TextStyle(color: _colors.accent)),
        content: Text(
          'Il vous manque $montantManquant FCFA pour pouvoir voter.\n\n'
          'Rechargez votre compte pour soutenir votre look préféré !',
          style: TextStyle(color: _colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('PLUS TARD', style: TextStyle(color: _colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => DepositScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: _colors.success),
            child: Text('RECHARGER MAINTENANT',
                style: TextStyle(color: _colors.onPrimary)),
          ),
        ],
      ),
    );
  }

  void _showVoteConfirmationDialog() {
    final user = _auth.currentUser;

    if (_isLookChallenge && _challenge != null && !_challenge!.voteGratuit!) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: _colors.surfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _colors.primary, width: 2),
            ),
            title: Text(
              '🎉 Voter pour ce Look',
              style: TextStyle(
                color: _colors.primary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              'Ce vote vous coûtera ${_challenge!.prixVote} FCFA.\n\n'
              'Voulez-vous continuer ?',
              style: TextStyle(color: _colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler',
                    style: TextStyle(color: _colors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _voteForLook();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colors.primary,
                ),
                child: Text('Voter ${_challenge!.prixVote} FCFA',
                    style: TextStyle(color: _colors.onPrimary)),
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: _colors.surfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _colors.primary, width: 2),
            ),
            title: Text(
              '🎉 Voter pour ce Look',
              style: TextStyle(
                color: _colors.primary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              'Vous allez voter pour ce look${_isLookChallenge ? ' challenge' : ''}. Cette action est irréversible${_isLookChallenge && _challenge != null ? ' et vous rapportera 3 points' : ''}!',
              style: TextStyle(color: _colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler',
                    style: TextStyle(color: _colors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _voteForLook();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colors.primary,
                ),
                child: Text('Voter', style: TextStyle(color: _colors.onPrimary)),
              ),
            ],
          );
        },
      );
    }
  }

  String formatNumber(int number) {
    if (number >= 1000) {
      double nombre = number / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return number.toString();
    }
  }

  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) {
          return "il y a quelques secondes";
        } else {
          return "il y a ${difference.inMinutes} min";
        }
      } else {
        return "il y a ${difference.inHours} h";
      }
    } else if (difference.inDays < 7) {
      return "il y a ${difference.inDays} j";
    } else {
      return DateFormat('dd/MM/yy').format(dateTime);
    }
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  bool _isProcessing = false;
  Future<void> _handleLike2() async {
    // Éviter les doubles clics au niveau UI
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final userId = authProvider.loginUserData.id!;
      final postId = widget.post.id!;
      final postRef = firestore.collection('Posts').doc(postId);

      // Utiliser une transaction pour garantir l'atomicité
      await firestore.runTransaction((transaction) async {
        // 1. Lire l'état actuel du post dans la transaction
        final postSnapshot = await transaction.get(postRef);

        if (!postSnapshot.exists) {
          throw Exception('Post non trouvé');
        }

        final postData = postSnapshot.data() as Map<String, dynamic>;
        final usersLoveId = List<String>.from(postData['users_love_id'] ?? []);
        final currentLoves = postData['loves'] ?? 0;

        // 2. VÉRIFICATION CRITIQUE : L'utilisateur a-t-il déjà liké ?
        if (usersLoveId.contains(userId)) {
          throw Exception('Vous avez déjà liké ce post');
        }

        // 3. Mise à jour atomique
        transaction.update(postRef, {
          'loves': currentLoves + 1,
          'users_love_id': FieldValue.arrayUnion([userId]),
          'popularity': FieldValue.increment(3),
          // 'updatedAt': DateTime.now().microsecondsSinceEpoch,
        });
      });

      // 4. Mettre à jour l'UI seulement après le succès de la transaction
      setState(() {
        // widget.post.loves = (widget.post.loves ?? 0) + 1;
        // widget.post.users_love_id!.add(userId);
      });

      // 5. Actions post-like (notifications, points, etc.)
      await Future.wait([
        FeedInteractionService.onPostLoved(widget.post, userId),
        authProvider.sendNotification(
            userIds: [widget.post.user!.oneIgnalUserid!],
            smallImage: "${authProvider.loginUserData.imageUrl!}",
            send_user_id: "${authProvider.loginUserData.id!}",
            recever_user_id: "${widget.post.user_id!}",
            message:
                "📢 @${authProvider.loginUserData.pseudo!} a aimé votre ${_isLookChallenge ? 'look' : 'post'}",
            type_notif: NotificationType.POST.name,
            post_id: "${widget.post!.id!}",
            post_type: PostDataType.IMAGE.name,
            chat_id: ''),
        addPointsForAction(UserAction.like),
        addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre),
      ]);

      _animationController
          .forward()
          .then((_) => _animationController.reverse());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+ de points ajoutés à votre compte'),
          backgroundColor: _colors.success,
        ),
      );
    } catch (e) {
      printVm("Erreur like: $e");

      // Message d'erreur spécifique
      String errorMessage = "Erreur lors du like";
      if (e.toString().contains("déjà liké")) {
        errorMessage = "Vous avez déjà liké ce post";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: _colors.danger,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleLike1() async {
    try {
      if (!isIn(widget.post.users_love_id!, authProvider.loginUserData.id!)) {
        setState(() {
          widget.post.loves = widget.post.loves! + 1;
          widget.post.users_love_id!.add(authProvider.loginUserData.id!);
        });

        await firestore.collection('Posts').doc(widget.post.id).update({
          'loves': FieldValue.increment(1),
          'users_love_id':
              FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(3),
        });
        FeedInteractionService.onPostLoved(
            widget.post, authProvider.loginUserData.id!);

        await authProvider.sendNotification(
            userIds: [widget.post.user!.oneIgnalUserid!],
            smallImage: "${authProvider.loginUserData.imageUrl!}",
            send_user_id: "${authProvider.loginUserData.id!}",
            recever_user_id: "${widget.post.user_id!}",
            message:
                "📢 @${authProvider.loginUserData.pseudo!} a aimé votre ${_isLookChallenge ? 'look' : 'post'}",
            type_notif: NotificationType.POST.name,
            post_id: "${widget.post!.id!}",
            post_type: PostDataType.IMAGE.name,
            chat_id: '');
        // await postProvider.interactWithPostAndIncrementSolde(widget.post.id!,
        //     authProvider.loginUserData.id!, "like", widget.post.user_id!);
        addPointsForAction(UserAction.like);
        addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);

        _animationController.forward().then((_) {
          _animationController.reverse();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+ de points ajoutés à votre compte',
              textAlign: TextAlign.center,
              style: TextStyle(color: _colors.success),
            ),
          ),
        );
      }
    } catch (e) {
      printVm("Erreur like: $e");
    }
  }
  Future<void> _handleLike3() async {
    try {
      // Vérifications préalables
      final userId = authProvider.loginUserData.id;
      if (userId == null) {
        printVm("❌ Like: utilisateur non connecté");
        return;
      }

      final postId = widget.post.id;
      if (postId == null) {
        printVm("❌ Like: post sans ID");
        return;
      }

      final usersLoveId = widget.post.users_love_id;
      if (usersLoveId == null) {
        printVm("❌ Like: users_love_id est null, initialisation");
        // Option: initialiser la liste vide dans le post localement
        widget.post.users_love_id = [];
      }

      // Vérifier si l'utilisateur a déjà liké
      if (usersLoveId != null && usersLoveId.contains(userId)) {
        printVm("❌ Like: déjà liké");
        return;
      }

      // Mise à jour locale
      setState(() {
        widget.post.loves = (widget.post.loves ?? 0) + 1;
        widget.post.users_love_id ??= [];
        widget.post.users_love_id!.add(userId);
      });

      // Mise à jour Firestore
      await firestore.collection('Posts').doc(postId).update({
        'loves': FieldValue.increment(1),
        'users_love_id': FieldValue.arrayUnion([userId]),
        'popularity': FieldValue.increment(3),
      });

      FeedInteractionService.onPostLoved(widget.post, userId);

      final currentTimeMicroseconds = DateTime.now().microsecondsSinceEpoch;
      final targetUser = widget.post.user;

      // Récupérer le propriétaire du post
      final userDoc = await firestore.collection('Users').doc(widget.post.user_id!).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final lastNotificationTime = (userData?['lastNotificationTime'] ?? 0) as int;
        const twentyMinutesMicroseconds = 20 * 60 * 1000 * 1000;
        final timeSinceLastNotification = currentTimeMicroseconds - lastNotificationTime;

        if (timeSinceLastNotification >= twentyMinutesMicroseconds || lastNotificationTime == 0) {
          // Création notification
          final notificationId = firestore.collection('Notifications').doc().id;
          final notification = NotificationData(
            id: notificationId,
            titre: "Like ❤️",
            media_url: authProvider.loginUserData.imageUrl ?? '',
            type: NotificationType.POST.name,
            description: "@${authProvider.loginUserData.pseudo ?? ''} a aimé votre ${_isLookChallenge ? 'look' : 'post'}",
            users_id_view: [],
            user_id: userId,
            receiver_id: widget.post.user_id!,
            post_id: postId,
            post_data_type: widget.post.dataType ?? PostDataType.IMAGE.name,
            updatedAt: currentTimeMicroseconds,
            createdAt: currentTimeMicroseconds,
            status: PostStatus.VALIDE.name,
          );
          await firestore.collection('Notifications').doc(notificationId).set(notification.toJson());

          // Push notification (si l'utilisateur a un OneSignal ID)
          if (targetUser != null && targetUser.oneIgnalUserid != null && targetUser.oneIgnalUserid!.isNotEmpty) {
            await authProvider.sendNotification(
              userIds: [targetUser.oneIgnalUserid!],
              smallImage: authProvider.loginUserData.imageUrl ?? '',
              send_user_id: userId,
              recever_user_id: widget.post.user_id!,
              message: "📢 @${authProvider.loginUserData.pseudo ?? ''} a aimé votre ${_isLookChallenge ? 'look' : 'post'}",
              type_notif: NotificationType.POST.name,
              post_id: postId,
              post_type: widget.post.dataType ?? PostDataType.IMAGE.name,
              chat_id: '',
            );
          }

          // Mise à jour du timestamp
          await firestore.collection('Users').doc(widget.post.user_id!).update({
            'lastNotificationTime': currentTimeMicroseconds
          });
        } else {
          final minutesPassed = (timeSinceLastNotification / (60 * 1000 * 1000)).toStringAsFixed(1);
          printVm("⏱️ Notification limitée pour @${targetUser?.pseudo ?? 'inconnu'} - Dernière notification il y a $minutesPassed minutes");
        }
      }

      // Incrémenter les interactions totales
      await authProvider.incrementPostTotalInteractions(postId: postId);

      // Notifier les abonnés
      await authProvider.notifySubscribersOfInteraction(
        actionUserId: userId,
        postOwnerId: widget.post.user_id!,
        postId: postId,
        actionType: 'like',
        postDescription: widget.post.description,
        postImageUrl: widget.post.images?.first,
        postDataType: widget.post.dataType,
      );

      // Ajout des points
      addPointsForAction(UserAction.like);
      addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);

      _animationController.forward().then((_) {
        _animationController.reverse();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('+ de points ajoutés à votre compte', textAlign: TextAlign.center),
          backgroundColor: _colors.success,
        ),
      );
    } catch (e) {
      printVm("❌ Erreur like: $e");
    }
  }

  Future<void> _handleLike() async {
    try {
      // Vérifications préalables
      final userId = authProvider.loginUserData.id;
      if (userId == null) {
        printVm("❌ Like: utilisateur non connecté");
        return;
      }

      final postId = widget.post.id;
      if (postId == null) {
        printVm("❌ Like: post sans ID");
        return;
      }

      final usersLoveId = widget.post.users_love_id;
      if (usersLoveId == null) {
        printVm("❌ Like: users_love_id est null, initialisation");
        widget.post.users_love_id = [];
      }

      // // Vérifier si l'utilisateur a déjà liké
      // if (usersLoveId != null && usersLoveId.contains(userId)) {
      //   printVm("❌ Like: déjà liké");
      //   return;
      // }

      // 🔥 VÉRIFICATION DU SOLDE DE PIÈCES (2 pièces minimum)
      final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
      final hasEnoughCoins = coinProvider.giftCoinsBalance >= 2;

      if (!hasEnoughCoins) {
        _showInsufficientCoinsForLikeDialog();
        return;
      }

      // 🔥 ENVOI DU LIKE AVEC PIÈCES
      final success = await coinProvider.sendLikeWithCoins(
        senderId: userId,
        receiverId: widget.post.user_id!,
        post: widget.post,
        context: context,
      );

      if (!success) {
        _showInsufficientCoinsForLikeDialog();
        return;
      }

      // Mise à jour locale
      setState(() {
        widget.post.loves = (widget.post.loves ?? 0) + 1;
        widget.post.users_love_id ??= [];
        widget.post.users_love_id!.add(userId);
      });


      if (!usersLoveId!.contains(userId)) {
        // Mise à jour Firestore (déjà faite dans sendLikeWithCoins, mais on garde pour la popularité)
        await firestore.collection('Posts').doc(postId).update({
          'popularity': FieldValue.increment(3),
        });
        FeedInteractionService.onPostLoved(widget.post, userId);

        final currentTimeMicroseconds = DateTime.now().microsecondsSinceEpoch;
        final targetUser = widget.post.user;

        // Récupérer le propriétaire du post
        final userDoc = await firestore.collection('Users').doc(widget.post.user_id!).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          final lastNotificationTime = (userData?['lastNotificationTime'] ?? 0) as int;
          const twentyMinutesMicroseconds = 20 * 60 * 1000 * 1000;
          final timeSinceLastNotification = currentTimeMicroseconds - lastNotificationTime;

          if (timeSinceLastNotification >= twentyMinutesMicroseconds || lastNotificationTime == 0) {
            // Création notification
            final notificationId = firestore.collection('Notifications').doc().id;
            final notification = NotificationData(
              id: notificationId,
              titre: "Like ❤️ + 1 pièce",
              media_url: authProvider.loginUserData.imageUrl ?? '',
              type: NotificationType.POST.name,
              description: "@${authProvider.loginUserData.pseudo ?? ''} a aimé votre ${_isLookChallenge ? 'look' : 'post'} et vous a offert 1 pièce !",
              users_id_view: [],
              user_id: userId,
              receiver_id: widget.post.user_id!,
              post_id: postId,
              post_data_type: widget.post.dataType ?? PostDataType.IMAGE.name,
              updatedAt: currentTimeMicroseconds,
              createdAt: currentTimeMicroseconds,
              status: PostStatus.VALIDE.name,
            );
            await firestore.collection('Notifications').doc(notificationId).set(notification.toJson());

            // Push notification
            if (targetUser != null && targetUser.oneIgnalUserid != null && targetUser.oneIgnalUserid!.isNotEmpty) {
              await authProvider.sendNotification(
                userIds: [targetUser.oneIgnalUserid!],
                smallImage: authProvider.loginUserData.imageUrl ?? '',
                send_user_id: userId,
                recever_user_id: widget.post.user_id!,
                message: "📢 @${authProvider.loginUserData.pseudo ?? ''} a aimé votre ${_isLookChallenge ? 'look' : 'post'} et vous a offert 1 pièce !",
                type_notif: NotificationType.POST.name,
                post_id: postId,
                post_type: widget.post.dataType ?? PostDataType.IMAGE.name,
                chat_id: '',
              );
            }

            // Mise à jour du timestamp
            await firestore.collection('Users').doc(widget.post.user_id!).update({
              'lastNotificationTime': currentTimeMicroseconds
            });
          } else {
            final minutesPassed = (timeSinceLastNotification / (60 * 1000 * 1000)).toStringAsFixed(1);
            printVm("⏱️ Notification limitée pour @${targetUser?.pseudo ?? 'inconnu'} - Dernière notification il y a $minutesPassed minutes");
          }
        }

        // Incrémenter les interactions totales
        await authProvider.incrementPostTotalInteractions(postId: postId);

        // Notifier les abonnés
        await authProvider.notifySubscribersOfInteraction(
          actionUserId: userId,
          postOwnerId: widget.post.user_id!,
          postId: postId,
          actionType: 'like',
          postDescription: widget.post.description,
          postImageUrl: widget.post.images?.first,
          postDataType: widget.post.dataType,
        );

        // Ajout des points
        addPointsForAction(UserAction.like);
        addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);

      }



      _animationController.forward().then((_) {
        _animationController.reverse();
      });

      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('❤️ Like envoyé ! 1 pièce offerte au créateur.'),
      //     backgroundColor: Colors.green,
      //     duration: Duration(seconds: 2),
      //   ),
      // );
    } catch (e) {
      // printVm("❌ Erreur like: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Erreur: $e'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    }
  }
  void _showInsufficientCoinsForLikeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.of(context).postDetailSupportCreatorTitle,
          style: TextStyle(color: _colors.accent, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).postDetailLikeGivesCoin,
              style: TextStyle(color: _colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _colors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _colors.accent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).postDetailLikeCostsCoins,
                      style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).postDetailRechargeToSupport,
              style: TextStyle(color: _colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).postDetailCancel, style: TextStyle(color: _colors.textSecondary)),
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
              backgroundColor: _colors.accent,
              foregroundColor: _colors.onAccent,
            ),
            child: Text(AppLocalizations.of(context).postDetailRecharge, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  Future<void> _createTransaction(
      String type, double montant, String description, String userid) async {
    try {
      final transaction = TransactionSolde()
        ..id = firestore.collection('TransactionSoldes').doc().id
        ..user_id = userid
        ..type = type
        ..statut = StatutTransaction.VALIDER.name
        ..description = description
        ..montant = montant
        ..methode_paiement = "cadeau"
        ..createdAt = DateTime.now().millisecondsSinceEpoch
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;

      await firestore
          .collection('TransactionSoldes')
          .doc(transaction.id)
          .set(transaction.toJson());
    } catch (e) {
      printVm("Erreur création transaction: $e");
    }
  }

  Future<void> _sendGift(double amount) async {
    try {
      setState(() => _isLoading = true);

      final firestore = FirebaseFirestore.instance;
      await authProvider.getAppData();
      final senderSnap = await firestore
          .collection('Users')
          .doc(authProvider.loginUserData.id)
          .get();
      if (!senderSnap.exists) {
        throw Exception("Utilisateur expéditeur introuvable");
      }
      final senderData = senderSnap.data() as Map<String, dynamic>;
      final double senderBalance =
          (senderData['votre_solde_principal'] ?? 0.0).toDouble();

      if (senderBalance >= amount) {
        final double gainDestinataire = amount * 0.7;

        await firestore
            .collection('Users')
            .doc(authProvider.loginUserData.id)
            .update({
          'votre_solde_principal': FieldValue.increment(-amount),
        });

        await firestore.collection('Users').doc(widget.post.user!.id).update({
          'votre_solde_principal': FieldValue.increment(gainDestinataire),
        });

        String appDataId = authProvider.appDefaultData.id!;

        if (widget.post.user!.codeParrain != null) {
          if (authProvider.loginUserData!.codeParrain != null) {
            final double gainApplication = amount * 0.25;

            await firestore.collection('AppData').doc(appDataId).update({
              'solde_gain': FieldValue.increment(gainApplication),
            });
            authProvider.ajouterCadeauCommissionParrain(
                codeParrainage: authProvider.loginUserData!.codeParrain!,
                montant: amount);
            authProvider.ajouterCadeauCommissionParrain(
                codeParrainage: widget.post.user!.codeParrain!,
                montant: amount);
          } else {
            final double gainApplication = amount * 0.25;

            await firestore.collection('AppData').doc(appDataId).update({
              'solde_gain': FieldValue.increment(gainApplication),
            });
            authProvider.ajouterCommissionParrain(
                codeParrainage: widget.post.user!.codeParrain!,
                montant: amount);
          }
        } else {
          if (authProvider.loginUserData!.codeParrain != null) {
            final double gainApplication = amount * 0.25;

            await firestore.collection('AppData').doc(appDataId).update({
              'solde_gain': FieldValue.increment(gainApplication),
            });
            authProvider.ajouterCommissionParrain(
                codeParrainage: authProvider.loginUserData!.codeParrain!,
                montant: amount);
          } else {
            final double gainApplication = amount * 0.3;

            await firestore.collection('AppData').doc(appDataId).update({
              'solde_gain': FieldValue.increment(gainApplication),
            });
          }
        }

        await firestore.collection('Posts').doc(widget.post.id).update({
          'users_cadeau_id':
              FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(5),
        });

        await _createTransaction(
            TypeTransaction.DEPENSE.name,
            amount,
            "Cadeau envoyé à @${widget.post.user!.pseudo}",
            authProvider.loginUserData.id!);
        await _createTransaction(
            TypeTransaction.GAIN.name,
            gainDestinataire,
            "Cadeau reçu de @${authProvider.loginUserData.pseudo}",
            widget.post.user_id!);
        FeedInteractionService.onPostLoved(
            widget.post, authProvider.loginUserData.id!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _colors.success,
            content: Text(
              '🎁 Cadeau de ${amount.toInt()} FCFA envoyé avec succès!',
              style: TextStyle(color: _colors.onPrimary),
            ),
          ),
        );
        await authProvider.sendNotification(
          userIds: [widget.post.user!.oneIgnalUserid!],
          smallImage: "",
          send_user_id: "",
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
      printVm("Erreur envoi cadeau: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _colors.danger,
          content: Text(
            'Erreur lors de l\'envoi du cadeau',
            style: TextStyle(color: _colors.onPrimary),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  void _showGiftDialog() {
    _handleGift();
  }
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
              backgroundColor: _colors.success,
              duration: const Duration(seconds: 2),
            ),
          );

          // 🔥 Appeler le callback parent si existant
          // widget.onGiftSuccess?.call();
        },
      ),
    );
  }

  void _showGiftDialog2() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final height = MediaQuery.of(context).size.height * 0.6;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: _colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: _colors.accent, width: 2),
              ),
              child: Container(
                height: height,
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Envoyer un Cadeau',
                      style: TextStyle(
                        color: _colors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Choisissez le montant en FCFA',
                      style: TextStyle(color: _colors.textPrimary),
                    ),
                    SizedBox(height: 12),
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
                            onTap: () =>
                                setState(() => _selectedGiftIndex = index),
                            child: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _selectedGiftIndex == index
                                    ? _colors.success
                                    : _colors.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedGiftIndex == index
                                      ? _colors.accent
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
                                      color: _colors.textPrimary,
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
                        color: _colors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Annuler',
                              style: TextStyle(color: _colors.textPrimary)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _sendGift(giftPrices[_selectedGiftIndex]);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _colors.success,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Envoyer',
                            style: TextStyle(color: _colors.onPrimary),
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

  List<double> giftPrices = [
    10,
    25,
    50,
    100,
    200,
    300,
    500,
    700,
    1500,
    2000,
    2500,
    5000,
    7000,
    10000,
    15000,
    20000,
    30000,
    50000,
    75000,
    100000
  ];

  List<String> giftIcons = [
    '🌹',
    '❤️',
    '👑',
    '💎',
    '🏎️',
    '⭐',
    '🍫',
    '🧰',
    '🌵',
    '🍕',
    '🍦',
    '💻',
    '🚗',
    '🏠',
    '🛩️',
    '🛥️',
    '🏰',
    '💎',
    '🏎️',
    '🚗'
  ];

  Future<void> _repostForCash() async {
    try {
      setState(() => _isLoading = true);

      final firestore = FirebaseFirestore.instance;

      final userDoc = await firestore
          .collection('Users')
          .doc(authProvider.loginUserData.id)
          .get();
      final userData = userDoc.data();
      if (userData == null) throw Exception("Utilisateur introuvable !");
      final double soldeActuel =
          (userData['votre_solde_principal'] ?? 0.0).toDouble();

      if (soldeActuel >= _selectedRepostPrice) {
        await firestore
            .collection('Users')
            .doc(authProvider.loginUserData.id)
            .update({
          'votre_solde_principal': FieldValue.increment(-_selectedRepostPrice),
        });

        await firestore
            .collection('AppData')
            .doc(authProvider.appDefaultData.id!)
            .update({
          'solde_gain': FieldValue.increment(_selectedRepostPrice),
        });

        await firestore.collection('Posts').doc(widget.post.id).update({
          'users_republier_id':
              FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(4),
          'created_at': DateTime.now().microsecondsSinceEpoch,
          'updated_at': DateTime.now().microsecondsSinceEpoch,
        });

        await _createTransaction(
          TypeTransaction.DEPENSE.name,
          _selectedRepostPrice.toDouble(),
          "Republication du post ${widget.post.id}",
          authProvider.loginUserData.id!,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _colors.success,
            content: Text(
              '🔝 Post republié pour $_selectedRepostPrice FCFA!',
              style: TextStyle(color: _colors.onPrimary),
            ),
          ),
        );
      } else {
        _showInsufficientBalanceDialog();
      }
    } catch (e) {
      printVm("Erreur republication: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _colors.danger,
          content: Text(
            'Erreur lors de la republication',
            style: TextStyle(color: _colors.onPrimary),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _colors.accent, width: 2),
          ),
          title: Text(
            'Solde Insuffisant',
            style: TextStyle(
              color: _colors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Votre solde est insuffisant pour effectuer cette action. Veuillez recharger votre compte.',
            style: TextStyle(color: _colors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: _colors.textPrimary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => DepositScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _colors.success,
              ),
              child: Text('Recharger', style: TextStyle(color: _colors.onPrimary)),
            ),
          ],
        );
      },
    );
  }

  void _showRepostDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _colors.accent, width: 2),
          ),
          title: Text(
            'Republier le Post',
            style: TextStyle(
              color: _colors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Republier ce post le mettra en avant dans le fil d\'actualité. Coût: 25 FCFA.',
            style: TextStyle(color: _colors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: _colors.textPrimary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _repostForCash();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _colors.success,
              ),
              child: Text('Republier', style: TextStyle(color: _colors.onPrimary)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserHeader(Post post) {
    final canal = post.canal;
    final user = post.user;
    final isLocked = _isLockedContent();

    return GestureDetector(
      onTap: () {
        if (canal != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      CanalDetails(canal: widget.post.canal!)));
        } else {
          double w = MediaQuery.of(context).size.width;
          double h = MediaQuery.of(context).size.height;
          showUserDetailsModalDialog(user!, w, h, context);
        }
      },
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(
                  _optimizeImageUrl(canal?.urlImage ?? user?.imageUrl ?? '')
                  ,
                ),
                radius: 25,
              ),
              if ((canal?.isVerify ?? false) || (user?.isVerify ?? false))
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: _colors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified, color: _colors.info, size: 14),
                  ),
                ),
              if (_isLookChallenge)
                Positioned(
                  top: -2,
                  left: -2,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: _colors.onPrimary,
                      size: 12,
                    ),
                  ),
                ),
              if (isLocked)
                Positioned(
                  bottom: -2,
                  left: -2,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _colors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock,
                      color: _colors.onAccent,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canal != null) ...[
                  Row(
                    children: [
                      Text(
                        '#${(canal.titre != null && canal.titre!.length > 12) ? '${canal.titre!.substring(0, 12)}...' : canal.titre ?? ''}',
                        style: TextStyle(
                          color: _colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 4),
                      if (canal.isVerify ?? false)
                        Icon(Icons.verified, color: _colors.info, size: 16),
                      if (isLocked)
                        Icon(Icons.lock, color: _colors.accent, size: 16),
                    ],
                  ),
                  Text(
                    '${canal.usersSuiviId!.length ?? 0} abonnés',
                    style: TextStyle(
                      color: _colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ] else if (user != null) ...[
                  Row(
                    children: [
                      Text(
                        '@${user.pseudo ?? ''}',
                        style: TextStyle(
                          color: _colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 4),
                      UserBadgeWidget(user: user, size: 15),
                      // if (user.isVerify ?? false)
                      //   Icon(Icons.verified, color: _twitterBlue, size: 16),

                      // Dans _buildUserHeader, après AbonnementUtils.getUserBadge()
                      if (post.dataType == PostDataType.AUDIO.name)
                        Container(
                          margin: EdgeInsets.only(left: 4),
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _colors.info.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border:
                                Border.all(color: _colors.info.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.audiotrack,
                                  color: _colors.info, size: 10),
                              SizedBox(width: 2),
                              Text(
                                'AUDIO',
                                style: TextStyle(
                                  color: _colors.info,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(width: 4),
                      if (_isLookChallenge)
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _colors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _colors.primary),
                          ),
                          child: Text(
                            'LOOK',
                            style: TextStyle(
                              color: _colors.primary,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${user.userAbonnesIds!.length ?? 0} abonnés${_isLookChallenge ? ' • ${post.votesChallenge ?? 0} votes' : ''}',
                    style: TextStyle(
                      color: _colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    formaterDateTime(
                      DateTime.fromMicrosecondsSinceEpoch(post.createdAt ?? 0),
                    ),
                    style: TextStyle(
                      color: _colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showPostMenu(widget.post),
            child: Icon(
              Icons.more_horiz,
              color: _colors.textPrimary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  void _showPostMenu(Post post) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: _colors.surfaceVariant,
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
                _colors.textPrimary,
                () async {
                  post.status = PostStatus.SIGNALER.name;
                  final value = await postProvider.updateVuePost(post, context);
                  Navigator.pop(context);

                  final snackBar = SnackBar(
                    content: Text(
                      value ? 'Post signalé !' : 'Échec du signalement !',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: value ? _colors.success : _colors.danger),
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
                _colors.danger,
                () async {
                  if (authProvider.loginUserData.role == UserRole.ADM.name) {
                    await deletePost(post, context);
                  } else {
                    post.status = PostStatus.SUPPRIMER.name;
                    await deletePost(post, context);
                  }
                  Navigator.pop(context);

                  final snackBar = SnackBar(
                    content: Text(
                      'Post supprimé !',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _colors.success),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
              ),
            SizedBox(height: 8),
            Container(
                height: 0.5, color: _colors.textSecondary.withOpacity(0.3)),
            SizedBox(height: 8),
            _buildMenuOption(Icons.cancel, "Annuler", _colors.textSecondary,
                () {
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

  Widget _buildPostContent(Post post) {
    final isLocked = _isLockedContent();
    final text = _translatedDescription ?? post.description ?? "";

    // Pour le contenu verrouillé, limiter l'affichage
    if (isLocked) {
      final words = text.split(' ');
      final limitedText =
          words.length > 50 ? words.take(50).join(' ') + '...' : text;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextContent(limitedText, isLocked: true),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _colors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _colors.accent),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: _colors.accent, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Contenu réservé aux abonnés du canal',
                            style: TextStyle(
                              color: _colors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Affichage selon le type de média
          if (post.dataType == PostDataType.AUDIO.name)
            _buildAudioContent(post, true)
          else if (post.images != null && post.images!.isNotEmpty)
            _buildLockedMediaContent(),
        ],
      );
    }

    // Contenu déverrouillé
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: _buildTextContent(text),
          ),
        if ((post.description ?? '').trim().isNotEmpty)
          TranslatableDescription(
            postId: post.id ?? '',
            text: post.description ?? '',
            targetLang: Provider.of<LocaleProvider>(context, listen: false).locale.languageCode,
            onToggle: (t) => setState(() => _translatedDescription = t),
            style: TextStyle(color: _colors.textPrimary),
          ),

        // Affichage selon le type de média
        if (post.dataType == PostDataType.AUDIO.name)
          _buildAudioContent(post, false)
        else if (post.images != null && post.images!.isNotEmpty)
          _buildMediaContent(post),
      ],
    );
  }

  Widget _buildTextContent(String text, {bool isLocked = false}) {
    final words = text.split(' ');
    final isLong = words.length > 20;
    final displayedText = _isExpanded || !isLong || isLocked
        ? text
        : words.take(20).join(' ') + '...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Utilisation de Linkify pour les liens et HashTagText pour les hashtags
        GestureDetector(
          onLongPress: () {
            if (text.isEmpty) return;
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Description copiée'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          },
          child: Linkify(
            onOpen: (link) async {
              if (!await launchUrl(Uri.parse(link.url))) {
                throw Exception('Could not launch ${link.url}');
              }
            },
            text: displayedText,
            style: TextStyle(
              color: isLocked ? _colors.textSecondary : _colors.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
            linkStyle: TextStyle(
              color: _colors.info,
              fontWeight: FontWeight.w500,
            ),
            options: LinkifyOptions(humanize: false),
          ),
        ),
        if (isLong && !isLocked)
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
                      color: _colors.info,
                    ),
                  ),
                ),
              ),
              _buildSupportButton(),
              // buildTotalInteractions(
              //   totalCount: widget.post.totalInteractions ?? 0,
              //   color: Colors.blue,
              //   showLabel: false,
              // ),
            ],
          ),

        if (!isLong)
          Row(
            spacing: 5,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildSupportButton(),
              // buildTotalInteractions(
              //   totalCount: widget.post.totalInteractions ?? 0,
              //   color: Colors.blue,
              //   showLabel: false,
              // ),
            ],
          ),
      ],
    );
  }

  Widget _buildLockedMediaContent() {
    return Container(
      height: 300,
      margin: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: _colors.surfaceVariant,
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: _colors.textSecondary.withOpacity(0.1),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, color: _colors.accent, size: 50),
                  SizedBox(height: 16),
                  Text(
                    'Contenu verrouillé',
                    style: TextStyle(
                      color: _colors.accent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Abonnez-vous au canal pour voir ce contenu',
                    style: TextStyle(
                      color: _colors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent2(Post post) {
    return Container(
      height: 300,
      margin: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: _isLookChallenge
            ? Border.all(color: _colors.primary.withOpacity(0.3))
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: ImageSlideshow(
          initialPage: 0,
          indicatorColor: _isLookChallenge ? _colors.primary : _colors.accent,
          indicatorBackgroundColor: _colors.textSecondary,
          onPageChanged: (value) {
            printVm('Page changed: $value');
          },
          isLoop: true,
          children: post.images!
              .map((imageUrl) => GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FullScreenImage(singleImageUrl: imageUrl),
                        ),
                      );
                    },
                    child: Hero(
                      tag: imageUrl,
                      child: CachedNetworkImage(
                        imageUrl:_optimizeImageUrl(imageUrl) ,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          color: _colors.surfaceVariant,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: _colors.accent)),
                        ),
                        errorWidget: (context, url, error) =>
                            Icon(Icons.error, color: _colors.danger),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // 🔥 Remplacer la méthode _buildMediaContent existante par cette nouvelle version
  Widget _buildMediaContent3(Post post) {
    final images = post.images!;
    final imageCount = images.length;
    final double screenWidth = MediaQuery.of(context).size.width;

    // Définir la hauteur en fonction du nombre d'images
    double contentHeight;
    if (imageCount == 1) {
      contentHeight = screenWidth * 0.8; // Plus grand pour 1 image
    } else if (imageCount == 2) {
      contentHeight = screenWidth * 0.7; // Un peu moins haut pour 2 images
    } else {
      contentHeight = screenWidth * 0.7; // Même hauteur pour 3+ images
    }

    return Container(
      height: contentHeight,
      margin: EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: _isLookChallenge
            ? Border.all(color: _colors.primary.withOpacity(0.3))
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: _buildImageGallery(images, contentHeight),
      ),
    );
  }

  Widget _buildMediaContent(Post post) {
    final images = post.images!;
    final imageCount = images.length;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    // Hauteur plus grande pour un affichage immersif
    double contentHeight = screenHeight * 0.5; // 50% de l'écran
    contentHeight = contentHeight.clamp(300.0, 550.0);

    return Container(
      height: contentHeight,
      margin: EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: _colors.surfaceVariant,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_colors.isDark ? 0.5 : 0.12),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: _isLookChallenge
            ? Border.all(color: _colors.primary.withOpacity(0.3))
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // 🔥 CAROUSEL D'IMAGES
            PageView.builder(
              controller: _carouselController,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
                // Réinitialiser le timer quand l'utilisateur change manuellement
                _resetCarouselTimer();
              },
              itemCount: images.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _showFullScreenImage(images[index]),
                  child: Hero(
                    tag: images[index],
                    child: CachedNetworkImage(
                      imageUrl:_optimizeImageUrl(images[index]) ,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: contentHeight,
                      placeholder: (context, url) => Container(
                        color: _colors.surfaceVariant,
                        child: Center(
                          child: CircularProgressIndicator(color: _colors.accent),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: _colors.surfaceVariant,
                        child: Center(
                          child: Icon(Icons.error, color: _colors.danger, size: 50),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // 🔥 INDICATEUR DE PAGE (dots)
            if (imageCount > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    imageCount,
                        (index) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      width: _currentImageIndex == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentImageIndex == index
                            ? _colors.accent
                            : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

            // 🔥 COMPTEUR D'IMAGES (ex: 1/5)
            if (imageCount > 1)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1}/${imageCount}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

            // 🔥 INDICATEUR DE LECTURE AUTO
            if (imageCount > 1)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_circle_filled,
                        color: _colors.accent,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context).postDetailAuto,
                        style: TextStyle(
                          color: _colors.onPrimary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

// 🔥 RÉINITIALISER LE TIMER APRÈS INTERACTION MANUELLE
  void _resetCarouselTimer() {
    if (widget.post.images != null && widget.post.images!.length > 1) {
      _stopCarouselAutoPlay();
      _startCarouselAutoPlay();
    }
  }

// 🔥 NOUVELLE MÉTHODE POUR CONSTRUIRE LA GALERIE D'IMAGES
  Widget _buildImageGallery(List<String> images, double height) {
    final imageCount = images.length;

    if (imageCount == 1) {
      return _buildSingleImageFullScreen(images[0], height);
    } else if (imageCount == 2) {
      return _buildTwoImagesSideBySide(images, height);
    } else if (imageCount == 3) {
      return _buildThreeImagesLayout(images, height);
    } else {
      return _buildImageSlideshow(images, height);
    }
  }

// 🔥 1 IMAGE : PLEIN ÉCRAN AVEC ZOOM
  Widget _buildSingleImageFullScreen(String imageUrl, double height) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImage(singleImageUrl: imageUrl),
          ),
        );
      },
      child: Hero(
        tag: imageUrl,
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.8,
          maxScale: 5.0,
          child: CachedNetworkImage(
            imageUrl:_optimizeImageUrl(imageUrl) ,
            fit: BoxFit.cover,
            width: double.infinity,
            height: height,
            placeholder: (context, url) => Container(
              color: _colors.surfaceVariant,
              child: Center(
                child: CircularProgressIndicator(color: _colors.accent),
              ),
            ),
            errorWidget: (context, url, error) =>
                Icon(Icons.error, color: _colors.danger, size: 50),
          ),
        ),
      ),
    );
  }

// 🔥 2 IMAGES : CÔTE À CÔTE
  Widget _buildTwoImagesSideBySide(List<String> images, double height) {
    return Row(
      children: [
        // Première image (gauche)
        Expanded(
          child: GestureDetector(
            onTap: () => _showFullScreenImage(images[0]),
            child: Container(
              margin: EdgeInsets.only(right: 2),
              child: Hero(
                tag: images[0],
                child: CachedNetworkImage(
                  imageUrl:_optimizeImageUrl( images[0]),
                  fit: BoxFit.cover,
                  height: height,
                  placeholder: (context, url) => Container(
                    color: _colors.surfaceVariant,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: _colors.surfaceVariant,
                    child: Icon(Icons.error, color: _colors.danger),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Deuxième image (droite)
        Expanded(
          child: GestureDetector(
            onTap: () => _showFullScreenImage(images[1]),
            child: Container(
              margin: EdgeInsets.only(left: 2),
              child: Hero(
                tag: images[1],
                child: CachedNetworkImage(
                  imageUrl:_optimizeImageUrl( images[1]),
                  fit: BoxFit.cover,
                  height: height,
                  placeholder: (context, url) => Container(
                    color: _colors.surfaceVariant,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: _colors.surfaceVariant,
                    child: Icon(Icons.error, color: _colors.danger),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

// 🔥 3 IMAGES : 1 GRANDE + 2 PETITES
  Widget _buildThreeImagesLayout(List<String> images, double height) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Première image (2/3 de la largeur)
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () => _showFullScreenImage(images[0]),
            child: Container(
              margin: EdgeInsets.only(right: 2),
              height: height,
              child: Hero(
                tag: images[0],
                child: CachedNetworkImage(
                  imageUrl:_optimizeImageUrl( images[0]),
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: _colors.surfaceVariant,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: _colors.surfaceVariant,
                    child: Icon(Icons.error, color: _colors.danger),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Deuxième et troisième images (1/3 de la largeur)
        Expanded(
          flex: 1,
          child: Column(
            children: [
              // Deuxième image (moitié supérieure)
              Expanded(
                child: GestureDetector(
                  onTap: () => _showFullScreenImage(images[1]),
                  child: Container(
                    margin: EdgeInsets.only(left: 2, bottom: 2),
                    child: Hero(
                      tag: images[1],
                      child: CachedNetworkImage(
                        imageUrl:_optimizeImageUrl( images[1]),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: _colors.surfaceVariant,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: _colors.surfaceVariant,
                          child: Icon(Icons.error, color: _colors.danger),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Troisième image (moitié inférieure)
              Expanded(
                child: GestureDetector(
                  onTap: () => _showFullScreenImage(images[2]),
                  child: Container(
                    margin: EdgeInsets.only(left: 2, top: 2),
                    child: Hero(
                      tag: images[2],
                      child: CachedNetworkImage(
                        imageUrl: _optimizeImageUrl( images[2]),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: _colors.surfaceVariant,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: _colors.surfaceVariant,
                          child: Icon(Icons.error, color: _colors.danger),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

// 🔥 4+ IMAGES : SLIDESHOW AVEC INDICATEURS
  Widget _buildImageSlideshow(List<String> images, double height) {
    return ImageSlideshow(
      initialPage: 0,
      indicatorColor: _isLookChallenge ? _colors.primary : _colors.accent,
      indicatorBackgroundColor: _colors.textSecondary,
      onPageChanged: (value) {
        printVm('Page changed: $value');
      },
      isLoop: true,
      children: images
          .map((imageUrl) => GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenImage(singleImageUrl: imageUrl),
                    ),
                  );
                },
                child: Hero(
                  tag: imageUrl,
                  child: CachedNetworkImage(
                    imageUrl:_optimizeImageUrl(imageUrl) ,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: _colors.surfaceVariant,
                      child: Center(
                          child:
                              CircularProgressIndicator(color: _colors.accent)),
                    ),
                    errorWidget: (context, url, error) =>
                        Icon(Icons.error, color: _colors.danger),
                  ),
                ),
              ))
          .toList(),
    );
  }

// 🔥 MÉTHODE POUR AFFICHER L'IMAGE PLEIN ÉCRAN
  void _showFullScreenImage(String imageUrl) {
    // Mettre en pause le carousel auto quand on ouvre le plein écran
    _stopCarouselAutoPlay();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImage(
          singleImageUrl: imageUrl,
          imageUrls: widget.post.images, // Passer toutes les images
          initialIndex: _currentImageIndex,
        ),
      ),
    ).then((_) {
      // Redémarrer le carousel auto quand on revient
      if (widget.post.images != null && widget.post.images!.length > 1) {
        _startCarouselAutoPlay();
      }
    });
  }
  // NOUVELLE SECTION POUR LES LOOK CHALLENGES
  Widget _buildLookChallengeSection(Post post) {
    if (!_isLookChallenge) return SizedBox();

    return FutureBuilder<DocumentSnapshot>(
      future: widget.post.challenge_id != null
          ? firestore
              .collection('Challenges')
              .doc(widget.post.challenge_id)
              .get()
          : null,
      builder: (context, challengeSnapshot) {
        if (challengeSnapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 15),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _colors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _colors.primary.withOpacity(0.3)),
            ),
            child: Center(
              child: CircularProgressIndicator(color: _colors.primary),
            ),
          );
        }

        if (challengeSnapshot.hasError ||
            !challengeSnapshot.hasData ||
            !challengeSnapshot.data!.exists) {
          return _buildBasicChallengeSection(post);
        }

        final challengeData =
            challengeSnapshot.data!.data() as Map<String, dynamic>;
        final challenge = Challenge.fromJson(challengeData);
        final bool challengeTermine = challenge.isTermine ||
            DateTime.now().microsecondsSinceEpoch > (challenge.finishedAt ?? 0);
        final bool peutVoter = challenge.peutParticiper && !_hasVoted;

        return FutureBuilder<DocumentSnapshot>(
          future: challenge.postChallengeId != null
              ? firestore
                  .collection('Posts')
                  .doc(challenge.postChallengeId)
                  .get()
              : null,
          builder: (context, postChallengeSnapshot) {
            Post? postChallenge;
            if (postChallengeSnapshot.hasData &&
                postChallengeSnapshot.data!.exists) {
              final postData =
                  postChallengeSnapshot.data!.data() as Map<String, dynamic>;
              postChallenge = Post.fromJson(postData);
            }

            return Container(
              margin: EdgeInsets.symmetric(vertical: 15),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _colors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _colors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_events, color: _colors.primary, size: 24),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LOOK CHALLENGE',
                              style: TextStyle(
                                color: _colors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (challenge.titre != null &&
                                challenge.titre!.isNotEmpty)
                              Text(
                                challenge.titre!,
                                style: TextStyle(
                                  color: _colors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  if (postChallenge != null)
                    _buildChallengePostPreview(challenge, postChallenge),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildChallengeStatItem(
                        icon: Icons.how_to_vote,
                        value: '${post.votesChallenge ?? 0}',
                        label: 'Votes',
                        color: _colors.primary,
                      ),
                      _buildChallengeStatItem(
                        icon: Icons.people,
                        value: '${challenge.usersInscritsIds!.length ?? 0}',
                        label: 'Participants',
                        color: _colors.info,
                      ),
                      _buildChallengeStatItem(
                        icon: Icons.favorite,
                        value: '${post.loves ?? 0}',
                        label: 'Likes',
                        color: _colors.danger,
                      ),
                      _buildChallengeStatItem(
                        icon: Icons.trending_up,
                        value: '${post.popularity ?? 0}',
                        label: 'Popularité',
                        color: _colors.accent,
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (challenge.description != null &&
                      challenge.description!.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _colors.background.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📝 À propos du challenge',
                            style: TextStyle(
                              color: _colors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            challenge.description!,
                            style: TextStyle(
                              color: _colors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 12),
                  Column(
                    children: [
                      if (!challengeTermine)
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _colors.isDark
                                ? Colors.black.withOpacity(0.3)
                                : _colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '🎯 VOTER POUR CE LOOK',
                                style: TextStyle(
                                  color: _colors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Votre vote aide ce participant à gagner le challenge !',
                                style: TextStyle(
                                  color: _colors.textSecondary,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (!challenge.voteGratuit!)
                                Text(
                                  'Coût du vote: ${challenge.prixVote} FCFA',
                                  style: TextStyle(
                                    color: _colors.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _colors.danger.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '⏰ CE CHALLENGE EST TERMINÉ',
                            style: TextStyle(
                              color: _colors.danger,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          if (peutVoter)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isVoting
                                    ? null
                                    : _showVoteConfirmationDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _colors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: _isVoting
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _colors.onPrimary,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.how_to_vote, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'VOTER',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            )
                          else
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _colors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _colors.primary),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: _colors.primary, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      _hasVoted
                                          ? 'DÉJÀ VOTÉ'
                                          : 'NON DISPONIBLE',
                                      style: TextStyle(
                                        color: _colors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              if (challenge.id != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChallengeDetailPage(
                                        challengeId: challenge.id!),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _colors.info,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Voir',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_votersList.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Derniers votants',
                      style: TextStyle(
                        color: _colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _votersList.length,
                        itemBuilder: (context, index) {
                          return FutureBuilder<DocumentSnapshot>(
                            future: firestore
                                .collection('Users')
                                .doc(_votersList[index])
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.exists) {
                                var userData = UserData.fromJson(snapshot.data!
                                    .data() as Map<String, dynamic>);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        backgroundImage: NetworkImage(_optimizeImageUrl(userData.imageUrl ?? '')
                                            ),
                                        radius: 15,
                                      ),
                                      SizedBox(height: 2),
                                      Text('🗳️',
                                          style: TextStyle(fontSize: 8)),
                                    ],
                                  ),
                                );
                              }
                              return SizedBox();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChallengePostPreview(Challenge challenge, Post postChallenge) {
    final hasImages =
        postChallenge.images != null && postChallenge.images!.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.primary.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsPost(post: postChallenge),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.all(8),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _colors.textSecondary.withOpacity(0.1),
                    ),
                    child: _buildChallengePreviewThumbnail(postChallenge),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Post du Challenge',
                          style: TextStyle(
                            color: _colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          challenge.titre ?? 'Challenge',
                          style: TextStyle(
                            color: _colors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap pour voir →',
                          style: TextStyle(
                            color: _colors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengePreviewThumbnail(Post post) {
    final hasImages = post.images != null && post.images!.isNotEmpty;

    if (hasImages) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: post.images!.first,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: _colors.textSecondary.withOpacity(0.2),
            child: Icon(Icons.photo, color: _colors.textSecondary, size: 20),
          ),
          errorWidget: (context, url, error) =>
              Icon(Icons.error, color: _colors.danger, size: 20),
        ),
      );
    } else {
      return Container(
        color: _colors.textSecondary.withOpacity(0.2),
        child: Icon(Icons.article, color: _colors.textSecondary, size: 20),
      );
    }
  }

  Widget _buildBasicChallengeSection(Post post) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 15),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: _colors.primary, size: 24),
              SizedBox(width: 8),
              Text(
                'LOOK CHALLENGE',
                style: TextStyle(
                  color: _colors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildChallengeStatItem(
                icon: Icons.how_to_vote,
                value: '${post.votesChallenge ?? 0}',
                label: 'Votes',
                color: _colors.primary,
              ),
              _buildChallengeStatItem(
                icon: Icons.bar_chart,
                value: '${post.totalInteractions ?? 0}',
                label: 'Interactions',
                color: _colors.info,
              ),
              _buildChallengeStatItem(
                icon: Icons.favorite,
                value: '${post.loves ?? 0}',
                label: 'Likes',
                color: _colors.danger,
              ),
            ],
          ),
          SizedBox(height: 16),
          if (!_hasVoted)
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVoting ? null : _showVoteConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isVoting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _colors.onPrimary,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.how_to_vote, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'VOTER POUR CE LOOK',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _colors.primary),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: _colors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Vous avez déjà voté pour ce look',
                    style: TextStyle(
                      color: _colors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChallengeStatItem(
      {required IconData icon,
      required String value,
      required String label,
      required Color color}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: _colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _colors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  void _handleShare() async {
    // Activer le mode chargement
    setState(() {
      _isSharing = true;
    });

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
        shareImageUrl = (widget.post.images?.isNotEmpty ?? false)
            ? widget.post.images!.first
            : "";
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
        'users_partage_id':
            FieldValue.arrayUnion([authProvider.loginUserData.id]),
      });

      authProvider.checkAndRefreshPostDates(widget.post.id!);

      if (!isIn(
          widget.post.users_partage_id!, authProvider.loginUserData.id!)) {
        addPointsForAction(UserAction.partagePost);
        addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);


        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+ de points ajoutés à votre compte',
              textAlign: TextAlign.center,
              style: TextStyle(color: _colors.success),
            ),
          ),
        );
      }
      // await authProvider. incrementPostTotalInteractions(postId: widget.post.id!);

      authProvider. notifySubscribersOfInteraction(
        actionUserId: authProvider.loginUserData.id!,
        postOwnerId: widget.post.user_id!,
        postId: widget.post.id!,
        actionType: 'share',
        postDescription: widget.post.description,
        postImageUrl: widget.post.images?.first,
        postDataType: widget.post.dataType,
      );
    } catch (e) {
      printVm("Erreur partage: $e");
    } finally {
      // Désactiver le chargement même en cas d'erreur
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _colors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: _colors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Icon(Icons.share, color: _colors.info),
              title: Text('Partager',
                  style: TextStyle(color: _colors.textPrimary)),
              onTap: () { Navigator.pop(ctx); _handleShare(); },
            ),
            ListTile(
              leading: Icon(Icons.send_rounded, color: _colors.primary),
              title: Text('Envoyer dans un chat',
                  style: TextStyle(color: _colors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => PostShareSheet(post: widget.post),
                );
              },
            ),
            Divider(color: _colors.divider),
            ListTile(
              leading: Icon(Icons.cancel, color: _colors.textSecondary),
              title: Text('Annuler',
                  style: TextStyle(color: _colors.textPrimary)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(Post post) {
    final hasAccess = _hasAccessToContent();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          icon: Icons.bar_chart,
          count: post!.isAdvertisement!
              ? _advertisement!.views!
              : post.totalInteractions ?? 0,
          label: 'Interactions',
        ),
        GestureDetector(
          onTap: _handleLike,
          child: _buildStatItem(
            icon: Icons.favorite_border,
            count: post.loves ?? 0,
            label: 'Likes',
            isLiked: isIn(post.users_love_id!, authProvider.loginUserData.id!),
            isLocked: false,
          ),
        ),
        GestureDetector(
          onTap: hasAccess
              ? () {
                  firestore.collection('Posts').doc(widget.post.id).update({
                    'popularity': FieldValue.increment(1),
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostComments(post: widget.post),
                    ),
                  );
                }
              : null,
          child: _buildStatItem(
            icon: Icons.comment,
            count: widget.post.comments ?? 0,
            label: 'Comments',
            isLocked: !hasAccess,
          ),
        ),
        // NOUVEAU : Compteur de favoris
        GestureDetector(
          onTap: hasAccess && !_isProcessingFavorite ? _toggleFavorite : null,
          child: _buildStatItem(
            icon: _isFavorite ? Icons.bookmark : Icons.bookmark_border,
            count: post.favoritesCount ?? 0,
            label: 'Favoris',
            isLiked: _isFavorite,
            isLocked: !hasAccess,
          ),
        ),
        Builder(builder: (ctx) {
          final isOwner = authProvider.loginUserData.id == post.user_id;
          if (isOwner || !hasAccess) {
            return _buildStatItem(
              icon: Icons.card_giftcard,
              count: post.totalGiftCoinsSentOnThisPost ?? 0,
              label: 'Cadeaux',
              isLocked: !hasAccess,
            );
          }
          return QuickGiftBar(
            receiverId: post.user_id!,
            receiverName: post.user?.pseudo ?? 'Créateur',
            receiverAvatar: post.user?.imageUrl ?? '',
            post: post,
            giftCount: post.totalGiftCoinsSentOnThisPost ?? 0,
          );
        }),
        _isSharing
            ? SizedBox(
          width: 40, // Ajustez selon la taille de vos boutons
          height: 40,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircularProgressIndicator(strokeWidth: 2, color: _colors.accent), // ou votre couleur _afroTextSecondary
          ),
        )
            :GestureDetector(
          onTap: hasAccess ? _showShareOptions : null,
          child: _buildStatItem(
            icon: Icons.share,
            count: post.partage ?? 0,
            label: 'Partages',
            isLocked: !hasAccess,
          ),
        ),
      ],
    );
  }


  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
    bool isLiked = false,
    bool isLocked = false,
  }) {
    Color iconColor;

    // Gestion spéciale pour l'icône bookmark
    if (icon == Icons.bookmark || icon == Icons.bookmark_border) {
      iconColor = isLocked
          ? _colors.textSecondary.withOpacity(0.3)
          : (isLiked ? _colors.accent : _colors.warning);
    } else if (icon == Icons.favorite || icon == Icons.favorite_border) {
      iconColor = isLocked
          ? _colors.textSecondary.withOpacity(0.3)
          : (isLiked ? _colors.danger : _colors.warning);
    } else {
      iconColor =
          isLocked ? _colors.textSecondary.withOpacity(0.3) : _colors.warning;
    }

    return Column(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
        SizedBox(height: 5),
        Text(
          formatNumber(count),
          style: TextStyle(
            color: isLocked
                ? _colors.textSecondary.withOpacity(0.3)
                : _colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isLocked
                ? _colors.textSecondary.withOpacity(0.3)
                : _colors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final isLocked = _isLockedContent();

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _colors.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isLookChallenge ? 'Look Challenge' : 'Post',
          style: TextStyle(
              color: _colors.accent, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Text(
            'Afrolook',
            style: TextStyle(
                color: _colors.success, fontWeight: FontWeight.bold, fontSize: 20),
          )
        ],
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _postStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Erreur de chargement',
                    style: TextStyle(color: _colors.textPrimary)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: _colors.accent));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
                child: Text('Post non trouvé',
                    style: TextStyle(color: _colors.textPrimary)));
          }

          final updatedPost =
              Post.fromJson(snapshot.data!.data() as Map<String, dynamic>);
          updatedPost.user = widget.post.user;
          updatedPost.canal = widget.post.canal;
          if (_isLoadingAd) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _colors.accent),
              ),
            );
          }
          return _isLoading
              ? Center(child: CircularProgressIndicator(color: _colors.accent))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserHeader(updatedPost),
                      SizedBox(height: 5),

                      _buildAdvertisementHeader(),
                      _buildBoostSection(),
                      _buildPostContent(updatedPost),

                      if (_isLookChallenge)
                        _buildLookChallengeSection(updatedPost),

                      // Bouton d'abonnement si contenu verrouillé
                      if (isLocked) _buildSubscribeButton(),

                      SizedBox(height: 20),
                      Divider(color: _colors.divider),
                      _buildStatsRow(updatedPost),
                      // _buildAdMrec(key: 'ad_details_post'),

                      PostGiftsList(
                        postId: widget. post.id!,
                        compactLevel: CompactLevel.light,
                        maxDisplayItems: 10,
                      ),

                      // Section des cadeaux récents
                      // if (updatedPost.users_cadeau_id != null &&
                      //     updatedPost.users_cadeau_id!.isNotEmpty &&
                      //     _hasAccessToContent())
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 20),
                      //     child: Column(
                      //       crossAxisAlignment: CrossAxisAlignment.start,
                      //       children: [
                      //         Text(
                      //           'Derniers cadeaux',
                      //           style: TextStyle(
                      //             color: Colors.yellow,
                      //             fontWeight: FontWeight.bold,
                      //             fontSize: 16,
                      //           ),
                      //         ),
                      //         SizedBox(height: 10),
                      //         Container(
                      //           height: 60,
                      //           child: ListView.builder(
                      //             scrollDirection: Axis.horizontal,
                      //             itemCount:
                      //                 updatedPost.users_cadeau_id!.length,
                      //             itemBuilder: (context, index) {
                      //               return FutureBuilder<DocumentSnapshot>(
                      //                 future: firestore
                      //                     .collection('Users')
                      //                     .doc(updatedPost
                      //                         .users_cadeau_id![index])
                      //                     .get(),
                      //                 builder: (context, snapshot) {
                      //                   if (snapshot.hasData &&
                      //                       snapshot.data!.exists) {
                      //                     var userData = UserData.fromJson(
                      //                         snapshot.data!.data()
                      //                             as Map<String, dynamic>);
                      //                     return Padding(
                      //                       padding: const EdgeInsets.only(
                      //                           right: 10),
                      //                       child: Column(
                      //                         children: [
                      //                           CircleAvatar(
                      //                             backgroundImage: NetworkImage(
                      //                                 userData.imageUrl ?? ''),
                      //                             radius: 15,
                      //                           ),
                      //                           SizedBox(height: 2),
                      //                           Text('🎁',
                      //                               style:
                      //                                   TextStyle(fontSize: 8)),
                      //                         ],
                      //                       ),
                      //                     );
                      //                   }
                      //                   return SizedBox();
                      //                 },
                      //               );
                      //             },
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),

                      _buildSuggestedPosts(), // AJOUTER CETTE LIGNE

                      if (_showRewardedAd)
                        RewardedAdWidget(
                          key: _rewardedAdKey,
                          onUserEarnedReward: (amount, name) async {
                            await _onSupportAdRewarded();
                          },
                          onAdDismissed: () {
                            setState(() {
                              _showRewardedAd = false;
                              _isSupporting = false;
                            });
                          },
                          child: const SizedBox.shrink(),
                        ),
                    ],
                  ),
                );
        },
      ),
    );
  }

  Widget _buildSubscribeButton() {
    final isCanalPost = widget.post.canal != null;
    final isPrivate = widget.post.canal?.isPrivate == true;
    final subscriptionPrice = widget.post.canal?.subscriptionPrice ?? 0;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 12),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _colors.accent,
          foregroundColor: _colors.onAccent,
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
                builder: (context) => CanalDetails(canal: widget.post.canal!),
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
}

class FullScreenImage extends StatefulWidget {
  final String? singleImageUrl;
  final List<String>? imageUrls;
  final int initialIndex;

  const FullScreenImage({
    super.key,
    this.singleImageUrl,
    this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> get images {
    if (widget.imageUrls != null && widget.imageUrls!.isNotEmpty) {
      return widget.imageUrls!;
    } else if (widget.singleImageUrl != null) {
      return [widget.singleImageUrl!];
    }
    return [];
  }
  String _optimizeImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final appDefaultData = authProvider.appDefaultData;

    return authProvider.convertToCdnUrl(url, appDefaultData);
  }
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Galerie d'images
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 5.0,
                  child: Center(
                    child: Hero(
                      tag: images[index],
                      child: CachedNetworkImage(
                        imageUrl:_optimizeImageUrl(images[index]) ,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(color: colors.accent),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(Icons.error, color: colors.danger, size: 60),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bouton retour
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: colors.background.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.close, color: colors.textPrimary, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Indicateur de position
          if (images.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.background.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1}/${images.length}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

          // Boutons de navigation
          if (images.length > 1) ...[
            if (_currentIndex > 0)
              Positioned(
                left: 16,
                top: MediaQuery.of(context).size.height / 2 - 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.background.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.chevron_left, color: colors.textPrimary, size: 36),
                    onPressed: () {
                      _pageController.previousPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),

            if (_currentIndex < images.length - 1)
              Positioned(
                right: 16,
                top: MediaQuery.of(context).size.height / 2 - 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.background.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.chevron_right, color: colors.textPrimary, size: 36),
                    onPressed: () {
                      _pageController.nextPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
