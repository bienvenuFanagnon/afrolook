import 'package:flutter/widgets.dart';

/// Priorité d'un élément intercalé entre les publications (plus petit = passe avant).
enum FeedSlotPriority { ad, paid, engagement, discovery }

class _Offer {
  _Offer(this.priority, this.widget, this.offeredAt);
  final FeedSlotPriority priority;
  final Widget widget;
  final int offeredAt; // numéro de publication au moment de la proposition
}

/// Planificateur unique des éléments intercalés (quiz, contes, étude, défis, actualités, canaux, pubs, musique…).
///
/// Règle du propriétaire (30/10/2026) : les publications dominent. Les 3 premières sont libres, puis AU PLUS UN élément toutes les
/// [postsPerInsert] publications (jamais deux de suite). Les éléments proposés par les anciennes règles attendent leur tour,
/// triés par priorité (pubs, contenus payants, engagement, découverte) ; ceux qui attendent trop longtemps sont abandonnés.
class FeedSlotPlanner {
  FeedSlotPlanner({this.postsPerInsert = 4, this.freeStart = 3, this.maxWait = 12});

  final int postsPerInsert;
  final int freeStart;
  final int maxWait;
  final List<_Offer> _queue = [];
  int _lastSlotAt = 0;

  /// Une ancienne règle propose un élément après la publication n° [postNumber] (1 = première).
  void offer(FeedSlotPriority priority, Widget widget, int postNumber) => _queue.add(_Offer(priority, widget, postNumber));

  /// À appeler après chaque publication ajoutée : renvoie l'élément à intercaler maintenant (ou rien).
  List<Widget> takeAfter(int postNumber) {
    _queue.removeWhere((o) => postNumber - o.offeredAt > maxWait);
    if (_queue.isEmpty || postNumber <= freeStart) return const [];
    final since = postNumber - (_lastSlotAt == 0 ? freeStart : _lastSlotAt);
    if (since < postsPerInsert) return const [];
    _queue.sort((a, b) {
      final p = a.priority.index.compareTo(b.priority.index);
      return p != 0 ? p : a.offeredAt.compareTo(b.offeredAt);
    });
    final picked = _queue.removeAt(0);
    _lastSlotAt = postNumber;
    return [picked.widget];
  }
}
