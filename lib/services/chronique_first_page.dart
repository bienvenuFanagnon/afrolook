import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../pages/chronique/chroniqueform.dart';

/// Première page des chroniques gardée en mémoire : le fil la lit, la page « Chroniques » la réutilise telle quelle
/// (affichage immédiat, aucune lecture en plus) et ne va chercher que la suite à partir du curseur.
class ChroniqueFirstPage {
  ChroniqueFirstPage._();

  /// Au-delà, la page est relue sur le serveur (les chroniques durent 24 h, 2 minutes de retard ne se voient pas).
  static const Duration maxAge = Duration(minutes: 2);

  static List<Chronique> _items = const [];
  static DocumentSnapshot? _last;
  static bool _hasMore = false;
  static DateTime? _at;

  /// Augmente à chaque publication ou suppression : l'accueil et la page « Chroniques » l'écoutent pour relire leur liste
  /// (sans cela, une chronique publiée n'apparaissait qu'au redémarrage de l'application).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void save(List<Chronique> items, DocumentSnapshot? last, {required bool hasMore}) {
    _items = List.unmodifiable(items);
    _last = last;
    _hasMore = hasMore;
    _at = DateTime.now();
  }

  /// Page encore fraîche (et chroniques non expirées), sinon null.
  static ({List<Chronique> items, DocumentSnapshot? last, bool hasMore})? fresh() {
    final at = _at;
    if (at == null || _items.isEmpty || DateTime.now().difference(at) > maxAge) return null;
    final alive = _items.where((c) => !c.isExpired).toList();
    if (alive.length != _items.length) return null;
    return (items: alive, last: _last, hasMore: _hasMore);
  }

  /// À appeler quand une chronique est publiée ou supprimée.
  static void clear() {
    _items = const [];
    _last = null;
    _at = null;
    changes.value++;
  }
}
