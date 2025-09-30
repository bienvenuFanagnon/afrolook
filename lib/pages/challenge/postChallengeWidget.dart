import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/linkService.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:hashtagable_v3/widgets/hashtag_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../canaux/detailsCanal.dart';
import '../component/showUserDetails.dart';
import '../postComments.dart';
import '../postDetails.dart';
import '../postDetailsVideoListe.dart';
import '../userPosts/postWidgets/postUserWidget.dart';

// Vos couleurs principales
const _afroBlack = Color(0xFF000000);
const _afroGreen = Color(0xFF00BA7C);
const _afroYellow = Color(0xFFFFD400);
const _afroRed = Color(0xFFF91880);
const _afroBlue = Color(0xFF1D9BF0);
const _afroCardBg = Color(0xFF16181C);
const _afroTextPrimary = Color(0xFFFFFFFF);
const _afroTextSecondary = Color(0xFF71767B);

class LookChallengePostWidget extends StatefulWidget {
  late Post post;
  late Color? color;
  final double height;
  final double width;
  final bool isDegrade;
  bool isPreview;
  final Function(Post, VisibilityInfo)? onVisibilityChanged;

  LookChallengePostWidget({
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
  _LookChallengePostWidgetState createState() => _LookChallengePostWidgetState();
}

class _LookChallengePostWidgetState extends State<LookChallengePostWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _isExpanded = false;
  Challenge? _challenge;
  Post? _challengePost;
  bool _isLoadingChallenge = false;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Variables pour stocker les données récupérées individuellement
  UserData? _currentUser;
  Canal? _currentCanal;
  bool _isLoadingUser = false;
  bool _isLoadingCanal = false;

  // Variables pour le vote
  bool _hasVoted = false;
  List<String> _votersList = [];

  // Variables pour la thumbnail vidéo
  String? _videoThumbnailPath;
  bool _isGeneratingThumbnail = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCanalData();
    _generateVideoThumbnail();
    _checkIfUserHasVoted();
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
      final userDoc =
      await firestore.collection('Users').doc(widget.post.user_id!).get();
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
      final canalDoc = await firestore
          .collection('Canaux')
          .doc(widget.post.canal_id!)
          .get();

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

  Future<void> _checkIfUserHasVoted() async {
    try {
      final postDoc = await firestore.collection('Posts').doc(widget.post.id).get();
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        final voters = List<String>.from(data['users_votes_ids'] ?? []);
        setState(() {
          _hasVoted = voters.contains(authProvider.loginUserData.id);
        });
      }
    } catch (e) {
      print('Erreur lors de la vérification du vote: $e');
    }
  }

  UserData? get currentUser {
    return widget.post.user ?? _currentUser;
  }

  Canal? get currentCanal {
    return widget.post.canal ?? _currentCanal;
  }

  @override
  void didUpdateWidget(LookChallengePostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _generateVideoThumbnail();
      _checkIfUserHasVoted();
    }
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

  // Vérifier si c'est un Look Challenge
  bool get _isLookChallenge {
    return widget.post.type == 'CHALLENGEPARTICIPATION';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    if (_isLoadingUser || _isLoadingCanal) {
      return _buildSkeletonLoader();
    }

    return Container(
      color: _afroBlack,
      child: Column(
        children: [
          // Ligne de séparation supérieure
          Container(
            height: 0.5,
            color: _afroTextSecondary.withOpacity(0.3),
          ),

          // Bannière Look Challenge seulement si c'est un challenge
          if (_isLookChallenge) _buildLookChallengeBanner(),

          // Contenu du post
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête du post
                _buildPostHeader(w, h),
                SizedBox(height: 8),

                // Contenu texte
                _buildPostContent(),
                SizedBox(height: 12),

                // Médias (images/vidéos)
                if (widget.post.images?.isNotEmpty ?? false)
                  _buildMediaContent(h),

                if (_isVideoPost(widget.post))
                  _buildVideoContent(h),

                // Section de vote pour les Look Challenges
                if (_isLookChallenge) _buildVoteSection(),

                // Actions du post
                SizedBox(height: 12),
                _buildPostActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLookChallengeBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_afroGreen, _afroYellow],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: _afroBlack, size: 16),
              SizedBox(width: 6),
              Text(
                'LOOK CHALLENGE',
                style: TextStyle(
                  color: _afroBlack,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            '${widget.post.votesChallenge ?? 0} votes',
            style: TextStyle(
              color: _afroBlack,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteSection() {
    return Container(
      margin: EdgeInsets.only(top: 12, bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _afroCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _afroGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '🎯 PARTICIPEZ AU CHALLENGE',
            style: TextStyle(
              color: _afroGreen,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Ce look participe à un challenge. Allez voter sur la page détaillée !',
            style: TextStyle(
              color: _afroTextSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),

          if (!_hasVoted)
            _buildVoteButton()
          else
            _buildVotedStatus(),
        ],
      ),
    );
  }

  Widget _buildVoteButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // Redirection vers la page de détails pour voter
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailsPost(post: widget.post),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _afroGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.symmetric(vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.how_to_vote, size: 18, color: _afroBlack),
            SizedBox(width: 8),
            Text(
              'VOTER POUR CE LOOK',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _afroBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVotedStatus() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _afroGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _afroGreen),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: _afroGreen, size: 16),
          SizedBox(width: 8),
          Text(
            'Vous avez déjà voté pour ce look',
            style: TextStyle(
              color: _afroGreen,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Container(
      color: _afroBlack,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Skeleton pour la bannière Look Challenge
          if (_isLookChallenge)
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: _afroTextSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ),
          SizedBox(height: 12),
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
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    final isCanalPost = widget.post.canal != null;
    final postOwner = isCanalPost ? widget.post.canal! : widget.post.user!;
    final isCurrentUser = currentUserId == widget.post.user?.id;

    final isAbonne = isCanalPost
        ? widget.post.canal?.usersSuiviId?.contains(currentUserId) ?? false
        : widget.post.user?.userAbonnesIds?.contains(currentUserId) ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar avec badge Look Challenge
        GestureDetector(
          onTap: () {
            if(widget.post.canal != null){
              Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: widget.post.canal!)));
            } else {
              showUserDetailsModalDialog(widget.post.user!, w, h, context);
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
                    size: 20
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
                      color: _afroBlack,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified,
                      color: _afroBlue,
                      size: 14,
                    ),
                  ),
                ),
              // Badge Look Challenge
              if (_isLookChallenge)
                Positioned(
                  top: -2,
                  left: -2,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _afroYellow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: _afroBlack,
                      size: 12,
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
                        SizedBox(width: 4),
                        // Badge participant Look Challenge
                        if (_isLookChallenge)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _afroGreen.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _afroGreen),
                            ),
                            child: Text(
                              'LOOK',
                              style: TextStyle(
                                color: _afroGreen,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bouton S'abonner ou menu
                  if (!isCurrentUser && !isAbonne)
                    _buildFollowButton(isCanalPost, postOwner),
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

  Widget _buildFollowButton(bool isCanalPost, dynamic postOwner) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isLoading = false;
        final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

        return Container(
          height: 28,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _afroGreen,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: isLoading ? null : () async {
              setState(() => isLoading = true);

              if (isCanalPost) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: widget.post.canal!)));
                if (mounted) {
                  setState(() {});
                }
              } else {
                await authProvider.abonner(postOwner as UserData, context);
                if (mounted) {
                  setState(() {});
                }
              }

              setState(() => isLoading = false);
            },
            child: isLoading
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Text(
              'Suivre',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostContent() {
    final text = widget.post.description ?? "";
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

  Widget _buildMediaContent(double h) {
    final images = widget.post.images!;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailsPost(post: widget.post),
        ),
      ),
      child: Container(
        margin: EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _afroCardBg,
          border: Border.all(
            color: _isLookChallenge ? _afroGreen.withOpacity(0.3) : Colors.transparent,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: images.length == 1
              ? CachedNetworkImage(
            imageUrl: images.first,
            fit: BoxFit.cover,
            width: double.infinity,
            height: h * 0.4,
            placeholder: (context, url) => Container(
              color: _afroTextSecondary.withOpacity(0.1),
              height: h * 0.4,
              child: Center(child: CircularProgressIndicator(color: _afroGreen)),
            ),
            errorWidget: (context, url, error) => Container(
              color: _afroTextSecondary.withOpacity(0.1),
              height: h * 0.4,
              child: Icon(Icons.error, color: _afroTextSecondary),
            ),
          )
              : ImageSlideshow(
            height: h * 0.4,
            children: images.map((image) => CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              width: double.infinity,
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent(double h) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _afroCardBg,
        border: Border.all(
          color: _isLookChallenge ? _afroGreen.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Stack(
        children: [
          // Thumbnail de la vidéo
          Container(
            height: h * 0.4,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _afroTextSecondary.withOpacity(0.1),
            ),
            child: _buildThumbnailContent(h),
          ),

          // Overlay de lecture
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoTikTokPage(initialPost: widget.post),
                    ),
                  );
                },
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _isGeneratingThumbnail ? 0.3 : 1.0,
                    duration: Duration(milliseconds: 300),
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: _isGeneratingThumbnail
                          ? CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                          : Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Badge "Look Challenge Video"
          if (_isLookChallenge)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _afroGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Look Video',
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
      ),
    );
  }

  Widget _buildThumbnailContent(double h) {
    if (_isGeneratingThumbnail) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: _afroGreen,
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
              _isLookChallenge ? 'Look Challenge Video' : 'Vidéo',
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

  Widget _buildPostActions() {
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
            onPressed: () {
              _showCommentsModal(widget.post);
            },
          ),

          // Vues
          _buildActionButton(
            icon: FontAwesome.eye,
            count: widget.post.vues ?? 0,
            color: _afroGreen,
            onPressed: () => _handleViewDetails(),
          ),

          // Like
          _buildActionButton(
            icon: isLiked ? FontAwesome.heart : FontAwesome.heart_o,
            count: widget.post.loves ?? 0,
            color: isLiked ? _afroRed : _afroTextSecondary,
            onPressed: () => _handleLike(),
          ),

          // Cadeau
          _buildActionButton(
            icon: FontAwesome.gift,
            count: widget.post.users_cadeau_id?.length ?? 0,
            color: _afroYellow,
            onPressed: () => _handleGift(),
          ),

          // Votes Look Challenge ou Partager pour les posts normaux
          if (_isLookChallenge)
            _buildActionButton(
              icon: Icons.how_to_vote,
              count: widget.post.votesChallenge ?? 0,
              color: _hasVoted ? _afroGreen : _afroTextSecondary,
              onPressed: () => _handleViewDetails(),
            )
          else
            _buildActionButton(
              icon: Icons.share,
              count: widget.post.partage ?? 0,
              color: _afroTextSecondary,
              onPressed: () => _handleShare(),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback onPressed,
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
              Icon(icon, size: 18, color: color),
              SizedBox(width: 6),
              Text(
                _formatCount(count),
                style: TextStyle(
                  color: color,
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
      return "${currentCanal!.usersSuiviId?.length ?? 0} abonné(s)${_isLookChallenge ? ' • ${widget.post.votesChallenge ?? 0} votes' : ''}";
    } else if (currentUser != null) {
      return "${currentUser!.userAbonnesIds?.length ?? 0} abonné(s)${_isLookChallenge ? ' • ${widget.post.votesChallenge ?? 0} votes' : ''}";
    }
    return "0 abonné(s)${_isLookChallenge ? ' • ${widget.post.votesChallenge ?? 0} votes' : ''}";
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
          color: _afroBlack,
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

        await authProvider.sendNotification(
            userIds: [widget.post.user!.oneIgnalUserid!],
            smallImage: "${authProvider.loginUserData.imageUrl!}",
            send_user_id: "${authProvider.loginUserData.id!}",
            recever_user_id: "${widget.post.user_id!}",
            message: "📢 @${authProvider.loginUserData.pseudo!} a aimé votre ${_isLookChallenge ? 'look' : 'post'}",
            type_notif: NotificationType.POST.name,
            post_id: "${widget.post!.id!}",
            post_type: PostDataType.IMAGE.name,
            chat_id: '');

        await postProvider.interactWithPostAndIncrementSolde(
            widget.post.id!,
            authProvider.loginUserData.id!,
            "like",
            widget.post.user_id!
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+2 points ajoutés à votre compte',
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

  void _handleViewDetails() {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailsPost(post: widget.post),
        ));
  }

  void _handleGift() {
    // Logique cadeau existante
    _showGiftDialog(widget.post);
  }

  void _handleShare() async {
    final AppLinkService _appLinkService = AppLinkService();
    _appLinkService.shareContent(
      type: AppLinkType.post,
      id: widget.post.id!,
      message: _isLookChallenge
          ? "🎯 Look Challenge: ${widget.post.description ?? ""}"
          : widget.post.description ?? "",
      mediaUrl: widget.post.images?.isNotEmpty ?? false ? widget.post.images!.first : "",
    );
  }

  // Méthode pour afficher le dialogue de cadeau (à adapter depuis votre code existant)
  void _showGiftDialog(Post post) {
    // Implémentation existante de la boîte de dialogue cadeau
    // ...
  }
}

// Méthodes utilitaires globales
bool isIn(List<String> list, String value) {
  return list.contains(value);
}