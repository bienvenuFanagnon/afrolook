import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../pages/canaux/detailsCanal.dart';
import '../../../pages/component/showUserDetails.dart';
import '../../../providers/authProvider.dart';
import '../../../services/feed/end_of_feed_cache.dart';
import '../../../theme/app_colors.dart';

/// Section de fin de feed — créateurs et canaux non encore suivis.
/// Affiche au moins 3 de chaque, avec "Voir plus" pour charger davantage.
/// [pageType] : si fourni (ex: 'SPORT'), filtre par catégorie.
/// [onSubscribed] : appelé dès qu'un abonnement (créateur ou canal) réussit.
class FeedEndDiscoverySection extends StatefulWidget {
  final String? pageType;
  final VoidCallback? onSubscribed;
  const FeedEndDiscoverySection({Key? key, this.pageType, this.onSubscribed}) : super(key: key);

  @override
  State<FeedEndDiscoverySection> createState() =>
      _FeedEndDiscoverySectionState();
}

class _FeedEndDiscoverySectionState extends State<FeedEndDiscoverySection> {
  static const _afroYellow = Color(0xFFFFD700);
  static const int _initialShow = 3;
  static const int _loadMoreCount = 3;

  List<UserData> _allUsers = [];
  List<Canal> _allCanaux = [];
  bool _loading = true;

  int _shownUsers = _initialShow;
  int _shownCanaux = _initialShow;
  bool _loadingMoreUsers = false;
  bool _loadingMoreCanaux = false;

  final Set<String> _followedIds = {};
  final Set<String> _subscribedCanalIds = {};

  @override
  void initState() {
    super.initState();
    _loadFromCacheThenRefresh();
  }

  Future<void> _loadFromCacheThenRefresh() async {
    final cached = await EndOfFeedCache.instance.get();
    if (cached.$1.isNotEmpty || cached.$2.isNotEmpty) {
      if (!mounted) return;
      final auth = Provider.of<UserAuthProvider>(context, listen: false);
      final myId = auth.loginUserData.id ?? '';
      final alreadyFollowing = Set<String>.from(auth.loginUserData.followingIds ?? [])..add(myId);
      final subscribedCanalIds = Set<String>.from(auth.loginUserData.canauxSuivisIds ?? []);
      setState(() {
        _allUsers = cached.$1.where((u) => !alreadyFollowing.contains(u.id)).take(30).toList();
        _allCanaux = cached.$2
            .where((c) => !subscribedCanalIds.contains(c.id))
            .take(30)
            .toList();
        _loading = false;
      });
    }
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final me = auth.loginUserData;
    final myId = me.id ?? '';
    final alreadyFollowing = Set<String>.from(me.followingIds ?? []);
    alreadyFollowing.add(myId);
    final subscribedCanalIds = Set<String>.from(me.canauxSuivisIds ?? []);

    final usersFuture = _fetchUsers(alreadyFollowing).catchError((_) => <UserData>[]);
    final canauxFuture = _fetchCanaux(subscribedCanalIds).catchError((_) => <Canal>[]);
    final results = await Future.wait([usersFuture, canauxFuture]);

    if (!mounted) return;
    final freshUsers = results[0] as List<UserData>;
    final freshCanaux = results[1] as List<Canal>;
    setState(() {
      // Ne pas écraser les données existantes si la requête réseau revient vide
      if (freshUsers.isNotEmpty) _allUsers = freshUsers;
      if (freshCanaux.isNotEmpty) _allCanaux = freshCanaux;
      _loading = false;
    });

    // Mettre à jour le cache avec les données fraîches (les deux listes)
    if (freshUsers.isNotEmpty || freshCanaux.isNotEmpty) {
      EndOfFeedCache.instance.saveFromWidget(
        users: _allUsers,
        canaux: _allCanaux,
      );
    }
  }

  Future<List<UserData>> _fetchUsers(Set<String> exclude) async {
    final pageType = widget.pageType;
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      if (pageType != null && pageType.isNotEmpty) {
        // where + orderBy sur le MÊME champ = index single-field automatique
        snap = await FirebaseFirestore.instance
            .collection('Users')
            .where('mainCategory', isEqualTo: pageType)
            .limit(50)
            .get()
            .timeout(const Duration(seconds: 15));
      } else {
        // orderBy abonnes seul = index single-field automatique, limite haute pour plus de variété
        snap = await FirebaseFirestore.instance
            .collection('Users')
            .orderBy('abonnes', descending: true)
            .limit(50)
            .get()
            .timeout(const Duration(seconds: 15));
      }
    } catch (_) {
      return [];
    }

    final all = snap.docs
        .map((d) {
          try { return UserData.fromJson(d.data())..id = d.id; } catch (_) { return null; }
        })
        .whereType<UserData>()
        .where((u) => u.id != null && !exclude.contains(u.id))
        .toList();

    // Tri par abonnés décroissant, shuffle du top 30 pour variété
    all.sort((a, b) => (b.abonnes ?? 0).compareTo(a.abonnes ?? 0));
    final top = all.take(30).toList();
    top.shuffle(Random());
    return top;
  }

  Future<List<Canal>> _fetchCanaux(Set<String> alreadySubscribed) async {
    final pageType = widget.pageType;
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      if (pageType != null && pageType.isNotEmpty) {
        // where sur mainCategory uniquement (single index), filtre status côté client
        snap = await FirebaseFirestore.instance
            .collection('Canaux')
            .where('mainCategory', isEqualTo: pageType)
            .limit(40)
            .get()
            .timeout(const Duration(seconds: 15));
      } else {
        // orderBy suivi seul = index single-field automatique
        snap = await FirebaseFirestore.instance
            .collection('Canaux')
            .orderBy('suivi', descending: true)
            .limit(40)
            .get()
            .timeout(const Duration(seconds: 15));
      }
    } catch (_) {
      return [];
    }

    final all = snap.docs
        .map((d) {
          try { return Canal.fromJson(d.data())..id = d.id; } catch (_) { return null; }
        })
        .whereType<Canal>()
        .where((c) => c.id != null && !alreadySubscribed.contains(c.id))
        .toList();

    all.sort((a, b) => (b.suivi ?? 0).compareTo(a.suivi ?? 0));
    return all;
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
      // Backfill 50 posts récents du créateur suivi dans unreadPosts du nouvel abonné
      FirebaseFunctions.instance
          .httpsCallable('backfillPostsOnFollow')
          .call({'followedUserId': uid}).ignore();
      widget.onSubscribed?.call();
    } catch (_) {
      if (mounted) setState(() => _followedIds.remove(uid));
    }
  }

  Future<void> _subscribeCanal(Canal canal) async {
    final cid = canal.id;
    if (cid == null) return;
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final myId = auth.loginUserData.id ?? '';
    if (myId.isEmpty) return;

    setState(() => _subscribedCanalIds.add(cid));
    final fs = FirebaseFirestore.instance;
    try {
      await Future.wait([
        fs.collection('Canaux').doc(cid).update({
          'usersSuiviId': FieldValue.arrayUnion([myId]),
          'suivi': FieldValue.increment(1),
        }),
        fs.collection('Users').doc(myId).update({
          'canauxSuivisIds': FieldValue.arrayUnion([cid]),
        }),
      ]);
      // Mettre à jour en mémoire pour que le bouton reflète l'état immédiatement
      auth.loginUserData.canauxSuivisIds ??= [];
      if (!auth.loginUserData.canauxSuivisIds!.contains(cid)) {
        auth.loginUserData.canauxSuivisIds!.add(cid);
      }
      // Backfill posts du canal dans unreadPosts de l'abonné
      FirebaseFunctions.instance
          .httpsCallable('backfillCanalPostsOnFollow')
          .call({'canalId': cid}).ignore();
      widget.onSubscribed?.call();
    } catch (_) {
      if (mounted) setState(() => _subscribedCanalIds.remove(cid));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2)),
      );
    }
    if (_allUsers.isEmpty && _allCanaux.isEmpty) return const SizedBox.shrink();

    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final myFollowingIds = Set<String>.from(auth.loginUserData.followingIds ?? []);
    final mySubscribedCanalIds = Set<String>.from(auth.loginUserData.canauxSuivisIds ?? []);

    final usersToShow = _allUsers.take(_shownUsers).toList();
    final canauxToShow = _allCanaux.take(_shownCanaux).toList();

    // Layout groupé : tous les profils en haut, tous les canaux en dessous
    final List<Widget> items = [];

    if (_allUsers.isNotEmpty) {
      items.add(_SubTitle(label: 'CRÉATEURS', colors: colors));
      items.add(const SizedBox(height: 8));
      for (final u in usersToShow) {
        final alreadyFollowed = _followedIds.contains(u.id) || myFollowingIds.contains(u.id);
        items.add(_UserCard(
          user: u,
          followed: alreadyFollowed,
          onFollow: alreadyFollowed ? () {} : () => _followUser(u),
          onTap: () => _openUser(u),
          colors: colors,
        ));
      }
      if (_shownUsers < _allUsers.length) {
        items.add(_VoirPlusButton(
          loading: _loadingMoreUsers,
          onTap: () => setState(() => _shownUsers = (_shownUsers + _loadMoreCount).clamp(0, _allUsers.length)),
          colors: colors,
        ));
      }
    }

    if (_allCanaux.isNotEmpty) {
      if (_allUsers.isNotEmpty) items.add(const SizedBox(height: 16));
      items.add(_SubTitle(label: 'CANAUX', colors: colors));
      items.add(const SizedBox(height: 8));
      for (final c in canauxToShow) {
        final alreadySubscribed = _subscribedCanalIds.contains(c.id) || mySubscribedCanalIds.contains(c.id);
        final isPrivate = c.isPrivate == true;
        items.add(_CanalCard(
          canal: c,
          subscribed: alreadySubscribed,
          isPrivate: isPrivate,
          onSubscribe: alreadySubscribed
              ? () {}
              : isPrivate
                  ? () => _openCanal(c)
                  : () => _subscribeCanal(c),
          onTap: () => _openCanal(c),
          colors: colors,
        ));
      }
      if (_shownCanaux < _allCanaux.length) {
        items.add(_VoirPlusButton(
          loading: _loadingMoreCanaux,
          onTap: () => setState(() => _shownCanaux = (_shownCanaux + _loadMoreCount).clamp(0, _allCanaux.length)),
          colors: colors,
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(colors: colors, pageType: widget.pageType),
          const SizedBox(height: 12),
          ...items,
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
        width: 3, height: 18,
        decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Text(_label(), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
    ]);
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle({required this.label, required this.colors});
  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5));
  }
}

class _VoirPlusButton extends StatelessWidget {
  const _VoirPlusButton({required this.loading, required this.onTap, required this.colors});
  final bool loading;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: colors.border.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: loading
            ? Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.expand_more, size: 18, color: colors.primary),
                  const SizedBox(width: 6),
                  Text('Voir plus', style: TextStyle(color: colors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user, required this.followed,
    required this.onFollow, required this.onTap, required this.colors,
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
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              if (followers > 0)
                Text('$followers abonné${followers > 1 ? 's' : ''}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          _CtaButton(label: followed ? 'Suivi ✓' : 'Suivre', done: followed, onPressed: followed ? null : onFollow),
        ]),
      ),
    );
  }
}

class _CanalCard extends StatelessWidget {
  const _CanalCard({
    required this.canal, required this.subscribed,
    required this.onSubscribe, required this.onTap, required this.colors,
    this.isPrivate = false,
  });
  final Canal canal;
  final bool subscribed;
  final bool isPrivate;
  final VoidCallback onSubscribe;
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
              Text('#${canal.titre ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              if (members > 0)
                Text('$members membre${members > 1 ? 's' : ''}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          _CtaButton(
            label: subscribed ? 'Rejoint ✓' : isPrivate ? 'Voir' : 'Rejoindre',
            done: subscribed,
            onPressed: subscribed ? null : onSubscribe,
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
                width: radius * 2, height: radius * 2,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _defaultIcon(),
              ),
            )
          : _defaultIcon(),
    );
  }

  Widget _defaultIcon() => Icon(Icons.person_rounded, color: Colors.white54, size: radius);
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.label, required this.done, required this.onPressed});
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
          color: done ? Colors.transparent : const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: done ? Colors.grey.withOpacity(0.4) : const Color(0xFFFFD700)),
        ),
        child: Text(label,
            style: TextStyle(color: done ? Colors.grey : Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}
