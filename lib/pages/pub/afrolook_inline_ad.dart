import 'dart:async';
import 'dart:math';
import 'package:video_player/video_player.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/ad_preload_service.dart';
import '../../services/ad_rotation_service.dart';
import '../../services/media_cache_service.dart';
import '../../services/utils/abonnement_utils.dart';
import '../user/userAbonnementPage.dart';
import '../postDetails.dart';
import '../post_video_format_tel_details.dart';
import '../user/otherUser/otherUser.dart';
import '../canaux/detailsCanal.dart';
import '../chat/group/group_info_page.dart';
import '../chat/group/group_chat_page.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import '../../theme/app_colors.dart';

/// Bannière pub inline affichant un post pub Afrolook (interne).
/// Masquée pour Premium, Gold et Admin.
/// Utilise les pubs préchargées depuis authProvider.advertisements.
class AfrolookInlineAd extends StatefulWidget {
  /// [compact] : format bannière horizontal (pour pages détails).
  /// [compact] = false (défaut) : format carte verticale (feed).
  const AfrolookInlineAd({Key? key, this.compact = false}) : super(key: key);
  final bool compact;

  @override
  State<AfrolookInlineAd> createState() => _AfrolookInlineAdState();
}

class _AfrolookInlineAdState extends State<AfrolookInlineAd> with TickerProviderStateMixin {
  Map<String, dynamic>? _adData;
  String? _lastAdId;
  bool _viewRecorded = false;
  Timer? _rotationTimer;
  VideoPlayerController? _adVideoController;
  bool _adVideoInitialized = false;
  bool _isCtaLoading = false;
  int? _liveFollowers;

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceOffset;
  late Animation<double> _bounceScale;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _bounceOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0,  end: -9.0), weight: 7),
      TweenSequenceItem(tween: Tween(begin: -9.0, end: -2.0), weight: 6),
      TweenSequenceItem(tween: Tween(begin: -2.0, end: -6.0), weight: 4),
      TweenSequenceItem(tween: Tween(begin: -6.0, end:  0.0), weight: 5),
      TweenSequenceItem(tween: ConstantTween(0.0),             weight: 78),
    ]).animate(_bounceCtrl);

    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0,  end: 1.06), weight: 7),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.02), weight: 6),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.04), weight: 4),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0),  weight: 5),
      TweenSequenceItem(tween: ConstantTween(1.0),             weight: 78),
    ]).animate(_bounceCtrl);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickAd();
      _rotationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _pickAd(rotate: true);
      });
    });
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _rotationTimer?.cancel();
    _adVideoController?.dispose();
    _adVideoController = null;
    super.dispose();
  }

  void _pickAd({bool rotate = false}) {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final ads = auth.advertisements;
    if (ads.isEmpty) return;

    // Rotation équitable : chaque appel réclame le prochain index global.
    // Deux bannières adjacentes voient toujours des pubs différentes.
    final idx = AdRotationService.instance.claimNext(ads.length);
    final picked = ads[idx];
    final newId = (picked['ad'] as Map<String, dynamic>?)?['id'];
    if (!rotate && newId == _lastAdId && ads.length > 1) return;

    _lastAdId = newId;
    _viewRecorded = false;
    _liveFollowers = null;
    if (mounted) setState(() { _adData = picked; _adVideoInitialized = false; });
    if (picked['isEntityBoost'] == true) _fetchLiveFollowers(picked);
    _recordView(picked);
    _initAdVideo(picked, auth);
  }

  Future<void> _fetchLiveFollowers(Map<String, dynamic> adData) async {
    try {
      final ad = Advertisement.fromJson(adData['ad'] as Map<String, dynamic>);
      if (ad.ownerId?.isEmpty != false) return;
      final fs = FirebaseFirestore.instance;
      int? count;
      switch (ad.ownerType) {
        case 'canal':
          final doc = await fs.collection('Canaux').doc(ad.ownerId).get();
          count = doc.data()?['suivi'] as int?;
          break;
        case 'group':
          final doc = await fs.collection('Groups').doc(ad.ownerId).get();
          count = doc.data()?['member_count'] as int?;
          break;
        default:
          final doc = await fs.collection('Users').doc(ad.ownerId).get();
          count = doc.data()?['abonnes'] as int?;
      }
      if (mounted && count != null) setState(() => _liveFollowers = count);
    } catch (_) {}
  }

  Future<void> _initAdVideo(Map<String, dynamic> picked, UserAuthProvider auth) async {
    _adVideoController?.dispose();
    _adVideoController = null;
    // Boost entité sans post → pas de vidéo à lire
    if (picked['isEntityBoost'] == true || picked['post'] == null) return;
    try {
      final post = Post.fromJson(picked['post'] as Map<String, dynamic>);
      final isVideo = post.dataType == PostDataType.VIDEO.name ||
          (post.url_media?.contains('.mp4') ?? false) ||
          (post.url_media?.contains('.mov') ?? false);
      if (!isVideo || post.url_media?.isEmpty != false) return;
      final cdnUrl = auth.convertToCdnUrl(post.url_media!, auth.appDefaultData);

      // 1. Contrôleur pré-initialisé disponible → lecture immédiate sans spinner
      final adId = (picked['ad'] as Map<String, dynamic>?)?['id'] as String?;
      if (adId != null) {
        final preloaded = AdPreloadService.instance.claimController(adId);
        if (preloaded != null && preloaded.value.isInitialized) {
          _adVideoController = preloaded;
          preloaded.setVolume(0);
          preloaded.setLooping(true);
          preloaded.play();
          if (mounted) setState(() => _adVideoInitialized = true);
          return;
        }
        preloaded?.dispose();
      }

      // 2. Fallback : cache disque (file) si dispo, sinon réseau + mise en cache bg
      final ctrl = await MediaCacheService.videoController(cdnUrl);
      _adVideoController = ctrl;
      await ctrl.initialize();
      await ctrl.setVolume(0);
      ctrl.setLooping(true);
      ctrl.play();
      if (mounted) setState(() => _adVideoInitialized = true);
    } catch (_) {
      _adVideoController?.dispose();
      _adVideoController = null;
    }
  }

  Future<void> _recordView(Map<String, dynamic> adData) async {
    if (_viewRecorded) return;
    _viewRecorded = true;
    try {
      final ad = Advertisement.fromJson(adData['ad'] as Map<String, dynamic>);
      if (ad.id == null) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final ref = FirebaseFirestore.instance.collection('Advertisements').doc(ad.id);
      await ref.update({
        'views': FieldValue.increment(1),
        'dailyStats.$today.views': FieldValue.increment(1),
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });
      final doc = await ref.get();
      if (doc.exists) {
        final viewers = List<String>.from(doc.data()?['viewersIds'] ?? []);
        if (!viewers.contains(uid)) {
          await ref.update({
            'uniqueViews': FieldValue.increment(1),
            'viewersIds': FieldValue.arrayUnion([uid]),
          });
        }
      }
    } catch (e) {
      printVm('AfrolookInlineAd._recordView error: $e');
    }
  }

  Future<void> _recordClick(Advertisement ad) async {
    if (ad.id == null) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final ref = FirebaseFirestore.instance.collection('Advertisements').doc(ad.id);
      await ref.update({
        'clicks': FieldValue.increment(1),
        'dailyStats.$today.clicks': FieldValue.increment(1),
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });
      final doc = await ref.get();
      if (doc.exists) {
        final clickers = List<String>.from(doc.data()?['clickersIds'] ?? []);
        if (!clickers.contains(uid)) {
          await ref.update({
            'uniqueClicks': FieldValue.increment(1),
            'clickersIds': FieldValue.arrayUnion([uid]),
          });
        }
      }
    } catch (e) {
      printVm('AfrolookInlineAd._recordClick error: $e');
    }
  }

  void _showPremiumModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111111);
    final textSecondary = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF416C)],
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.workspace_premium, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              'Passez à Premium',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 8),
            Text(
              'Profitez d\'Afrolook sans interruption publicitaire.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textSecondary, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 20),
            // Avantages
            _premiumBenefit(Icons.block, 'Aucune pub dans le feed', textPrimary, textSecondary),
            _premiumBenefit(Icons.video_library, 'Vidéos sans interruption', textPrimary, textSecondary),
            _premiumBenefit(Icons.star, 'Badge Premium exclusif', textPrimary, textSecondary),
            _premiumBenefit(Icons.support_agent, 'Support prioritaire', textPrimary, textSecondary),
            const SizedBox(height: 24),
            // Prix
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${AfrolookAbonnement.prixPremiumBase.toInt()} F',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFFFF8C00), decoration: TextDecoration.none),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '/ mois',
                    style: TextStyle(fontSize: 14, color: textSecondary, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Bouton S'abonner
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AbonnementScreen(initialTab: 1)));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF416C)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'S\'abonner maintenant',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                'Non merci, continuer avec les pubs',
                style: TextStyle(fontSize: 12, color: textSecondary, decoration: TextDecoration.none),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumBenefit(IconData icon, String text, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFFFF8C00)),
          ),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 13, color: textPrimary, decoration: TextDecoration.none)),
        ],
      ),
    );
  }

  // ── Helpers profil créateur ──────────────────────────────────────

  String _ownerCtaLabel(String? type) {
    switch (type) {
      case 'canal':     return "S'abonner";
      case 'group':     return 'Rejoindre';
      case 'event':     return 'Participer';
      case 'challenge': return 'Participer';
      case 'product':   return 'Commander';
      case 'service':   return 'Contacter';
      case 'content':   return 'Voir';
      case 'user':      return 'Suivre';
      default:          return 'Voir';
    }
  }

  Future<void> _navigateToAdOwner(BuildContext context, Advertisement ad) async {
    final id = ad.ownerId;
    if (id == null || id.isEmpty) return;
    try {
      final fs = FirebaseFirestore.instance;
      switch (ad.ownerType) {
        case 'canal':
          final doc = await fs.collection('Canaux').doc(id).get();
          if (!doc.exists || !context.mounted) return;
          final data = Map<String, dynamic>.from(doc.data()!);
          data['id'] = doc.id;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CanalDetails(canal: Canal.fromJson(data)),
          ));
          break;
        case 'group':
          if (!context.mounted) return;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => GroupChatPage(
              groupId: id,
              groupName: ad.ownerName ?? 'Groupe',
              groupImageUrl: ad.ownerAvatar ?? '',
            ),
          ));
          break;
        case 'user':
        default:
          final doc = await fs.collection('Users').doc(id).get();
          if (!doc.exists || !context.mounted) return;
          final data = Map<String, dynamic>.from(doc.data()!);
          data['id'] = doc.id;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => OtherUserPage(otherUser: UserData.fromJson(data)),
          ));
      }
    } catch (e) {
      printVm('_navigateToAdOwner error: $e');
    }
  }

  bool _isAdminOrOwner(Advertisement ad, UserAuthProvider auth) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return uid == ad.ownerId || AbonnementUtils.isAdmin(auth.loginUserData?.role);
  }

  // ── Dispatcher entité ──────────────────────────────────────────────
  Widget _buildEntityBoostBanner(BuildContext context, Advertisement ad, String adDescription) {
    if (ad.ownerName?.isEmpty != false) return const SizedBox.shrink();
    if (widget.compact) return _buildEntityBoostBannerHorizontal(context, ad, adDescription);
    switch (ad.ownerType) {
      case 'canal': return _buildCanalCard(context, ad, adDescription);
      case 'group': return _buildGroupCard(context, ad, adDescription);
      default:      return _buildProfileCard(context, ad, adDescription);
    }
  }

  // ── Bannière horizontale compacte (pages détails image + vidéo) ─────
  Widget _buildEntityBoostBannerHorizontal(BuildContext context, Advertisement ad, String adDescription) {
    final colors = AppColors.of(context);
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final showClicks = _isAdminOrOwner(ad, auth);
    final typeLabel = ad.ownerType == 'canal' ? 'Canal' : ad.ownerType == 'group' ? 'Groupe' : 'Créateur';
    final ctaLabel  = ad.ownerType == 'canal' ? "S'abonner" : ad.ownerType == 'group' ? 'Rejoindre' : 'Suivre';
    final ctaIcon   = ad.ownerType == 'canal' ? Icons.notifications_none : ad.ownerType == 'group' ? Icons.login : Icons.person_add;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _isCtaLoading ? null : () async {
            setState(() => _isCtaLoading = true);
            await _recordClick(ad);
            if (context.mounted) await _navigateToAdOwner(context, ad);
            if (mounted) setState(() => _isCtaLoading = false);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: const Border.fromBorderSide(BorderSide(color: Color(0xFFFFD700), width: 2)),
                  ),
                  child: ClipOval(
                    child: ad.ownerAvatar?.isNotEmpty == true
                        ? CachedNetworkImage(imageUrl: ad.ownerAvatar!, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(color: colors.surfaceVariant,
                              child: const Icon(Icons.person, color: Color(0xFFFFD700), size: 20)))
                        : Container(color: colors.surfaceVariant,
                            child: const Icon(Icons.person, color: Color(0xFFFFD700), size: 20)),
                  ),
                ),
                const SizedBox(width: 10),
                // Texte
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badges
                      Row(
                        children: [
                          _sponsoredBadge(),
                          const SizedBox(width: 4),
                          _typeBadge(typeLabel),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(ad.ownerName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: colors.textPrimary, decoration: TextDecoration.none)),
                      if (adDescription.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(adDescription, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: colors.textSecondary, decoration: TextDecoration.none)),
                      ],
                      if ((ad.views ?? 0) > 0)
                        Row(children: [
                          Icon(Icons.remove_red_eye_outlined, size: 10, color: colors.textSecondary),
                          const SizedBox(width: 2),
                          Text('${ad.views}', style: TextStyle(fontSize: 9, color: colors.textSecondary, decoration: TextDecoration.none)),
                          if (showClicks && (ad.clicks ?? 0) > 0) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.touch_app_outlined, size: 10, color: colors.textSecondary),
                            const SizedBox(width: 2),
                            Text('${ad.clicks}', style: TextStyle(fontSize: 9, color: colors.textSecondary, decoration: TextDecoration.none)),
                          ],
                        ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // CTA
                GestureDetector(
                  onTap: _isCtaLoading ? null : () async {
                    setState(() => _isCtaLoading = true);
                    await _recordClick(ad);
                    if (context.mounted) await _navigateToAdOwner(context, ad);
                    if (mounted) setState(() => _isCtaLoading = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _isCtaLoading
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Color(0xFF5a3d00))))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(ctaIcon, size: 13, color: const Color(0xFF5a3d00)),
                              const SizedBox(width: 4),
                              Text(ctaLabel,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                  color: Color(0xFF5a3d00), decoration: TextDecoration.none)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Carte Profil (user) ─────────────────────────────────────────────
  Widget _buildProfileCard(BuildContext context, Advertisement ad, String adDescription) {
    final colors = AppColors.of(context);
    final posts = ad.ownerRecentPosts ?? [];
    final disableAnim = MediaQuery.of(context).disableAnimations;

    return _buildEntityCardShell(
      context: context,
      ad: ad,
      colors: colors,
      disableAnim: disableAnim,
      ctaLabel: 'Suivre',
      ctaIcon: Icons.person_add,
      visualZone: Stack(
        children: [
          // Fond dégradé violet profil
          Container(
            width: double.infinity,
            height: 100,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7A5A9E), Color(0xFF5A3A7E)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          // Avatar centré
          Positioned.fill(
            child: Center(
              child: Container(
                width: 76, height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: const Border.fromBorderSide(BorderSide(color: Color(0xFFFFD700), width: 3)),
                  color: const Color(0xFF7A5A9E),
                ),
                child: ClipOval(
                  child: ad.ownerAvatar?.isNotEmpty == true
                      ? CachedNetworkImage(imageUrl: ad.ownerAvatar!, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _profileAvatarFallback())
                      : _profileAvatarFallback(),
                ),
              ),
            ),
          ),
          // Badge info
          Positioned(top: 8, right: 12,
            child: Icon(Icons.info_outline, size: 16, color: Colors.white54)),
          // Badges sponsorisé + type (inline, pas de bandeau)
        ],
      ),
      badgesInline: true,
      typeLabel: 'Créateur',
      posts: posts,
      adDescription: adDescription,
    );
  }

  Widget _profileAvatarFallback() => Container(
    color: const Color(0xFF7A5A9E),
    child: const Icon(Icons.person, color: Color(0xFFFFD700), size: 34),
  );

  // ── Carte Canal ─────────────────────────────────────────────────────
  Widget _buildCanalCard(BuildContext context, Advertisement ad, String adDescription) {
    final colors = AppColors.of(context);
    final posts = ad.ownerRecentPosts ?? [];
    final disableAnim = MediaQuery.of(context).disableAnimations;

    return _buildEntityCardShell(
      context: context,
      ad: ad,
      colors: colors,
      disableAnim: disableAnim,
      ctaLabel: "S'abonner",
      ctaIcon: Icons.notifications_none,
      visualZone: _buildCoverWithLogo(
        coverColor: const Color(0xFF1C4A6E),
        logo: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            width: 52, height: 52,
            child: ad.ownerAvatar?.isNotEmpty == true
                ? CachedNetworkImage(imageUrl: ad.ownerAvatar!, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _canalLogoFallback())
                : _canalLogoFallback(),
          ),
        ),
        logoShape: BoxShape.rectangle,
        logoRadius: 11,
        badgeTypeLabel: 'Canal',
        borderColor: colors.surface,
      ),
      badgesInline: false,
      typeLabel: 'Canal',
      posts: posts,
      adDescription: adDescription,
    );
  }

  Widget _canalLogoFallback() => Container(
    color: const Color(0xFF1C4A6E),
    child: const Icon(Icons.podcasts, color: Colors.white70, size: 26),
  );

  // ── Carte Groupe ────────────────────────────────────────────────────
  Widget _buildGroupCard(BuildContext context, Advertisement ad, String adDescription) {
    final colors = AppColors.of(context);
    final posts = ad.ownerRecentPosts ?? [];
    final disableAnim = MediaQuery.of(context).disableAnimations;

    return _buildEntityCardShell(
      context: context,
      ad: ad,
      colors: colors,
      disableAnim: disableAnim,
      ctaLabel: 'Rejoindre',
      ctaIcon: Icons.login,
      visualZone: _buildCoverWithLogo(
        coverColor: const Color(0xFF3D2560),
        logo: ClipOval(
          child: SizedBox(
            width: 52, height: 52,
            child: ad.ownerAvatar?.isNotEmpty == true
                ? CachedNetworkImage(imageUrl: ad.ownerAvatar!, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _groupLogoFallback())
                : _groupLogoFallback(),
          ),
        ),
        logoShape: BoxShape.circle,
        logoRadius: 26,
        badgeTypeLabel: 'Groupe',
        borderColor: colors.surface,
      ),
      badgesInline: false,
      typeLabel: 'Groupe',
      posts: posts,
      adDescription: adDescription,
    );
  }

  Widget _groupLogoFallback() => Container(
    color: const Color(0xFF3D2560),
    child: const Icon(Icons.people, color: Colors.white70, size: 26),
  );

  // ── Cover + logo chevauchant (canal / groupe) ───────────────────────
  Widget _buildCoverWithLogo({
    required Color coverColor,
    required Widget logo,
    required BoxShape logoShape,
    required double logoRadius,
    required String badgeTypeLabel,
    required Color borderColor,
  }) {
    return SizedBox(
      height: 78 + 24 + 4, // bandeau + dépassement logo + marge
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bandeau cover
          Container(
            width: double.infinity,
            height: 78,
            decoration: BoxDecoration(
              color: coverColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Stack(children: [
              // Texture légère
              Opacity(
                opacity: 0.12,
                child: Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white24, Colors.transparent],
                    ),
                  ),
                ),
              ),
              // Badge info
              Positioned(top: 8, right: 12,
                child: const Icon(Icons.info_outline, size: 16, color: Colors.white54)),
            ]),
          ),
          // Logo chevauchant
          Positioned(
            bottom: 4,
            left: 0, right: 0,
            child: Center(
              child: Container(
                width: 52 + 6, height: 52 + 6,
                decoration: BoxDecoration(
                  shape: logoShape,
                  borderRadius: logoShape == BoxShape.rectangle ? BorderRadius.circular(logoRadius + 3) : null,
                  color: borderColor,
                ),
                padding: const EdgeInsets.all(3),
                child: logo,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shell commun aux 3 cartes ───────────────────────────────────────
  Widget _buildEntityCardShell({
    required BuildContext context,
    required Advertisement ad,
    required AppColors colors,
    required bool disableAnim,
    required String ctaLabel,
    required IconData ctaIcon,
    required Widget visualZone,
    required bool badgesInline,
    required String typeLabel,
    required List<dynamic> posts,
    required String adDescription,
  }) {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final showClicks = _isAdminOrOwner(ad, auth);
    final followers = _liveFollowers ?? ad.ownerFollowers ?? 0;
    final followersLabel = typeLabel == 'Groupe' ? 'membres' : 'abonnés';

    Widget sponsoredBadges = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sponsoredBadge(),
        const SizedBox(width: 5),
        _typeBadge(typeLabel),
      ],
    );

    Widget ctaButton = AnimatedBuilder(
      animation: _bounceCtrl,
      builder: (_, child) {
        final offset = disableAnim ? 0.0 : _bounceOffset.value;
        final scale  = disableAnim ? 1.0 : _bounceScale.value;
        return Transform.translate(
          offset: Offset(0, offset),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: GestureDetector(
        onTap: _isCtaLoading ? null : () async {
          setState(() => _isCtaLoading = true);
          await _recordClick(ad);
          if (context.mounted) await _navigateToAdOwner(context, ad);
          if (mounted) setState(() => _isCtaLoading = false);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700),
            borderRadius: BorderRadius.circular(30),
          ),
          child: _isCtaLoading
              ? const Center(
                  child: SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF5a3d00)))))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(ctaIcon, size: 16, color: const Color(0xFF5a3d00)),
                    const SizedBox(width: 6),
                    Text(ctaLabel,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: Color(0xFF5a3d00), decoration: TextDecoration.none,
                      )),
                  ],
                ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _isCtaLoading ? null : () async {
            setState(() => _isCtaLoading = true);
            await _navigateToAdOwner(context, ad);
            if (mounted) setState(() => _isCtaLoading = false);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Zone visuelle
                visualZone,

                // Badges inline (profil uniquement — ils sont dans la visual zone pour canal/groupe)
                if (badgesInline)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: sponsoredBadges,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: sponsoredBadges,
                  ),

                // Nom + abonnés
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Column(
                    children: [
                      Text(
                        ad.ownerName ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: colors.textPrimary, decoration: TextDecoration.none,
                        ),
                      ),
                      // Description publicitaire
                      if (adDescription.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          adDescription,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5, color: colors.textPrimary,
                            height: 1.4, decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Mini-posts grid
                if (posts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        ...posts.take(3).map((p) {
                          final thumb = p['thumb'] as String? ?? '';
                          final isVid = p['isVideo'] as bool? ?? false;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: Stack(fit: StackFit.expand, children: [
                                    thumb.isNotEmpty
                                        ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(color: colors.surfaceVariant),
                                            errorWidget: (_, __, ___) => Container(color: colors.surfaceVariant))
                                        : Container(color: colors.surfaceVariant),
                                    Container(color: Colors.black.withOpacity(0.32)),
                                    if (isVid) const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 18)),
                                  ]),
                                ),
                              ),
                            ),
                          );
                        }),
                        // Remplir si < 3 posts
                        ...List.generate((3 - posts.length).clamp(0, 3),
                          (_) => const Expanded(child: SizedBox.shrink())),
                      ],
                    ),
                  ),
                ],

                // Stats pub (vues toujours, clics uniquement admin/propriétaire)
                if ((ad.views ?? 0) > 0 || (showClicks && (ad.clicks ?? 0) > 0))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_red_eye_outlined, size: 11, color: colors.textSecondary),
                        const SizedBox(width: 3),
                        Text('${ad.views ?? 0}',
                            style: TextStyle(fontSize: 10, color: colors.textSecondary,
                                decoration: TextDecoration.none)),
                        if (showClicks && (ad.clicks ?? 0) > 0) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.touch_app_outlined, size: 11, color: colors.textSecondary),
                          const SizedBox(width: 3),
                          Text('${ad.clicks ?? 0}',
                              style: TextStyle(fontSize: 10, color: colors.textSecondary,
                                  decoration: TextDecoration.none)),
                        ],
                      ],
                    ),
                  ),

                // CTA bounce + "Ne plus voir" inline
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Row(
                    children: [
                      Expanded(child: ctaButton),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showPremiumModal(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.workspace_premium, size: 11, color: Colors.grey),
                              SizedBox(width: 3),
                              Text('Ne plus voir',
                                style: TextStyle(fontSize: 10, color: Colors.grey,
                                  decoration: TextDecoration.none, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sponsoredBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Text('Sponsorisé',
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, decoration: TextDecoration.none)),
  );

  Widget _typeBadge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFFFD700).withOpacity(0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label,
      style: const TextStyle(fontSize: 9, color: Color(0xFFFFD700), fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
  );


  Widget _buildOwnerSection(BuildContext context, Advertisement ad, Color subText) {
    if (ad.ownerName?.isEmpty != false) return const SizedBox.shrink();
    final label = _ownerCtaLabel(ad.ownerType);
    final posts = ad.ownerRecentPosts ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Ligne profil ──
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 24, height: 24,
                  child: ad.ownerAvatar?.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: ad.ownerAvatar!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: const Color(0xFFFFD700).withOpacity(0.3)),
                          errorWidget: (_, __, ___) => Container(color: const Color(0xFFFFD700).withOpacity(0.3)),
                        )
                      : Container(
                          color: const Color(0xFFFFD700).withOpacity(0.3),
                          child: const Icon(Icons.person, size: 14, color: Color(0xFFFFD700)),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.ownerName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: subText, fontWeight: FontWeight.w600),
                    ),
                    if (ad.ownerDescription?.isNotEmpty == true)
                      Text(
                        ad.ownerDescription!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: subText.withOpacity(0.6)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _isCtaLoading ? null : () async {
                  setState(() => _isCtaLoading = true);
                  await _recordClick(ad);
                  if (context.mounted) await _navigateToAdOwner(context, ad);
                  if (mounted) setState(() => _isCtaLoading = false);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                  ),
                  child: _isCtaLoading
                      ? const SizedBox(
                          height: 14, width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Color(0xFFFFD700))))
                      : Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFD700),
                            decoration: TextDecoration.none,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        // ── Mini-feed 3 derniers posts ──
        if (posts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                ...posts.take(3).map((p) {
                  final thumb = p['thumb'] as String? ?? '';
                  final isVideo = p['isVideo'] as bool? ?? false;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (thumb.isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: thumb,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: Colors.grey.shade800),
                                  errorWidget: (_, __, ___) => Container(color: Colors.grey.shade800),
                                )
                              else
                                Container(color: Colors.grey.shade800),
                              // Overlay sombre
                              Container(color: Colors.black.withOpacity(0.35)),
                              // Icône vidéo si nécessaire
                              if (isVideo)
                                const Center(
                                  child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 18),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                // Remplir si moins de 3 posts
                ...List.generate(
                  (3 - posts.length).clamp(0, 3),
                  (_) => const Expanded(child: SizedBox.shrink()),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Alias pour compatibilité avec les anciens appels
  Widget _buildOwnerRow(BuildContext context, Advertisement ad, Color subText) =>
      _buildOwnerSection(context, ad, subText);

  void _openPostPage(BuildContext context, Post post, Advertisement ad) {
    _recordClick(ad);
    if (post.dataType == PostDataType.VIDEO.name ||
        (post.url_media?.contains('.mp4') ?? false) ||
        (post.url_media?.contains('.mov') ?? false)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailsVideoFormatTel(initialPost: post, isIn: false),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailsPost(post: post)),
      );
    }
  }

  String? _thumbUrl(Post post) {
    if (post.thumbnail?.isNotEmpty == true) return post.thumbnail;
    final firstImg = post.images?.isNotEmpty == true ? post.images!.first : null;
    if (firstImg?.isNotEmpty == true) return firstImg;
    if (post.dataType != 'VIDEO' && post.url_media?.isNotEmpty == true) return post.url_media;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<UserAuthProvider>(context);
    final abonnement = auth.loginUserData.abonnement;
    final role = auth.loginUserData.role;

    // TODO: réactiver quand le système premium sera prêt
    // if (AbonnementUtils.isPremiumActive(abonnement) || AbonnementUtils.isAdmin(role)) {
    //   return const SizedBox.shrink();
    // }

    // Retry si advertisements vient d'arriver après initState
    if (_adData == null && auth.advertisements.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _adData == null) _pickAd();
      });
    }

    if (_adData == null) return const SizedBox.shrink();

    final isEntityBoost = _adData!['isEntityBoost'] == true;
    final ad = Advertisement.fromJson(_adData!['ad'] as Map<String, dynamic>);

    // ── Boost entité (profil / canal / groupe) ──
    if (isEntityBoost) {
      final adDescription = ad.description ?? '';
      return _buildEntityBoostBanner(context, ad, adDescription);
    }

    // ── Pub post standard ──
    final post = Post.fromJson(_adData!['post'] as Map<String, dynamic>);
    final thumb = _thumbUrl(post);
    final caption = post.description ?? '';
    final btnText = ad.actionButtonText ?? 'En savoir plus';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : const Color(0xFF111111);
    final subText = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _openPostPage(context, post, ad),
          child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header sponsorisé
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Sponsorisé',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            decoration: TextDecoration.none),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.info_outline, size: 14, color: subText),
                  ],
                ),
              ),
              // Contenu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail ou vidéo muette
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 72, height: 72,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: isDark ? Colors.white10 : Colors.black12),
                            if (_adVideoInitialized && _adVideoController != null)
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _adVideoController!.value.size.width,
                                  height: _adVideoController!.value.size.height,
                                  child: VideoPlayer(_adVideoController!),
                                ),
                              )
                            else if (thumb != null)
                              CachedNetworkImage(
                                imageUrl: thumb,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const SizedBox(),
                                errorWidget: (_, __, ___) => Icon(Icons.image, color: subText),
                              )
                            else
                              Icon(Icons.image, color: subText),
                            // Badge play si vidéo
                            if (post.dataType == PostDataType.VIDEO.name ||
                                (post.url_media?.contains('.mp4') ?? false))
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (thumb != null) const SizedBox(width: 10),
                    // Texte
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (caption.isNotEmpty)
                            Text(
                              caption,
                              maxLines: ad.ownerName?.isNotEmpty == true ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: textColor,
                                height: 1.3,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          // Profil / entité boostée
                          _buildOwnerRow(context, ad, subText),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  await _recordClick(ad);
                                  final url = ad.actionUrl;
                                  if (url != null && url.isNotEmpty) {
                                    final uri = Uri.tryParse(url);
                                    if (uri != null && await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    btnText,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        decoration: TextDecoration.none),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showPremiumModal(context),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.workspace_premium, size: 10, color: Colors.grey),
                                    SizedBox(width: 3),
                                    Text('Ne plus voir',
                                      style: TextStyle(fontSize: 10, color: Colors.grey,
                                        decoration: TextDecoration.none, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        ), // GestureDetector card
      ],
    );
  }
}
