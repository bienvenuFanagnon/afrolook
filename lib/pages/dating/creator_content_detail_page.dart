// lib/pages/creator/creator_content_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/dating_data.dart';
import '../../models/enums.dart';
import '../../providers/authProvider.dart';
import '../../providers/dating/creator_provider.dart';
import 'creator_profile_page.dart';
import 'creator_subscription_page.dart';
import 'buy_coins_page.dart';

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
  // Contrôleurs vidéo
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  // État du contenu
  bool _isLiked = false;
  bool _isPurchased = false;
  bool _isLoading = false;
  bool _isSubscribed = false;

  // Profil créateur
  CreatorProfile? _creatorProfile;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Couleurs
  final Color primaryRed = const Color(0xFFE63946);
  final Color primaryYellow = const Color(0xFFFFD700);
  final Color primaryBlack = Colors.black;
  final Color secondaryGrey = const Color(0xFF2C2C2C);

  @override
  void initState() {
    super.initState();
    _loadCreatorProfile();
    _checkSubscription();
    _checkPurchaseStatus();
    _checkLikeStatus();
    _initVideoPlayer();
    _recordView();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _initVideoPlayer() {
    if (widget.content.mediaType == MediaType.video && widget.content.mediaUrl.isNotEmpty) {
      _videoController = VideoPlayerController.network(widget.content.mediaUrl);
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: primaryRed,
          handleColor: primaryRed,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade300,
        ),
      );
      _videoController!.initialize().then((_) {
        if (mounted) setState(() => _isVideoInitialized = true);
      });
    }
  }

  Future<void> _loadCreatorProfile() async {
    try {
      final doc = await _firestore.collection('creator_profiles').doc(widget.content.creatorId).get();
      if (doc.exists) {
        setState(() => _creatorProfile = CreatorProfile.fromJson(doc.data()!));
      }
    } catch (e) {
      print('❌ Erreur chargement profil créateur: $e');
    }
  }

  Future<void> _checkSubscription() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    try {
      final snapshot = await _firestore
          .collection('creator_subscriptions')
          .where('userId', isEqualTo: currentUserId)
          .where('creatorId', isEqualTo: widget.content.creatorId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      setState(() => _isSubscribed = snapshot.docs.isNotEmpty);
    } catch (e) {
      print('❌ Erreur vérification abonnement: $e');
    }
  }

  Future<void> _checkPurchaseStatus() async {
    if (!widget.content.isPaid) return;

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    try {
      final snapshot = await _firestore
          .collection('creator_content_purchases')
          .where('contentId', isEqualTo: widget.content.id)
          .where('buyerUserId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'paid')
          .limit(1)
          .get();
      setState(() => _isPurchased = snapshot.docs.isNotEmpty);
    } catch (e) {
      print('❌ Erreur vérification achat: $e');
    }
  }

  Future<void> _checkLikeStatus() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    try {
      final snapshot = await _firestore
          .collection('creator_content_reactions')
          .where('contentId', isEqualTo: widget.content.id)
          .where('userId', isEqualTo: currentUserId)
          .where('reactionType', isEqualTo: 'like')
          .limit(1)
          .get();
      setState(() => _isLiked = snapshot.docs.isNotEmpty);
    } catch (e) {
      print('❌ Erreur vérification like: $e');
    }
  }

  Future<void> _recordView() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    try {
      // Vérifier si la vue a déjà été comptée (par exemple en session)
      // On utilise une collection `creator_content_views` (déjà existante)
      final existing = await _firestore
          .collection('creator_content_views')
          .where('contentId', isEqualTo: widget.content.id)
          .where('userId', isEqualTo: currentUserId)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        await _firestore.collection('creator_content_views').add({
          'contentId': widget.content.id,
          'creatorId': widget.content.creatorId,
          'userId': currentUserId,
          'viewedAt': DateTime.now().millisecondsSinceEpoch,
        });
        // Incrémenter le compteur de vues
        await _firestore
            .collection('creator_contents')
            .doc(widget.content.id)
            .update({'viewsCount': FieldValue.increment(1)});
      }
    } catch (e) {
      print('❌ Erreur enregistrement vue: $e');
    }
  }

  Future<void> _toggleLike() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    // Vérifier l'accès : si contenu payant, il faut être abonné ou avoir acheté
    if (widget.content.isPaid && !_isSubscribed && !_isPurchased) {
      _showAccessRequiredDialog();
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLiked) {
        // Supprimer le like
        final likeDoc = await _firestore
            .collection('creator_content_reactions')
            .where('contentId', isEqualTo: widget.content.id)
            .where('userId', isEqualTo: currentUserId)
            .where('reactionType', isEqualTo: 'like')
            .limit(1)
            .get();
        if (likeDoc.docs.isNotEmpty) {
          await likeDoc.docs.first.reference.delete();
          await _firestore
              .collection('creator_contents')
              .doc(widget.content.id)
              .update({'likesCount': FieldValue.increment(-1)});
          setState(() => _isLiked = false);
        }
      } else {
        // Ajouter le like
        await _firestore.collection('creator_content_reactions').add({
          'contentId': widget.content.id,
          'creatorId': widget.content.creatorId,
          'userId': currentUserId,
          'reactionType': 'like',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
        await _firestore
            .collection('creator_contents')
            .doc(widget.content.id)
            .update({'likesCount': FieldValue.increment(1)});
        setState(() => _isLiked = true);
      }
    } catch (e) {
      print('❌ Erreur like: $e');
    } finally {
      setState(() => _isLoading = false);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Acheter ce contenu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 50, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'Ce contenu est payant',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Prix: $priceCoins pièces',
              style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Vous avez $currentCoins pièces',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Acheter'),
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

    if (success && mounted) {
      setState(() => _isPurchased = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contenu débloqué avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'achat'),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Solde insuffisant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Vous n\'avez pas assez de pièces pour acheter ce contenu.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Prix: ${widget.content.priceCoins} pièces',
              style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuyCoinsPage()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Acheter des pièces'),
          ),
        ],
      ),
    );
  }

  void _showAccessRequiredDialog() {
    final isCreator = _creatorProfile != null && _creatorProfile!.userId == Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;
    if (isCreator) return; // Le créateur a accès à son propre contenu

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.lock, color: primaryYellow),
            const SizedBox(width: 8),
            const Text('Accès restreint', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ce contenu est payant. Pour y accéder, vous devez vous abonner à ce créateur.',
              style: TextStyle(color: Colors.grey[300]),
            ),
            const SizedBox(height: 16),
            Text(
              'Abonnez-vous pour débloquer tous ses contenus.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatorSubscriptionPage(
                    creatorId: widget.content.creatorId,
                    creatorName: _creatorProfile?.pseudo ?? 'ce créateur',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryYellow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('S\'abonner'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareContent() async {
    // Implémenter le partage (à faire)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Partage à venir'), duration: Duration(seconds: 1)),
    );
  }

  bool _canAccessContent() {
    if (!widget.content.isPaid) return true;
    if (_isPurchased) return true;
    if (_isSubscribed) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final canAccess = _canAccessContent();
    final isCreator = _creatorProfile != null && _creatorProfile!.userId == Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.content.titre,
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: primaryRed,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareContent,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Média
            _buildMediaSection(canAccess),
            const SizedBox(height: 16),
            // Carte d'info (titre, description, créateur)
            _buildInfoCard(canAccess, isCreator),
            const SizedBox(height: 24),
            // Bouton like / action
            _buildLikeButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(bool canAccess) {
    if (!canAccess) {
      return Container(
        height: 400,
        color: Colors.grey[900],
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Aperçu flouté (optionnel)
            CachedNetworkImage(
              imageUrl: widget.content.thumbnailUrl ?? widget.content.mediaUrl,
              fit: BoxFit.cover,
              colorBlendMode: BlendMode.darken,
              color: Colors.black54,
              errorWidget: (_, __, ___) => Container(color: Colors.grey[800]),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 60, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'Contenu verrouillé',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Abonnez-vous pour accéder à ce contenu',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreatorSubscriptionPage(
                            creatorId: widget.content.creatorId,
                            creatorName: _creatorProfile?.pseudo ?? 'ce créateur',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryYellow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('S\'abonner'),
                  ),
                  if (widget.content.isPaid && !_isSubscribed) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _handlePurchase,
                      child: Text(
                        'Acheter pour ${widget.content.priceCoins} coins',
                        style: TextStyle(color: primaryYellow),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Contenu accessible
    switch (widget.content.mediaType) {
      case MediaType.image:
        return CachedNetworkImage(
          imageUrl: widget.content.mediaUrl,
          height: 400,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(height: 400, color: Colors.grey[800]),
          errorWidget: (_, __, ___) => Container(height: 400, color: Colors.grey[800], child: const Icon(Icons.broken_image)),
        );
      case MediaType.video:
        return Container(
          height: 400,
          color: Colors.black,
          child: _isVideoInitialized && _chewieController != null
              ? Chewie(controller: _chewieController!)
              : const Center(child: CircularProgressIndicator()),
        );
      case MediaType.text:
        return Container(
          padding: const EdgeInsets.all(24),
          color: Colors.grey[100],
          child: Text(
            widget.content.description,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        );
    }
  }

  Widget _buildInfoCard(bool canAccess, bool isCreator) {
    final bool showSubscribeButton = !canAccess && widget.content.isPaid && !_isSubscribed && !isCreator;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre et badge
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.content.titre,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.content.isPaid ? Colors.amber.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.content.isPaid ? '${widget.content.priceCoins} coins' : 'Gratuit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.content.isPaid ? Colors.amber.shade800 : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Description
          Text(
            widget.content.description,
            style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          // Séparateur
          const Divider(),
          const SizedBox(height: 12),
          // Créateur
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatorProfilePage(userId: _creatorProfile?.userId ?? widget.content.creatorUserId),
                ),
              );
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: _creatorProfile?.imageUrl != null ? NetworkImage(_creatorProfile!.imageUrl) : null,
                  child: (_creatorProfile?.imageUrl ?? '').isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _creatorProfile?.pseudo ?? 'Créateur',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_creatorProfile?.subscribersCount ?? 0} abonnés',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (showSubscribeButton)
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
                      side: BorderSide(color: primaryRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text('S\'abonner', style: TextStyle(color: primaryRed)),
                  ),
              ],
            ),
          ),
          if (!canAccess && widget.content.isPaid && !isCreator) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _handlePurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('Débloquer maintenant'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLikeButton() {
    final canAccess = _canAccessContent();
    final isCreator = _creatorProfile != null && _creatorProfile!.userId == Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;
    final isDisabled = (!canAccess && !isCreator) || _isLoading;

    return Center(
      child: GestureDetector(
        onTap: isDisabled ? null : _toggleLike,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _isLiked ? Colors.red : Colors.grey[200],
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _isLiked ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 32,
                  color: _isLiked ? Colors.white : Colors.grey[600],
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.content.likesCount}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isLiked ? Colors.white : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}