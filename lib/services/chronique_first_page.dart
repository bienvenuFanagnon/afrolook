import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/chronique/chroniqueform.dart';
import 'api/chroniques_mapper.dart';

/// Première page des chroniques : gardée en mémoire ET sur le téléphone.
///  - le fil la lit, la page « Chroniques » la réutilise telle quelle (affichage immédiat, aucune lecture en plus) ;
///  - à la réouverture de l'application, la dernière page enregistrée s'affiche TOUT DE SUITE (chroniques non expirées seulement), pendant qu'une
///    lecture discrète du serveur la rafraîchit ; quand elle arrive, les écrans qui écoutent [changes] se mettent à jour sans clignoter.
class ChroniqueFirstPage {
  ChroniqueFirstPage._();

  /// Au-delà, la page est relue sur le serveur (les chroniques durent 24 h, 2 minutes de retard ne se voient pas).
  static const Duration maxAge = Duration(minutes: 2);

  /// Une page enregistrée plus vieille que cela n'est plus montrée en attendant le serveur.
  static const Duration maxStale = Duration(hours: 12);

  static List<Chronique> _items = const [];
  static Object? _last; // curseur de la page suivante (API) ; tout autre type est ignoré par le fournisseur
  static bool _hasMore = false;
  static DateTime? _at;
  static String? _loadedFor;

  /// Augmente à chaque publication ou suppression : l'accueil et la page « Chroniques » l'écoutent pour relire leur liste
  /// (sans cela, une chronique publiée n'apparaissait qu'au redémarrage de l'application).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void save(List<Chronique> items, Object? last, {required bool hasMore}) {
    _items = List.unmodifiable(items);
    _last = last;
    _hasMore = hasMore;
    _at = DateTime.now();
  }

  /// Page encore fraîche (et chroniques non expirées), sinon null.
  static ({List<Chronique> items, Object? last, bool hasMore})? fresh() {
    final at = _at;
    if (at == null || _items.isEmpty || DateTime.now().difference(at) > maxAge) return null;
    final alive = _items.where((c) => !c.isExpired).toList();
    if (alive.length != _items.length) return null;
    return (items: alive, last: _last, hasMore: _hasMore);
  }

  /// Page gardée, même ancienne (jusqu'à [maxStale]) : montrée tout de suite pendant que le serveur répond. Seules les chroniques non expirées restent.
  static ({List<Chronique> items, Object? last, bool hasMore})? stale() {
    final at = _at;
    if (at == null || _items.isEmpty || DateTime.now().difference(at) > maxStale) return null;
    final alive = _items.where((c) => !c.isExpired).toList();
    if (alive.isEmpty) return null;
    return (items: alive, last: _last, hasMore: _hasMore);
  }

  /// La page vient d'être relue en arrière-plan : les écrans qui écoutent se mettent à jour (sans vider la mémoire).
  static void refreshed() => changes.value++;

  // ── Enregistrement sur le téléphone ─────────────────────────────────────────

  static String _key(String uid) => 'chronicles_first_v1_$uid';

  /// Enregistre la première page brute (réponse de l'API) pour la prochaine ouverture. Sans effet si l'enregistrement échoue.
  static Future<void> persistRaw(String? uid, List<Map<String, dynamic>> raw, String? next) async {
    if (uid == null || uid.isEmpty) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key(uid), jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'next': next, 'items': raw}));
    } catch (_) {/* confort : une écriture ratée n'est pas une erreur */}
  }

  /// Relit la dernière page enregistrée (une seule fois par compte). À appeler dès le lancement ; sans danger si rien n'est enregistré.
  static Future<void> ensureLoaded(String? uid) async {
    if (uid == null || uid.isEmpty || _loadedFor == uid) return;
    _loadedFor = uid;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key(uid));
      if (raw == null || raw.isEmpty) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.fromMillisecondsSinceEpoch((d['t'] as num?)?.toInt() ?? 0);
      if (DateTime.now().difference(at) > maxStale || _items.isNotEmpty) return;   // trop vieux, ou déjà remplacé par une lecture du serveur
      final list = (d['items'] as List? ?? const []).whereType<Map>().map((m) => chroniqueFromApi(Map<String, dynamic>.from(m), myId: uid)).where((c) => !c.isExpired).toList();
      if (list.isEmpty) return;
      _items = List.unmodifiable(list);
      _last = d['next'];
      _hasMore = d['next'] != null;
      _at = at;
    } catch (_) {/* enregistrement illisible : on repart du serveur */}
  }

  /// Pour les tests : repart d'un état vide (mémoire et compte chargé).
  @visibleForTesting
  static void resetForTest() {
    _items = const [];
    _last = null;
    _hasMore = false;
    _at = null;
    _loadedFor = null;
  }

  /// À appeler quand une chronique est publiée ou supprimée.
  static void clear() {
    _items = const [];
    _last = null;
    _at = null;
    changes.value++;
  }
}
