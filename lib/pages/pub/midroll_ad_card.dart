import 'dart:async';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/canaux/detailsCanal.dart';
import 'package:afrotok/pages/user/otherUser/otherUser.dart';
import 'package:afrotok/pages/user/userAbonnementPage.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/post_video_format_tel_details.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/services/utils/abonnement_utils.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Pub affichée pendant une vidéo (pages vidéo portrait et paysage).
/// Aucune fermeture automatique : après [closeDelaySeconds] secondes d'attente,
/// l'utilisateur ferme lui-même la pub avec le bouton « Fermer ».
class MidrollAdCard extends StatefulWidget {
  final Map<String, dynamic>? adData;
  final VideoPlayerController? videoController;
  final bool videoInitialized;
  final VoidCallback onClose;
  final int closeDelaySeconds;

  const MidrollAdCard({
    super.key,
    required this.adData,
    required this.videoController,
    required this.videoInitialized,
    required this.onClose,
    this.closeDelaySeconds = 5,
  });

  @override
  State<MidrollAdCard> createState() => _MidrollAdCardState();
}

class _MidrollAdCardState extends State<MidrollAdCard> {
  late int _countdown = widget.closeDelaySeconds;
  bool _ctaLoading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { if (_countdown > 0) _countdown--; });
      if (_countdown <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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

  Future<void> _navigateToAdOwner(BuildContext ctx, String ownerId, String? ownerType) async {
    try {
      final fs = FirebaseFirestore.instance;
      switch (ownerType) {
        case 'canal':
          final doc = await fs.collection('Canaux').doc(ownerId).get();
          if (!doc.exists || !ctx.mounted) return;
          final data = Map<String, dynamic>.from(doc.data()!);
          data['id'] = doc.id;
          Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => CanalDetails(canal: Canal.fromJson(data)),
          ));
          break;
        case 'user':
        default:
          final doc = await fs.collection('Users').doc(ownerId).get();
          if (!doc.exists || !ctx.mounted) return;
          final data = Map<String, dynamic>.from(doc.data()!);
          data['id'] = doc.id;
          Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => OtherUserPage(otherUser: UserData.fromJson(data)),
          ));
      }
    } catch (e) {
      debugPrint('_navigateToAdOwner error: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final adData = widget.adData;

    Post? post;
    Advertisement? ad;
    String? thumb;
    String caption = '';
    String btnText = 'En savoir plus';

    if (adData != null) {
      // Parse l'annonce en premier (toujours disponible)
      try {
        ad = Advertisement.fromJson(adData['ad'] as Map<String, dynamic>);
      } catch (_) {}

      final isEntityBoost = adData['isEntityBoost'] == true;
      if (isEntityBoost && ad != null) {
        // Boost entité : description de la pub (saisie par l'annonceur)
        thumb = ad!.ownerAvatar?.isNotEmpty == true ? ad!.ownerAvatar : null;
        caption = ad!.description ?? '';
        btnText = _ownerCtaLabel(ad!.ownerType);
      } else if (!isEntityBoost) {
        // Boost post standard
        try {
          post = Post.fromJson(adData['post'] as Map<String, dynamic>);
          if (post!.thumbnail?.isNotEmpty == true) thumb = post!.thumbnail;
          else if (post!.images?.isNotEmpty == true && post!.images!.first.isNotEmpty) thumb = post!.images!.first;
          // Description de la pub en priorité, fallback sur le post
          caption = ad?.description?.isNotEmpty == true ? ad!.description! : post!.description ?? '';
          btnText = ad?.actionButtonText ?? 'En savoir plus';
        } catch (_) {}
      }
    }

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.93),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenH * 0.72, maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Barre de header : badge + close ──
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('SPONSORISÉ',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.none)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _countdown <= 0 ? widget.onClose : null,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _countdown > 0 ? Colors.white12 : Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: _countdown > 0
                                ? Text(
                                    '$_countdown',
                                    style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                                  )
                                : const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Carte principale ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        color: const Color(0xFF1A1A1A),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Zone média : vidéo auto-play muet ou image
                            GestureDetector(
                              onTap: () {
                                if (post != null && ad != null) {
                                  widget.onClose();
                                  if (post.dataType == PostDataType.VIDEO.name ||
                                      (post.url_media?.contains('.mp4') ?? false)) {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => PostDetailsVideoFormatTel(initialPost: post!, isIn: false),
                                    ));
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => DetailsPost(post: post!),
                                    ));
                                  }
                                }
                              },
                              child: Builder(builder: (ctx) {
                                final isVideo = widget.videoInitialized && widget.videoController != null;
                                final videoSize = isVideo ? widget.videoController!.value.size : Size.zero;
                                final videoRatio = (isVideo && videoSize.height > 0)
                                    ? videoSize.width / videoSize.height
                                    : 16 / 9;
                                return Container(
                                  color: Colors.black,
                                  constraints: BoxConstraints(
                                    maxHeight: MediaQuery.of(ctx).size.height * 0.42,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: isVideo ? videoRatio : 4 / 3,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Container(color: Colors.black),
                                        // Vidéo en contain : pas de déformation ni de crop
                                        if (isVideo)
                                          FittedBox(
                                            fit: BoxFit.contain,
                                            child: SizedBox(
                                              width: videoSize.width,
                                              height: videoSize.height,
                                              child: VideoPlayer(widget.videoController!),
                                            ),
                                          )
                                        else if (thumb != null)
                                          CachedNetworkImage(
                                            imageUrl: thumb,
                                            fit: BoxFit.contain,
                                            placeholder: (_, __) => const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)),
                                            ),
                                            errorWidget: (_, __, ___) => const Icon(Icons.image, color: Colors.white38, size: 48),
                                          )
                                        else
                                          const Icon(Icons.image, color: Colors.white38, size: 48),
                                        // Badge VIDÉO
                                        if (post != null && (post.dataType == PostDataType.VIDEO.name ||
                                            (post.url_media?.contains('.mp4') ?? false)))
                                          Positioned(
                                            bottom: 8, right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.7),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.videocam, color: Colors.white, size: 12),
                                                  SizedBox(width: 3),
                                                  Text('VIDÉO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        // Icône son coupé
                                        if (widget.videoInitialized)
                                          Positioned(
                                            top: 8, left: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                              child: const Icon(Icons.volume_off, color: Colors.white, size: 14),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),

                            // ── Infos pub ──
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (caption.isNotEmpty)
                                    Text(
                                      caption,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  if (caption.isNotEmpty) const SizedBox(height: 10),

                                  // ── Profil / entité boostée ──
                                  if (ad != null && ad!.ownerName?.isNotEmpty == true) ...[
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 14),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.07),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                                      ),
                                      child: Row(
                                        children: [
                                          // Avatar
                                          ClipOval(
                                            child: SizedBox(
                                              width: 42, height: 42,
                                              child: ad!.ownerAvatar?.isNotEmpty == true
                                                  ? CachedNetworkImage(
                                                      imageUrl: ad!.ownerAvatar!,
                                                      fit: BoxFit.cover,
                                                      placeholder: (_, __) => Container(color: const Color(0xFFFFD700).withOpacity(0.3)),
                                                      errorWidget: (_, __, ___) => Container(
                                                        color: const Color(0xFFFFD700).withOpacity(0.3),
                                                        child: const Icon(Icons.person, color: Color(0xFFFFD700), size: 20),
                                                      ),
                                                    )
                                                  : Container(
                                                      color: const Color(0xFFFFD700).withOpacity(0.3),
                                                      child: const Icon(Icons.person, color: Color(0xFFFFD700), size: 20),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Infos
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ad!.ownerName!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    decoration: TextDecoration.none,
                                                  ),
                                                ),
                                                if (ad!.ownerDescription?.isNotEmpty == true)
                                                  Text(
                                                    ad!.ownerDescription!,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 11,
                                                      decoration: TextDecoration.none,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Bouton suivre / rejoindre
                                          GestureDetector(
                                            onTap: _ctaLoading ? null : () async {
                                              final ownerId = ad!.ownerId;
                                              final ownerType = ad!.ownerType;
                                              if (ownerId == null) return;
                                              setState(() => _ctaLoading = true);
                                              widget.onClose();
                                              await _navigateToAdOwner(context, ownerId, ownerType);
                                              if (mounted) setState(() => _ctaLoading = false);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFD700),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: _ctaLoading
                                                  ? const SizedBox(
                                                      height: 14, width: 14,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation(Colors.black),
                                                      ))
                                                  : Text(
                                                      _ownerCtaLabel(ad!.ownerType),
                                                      style: const TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w800,
                                                        decoration: TextDecoration.none,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // ── Mini-feed 3 derniers posts ──
                                    if (ad!.ownerRecentPosts?.isNotEmpty == true)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: ad!.ownerRecentPosts!.take(3).map((p) {
                                                final thumb = p['thumb'] as String? ?? '';
                                                final isVideo = p['isVideo'] as bool? ?? false;
                                                return Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(right: 6),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(10),
                                                      child: AspectRatio(
                                                        aspectRatio: 1,
                                                        child: Stack(
                                                          fit: StackFit.expand,
                                                          children: [
                                                            if (thumb.isNotEmpty)
                                                              CachedNetworkImage(
                                                                imageUrl: thumb,
                                                                fit: BoxFit.cover,
                                                                placeholder: (_, __) => Container(color: Colors.white10),
                                                                errorWidget: (_, __, ___) => Container(color: Colors.white10),
                                                              )
                                                            else
                                                              Container(color: Colors.white10),
                                                            // Overlay sombre
                                                            Container(color: Colors.black.withOpacity(0.40)),
                                                            // Icône vidéo
                                                            if (isVideo)
                                                              const Center(
                                                                child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 22),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 12),
                                            // CTA pleine largeur "Suivre ce créateur"
                                            GestureDetector(
                                              onTap: _ctaLoading ? null : () async {
                                                final ownerId = ad!.ownerId;
                                                final ownerType = ad!.ownerType;
                                                if (ownerId == null) return;
                                                setState(() => _ctaLoading = true);
                                                widget.onClose();
                                                await _navigateToAdOwner(context, ownerId, ownerType);
                                                if (mounted) setState(() => _ctaLoading = false);
                                              },
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFD700),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: _ctaLoading
                                                    ? const Center(
                                                        child: SizedBox(
                                                          height: 18, width: 18,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2.5,
                                                            valueColor: AlwaysStoppedAnimation(Colors.black),
                                                          )))
                                                    : Text(
                                                        _ownerCtaLabel(ad!.ownerType) == 'Suivre'
                                                            ? 'Suivre ce créateur'
                                                            : _ownerCtaLabel(ad!.ownerType) == "S'abonner"
                                                                ? 'S\'abonner à ce canal'
                                                                : 'Rejoindre ${ad!.ownerName ?? ''}',
                                                        textAlign: TextAlign.center,
                                                        style: const TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w800,
                                                          decoration: TextDecoration.none,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],

                                  // Stats pub (vues toujours, clics uniquement admin/propriétaire)
                                  if (ad != null && (ad!.views ?? 0) > 0) ...[
                                    Builder(builder: (ctx) {
                                      final authProvider = Provider.of<UserAuthProvider>(ctx, listen: false);
                                      final uid = authProvider.loginUserData.id;
                                      final showClicks = uid != null &&
                                          (uid == ad!.ownerId ||
                                              AbonnementUtils.isAdmin(authProvider.loginUserData.role));
                                      return Column(mainAxisSize: MainAxisSize.min, children: [
                                        const SizedBox(height: 10),
                                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          const Icon(Icons.remove_red_eye_outlined, size: 13, color: Colors.white54),
                                          const SizedBox(width: 4),
                                          Text('${ad!.views} vues',
                                            style: const TextStyle(color: Colors.white54, fontSize: 11, decoration: TextDecoration.none)),
                                          if (showClicks && (ad!.clicks ?? 0) > 0) ...[
                                            const SizedBox(width: 12),
                                            const Icon(Icons.touch_app_outlined, size: 13, color: Colors.white54),
                                            const SizedBox(width: 4),
                                            Text('${ad!.clicks} clics',
                                              style: const TextStyle(color: Colors.white54, fontSize: 11, decoration: TextDecoration.none)),
                                          ],
                                        ]),
                                      ]);
                                    }),
                                  ],
                                  const SizedBox(height: 12),

                                  // Bouton CTA
                                  SizedBox(
                                    width: double.infinity,
                                    child: GestureDetector(
                                      onTap: _ctaLoading ? null : () async {
                                        if (ad == null) return;
                                        widget.onClose();
                                        if (post != null) {
                                          if (post!.dataType == PostDataType.VIDEO.name ||
                                              (post!.url_media?.contains('.mp4') ?? false)) {
                                            Navigator.push(context, MaterialPageRoute(
                                              builder: (_) => PostDetailsVideoFormatTel(initialPost: post!, isIn: false),
                                            ));
                                          } else {
                                            Navigator.push(context, MaterialPageRoute(
                                              builder: (_) => DetailsPost(post: post!),
                                            ));
                                          }
                                        } else if (ad!.ownerId != null) {
                                          setState(() => _ctaLoading = true);
                                          await _navigateToAdOwner(context, ad!.ownerId!, ad!.ownerType);
                                          if (mounted) setState(() => _ctaLoading = false);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                                          ),
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        child: _ctaLoading
                                            ? const Center(
                                                child: SizedBox(
                                                  height: 20, width: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                                  )))
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.open_in_new, color: Colors.white, size: 16),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    btnText,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      decoration: TextDecoration.none,
                                                    ),
                                                  ),
                                                ],
                                              ),
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

                    const SizedBox(height: 14),

                    // ── Countdown / bouton Fermer ──
                    if (_countdown > 0) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _countdown / 5.0,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Fermer disponible dans ${_countdown}s',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ] else
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white38),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'Fermer',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // ── Lien "Ne plus voir" ──
                    GestureDetector(
                      onTap: () {
                        widget.onClose();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AbonnementScreen(initialTab: 1)));
                      },
                      child: const Text(
                        'Ne plus voir de pubs → Premium',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
