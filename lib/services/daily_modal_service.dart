// lib/services/daily_modal_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class DailyModalService {
  static const String _keyPrefix = 'daily_modal_';
  static const String _dateFormat = 'yyyy-MM-dd';

  /// Vérifie si le modal identifié par [modalKey] a déjà été affiché aujourd'hui.
  static Future<bool> isModalShownToday(String modalKey) async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString('$_keyPrefix$modalKey');
    final today = _todayString();
    return lastShown == today;
  }

  /// Marque le modal comme affiché aujourd'hui.
  static Future<void> markModalShownToday(String modalKey) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    await prefs.setString('$_keyPrefix$modalKey', today);
  }

  /// Retourne la clé du modal à afficher aujourd'hui, ou null si tous les modals
  /// ont déjà été affichés aujourd'hui.
  static Future<String?> getModalToShowToday(List<String> modalKeys) async {
    // Récupérer la liste des modals non encore affichés aujourd'hui
    final notShown = <String>[];
    for (final key in modalKeys) {
      if (!await isModalShownToday(key)) {
        notShown.add(key);
      }
    }
    if (notShown.isEmpty) return null;
    // Choisir un modal au hasard parmi ceux non affichés
    notShown.shuffle();
    return notShown.first;
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}