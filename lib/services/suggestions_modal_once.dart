import 'package:shared_preferences/shared_preferences.dart';

/// Le modal « Découvrez d'autres posts » ne s'affiche qu'UNE SEULE FOIS par compte (sur cet appareil), quelle que soit la page de détail
/// (post, vidéo, vidéo portrait) et quelle que soit la façon de le fermer. On le note dès qu'il s'ouvre.
class SuggestionsModalOnce {
  static const _key = 'suggestions_modal_shown_once_v2';

  static String _k(String? uid) => '${_key}_${uid ?? 'anon'}';

  /// Faut-il l'afficher ? Non si déjà vu (nouvelle clé) ou si l'ancienne clé « J'ai compris » existe.
  static Future<bool> shouldShow(String? uid) async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (sp.getBool(_k(uid)) ?? false) return false;
      if (uid != null && (sp.getBool('has_seen_suggestions_modal_video_$uid') ?? false)) return false;
      return true;
    } catch (_) {
      return false; // en cas de doute, on n'affiche pas
    }
  }

  static Future<void> markShown(String? uid) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_k(uid), true);
    } catch (_) {}
  }
}
