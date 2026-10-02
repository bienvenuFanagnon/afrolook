import 'package:flutter/material.dart';

import '../../models/model_data.dart';
import '../pseudo_tag.dart';
import '../user_badge_widget.dart';

/// Titre d'un utilisateur dans une liste de partage : badge (vérifié, Premium, Gold, officiel) devant le pseudo.
class ShareUserTitle extends StatelessWidget {
  final UserData? user;
  final TextStyle style;
  const ShareUserTitle({super.key, required this.user, required this.style});

  @override
  Widget build(BuildContext context) {
    final pseudo = user?.pseudo ?? '...';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (user != null) ...[
          UserBadgeWidget(user: user, size: 15),
          const SizedBox(width: 5),
        ],
        Flexible(child: PseudoTag(label: '@$pseudo', style: style)),
      ],
    );
  }
}

/// Titre d'un groupe dans une liste de partage : badge devant le nom
/// (officiel ✔ bleu, gelé, privé 🔒).
class ShareGroupTitle extends StatelessWidget {
  final Map<String, dynamic> group;
  final TextStyle style;
  const ShareGroupTitle({super.key, required this.group, required this.style});

  @override
  Widget build(BuildContext context) {
    final name = group['name'] as String? ?? 'Groupe';
    final official = group['is_official'] == true;
    final frozen = group['is_frozen'] == true;
    final private = group['is_private'] == true || group['isPrivate'] == true;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (official) ...[
          const Icon(Icons.verified_rounded, color: Colors.blue, size: 15),
          const SizedBox(width: 5),
        ],
        if (private) ...[
          Icon(Icons.lock_rounded, color: style.color?.withOpacity(.7), size: 13),
          const SizedBox(width: 4),
        ],
        if (frozen) ...[
          const Icon(Icons.ac_unit_rounded, color: Colors.orange, size: 13),
          const SizedBox(width: 4),
        ],
        Flexible(child: Text(name, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
