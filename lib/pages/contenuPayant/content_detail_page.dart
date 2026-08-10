import 'package:afrotok/utils/responsive_sheet.dart';
import 'dart:async';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/contentForm.dart' show ContentFormScreen;
import 'package:afrotok/pages/contenuPayant/creator_promo_codes_page.dart';
import 'package:afrotok/pages/contenuPayant/profileScreenContent.dart';
import 'package:afrotok/pages/contenuPayant/widgets/boost_modal.dart';
import 'package:afrotok/pages/contenuPayant/widgets/content_comments_section.dart';
import 'package:afrotok/pages/contenuPayant/widgets/promo_code_modal.dart';
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/sessions/session_checker_service.dart';
import 'package:video_player/video_player.dart';
import '../../services/media_cache_service.dart';

class ContentDetailPage extends StatefulWidget {
  final ContentPaie content;

  const ContentDetailPage({Key? key, required this.content}) : super(key: key);

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  late ContentPaie _content;
  int _coverIndex = 0;
  bool _hasPurchased = false;
  bool _checkingPurchase = true;
  bool _buying = false;
  PromoCode? _appliedPromoCode;
  String? _affiliateId; // ref= détecté via SharedPreferences (lien de partage)

  // Données créateur (chargées async)
  UserData? _creatorData;

  // Lecteur vidéo inline (VIDEO seulement, après achat)
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoReady = false;
  bool _initializingVideo = false;

  // Lecteur vidéo tutoriel (pour contenus non-vidéo avec tutorialVideoUrl)
  VideoPlayerController? _tutorialController;
  ChewieController? _tutorialChewieController;
  bool _isTutorialReady = false;
  bool _initializingTutorial = false;

  // Preview 10 secondes (capsules vidéo)
  Timer? _previewTimer;

  // Lecteur léger pour extraits (non-acheteurs) — URL directe, pas de Cloud Function
  VideoPlayerController? _previewController;
  bool _isPreviewReady = false;
  bool _initializingPreview = false;

  // Téléchargement en cours
  String? _downloadingKey;   // fileKey en cours ('pdfUrl', 'fileUrl', etc.)
  double _downloadProgress = 0.0;

  double get _finalPrice {
    final base = _content.effectivePrice;
    if (_appliedPromoCode != null) {
      return _appliedPromoCode!.discountedPrice(base);
    }
    return base;
  }

  AppColors get _colors => AppColors.of(context);

  @override
  void initState() {
    super.initState();
    _content = widget.content;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      SessionCheckerService.checkSessionAndShowModalIfNeeded(
        context: context,
        authProvider: authProvider,
      );
    });
    _checkPurchase();
    _incrementView();
    _loadAffiliateRef();
    _loadCreatorData();
  }

  Future<void> _loadCreatorData() async {
    final ownerId = _content.ownerId;
    if (ownerId == null || ownerId.isEmpty) return;
    final doc = await FirebaseFirestore.instance.collection('Users').doc(ownerId).get();
    if (doc.exists && mounted) {
      setState(() => _creatorData = UserData.fromJson({...doc.data()!, 'id': doc.id}));
    }
  }

  /// Lance la vidéo pendant 10 secondes à la position [ratio] (0.0 = début, 0.5 = milieu, 0.9 = fin).
  /// Utilise le lecteur complet (Cloud Function) si l'utilisateur a accès,
  /// sinon le lecteur léger (URL directe) pour les extraits gratuits.
  Future<void> _playPreviewAt(double ratio) async {
    _previewTimer?.cancel();

    final hasAccess = _hasPurchased || _content.isFree;

    if (hasAccess) {
      // Lecteur complet via Cloud Function
      if (!_isVideoReady) {
        await _initVideoPlayer();
        if (!_isVideoReady || !mounted) return;
      }
      final total = _videoController!.value.duration;
      if (total == Duration.zero) return;
      await _videoController!.seekTo(total * ratio);
      await _videoController!.play();
      _previewTimer = Timer(const Duration(seconds: 10), () async {
        if (_videoController?.value.isPlaying == true) await _videoController!.pause();
      });
    } else {
      // Lecteur léger — URL directe, pas de vérification d'achat Cloud Function
      if (!_isPreviewReady) {
        await _initPreviewPlayer();
        if (!_isPreviewReady || !mounted) return;
      }
      final total = _previewController!.value.duration;
      if (total == Duration.zero) return;
      await _previewController!.seekTo(total * ratio);
      await _previewController!.play();
      _previewTimer = Timer(const Duration(seconds: 10), () async {
        if (_previewController?.value.isPlaying == true) await _previewController!.pause();
      });
    }
  }

  /// Initialise le lecteur léger pour les extraits gratuits (URL directe, sans Cloud Function).
  Future<void> _initPreviewPlayer() async {
    if (_initializingPreview || _isPreviewReady) return;
    final rawUrl = _content.videoUrl;
    if (rawUrl == null || rawUrl.isEmpty) return;
    setState(() => _initializingPreview = true);
    try {
      _previewController = await MediaCacheService.videoController(rawUrl);
      await _previewController!.initialize();
      await _previewController!.setVolume(0); // muet pour l'aperçu
      if (mounted) setState(() => _isPreviewReady = true);
    } catch (e) {
      debugPrint('[PreviewPlayer] erreur: $e');
      _previewController?.dispose();
      _previewController = null;
    } finally {
      if (mounted) setState(() => _initializingPreview = false);
    }
  }

  String _friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('permission-denied') || msg.contains('achat non trouvé')) {
      return 'Accès refusé. Vérifiez votre achat ou réessayez.';
    }
    if (msg.contains('unauthenticated')) {
      return 'Veuillez vous connecter pour continuer.';
    }
    if (msg.contains('not-found') || msg.contains('introuvable')) {
      return 'Contenu introuvable.';
    }
    if (msg.contains('network') || msg.contains('unavailable') || msg.contains('connexion')) {
      return 'Problème de connexion. Vérifiez votre réseau.';
    }
    if (msg.contains('resource-exhausted') || msg.contains('solde insuffisant')) {
      return 'Solde insuffisant pour effectuer cet achat.';
    }
    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  void _showResultDialog({required bool success, required String message, bool insufficientBalance = false}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: success,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: (success ? const Color(0xFF25D366) : Colors.red).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: success ? const Color(0xFF25D366) : Colors.red,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              success ? 'Succès' : 'Erreur',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: success ? const Color(0xFF25D366) : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _colors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            if (insufficientBalance) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DepositScreen(defaultAmount: _finalPrice),
                      ),
                    );
                  },
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.white),
                  label: const Text('Recharger mon solde', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Fermer', style: TextStyle(color: _colors.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: success ? const Color(0xFF25D366) : Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                  child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _initVideoPlayer() async {
    if (_initializingVideo || _isVideoReady) return;
    setState(() => _initializingVideo = true);
    try {
      // Toujours passer par la Cloud Function — elle gère free/admin/acheté
      // et génère une URL signée Firebase Storage valide 1h.
      final callable =
          FirebaseFunctions.instance.httpsCallable('getSecureDownloadUrl');
      final result = await callable
          .call({'contentId': _content.id, 'fileKey': 'videoUrl'});
      final videoUrl = result.data['url'] as String?;

      if (videoUrl == null || videoUrl.isEmpty || !mounted) {
        _showResultDialog(success: false, message: 'Impossible de charger la vidéo. Vérifiez votre connexion et réessayez.');
        return;
      }

      _videoController = await MediaCacheService.videoController(videoUrl);
      await _videoController!.initialize();
      // Contenu gratuit : lecture auto sans son pour découverte
      final autoPlay = _content.isFree;
      if (autoPlay) await _videoController!.setVolume(0);
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: autoPlay,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: true,
        showOptions: false,
        placeholder:
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
      if (mounted) setState(() => _isVideoReady = true);
    } catch (e) {
      debugPrint('[VideoPlayer] erreur: $e');
      _showResultDialog(
        success: false,
        message: _friendlyError(e),
      );
    } finally {
      if (mounted) setState(() => _initializingVideo = false);
    }
  }

  Future<void> _initTutorialPlayer() async {
    if (_initializingTutorial || _isTutorialReady) return;
    if (_content.tutorialVideoUrl == null) return;
    setState(() => _initializingTutorial = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getSecureDownloadUrl');
      final result = await callable
          .call({'contentId': _content.id, 'fileKey': 'tutorialVideoUrl'});
      final url = result.data['url'] as String?;
      if (url == null || url.isEmpty || !mounted) return;

      _tutorialController = await MediaCacheService.videoController(url);
      await _tutorialController!.initialize();
      _tutorialChewieController = ChewieController(
        videoPlayerController: _tutorialController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _tutorialController!.value.aspectRatio,
        allowFullScreen: true,
        showOptions: false,
        placeholder:
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
      if (mounted) setState(() => _isTutorialReady = true);
    } catch (e) {
      debugPrint('[TutorialPlayer] erreur: $e');
      _showResultDialog(
        success: false,
        message: 'Impossible de charger le tutoriel.\n${e.toString()}',
      );
    } finally {
      if (mounted) setState(() => _initializingTutorial = false);
    }
  }

  // Lit le ref= sauvegardé lors de l'ouverture d'un lien de partage (?ref=userId)
  Future<void> _loadAffiliateRef() async {
    if (_content.id == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'affiliate_ref_${_content.id}';
    final ref = prefs.getString(key);
    final ts = prefs.getInt('${key}_ts') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final age = now - ts;
    // TTL 30 jours ; on rejette si c'est le propriétaire lui-même
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    if (ref != null &&
        age < 30 * 24 * 3600 * 1000 &&
        ref != _content.ownerId) {
      setState(() => _affiliateId = ref);
      // Tracker le clic une seule fois par appareil (fenêtre 1h = lien frais)
      final trackKey = 'affiliate_click_tracked_${_content.id}_$ref';
      final alreadyTracked = prefs.getBool(trackKey) ?? false;
      if (!alreadyTracked && age < 60 * 60 * 1000) {
        await prefs.setBool(trackKey, true);
        _trackAffiliateClick(ref);
      }
    }
  }

  Future<void> _trackAffiliateClick(String affiliateId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('AffiliateLinks')
          .where('affiliateId', isEqualTo: affiliateId)
          .where('contentId', isEqualTo: _content.id)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference
            .update({'clicks': FieldValue.increment(1)});
      }
    } catch (_) {
      // Echec silencieux — le tracking de clic est non critique
    }
  }

  Future<void> _checkPurchase() async {
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    final uid = authProvider.loginUserData.id;
    final isAdmin = authProvider.loginUserData.role == 'ADM';

    if (uid == null || _content.id == null) {
      setState(() => _checkingPurchase = false);
      return;
    }
    if (isAdmin || _content.isFree) {
      setState(() {
        _hasPurchased = true;
        _checkingPurchase = false;
      });
      // Lancer la vidéo automatiquement (muet) pour les contenus gratuits
      if (_content.isVideo && _content.isFree) {
        _initVideoPlayer();
      }
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('ContentPaie_purchases')
        .where('userId', isEqualTo: uid)
        .where('contentId', isEqualTo: _content.id)
        .limit(1)
        .get();
    if (mounted) {
      setState(() {
        _hasPurchased = snap.docs.isNotEmpty;
        _checkingPurchase = false;
      });
    }
  }

  void _shareContent() {
    final link =
        'https://afrolookmedia.com/share/contenu/${_content.id}';
    Share.share(
      '🛍️ ${_content.title}\n\n${_content.description.length > 100 ? _content.description.substring(0, 100) + "..." : _content.description}\n\n$link',
      subject: _content.title,
    );
  }

  Future<void> _incrementView() async {
    final id = _content.id;
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'viewed_content_$id';
    if (prefs.getBool(key) == true) return; // déjà vu cette session
    await prefs.setBool(key, true);
    await FirebaseFirestore.instance
        .collection('ContentPaies')
        .doc(id)
        .update({'views': FieldValue.increment(1)});
  }

  Future<void> _buy() async {
    if (_content.id == null || _content.ownerId == null) return;

    setState(() => _buying = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('securePurchase');
      await callable.call({
        'contentId': _content.id,
        if (_appliedPromoCode?.id != null) 'promoCodeId': _appliedPromoCode!.id,
        if (_affiliateId != null) 'affiliateId': _affiliateId,
      });

      // Nettoyage du lien d'affiliation
      if (_affiliateId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('affiliate_ref_${_content.id}');
        await prefs.remove('affiliate_ref_${_content.id}_ts');
      }

      if (mounted) {
        setState(() => _hasPurchased = true);
        // Rafraîchir le solde local après déduction
        final authProvider =
            Provider.of<UserAuthProvider>(context, listen: false);
        await authProvider.refreshUserData();
        _showResultDialog(
          success: true,
          message: 'Achat réussi ! Votre contenu est maintenant débloqué.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      final raw = e.message ?? '';
      final isInsufficient = e.code == 'resource-exhausted' ||
          raw.toLowerCase().contains('solde insuffisant') ||
          raw.toLowerCase().contains('resource-exhausted');
      _showResultDialog(
        success: false,
        message: isInsufficient
            ? 'Solde insuffisant pour effectuer cet achat.\nRechargez votre solde et réessayez.'
            : (raw.isNotEmpty ? raw : 'Erreur lors de l\'achat.'),
        insufficientBalance: isInsufficient,
      );
    } catch (e) {
      _showResultDialog(success: false, message: _friendlyError(e));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _chewieController?.dispose();
    _videoController?.dispose();
    _previewController?.dispose();
    _tutorialChewieController?.dispose();
    _tutorialController?.dispose();
    super.dispose();
  }

  bool get _isOwner {
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    return authProvider.loginUserData.id == _content.ownerId;
  }

  bool get _isAdmin {
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    return authProvider.loginUserData.role == 'ADM';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colors.background,
      body: CustomScrollView(

        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBar() {
    // Pour les vidéos : pas de galerie de couverture (la vidéo s'affiche dans le body)
    final showCover = !_content.isVideo;

    return SliverAppBar(
      expandedHeight: showCover ? 260 : 0,
      pinned: true,
      backgroundColor: _colors.background,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: showCover ? Colors.black54 : _colors.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_back,
              color: showCover ? Colors.white : _colors.textPrimary, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // Bouton like
        Builder(builder: (ctx) {
          final authProvider =
              Provider.of<UserAuthProvider>(ctx, listen: false);
          final uid = authProvider.loginUserData.id ?? '';
          final isLiked = _content.isLikedByUser(uid);
          final iconColor = isLiked
              ? Colors.red
              : (showCover ? Colors.white : _colors.textPrimary);
          final bgColor = isLiked
              ? Colors.red.withOpacity(0.2)
              : (showCover ? Colors.black54 : _colors.surface);
          return IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_outline,
                color: iconColor,
                size: 18,
              ),
            ),
            onPressed: _toggleLike,
          );
        }),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: showCover ? Colors.black54 : _colors.surface,
                shape: BoxShape.circle),
            child: Icon(Icons.share_outlined,
                color: showCover ? Colors.white : _colors.textPrimary, size: 18),
          ),
          onPressed: _shareContent,
        ),
        if (_isOwner || _isAdmin)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: showCover ? Colors.black54 : _colors.surface,
                  shape: BoxShape.circle),
              child: Icon(Icons.more_vert,
                  color: showCover ? Colors.white : _colors.textPrimary, size: 18),
            ),
            onPressed: _showOwnerMenu,
          ),
      ],
      flexibleSpace: showCover
          ? FlexibleSpaceBar(background: _buildCoverGallery())
          : null,
    );
  }

  Widget _buildCoverGallery() {
    // Construire la liste d'images : coverImages en priorité, sinon thumbnailUrl comme fallback
    final rawImgs = _content.coverImages;
    final imgs = rawImgs.isNotEmpty
        ? rawImgs
        : (_content.thumbnailUrl.isNotEmpty ? [_content.thumbnailUrl] : <String>[]);
    final hasCover = imgs.isNotEmpty;
    final coverCount = hasCover ? imgs.length : 1;

    return Stack(
      children: [
        if (hasCover)
          PageView.builder(
            itemCount: coverCount,
            onPageChanged: (i) => setState(() => _coverIndex = i),
            itemBuilder: (_, i) => _coverImage(imgs[i]),
          )
        else
          _coverPlaceholder(),

        // Gradient bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  _colors.background.withOpacity(0.9),
                ],
              ),
            ),
          ),
        ),

        // Type badge
        Positioned(
          top: 50,
          left: 16,
          child: _TypeBadge(type: _content.contentType),
        ),

        // Boost badge
        if (_content.isBoostActive)
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD400), Color(0xFFFF8C00)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.bolt, color: Colors.black, size: 12),
                  Text(' BOOSTÉ',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.black)),
                ],
              ),
            ),
          ),

        // Dots indicator
        if (coverCount > 1)
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                coverCount,
                (i) => Container(
                  width: i == _coverIndex ? 20 : 6,
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i == _coverIndex
                        ? const Color(0xFFFFD400)
                        : Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _coverImage(String url) {
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    final cdnUrl =
        authProvider.convertToCdnUrl(url, authProvider.appDefaultData);
    return CachedNetworkImage(
      imageUrl: cdnUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      errorWidget: (_, __, ___) => _coverPlaceholder(),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: const Color(0xFF111111),
      child: Center(
        child: Text(
          _typeEmoji(_content.contentType),
          style: const TextStyle(fontSize: 60),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final hasAccess = _hasPurchased || _content.isFree;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Vidéo : lecteur en haut (accessible) ou thumbnail seul (non acheté)
        if (_content.isVideo) _buildVideoSection(),
        _buildCreatorCard(),
        _buildInfoSection(),
        _buildStatsRow(),
        const SizedBox(height: 8),
        _buildDescriptionSection(),
        // ── Capsules aperçu :
        //    VIDEO → toujours visibles (tap = 10 secondes si accès, sinon juste image)
        //    Non-vidéo → visibles uniquement si pas encore acheté
        if (_content.isVideo || !hasAccess)
          _buildPreviewSection(),
        // ── Téléchargement (ebook, template, etc.) après achat
        if (hasAccess && !_content.isVideo) _buildDownloadSection(),
        if (_content.isSeries) _buildEpisodesList(),
        const SizedBox(height: 8),
        if (_content.id != null)
          ContentCommentsSection(contentId: _content.id!),
        const SizedBox(height: 100),
      ],
    );
  }

  // ── Carte créateur ──────────────────────────────────────────────────────────
  Widget _buildCreatorCard() {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProfileScreenContenu(userId: _content.ownerId)),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _colors.border),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: _colors.primary.withValues(alpha: 0.15),
                backgroundImage: _creatorData?.imageUrl != null && _creatorData!.imageUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(
                        authProvider.convertToCdnUrl(_creatorData!.imageUrl!, authProvider.appDefaultData))
                    : null,
                child: _creatorData?.imageUrl == null || _creatorData!.imageUrl!.isEmpty
                    ? Text(
                        (_creatorData?.pseudo ?? _content.ownerId ?? '?')[0].toUpperCase(),
                        style: TextStyle(color: _colors.primary, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${_creatorData?.pseudo ?? 'Créateur'}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _colors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Créateur de contenu',
                      style: TextStyle(fontSize: 11, color: _colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF25D366), width: 1.2),
                ),
                child: const Text(
                  'Business',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF25D366),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Lecteur vidéo inline ───────────────────────────────────────────────────
  Widget _buildVideoSection() {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final coverRaw = _content.coverImages.isNotEmpty
        ? _content.coverImages.first
        : (_content.thumbnailUrl.isNotEmpty ? _content.thumbnailUrl : null);
    final cover = coverRaw != null
        ? authProvider.convertToCdnUrl(coverRaw, authProvider.appDefaultData)
        : null;

    if (_isVideoReady) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      );
    }

    // Placeholder : cover image + bouton play (ou loader pendant l'init)
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover != null)
            CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: Colors.black))
          else
            Container(color: Colors.black),
          Container(color: Colors.black.withValues(alpha: 0.35)),
          Center(
            child: _initializingVideo
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: _initVideoPlayer,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                              color: Colors.white24, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _content.isFree ? 'Lecture gratuite' : 'Regarder la vidéo',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Text(
        _content.title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: _colors.textPrimary,
          height: 1.2,
        ),
      ),
    );
  }

  Future<void> _toggleLike() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final uid = authProvider.loginUserData.id;
    if (uid == null || _content.id == null) return;

    final wasLiked = _content.isLikedByUser(uid);
    setState(() => _content.toggleLike(uid));

    try {
      await FirebaseFirestore.instance
          .collection('ContentPaies')
          .doc(_content.id)
          .update({
        'likes': FieldValue.increment(wasLiked ? -1 : 1),
        'likedBy': wasLiked
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      });
    } catch (_) {
      // Rollback optimiste si erreur
      if (mounted) setState(() => _content.toggleLike(uid));
    }
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _StatChip(
              icon: Icons.visibility_outlined,
              value: _formatCount(_content.views)),
          const SizedBox(width: 12),
          _StatChip(
              icon: Icons.favorite_outline,
              value: _formatCount(_content.likes)),
          const SizedBox(width: 12),
          _StatChip(
              icon: Icons.comment_outlined,
              value: _formatCount(_content.comments)),
          const SizedBox(width: 12),
          _StatChip(
              icon: Icons.shopping_bag_outlined,
              value: _formatCount(_content.sales),
              label: 'vente${_content.sales != 1 ? 's' : ''}'),
          if (_content.duration > 0) ...[
            const SizedBox(width: 12),
            _StatChip(
                icon: Icons.timer_outlined,
                value: _formatDuration(_content.duration)),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _content.description,
            style: TextStyle(
              fontSize: 13,
              color: _colors.textSecondary,
              height: 1.6,
            ),
          ),
          if (_content.hashtags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _content.hashtags
                  .map((h) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF25D366)
                                  .withOpacity(0.3)),
                        ),
                        child: Text(
                          '#$h',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF25D366)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final hasAccess = _hasPurchased || _content.isFree;
    final isVideo = _content.isVideo;

    // Résolution d'image : coverImages en priorité, thumbnailUrl en fallback
    String _resolveImg(int i) {
      final imgs = _content.coverImages;
      final raw = imgs.length > i && imgs[i].isNotEmpty ? imgs[i] : _content.thumbnailUrl;
      if (raw.isEmpty) return '';
      return authProvider.convertToCdnUrl(raw, authProvider.appDefaultData);
    }

    // Labels et positions selon type
    final labels = isVideo
        ? ['▶ Début', '⏩ Mi-parcours', '🔁 Fin']
        : ['📖 Couverture', '📄 Extrait', '📋 Fin du contenu'];
    final positions = [0.0, 0.5, 0.9]; // ratio de la durée totale

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                isVideo ? 'EXTRAITS VIDÉO' : 'APERÇU DU CONTENU',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: _colors.textSecondary),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isVideo ? '3 × 10 sec' : '3 aperçus',
                  style: const TextStyle(
                      fontSize: 9, color: Color(0xFF25D366), fontWeight: FontWeight.w700)),
              ),
              if (isVideo) ...[
                const SizedBox(width: 6),
                Text('Appuyez pour écouter',
                    style: TextStyle(fontSize: 9, color: _colors.textSecondary)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── 3 capsules ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: List.generate(3, (i) {
              final url = _resolveImg(i);
              final label = labels[i];
              return Expanded(
                child: GestureDetector(
                  onTap: isVideo ? () => _playPreviewAt(positions[i]) : null,
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    height: 120,
                    decoration: BoxDecoration(
                      color: _colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF25D366).withValues(alpha: 0.5),
                          width: 1.2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image de fond (thumbnail ou cover)
                        if (url.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Center(
                                child: Text(_typeEmoji(_content.contentType),
                                    style: const TextStyle(fontSize: 28))),
                          )
                        else
                          Center(
                              child: Text(_typeEmoji(_content.contentType),
                                  style: const TextStyle(fontSize: 28))),
                        // Overlay léger pour lisibilité
                        Container(color: Colors.black.withValues(alpha: 0.25)),
                        // Icône play pour les vidéos (extraits disponibles même sans achat)
                        if (isVideo)
                          Center(
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                  color: Colors.white24, shape: BoxShape.circle),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        // Label en bas
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.85)
                                ],
                              ),
                            ),
                            child: Text(label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            isVideo
                ? 'Appuyez sur un extrait pour écouter 10 secondes à cette position.'
                : 'Achetez pour accéder à l\'intégralité du contenu.',
            style: TextStyle(fontSize: 11, color: _colors.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadSection() {
    final hasPdf = _content.pdfUrl != null && _content.pdfUrl!.isNotEmpty;
    if (!_content.hasFile && !hasPdf && _content.tutorialVideoUrl == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF25D366).withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download_done_outlined,
                    color: Color(0xFF25D366), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Vos fichiers — téléchargement sécurisé',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF25D366),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_content.pdfUrl != null && _content.pdfUrl!.isNotEmpty)
              _DownloadTile(
                icon: Icons.picture_as_pdf_outlined,
                name: 'Lire l\'ebook (PDF)',
                size: 'PDF',
                color: const Color(0xFF25D366),
                isLoading: _downloadingKey == 'pdfUrl',
                progress: _downloadingKey == 'pdfUrl' ? _downloadProgress : null,
                onTap: _downloadingKey == null
                    ? () => _downloadFile(_content.pdfUrl!, fileKey: 'pdfUrl')
                    : null,
              ),
            if (_content.hasFile) ...[
              if (_content.pdfUrl != null && _content.pdfUrl!.isNotEmpty)
                const SizedBox(height: 8),
              _DownloadTile(
                icon: Icons.folder_zip_outlined,
                name: 'Fichier principal',
                size: _content.fileSize ?? '',
                color: const Color(0xFF25D366),
                isLoading: _downloadingKey == 'fileUrl',
                progress: _downloadingKey == 'fileUrl' ? _downloadProgress : null,
                onTap: _downloadingKey == null
                    ? () => _downloadFile(_content.fileUrl!, fileKey: 'fileUrl')
                    : null,
              ),
            ],
            if (_content.tutorialVideoUrl != null) ...[
              const SizedBox(height: 12),
              _buildTutorialVideoSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.play_lesson_outlined,
                color: Color(0xFF4a90e2), size: 14),
            const SizedBox(width: 6),
            Text(
              'VIDÉO TUTORIEL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF4a90e2),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _isTutorialReady
              ? AspectRatio(
                  aspectRatio: _tutorialController!.value.aspectRatio,
                  child: Chewie(controller: _tutorialChewieController!),
                )
              : AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: _initializingTutorial
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : GestureDetector(
                              onTap: _initTutorialPlayer,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4a90e2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 36),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Regarder le tutoriel',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEpisodesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ÉPISODES',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: _colors.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Episodes')
              .where('seriesId', isEqualTo: _content.id)
              .orderBy('episodeNumber')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator()));
            }
            final eps = snap.data!.docs
                .map((d) => Episode.fromJson(
                    {...d.data() as Map<String, dynamic>, 'id': d.id}))
                .toList();
            if (eps.isEmpty) return const SizedBox.shrink();
            return Column(
              children: eps
                  .map((ep) => _EpisodeRow(
                      episode: ep,
                      hasPurchased: _hasPurchased,
                      colors: _colors))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (_checkingPurchase) {
      return const SizedBox(height: 80);
    }

    final showBuyFlow = !_hasPurchased && !_content.isFree;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: _colors.background,
        border: Border(top: BorderSide(color: _colors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasPurchased || _content.isFree)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF25D366).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle_outline,
                      color: Color(0xFF25D366), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Contenu débloqué',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF25D366)),
                  ),
                ],
              ),
            )
          else if (showBuyFlow) ...[
            // Code promo row
            GestureDetector(
              onTap: () => PromoCodeModal.show(context, _content, (code) {
                setState(() => _appliedPromoCode = code);
              }),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.local_offer_outlined,
                      size: 13, color: Color(0xFF25D366)),
                  const SizedBox(width: 4),
                  Text(
                    _appliedPromoCode != null
                        ? 'Code ${_appliedPromoCode!.code} appliqué — changer'
                        : 'Avez-vous un code promo ?',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF25D366),
                        fontWeight: FontWeight.w700),
                  ),
                  if (_appliedPromoCode != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _appliedPromoCode = null),
                      child: const Icon(Icons.cancel_outlined,
                          size: 14, color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Bandeau affiliation — visible seulement si l'acheteur vient via un lien affilié
            if (_affiliateId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF25D366).withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.handshake_outlined, size: 14, color: Color(0xFF25D366)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Achat via lien d\'affiliation',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF25D366),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('affiliate_ref_${_content.id}');
                        await prefs.remove('affiliate_ref_${_content.id}_ts');
                        if (mounted) setState(() => _affiliateId = null);
                      },
                      child: const Icon(Icons.close, size: 14, color: Color(0xFF25D366)),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_appliedPromoCode != null)
                      Text(
                        '${_content.effectivePrice.toInt()} F',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _colors.textSecondary,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Text(
                      '${_finalPrice.toInt()} F',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD400),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                if (_isOwner || _isAdmin)
                  OutlinedButton.icon(
                    onPressed: () => BoostModal.show(context, _content,
                        isAdmin: _isAdmin),
                    icon: const Icon(Icons.bolt,
                        size: 16, color: Color(0xFFFFD400)),
                    label: const Text('Booster',
                        style: TextStyle(color: Color(0xFFFFD400))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFFFD400), width: 1.5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _buying ? null : _buy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _buying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text(
                            'Acheter maintenant',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showOwnerMenu() {
    showResponsiveBottomSheet(
      context: context,
      backgroundColor: _colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bolt, color: Color(0xFFFFD400)),
              title: Text(_isAdmin ? 'Booster (gratuit)' : 'Booster'),
              onTap: () {
                Navigator.pop(context);
                BoostModal.show(context, _content, isAdmin: _isAdmin);
              },
            ),
            if (_isOwner) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier le contenu'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContentFormScreen(content: _content),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.discount_outlined,
                    color: Color(0xFF25D366)),
                title: const Text('Codes promo'),
                subtitle: const Text('Créer et gérer vos codes de réduction'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CreatorPromoCodesPage(content: _content),
                    ),
                  );
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Supprimer',
                  style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(String url, {required String fileKey}) async {
    final contentId = _content.id;
    if (contentId == null || _downloadingKey != null) return;

    setState(() {
      _downloadingKey = fileKey;
      _downloadProgress = 0.0;
    });

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getSecureDownloadUrl');
      final result = await callable.call({
        'contentId': contentId,
        'fileKey': fileKey,
      });
      final signedUrl = result.data['url'] as String?;
      if (signedUrl == null) throw Exception('URL manquante');

      if (!mounted) return;
      _showDownloadLinkDialog(signedUrl, fileKey);
    } catch (e) {
      if (!mounted) return;
      _showResultDialog(success: false, message: _friendlyError(e));
    } finally {
      if (mounted) setState(() => _downloadingKey = null);
    }
  }

  void _showDownloadLinkDialog(String signedUrl, String fileKey) {
    final ext = _fileExtension(fileKey);
    final label = ext == '.pdf'
        ? 'PDF'
        : ext == '.mp4'
            ? 'Vidéo'
            : 'Fichier';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4a90e2).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.link_rounded,
                      color: Color(0xFF4a90e2), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Lien de téléchargement',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _colors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Lien valide 1 heure. Ouvrez-le dans votre navigateur pour télécharger le $label.',
              style: TextStyle(
                  fontSize: 12, color: _colors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 12),
            // Affichage du lien
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _colors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _colors.divider),
              ),
              child: Text(
                signedUrl,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    color: _colors.textSecondary,
                    fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 14),
            // Bouton Copier
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: signedUrl));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lien copié !'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                label: const Text('Copier le lien',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4a90e2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Bouton Ouvrir dans le navigateur
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(signedUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
                icon: Icon(Icons.open_in_browser_rounded,
                    size: 16, color: _colors.textPrimary),
                label: Text('Ouvrir dans le navigateur',
                    style: TextStyle(
                        color: _colors.textPrimary,
                        fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _colors.divider),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Fermer',
                    style: TextStyle(
                        fontSize: 12, color: _colors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fileExtension(String fileKey) {
    switch (fileKey) {
      case 'pdfUrl':
        return '.pdf';
      case 'videoUrl':
      case 'tutorialVideoUrl':
        return '.mp4';
      case 'fileUrl':
        return ''; // Extension déjà dans le nom original
      default:
        return '';
    }
  }


  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}';
    return '${m}min';
  }

  String _typeEmoji(ContentType t) {
    switch (t) {
      case ContentType.VIDEO:
        return '🎬';
      case ContentType.EBOOK:
        return '📘';
      case ContentType.FORMATION:
        return '🎓';
      case ContentType.TEMPLATE:
        return '🎨';
      case ContentType.PACK_ZIP:
        return '📦';
      case ContentType.AUDIO:
        return '🎵';
      case ContentType.PRESET:
        return '🎛️';
      case ContentType.BUNDLE:
        return '🗂️';
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? label;

  const _StatChip({required this.icon, required this.value, this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.textSecondary),
        const SizedBox(width: 3),
        Text(
          label != null ? '$value $label' : value,
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ContentType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _info(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  (String, Color) _info(ContentType t) {
    switch (t) {
      case ContentType.VIDEO:
        return ('VIDÉO', const Color(0xFF4a90e2));
      case ContentType.EBOOK:
        return ('EBOOK', const Color(0xFF9b59b6));
      case ContentType.FORMATION:
        return ('FORMATION', const Color(0xFF8e44ad));
      case ContentType.TEMPLATE:
        return ('TEMPLATE', const Color(0xFFFFD400));
      case ContentType.PACK_ZIP:
        return ('PACK ZIP', const Color(0xFF25D366));
      case ContentType.AUDIO:
        return ('AUDIO', const Color(0xFFe67e22));
      case ContentType.PRESET:
        return ('PRESET', const Color(0xFF1abc9c));
      case ContentType.BUNDLE:
        return ('BUNDLE', const Color(0xFFe74c3c));
    }
  }
}

class _DownloadTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String size;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;
  final double? progress; // 0.0→1.0, null = indéterminé

  const _DownloadTile({
    required this.icon,
    required this.name,
    required this.size,
    required this.color,
    required this.onTap,
    this.isLoading = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    color: isLoading ? colors.textSecondary : color,
                    size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isLoading
                                  ? colors.textSecondary
                                  : colors.textPrimary)),
                      if (isLoading)
                        Text(
                          progress != null
                              ? '${(progress! * 100).toInt()}%'
                              : 'Connexion...',
                          style: TextStyle(
                              fontSize: 10, color: colors.textSecondary),
                        )
                      else if (size.isNotEmpty)
                        Text(size,
                            style: TextStyle(
                                fontSize: 10,
                                color: colors.textSecondary)),
                    ],
                  ),
                ),
                if (isLoading)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: (progress != null && progress! > 0)
                          ? progress
                          : null,
                      color: color,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      icon == Icons.play_circle_outline ? '▶' : '⬇',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color),
                    ),
                  ),
              ],
            ),
            // Barre de progression sous la ligne
            if (isLoading && progress != null && progress! > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  final Episode episode;
  final bool hasPurchased;
  final AppColors colors;

  const _EpisodeRow({
    required this.episode,
    required this.hasPurchased,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = !hasPurchased && !episode.isFree;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isLocked
                  ? colors.surface
                  : const Color(0xFF25D366).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: isLocked
                    ? colors.divider
                    : const Color(0xFF25D366).withOpacity(0.4),
              ),
            ),
            child: Center(
              child: Text(
                'E${episode.episodeNumber}',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isLocked
                        ? colors.textSecondary
                        : const Color(0xFF25D366)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 52,
            height: 38,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text('🎬', style: const TextStyle(fontSize: 18)),
                if (isLocked)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.lock_outline,
                        color: Colors.white, size: 14),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  episode.isFree
                      ? 'Gratuit'
                      : '${episode.price.toInt()} F',
                  style: TextStyle(
                      fontSize: 10,
                      color: episode.isFree
                          ? const Color(0xFF25D366)
                          : const Color(0xFFFFD400)),
                ),
              ],
            ),
          ),
          if (!isLocked)
            const Icon(Icons.play_circle_outline,
                color: Color(0xFF25D366), size: 26)
          else
            const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}
