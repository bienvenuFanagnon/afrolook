// lib/pages/creator/creator_content_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../models/dating_data.dart';
import '../../models/enums.dart';
import '../../providers/authProvider.dart';
import '../../providers/dating/creator_provider.dart';
import 'creator_profile_page.dart';
import 'creator_subscription_page.dart';

class CreatorContentDetailPage extends StatefulWidget {
  final CreatorContent content;

  const CreatorContentDetailPage({
    Key? key,
    required this.content,
  }) : super(key: key);

  @override
  State<CreatorContentDetailPage> createState() => _CreatorContentDetailPageState();
}

class _CreatorContentDetailPageState extends State<CreatorContentDetailPage> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  bool _isLiked = false;
  bool _isLoved = false;
  bool _isUnliked = false;
  bool _isPurchased = false;
  bool _isLoading = false;
  CreatorProfile? _creatorProfile;
  bool _isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _checkPurchaseStatus();
    _loadCreatorProfile();
    _checkSubscription();
    _initVideoPlayer();
    _recordView();
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _initVideoPlayer() {
    if (widget.content.mediaType == MediaType.video && widget.content.mediaUrl.isNotEmpty) {
      _videoController = VideoPlayerController.network(widget.content.mediaUrl);
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade300,
        ),
      );
      _videoController.initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
      });
    }
  }

  Future<void> _recordView() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null) return;

    try {
      final creatorProvider = Provider.of<CreatorProvider>(context, listen: false);
      await creatorProvider.reactToContent(
        contentId: widget.content.id,
        creatorId: widget.content.creatorId,
        reactionType: ReactionType.like, // Ne change pas le like, juste enregistre la vue
      );
    } catch (e) {
      print('Erreur enregistrement vue: $e');
    }
  }

  Future<void> _checkPurchaseStatus() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null || !widget.content.isPaid) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('creator_content_purchases')
          .where('contentId', isEqualTo: widget.content.id)
          .where('buyerUserId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'paid')
          .limit(1)
          .get();

      setState(() {
        _isPurchased = snapshot.docs.isNotEmpty;
      });
    } catch (e) {
      print('Erreur vérification achat: $e');
    }
  }

  Future<void> _loadCreatorProfile() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('creator_profiles')
          .doc(widget.content.creatorId)
          .get();

      if (snapshot.exists) {
        setState(() {
          _creatorProfile = CreatorProfile.fromJson(snapshot.data()!);
        });
      }
    } catch (e) {
      print('Erreur chargement profil créateur: $e');
    }
  }

  Future<void> _checkSubscription() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('creator_subscriptions')
          .where('userId', isEqualTo: currentUserId)
          .where('creatorId', isEqualTo: widget.content.creatorId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      setState(() {
        _isSubscribed = snapshot.docs.isNotEmpty;
      });
    } catch (e) {
      print('Erreur vérification abonnement: $e');
    }
  }

  Future<void> _handleReaction(ReactionType reactionType) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null) return;

    final creatorProvider = Provider.of<CreatorProvider>(context, listen: false);
    final success = await creatorProvider.reactToContent(
      contentId: widget.content.id,
      creatorId: widget.content.creatorId,
      reactionType: reactionType,
    );

    if (success) {
      setState(() {
        switch (reactionType) {
          case ReactionType.like:
            _isLiked = true;
            _isLoved = false;
            _isUnliked = false;
            break;
          case ReactionType.love:
            _isLoved = true;
            _isLiked = false;
            _isUnliked = false;
            break;
          case ReactionType.unlike:
            _isUnliked = true;
            _isLiked = false;
            _isLoved = false;
            break;
        }
      });
    }
  }

  Future<void> _handlePurchase() async {
    if (_isPurchased) return;

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    final currentCoins = authProvider.loginUserData.coinsBalance ?? 0;
    final priceCoins = widget.content.priceCoins ?? 0;

    if (currentCoins < priceCoins) {
      _showInsufficientCoinsDialog();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Acheter ce contenu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock,
              size: 50,
              color: Colors.amber,
            ),
            SizedBox(height: 16),
            Text(
              'Ce contenu est payant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Prix: $priceCoins pièces',
              style: TextStyle(
                color: Colors.amber.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Vous avez $currentCoins pièces',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
            ),
            child: Text('Acheter'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final creatorProvider = Provider.of<CreatorProvider>(context, listen: false);
    final success = await creatorProvider.purchasePaidContent(
      contentId: widget.content.id,
      creatorId: widget.content.creatorId,
      priceCoins: priceCoins,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      setState(() {
        _isPurchased = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contenu débloqué avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'achat'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Solde insuffisant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.monetization_on,
              size: 50,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              'Vous n\'avez pas assez de pièces pour acheter ce contenu.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Prix: ${widget.content.priceCoins} pièces',
              style: TextStyle(
                color: Colors.amber.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/coins/buy');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
            ),
            child: Text('Acheter des pièces'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShare() async {
    // Implémenter le partage du contenu
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fonctionnalité de partage à venir'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _canAccessContent() {
    if (!widget.content.isPaid) return true;
    if (_isPurchased) return true;
    if (_isSubscribed && widget.content.isPaid) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final canAccess = _canAccessContent();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.content.titre,
          style: TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: Colors.white),
            onPressed: _handleShare,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Contenu média
            _buildMediaContent(canAccess),

            if (!canAccess)
              _buildLockedContent(),

            if (canAccess)
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre et stats
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.content.titre,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.content.isPaid
                                ? Colors.amber.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.content.isPaid
                                ? 'Payant - ${widget.content.priceCoins} coins'
                                : 'Gratuit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.content.isPaid
                                  ? Colors.amber.shade800
                                  : Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Description
                    Text(
                      widget.content.description,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Profil créateur
                    GestureDetector(
                      onTap: () {
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder: (_) => CreatorProfilePage(
                        //       userId: widget.content.creatorId,
                        //     ),
                        //   ),
                        // );
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: NetworkImage(
                              _creatorProfile?.imageUrl ?? '',
                            ),
                            child: (_creatorProfile?.imageUrl ?? '').isEmpty
                                ? Icon(Icons.person, size: 24)
                                : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _creatorProfile?.pseudo ?? 'Créateur',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '@${_creatorProfile?.pseudo ?? ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isSubscribed && !widget.content.isPaid)
                            OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CreatorSubscriptionPage(
                                      creatorId: widget.content.creatorId,
                                      creatorName: _creatorProfile?.pseudo ?? 'Créateur',
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                'S\'abonner',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                          icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                          label: '${widget.content.likesCount}',
                          color: Colors.red,
                          onPressed: () => _handleReaction(ReactionType.like),
                        ),
                        _buildActionButton(
                          icon: _isLoved ? Icons.favorite : Icons.favorite_border,
                          label: '${widget.content.lovesCount}',
                          color: Colors.pink,
                          onPressed: () => _handleReaction(ReactionType.love),
                        ),
                        _buildActionButton(
                          icon: Icons.visibility,
                          label: '${widget.content.viewsCount}',
                          color: Colors.blue,
                          onPressed: null,
                        ),
                        _buildActionButton(
                          icon: Icons.share,
                          label: '${widget.content.sharesCount}',
                          color: Colors.green,
                          onPressed: _handleShare,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(bool canAccess) {
    if (!canAccess) {
      return Container(
        height: 300,
        color: Colors.grey.shade900,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 60,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'Contenu verrouillé',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Abonnez-vous ou achetez ce contenu pour y accéder',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handlePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                ),
                child: Text(
                  'Acheter ${widget.content.priceCoins} pièces',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (widget.content.mediaType) {
      case MediaType.image:
        return Image.network(
          widget.content.mediaUrl,
          height: 400,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 400,
              color: Colors.grey.shade200,
              child: Center(
                child: Icon(
                  Icons.broken_image,
                  size: 50,
                  color: Colors.grey.shade400,
                ),
              ),
            );
          },
        );

      case MediaType.video:
        return Container(
          height: 400,
          color: Colors.black,
          child: _isVideoInitialized && _chewieController != null
              ? Chewie(controller: _chewieController!)
              : Center(
            child: CircularProgressIndicator(),
          ),
        );

      case MediaType.text:
        return Container(
          padding: EdgeInsets.all(24),
          color: Colors.grey.shade100,
          child: Text(
            widget.content.description,
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        );
    }
  }

  Widget _buildLockedContent() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Aperçu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  widget.content.description.length > 200
                      ? '${widget.content.description.substring(0, 200)}...'
                      : widget.content.description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '...',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _handlePurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                  ),
                  child: Text(
                    'Débloquer le contenu complet',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: color,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}