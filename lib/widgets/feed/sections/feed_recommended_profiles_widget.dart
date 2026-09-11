import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/model_data.dart';
import '../../../pages/user/otherUser/otherUser.dart';
import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Section profils créateurs recommandés, triés par creatorScore.
/// Widget autonome — charge ses propres données depuis Firestore.
class FeedRecommendedProfilesWidget extends StatefulWidget {
  const FeedRecommendedProfilesWidget({Key? key}) : super(key: key);

  @override
  State<FeedRecommendedProfilesWidget> createState() =>
      _FeedRecommendedProfilesWidgetState();
}

class _FeedRecommendedProfilesWidgetState
    extends State<FeedRecommendedProfilesWidget> {
  List<UserData> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = context.read<UserAuthProvider>();
      final me = auth.loginUserData;
      final myId = me.id ?? '';
      final following = Set<String>.from(me.followingIds ?? []);

      // Sans orderBy pour éviter de nécessiter un index composite Firestore
      final snap = await FirebaseFirestore.instance
          .collection('Users')
          .where('isCreator', isEqualTo: true)
          .limit(50)
          .get();

      final results = snap.docs
          .map((d) {
            try {
              return UserData.fromJson(d.data())..id = d.id;
            } catch (_) {
              return null;
            }
          })
          .whereType<UserData>()
          .where((u) => u.id != null && u.id != myId && !following.contains(u.id))
          .toList()
          ..sort((a, b) => (b.creatorScore ?? 0).compareTo(a.creatorScore ?? 0));
      final top = results.take(10).toList();

      if (mounted) setState(() { _profiles = top; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _profiles.isEmpty) return const SizedBox.shrink();

    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Créateurs à découvrir',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _profiles.length,
            itemBuilder: (context, index) {
              final user = _profiles[index];
              return _ProfileCard(user: user);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserData user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final imageUrl = user.imageUrl ?? '';
    final name = user.pseudo ?? user.nom ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtherUserPage(otherUser: user),
          ),
        );
      },
      child: Container(
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: colors.surfaceVariant,
              backgroundImage: imageUrl.isNotEmpty
                  ? CachedNetworkImageProvider(imageUrl)
                  : null,
              child: imageUrl.isEmpty
                  ? Icon(Icons.person, color: colors.textSecondary)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
