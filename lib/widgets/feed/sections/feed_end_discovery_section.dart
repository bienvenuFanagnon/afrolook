import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../pages/canaux/detailsCanal.dart';
import '../../../pages/component/showUserDetails.dart';
import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';

/// Section de fin de feed — créateurs et canaux non encore suivis.
/// Chargement autonome, pas de dépendance sur l'état parent.
/// [pageType] : si fourni (ex: 'SPORT'), filtre créateurs et canaux par catégorie.
class FeedEndDiscoverySection extends StatefulWidget {
  final String? pageType;
  const FeedEndDiscoverySection({Key? key, this.pageType}) : super(key: key);

  @override
  State<FeedEndDiscoverySection> createState() =>
      _FeedEndDiscoverySectionState();
}

class _FeedEndDiscoverySectionState extends State<FeedEndDiscoverySection> {
  static const _afroYellow = Color(0xFFFFD700);

  List<UserData> _suggestedUsers = [];
  List<Canal> _suggestedCanaux = [];
  bool _loading = true;

  // Suivi local optimiste pour les utilisateurs uniquement
  final Set<String> _followedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final me = auth.loginUserData;
    final myId = me.id ?? '';
    final alreadyFollowing = Set<String>.from(me.followingIds ?? []);
    alreadyFollowing.add(myId); // exclure soi-même

    try {
      final results = await Future.wait([
        _fetchUsers(alreadyFollowing),
        _fetchCanaux(myId),
      ]);

      if (!mounted) return;
      setState(() {
        _suggestedUsers = results[0] as List<UserData>;
        _suggestedCanaux = results[1] as List<Canal>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<UserData>> _fetchUsers(Set<String> exclude) async {
    final pageType = widget.pageType;
    QuerySnapshot<Map<String, dynamic>> snap;
    // mainCategory dans UserData utilise les mêmes valeurs uppercase que les posts/canaux
    if (pageType != null && pageType.isNotEmpty) {
      snap = await FirebaseFirestore.instance
          .collection('Users')
          .where('status', isEqualTo: 'VALIDE')
          .where('mainCategory', isEqualTo: pageType)
          .limit(20)
          .get();
    } else {
      snap = await FirebaseFirestore.instance
          .collection('Users')
          .where('status', isEqualTo: 'VALIDE')
          .orderBy('creatorScore', descending: true)
          .limit(20)
          .get();
    }

    final all = snap.docs
        .map((d) {
          try {
            return UserData.fromJson(d.data())..id = d.id;
          } catch (_) {
            return null;
          }
        })
        .whereType<UserData>()
        .where((u) => u.id != null && !exclude.contains(u.id))
        .toList();

    all.shuffle(Random());
    return all.take(5).toList();
  }

  Future<List<Canal>> _fetchCanaux(String myId) async {
    final snap = await FirebaseFirestore.instance
        .collection('Canaux')
        .orderBy('canalScore', descending: true)
        .limit(30)
        .get();

    final pageType = widget.pageType;
    final all = snap.docs
        .map((d) {
          try {
            return Canal.fromJson(d.data())..id = d.id;
          } catch (_) {
            return null;
          }
        })
        .whereType<Canal>()
        .where((c) => !(c.usersSuiviId?.contains(myId) ?? false))
        .where((c) {
          if (pageType == null || pageType.isEmpty) return true;
          // Filtrer par catégorie principale ou liste de catégories du canal
          final matchMain = c.mainCategory == pageType;
          final matchList = c.categories?.contains(pageType) ?? false;
          return matchMain || matchList;
        })
        .toList();

    all.shuffle(Random());
    return all.take(3).toList();
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _followUser(UserData user) async {
    final uid = user.id;
    if (uid == null) return;
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final myId = auth.loginUserData.id ?? '';
    if (myId.isEmpty) return;

    setState(() => _followedIds.add(uid));

    final fs = FirebaseFirestore.instance;
    try {
      await Future.wait([
        fs.collection('Users').doc(uid).update({
          'userAbonnesIds': FieldValue.arrayUnion([myId]),
          'abonnes': FieldValue.increment(1),
        }),
        fs.collection('Users').doc(myId).update({
          'followingIds': FieldValue.arrayUnion([uid]),
        }),
      ]);
      auth.loginUserData.followingIds ??= [];
      if (!auth.loginUserData.followingIds!.contains(uid)) {
        auth.loginUserData.followingIds!.add(uid);
      }
    } catch (_) {
      if (mounted) setState(() => _followedIds.remove(uid));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_suggestedUsers.isEmpty && _suggestedCanaux.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(colors: colors, pageType: widget.pageType),
          const SizedBox(height: 12),
          if (_suggestedUsers.isNotEmpty) ...[
            _SubTitle(label: 'Créateurs', colors: colors),
            const SizedBox(height: 8),
            ..._suggestedUsers.map((u) => _UserCard(
                  user: u,
                  followed: _followedIds.contains(u.id),
                  onFollow: () => _followUser(u),
                  onTap: () => _openUser(u),
                  colors: colors,
                )),
          ],
          if (_suggestedCanaux.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SubTitle(label: 'Canaux', colors: colors),
            const SizedBox(height: 8),
            ..._suggestedCanaux.map((c) => _CanalCard(
                  canal: c,
                  onTap: () => _openCanal(c),
                  colors: colors,
                )),
          ],
        ],
      ),
    );
  }

  void _openUser(UserData user) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    showUserDetailsModalDialog(user, w, h, context);
  }

  void _openCanal(Canal canal) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CanalDetails(canal: canal)),
    );
  }
}

// ── Sous-widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.colors, this.pageType});
  final AppColors colors;
  final String? pageType;

  String _label() {
    if (pageType == null || pageType!.isEmpty) return 'À découvrir · Créateurs & Canaux';
    switch (pageType) {
      case 'SPORT':      return '⚽ Créateurs & Canaux Sport';
      case 'EVENEMENT':  return '🎉 Créateurs & Canaux Événement';
      case 'LOOKS':      return '👗 Créateurs & Canaux Mode';
      case 'ACTUALITES': return '📰 Créateurs & Canaux Actu';
      case 'GAMER':      return '🎮 Créateurs & Canaux Gaming';
      default:           return 'À découvrir · Créateurs & Canaux';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3,
        height: 18,
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        _label(),
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    ]);
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle({required this.label, required this.colors});
  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.followed,
    required this.onFollow,
    required this.onTap,
    required this.colors,
  });

  final UserData user;
  final bool followed;
  final VoidCallback onFollow;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final name = user.pseudo?.isNotEmpty == true
        ? '@${user.pseudo}'
        : '${user.nom ?? ''} ${user.prenom ?? ''}'.trim();
    final followers = user.userAbonnesIds?.length ?? (user.abonnes ?? 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border.withOpacity(0.5)),
        ),
        child: Row(children: [
          _Avatar(imageUrl: user.imageUrl, radius: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              Text('$followers abonné${followers > 1 ? 's' : ''}',
                  style:
                      TextStyle(color: colors.textSecondary, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          _CtaButton(
            label: followed ? 'Suivi ✓' : 'Suivre',
            done: followed,
            onPressed: followed ? null : onFollow,
          ),
        ]),
      ),
    );
  }
}

class _CanalCard extends StatelessWidget {
  const _CanalCard({
    required this.canal,
    required this.onTap,
    required this.colors,
  });

  final Canal canal;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final members = canal.usersSuiviId?.length ?? (canal.suivi ?? 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border.withOpacity(0.5)),
        ),
        child: Row(children: [
          _Avatar(imageUrl: canal.urlImage, radius: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#${canal.titre ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              Text('$members membre${members > 1 ? 's' : ''}',
                  style:
                      TextStyle(color: colors.textSecondary, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          _CtaButton(
            label: 'Voir le canal',
            done: false,
            onPressed: onTap,
          ),
        ]),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.imageUrl, required this.radius});
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF2A2A2A),
      child: url.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _defaultIcon(),
              ),
            )
          : _defaultIcon(),
    );
  }

  Widget _defaultIcon() =>
      Icon(Icons.person_rounded, color: Colors.white54, size: radius);
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.done,
    required this.onPressed,
  });

  final String label;
  final bool done;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: done
              ? Colors.transparent
              : const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: done
                ? Colors.grey.withOpacity(0.4)
                : const Color(0xFFFFD700),
          ),
        ),
        child: Text(
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
