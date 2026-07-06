import 'package:afrotok/utils/responsive_sheet.dart';
import 'dart:async';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:afrotok/pages/contenuPayant/userAbonnerInfos.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:video_player/video_player.dart';

import 'package:chewie/chewie.dart';

import 'package:lottie/lottie.dart';

import '../../models/model_data.dart';

import '../../providers/contenuPayantProvider.dart';

import '../../providers/userProvider.dart';

import '../../providers/authProvider.dart';

import '../../widgets/chat/generic_share_sheet.dart';

import '../../services/linkService.dart';

import '../../theme/app_colors.dart';

import '../pub/native_ad_widget.dart';

import 'dart:async';

import 'dart:math';

class ContentDetailScreen extends StatefulWidget {
  final ContentPaie content;
  final Episode? episode;

  ContentDetailScreen({required this.content, this.episode});

  @override
  _ContentDetailScreenState createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> with SingleTickerProviderStateMixin {
  AppColors get _colors => AppColors.of(context);

  // Lecteur vidéo principal (NE SERT QUE POUR LES ACHETEURS)
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isFullVideoReady = false;

  // Lecteurs pour les capsules (3 extraits indépendants)
  VideoPlayerController? _capsuleStartController;
  VideoPlayerController? _capsuleMiddleController;
  VideoPlayerController? _capsuleEndController;

  bool _isCapsuleStartReady = false;
  bool _isCapsuleMiddleReady = false;
  bool _isCapsuleEndReady = false;

  // Lecteur actif pour la capsule (affiché temporairement)
  VideoPlayerController? _activeCapsuleController;
  ChewieController? _activeCapsuleChewie;
  bool _isCapsulePlaying = false;
  int _currentCapsuleIndex = -1;
  Timer? _capsuleTimer;

  bool _isPurchasing = false;
  bool _isLiked = false;
  bool _showLikeAnimation = false;
  late AnimationController _likeAnimationController;
  Episode? _currentEpisode;
  bool _isDisliked = false;
  bool _showDislikeAnimation = false;
  bool _isLikedAnimation = false;

  bool _isPreviewMode = false;      // true = utilisateur non acheteur
  double _videoDuration = 0;
  static const double _capsuleDuration = 5.0;

  final List<PreviewCapsule> _capsules = [
    PreviewCapsule(index: 0, label: 'Début', icon: Icons.play_arrow, duration: 5, position: 'start'),
    PreviewCapsule(index: 1, label: 'Milieu', icon: Icons.timeline, duration: 5, position: 'middle'),
    PreviewCapsule(index: 2, label: 'Fin', icon: Icons.stop, duration: 5, position: 'end'),
  ];
  late UserAuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _currentEpisode = widget.episode;
    _checkAccessAndInitialize();
    _incrementViews();
    _checkUserReaction();
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
  }

  Future<void> _checkAccessAndInitialize() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);

    final hasPurchased = contentProvider.userPurchases
        .any((purchase) => purchase.contentId == widget.content.id);
    final isAdminOrOwner = userProvider.loginUserData?.role == UserRole.ADM.name ||
        userProvider.loginUserData?.id == widget.content.ownerId;
    final isSeries = widget.content.isSeries;
    final isFree = isSeries ? (_currentEpisode?.isFree ?? false) : widget.content.isFree;

    if (hasPurchased || isAdminOrOwner || isFree) {
      // Utilisateur autorisé => vidéo complète
      setState(() {
        _isPreviewMode = false;
      });
      await _initializeFullVideo();
    } else {
      // Mode aperçu : vidéo principale verrouillée, capsules préparées
      setState(() {
        _isPreviewMode = true;
      });
      await _prepareCapsulesOnly();  // Ne prépare que les capsules, pas le lecteur principal
    }
  }

  /// Pour les acheteurs : charge la vidéo complète
  Future<void> _initializeFullVideo() async {
    final isSeries = widget.content.isSeries;
    String? videoUrl = isSeries && _currentEpisode != null
        ? _currentEpisode!.videoUrl
        : widget.content.videoUrl ?? '';
    if (videoUrl!.isEmpty) return;
    final String optimizedUrl = _authProvider.convertToCdnUrl(videoUrl, _authProvider.appDefaultData);
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(optimizedUrl));
    // _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await _videoPlayerController!.initialize();
    _videoDuration = _videoPlayerController!.value.duration.inSeconds.toDouble();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: false,
      looping: false,
      aspectRatio: _videoPlayerController!.value.aspectRatio,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: _colors.primary,
        handleColor: _colors.primary,
        backgroundColor: Colors.grey[700]!,
        bufferedColor: Colors.grey[500]!,
      ),
      placeholder: Container(
        color: _colors.background,
        child: Center(child: CircularProgressIndicator(color: _colors.primary)),
      ),
    );
    setState(() {
      _isFullVideoReady = true;
    });
  }

  /// Pour le mode preview : on ne charge que les 3 extraits (capsules)
  Future<void> _prepareCapsulesOnly() async {
    final isSeries = widget.content.isSeries;
    String? videoUrl = isSeries && _currentEpisode != null
        ? _currentEpisode!.videoUrl
        : widget.content.videoUrl ?? '';
    if (videoUrl!.isEmpty) return;
    final String optimizedUrl = _authProvider.convertToCdnUrl(videoUrl, _authProvider.appDefaultData);

    // Récupérer la durée de la vidéo (besoin d'un contrôleur temporaire)
    final tempController = VideoPlayerController.networkUrl(Uri.parse(optimizedUrl));
    await tempController.initialize();
    _videoDuration = tempController.value.duration.inSeconds.toDouble();
    await tempController.dispose();

    // Calcul des positions
    double startPos = 0;
    double middlePos = max(0, (_videoDuration / 2) - (_capsuleDuration / 2));
    double endPos = max(0, _videoDuration - _capsuleDuration);

    // Charger la capsule début
    _capsuleStartController = VideoPlayerController.networkUrl(Uri.parse(optimizedUrl));
    await _capsuleStartController!.initialize();
    await _capsuleStartController!.seekTo(Duration(seconds: startPos.toInt()));
    await _capsuleStartController!.pause();

    // Charger la capsule milieu
    _capsuleMiddleController = VideoPlayerController.networkUrl(Uri.parse(optimizedUrl));
    await _capsuleMiddleController!.initialize();
    await _capsuleMiddleController!.seekTo(Duration(seconds: middlePos.toInt()));
    await _capsuleMiddleController!.pause();

    // Charger la capsule fin
    _capsuleEndController = VideoPlayerController.networkUrl(Uri.parse(optimizedUrl));
    await _capsuleEndController!.initialize();
    await _capsuleEndController!.seekTo(Duration(seconds: endPos.toInt()));
    await _capsuleEndController!.pause();

    setState(() {
      _isCapsuleStartReady = true;
      _isCapsuleMiddleReady = true;
      _isCapsuleEndReady = true;
    });
  }

  /// Joue une capsule (remplace temporairement l'affichage)
  void _playCapsule(int index) async {
    if (!_isPreviewMode) return;

    // Arrêter toute capsule en cours
    _stopCapsule();

    VideoPlayerController? selected;
    switch (index) {
      case 0: selected = _capsuleStartController; break;
      case 1: selected = _capsuleMiddleController; break;
      case 2: selected = _capsuleEndController; break;
    }
    if (selected == null || !selected.value.isInitialized) return;

    // Repositionner au début de l'extrait
    double startPos = _getCapsuleStartPosition(index);
    await selected.seekTo(Duration(seconds: startPos.toInt()));

    // Créer le contrôleur Chewie pour la capsule
    _activeCapsuleController = selected;
    _activeCapsuleChewie = ChewieController(
      videoPlayerController: selected,
      autoPlay: true,
      looping: false,
      aspectRatio: selected.value.aspectRatio,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: _colors.primary,
        handleColor: _colors.primary,
        backgroundColor: Colors.grey[700]!,
        bufferedColor: Colors.grey[500]!,
      ),
    );

    setState(() {
      _isCapsulePlaying = true;
      _currentCapsuleIndex = index;
    });

    // Timer pour arrêter après 3 secondes
    _capsuleTimer = Timer(Duration(seconds: _capsuleDuration.toInt()), () {
      _stopCapsuleAndShowModal();
    });
  }

  void _stopCapsule() {
    _capsuleTimer?.cancel();
    if (_activeCapsuleChewie != null) {
      _activeCapsuleChewie!.pause();
      _activeCapsuleChewie!.dispose();
      _activeCapsuleChewie = null;
    }
    _activeCapsuleController = null;
    setState(() {
      _isCapsulePlaying = false;
      _currentCapsuleIndex = -1;
    });
  }

  void _stopCapsuleAndShowModal() {
    _stopCapsule();
    _showPurchaseIncentiveModal();
  }

  double _getCapsuleStartPosition(int segment) {
    switch (segment) {
      case 0: return 0;
      case 1: return max(0, (_videoDuration / 2) - (_capsuleDuration / 2));
      case 2: return max(0, _videoDuration - _capsuleDuration);
      default: return 0;
    }
  }

  void _showPurchaseIncentiveModal() {
    final selectedCapsule = _capsules.firstWhere((c) => c.index == _currentCapsuleIndex, orElse: () => _capsules[0]);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _colors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _colors.accent, width: 2),
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_filled, color: _colors.accent, size: 60),
              SizedBox(height: 16),
              Text('✨ Extrait visionné ! ✨', style: TextStyle(color: _colors.accent, fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('Vous avez vu ${_capsuleDuration.toInt()} secondes de l\'extrait "${selectedCapsule.label}".', style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
              SizedBox(height: 20),
              Text('Convaincu ? Débloquez l\'intégralité de ce contenu !', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text('💰 ${widget.content.price.toInt()} FCFA seulement', style: TextStyle(color: _colors.accent, fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Votre soutien permet aux artistes de créer plus de contenu', style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.grey)),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Plus tard',style: TextStyle(fontSize: 12),),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(foregroundColor: _colors.background, backgroundColor: _colors.accent),
                      onPressed: _isPurchasing ? null : () { Navigator.pop(context); _handlePurchase(); },
                      child: _isPurchasing ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('ACHETER', style: TextStyle(fontWeight: FontWeight.bold,fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

// ==================== GESTION DES INTERACTIONS ====================

  void _checkUserReaction() async {
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final currentUserId = userProvider.loginUserData?.id;

    if (currentUserId == null) return;

    bool isLiked = false;
    bool isDisliked = false;

    if (widget.content.isSeries && _currentEpisode != null) {
      isLiked = await contentProvider.isEpisodeLikedByUser(_currentEpisode!.id!, currentUserId);
      isDisliked = await contentProvider.isEpisodeDislikedByUser(_currentEpisode!.id!, currentUserId);
    } else {
      isLiked = widget.content.isLikedByUser(currentUserId);
      isDisliked = widget.content.isDislikedByUser(currentUserId);
    }

    setState(() {
      _isLiked = isLiked;
      _isDisliked = isDisliked;
    });
  }

  void _handleLike() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = userProvider.loginUserData?.id;

    if (currentUserId == null) return;

    setState(() {
      if (_isDisliked) _isDisliked = false;
      _isLiked = !_isLiked;
      _showLikeAnimation = _isLiked;
    });

    if (_isLiked) {
      _likeAnimationController.reset();
      _likeAnimationController.forward();
      _triggerLikeAnimation();
    }

    if (widget.content.isSeries && _currentEpisode != null) {
      if (_isLiked) {
        await contentProvider.likeEpisode(_currentEpisode!.id!, currentUserId);
      } else {
        await contentProvider.removeLikeEpisode(_currentEpisode!.id!, currentUserId);
      }
    } else {
      if (_isLiked) {
        await contentProvider.likeContent(widget.content.id!, currentUserId);
      } else {
        await contentProvider.removeLikeContent(widget.content.id!, currentUserId);
      }
    }
  }

  void _handleDislike() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = userProvider.loginUserData?.id;

    if (currentUserId == null) return;

    setState(() {
      if (_isLiked) _isLiked = false;
      _isDisliked = !_isDisliked;
      _showDislikeAnimation = _isDisliked;
    });

    if (_isDisliked) {
      _likeAnimationController.reset();
      _likeAnimationController.forward();
      _triggerDislikeAnimation();
    }

    if (widget.content.isSeries && _currentEpisode != null) {
      if (_isDisliked) {
        await contentProvider.dislikeEpisode(_currentEpisode!.id!, currentUserId);
      } else {
        await contentProvider.removeDislikeEpisode(_currentEpisode!.id!, currentUserId);
      }
    } else {
      if (_isDisliked) {
        await contentProvider.dislikeContent(widget.content.id!, currentUserId);
      } else {
        await contentProvider.removeDislikeContent(widget.content.id!, currentUserId);
      }
    }
  }

  void _triggerDislikeAnimation() {
    Future.delayed(Duration(milliseconds: 1000), () {
      setState(() => _showDislikeAnimation = false);
    });
  }

  void _triggerLikeAnimation() {
    Future.delayed(Duration(milliseconds: 1000), () {
      setState(() => _showLikeAnimation = false);
    });
  }

  void _incrementViews() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    if (widget.content.isSeries && _currentEpisode != null) {
      await contentProvider.incrementViews(_currentEpisode!.id!, isEpisode: true);
    } else {
      await contentProvider.incrementViews(widget.content.id!);
    }
  }

  Future<void> _handlePurchase() async {
    setState(() => _isPurchasing = true);

    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);

    final result = await contentProvider.purchaseContentPaie(
        userProvider.loginUserData!,
        widget.content,
        context
    );

    setState(() => _isPurchasing = false);

    if (result == PurchaseResult.success) {
      contentProvider.loadUserPurchases();
      // Recharger la page pour passer en mode acheté
      _checkAccessAndInitialize();
      _showSuccessModal();
    } else if (result == PurchaseResult.alreadyPurchased) {
      _showAlreadyPurchasedModal();
      _checkAccessAndInitialize();
    }
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(color: _colors.background, borderRadius: BorderRadius.circular(20)),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: _colors.primary, size: 60),
                SizedBox(height: 20),
                Text('Achat Réussi!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text('Le contenu a été débloqué avec succès.', style: TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _colors.primary,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: Text('Regarder maintenant'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAlreadyPurchasedModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(color: _colors.background, borderRadius: BorderRadius.circular(20)),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: _colors.accent, size: 60),
                SizedBox(height: 20),
                Text('Déjà Acheté', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text('Vous avez déjà acheté ce contenu.', style: TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _colors.accent,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
                    setState(() => contentProvider.loadUserPurchases());
                  },
                  child: Text('Actualiser'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('Supprimer le contenu ?'),
        content: Text(
          widget.content.isSeries
              ? 'Êtes-vous sûr de vouloir supprimer cette série et tous ses épisodes ? Cette action est irréversible.'
              : 'Êtes-vous sûr de vouloir supprimer ce contenu ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              bool success = false;
              final contentProvider = Provider.of<ContentProvider>(context, listen: false);

              if (widget.content.isSeries) {
                success = await contentProvider.deleteContentPaie(widget.content.id!);
              } else if (widget.episode != null) {
                success = await contentProvider.deleteEpisode(widget.episode!.id!);
              } else {
                success = await contentProvider.deleteContentPaie(widget.content.id!);
              }

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suppression réussie !'), backgroundColor: Colors.green));
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la suppression.'), backgroundColor: Colors.red));
              }
            },
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdMrec({required String key}) {
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
        onAdLoaded: () {
          printVm('✅ Native Ad Afrolook chargée: $key');
        },
      ),
    );
  }

  Widget _buildSeriesInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.content.title!, style: TextStyle(color: _colors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Série', style: TextStyle(color: _colors.accent, fontSize: 16, fontWeight: FontWeight.w500)),
        SizedBox(height: 16),
        if (_currentEpisode != null) ...[
          Text('Épisode: ${_currentEpisode!.title}', style: TextStyle(color: _colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Épisode ${_currentEpisode!.episodeNumber}', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSimpleContentInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.content.title!, style: TextStyle(color: _colors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
      ],
    );
  }

// ==================== GESTION DU PARTAGE ====================

  bool _isSharing = false;

  void _handleShare() async {
    if (_isSharing) return;
    showResponsiveBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Partager (lien externe)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _isSharing = true);
                  try {
                    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
                    final svc = AppLinkService();
                    if (widget.episode == null) {
                      svc.shareContent(
                        type: AppLinkType.contentpaie,
                        id: widget.content.id!,
                        message: widget.content.description,
                        mediaUrl: widget.content.thumbnailUrl ?? '',
                      );
                    } else {
                      svc.shareContent(
                        type: AppLinkType.contentpaie,
                        id: widget.content.id!,
                        message: widget.episode!.description ?? '',
                        mediaUrl: widget.episode!.thumbnailUrl ?? '',
                      );
                    }
                    unawaited((widget.content.isSeries && _currentEpisode != null)
                        ? contentProvider.incrementShares(_currentEpisode!.id!, isEpisode: true)
                        : contentProvider.incrementShares(widget.content.id!));
                    await Future.delayed(const Duration(milliseconds: 500));
                  } catch (_) {}
                  finally { if (mounted) setState(() => _isSharing = false); }
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: const Text('Envoyer dans un chat'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareContentToChat();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _shareContentToChat() {
    final thumb = widget.content.thumbnailUrl ?? '';
    final typeLabel = widget.content.isSeries ? 'Série VIP' : 'Contenu VIP';
    showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GenericShareSheet(
        itemId: widget.content.id ?? '',
        itemType: 'vip',
        title: widget.content.title,
        subtitle: typeLabel,
        thumbnail: thumb,
        icon: Icons.star_rounded,
      ),
    );
  }

  @override
  void dispose() {
    _capsuleTimer?.cancel();
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _capsuleStartController?.dispose();
    _capsuleMiddleController?.dispose();
    _capsuleEndController?.dispose();
    _activeCapsuleChewie?.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  Widget _buildCapsulesSection() {
    if (!_isPreviewMode) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _colors.background.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.visibility, color: _colors.accent, size: 18), SizedBox(width: 8), Text('🔍 Aperçu gratuit (5 secondes par extrait)', style: TextStyle(color: _colors.accent, fontSize: 14, fontWeight: FontWeight.bold))]),
          SizedBox(height: 12),
          Text('Cliquez sur un extrait pour voir un aperçu - Lecture instantanée', style: TextStyle(color: Colors.white70, fontSize: 12)),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _capsules.map((capsule) {
              bool isReady = capsule.index == 0 ? _isCapsuleStartReady : (capsule.index == 1 ? _isCapsuleMiddleReady : _isCapsuleEndReady);
              bool isLoading = _currentCapsuleIndex == capsule.index && _isCapsulePlaying;
              return Expanded(
                child: GestureDetector(
                  onTap: (isReady && !isLoading) ? () => _playCapsule(capsule.index) : null,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isLoading ? LinearGradient(colors: [_colors.primary, _colors.primary.withOpacity(0.7)]) : null,
                      color: !isReady ? Colors.grey[800] : (isLoading ? null : _colors.background.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isLoading ? _colors.primary : (isReady ? _colors.accent.withOpacity(0.5) : Colors.grey[700]!), width: 1),
                    ),
                    child: !isReady
                        ? Column(children: [SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _colors.accent, strokeWidth: 2)), SizedBox(height: 8), Text('Chargement...', style: TextStyle(color: _colors.accent, fontSize: 11))])
                        : isLoading
                        ? Column(children: [SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _colors.accent, strokeWidth: 2)), SizedBox(height: 8), Text('Lecture...', style: TextStyle(color: _colors.accent, fontSize: 11))])
                        : Column(children: [Icon(capsule.icon, color: _colors.accent, size: 28), SizedBox(height: 8), Text(capsule.label, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)), SizedBox(height: 4), Text('${_capsuleDuration.toInt()} sec', style: TextStyle(color: Colors.white54, fontSize: 10))]),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final isAdminOrOwner = userProvider.loginUserData?.role == UserRole.ADM.name ||
        userProvider.loginUserData?.id == widget.content.ownerId;
    final hasPurchased = contentProvider.userPurchases.any((p) => p.contentId == widget.content.id);
    final isSeries = widget.content.isSeries;
    bool canWatch = (isSeries ? (_currentEpisode?.isFree ?? false) : widget.content.isFree) || hasPurchased || isAdminOrOwner;
    String thumbnailUrl = _authProvider.convertToCdnUrl(
      isSeries && _currentEpisode != null ? _currentEpisode!.thumbnailUrl! : widget.content.thumbnailUrl ?? '',
      _authProvider.appDefaultData,
    );

    return Scaffold(
      backgroundColor: _colors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                floating: false,
                pinned: true,
                backgroundColor: _colors.background,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(color: Colors.grey[900]),
                        errorWidget: (context, url, error) => Container(color: Colors.grey[900], child: Icon(Icons.error, color: Colors.white)),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [_colors.background.withOpacity(0.9), _colors.background.withOpacity(0.3), Colors.transparent],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      // Affichage principal : soit la vidéo complète (si acheté), soit l'overlay verrouillé
                      if (canWatch && _isFullVideoReady && _chewieController != null)
                        Positioned.fill(child: Chewie(controller: _chewieController!))
                      else if (!canWatch && _isPreviewMode)
                        Positioned.fill(
                          child: Container(
                            color: _colors.background.withOpacity(0.85),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_outline, size: 60, color: _colors.textPrimary),
                                  SizedBox(height: 16),
                                  Text('Contenu premium', style: TextStyle(color: _colors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 8),
                                  Text('Débloquez ce contenu pour le regarder', style: TextStyle(color: Colors.white70, fontSize: 16)),
                                  SizedBox(height: 8),
                                  Text('Utilisez les aperçus ci-dessous pour juger de la qualité', style: TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (canWatch && !_isFullVideoReady)
                          Positioned.fill(child: Center(child: CircularProgressIndicator(color: _colors.accent))),
                      // Superposition temporaire de la capsule en cours de lecture
                      if (_isPreviewMode && _isCapsulePlaying && _activeCapsuleChewie != null)
                        Positioned.fill(
                          child: Container(
                            color: _colors.background,
                            child: Chewie(controller: _activeCapsuleChewie!),
                          ),
                        ),
                    ],
                  ),
                ),
                leading: IconButton(icon: Icon(Icons.arrow_back, color: _colors.textPrimary), onPressed: () => Navigator.pop(context)),
                actions: [
                  if (isAdminOrOwner) IconButton(icon: Icon(Icons.delete_outline, color: Colors.red), onPressed: _showDeleteModal),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      widget.content.isSeries ? _buildSeriesInfo() : _buildSimpleContentInfo(),
                      SizedBox(height: 5),
                      _buildAdMrec(key: 'ad_native_content_details'),
                      SizedBox(height: 5),
                      ContentOwnerInfo(ownerId: widget.content.ownerId),
                      // Ligne des stats
                      Row(
                        children: [
                          _buildStatButton(Icons.share, _isSharing ? null : _handleShare, widget.content.shares, _isSharing),
                          _buildStatButton(Icons.thumb_down, _handleDislike, widget.content.dislikes, false, isActive: _isDisliked, activeColor: Colors.blue),
                          _buildStatButton(Icons.favorite, _handleLike, widget.content.likes, false, isActive: _isLiked, activeColor: Colors.red),
                          _buildStatButton(Icons.visibility, null, widget.content.views, false),
                          Spacer(),
                          if (!widget.content.isFree && (!widget.content.isSeries || (widget.content.isSeries && _currentEpisode != null && !_currentEpisode!.isFree)))
                            Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _colors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: _colors.accent)), child: Text('PREMIUM', style: TextStyle(color: _colors.accent, fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      SizedBox(height: 20),
                      // SECTION CAPSULES (uniquement pour les non-acheteurs)
                      _buildCapsulesSection(),
                      SizedBox(height: 10),
                      Text(widget.content.description ?? '', style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
                      SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _colors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _colors.primary.withOpacity(0.3))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [Icon(Icons.favorite, color: _colors.primary, size: 16), SizedBox(width: 8), Text('Soutenez les créateurs', style: TextStyle(color: _colors.primary, fontSize: 16, fontWeight: FontWeight.bold))]),
                            SizedBox(height: 8),
                            Text('En achetant ce contenu, vous soutenez directement les artistes et leur permettez de créer plus de vidéos de qualité.', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      if (!canWatch && _isPreviewMode)
                        Container(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(foregroundColor: _colors.background, backgroundColor: _colors.accent, padding: EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            onPressed: _isPurchasing ? null : _handlePurchase,
                            child: _isPurchasing ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _colors.background, strokeWidth: 2)) : Text('SOUTENIR LES CRÉATEURS - ${widget.content.price.toInt()} F', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        )
                      else if (canWatch && _isFullVideoReady && _chewieController != null)
                        Container(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(foregroundColor: _colors.textPrimary, backgroundColor: _colors.primary, padding: EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            onPressed: () {
                              if (_chewieController!.isPlaying) _chewieController!.pause();
                              else _chewieController!.play();
                            },
                            child: Text(_chewieController!.isPlaying ? 'PAUSER' : 'JOUER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      SizedBox(height: 20),
                      if (widget.content.hashtags != null && widget.content.hashtags!.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tags:', style: TextStyle(color: _colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: widget.content.hashtags!.map((hashtag) => Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _colors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: _colors.primary)), child: Text('#$hashtag', style: TextStyle(color: _colors.primary)))).toList(),
                            ),
                          ],
                        ),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showLikeAnimation)
            Positioned.fill(
              child: Center(
                child: IgnorePointer(
                  child: AnimatedScale(
                    scale: _isLikedAnimation ? 1.5 : 1.0,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Icon(Icons.favorite, color: Colors.red, size: 100),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatButton(IconData icon, VoidCallback? onTap, int count, bool isLoading, {bool isActive = false, Color activeColor = Colors.red}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: _colors.background.withOpacity(0.5), shape: BoxShape.circle),
            child: isLoading ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _colors.accent, strokeWidth: 2)) : Icon(icon, color: isActive ? activeColor : _colors.textPrimary, size: 24),
          ),
        ),
        SizedBox(height: 1),
        Text('$count', style: TextStyle(color: isActive ? activeColor : _colors.textPrimary, fontSize: 12)),
      ],
    );
  }
}

class PreviewCapsule {
  final int index;
  final String label;
  final IconData icon;
  final int duration;
  final String position;
  PreviewCapsule({required this.index, required this.label, required this.icon, required this.duration, required this.position});
}

enum PurchaseResult { success, insufficientBalance, alreadyPurchased, error }

//
// class ContentDetailScreen extends StatefulWidget {
//   final ContentPaie content;
//   final Episode? episode;
//
//   ContentDetailScreen({required this.content, this.episode});
//
//   @override
//   _ContentDetailScreenState createState() => _ContentDetailScreenState();
// }
//
// class _ContentDetailScreenState extends State<ContentDetailScreen> with SingleTickerProviderStateMixin {
//   late VideoPlayerController _videoPlayerController;
//   late ChewieController _chewieController;
//   bool _isVideoInitialized = false;
//   bool _isPurchasing = false;
//   bool _isLiked = false;
//   bool _showLikeAnimation = false;
//   late AnimationController _likeAnimationController;
//   bool _isLikedAnimation = false;
//   Episode? _currentEpisode;
//   bool _isDisliked = false; // NOUVEAU: état pour le dislike
//   bool _showDislikeAnimation = false; // NOUVEAU
//   @override
//   void initState() {
//     super.initState();
//     _currentEpisode = widget.episode;
//     _initializeVideo();
//     _incrementViews();
//     // Récupérer l'état actuel du like/dislike de l'utilisateur
//     _checkUserReaction(); // NOUVEAU
//     _likeAnimationController = AnimationController(
//       vsync: this,
//       duration: Duration(milliseconds: 1500),
//     );
//   }
//   Widget _buildAdMrec({required String key}) {
//     // return SizedBox.shrink();
//
//     return Container(
//       key: ValueKey(key),
//       margin: EdgeInsets.symmetric(vertical: 16),
//       decoration: BoxDecoration(
//         color: Colors.transparent,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.transparent),
//       ),
//       child: MrecAdWidget(
//         key: ValueKey(key),
//         // templateType: TemplateType.medium, // ou TemplateType.small
//
//         onAdLoaded: () {
//           printVm('✅ Native Ad Afrolook chargée: $key');
//         },
//       ),
//       // child: BannerAdWidget(
//       //   onAdLoaded: () {
//       //     printVm('✅ Bannière Afrolook chargée: $key');
//       //   },
//       // ),
//     );
//   }
//
// // NOUVEAU: Méthode pour vérifier la réaction de l'utilisateur
//   void _checkUserReaction() async {
//     final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//     final currentUserId = userProvider.loginUserData?.id;
//
//     if (currentUserId == null) return;
//
//     bool isLiked = false;
//     bool isDisliked = false;
//
//     if (widget.content.isSeries && _currentEpisode != null) {
//       // Pour les épisodes, vous devrez adapter votre ContentProvider
//       // pour récupérer les réactions spécifiques aux épisodes
//       isLiked = await contentProvider.isEpisodeLikedByUser(
//           _currentEpisode!.id!, currentUserId);
//       isDisliked = await contentProvider.isEpisodeDislikedByUser(
//           _currentEpisode!.id!, currentUserId);
//     } else {
//       isLiked = widget.content.isLikedByUser(currentUserId);
//       isDisliked = widget.content.isDislikedByUser(currentUserId);
//     }
//
//     setState(() {
//       _isLiked = isLiked;
//       _isDisliked = isDisliked;
//     });
//   }
//
//   // MODIFIÉ: Gérer le like
//   void _handleLike() async {
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//     final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final currentUserId = userProvider.loginUserData?.id;
//
//     if (currentUserId == null) return;
//
//     setState(() {
//       if (_isDisliked) {
//         _isDisliked = false;
//       }
//       _isLiked = !_isLiked;
//       _showLikeAnimation = _isLiked;
//     });
//
//     if (_isLiked) {
//       _likeAnimationController.reset();
//       _likeAnimationController.forward();
//       _triggerLikeAnimation();
//     }
//
//     // Gérer le like/dislike dans Firestore
//     if (widget.content.isSeries && _currentEpisode != null) {
//       if (_isLiked) {
//         await contentProvider.likeEpisode(
//             _currentEpisode!.id!, currentUserId);
//       } else {
//         await contentProvider.removeLikeEpisode(
//             _currentEpisode!.id!, currentUserId);
//       }
//     } else {
//       if (_isLiked) {
//         await contentProvider.likeContent(
//             widget.content.id!, currentUserId);
//       } else {
//         await contentProvider.removeLikeContent(
//             widget.content.id!, currentUserId);
//       }
//     }
//   }
//
//   // NOUVEAU: Gérer le dislike
//   void _handleDislike() async {
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//     final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final currentUserId = userProvider.loginUserData?.id;
//
//     if (currentUserId == null) return;
//
//     setState(() {
//       if (_isLiked) {
//         _isLiked = false;
//       }
//       _isDisliked = !_isDisliked;
//       _showDislikeAnimation = _isDisliked;
//     });
//
//     if (_isDisliked) {
//       _likeAnimationController.reset();
//       _likeAnimationController.forward();
//       _triggerDislikeAnimation();
//     }
//
//     // Gérer le dislike dans Firestore
//     if (widget.content.isSeries && _currentEpisode != null) {
//       if (_isDisliked) {
//         await contentProvider.dislikeEpisode(
//             _currentEpisode!.id!, currentUserId);
//       } else {
//         await contentProvider.removeDislikeEpisode(
//             _currentEpisode!.id!, currentUserId);
//       }
//     } else {
//       if (_isDisliked) {
//         await contentProvider.dislikeContent(
//             widget.content.id!, currentUserId);
//       } else {
//         await contentProvider.removeDislikeContent(
//             widget.content.id!, currentUserId);
//       }
//     }
//   }
//
//   // NOUVEAU: Animation pour le dislike
//   void _triggerDislikeAnimation() {
//     Future.delayed(Duration(milliseconds: 1000), () {
//       setState(() {
//         _showDislikeAnimation = false;
//       });
//     });
//   }
// // Dans votre widget, ajoutez cette variable d'état
//   bool _isSharing = false;
//
// // Version optimisée de _handleShare
//   void _handleShare() async {
//     // Éviter les doubles clics
//     if (_isSharing) return;
//
//     setState(() {
//       _isSharing = true;
//     });
//
//     try {
//       final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//       final _appLinkService = AppLinkService();
//
//       // Lancer le partage immédiatement (ne pas attendre)
//       if (widget.episode == null) {
//         _appLinkService.shareContent(
//           type: AppLinkType.contentpaie,
//           id: widget.content.id!,
//           message: "${widget.content.description}",
//           mediaUrl: widget.content.thumbnailUrl!.isNotEmpty
//               ? "${widget.content.thumbnailUrl!}"
//               : "",
//         );
//       } else {
//         _appLinkService.shareContent(
//           type: AppLinkType.contentpaie,
//           id: widget.content.id!,
//           message: "${widget.episode!.description}",
//           mediaUrl: widget.episode!.thumbnailUrl!.isNotEmpty
//               ? "${widget.episode!.thumbnailUrl!}"
//               : "",
//         );
//       }
//
//       // Incrémenter le compteur en arrière-plan (ne pas bloquer avec await)
//       unawaited(
//           (widget.content.isSeries && _currentEpisode != null)
//               ? contentProvider.incrementShares(_currentEpisode!.id!, isEpisode: true)
//               : contentProvider.incrementShares(widget.content.id!)
//       );
//
//       // Petit délai pour éviter un flash trop rapide (optionnel)
//       await Future.delayed(Duration(milliseconds: 500));
//
//     } catch (e) {
//       printVm('Erreur lors du partage: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Erreur lors du partage'),
//             backgroundColor: Colors.red,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isSharing = false;
//         });
//       }
//     }
//   }
//   void _handleShare2() async {
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//     final _appLinkService = AppLinkService();
//
//     // Incrémenter le compteur de partages
//     if (widget.content.isSeries && _currentEpisode != null) {
//       await contentProvider.incrementShares(_currentEpisode!.id!, isEpisode: true);
//     } else {
//       await contentProvider.incrementShares(widget.content.id!);
//     }
//
//     // Partager le contenu
//     if (widget.episode == null) {
//       _appLinkService.shareContent(
//         type: AppLinkType.contentpaie,
//         id: widget.content.id!,
//         message: "${widget.content.description}",
//         mediaUrl: widget.content.thumbnailUrl!.isNotEmpty
//             ? "${widget.content.thumbnailUrl!}"
//             : "",
//       );
//     } else {
//       _appLinkService.shareContent(
//         type: AppLinkType.contentpaie,
//         id: widget.content.id!,
//         message: "${widget.episode!.description}",
//         mediaUrl: widget.episode!.thumbnailUrl!.isNotEmpty
//             ? "${widget.episode!.thumbnailUrl!}"
//             : "",
//       );
//     }
//   }
//
//   void _showDeleteModal() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         title: Text('Supprimer le contenu ?'),
//         content: Text(
//           widget.content.isSeries
//               ? 'Êtes-vous sûr de vouloir supprimer cette série et tous ses épisodes ? Cette action est irréversible.'
//               : 'Êtes-vous sûr de vouloir supprimer ce contenu ? Cette action est irréversible.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Annuler'),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             onPressed: () async {
//               Navigator.pop(context); // fermer le modal
//
//               bool success = false;
//               final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//
//               if (widget.content.isSeries) {
//                 // Supprimer série + épisodes
//                 success = await contentProvider.deleteContentPaie(widget.content.id!);
//               } else if (widget.episode != null) {
//                 // Supprimer un épisode spécifique
//                 success = await contentProvider.deleteEpisode(widget.episode!.id!);
//               } else {
//                 // Supprimer un contenu simple
//                 success = await contentProvider.deleteContentPaie(widget.content.id!);
//               }
//
//               if (success) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('Suppression réussie !'),
//                     backgroundColor: Colors.green,
//                   ),
//                 );
//                 Navigator.pop(context); // revenir à la page précédente
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('Erreur lors de la suppression.'),
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//               }
//             },
//             child: Text('Supprimer'),
//           ),
//         ],
//       ),
//     );
//   }
//
//
//   void _triggerLikeAnimation() {
//     Future.delayed(Duration(milliseconds: 1000), () {
//       setState(() {
//         _showLikeAnimation = false;
//       });
//     });
//   }
//
//   void _initializeVideo() async {
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//
//     // Vérifier si l'utilisateur a acheté le contenu
//     bool hasPurchased = contentProvider.userPurchases
//         .any((purchase) => purchase.contentId == widget.content.id);
//
//     // Déterminer si c'est une série avec épisodes
//     bool isSeries = widget.content.isSeries;
//     String? videoUrl = isSeries && _currentEpisode != null
//         ? _currentEpisode!.videoUrl
//         : widget.content.videoUrl ?? '';
//     final userProvider = Provider.of<UserAuthProvider>(context,listen: false);
//     final isAdminOrOwner = userProvider.loginUserData?.role == UserRole.ADM.name ||
//         userProvider.loginUserData?.id == widget.content.ownerId;
//
//     bool canWatch = (isSeries ? (_currentEpisode?.isFree ?? false) : widget.content.isFree)
//         || hasPurchased
//         || isAdminOrOwner; // ajouté
//
//     // bool canWatch = (isSeries ? _currentEpisode?.isFree ?? false : widget.content.isFree) || hasPurchased;
//
//     if (canWatch && videoUrl!.isNotEmpty) {
//       _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
//       await _videoPlayerController.initialize();
//
//       _chewieController = ChewieController(
//         videoPlayerController: _videoPlayerController,
//         autoPlay: false,
//         looping: false,
//         aspectRatio: _videoPlayerController.value.aspectRatio,
//         showControls: true,
//         materialProgressColors: ChewieProgressColors(
//           playedColor: _colors.primary,
//           handleColor: _colors.primary,
//           backgroundColor: Colors.grey[700]!,
//           bufferedColor: Colors.grey[500]!,
//         ),
//         placeholder: Container(
//           color: _colors.background,
//           child: Center(
//             child: CircularProgressIndicator(color: _colors.primary),
//           ),
//         ),
//       );
//
//       setState(() {
//         _isVideoInitialized = true;
//       });
//     }
//   }
//
//   void _incrementViews() async {
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//
//     // Incrémenter les vues de l'épisode si c'est une série, sinon du contenu
//     if (widget.content.isSeries && _currentEpisode != null) {
//       await contentProvider.incrementViews(_currentEpisode!.id!,isEpisode: true);
//     } else {
//       await contentProvider.incrementViews(widget.content.id!);
//     }
//   }
//
//   void _handleLike2() async {
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//
//     setState(() {
//       _isLiked = !_isLiked;
//       _showLikeAnimation = true;
//     });
//
//     _likeAnimationController.reset();
//     _likeAnimationController.forward();
//     _triggerLikeAnimation();
//
//     // Gérer le like selon qu'il s'agit d'un épisode ou d'un contenu simple
//     if (widget.content.isSeries && _currentEpisode != null) {
//       await contentProvider.toggleLike(_currentEpisode!.id!,isEpisode: true );
//     } else {
//       await contentProvider.toggleLike(widget.content.id!);
//     }
//   }
//
//   @override
//   void dispose() {
//     if (_isVideoInitialized) {
//       _videoPlayerController.dispose();
//       _chewieController.dispose();
//     }
//     _likeAnimationController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _handlePurchase() async {
//     setState(() {
//       _isPurchasing = true;
//     });
//
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//     final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
//
//     final result = await contentProvider.purchaseContentPaie(
//         userProvider.loginUserData!,
//         widget.content,
//         context
//     );
//
//     setState(() {
//       _isPurchasing = false;
//     });
//
//     if (result == PurchaseResult.success) {
//       contentProvider.loadUserPurchases();
//       _showSuccessModal();
//       setState(() {});
//     } else if (result == PurchaseResult.alreadyPurchased) {
//       _showAlreadyPurchasedModal();
//     }
//   }
//
//   void _showSuccessModal() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: Colors.transparent,
//           child: Container(
//             decoration: BoxDecoration(
//               color: _colors.background,
//               borderRadius: BorderRadius.circular(20),
//             ),
//             padding: EdgeInsets.all(24),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   Icons.check_circle,
//                   color: _colors.primary,
//                   size: 60,
//                 ),
//                 SizedBox(height: 20),
//                 Text(
//                   'Achat Réussi!',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 SizedBox(height: 12),
//                 Text(
//                   'Le contenu a été débloqué avec succès.',
//                   style: TextStyle(
//                     color: Colors.white70,
//                     fontSize: 16,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 24),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     backgroundColor: _colors.primary,
//                     padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   onPressed: () {
//                     Navigator.pop(context);
//                     setState(() {});
//                   },
//                   child: Text('Regarder maintenant'),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   void _showAlreadyPurchasedModal() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: Colors.transparent,
//           child: Container(
//             decoration: BoxDecoration(
//               color: _colors.background,
//               borderRadius: BorderRadius.circular(20),
//             ),
//             padding: EdgeInsets.all(24),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   Icons.info_outline,
//                   color: _colors.accent,
//                   size: 60,
//                 ),
//                 SizedBox(height: 20),
//                 Text(
//                   'Déjà Acheté',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 SizedBox(height: 12),
//                 Text(
//                   'Vous avez déjà acheté ce contenu.',
//                   style: TextStyle(
//                     color: Colors.white70,
//                     fontSize: 16,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 24),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     backgroundColor: _colors.accent,
//                     padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   onPressed: () {
//                     Navigator.pop(context);
//                     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//                     setState(() {
//                       contentProvider.loadUserPurchases();
//                     });
//                   },
//                   child: Text('Actualiser'),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   void _selectEpisode(Episode episode) {
//     setState(() {
//       _currentEpisode = episode;
//       _isVideoInitialized = false;
//     });
//     _initializeVideo();
//   }
//
//   Widget _buildSeriesInfo() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           widget.content.title!,
//           style: TextStyle(
//             color: _colors.textPrimary,
//             fontSize: 28,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         SizedBox(height: 8),
//         Text(
//           'Série',
//           style: TextStyle(
//             color: _colors.accent,
//             fontSize: 16,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         SizedBox(height: 16),
//         if (_currentEpisode != null) ...[
//           Text(
//             'Épisode: ${_currentEpisode!.title}',
//             style: TextStyle(
//               color: _colors.textPrimary,
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             // 'Saison ${_currentEpisode!.}, Épisode ${_currentEpisode!.episodeNumber}',
//             'Épisode ${_currentEpisode!.episodeNumber}',
//             style: TextStyle(
//               color: Colors.white70,
//               fontSize: 14,
//             ),
//           ),
//         ],
//         SizedBox(height: 16),
//       ],
//     );
//   }
//
//   Widget _buildSimpleContentInfo() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           widget.content.title!,
//           style: TextStyle(
//             color: _colors.textPrimary,
//             fontSize: 28,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         SizedBox(height: 12),
//       ],
//     );
//   }
//
//   // Widget _buildEpisodeSelector() {
//   //   if (!widget.content.isSeries || widget.content.episodes == null || widget.content.episodes!.isEmpty) {
//   //     return SizedBox();
//   //   }
//   //
//   //   return Column(
//   //     crossAxisAlignment: CrossAxisAlignment.start,
//   //     children: [
//   //       Text(
//   //         'Épisodes:',
//   //         style: TextStyle(
//   //           color: _colors.textPrimary,
//   //           fontSize: 18,
//   //           fontWeight: FontWeight.bold,
//   //         ),
//   //       ),
//   //       SizedBox(height: 12),
//   //       Container(
//   //         height: 120,
//   //         child: ListView.builder(
//   //           scrollDirection: Axis.horizontal,
//   //           itemCount: widget.content.episodes!.length,
//   //           itemBuilder: (context, index) {
//   //             final episode = widget.content.episodes![index];
//   //             final isSelected = _currentEpisode?.id == episode.id;
//   //
//   //             return GestureDetector(
//   //               onTap: () => _selectEpisode(episode),
//   //               child: Container(
//   //                 width: 160,
//   //                 margin: EdgeInsets.only(right: 12),
//   //                 decoration: BoxDecoration(
//   //                   color: isSelected ? _colors.primary.withOpacity(0.2) : _colors.background.withOpacity(0.5),
//   //                   borderRadius: BorderRadius.circular(8),
//   //                   border: Border.all(
//   //                     color: isSelected ? _colors.primary : Colors.transparent,
//   //                     width: 2,
//   //                   ),
//   //                 ),
//   //                 child: Column(
//   //                   crossAxisAlignment: CrossAxisAlignment.start,
//   //                   children: [
//   //                     Expanded(
//   //                       child: ClipRRect(
//   //                         borderRadius: BorderRadius.only(
//   //                           topLeft: Radius.circular(8),
//   //                           topRight: Radius.circular(8),
//   //                         ),
//   //                         child: CachedNetworkImage(
//   //                           imageUrl: episode.thumbnailUrl,
//   //                           fit: BoxFit.cover,
//   //                           width: double.infinity,
//   //                           placeholder: (context, url) => Container(
//   //                             color: Colors.grey[900],
//   //                           ),
//   //                           errorWidget: (context, url, error) => Container(
//   //                             color: Colors.grey[900],
//   //                             child: Icon(Icons.error, color: Colors.white),
//   //                           ),
//   //                         ),
//   //                       ),
//   //                     ),
//   //                     Padding(
//   //                       padding: EdgeInsets.all(8),
//   //                       child: Text(
//   //                         'E${episode.episodeNumber}: ${episode.title}',
//   //                         style: TextStyle(
//   //                           color: _colors.textPrimary,
//   //                           fontSize: 12,
//   //                           fontWeight: FontWeight.w500,
//   //                         ),
//   //                         maxLines: 1,
//   //                         overflow: TextOverflow.ellipsis,
//   //                       ),
//   //                     ),
//   //                   ],
//   //                 ),
//   //               ),
//   //             );
//   //           },
//   //         ),
//   //       ),
//   //       SizedBox(height: 20),
//   //     ],
//   //   );
//   // }
//
//   @override
//   Widget build(BuildContext context) {
//     final contentProvider = Provider.of<ContentProvider>(context,listen: false);
//     final userProvider = Provider.of<UserAuthProvider>(context,listen: false);
//     final isAdminOrOwner = userProvider.loginUserData?.role == UserRole.ADM.name ||
//         userProvider.loginUserData?.id == widget.content.ownerId;
//     final hasPurchased = contentProvider.userPurchases
//         .any((purchase) => purchase.contentId == widget.content.id);
//
//     final isSeries = widget.content.isSeries;
//     // final canWatch = (isSeries
//     //     ? (_currentEpisode?.isFree ?? false)
//     //     : widget.content.isFree) || hasPurchased;
//
//     bool canWatch = (isSeries ? (_currentEpisode?.isFree ?? false) : widget.content.isFree)
//         || hasPurchased
//         || isAdminOrOwner; // ajouté
//
//     // Déterminer l'URL de la miniature
//     String thumbnailUrl = isSeries && _currentEpisode != null
//         ? _currentEpisode!.thumbnailUrl!
//         : widget.content.thumbnailUrl ?? '';
//
//     return Scaffold(
//       backgroundColor: _colors.background,
//       body: Stack(
//         children: [
//           CustomScrollView(
//             slivers: [
//               SliverAppBar(
//                 expandedHeight: 400,
//                 floating: false,
//                 pinned: true,
//                 backgroundColor: _colors.background,
//                 flexibleSpace: FlexibleSpaceBar(
//                   background: Stack(
//                     children: [
//                       CachedNetworkImage(
//                         imageUrl: thumbnailUrl,
//                         fit: BoxFit.cover,
//                         width: double.infinity,
//                         placeholder: (context, url) => Container(
//                           color: Colors.grey[900],
//                         ),
//                         errorWidget: (context, url, error) => Container(
//                           color: Colors.grey[900],
//                           child: Icon(Icons.error, color: Colors.white),
//                         ),
//                       ),
//                       Container(
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             begin: Alignment.bottomCenter,
//                             end: Alignment.topCenter,
//                             colors: [
//                               _colors.background.withOpacity(0.9),
//                               _colors.background.withOpacity(0.3),
//                               Colors.transparent,
//                             ],
//                             stops: [0.0, 0.5, 1.0],
//                           ),
//                         ),
//                       ),
//                       if (canWatch && _isVideoInitialized)
//                         Positioned.fill(
//                           child: Chewie(controller: _chewieController),
//                         )
//                       else if (!canWatch && !isAdminOrOwner) // Modifié ici
//                         Positioned.fill(
//                           child: Container(
//                             color: _colors.background.withOpacity(0.7),
//                             child: Center(
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.lock_outline,
//                                     size: 60,
//                                     color: _colors.textPrimary,
//                                   ),
//                                   SizedBox(height: 16),
//                                   Text(
//                                     'Contenu verrouillé',
//                                     style: TextStyle(
//                                       color: _colors.textPrimary,
//                                       fontSize: 24,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   SizedBox(height: 8),
//                                   Text(
//                                     'Débloquez ce contenu pour le regarder',
//                                     style: TextStyle(
//                                       color: Colors.white70,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                   SizedBox(height: 8),
//                                   Text(
//                                     'Votre soutien aide les artistes à créer plus de contenu',
//                                     style: TextStyle(
//                                       color: Colors.white70,
//                                       fontSize: 14,
//                                       fontStyle: FontStyle.italic,
//                                     ),
//                                     textAlign: TextAlign.center,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         )
//                       else if (isAdminOrOwner) // Nouveau bloc pour admin/propriétaire
//                           Positioned.fill(
//                             child: Container(
//                               color: _colors.background.withOpacity(0.5),
//                               child: Center(
//                                 child: Text(
//                                   'Vous pouvez visionner ce contenu gratuitement (Admin/Propriétaire)',
//                                   style: TextStyle(
//                                     color: Colors.white70,
//                                     fontSize: 16,
//                                     fontStyle: FontStyle.italic,
//                                   ),
//                                   textAlign: TextAlign.center,
//                                 ),
//                               ),
//                             ),
//                           ),
//
//                     ],
//                   ),
//                 ),
//                 leading: IconButton(
//                   icon: Icon(Icons.arrow_back, color: _colors.textPrimary),
//                   onPressed: () => Navigator.pop(context),
//                 ),
//                 actions: [
//                   if (isAdminOrOwner)
//                     IconButton(
//                       icon: Icon(Icons.delete_outline, color: Colors.red),
//                       onPressed: _showDeleteModal,
//                     ),
//
//                   // IconButton(
//                   //   icon: Icon(Icons.share, color: _colors.textPrimary),
//                   //   onPressed: () {},
//                   // ),
//                   // IconButton(
//                   //   icon: Icon(Icons.bookmark_border, color: _colors.textPrimary),
//                   //   onPressed: () {},
//                   // ),
//                 ],
//               ),
//
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: EdgeInsets.all(20),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Affichage des informations selon le type de contenu
//                       widget.content.isSeries ? _buildSeriesInfo() : _buildSimpleContentInfo(),
//                       SizedBox(height: 5),
//                       _buildAdMrec(key: 'ad_native_content_details'),
//                       SizedBox(height: 5),
//
//                       // --- Ici on affiche le widget ContentOwnerInfo ---
//                       ContentOwnerInfo(ownerId: widget.content.ownerId),
//                       // Actions rapides (Like, Vue, etc.)
// // Actions rapides (Partage, Like, Dislike, Vue)
// // Actions rapides (Partage, Like, Dislike, Vue)
//                       Row(
//                         children: [
//                           // Bouton Partage avec compteur
//                           Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               GestureDetector(
//                                 onTap: _isSharing ? null : _handleShare, // Désactive le bouton pendant le partage
//                                 child: Container(
//                                   padding: EdgeInsets.all(8),
//                                   decoration: BoxDecoration(
//                                     color: _colors.background.withOpacity(0.5),
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: _isSharing
//                                       ? SizedBox(
//                                     width: 24,
//                                     height: 24,
//                                     child: CircularProgressIndicator(
//                                       color: _colors.accent,
//                                       strokeWidth: 2,
//                                     ),
//                                   )
//                                       : Icon(
//                                     Icons.share,
//                                     color: Colors.white,
//                                     size: 24,
//                                   ),
//                                 ),
//                               ),
//                               SizedBox(height: 1),
//
//                               // Compteur des partages
//                               Consumer<ContentProvider>(
//                                 builder: (context, contentProvider, child) {
//                                   final shares = widget.content.isSeries && _currentEpisode != null
//                                       ? _currentEpisode?.shares ?? 0
//                                       : widget.content.shares;
//                                   return Text(
//                                     '$shares',
//                                     style: TextStyle(color: _colors.textPrimary, fontSize: 16),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//
//                           SizedBox(width: 5),
//
//                           // Bouton Dislike avec compteur
//                           Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               GestureDetector(
//                                 onTap: _handleDislike,
//                                 child: Container(
//                                   padding: EdgeInsets.all(8),
//                                   decoration: BoxDecoration(
//                                     color: _colors.background.withOpacity(0.5),
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: Icon(
//                                     _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
//                                     color: _isDisliked ? Colors.blue : _colors.textPrimary,
//                                     size: 24,
//                                   ),
//                                 ),
//                               ),
//                               SizedBox(height: 1),
//                               Consumer<ContentProvider>(
//                                 builder: (context, contentProvider, child) {
//                                   final dislikes = widget.content.isSeries && _currentEpisode != null
//                                       ? _currentEpisode?.dislikes ?? 0
//                                       : widget.content.dislikes;
//                                   return Text(
//                                     '$dislikes',
//                                     style: TextStyle(
//                                       color: _isDisliked ? Colors.blue : _colors.textPrimary,
//                                       fontSize: 12,
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//                           SizedBox(width: 5),
//
//                           // Bouton Like avec compteur
//                           Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               GestureDetector(
//                                 onTap: _handleLike,
//                                 child: Container(
//                                   padding: EdgeInsets.all(8),
//                                   decoration: BoxDecoration(
//                                     color: _colors.background.withOpacity(0.5),
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: Icon(
//                                     _isLiked ? Icons.favorite : Icons.favorite_border,
//                                     color: _isLiked ? Colors.red : _colors.textPrimary,
//                                     size: 24,
//                                   ),
//                                 ),
//                               ),
//                               SizedBox(height: 1),
//                               Consumer<ContentProvider>(
//                                 builder: (context, contentProvider, child) {
//                                   final likes = widget.content.isSeries && _currentEpisode != null
//                                       ? _currentEpisode?.likes ?? 0
//                                       : widget.content.likes;
//                                   return Text(
//                                     '$likes',
//                                     style: TextStyle(
//                                       color: _isLiked ? Colors.red : _colors.textPrimary,
//                                       fontSize: 12,
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//                           SizedBox(width: 5),
//
//                           // Affichage des vues
//                           Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(Icons.visibility, color: _colors.textPrimary, size: 24),
//                               SizedBox(height: 1),
//                               Consumer<ContentProvider>(
//                                 builder: (context, contentProvider, child) {
//                                   final views = widget.content.isSeries && _currentEpisode != null
//                                       ? _currentEpisode?.views ?? 0
//                                       : widget.content.views;
//                                   return Text(
//                                     '$views',
//                                     style: TextStyle(color: _colors.textPrimary, fontSize: 12),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//                           Spacer(),
//
//                           if (!widget.content.isFree && (!widget.content.isSeries ||
//                               (widget.content.isSeries && _currentEpisode != null && !_currentEpisode!.isFree)))
//                             Container(
//                               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                               decoration: BoxDecoration(
//                                 color: _colors.accent.withOpacity(0.2),
//                                 borderRadius: BorderRadius.circular(4),
//                                 border: Border.all(color: _colors.accent),
//                               ),
//                               child: Text(
//                                 'PREMIUM',
//                                 style: TextStyle(
//                                   color: _colors.accent,
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                       SizedBox(height: 10),
//
//                       // Sélecteur d'épisodes pour les séries
//                       // if (widget.content.isSeries) _buildEpisodeSelector(),
//
//                       Text(
//                         widget.content.isSeries && _currentEpisode != null
//                             ? _currentEpisode!.description
//                             : widget.content.description!,
//                         style: TextStyle(
//                           color: Colors.white70,
//                           fontSize: 16,
//                           height: 1.5,
//                         ),
//                       ),
//                       SizedBox(height: 20),
//
//                       // Message de soutien aux artistes
//                       Container(
//                         width: double.infinity,
//                         padding: EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: _colors.primary.withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(color: _colors.primary.withOpacity(0.3)),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               children: [
//                                 Icon(Icons.favorite, color: _colors.primary, size: 16),
//                                 SizedBox(width: 8),
//                                 Text(
//                                   'Soutenez les créateurs',
//                                   style: TextStyle(
//                                     color: _colors.primary,
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             SizedBox(height: 8),
//                             Text(
//                               'En achetant ce contenu, vous soutenez directement les artistes et leur permettez de créer plus de vidéos de qualité.',
//                               style: TextStyle(
//                                 color: Colors.white70,
//                                 fontSize: 14,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       SizedBox(height: 20),
//
//                       if (!canWatch)
//                         Container(
//                           width: double.infinity,
//                           child: ElevatedButton(
//                             style: ElevatedButton.styleFrom(
//                               foregroundColor: _colors.background,
//                               backgroundColor: _colors.accent,
//                               padding: EdgeInsets.symmetric(vertical: 18),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               elevation: 2,
//                             ),
//                             onPressed: _isPurchasing ? null : _handlePurchase,
//                             child: _isPurchasing
//                                 ? SizedBox(
//                               width: 20,
//                               height: 20,
//                               child: CircularProgressIndicator(
//                                 color: _colors.background,
//                                 strokeWidth: 2,
//                               ),
//                             )
//                                 : Text(
//                               'SOUTENIR LES CRÉATEURS - ${widget.content.price} F',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         )
//                       else if (_isVideoInitialized)
//                         Container(
//                           width: double.infinity,
//                           child: ElevatedButton(
//                             style: ElevatedButton.styleFrom(
//                               foregroundColor: _colors.textPrimary,
//                               backgroundColor: _colors.primary,
//                               padding: EdgeInsets.symmetric(vertical: 18),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               elevation: 2,
//                             ),
//                             onPressed: () {
//                               if (_chewieController.isPlaying) {
//                                 _chewieController.pause();
//                               } else {
//                                 _chewieController.play();
//                               }
//                             },
//                             child: Text(
//                               _chewieController.isPlaying ? 'PAUSER' : 'JOUER',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ),
//                       SizedBox(height: 20),
//
//                       if ((widget.content.isSeries ? widget.content.hashtags!: widget.content.hashtags) != null &&
//                           (widget.content.isSeries ? widget.content.hashtags!.isNotEmpty : widget.content.hashtags!.isNotEmpty))
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Tags:',
//                               style: TextStyle(
//                                 color: _colors.textPrimary,
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             SizedBox(height: 8),
//                             Wrap(
//                               spacing: 8,
//                               runSpacing: 4,
//                               children: (widget.content.isSeries && _currentEpisode != null
//                                   ? widget.content.hashtags!
//                                   : widget.content.hashtags!).map((hashtag) {
//                                 return Container(
//                                   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                                   decoration: BoxDecoration(
//                                     color: _colors.primary.withOpacity(0.2),
//                                     borderRadius: BorderRadius.circular(16),
//                                     border: Border.all(color: _colors.primary),
//                                   ),
//                                   child: Text(
//                                     '#$hashtag',
//                                     style: TextStyle(color: _colors.primary),
//                                   ),
//                                 );
//                               }).toList(),
//                             ),
//                           ],
//                         ),
//                       SizedBox(height: 24),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//           // Animation like au centre de l'écran
//           if (_showLikeAnimation)
//             Positioned.fill(
//               child: Center(
//                 child: IgnorePointer(
//                   child: AnimatedScale(
//                     scale: _isLikedAnimation ? 1.5 : 1.0,
//                     duration: Duration(milliseconds: 300),
//                     curve: Curves.easeOutBack,
//                     child: Icon(
//                       Icons.favorite,
//                       color: Colors.red,
//                       size: 100,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//
//           // Animation de vue discrète en haut
//           Positioned(
//             top: 100,
//             right: 20,
//             child: Visibility(
//               visible: (widget.content.isSeries && _currentEpisode != null
//                   ? _currentEpisode!.views > 0
//                   : widget.content.views != null && widget.content.views! > 0),
//               child: Container(
//                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: _colors.background.withOpacity(0.7),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.visibility, color: _colors.textPrimary, size: 14),
//                     SizedBox(width: 4),
//                     Text(
//                       widget.content.isSeries && _currentEpisode != null
//                           ? '${_currentEpisode!.views}'
//                           : '${widget.content.views}',
//                       style: TextStyle(color: _colors.textPrimary, fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // Couleurs thématiques — via AppColors.of(context)
//
// enum PurchaseResult {
//   success,
//   insufficientBalance,
//   alreadyPurchased,
//   error
// }