import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/model_data.dart';
import '../providers/authProvider.dart';
import '../providers/profilLikeProvider.dart';
import '../theme/app_colors.dart';
import '../utils/count_format.dart';

/// « ❤ 12 Likes profil » + bouton Like / Aimé, identique à celui du modal de profil.
/// Le bouton est masqué sur son propre profil.
class ProfileLikeSection extends StatefulWidget {
  final UserData user;
  const ProfileLikeSection({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileLikeSection> createState() => _ProfileLikeSectionState();
}

class _ProfileLikeSectionState extends State<ProfileLikeSection> {
  bool? _hasLiked;
  bool _busy = false;

  String get _userId => widget.user.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadLiked();
  }

  Future<void> _loadLiked() async {
    final me = Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;
    if (_userId.isEmpty || me == null || me == _userId) return;
    try {
      final liked = await Provider.of<ProfileLikeProvider>(context, listen: false).hasLikedProfile(_userId, me);
      if (mounted) setState(() => _hasLiked = liked);
    } catch (_) {}
  }

  Future<void> _toggle() async {
    if (_busy || _hasLiked == null) return;
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final provider = Provider.of<ProfileLikeProvider>(context, listen: false);
    final me = auth.loginUserData.id!;
    setState(() => _busy = true);
    try {
      if (_hasLiked == true) {
        await provider.unlikeProfile(_userId, me);
        if (mounted) setState(() => _hasLiked = false);
      } else {
        await provider.likeProfile(_userId, me);
        if (mounted) setState(() => _hasLiked = true);
        final target = widget.user.oneIgnalUserid;
        if (target != null && target.isNotEmpty) {
          unawaited(auth.sendNotification(
            appName: '@${auth.loginUserData.pseudo!}',
            userIds: [target],
            smallImage: auth.loginUserData.imageUrl ?? '',
            send_user_id: me,
            recever_user_id: _userId,
            message: '❤️ a aimé votre profil !',
            type_notif: 'PROFILE_LIKE',
            post_id: '',
            post_type: '',
            chat_id: '',
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.profileLikeError),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final me = Provider.of<UserAuthProvider>(context).loginUserData.id;
    final isOwn = me == _userId;
    final liked = _hasLiked == true;

    return StreamBuilder<int>(
      stream: Provider.of<ProfileLikeProvider>(context, listen: false).getProfileLikesStream(_userId),
      builder: (context, snap) {
        final count = snap.data ?? widget.user.userlikes ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(formatCompactCount(count),
                  style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(l10n.profileLikes,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textSecondary, fontSize: 14)),
              ),
              if (!isOwn) ...[
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: liked ? Colors.red : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: liked ? Colors.red : colors.textSecondary, width: 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_busy)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: liked ? Colors.white : Colors.red, strokeWidth: 2),
                        )
                      else
                        Icon(liked ? Icons.favorite : Icons.favorite_border,
                            color: liked ? Colors.white : colors.textSecondary, size: 16),
                      const SizedBox(width: 6),
                      Text(_busy ? l10n.profilePleaseWait : (liked ? l10n.profileLiked : l10n.profileLike),
                          style: TextStyle(
                              color: liked ? Colors.white : colors.textSecondary, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
