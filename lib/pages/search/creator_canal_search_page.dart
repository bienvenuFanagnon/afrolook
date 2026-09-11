import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../pages/canaux/detailsCanal.dart';
import '../../pages/user/otherUser/otherUser.dart';
import '../../providers/authProvider.dart';
import '../../services/feed/end_of_feed_cache.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_badge_widget.dart';

/// Overlay de recherche rapide — créateurs & canaux.
/// Affiché depuis l'icône search du header.
class CreatorCanalSearchPage extends StatefulWidget {
  const CreatorCanalSearchPage({Key? key}) : super(key: key);

  @override
  State<CreatorCanalSearchPage> createState() => _CreatorCanalSearchPageState();
}

class _CreatorCanalSearchPageState extends State<CreatorCanalSearchPage> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;

  // Résultats
  List<UserData> _topCreators = [];
  List<Canal> _topCanaux = [];
  List<UserData> _searchCreators = [];
  List<Canal> _searchCanaux = [];

  bool _loadingDefault = true;
  bool _searching = false;
  String _query = '';

  // Follow optimiste local
  final Set<String> _followedIds = {};
  // Subscribe optimiste local
  final Set<String> _subscribedIds = {};

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Chargement des tops par défaut ──────────────────────────────────────

  Future<void> _loadDefaults() async {
    final cached = await EndOfFeedCache.instance.get();
    if (mounted) {
      setState(() {
        _topCreators = cached.$1.take(3).toList();
        _topCanaux = cached.$2
            .where((c) => ((c.suivi ?? 0) + (c.usersSuiviId?.length ?? 0)) > 0)
            .take(3)
            .toList();
        _loadingDefault = false;
      });
    }

    if (_topCreators.isEmpty || _topCanaux.isEmpty) {
      _fetchDefaultsFromFirestore();
    }
  }

  Future<void> _fetchDefaultsFromFirestore() async {
    try {
      // Pas de filtre status — tous les créateurs triés par score
      final cSnap = await FirebaseFirestore.instance
          .collection('Users')
          .limit(30)
          .get();
      final creators = cSnap.docs
          .map((d) { try { return UserData.fromJson(d.data())..id = d.id; } catch (_) { return null; } })
          .whereType<UserData>()
          .where((u) => u.pseudo?.isNotEmpty == true)
          .toList()
        ..sort((a, b) => (b.creatorScore ?? 0).compareTo(a.creatorScore ?? 0));

      final kSnap = await FirebaseFirestore.instance
          .collection('Canaux')
          .limit(20)
          .get();
      final canaux = kSnap.docs
          .map((d) { try { return Canal.fromJson(d.data())..id = d.id; } catch (_) { return null; } })
          .whereType<Canal>()
          // Exclure les canaux sans membres
          .where((c) => ((c.suivi ?? 0) + (c.usersSuiviId?.length ?? 0)) > 0)
          .toList()
        ..sort((a, b) => (b.canalScore ?? 0).compareTo(a.canalScore ?? 0));

      if (!mounted) return;
      setState(() {
        _topCreators = creators.take(3).toList();
        _topCanaux = canaux.take(3).toList();
        _loadingDefault = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDefault = false);
    }
  }

  // ── Recherche Firestore avec debounce ───────────────────────────────────

  void _onChanged(String value) {
    _query = value.trim();
    _debounce?.cancel();
    if (_query.isEmpty) {
      setState(() { _searching = false; _searchCreators = []; _searchCanaux = []; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 800), _search);
  }

  Future<void> _search() async {
    final q = _query;
    if (q.isEmpty) return;

    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('Users')
          .where('pseudo', isGreaterThanOrEqualTo: q)
          .where('pseudo', isLessThan: '${q}z')
          .limit(8)
          .get();
      final users = userSnap.docs
          .map((d) { try { return UserData.fromJson(d.data())..id = d.id; } catch (_) { return null; } })
          .whereType<UserData>()
          .toList();

      final canalSnap = await FirebaseFirestore.instance
          .collection('Canaux')
          .where('titre', isGreaterThanOrEqualTo: q)
          .where('titre', isLessThan: '${q}z')
          .limit(6)
          .get();
      final canaux = canalSnap.docs
          .map((d) { try { return Canal.fromJson(d.data())..id = d.id; } catch (_) { return null; } })
          .whereType<Canal>()
          .toList();

      if (!mounted || _query != q) return;
      setState(() {
        _searching = false;
        _searchCreators = users;
        _searchCanaux = canaux;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _followUser(UserData user) async {
    final uid = user.id;
    if (uid == null) return;
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final myId = auth.loginUserData.id ?? '';
    if (myId.isEmpty) return;
    setState(() => _followedIds.add(uid));
    try {
      await Future.wait([
        FirebaseFirestore.instance.collection('Users').doc(uid).update({
          'userAbonnesIds': FieldValue.arrayUnion([myId]),
          'abonnes': FieldValue.increment(1),
        }),
        FirebaseFirestore.instance.collection('Users').doc(myId).update({
          'followingIds': FieldValue.arrayUnion([uid]),
        }),
      ]);
      auth.loginUserData.followingIds ??= [];
      if (!auth.loginUserData.followingIds!.contains(uid)) {
        auth.loginUserData.followingIds!.add(uid);
      }
      await EndOfFeedCache.instance.invalidate();
    } catch (_) {
      if (mounted) setState(() => _followedIds.remove(uid));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _onChanged,
          style: TextStyle(color: colors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Rechercher créateurs ou canaux…',
            hintStyle: TextStyle(color: colors.textSecondary),
            border: InputBorder.none,
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: colors.textSecondary, size: 18),
                    onPressed: () {
                      _ctrl.clear();
                      _onChanged('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    final showSearch = _query.isNotEmpty;
    final creators = showSearch ? _searchCreators : _topCreators;
    final canaux = showSearch ? _searchCanaux : _topCanaux;
    final labelPrefix = showSearch ? 'Résultats' : 'Top 3';

    if (creators.isEmpty && canaux.isEmpty) {
      return Center(
        child: Text(
          showSearch ? 'Aucun résultat pour "$_query"' : 'Aucune suggestion disponible',
          style: TextStyle(color: colors.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (creators.isNotEmpty) ...[
          _SectionLabel(label: '$labelPrefix Créateurs', colors: colors),
          const SizedBox(height: 8),
          ...creators.map((u) => _CreatorTile(
                user: u,
                followed: _followedIds.contains(u.id) ||
                    (Provider.of<UserAuthProvider>(context, listen: false)
                            .loginUserData
                            .followingIds
                            ?.contains(u.id) ??
                        false),
                onFollow: () => _followUser(u),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OtherUserPage(otherUser: u)),
                ),
                colors: colors,
              )),
          const SizedBox(height: 16),
        ],
        if (canaux.isNotEmpty) ...[
          _SectionLabel(label: '$labelPrefix Canaux', colors: colors),
          const SizedBox(height: 8),
          ...canaux.map((c) => _CanalTile(
                canal: c,
                subscribed: _subscribedIds.contains(c.id),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CanalDetails(canal: c)),
                ),
                colors: colors,
              )),
        ],
      ],
    );
  }
}

// ── Sous-widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.colors});
  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 16, color: const Color(0xFFFFD700)),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14)),
    ]);
  }
}

class _CreatorTile extends StatelessWidget {
  const _CreatorTile({
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
    final name = user.pseudo?.isNotEmpty == true ? '@${user.pseudo}' : '${user.nom ?? ''} ${user.prenom ?? ''}'.trim();
    final followers = user.abonnes ?? user.userAbonnesIds?.length ?? 0;
    final score = user.creatorScore ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border.withOpacity(0.4)),
        ),
        child: Row(children: [
          _Avatar(imageUrl: user.imageUrl, radius: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                const SizedBox(width: 4),
                UserBadgeWidget(user: user, size: 14),
              ]),
              Text('$followers abonné${followers > 1 ? 's' : ''} · score ${score.toStringAsFixed(0)}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          _PillButton(
            label: followed ? 'Suivi ✓' : 'Suivre',
            done: followed,
            onPressed: followed ? null : onFollow,
          ),
        ]),
      ),
    );
  }
}

class _CanalTile extends StatelessWidget {
  const _CanalTile({
    required this.canal,
    required this.subscribed,
    required this.onTap,
    required this.colors,
  });
  final Canal canal;
  final bool subscribed;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final members = canal.suivi ?? canal.usersSuiviId?.length ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border.withOpacity(0.4)),
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
                  style: TextStyle(color: colors.textSecondary, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          _PillButton(
            label: 'Voir',
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
                errorWidget: (_, __, ___) => Icon(Icons.person_rounded, color: Colors.white54, size: radius),
              ),
            )
          : Icon(Icons.person_rounded, color: Colors.white54, size: radius),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.done, required this.onPressed});
  final String label;
  final bool done;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: done ? Colors.transparent : const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: done ? Colors.grey.withOpacity(0.4) : const Color(0xFFFFD700),
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
