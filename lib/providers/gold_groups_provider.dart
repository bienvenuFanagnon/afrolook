import 'dart:math';
import 'package:afrotok/services/api/chat_api.dart';
import 'package:afrotok/services/api/chat_mapper.dart';
import 'package:flutter/foundation.dart';

/// Groupes mis en avant (officiels + groupes de comptes Gold), lus depuis l'API.
/// Lus sur GET /groups/discover?featured=1 (groupes officiels et Gold, publics et non gelés, que la personne en soit membre ou non).
/// Plus d'écoute temps réel (rafraîchissement à l'ouverture).
class GoldGroupsProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<Map<String, dynamic>> get groups => _groups;
  bool get loading => _loading;
  bool get isLoaded => _loaded;

  /// Message d'erreur en français (null si tout va bien) : l'écran peut proposer « Réessayer » ([load] avec force).
  String? get error => _error;

  /// Conservé pour compatibilité : le premier chargement suffit désormais.
  void startStream() {
    if (!_loaded && !_loading) load();
  }

  /// Charge les groupes mis en avant. [force] ignore le cache et relit l'API.
  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (!force && _loaded) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Groupes à découvrir : officiels et groupes de comptes Gold (publics, non gelés), choisis par le serveur. Aucun repli.
      final rows = await ChatApi.discoverGroups(featured: true, limit: 40);
      final out = rows.where((g) => g['is_frozen'] != true).map(groupToLegacy).toList();
      out.shuffle(Random());
      _groups = out;
    } catch (e) {
      _error = ChatApi.message(e);
      debugPrint('GoldGroupsProvider.load : $e');
    }
    _loaded = true;
    _loading = false;
    notifyListeners();
  }
}
