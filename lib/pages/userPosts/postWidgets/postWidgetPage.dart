import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import 'package:afrotok/pages/user/monetisation.dart';
import 'package:afrotok/pages/userPosts/postColorsWidget.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postCadeau.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postUserWidget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:hashtagable_v3/widgets/hashtag_text.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../models/model_data.dart';
import '../../../constant/constColors.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../../services/linkService.dart';
import '../../home/homeWidget.dart';
import '../../paiement/newDepot.dart';
import '../../postComments.dart';
import '../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../canaux/detailsCanal.dart';
import '../../canaux/listCanal.dart';
import '../../component/consoleWidget.dart';
import '../../component/showUserDetails.dart';
import '../../postComments.dart';
import '../../postDetails.dart';
import '../../postDetailsVideoListe.dart';
import '../../socialVideos/afrovideos/afrovideo.dart';
import '../../user/detailsOtherUser.dart';

// Couleurs style Twitter Dark Mode
const _twitterDarkBg = Color(0xFF000000);
const _twitterCardBg = Color(0xFF16181C);
const _twitterTextPrimary = Color(0xFFFFFFFF);
const _twitterTextSecondary = Color(0xFF71767B);
const _twitterBlue = Color(0xFF1D9BF0);
const _twitterRed = Color(0xFFF91880);
const _twitterGreen = Color(0xFF00BA7C);
const _twitterYellow = Color(0xFFFFD400);
const _afroBlack = Color(0xFF000000);


// Couleurs style AfroTok
const _afroDarkBg = Color(0xFF000000);
const _afroCardBg = Color(0xFF1A1A1A);
const _afroTextPrimary = Color(0xFFFFFFFF);
const _afroTextSecondary = Color(0xFF71767B);
const _afroGreen = Color(0xFF2E7D32);
const _afroYellow = Color(0xFFFFD600);
const _afroRed = Color(0xFFF91880);
const _afroBlue = Color(0xFF1D9BF0);

class HomePostUsersWidget extends StatefulWidget {
  late Post post;
  late Color? color;
  final double height;
  final double width;
  final bool isDegrade;
  bool isPreview;
  final Function(Post, VisibilityInfo)? onVisibilityChanged;

  HomePostUsersWidget({
    required this.post,
    this.color,
    this.isDegrade = false,
    required this.height,
    required this.width,
    Key? key,
    this.isPreview = true,
    this.onVisibilityChanged,
  }) : super(key: key);

  @override
  _HomePostUsersWidgetState createState() => _HomePostUsersWidgetState();
}

class _HomePostUsersWidgetState extends State<HomePostUsersWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _isExpanded = false;

  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  late UserProvider userProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Random random = Random();
  bool _isLoading = false;
  bool _isProcessingFollow = false;

  // Variables pour stocker les données récupérées individuellement
  UserData? _currentUser;
  Canal? _currentCanal;
  bool _isLoadingUser = false;
  bool _isLoadingCanal = false;

  // Variables pour la thumbnail vidéo
  String? _videoThumbnailPath;
  bool _isGeneratingThumbnail = false;

  // CONFIGURATION - Paiement pour abonnés existants
  final bool _requirePaymentForExistingSubscribers = false;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);

    _loadUserData();
    _loadCanalData();
    _generateVideoThumbnail();
  }

  @override
  void dispose() {
    super.dispose();
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
      // - Le canal n’est pas privé
      // - OU l’utilisateur est abonné
      // - OU c’est un admin
      if (!isPrivate || isSubscribed || isAdmin|| isCurrentUser) {
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
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    if (_isLoadingUser || _isLoadingCanal) {
      return _buildSkeletonLoader();
    }

    final isLocked = _isLockedContent();
    // final isLocked = false;
    final hasAccess = _hasAccessToContent();

    return Container(
      color: _afroDarkBg,
      child: Column(
        children: [
          // Ligne de séparation supérieure
          Container(
            height: 0.5,
            color: _afroTextSecondary.withOpacity(0.3),
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
                if (widget.post.images?.isNotEmpty ?? false)
                  _buildMediaContent(h, isLocked),

                if (_isVideoPost(widget.post))
                  _buildVideoContent(h, isLocked),

                // Bouton d'abonnement si contenu verrouillé
                if (isLocked) _buildSubscribeButton(),

                // Actions du post
                SizedBox(height: 12),
                _buildPostActions(hasAccess),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Container(
      color: _afroDarkBg,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: _afroTextSecondary.withOpacity(0.3)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 14, color: _afroTextSecondary.withOpacity(0.3)),
                    SizedBox(height: 4),
                    Container(width: 80, height: 12, color: _afroTextSecondary.withOpacity(0.3)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(width: double.infinity, height: 16, color: _afroTextSecondary.withOpacity(0.3)),
          SizedBox(height: 4),
          Container(width: double.infinity, height: 16, color: _afroTextSecondary.withOpacity(0.3)),
          SizedBox(height: 8),
          Container(
            height: 200,
            width: double.infinity,
            color: _afroTextSecondary.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildPostHeader(double w, double h) {
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
                backgroundColor: _afroGreen,
                backgroundImage: _getProfileImage(),
                child: _getProfileImage() == null
                    ? Icon(
                  isCanalPost ? Icons.group : Icons.person,
                  color: Colors.white,
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
                      color: _afroDarkBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified,
                      color: _afroBlue,
                      size: 14,
                    ),
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
                            color: _afroTextPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(width: 4),
                        if (_isVerified())
                          Icon(Icons.verified, color: _afroBlue, size: 16),
                      ],
                    ),
                  ),

                  // Bouton S'abonner ou menu
                  if (!isCurrentUser && !isAbonne)
                    _buildFollowButton(isCanalPost, postOwner, isAbonne),
                  SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _showPostMenu(widget.post),
                    child: Icon(
                      Icons.more_horiz,
                      color: _afroTextSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                _getFollowerCount(),
                style: TextStyle(
                  color: _afroTextSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton(bool isCanalPost, dynamic postOwner, bool isAbonne) {
    return Container(
      height: 28,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isCanalPost && (postOwner as Canal).isPrivate == true
              ? _afroYellow
              : _afroGreen,
          foregroundColor: isCanalPost && (postOwner as Canal).isPrivate == true
              ? Colors.black
              : Colors.white,
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
                ? Colors.black
                : Colors.white,
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
        video: widget.post.url_media!,
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
              color: _afroTextSecondary, // Texte grisé pour contenu verrouillé
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lock, color: _afroYellow, size: 16),
              SizedBox(width: 4),
              Text(
                'Contenu réservé aux abonnés',
                style: TextStyle(
                  color: _afroYellow,
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
    final words = text.split(' ');
    final isLong = words.length > 50;
    final displayedText = _isExpanded || !isLong
        ? text
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
              color: _afroBlue,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            basicStyle: TextStyle(
              fontSize: 15,
              color: _afroTextPrimary,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            onTap: (text) {
              // Gestion des hashtags
            },
          ),
        ),
        if (isLong)
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _afroBlue,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaContent(double h, bool isLocked) {
    final images = widget.post.images!;

    return Stack(
      children: [
        // Image ou vidéo en arrière-plan
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: images.isNotEmpty
              ? Opacity(
            opacity: isLocked ? 0.15 : 1.0, // réduit la visibilité si verrouillé
            child:         GestureDetector(
              onTap: () {
                if(widget.post.dataType==PostDataType.VIDEO.name){
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoTikTokPageDetails(initialPost: widget.post),
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
              child: CachedNetworkImage(
                imageUrl: images.first,
                fit: BoxFit.cover,
                width: double.infinity,
                height: h * 0.4,
                placeholder: (context, url) =>
                    Container(color: _afroTextSecondary.withOpacity(0.1)),
                errorWidget: (context, url, error) =>
                    Container(color: _afroTextSecondary.withOpacity(0.1)),
              ),
            ),
          )
              : Container(color: _afroTextSecondary.withOpacity(0.1)),
        ),

        // Overlay pour contenu verrouillé
        if (isLocked)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, color: _afroYellow, size: 50),
                    SizedBox(height: 8),
                    Text(
                      'Contenu verrouillé',
                      style: TextStyle(
                        color: _afroYellow,
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
      ],
    );
  }

  Widget _buildVideoContent(double h, bool isLocked) {
    return Stack(
      children: [
        // Thumbnail vidéo ou fallback
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _isGeneratingThumbnail
              ? Center(
            child: CircularProgressIndicator(color: _afroBlue),
          )
              : (_videoThumbnailPath != null &&
              File(_videoThumbnailPath!).existsSync())
              ? GestureDetector(
            onTap: () {
              if(widget.post.dataType==PostDataType.VIDEO.name){
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoTikTokPageDetails(initialPost: widget.post),
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
                    Icon(Icons.lock, color: _afroYellow, size: 50),
                    SizedBox(height: 8),
                    Text(
                      'Vidéo verrouillée',
                      style: TextStyle(
                        color: _afroYellow,
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


  Widget _buildThumbnailContent(double h) {
    if (_isGeneratingThumbnail) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: _afroBlue,
              strokeWidth: 2,
            ),
            SizedBox(height: 8),
            Text(
              'Chargement de la vidéo...',
              style: TextStyle(
                color: _afroTextSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_videoThumbnailPath != null && File(_videoThumbnailPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(_videoThumbnailPath!),
          fit: BoxFit.cover,
          width: double.infinity,
          height: h * 0.4,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackThumbnail();
          },
        ),
      );
    }

    return _buildFallbackThumbnail();
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _afroTextSecondary.withOpacity(0.2),
            _afroTextSecondary.withOpacity(0.1),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam,
              color: _afroTextSecondary.withOpacity(0.7),
              size: 50,
            ),
            SizedBox(height: 8),
            Text(
              'Vidéo',
              style: TextStyle(
                color: _afroTextSecondary.withOpacity(0.7),
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
    final isCanalPost = currentCanal != null;
    final isPrivate = currentCanal?.isPrivate == true;
    final subscriptionPrice = currentCanal?.subscriptionPrice ?? 0;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 12),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _afroYellow,
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
            color: _afroTextSecondary,
            onPressed: hasAccess ? () {
              _showCommentsModal(widget.post);
            } : null,
          ),

          // Vues
          _buildActionButton(
            icon: FontAwesome.eye,
            count: widget.post.vues ?? 0,
            color: _afroGreen,
            onPressed: hasAccess ? () => _handleRepost() : null,
          ),

          // Like
          _buildActionButton(
            icon: isLiked ? FontAwesome.heart : FontAwesome.heart_o,
            count: widget.post.loves ?? 0,
            color: isLiked ? _afroRed : _afroTextSecondary,
            onPressed: hasAccess ? () => _handleLike() : null,
          ),

          // Cadeau
          _buildActionButton(
            icon: FontAwesome.gift,
            count: widget.post.users_cadeau_id?.length ?? 0,
            color: _afroYellow,
            onPressed: hasAccess ? () => _handleGift() : null,
          ),

          // Partager
          _buildActionButton(
            icon: Icons.share,
            count: widget.post.partage ?? 0,
            color: _afroTextSecondary,
            onPressed: hasAccess ? () => _handleShare() : null,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
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
  ImageProvider? _getProfileImage() {
    if (currentCanal != null && currentCanal!.urlImage != null) {
      return NetworkImage(currentCanal!.urlImage!);
    } else if (currentUser != null && currentUser!.imageUrl != null) {
      return NetworkImage(currentUser!.imageUrl!);
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: _afroDarkBg,
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
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
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
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: _afroCardBg,
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
                _afroTextPrimary,
                    () async {
                  post.status = PostStatus.SIGNALER.name;
                  final value = await postProvider.updateVuePost(post, context);
                  Navigator.pop(context);

                  final snackBar = SnackBar(
                    content: Text(
                      value ? 'Post signalé !' : 'Échec du signalement !',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: value ? Colors.green : Colors.red),
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
                      style: TextStyle(color: Colors.green),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
              ),

            SizedBox(height: 8),
            Container(height: 0.5, color: _afroTextSecondary.withOpacity(0.3)),
            SizedBox(height: 8),

            _buildMenuOption(Icons.cancel, "Annuler", _afroTextSecondary, () {
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
          'popularity': FieldValue.increment(1),
        });

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

        addPointsForAction(UserAction.like);
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

  void _handleGift() {
    _showGiftDialog(widget.post);
  }

  void _handleShare() async {
    final AppLinkService _appLinkService = AppLinkService();
    _appLinkService.shareContent(
      type: AppLinkType.post,
      id: widget.post.id!,
      message: widget.post.description ?? "",
      mediaUrl: widget.post.images?.isNotEmpty ?? false ? widget.post.images!.first : "",
    );
    addPointsForAction(UserAction.partagePost);

  }

  // Méthode pour supprimer un post
  Future<void> _deletePost2(Post post, BuildContext context) async {
    try {
      await firestore.collection('Posts').doc(post.id).update({
        'status': PostStatus.SUPPRIMER.name,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Erreur suppression post: $e');
      throw e;
    }
  }


  Future<void> _deletePost(Post post) async {
    final firestore = FirebaseFirestore.instance;
    final appDefaultRef = firestore.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT'); // Remplace par ton docId réel

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
                // Naviguer vers la page de recharge
                Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen()));
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

  Future<void> _sendGift(double amount) async {
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
        final double gainApplication = amount * 0.3;

        // Débiter l’expéditeur
        await firestore.collection('Users').doc(authProvider.loginUserData.id).update({
          'votre_solde_principal': FieldValue.increment(-amount),
        });

        // Créditer le destinataire
        await firestore.collection('Users').doc(widget.post.user!.id).update({
          'votre_solde_principal': FieldValue.increment(gainDestinataire),
        });

        // Créditer l'application
        String appDataId = authProvider.appDefaultData.id!;
        await firestore.collection('AppData').doc(appDataId).update({
          'solde_gain': FieldValue.increment(gainApplication),
        });

        // Ajouter l'expéditeur à la liste des cadeaux du post
        await firestore.collection('Posts').doc(widget.post.id).update({
          'users_cadeau_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(5), // pondération pour un commentaire

        });

        // Créer les transactions
        // Créer les transactions
        await _createTransaction(TypeTransaction.DEPENSE.name, amount, "Cadeau envoyé à @${widget.post.user!.pseudo}",authProvider.loginUserData.id!);
        await _createTransaction(TypeTransaction.GAIN.name, gainDestinataire, "Cadeau reçu de @${authProvider.loginUserData.pseudo}",widget.post.user_id!);
        addPointsForAction(UserAction.cadeau);

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
  void _showGiftDialog(Post post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final height = MediaQuery.of(context).size.height * 0.6; // 60% de l'écran
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
                    // -----------------------------
                    // Expanded pour GridView scrollable
                    Expanded(
                      child: GridView.builder(
                        physics: BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, // 3 colonnes
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
                          child: Text('Annuler', style: TextStyle(color: Colors.white)),
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
        return AlertDialog(
          backgroundColor: _twitterCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "✨ Republier",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _twitterTextPrimary),
            textAlign: TextAlign.center,
          ),
          content: Text(
            "🔝 Cette action mettra votre post en première position.\n\n💰 1 PC sera retiré de votre compte principal.",
            textAlign: TextAlign.center,
            style: TextStyle(color: _twitterTextSecondary, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("❌ Fermer", style: TextStyle(color: _twitterTextSecondary)),
            ),
            TextButton(
              onPressed: () async {
                // Logique existante
              },
              child: Text("🚀 Republier", style: TextStyle(color: _twitterBlue)),
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
  }}

//
// class HomePostUsersWidget extends StatefulWidget {
//   late Post post;
//   late Color? color;
//   final double height;
//   final double width;
//   final bool isDegrade;
//   bool isPreview;
//   final Function(Post, VisibilityInfo)? onVisibilityChanged;
//
//   HomePostUsersWidget({
//     required this.post,
//     this.color,
//     this.isDegrade = false,
//     required this.height,
//     required this.width,
//     Key? key,
//     this.isPreview = true,
//     this.onVisibilityChanged,
//   }) : super(key: key);
//
//   @override
//   _HomePostUsersWidgetState createState() => _HomePostUsersWidgetState();
// }
//
// class _HomePostUsersWidgetState extends State<HomePostUsersWidget>
//     with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
//   @override
//   bool get wantKeepAlive => true;
//   bool _isExpanded = false;
//
//   late UserAuthProvider authProvider =
//   Provider.of<UserAuthProvider>(context, listen: false);
//   late PostProvider postProvider =
//   Provider.of<PostProvider>(context, listen: false);
//   late CategorieProduitProvider categorieProduitProvider =
//   Provider.of<CategorieProduitProvider>(context, listen: false);
//   late UserProvider userProvider =
//   Provider.of<UserProvider>(context, listen: false);
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//
//   Random random = Random();
//   bool abonneTap = false;
//   late int like;
//   int imageIndex = 0;
//   late int love;
//   late int vue;
//   late int comments;
//   late bool tapLove;
//   late bool tapLike;
//   List<int> likes = [];
//   List<int> loves = [];
//   int idUser = 7;
//   double baseFontSize = 20.0;
//   late double fontSize;
//   int limitePosts = 30;
//   bool _isLoading = false;
//
//   // Variables pour stocker les données récupérées individuellement
//   UserData? _currentUser;
//   Canal? _currentCanal;
//   bool _isLoadingUser = false;
//   bool _isLoadingCanal = false;
//
//   final List<AnimationController> _heartAnimations = [];
//   final List<AnimationController> _giftAnimations = [];
//   final List<AnimationController> _giftReplyAnimations = [];
//
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//     _loadCanalData();
//     _generateVideoThumbnail();
//
//   }
//
//   @override
//   void dispose() {
//     for (var controller in _heartAnimations) {
//       controller.dispose();
//     }
//     for (var controller in _giftAnimations) {
//       controller.dispose();
//     }
//     for (var controller in _giftReplyAnimations) {
//       controller.dispose();
//     }
//     super.dispose();
//   }
//
//   Future<void> _loadUserData() async {
//     if (widget.post.user_id == null) return;
//
//     setState(() {
//       _isLoadingUser = true;
//     });
//
//     try {
//       final userDoc =
//       await firestore.collection('Users').doc(widget.post.user_id!).get();
//       if (userDoc.exists) {
//         setState(() {
//           _currentUser = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
//           widget.post.user = _currentUser;
//         });
//       }
//     } catch (e) {
//       print('Erreur lors du chargement de l\'utilisateur: $e');
//     } finally {
//       // setState(() {
//       //   _isLoadingUser = false;
//       // });
//       _isLoadingUser = false;
//
//     }
//   }
//
//   Future<void> _loadCanalData() async {
//     if (widget.post.canal_id == null || widget.post.canal_id!.isEmpty) return;
//
//     setState(() {
//       _isLoadingCanal = true;
//     });
//
//     try {
//       final canalDoc = await firestore
//           .collection('Canaux')
//           .doc(widget.post.canal_id!)
//           .get();
//
//       if (canalDoc.exists) {
//         final canalData = canalDoc.data() as Map<String, dynamic>;
//         setState(() {
//           _currentCanal = Canal.fromJson(canalData);
//           widget.post.canal = _currentCanal;
//         });
//       }
//     } catch (e) {
//       print('Erreur lors du chargement du canal: $e');
//     } finally {
//       setState(() {
//         _isLoadingCanal = false;
//       });
//     }
//   }
//
//   UserData? get currentUser {
//     return widget.post.user ?? _currentUser;
//   }
//
//   Canal? get currentCanal {
//     return widget.post.canal ?? _currentCanal;
//   }
//   int _selectedGiftIndex = 0;
//
//   List<double> giftPrices = [
//     10, 25, 50, 100, 200, 300, 500, 700, 1500, 2000,
//     2500, 5000, 7000, 10000, 15000, 20000, 30000,
//     50000, 75000, 100000
//   ];
//
//   List<String> giftIcons = [
//     '🌹','❤️','👑','💎','🏎️','⭐','🍫','🧰','🌵','🍕',
//     '🍦','💻','🚗','🏠','🛩️','🛥️','🏰','💎','🏎️','🚗'
//   ];
//   void _showInsufficientBalanceDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           backgroundColor: Colors.black,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//             side: BorderSide(color: Colors.yellow, width: 2),
//           ),
//           title: Text(
//             'Solde Insuffisant',
//             style: TextStyle(
//               color: Colors.yellow,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           content: Text(
//             'Votre solde est insuffisant pour effectuer cette action. Veuillez recharger votre compte.',
//             style: TextStyle(color: Colors.white),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text('Annuler', style: TextStyle(color: Colors.white)),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 // Naviguer vers la page de recharge
//                 Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen()));
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green,
//               ),
//               child: Text('Recharger', style: TextStyle(color: Colors.black)),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Future<void> _sendGift(double amount) async {
//     try {
//       setState(() => _isLoading = true);
//
//       final firestore = FirebaseFirestore.instance;
//       await authProvider.getAppData();
//       // Récupérer l'utilisateur expéditeur à jour
//       final senderSnap = await firestore.collection('Users').doc(authProvider.loginUserData.id).get();
//       if (!senderSnap.exists) {
//         throw Exception("Utilisateur expéditeur introuvable");
//       }
//       final senderData = senderSnap.data() as Map<String, dynamic>;
//       final double senderBalance = (senderData['votre_solde_principal'] ?? 0.0).toDouble();
//
//       // Vérifier le solde
//       if (senderBalance >= amount) {
//         final double gainDestinataire = amount * 0.5;
//         final double gainApplication = amount * 0.5;
//
//         // Débiter l’expéditeur
//         await firestore.collection('Users').doc(authProvider.loginUserData.id).update({
//           'votre_solde_principal': FieldValue.increment(-amount),
//         });
//
//         // Créditer le destinataire
//         await firestore.collection('Users').doc(widget.post.user!.id).update({
//           'votre_solde_principal': FieldValue.increment(gainDestinataire),
//         });
//
//         // Créditer l'application
//         String appDataId = authProvider.appDefaultData.id!;
//         await firestore.collection('AppData').doc(appDataId).update({
//           'solde_gain': FieldValue.increment(gainApplication),
//         });
//
//         // Ajouter l'expéditeur à la liste des cadeaux du post
//         await firestore.collection('Posts').doc(widget.post.id).update({
//           'users_cadeau_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
//           'popularity': FieldValue.increment(5), // pondération pour un commentaire
//
//         });
//
//         // Créer les transactions
//         // Créer les transactions
//         await _createTransaction(TypeTransaction.DEPENSE.name, amount, "Cadeau envoyé à @${widget.post.user!.pseudo}",authProvider.loginUserData.id!);
//         await _createTransaction(TypeTransaction.GAIN.name, gainDestinataire, "Cadeau reçu de @${authProvider.loginUserData.pseudo}",widget.post.user_id!);
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             backgroundColor: Colors.green,
//             content: Text(
//               '🎁 Cadeau de ${amount.toInt()} FCFA envoyé avec succès!',
//               style: TextStyle(color: Colors.white),
//             ),
//           ),
//         );
//         await authProvider.sendNotification(
//           userIds: [widget.post.user!.oneIgnalUserid!],
//           smallImage: "", // pas besoin de montrer l'image de l'expéditeur
//           send_user_id: "", // pas besoin de l'expéditeur
//           recever_user_id: "${widget.post.user_id!}",
//           message: "🎁 Vous avez reçu un cadeau de ${amount.toInt()} FCFA !",
//           type_notif: NotificationType.POST.name,
//           post_id: "${widget.post!.id!}",
//           post_type: PostDataType.IMAGE.name,
//           chat_id: '',
//         );
//       } else {
//         _showInsufficientBalanceDialog();
//       }
//     } catch (e) {
//       print("Erreur envoi cadeau: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.red,
//           content: Text(
//             'Erreur lors de l\'envoi du cadeau',
//             style: TextStyle(color: Colors.white),
//           ),
//         ),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//   void _showGiftDialog(Post post) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         final height = MediaQuery.of(context).size.height * 0.6; // 60% de l'écran
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return Dialog(
//               backgroundColor: Colors.black,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20),
//                 side: BorderSide(color: Colors.yellow, width: 2),
//               ),
//               child: Container(
//                 height: height,
//                 padding: EdgeInsets.all(16),
//                 child: Column(
//                   children: [
//                     Text(
//                       'Envoyer un Cadeau',
//                       style: TextStyle(
//                         color: Colors.yellow,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 20,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     SizedBox(height: 12),
//                     Text(
//                       'Choisissez le montant en FCFA',
//                       style: TextStyle(color: Colors.white),
//                     ),
//                     SizedBox(height: 12),
//                     // -----------------------------
//                     // Expanded pour GridView scrollable
//                     Expanded(
//                       child: GridView.builder(
//                         physics: BouncingScrollPhysics(),
//                         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: 3, // 3 colonnes
//                           crossAxisSpacing: 10,
//                           mainAxisSpacing: 10,
//                           childAspectRatio: 0.8,
//                         ),
//                         itemCount: giftPrices.length,
//                         itemBuilder: (context, index) {
//                           return GestureDetector(
//                             onTap: () => setState(() => _selectedGiftIndex = index),
//                             child: Container(
//                               padding: EdgeInsets.all(10),
//                               decoration: BoxDecoration(
//                                 color: _selectedGiftIndex == index
//                                     ? Colors.green
//                                     : Colors.grey[800],
//                                 borderRadius: BorderRadius.circular(10),
//                                 border: Border.all(
//                                   color: _selectedGiftIndex == index
//                                       ? Colors.yellow
//                                       : Colors.transparent,
//
//                                   width: 1,
//                                 ),
//                               ),
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Text(
//                                     giftIcons[index],
//                                     style: TextStyle(fontSize: 24),
//                                   ),
//                                   SizedBox(height: 5),
//                                   Text(
//                                     '${giftPrices[index].toInt()} FCFA',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                     textAlign: TextAlign.center,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                     SizedBox(height: 12),
//                     Text(
//                       'Votre solde: ${authProvider.loginUserData.votre_solde_principal?.toInt() ?? 0} FCFA',
//                       style: TextStyle(
//                         color: Colors.yellow,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     SizedBox(height: 12),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         TextButton(
//                           onPressed: () => Navigator.pop(context),
//                           child: Text('Annuler', style: TextStyle(color: Colors.white)),
//                         ),
//                         ElevatedButton(
//                           onPressed: () {
//                             Navigator.pop(context);
//                             _sendGift(giftPrices[_selectedGiftIndex]);
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                           ),
//                           child: Text(
//                             'Envoyer',
//                             style: TextStyle(color: Colors.black),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//   Future<void> _createTransaction(String type, double montant, String description,String userid) async {
//     final FirebaseFirestore firestore = FirebaseFirestore.instance;
//
//     try {
//       final transaction = TransactionSolde()
//         ..id = firestore.collection('TransactionSoldes').doc().id
//         ..user_id =userid
//         ..type = type
//         ..statut = StatutTransaction.VALIDER.name
//         ..description = description
//         ..montant = montant
//         ..methode_paiement = "cadeau"
//         ..createdAt = DateTime.now().millisecondsSinceEpoch
//         ..updatedAt = DateTime.now().millisecondsSinceEpoch;
//
//       await firestore.collection('TransactionSoldes').doc(transaction.id).set(transaction.toJson());
//     } catch (e) {
//       print("Erreur création transaction: $e");
//     }
//   }
//
//   // Méthodes existantes conservées (simplifiées pour l'exemple)
//   void showRepublishDialog(Post post, UserData userSendCadeau, AppDefaultData appdata, BuildContext context) {
//     // Implémentation existante conservée
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           backgroundColor: _twitterCardBg,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           title: Text(
//             "✨ Republier",
//             style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _twitterTextPrimary),
//             textAlign: TextAlign.center,
//           ),
//           content: Text(
//             "🔝 Cette action mettra votre post en première position.\n\n💰 1 PC sera retiré de votre compte principal.",
//             textAlign: TextAlign.center,
//             style: TextStyle(color: _twitterTextSecondary, fontSize: 16),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text("❌ Fermer", style: TextStyle(color: _twitterTextSecondary)),
//             ),
//             TextButton(
//               onPressed: () async {
//                 // Logique existante
//               },
//               child: Text("🚀 Republier", style: TextStyle(color: _twitterBlue)),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   void _sendLike() {
//     final controller = AnimationController(
//       vsync: this,
//       duration: Duration(milliseconds: 1000),
//     );
//     setState(() {
//       _heartAnimations.add(controller);
//     });
//     controller.forward().then((_) {
//       setState(() {
//         _heartAnimations.remove(controller);
//       });
//     });
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     super.build(context);
//     final h = MediaQuery.of(context).size.height;
//     final w = MediaQuery.of(context).size.width;
//
//     if (_isLoadingUser || _isLoadingCanal) {
//       return _buildSkeletonLoader();
//     }
//
//     return Container(
//       color: _twitterDarkBg,
//       child: Column(
//         children: [
//           // Ligne de séparation supérieure
//           Container(
//             height: 0.5,
//             color: _twitterTextSecondary.withOpacity(0.3),
//           ),
//
//           // Contenu du post
//           Padding(
//             padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // En-tête du post
//                 _buildPostHeader(w, h),
//                 SizedBox(height: 8),
//
//                 // Contenu texte
//                 _buildPostContent(),
//                 SizedBox(height: 12),
//
//                 // Médias (images/vidéos)
//                 if (widget.post.images?.isNotEmpty ?? false)
//                   _buildMediaContent(h),
//
//                 if (_isVideoPost(widget.post))
//                   _buildVideoContent(h),
//
//                 // Actions du post
//                 SizedBox(height: 12),
//                 _buildPostActions(),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSkeletonLoader() {
//     return Container(
//       color: _twitterDarkBg,
//       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       child: Column(
//         children: [
//           Row(
//             children: [
//               CircleAvatar(radius: 20, backgroundColor: _twitterTextSecondary.withOpacity(0.3)),
//               SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Container(width: 120, height: 14, color: _twitterTextSecondary.withOpacity(0.3)),
//                     SizedBox(height: 4),
//                     Container(width: 80, height: 12, color: _twitterTextSecondary.withOpacity(0.3)),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 12),
//           Container(width: double.infinity, height: 16, color: _twitterTextSecondary.withOpacity(0.3)),
//           SizedBox(height: 4),
//           Container(width: double.infinity, height: 16, color: _twitterTextSecondary.withOpacity(0.3)),
//           SizedBox(height: 8),
//           Container(
//             height: 200,
//             width: double.infinity,
//             color: _twitterTextSecondary.withOpacity(0.3),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildPostHeader(double w, double h) {
//     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final currentUserId = authProvider.loginUserData.id;
//
//     // Déterminer si c'est un post de canal ou d'utilisateur
//     final isCanalPost = widget.post.canal != null;
//     final postOwner = isCanalPost ? widget.post.canal! : widget.post.user!;
//     final isCurrentUser = currentUserId == widget.post.user?.id;
//
//     // Vérifier si déjà abonné
//     final isAbonne = isCanalPost
//         ? widget.post.canal?.usersSuiviId?.contains(currentUserId) ?? false
//         : widget.post.user?.userAbonnesIds?.contains(currentUserId) ?? false;
//
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Avatar
//         GestureDetector(
//           onTap: () {
//             if(widget.post.canal != null){
//               Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: widget.post.canal!)));
//             } else {
//               showUserDetailsModalDialog(widget.post.user!, w, h, context);
//             }
//           },
//           child: Stack(
//             children: [
//               CircleAvatar(
//                 radius: 23,
//                 backgroundColor: _twitterBlue,
//                 backgroundImage: _getProfileImage(),
//                 child: _getProfileImage() == null
//                     ? Icon(
//                     isCanalPost ? Icons.group : Icons.person,
//                     color: Colors.white,
//                     size: 20
//                 )
//                     : null,
//               ),
//               if (_isVerified())
//                 Positioned(
//                   bottom: 0,
//                   right: 0,
//                   child: Container(
//                     padding: EdgeInsets.all(2),
//                     decoration: BoxDecoration(
//                       color: _twitterDarkBg,
//                       shape: BoxShape.circle,
//                     ),
//                     child: Icon(
//                       Icons.verified,
//                       color: _twitterBlue,
//                       size: 14,
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//         SizedBox(width: 12),
//
//         // Informations utilisateur et menu
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Expanded(
//                     child: Row(
//                       children: [
//                         Text(
//                           _getDisplayName(),
//                           style: TextStyle(
//                             color: _twitterTextPrimary,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 15,
//                           ),
//                         ),
//                         SizedBox(width: 4),
//                         if (_isVerified()) Icon(Icons.verified, color: _twitterBlue, size: 16),
//                       ],
//                     ),
//                   ),
//
//                   // Bouton S'abonner ou menu
//                   if (!isCurrentUser && !isAbonne)
//                     _buildFollowButton(isCanalPost, postOwner),
//                   SizedBox(width: 10),
//                   GestureDetector(
//                     onTap: () => _showPostMenu(widget.post),
//                     child: Icon(
//                       Icons.more_horiz,
//                       color: _twitterTextSecondary,
//                       size: 20,
//                     ),
//                   ),
//                 ],
//               ),
//               SizedBox(height: 2),
//               Text(
//                 _getFollowerCount(),
//                 style: TextStyle(
//                   color: _twitterTextSecondary,
//                   fontSize: 12,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildFollowButton(bool isCanalPost, dynamic postOwner) {
//     return StatefulBuilder(
//       builder: (context, setState) {
//         bool isLoading = false;
//         final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//
//         return Container(
//           height: 28,
//           child: ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.green,
//               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//             ),
//             onPressed: isLoading ? null : () async {
//               setState(() => isLoading = true);
//
//               if (isCanalPost) {
//                 // Abonnement au canal
//                 Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: widget.post.canal!)));
//                 // Mettre à jour l'état local après l'abonnement
//                 if (mounted) {
//                   setState(() {});
//                 }
//               } else {
//                 // Abonnement à l'utilisateur
//                 await authProvider.abonner(postOwner as UserData, context);
//                 // Mettre à jour l'état local après l'abonnement
//                 if (mounted) {
//                   setState(() {});
//                 }
//               }
//
//               setState(() => isLoading = false);
//             },
//             child: isLoading
//                 ? SizedBox(
//               width: 16,
//               height: 16,
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 color: Colors.white,
//               ),
//             )
//                 : Text(
//               'Suivre',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 12,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//   Widget _buildPostContent() {
//     final text = widget.post.description ?? "";
//     final words = text.split(' ');
//     final isLong = words.length > 50;
//
//     // Texte à afficher selon l'état
//     final displayedText = _isExpanded || !isLong
//         ? text
//         : words.take(50).join(' ') + '...';
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         GestureDetector(
//           onTap: () => Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => DetailsPost(post: widget.post),
//             ),
//           ),
//           child: HashTagText(
//
//             text: displayedText,
//             decoratedStyle: TextStyle(
//               fontSize: 15,
//               color: _twitterBlue,
//               fontWeight: FontWeight.w400,
//               height: 1.4,
//             ),
//             basicStyle: TextStyle(
//               fontSize: 15,
//               color: _twitterTextPrimary,
//               fontWeight: FontWeight.w400,
//               height: 1.4,
//             ),
//             onTap: (text) {
//               // Gestion des hashtags
//             },
//           ),
//         ),
//         if (isLong)
//           GestureDetector(
//             onTap: () {
//               setState(() {
//                 _isExpanded = !_isExpanded;
//               });
//             },
//             child: Padding(
//               padding: const EdgeInsets.only(top: 4),
//               child: Text(
//                 _isExpanded ? "Voir moins" : "Voir plus",
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.bold,
//                   color: _twitterBlue,
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }
//
//   Widget _buildMediaContent(double h) {
//     final images = widget.post.images!;
//     return GestureDetector(
//                 onTap: () => Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => DetailsPost(post: widget.post),
//             ),
//           ),
//       child: Container(
//         margin: EdgeInsets.only(top: 8),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(16),
//           color: _twitterCardBg,
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(16),
//           child: images.length == 1
//               ? CachedNetworkImage(
//             imageUrl: images.first,
//             fit: BoxFit.cover,
//             width: double.infinity,
//             height: h * 0.4,
//             placeholder: (context, url) => Container(
//               color: _twitterTextSecondary.withOpacity(0.1),
//               height: h * 0.4,
//               child: Center(child: CircularProgressIndicator(color: _twitterBlue)),
//             ),
//             errorWidget: (context, url, error) => Container(
//               color: _twitterTextSecondary.withOpacity(0.1),
//               height: h * 0.4,
//               child: Icon(Icons.error, color: _twitterTextSecondary),
//             ),
//           )
//               : ImageSlideshow(
//             height: h * 0.4,
//             children: images.map((image) => CachedNetworkImage(
//               imageUrl: image,
//               fit: BoxFit.cover,
//               width: double.infinity,
//             )).toList(),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Variables pour la thumbnail vidéo
//   String? _videoThumbnailPath;
//   bool _isGeneratingThumbnail = false;
//
//
//
//   @override
//   void didUpdateWidget(HomePostUsersWidget oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.post.id != widget.post.id) {
//       _generateVideoThumbnail();
//     }
//   }
//
//   Future<void> _generateVideoThumbnail() async {
//     if (!_isVideoPost(widget.post) || widget.post.url_media == null) return;
//
//     setState(() {
//       _isGeneratingThumbnail = true;
//     });
//
//     try {
//       final thumbnailPath = await VideoThumbnail.thumbnailFile(
//         video: widget.post.url_media!,
//         thumbnailPath: (await getTemporaryDirectory()).path,
//         imageFormat: ImageFormat.JPEG,
//         maxWidth: 400, // Largeur maximale de la thumbnail
//         quality: 75, // Qualité de l'image
//         timeMs: 1000, // Prendre la frame à 1 seconde
//       );
//
//       if (thumbnailPath != null && File(thumbnailPath).existsSync()) {
//         setState(() {
//           _videoThumbnailPath = thumbnailPath;
//           _isGeneratingThumbnail = false;
//         });
//       }
//     } catch (e) {
//       print('Erreur génération thumbnail: $e');
//       setState(() {
//         _isGeneratingThumbnail = false;
//       });
//     }
//   }
//
//   Widget _buildVideoContent(double h) {
//     return Container(
//       margin: EdgeInsets.only(top: 8),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(16),
//         color: _twitterCardBg,
//       ),
//       child: Stack(
//         children: [
//           // Thumbnail de la vidéo
//           Container(
//             height: h * 0.4,
//             width: double.infinity,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(16),
//               color: _twitterTextSecondary.withOpacity(0.1),
//             ),
//             child: _buildThumbnailContent(h),
//           ),
//
//           // Overlay de lecture
//           Positioned.fill(
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 borderRadius: BorderRadius.circular(16),
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => VideoTikTokPageDetails(initialPost: widget.post),
//                     ),
//                   );
//                 },
//                 child: Center(
//                   child: AnimatedOpacity(
//                     opacity: _isGeneratingThumbnail ? 0.3 : 1.0,
//                     duration: Duration(milliseconds: 300),
//                     child: Container(
//                       padding: EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.6),
//                         shape: BoxShape.circle,
//                       ),
//                       child: _isGeneratingThumbnail
//                           ? CircularProgressIndicator(
//                         color: Colors.white,
//                         strokeWidth: 2,
//                       )
//                           : Icon(
//                         Icons.play_arrow,
//                         color: Colors.white,
//                         size: 40,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//
//           // Badge "Vidéo" en haut à gauche
//           Positioned(
//             top: 8,
//             left: 8,
//             child: Container(
//               padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.7),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.videocam, color: Colors.white, size: 12),
//                   SizedBox(width: 4),
//                   Text(
//                     'Vidéo',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 10,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//
//         ],
//       ),
//     );
//   }
//
//   Widget _buildThumbnailContent(double h) {
//     if (_isGeneratingThumbnail) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(
//               color: _twitterBlue,
//               strokeWidth: 2,
//             ),
//             SizedBox(height: 8),
//             Text(
//               'Chargement de la vidéo...',
//               style: TextStyle(
//                 color: _twitterTextSecondary,
//                 fontSize: 12,
//               ),
//             ),
//           ],
//         ),
//       );
//     }
//
//     if (_videoThumbnailPath != null && File(_videoThumbnailPath!).existsSync()) {
//       return ClipRRect(
//         borderRadius: BorderRadius.circular(16),
//         child: Image.file(
//           File(_videoThumbnailPath!),
//           fit: BoxFit.cover,
//           width: double.infinity,
//           height: h * 0.4,
//           errorBuilder: (context, error, stackTrace) {
//             return _buildFallbackThumbnail();
//           },
//         ),
//       );
//     }
//
//     return _buildFallbackThumbnail();
//   }
//
//   Widget _buildFallbackThumbnail() {
//     return Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(16),
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [
//             _twitterTextSecondary.withOpacity(0.2),
//             _twitterTextSecondary.withOpacity(0.1),
//           ],
//         ),
//       ),
//       child: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.videocam,
//               color: _twitterTextSecondary.withOpacity(0.7),
//               size: 50,
//             ),
//             SizedBox(height: 8),
//             Text(
//               'Vidéo',
//               style: TextStyle(
//                 color: _twitterTextSecondary.withOpacity(0.7),
//                 fontSize: 16,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   String _formatDuration(int seconds) {
//     final duration = Duration(seconds: seconds);
//     String twoDigits(int n) => n.toString().padLeft(2, "0");
//     final minutes = twoDigits(duration.inMinutes.remainder(60));
//     final secs = twoDigits(duration.inSeconds.remainder(60));
//
//     if (duration.inHours > 0) {
//       final hours = twoDigits(duration.inHours);
//       return "$hours:$minutes:$secs";
//     }
//
//     return "$minutes:$secs";
//   }
//
//   bool _isVideoPost(Post post) {
//     return post.dataType == PostDataType.VIDEO.name ||
//         (post.url_media ?? '').contains('.mp4') ||
//         (post.url_media ?? '').contains('.mov') ||
//         (post.url_media ?? '').contains('.avi') ||
//         (post.url_media ?? '').contains('.webm') ||
//         (post.url_media ?? '').contains('.mkv') ||
//         (post.description ?? '').toLowerCase().contains('#video');
//   }
//
//   Widget _buildPostActions() {
//     final isLiked = isIn(widget.post.users_love_id ?? [], authProvider.loginUserData.id!);
//
//     return Container(
//       margin: EdgeInsets.only(top: 8),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           // Commentaire
//           _buildActionButton(
//             icon: FontAwesome.comment_o,
//             count: widget.post.comments ?? 0,
//             color: _twitterTextSecondary,
//             onPressed: () {
//               _showCommentsModal(widget.post);
//             },
//             // onPressedq: () => Navigator.push(
//             //   context,
//             //   MaterialPageRoute(builder: (context) => PostComments(post: widget.post)),
//             // ),
//           ),
//
//           // Republier
//           _buildActionButton(
//             icon: FontAwesome.eye,
//             count: widget.post.vues ?? 0,
//             color: _twitterGreen,
//             onPressed: () => _handleRepost(),
//           ),
//
//           // Like
//           _buildActionButton(
//             icon: isLiked ? FontAwesome.heart : FontAwesome.heart_o,
//             count: widget.post.loves ?? 0,
//             color: isLiked ? _twitterRed : _twitterTextSecondary,
//             onPressed: () => _handleLike(),
//           ),
//
//           // Cadeau
//           _buildActionButton(
//             icon: FontAwesome.gift,
//             count: widget.post.users_cadeau_id?.length ?? 0,
//             color: _twitterYellow,
//             onPressed: () => _handleGift(),
//           ),
//
//           // Partager
//           _buildActionButton(
//             icon: Icons.share,
//             count: widget.post.partage ?? 0,
//             color: _twitterTextSecondary,
//             onPressed: () => _handleShare(),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildActionButton({
//     required IconData icon,
//     required int count,
//     required Color color,
//     required VoidCallback onPressed,
//   }) {
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(20),
//         onTap: onPressed,
//         child: Container(
//           padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           child: Row(
//             children: [
//               Icon(icon, size: 18, color: color),
//               SizedBox(width: 6),
//               Text(
//                 _formatCount(count),
//                 style: TextStyle(
//                   color: color,
//                   fontSize: 13,
//                   fontWeight: FontWeight.w400,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Méthodes utilitaires
//   ImageProvider? _getProfileImage() {
//     if (currentCanal != null && currentCanal!.urlImage != null) {
//       return NetworkImage(currentCanal!.urlImage!);
//     } else if (currentUser != null && currentUser!.imageUrl != null) {
//       return NetworkImage(currentUser!.imageUrl!);
//     }
//     return null;
//   }
//   String _getFollowerCount() {
//     if (currentCanal != null) {
//       return "${currentCanal!.usersSuiviId?.length ?? 0} abonné(s)";
//     } else if (currentUser != null) {
//       return "${currentUser!.userAbonnesIds?.length ?? 0} abonné(s)";
//     }
//     return "0 abonné(s)";
//   }
//   bool _isVerified() {
//     if (currentCanal != null) return currentCanal!.isVerify ?? false;
//     if (currentUser != null) return currentUser!.isVerify ?? false;
//     return false;
//   }
//
//   String _getDisplayName() {
//     String name;
//
//     if (currentCanal != null) {
//       name = '#${currentCanal!.titre}';
//     } else if (currentUser != null) {
//       name = '@${currentUser!.pseudo}';
//     } else {
//       name = 'Utilisateur';
//     }
//
//     // Réduire la longueur si trop long (20 caractères ici)
//     const maxLength = 20;
//     if (name.length > maxLength) {
//       name = name.substring(0, maxLength) + '...';
//     }
//
//     return name;
//   }
//
//   String _getUserInfo() {
//     if (currentCanal != null) {
//       return '@${currentCanal!.titre?.toLowerCase().replaceAll(' ', '') ?? 'canal'}';
//     }
//     if (currentUser != null) {
//       return '@${currentUser!.pseudo?.toLowerCase().replaceAll(' ', '') ?? 'utilisateur'}';
//     }
//     return '@utilisateur';
//   }
//
//   String _getPostTime() {
//     // Implémentation simplifiée - à adapter avec vos données
//     final timestamp = widget.post.createdAt ?? DateTime.now().millisecondsSinceEpoch;
//     final date = DateTime.fromMicrosecondsSinceEpoch(timestamp);
//     final now = DateTime.now();
//     final difference = now.difference(date);
//
//     if (difference.inMinutes < 60) return '${difference.inMinutes}m';
//     if (difference.inHours < 24) return '${difference.inHours}h';
//     return '${difference.inDays}j';
//   }
//
//   String _formatCount(int count) {
//     if (count < 1000) return count.toString();
//     if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
//     return '${(count / 1000000).toStringAsFixed(1)}M';
//   }
//
//
//   void _showUserDetails(UserData user, double w, double h) {
//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         backgroundColor: _twitterDarkBg,
//         insetPadding: EdgeInsets.all(16),
//         child: DetailsOtherUser(user: user, w: w, h: h),
//       ),
//     );
//   }
//   void _showCommentsModal(Post post) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => Container(
//         height: MediaQuery.of(context).size.height * 0.85,
//         decoration: BoxDecoration(
//           color: _afroBlack,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         child: Column(
//           children: [
//             Container(
//               padding: EdgeInsets.all(16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'Commentaires',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   IconButton(
//                     icon: Icon(Icons.close, color: Colors.white),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: PostComments(post: post),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _showPostMenu(Post post) {
//     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final postProvider = Provider.of<PostProvider>(context, listen: false);
//
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: _twitterCardBg,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (context) => Container(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // --- Signaler (si ce n’est pas ton post)
//             if (post.user_id != authProvider.loginUserData.id)
//               _buildMenuOption(
//                 Icons.flag,
//                 "Signaler",
//                 _twitterTextPrimary,
//                     () async {
//                   post.status = PostStatus.SIGNALER.name;
//                   final value = await postProvider.updateVuePost(post, context);
//                   Navigator.pop(context);
//
//                   final snackBar = SnackBar(
//                     content: Text(
//                       value ? 'Post signalé !' : 'Échec du signalement !',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: value ? Colors.green : Colors.red),
//                     ),
//                   );
//                   ScaffoldMessenger.of(context).showSnackBar(snackBar);
//                 },
//               ),
//
//             // --- Supprimer (si admin OU propriétaire)
//             if (post.user!.id == authProvider.loginUserData.id ||
//                 authProvider.loginUserData.role == UserRole.ADM.name)
//               _buildMenuOption(
//                 Icons.delete,
//                 "Supprimer",
//                 Colors.red,
//                     () async {
//                   if (authProvider.loginUserData.role == UserRole.ADM.name) {
//                     await deletePost(post, context);
//                   } else {
//                     post.status = PostStatus.SUPPRIMER.name;
//                     await deletePost(post, context);
//                   }
//                   Navigator.pop(context);
//
//                   final snackBar = SnackBar(
//                     content: Text(
//                       'Post supprimé !',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: Colors.green),
//                     ),
//                   );
//                   ScaffoldMessenger.of(context).showSnackBar(snackBar);
//                 },
//               ),
//
//             SizedBox(height: 8),
//             Container(height: 0.5, color: _twitterTextSecondary.withOpacity(0.3)),
//             SizedBox(height: 8),
//
//             // --- Annuler
//             _buildMenuOption(Icons.cancel, "Annuler", _twitterTextSecondary, () {
//               Navigator.pop(context);
//             }),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildMenuOption(
//       IconData icon, String text, Color color, VoidCallback onTap) {
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: onTap,
//         child: Container(
//           padding: EdgeInsets.symmetric(vertical: 16),
//           child: Row(
//             children: [
//               Icon(icon, color: color, size: 20),
//               SizedBox(width: 12),
//               Text(text, style: TextStyle(color: color, fontSize: 16)),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Future<void> _handleLike() async {
//     _sendLike();
//
//     try {
//       if (!isIn(widget.post.users_love_id!, authProvider.loginUserData.id!)) {
//         // Mettre à jour localement
//         setState(() {
//           widget.post.loves = widget.post.loves! + 1;
//           widget.post.users_love_id!.add(authProvider.loginUserData.id!);
//         });
//
//         // Mettre à jour dans Firestore
//         await firestore.collection('Posts').doc(widget.post.id).update({
//           'loves': FieldValue.increment(1),
//           'users_love_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
//           'popularity': FieldValue.increment(1), // pondération pour un commentaire
//
//         });
//         await authProvider.sendNotification(
//             userIds: [widget.post.user!.oneIgnalUserid!],
//             smallImage:
//             "${authProvider.loginUserData.imageUrl!}",
//             send_user_id:
//             "${authProvider.loginUserData.id!}",
//             recever_user_id: "${widget.post.user_id!}",
//             message:
//             "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look",
//             type_notif:
//             NotificationType.POST.name,
//             post_id: "${widget.post!.id!}",
//             post_type: PostDataType.IMAGE.name,
//             chat_id: '');
//         // Incrémenter le solde de l'utilisateur qui aime
//         await postProvider.interactWithPostAndIncrementSolde(
//             widget.post.id!,
//             authProvider.loginUserData.id!,
//             "like",
//             widget.post.user_id!
//         );
//
//         // Animation
//         // _animationController.forward().then((_) {
//         //   _animationController.reverse();
//         // });
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               '+2 points ajoutés à votre compte',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.green),
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       print("Erreur like: $e");
//     }
//   }
//
//   // Méthodes de gestion des actions (à compléter avec votre logique existante)
//   void _handleLike2() async {
//     _sendLike();
//     // Votre logique like existante
//   }
//
//   void _handleRepost() {
//     // Logique repost
//     Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => DetailsPost(post: widget.post),
//         ));
//   }
//
//   void _handleGift() {
//
//     _showGiftDialog(widget.post);
//
//     // Navigator.push(
//     //     context,
//     //     MaterialPageRoute(
//     //       builder: (context) => DetailsPost(post: widget.post),
//     //     ));
//     // Logique cadeau
//   }
//
//   void _handleShare() async {
//     final AppLinkService _appLinkService = AppLinkService();
//     _appLinkService.shareContent(
//       type: AppLinkType.post,
//       id: widget.post.id!,
//       message: widget.post.description ?? "",
//       mediaUrl: widget.post.images?.isNotEmpty ?? false ? widget.post.images!.first : "",
//     );
//   }
// }

// Méthodes utilitaires globales
// bool isIn(List<String> list, String value) {
//   return list.contains(value);
// }
//
// bool isUserAbonne(List<String> abonnesIds, String userId) {
//   return abonnesIds.contains(userId);
// }

void showInsufficientBalanceDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: _twitterCardBg,
        title: Text("Solde insuffisant", style: TextStyle(color: _twitterTextPrimary)),
        content: Text("Votre solde principal est insuffisant.", style: TextStyle(color: _twitterTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Fermer", style: TextStyle(color: _twitterTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => MonetisationPage()));
            },
            child: Text("Recharger", style: TextStyle(color: _twitterBlue)),
          ),
        ],
      );
    },
  );
}


