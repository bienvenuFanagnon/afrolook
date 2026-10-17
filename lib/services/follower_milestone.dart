// Paliers d'abonnés (100, 500, 1 000, 5 000, 10 000…) : la carte « Merci pour vos abonnés » reprend le dernier palier franchi,
// et l'application propose de la créer une fois par palier.

import 'package:shared_preferences/shared_preferences.dart';

class FollowerMilestone {
  FollowerMilestone._();

  static const List<int> steps = [
    100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000, 250000, 500000, 1000000, 5000000, 10000000,
  ];

  /// Dernier palier franchi avec [followers] abonnés ; null avant 100.
  static int? reached(int followers) {
    int? out;
    for (final s in steps) {
      if (followers >= s) out = s;
    }
    return out;
  }

  /// « 10 000 » (espace insécable fine), « 1 000 000 ».
  static String format(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String _key(String uid) => 'follower_milestone_$uid';

  /// Palier à proposer maintenant (franchi et pas encore proposé), sinon null. L'appel le marque comme proposé.
  static Future<int?> claim(String uid, int followers) async {
    final m = reached(followers);
    if (m == null) return null;
    try {
      final sp = await SharedPreferences.getInstance();
      final seen = sp.getInt(_key(uid)) ?? 0;
      if (m <= seen) return null;
      await sp.setInt(_key(uid), m);
      return m;
    } catch (_) {
      return null;
    }
  }
}
