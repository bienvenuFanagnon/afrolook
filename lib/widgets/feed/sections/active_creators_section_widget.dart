import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../services/active_creators_service.dart';
import '../../../pages/user/active_creators_list_page.dart';
import '../../../pages/user/creator_unseen_posts_page.dart';
import 'feed_profiles_section.dart';

/// Section "Créateurs actifs" réutilisable dans n'importe quel feed.
/// Encapsule tout le chargement via ActiveCreatorsService.
class ActiveCreatorsSectionWidget extends StatefulWidget {
  const ActiveCreatorsSectionWidget({Key? key}) : super(key: key);

  @override
  State<ActiveCreatorsSectionWidget> createState() => _ActiveCreatorsSectionWidgetState();
}

class _ActiveCreatorsSectionWidgetState extends State<ActiveCreatorsSectionWidget> {
  final _service = ActiveCreatorsService();

  List<ActiveCreator> _activeCreators = [];
  List<UserData> _users = [];
  Map<String, int> _unseenCounts = {};
  Map<String, int> _creatorLastActivityUs = {};
  List<ActiveCanal> _recentCanaux = [];
  List<String> _followedCanalIds = [];
  List<String> _followingIds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final me = auth.loginUserData;
    final userId = me.id ?? '';
    if (userId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // 1. Following IDs
      List<String> followingIds = me.followingIds ?? [];
      final results = await Future.wait([
        _service.fetchFollowedCanalIds(userId),
        if (followingIds.isEmpty) _service.fetchFollowingIds(userId) else Future.value(<String>[]),
      ]);
      final canalIds = results[0];
      final migratedIds = results[1];
      if (followingIds.isEmpty && migratedIds.isNotEmpty) followingIds = migratedIds;

      _followedCanalIds = canalIds;
      _followingIds = followingIds;

      // 2. Canaux récents
      var canaux = await _service.fetchFollowedRecentCanaux(canalIds, limit: 5);
      if (canaux.isEmpty && canalIds.isNotEmpty) {
        canaux = await _service.fetchFollowedCanauxDirect(canalIds, limit: 5);
      }

      // 3. Compteurs non vus frais
      Map<String, int> freshCounts = {};
      try {
        final doc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
        final raw = doc.data()?['newPostsByCreator'] as Map<String, dynamic>? ?? {};
        freshCounts = Map<String, int>.fromEntries(
          raw.entries
              .where((e) => (e.value as num? ?? 0).toInt() > 0)
              .map((e) => MapEntry(e.key, (e.value as num).toInt())),
        );
      } catch (_) {}

      // 4. Résolution créateurs actifs
      final creators = await _service.resolve(
        me,
        limit: 20,
        followingIds: followingIds.isNotEmpty ? followingIds : null,
        freshCounts: freshCounts.isNotEmpty ? freshCounts : null,
      );

      final hasUnseen = creators.any((c) => c.unseenCount > 0);
      final ordered = hasUnseen ? creators : (List.of(creators)..shuffle());

      if (!mounted) return;
      setState(() {
        _activeCreators = ordered;
        _users = ordered.map((c) => c.user).toList();
        _unseenCounts = {
          for (final c in ordered)
            if (c.unseenCount > 0 && c.user.id != null) c.user.id!: c.unseenCount,
        };
        _creatorLastActivityUs = {
          for (final c in ordered) if (c.user.id != null) c.user.id!: c.lastActivityUs,
        };
        _recentCanaux = canaux;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final me = auth.loginUserData;

    final hasUnseen = _unseenCounts.isNotEmpty;
    final hasFollowings = _followingIds.isNotEmpty || (me.followingIds?.isNotEmpty ?? false);
    final hasCanaux = _recentCanaux.isNotEmpty;

    final String title;
    if (hasUnseen) {
      title = 'Vos Créateurs actifs';
    } else if (hasFollowings || _users.isNotEmpty) {
      title = hasCanaux && _users.isEmpty ? 'Vos Canaux suivis' : 'Créateurs & Canaux';
    } else if (hasCanaux) {
      title = 'Vos Canaux suivis';
    } else {
      title = 'Créateurs à découvrir';
    }

    return FeedProfilesSection(
      users: _users,
      isLoading: _loading,
      title: title,
      unseenCounts: _unseenCounts,
      recentCanaux: _recentCanaux,
      creatorLastActivityUs: _creatorLastActivityUs,
      roundCards: true,
      onShowProfile: (user) {},
      onSeeAllOverride: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveCreatorsListPage(
              abonnesIds: _followingIds.isNotEmpty
                  ? _followingIds
                  : (me.followingIds ?? me.userAbonnesIds ?? []),
              viewedPostIds: me.viewedPostIds ?? [],
              currentUserId: me.id ?? '',
              unseenCounts: _unseenCounts,
              followedCanalIds: _followedCanalIds,
              recentCanaux: _recentCanaux,
              preloadedCreators: _activeCreators,
            ),
          ),
        );
      },
      onTapCard: (user) {
        final unseen = _unseenCounts[user.id] ?? 0;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatorUnseenPostsPage(
              creator: user,
              unseenCount: unseen,
              viewedPostIds: me.viewedPostIds ?? [],
              currentUserId: me.id ?? '',
            ),
          ),
        ).then((_) {
          if (mounted && user.id != null) {
            setState(() {
              _unseenCounts.remove(user.id);
              _activeCreators = _activeCreators
                  .map((c) => c.user.id == user.id
                      ? ActiveCreator(user: c.user, unseenCount: 0, lastActivityUs: c.lastActivityUs)
                      : c)
                  .toList();
            });
          }
        });
      },
    );
  }
}
