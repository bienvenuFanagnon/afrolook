import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../pages/canaux/detailsCanal.dart';
import '../../../pages/component/showUserDetails.dart';
import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';

/// Variante B — Card pub profil/canal avec bande de posts pleine largeur.
///
/// Données entièrement tirées de l'objet [Advertisement] (entity boost) :
/// - [Advertisement.description] → texte de la pub (saisi par l'annonceur)
/// - [Advertisement.ownerRecentPosts] → vignettes pré-snapshotées (1–3 posts)
/// - [Advertisement.ownerAvatar] / [ownerName] / [ownerFollowers]
///
/// Aucune query Firestore supplémentaire — tout est déjà dans le document boost.
class FeedCreatorPostsCard extends StatefulWidget {
  final Advertisement ad;
  const FeedCreatorPostsCard({Key? key, required this.ad}) : super(key: key);

  @override
  State<FeedCreatorPostsCard> createState() => _FeedCreatorPostsCardState();
}

class _FeedCreatorPostsCardState extends State<FeedCreatorPostsCard> {
  bool _followed = false;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyFollowed();
  }

  void _checkAlreadyFollowed() {
    try {
      final auth = context.read<UserAuthProvider>();
      final me = auth.loginUserData;
      final ownerId = widget.ad.ownerId ?? '';
      if (ownerId.isEmpty) return;

      final isUser = (widget.ad.ownerType ?? '') == 'user';
      if (isUser) {
        final following = Set<String>.from(me.followingIds ?? []);
        if (following.contains(ownerId)) setState(() => _followed = true);
      } else {
        // Canal : on ne peut pas vérifier facilement sans données locales
        // → on ne prémarque pas le bouton pour éviter un faux positif
      }
    } catch (_) {}
  }

  Future<void> _handleCta() async {
    if (_followed || _following) return;
    final auth = context.read<UserAuthProvider>();
    final myId = auth.loginUserData.id ?? '';
    if (myId.isEmpty) return;

    final ownerId = widget.ad.ownerId ?? '';
    if (ownerId.isEmpty) return;

    setState(() => _following = true);

    final isUser = (widget.ad.ownerType ?? '') == 'user';
    final fs = FirebaseFirestore.instance;
    try {
      if (isUser) {
        await Future.wait([
          fs.collection('Users').doc(ownerId).update({
            'userAbonnesIds': FieldValue.arrayUnion([myId]),
            'abonnes': FieldValue.increment(1),
          }),
          fs.collection('Users').doc(myId).update({
            'followingIds': FieldValue.arrayUnion([ownerId]),
          }),
        ]);
        auth.loginUserData.followingIds ??= [];
        if (!auth.loginUserData.followingIds!.contains(ownerId)) {
          auth.loginUserData.followingIds!.add(ownerId);
        }
        FirebaseFunctions.instance
            .httpsCallable('backfillPostsOnFollow')
            .call({'followedUserId': ownerId}).ignore();
      } else {
        await Future.wait([
          fs.collection('Canaux').doc(ownerId).update({
            'usersSuiviId': FieldValue.arrayUnion([myId]),
            'suivi': FieldValue.increment(1),
          }),
          fs.collection('Users').doc(myId).update({
            'canauxSuivisIds': FieldValue.arrayUnion([ownerId]),
          }),
        ]);
      }
      if (mounted) setState(() { _followed = true; _following = false; });
    } catch (_) {
      if (mounted) setState(() => _following = false);
    }
  }

  void _openOwner() {
    final ownerId = widget.ad.ownerId ?? '';
    if (ownerId.isEmpty) return;

    final isCanal = (widget.ad.ownerType ?? '') == 'canal';
    if (isCanal) {
      final canal = Canal(
        id: ownerId,
        titre: widget.ad.ownerName,
        urlImage: widget.ad.ownerAvatar,
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CanalDetails(canal: canal)),
      );
    } else {
      final user = UserData()
        ..id = ownerId
        ..pseudo = widget.ad.ownerName
        ..imageUrl = widget.ad.ownerAvatar;
      final w = MediaQuery.of(context).size.width;
      final h = MediaQuery.of(context).size.height;
      showUserDetailsModalDialog(user, w, h, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ad = widget.ad;

    final String name = ad.ownerName ?? '';
    final String? avatarUrl = ad.ownerAvatar;
    final int followers = ad.ownerFollowers ?? 0;
    final String? pubDescription = ad.description;
    final bool isCanal = (ad.ownerType ?? '') == 'canal';
    final String category = ad.ownerCategory?.isNotEmpty == true
        ? ad.ownerCategory!
        : 'Looks';

    final String metaLabel = isCanal
        ? '$followers membre${followers > 1 ? 's' : ''} · $category'
        : '$followers abonné${followers > 1 ? 's' : ''} · $category';

    final String ctaLabel = _following
        ? '...'
        : (_followed
            ? (isCanal ? 'Rejoint ✓' : 'Suivi ✓')
            : (isCanal ? 'Rejoindre' : 'Suivre'));

    // Vignettes pré-snapshotées — liste vide tolérée (affichage dégradé gracieux)
    final recentPosts =
        List<Map<String, dynamic>>.from(ad.ownerRecentPosts ?? []);

    return GestureDetector(
      onTap: _openOwner,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Avatar(url: avatarUrl, isCanal: isCanal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCanal ? '#$name' : '@$name',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              metaLabel,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CtaButton(
                        label: ctaLabel,
                        done: _followed,
                        loading: _following,
                        onPressed: _handleCta,
                      ),
                    ],
                  ),

                  // Description de la pub (texte saisi par l'annonceur)
                  if (pubDescription?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      pubDescription!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],

                  // Badge "Sponsorisé"
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.campaign_outlined,
                          size: 11, color: colors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        'Sponsorisé',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Bande de posts ───────────────────────────────────────────────
            if (recentPosts.isNotEmpty)
              _PostBand(posts: recentPosts, colors: colors)
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ── Widgets internes ─────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? url;
  final bool isCanal;
  const _Avatar({this.url, required this.isCanal});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return CircleAvatar(
      radius: 22,
      backgroundColor: colors.surfaceVariant,
      child: url?.isNotEmpty == true
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    _icon(isCanal, colors),
              ),
            )
          : _icon(isCanal, colors),
    );
  }

  Widget _icon(bool canal, AppColors c) =>
      Icon(canal ? Icons.tv : Icons.person,
          color: c.textSecondary, size: 20);
}

class _CtaButton extends StatelessWidget {
  final String label;
  final bool done;
  final bool loading;
  final VoidCallback onPressed;
  const _CtaButton({
    required this.label,
    required this.done,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: done || loading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: done ? Colors.transparent : const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: done
                ? Colors.grey.withOpacity(0.4)
                : const Color(0xFFFFD700),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  color: done ? Colors.grey : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }
}

/// Bande horizontale pleine largeur avec 1, 2 ou 3 vignettes pré-snapshotées.
/// Chaque map du snapshot contient : { 'thumb': String, 'isVideo': bool }
class _PostBand extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final AppColors colors;
  const _PostBand({required this.posts, required this.colors});

  @override
  Widget build(BuildContext context) {
    final count = posts.length.clamp(1, 3);
    // Ratio : 1 post → 16/9, 2 posts → 2:1, 3 posts → 3:1
    final ratio = count == 1 ? 16 / 9.0 : count == 2 ? 2.0 : 3.0;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(14),
        bottomRight: Radius.circular(14),
      ),
      child: AspectRatio(
        aspectRatio: ratio,
        child: Row(
          children: List.generate(count, (i) {
            final item = posts[i];
            final thumb = (item['thumb'] as String?) ?? '';
            final isVideo = (item['isVideo'] as bool?) ?? false;

            return Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  border: i > 0
                      ? Border(
                          left: BorderSide(
                              color: colors.surface, width: 1.5))
                      : null,
                ),
                child: thumb.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _placeholder(isVideo),
                          ),
                          if (isVideo)
                            Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Colors.white70,
                                size: count == 1 ? 40 : 24,
                              ),
                            ),
                        ],
                      )
                    : _placeholder(isVideo),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _placeholder(bool isVideo) => Center(
        child: Icon(
          isVideo
              ? Icons.play_circle_outline
              : Icons.image_outlined,
          color: colors.textSecondary,
          size: 28,
        ),
      );
}
