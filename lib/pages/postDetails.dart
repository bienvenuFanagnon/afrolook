import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:afrotok/pages/challenge/challengeDetails.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/home/homeWidget.dart';
import 'package:afrotok/pages/paiement/depotPaiment.dart';
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:afrotok/pages/postDetailsVideo.dart';
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

import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/authProvider.dart';
import '../services/linkService.dart';
import '../services/postService/feed_interaction_service.dart';
import '../services/utils/abonnement_utils.dart';
import 'UserServices/deviceService.dart';
import 'canaux/detailsCanal.dart';

import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:shared_preferences/shared_preferences.dart';

const _twitterDarkBg = Color(0xFF000000);
const _twitterCardBg = Color(0xFF16181C);
const _twitterTextPrimary = Color(0xFFFFFFFF);
const _twitterTextSecondary = Color(0xFF71767B);
const _twitterBlue = Color(0xFF1D9BF0);
const _twitterRed = Color(0xFFF91880);
const _twitterGreen = Color(0xFF00BA7C);
const _twitterYellow = Color(0xFFFFD400);
const _afroBlack = Color(0xFF000000);

const _afroGreen = Color(0xFF2ECC71);
const _afroYellow = Color(0xFFF1C40F);
const _afroRed = Color(0xFFE74C3C);
const _afroDarkGrey = Color(0xFF16181C);
const _afroLightGrey = Color(0xFF71767B);

class DetailsPost extends StatefulWidget {
  final Post post;

  DetailsPost({Key? key, required this.post}) : super(key: key);

  @override
  _DetailsPostState createState() => _DetailsPostState();
}

class _DetailsPostState extends State<DetailsPost>
    with SingleTickerProviderStateMixin {
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
      print('Erreur lors de la vérification des favoris: $e');
    }
  }

  // Modifications à apporter à DetailsPost (ajouter ces méthodes et widgets)

// 1. Ajouter dans l'état de _DetailsPostState :

// Variables pour la publicité
  Advertisement? _advertisement;
  bool _isLoadingAd = false;
  bool _isAd = false;
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
          child: CircularProgressIndicator(color: Colors.yellow),
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
              color: Colors.white,
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
                            color: Colors.grey[800],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Miniature (image ou vidéo)
                                (post.dataType == PostDataType.VIDEO.name && post.thumbnail != null && post.thumbnail!.isNotEmpty)
                                    ? CachedNetworkImage(
                                  imageUrl: post.thumbnail!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(color: Colors.yellow),
                                  ),
                                  errorWidget: (context, url, error) => Icon(Icons.video_library, color: Colors.grey, size: 40),
                                )
                                    : (post.images != null && post.images!.isNotEmpty)
                                    ? CachedNetworkImage(
                                  imageUrl: post.images!.first,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(color: Colors.yellow),
                                  ),
                                  errorWidget: (context, url, error) => Icon(Icons.image, color: Colors.grey, size: 40),
                                )
                                    : Icon(Icons.image, color: Colors.grey, size: 40),

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
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),

                              SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.bar_chart, size: 12, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Text(
                                    '${post.totalInteractions ?? 0}',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
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
                if (!isLastItem) Divider(color: Colors.grey[800]),
              ],
            );
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
        SnackBar(content: Text('Vous ne pouvez pas soutenir votre propre post'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Vérifier la limite quotidienne
    final hasSupported = await _hasSupportedToday(widget.post.id!, currentUserId!);
    if (hasSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vous avez déjà soutenu ce post aujourd\'hui. Revenez demain !'),
          backgroundColor: Colors.orange,
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
        backgroundColor: _twitterCardBg,
        title: Row(
          children: [
            Icon(Icons.volunteer_activism, color: _twitterYellow),
            SizedBox(width: 8),
            Text('Soutenir le créateur', style: TextStyle(color: _twitterTextPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'En regardant cette publicité, vous offrez pièces au créateur de ce post.',
              style: TextStyle(color: _twitterTextSecondary),
            ),
            SizedBox(height: 12),
            Text(
              'Cela l’encourage à produire plus de contenu et peut lui rapporter jusqu’à 100€ (environ 65 000 FCFA) par mois !',
              style: TextStyle(color: _twitterTextPrimary),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.monetization_on, color: _twitterYellow),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '💰 Les pièces récoltées peuvent être converties en argent réel.',
                      style: TextStyle(color: _twitterTextPrimary, fontSize: 12),
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
            child: Text('Plus tard', style: TextStyle(color: _twitterTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _markSupportModalSeen();
              _startSupportAd();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _twitterYellow),
            child: Text('Regarder la pub', style: TextStyle(color: Colors.black)),
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
        backgroundColor: Colors.green,
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
    print('🔍 _loadSuggestionsModalPreference - userId: $userId');
    if (userId == null) {
      print('⚠️ userId est null, impossible de charger la préférence');
      return;
    }
    final key = 'has_seen_suggestions_modal_video_$userId';
    _hasSeenSuggestionsModal = _prefs.getBool(key) ?? false;
    print('📖 Clé lue: $key, valeur: $_hasSeenSuggestionsModal');
    setState(() {});
  }

  Future<void> _markSuggestionsModalSeen() async {
    final userId = authProvider.loginUserData?.id;
    print('🔍 _markSuggestionsModalSeen - userId: $userId');
    if (userId == null) {
      print('⚠️ userId est null, impossible de sauvegarder');
      return;
    }
    final key = 'has_seen_suggestions_modal_video_$userId';
    await _prefs.setBool(key, true);
    print('💾 Clé sauvegardée: $key = true');
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
        backgroundColor: _afroDarkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lightbulb, color: _afroYellow),
            SizedBox(width: 8),
            Text(
              'Découvrez d’autres posts',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,fontSize: 13),
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
                style: TextStyle(color: _twitterTextSecondary),
              ),
              SizedBox(height: 16),
              Text(
                'Suggestions pour vous :',
                style: TextStyle(color: _afroYellow, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (int i = 0; i < suggestions.length; i++)
                        Column(
                          children: [
                            if (i == 3) // 4ème élément (index 3)
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
            child: Text('Fermer', style: TextStyle(color: _twitterTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markSuggestionsModalSeen();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _afroGreen),
            child: Text('J’ai compris', style: TextStyle(color: Colors.white)),
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
                  color: Colors.grey[800],
                  child: post.dataType == PostDataType.VIDEO.name && post.thumbnail != null
                      ? CachedNetworkImage(imageUrl: post.thumbnail!, fit: BoxFit.cover)
                      : (post.images != null && post.images!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: post.images!.first, fit: BoxFit.cover)
                      : Icon(Icons.videocam, color: Colors.grey)),
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
                  style: TextStyle(color: Colors.white),
                ),
                Row(
                  children: [
                    Icon(Icons.remove_red_eye, size: 12, color: _twitterTextSecondary),
                    SizedBox(width: 2),
                    Text(
                      _formatCount(post.totalInteractions ?? 0),
                      style: TextStyle(color: _twitterTextSecondary, fontSize: 12),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.favorite, size: 12, color: _twitterRed),
                    SizedBox(width: 2),
                    Text(
                      _formatCount(post.loves ?? 0),
                      style: TextStyle(color: _twitterTextSecondary, fontSize: 12),
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
          print('✅ Native Ad Afrolook chargée: $key');
        },
      ),
      // child: BannerAdWidget(
      //   onAdLoaded: () {
      //
      //     print('✅ Bannière Afrolook chargée: $key');


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
      print('Erreur chargement publicité: $e');
    } finally {
      setState(() => _isLoadingAd = false);
    }
  }

// 4. Ajouter ce widget dans la partie supérieure de la page (après l'en-tête) :

  Widget _buildAdvertisementHeader() {
    if (!_isAd || _advertisement == null) return const SizedBox.shrink();

    final ad = _advertisement!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD600).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD600), width: 1),
      ),
      child: Row(
        // mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Badge SPONSORISÉ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD600),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                const Icon(Icons.verified, color: Colors.black, size: 14),
                const SizedBox(width: 4),
                const Text(
                  'SPONSORISÉ',
                  style: TextStyle(
                    color: Colors.black,
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
      print('Erreur préchargement audio $postId: $e');
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
      print('Erreur lecture audio: $e');
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

        // Préparer les mises à jour
        Map<String, dynamic> updates = {
          'clicks': FieldValue.increment(1),
          'updatedAt': DateTime.now().microsecondsSinceEpoch,
        };

        // Mettre à jour dailyStats
        if (currentAd.dailyStats != null) {
          updates['dailyStats.$today.clicks'] = FieldValue.increment(1);
        }

        // Vérifier si c'est un clic unique
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

      print('✅ Clic enregistré pour la pub: ${ad.id}');
    } catch (e) {
      print('❌ Erreur lors de l\'enregistrement du clic: $e');
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
              ? Border.all(color: _twitterGreen.withOpacity(0.5), width: 2)
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
                    image: CachedNetworkImageProvider(coverImage),
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
                        Icon(Icons.lock, color: _twitterYellow, size: 60),
                        SizedBox(height: 20),
                        Text(
                          'Audio verrouillé',
                          style: TextStyle(
                            color: _twitterYellow,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Abonnez-vous au canal pour écouter',
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
                              color: Colors.blue.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
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
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.4),
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
                                    activeColor: Colors.blue,
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
                                  ? Colors.blue
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
                          '👆 Cliquez sur l\'image pour l\'agrandir',
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
        backgroundColor: Colors.red,
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
    authProvider. incrementPostTotalInteractions(postId: widget.post.id!);
    _startSuggestionModalTimer();
    if (widget.post!=null&&widget.post.type == PostType.PRONOSTIC.name) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PronosticDetailPage(postId: widget.post.id!),));
    }
    _loadSupportModalSeen();
    _isAd = widget.post.isAdvertisement == true;
    if (_isAd && widget.post.advertisementId != null) {
      _loadAdvertisement();
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
  Widget _buildSupportButton() {
    final hasAccess = _hasAccessToContent();
    final isOwner = authProvider.loginUserData.id == widget.post.user_id;
    final count = widget.post.adSupportCount ?? 0;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: hasAccess && !_isSupporting && !isOwner ? _handleSupportAd : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _twitterCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _twitterYellow.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSupporting)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _twitterYellow),
                )
              else
                Icon(Icons.volunteer_activism, color: _twitterYellow, size: 18),
              SizedBox(width: 6),
              Text(
                'Soutenir le créateur',
                style: TextStyle(
                  color: _twitterTextPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (count > 0) ...[
                SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _twitterYellow.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: _twitterYellow,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: _isFavorite ? _twitterGreen : Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Erreur toggle favori: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Erreur lors de la modification',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
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
      print('Erreur création notification favori: $e');
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
      print('Erreur lors de la vérification du vote: $e');
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
        print('⏭️ Vue déjà enregistrée pour cet utilisateur');
        return;
      }

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

      print('✅ Vue unique enregistrée pour ${widget.post.id}');
    } catch (e) {
      print("Erreur incrémentation vues: $e");
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
          print(
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

      print('✅ Vue enregistrée pour ${widget.post.id}');
    } catch (e) {
      print("Erreur incrémentation vues: $e");
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
      print('Erreur chargement challenge: $e');
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
            backgroundColor: Colors.grey[900],
            title: Text('Confirmer votre vote',
                style: TextStyle(color: Colors.white)),
            content: Text(
              !_challenge!.voteGratuit!
                  ? 'Êtes-vous sûr de vouloir voter pour ce look ?\n\nCe vote vous coûtera ${_challenge!.prixVote} FCFA.'
                  : 'Voulez-vous vraiment voter pour ce look ?\n\nVotre vote est gratuit et ne peut être changé.',
              style: TextStyle(color: Colors.grey[300]),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _isVoting = false;
                  });
                },
                child: Text('ANNULER', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _processVoteWithChallenge(user.uid);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('CONFIRMER MON VOTE',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        // Vote normal (sans challenge)
        await _processVoteNormal(user.uid);
      }
    } catch (e) {
      print("Erreur lors de la préparation du vote: $e");
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
        print('Challenge non trouvé: ${widget.post.challenge_id}');
        if (mounted) {
          setState(() {
            _challenge = null;
          });
        }
      }
    } catch (e) {
      print('Erreur rechargement challenge: $e');
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
      print("Vérification appareil pour vote: $deviceId");

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
      print("Erreur lors du vote avec challenge: $e");

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
      print("Erreur lors du vote avec challenge: $e");
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
      print("Erreur lors du vote normal: $e");
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
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showSoldeInsuffisant(int montantManquant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            Text('SOLDE INSUFFISANT', style: TextStyle(color: Colors.yellow)),
        content: Text(
          'Il vous manque $montantManquant FCFA pour pouvoir voter.\n\n'
          'Rechargez votre compte pour soutenir votre look préféré !',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('PLUS TARD', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => DepositScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('RECHARGER MAINTENANT',
                style: TextStyle(color: Colors.white)),
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
            backgroundColor: _twitterCardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _twitterGreen, width: 2),
            ),
            title: Text(
              '🎉 Voter pour ce Look',
              style: TextStyle(
                color: _twitterGreen,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              'Ce vote vous coûtera ${_challenge!.prixVote} FCFA.\n\n'
              'Voulez-vous continuer ?',
              style: TextStyle(color: _twitterTextPrimary),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler',
                    style: TextStyle(color: _twitterTextSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _voteForLook();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _twitterGreen,
                ),
                child: Text('Voter ${_challenge!.prixVote} FCFA',
                    style: TextStyle(color: Colors.white)),
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
            backgroundColor: _twitterCardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _twitterGreen, width: 2),
            ),
            title: Text(
              '🎉 Voter pour ce Look',
              style: TextStyle(
                color: _twitterGreen,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              'Vous allez voter pour ce look${_isLookChallenge ? ' challenge' : ''}. Cette action est irréversible${_isLookChallenge && _challenge != null ? ' et vous rapportera 3 points' : ''}!',
              style: TextStyle(color: _twitterTextPrimary),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler',
                    style: TextStyle(color: _twitterTextSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _voteForLook();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _twitterGreen,
                ),
                child: Text('Voter', style: TextStyle(color: Colors.white)),
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
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Erreur like: $e");

      // Message d'erreur spécifique
      String errorMessage = "Erreur lors du like";
      if (e.toString().contains("déjà liké")) {
        errorMessage = "Vous avez déjà liké ce post";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
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
              style: TextStyle(color: Colors.green),
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
      if (!isIn(widget.post.users_love_id!, authProvider.loginUserData.id!)) {
        setState(() {
          widget.post.loves = widget.post.loves! + 1;
          widget.post.users_love_id!.add(authProvider.loginUserData.id!);
        });

        await firestore.collection('Posts').doc(widget.post.id).update({
          'loves': FieldValue.increment(1),
          'users_love_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(3),
        });

        FeedInteractionService.onPostLoved(widget.post, authProvider.loginUserData.id!);

        // ✅ TIMESTAMP ACTUEL EN MICROSECONDES
        final currentTimeMicroseconds = DateTime.now().microsecondsSinceEpoch;

        // ✅ RÉCUPÉRER L'UTILISATEUR CIBLE (propriétaire du post)
        final userDoc = await firestore.collection('Users').doc(widget.post.user_id!).get();

        if (userDoc.exists) {
          final userData = userDoc.data();

          // ✅ Récupérer le dernier timestamp de notification
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
              description: "@${authProvider.loginUserData.pseudo!} a aimé votre ${_isLookChallenge ? 'look' : 'post'}",
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
            print("✅ Notification Firebase enregistrée pour @${widget.post.user!.pseudo}");

            // =====================================================
            // ✅ 2. ENVOYER LA PUSH NOTIFICATION (OneSignal)
            // =====================================================
            if (widget.post.user!.oneIgnalUserid != null && widget.post.user!.oneIgnalUserid!.isNotEmpty) {
              await authProvider.sendNotification(
                userIds: [widget.post.user!.oneIgnalUserid!],
                smallImage: authProvider.loginUserData.imageUrl!,
                send_user_id: authProvider.loginUserData.id!,
                recever_user_id: widget.post.user_id!,
                message: "📢 @${authProvider.loginUserData.pseudo!} a aimé votre ${_isLookChallenge ? 'look' : 'post'}",
                type_notif: NotificationType.POST.name,
                post_id: widget.post.id!,
                post_type: widget.post.dataType ?? PostDataType.IMAGE.name,
                chat_id: '',
              );
              print("✅ Push notification envoyée à @${widget.post.user!.pseudo}");
            }

            // =====================================================
            // ✅ 3. METTRE À JOUR LE TIMESTAMP (un seul champ)
            // =====================================================
            await firestore.collection('Users').doc(widget.post.user_id!).update({
              'lastNotificationTime': currentTimeMicroseconds
            });

          }
          else {
            // ⏱️ LIMITE ATTEINTE - NI NOTIFICATION NI PUSH
            final minutesPassed = (timeSinceLastNotification / (60 * 1000 * 1000)).toStringAsFixed(1);
            final minutesRemaining = ((twentyMinutesMicroseconds - timeSinceLastNotification) / (60 * 1000 * 1000)).toStringAsFixed(1);

            print("⏱️ Notification limitée pour @${widget.post.user!.pseudo} - Dernière notification il y a $minutesPassed minutes");
            print("⏱️ Prochaine notification possible dans $minutesRemaining minutes");
          }
          await authProvider. incrementPostTotalInteractions(postId: widget.post.id!);

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

        // ✅ ACTIONS STANDARD (points, animation, etc.)
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
              style: TextStyle(color: Colors.green),
            ),
          ),
        );
      }
    } catch (e) {
      print("❌ Erreur like: $e");
    }
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
      print("Erreur création transaction: $e");
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
            backgroundColor: Colors.green,
            content: Text(
              '🎁 Cadeau de ${amount.toInt()} FCFA envoyé avec succès!',
              style: TextStyle(color: Colors.white),
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
      print("Erreur envoi cadeau: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Erreur lors de l\'envoi du cadeau',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showGiftDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final height = MediaQuery.of(context).size.height * 0.6;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.yellow, width: 2),
              ),
              child: Container(
                height: height,
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Envoyer un Cadeau',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Choisissez le montant en FCFA',
                      style: TextStyle(color: Colors.white),
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
                                    ? Colors.green
                                    : Colors.grey[800],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedGiftIndex == index
                                      ? Colors.yellow
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
                                      color: Colors.white,
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
                        color: Colors.yellow,
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
                              style: TextStyle(color: Colors.white)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _sendGift(giftPrices[_selectedGiftIndex]);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Envoyer',
                            style: TextStyle(color: Colors.black),
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
            backgroundColor: Colors.green,
            content: Text(
              '🔝 Post republié pour $_selectedRepostPrice FCFA!',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      } else {
        _showInsufficientBalanceDialog();
      }
    } catch (e) {
      print("Erreur republication: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Erreur lors de la republication',
            style: TextStyle(color: Colors.white),
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
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.yellow, width: 2),
          ),
          title: Text(
            'Solde Insuffisant',
            style: TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Votre solde est insuffisant pour effectuer cette action. Veuillez recharger votre compte.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => DepositScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Recharger', style: TextStyle(color: Colors.black)),
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
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.yellow, width: 2),
          ),
          title: Text(
            'Republier le Post',
            style: TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Republier ce post le mettra en avant dans le fil d\'actualité. Coût: 25 FCFA.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _repostForCash();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Republier', style: TextStyle(color: Colors.black)),
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
                  canal?.urlImage ?? user?.imageUrl ?? '',
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
                      color: _twitterDarkBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified, color: Colors.blue, size: 14),
                  ),
                ),
              if (_isLookChallenge)
                Positioned(
                  top: -2,
                  left: -2,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _twitterGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: Colors.white,
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
                      color: _twitterYellow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock,
                      color: Colors.black,
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
                        '#${canal.titre ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 4),
                      if (canal.isVerify ?? false)
                        Icon(Icons.verified, color: _twitterBlue, size: 16),
                      if (isLocked)
                        Icon(Icons.lock, color: _twitterYellow, size: 16),
                    ],
                  ),
                  Text(
                    '${canal.usersSuiviId!.length ?? 0} abonnés',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ] else if (user != null) ...[
                  Row(
                    children: [
                      Text(
                        '@${user.pseudo ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 4),
                      AbonnementUtils.getUserBadge(
                          abonnement: user.abonnement,
                          isVerified: user.isVerify!),
                      // if (user.isVerify ?? false)
                      //   Icon(Icons.verified, color: _twitterBlue, size: 16),

                      // Dans _buildUserHeader, après AbonnementUtils.getUserBadge()
                      if (post.dataType == PostDataType.AUDIO.name)
                        Container(
                          margin: EdgeInsets.only(left: 4),
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border:
                                Border.all(color: Colors.blue.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.audiotrack,
                                  color: Colors.blue, size: 10),
                              SizedBox(width: 2),
                              Text(
                                'AUDIO',
                                style: TextStyle(
                                  color: Colors.blue,
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
                            color: _twitterGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _twitterGreen),
                          ),
                          child: Text(
                            'LOOK',
                            style: TextStyle(
                              color: _twitterGreen,
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
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    formaterDateTime(
                      DateTime.fromMicrosecondsSinceEpoch(post.createdAt ?? 0),
                    ),
                    style: TextStyle(
                      color: Colors.grey[400],
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
              color: Colors.white,
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
      backgroundColor: _twitterCardBg,
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
                _twitterTextPrimary,
                () async {
                  post.status = PostStatus.SIGNALER.name;
                  final value = await postProvider.updateVuePost(post, context);
                  Navigator.pop(context);

                  final snackBar = SnackBar(
                    content: Text(
                      value ? 'Post signalé !' : 'Échec du signalement !',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: value ? Colors.green : Colors.red),
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
                Colors.red,
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
                      style: TextStyle(color: Colors.green),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
              ),
            SizedBox(height: 8),
            Container(
                height: 0.5, color: _twitterTextSecondary.withOpacity(0.3)),
            SizedBox(height: 8),
            _buildMenuOption(Icons.cancel, "Annuler", _twitterTextSecondary,
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
    final text = post.description ?? "";

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
                      color: _twitterYellow.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _twitterYellow),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: _twitterYellow, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Contenu réservé aux abonnés du canal',
                            style: TextStyle(
                              color: _twitterYellow,
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
        Linkify(
          onOpen: (link) async {
            if (!await launchUrl(Uri.parse(link.url))) {
              throw Exception('Could not launch ${link.url}');
            }
          },
          text: displayedText,
          style: TextStyle(
            color: isLocked ? _twitterTextSecondary : _twitterTextPrimary,
            fontSize: 14,
            height: 1.4,
          ),
          linkStyle: TextStyle(
            color: _twitterBlue,
            fontWeight: FontWeight.w500,
          ),
          options: LinkifyOptions(humanize: false),
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
                      color: _twitterBlue,
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
        color: _twitterCardBg,
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: _twitterTextSecondary.withOpacity(0.1),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, color: _twitterYellow, size: 50),
                  SizedBox(height: 16),
                  Text(
                    'Contenu verrouillé',
                    style: TextStyle(
                      color: _twitterYellow,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Abonnez-vous au canal pour voir ce contenu',
                    style: TextStyle(
                      color: _twitterTextSecondary,
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
            ? Border.all(color: _twitterGreen.withOpacity(0.3))
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: ImageSlideshow(
          initialPage: 0,
          indicatorColor: _isLookChallenge ? _twitterGreen : Colors.yellow,
          indicatorBackgroundColor: Colors.grey,
          onPageChanged: (value) {
            print('Page changed: $value');
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
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: Colors.yellow)),
                        ),
                        errorWidget: (context, url, error) =>
                            Icon(Icons.error, color: Colors.red),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // 🔥 Remplacer la méthode _buildMediaContent existante par cette nouvelle version
  Widget _buildMediaContent(Post post) {
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
            ? Border.all(color: _twitterGreen.withOpacity(0.3))
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: _buildImageGallery(images, contentHeight),
      ),
    );
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
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: height,
            placeholder: (context, url) => Container(
              color: Colors.grey[800],
              child: Center(
                child: CircularProgressIndicator(color: Colors.yellow),
              ),
            ),
            errorWidget: (context, url, error) =>
                Icon(Icons.error, color: Colors.red, size: 50),
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
                  imageUrl: images[0],
                  fit: BoxFit.cover,
                  height: height,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: Icon(Icons.error, color: Colors.red),
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
                  imageUrl: images[1],
                  fit: BoxFit.cover,
                  height: height,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: Icon(Icons.error, color: Colors.red),
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
                  imageUrl: images[0],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: Icon(Icons.error, color: Colors.red),
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
                        imageUrl: images[1],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: Icon(Icons.error, color: Colors.red),
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
                        imageUrl: images[2],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: Icon(Icons.error, color: Colors.red),
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
      indicatorColor: _isLookChallenge ? _twitterGreen : Colors.yellow,
      indicatorBackgroundColor: Colors.grey,
      onPageChanged: (value) {
        print('Page changed: $value');
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
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[800],
                      child: Center(
                          child:
                              CircularProgressIndicator(color: Colors.yellow)),
                    ),
                    errorWidget: (context, url, error) =>
                        Icon(Icons.error, color: Colors.red),
                  ),
                ),
              ))
          .toList(),
    );
  }

// 🔥 MÉTHODE POUR AFFICHER L'IMAGE PLEIN ÉCRAN
  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImage(singleImageUrl: imageUrl),
      ),
    );
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
              color: _twitterCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _twitterGreen.withOpacity(0.3)),
            ),
            child: Center(
              child: CircularProgressIndicator(color: _twitterGreen),
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
                color: _twitterCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _twitterGreen.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_events, color: _twitterGreen, size: 24),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LOOK CHALLENGE',
                              style: TextStyle(
                                color: _twitterGreen,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (challenge.titre != null &&
                                challenge.titre!.isNotEmpty)
                              Text(
                                challenge.titre!,
                                style: TextStyle(
                                  color: Colors.white,
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
                        color: _twitterGreen,
                      ),
                      _buildChallengeStatItem(
                        icon: Icons.people,
                        value: '${challenge.usersInscritsIds!.length ?? 0}',
                        label: 'Participants',
                        color: _twitterBlue,
                      ),
                      _buildChallengeStatItem(
                        icon: Icons.favorite,
                        value: '${post.loves ?? 0}',
                        label: 'Likes',
                        color: _twitterRed,
                      ),
                      _buildChallengeStatItem(
                        icon: Icons.trending_up,
                        value: '${post.popularity ?? 0}',
                        label: 'Popularité',
                        color: _twitterYellow,
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (challenge.description != null &&
                      challenge.description!.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📝 À propos du challenge',
                            style: TextStyle(
                              color: _twitterGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            challenge.description!,
                            style: TextStyle(
                              color: _twitterTextSecondary,
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
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '🎯 VOTER POUR CE LOOK',
                                style: TextStyle(
                                  color: _twitterGreen,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Votre vote aide ce participant à gagner le challenge !',
                                style: TextStyle(
                                  color: _twitterTextSecondary,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (!challenge.voteGratuit!)
                                Text(
                                  'Coût du vote: ${challenge.prixVote} FCFA',
                                  style: TextStyle(
                                    color: _twitterYellow,
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
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '⏰ CE CHALLENGE EST TERMINÉ',
                            style: TextStyle(
                              color: Colors.red,
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
                                  backgroundColor: _twitterGreen,
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
                                          color: Colors.white,
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
                                  color: _twitterGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _twitterGreen),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: _twitterGreen, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      _hasVoted
                                          ? 'DÉJÀ VOTÉ'
                                          : 'NON DISPONIBLE',
                                      style: TextStyle(
                                        color: _twitterGreen,
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
                              backgroundColor: _twitterBlue,
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
                        color: _twitterTextPrimary,
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
                                        backgroundImage: NetworkImage(
                                            userData.imageUrl ?? ''),
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
        border: Border.all(color: _twitterGreen.withOpacity(0.5)),
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
                      color: _twitterTextSecondary.withOpacity(0.1),
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
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          challenge.titre ?? 'Challenge',
                          style: TextStyle(
                            color: _twitterTextSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap pour voir →',
                          style: TextStyle(
                            color: _twitterGreen,
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
            color: _twitterTextSecondary.withOpacity(0.2),
            child: Icon(Icons.photo, color: _twitterTextSecondary, size: 20),
          ),
          errorWidget: (context, url, error) =>
              Icon(Icons.error, color: Colors.red, size: 20),
        ),
      );
    } else {
      return Container(
        color: _twitterTextSecondary.withOpacity(0.2),
        child: Icon(Icons.article, color: _twitterTextSecondary, size: 20),
      );
    }
  }

  Widget _buildBasicChallengeSection(Post post) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 15),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _twitterCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _twitterGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: _twitterGreen, size: 24),
              SizedBox(width: 8),
              Text(
                'LOOK CHALLENGE',
                style: TextStyle(
                  color: _twitterGreen,
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
                color: _twitterGreen,
              ),
              _buildChallengeStatItem(
                icon: Icons.bar_chart,
                value: '${post.totalInteractions ?? 0}',
                label: 'Interactions',
                color: Colors.blue,
              ),
              _buildChallengeStatItem(
                icon: Icons.favorite,
                value: '${post.loves ?? 0}',
                label: 'Likes',
                color: _twitterRed,
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
                  backgroundColor: _twitterGreen,
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
                          color: Colors.white,
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
                color: _twitterGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _twitterGreen),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: _twitterGreen, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Vous avez déjà voté pour ce look',
                    style: TextStyle(
                      color: _twitterGreen,
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
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _twitterTextSecondary,
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
              style: TextStyle(color: Colors.green),
            ),
          ),
        );
      }
      await authProvider. incrementPostTotalInteractions(postId: widget.post.id!);

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
      print("Erreur partage: $e");
    } finally {
      // Désactiver le chargement même en cas d'erreur
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
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
          onTap: hasAccess ? _handleLike : null,
          child: _buildStatItem(
            icon: Icons.favorite,
            count: post.loves ?? 0,
            label: 'Likes',
            isLiked: isIn(post.users_love_id!, authProvider.loginUserData.id!),
            isLocked: !hasAccess,
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
        GestureDetector(
          onTap: hasAccess ? _showGiftDialog : null,
          child: _buildStatItem(
            icon: Icons.card_giftcard,
            count: post.users_cadeau_id?.length ?? 0,
            label: 'Cadeaux',
            isLocked: !hasAccess,
          ),
        ),
        _isSharing
            ? const SizedBox(
          width: 40, // Ajustez selon la taille de vos boutons
          height: 40,
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber), // ou votre couleur _afroTextSecondary
          ),
        )
            :GestureDetector(
          onTap: hasAccess
              ? () async {
            _handleShare();

                }
              : null,
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
          ? _twitterTextSecondary.withOpacity(0.3)
          : (isLiked ? _twitterYellow : Colors.yellow);
    } else if (icon == Icons.favorite || icon == Icons.favorite_border) {
      iconColor = isLocked
          ? _twitterTextSecondary.withOpacity(0.3)
          : (isLiked ? Colors.red : Colors.yellow);
    } else {
      iconColor =
          isLocked ? _twitterTextSecondary.withOpacity(0.3) : Colors.yellow;
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
                ? _twitterTextSecondary.withOpacity(0.3)
                : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isLocked
                ? _twitterTextSecondary.withOpacity(0.3)
                : Colors.grey[400],
            fontSize: 10,
          ),
        ),
      ],
    );
  }


  Widget _buildActionButtons(Post post) {
    final hasAccess = _hasAccessToContent();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 15),
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Bouton Like
          ScaleTransition(
            scale: _scaleAnimation,
            child: IconButton(
              icon: Icon(
                isIn(post.users_love_id!, authProvider.loginUserData.id!)
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: !hasAccess
                    ? _twitterTextSecondary.withOpacity(0.3)
                    : (isIn(post.users_love_id!, authProvider.loginUserData.id!)
                        ? Colors.red
                        : Colors.white),
                size: 30,
              ),
              onPressed: hasAccess ? _handleLike : null,
            ),
          ),

          // Bouton Commentaire
          IconButton(
            icon: Icon(Icons.chat_bubble_outline,
                color: !hasAccess
                    ? _twitterTextSecondary.withOpacity(0.3)
                    : Colors.white,
                size: 30),
            onPressed: hasAccess
                ? () async {
                    await firestore
                        .collection('Posts')
                        .doc(widget.post.id)
                        .update({
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
          ),

          // Bouton Favoris (NOUVEAU)
          IconButton(
            icon: Icon(_isFavorite ? Icons.bookmark : Icons.bookmark_border,
                color: !hasAccess
                    ? _twitterTextSecondary.withOpacity(0.3)
                    : (_isFavorite ? _twitterYellow : Colors.white),
                size: 30),
            onPressed:
                hasAccess && !_isProcessingFavorite ? _toggleFavorite : null,
          ),

          // Bouton Cadeau
          IconButton(
            icon: Icon(Icons.card_giftcard,
                color: !hasAccess
                    ? _twitterTextSecondary.withOpacity(0.3)
                    : Colors.yellow,
                size: 30),
            onPressed: hasAccess ? _showGiftDialog : null,
          ),

          // Bouton Republier
          IconButton(
            icon: Icon(Icons.repeat,
                color: !hasAccess
                    ? _twitterTextSecondary.withOpacity(0.3)
                    : Colors.green,
                size: 30),
            onPressed: hasAccess ? _showRepostDialog : null,
          ),

          // Bouton Partager
          _isSharing
              ? const SizedBox(
            width: 40, // Ajustez selon la taille de vos boutons
            height: 40,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber), // ou votre couleur _afroTextSecondary
            ),
          )
              :IconButton(
            icon: Icon(Icons.share,
                color: !hasAccess
                    ? _twitterTextSecondary.withOpacity(0.3)
                    : Colors.white,
                size: 30),
            onPressed: hasAccess
                ? () async {
              _handleShare();

                  }
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _isLockedContent();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.yellow),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isLookChallenge ? 'Look Challenge' : 'Post',
          style: TextStyle(
              color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Text(
            'Afrolook',
            style: TextStyle(
                color: Colors.green, fontWeight: FontWeight.bold, fontSize: 20),
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
                    style: TextStyle(color: Colors.white)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: Colors.yellow));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
                child: Text('Post non trouvé',
                    style: TextStyle(color: Colors.white)));
          }

          final updatedPost =
              Post.fromJson(snapshot.data!.data() as Map<String, dynamic>);
          updatedPost.user = widget.post.user;
          updatedPost.canal = widget.post.canal;
          if (_isLoadingAd) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Color(0xFFFFD600)),
              ),
            );
          }
          return _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.yellow))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserHeader(updatedPost),
                      SizedBox(height: 5),

                      _buildAdvertisementHeader(),
                      _buildPostContent(updatedPost),

                      if (_isLookChallenge)
                        _buildLookChallengeSection(updatedPost),

                      // Bouton d'abonnement si contenu verrouillé
                      if (isLocked) _buildSubscribeButton(),

                      SizedBox(height: 20),
                      Divider(color: Colors.grey[700]),
                      _buildStatsRow(updatedPost),
                      Divider(color: Colors.grey[700]),
                      _buildActionButtons(updatedPost),
                      _buildAdMrec(key: 'ad_details_post'),
                      // Section des cadeaux récents
                      if (updatedPost.users_cadeau_id != null &&
                          updatedPost.users_cadeau_id!.isNotEmpty &&
                          _hasAccessToContent())
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Derniers cadeaux',
                                style: TextStyle(
                                  color: Colors.yellow,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 10),
                              Container(
                                height: 60,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount:
                                      updatedPost.users_cadeau_id!.length,
                                  itemBuilder: (context, index) {
                                    return FutureBuilder<DocumentSnapshot>(
                                      future: firestore
                                          .collection('Users')
                                          .doc(updatedPost
                                              .users_cadeau_id![index])
                                          .get(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData &&
                                            snapshot.data!.exists) {
                                          var userData = UserData.fromJson(
                                              snapshot.data!.data()
                                                  as Map<String, dynamic>);
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                right: 10),
                                            child: Column(
                                              children: [
                                                CircleAvatar(
                                                  backgroundImage: NetworkImage(
                                                      userData.imageUrl ?? ''),
                                                  radius: 15,
                                                ),
                                                SizedBox(height: 2),
                                                Text('🎁',
                                                    style:
                                                        TextStyle(fontSize: 8)),
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
                          ),
                        ),

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
          backgroundColor: _twitterYellow,
          foregroundColor: Colors.black,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                        imageUrl: images[index],
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Center(
                          child:
                              CircularProgressIndicator(color: Colors.yellow),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(
                            Icons.error,
                            color: Colors.red,
                            size: 60,
                          ),
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
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Indicateur de position (si plus d'une image)
          if (images.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1}/${images.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

          // Boutons de navigation (si plus d'une image)
          if (images.length > 1) ...[
            // Bouton précédent
            if (_currentIndex > 0)
              Positioned(
                left: 16,
                top: MediaQuery.of(context).size.height / 2 - 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon:
                        Icon(Icons.chevron_left, color: Colors.white, size: 36),
                    onPressed: () {
                      _pageController.previousPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),

            // Bouton suivant
            if (_currentIndex < images.length - 1)
              Positioned(
                right: 16,
                top: MediaQuery.of(context).size.height / 2 - 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.chevron_right,
                        color: Colors.white, size: 36),
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
