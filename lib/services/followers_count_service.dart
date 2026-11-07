import 'package:afrotok/services/api/users_api.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';

/// Source unique du nombre d'abonnés d'un utilisateur, partagée par tous les feeds
/// et toutes les pages de détails (image, vidéo portrait/paysage, audio) : même
/// document Firestore, même calcul, même cache → le même chiffre partout.
class FollowersCountService {
  FollowersCountService._();
  static final FollowersCountService instance = FollowersCountService._();

  static const _ttl = Duration(minutes: 3);
  final Map<String, ({int count, DateTime at})> _cache = {};
  final Map<String, Future<int?>> _inflight = {};

  int? cached(String userId) => _cache[userId]?.count;

  Future<int?> fresh(String userId) {
    final hit = _cache[userId];
    if (hit != null && DateTime.now().difference(hit.at) < _ttl) return Future.value(hit.count);
    return _inflight[userId] ??= _fetch(userId).whenComplete(() => _inflight.remove(userId));
  }

  /// À appeler après un abonnement / désabonnement pour forcer la relecture.
  void invalidate(String userId) => _cache.remove(userId);

  Future<int?> _fetch(String userId) async {
    try {
      final data = await UsersApi.publicProfile(userId);
      final count = (data['followers_count'] as num?)?.toInt();
      if (count == null) return null;
      _cache[userId] = (count: count, at: DateTime.now());
      return count;
    } catch (_) {
      return null;
    }
  }
}

/// Affiche le nombre d'abonnés à jour ; en attendant, la valeur locale ([fallback]).
class FollowersCountBuilder extends StatefulWidget {
  final String? userId;
  final int fallback;
  final Widget Function(BuildContext context, int count) builder;

  /// Vrai : tant que le vrai nombre n'est pas connu et que la valeur locale est vide (0), rien n'est affiché (au lieu d'un faux « 0 »).
  final bool hideUntilKnown;

  const FollowersCountBuilder({super.key, required this.userId, required this.fallback, required this.builder, this.hideUntilKnown = false});

  @override
  State<FollowersCountBuilder> createState() => _FollowersCountBuilderState();
}

class _FollowersCountBuilderState extends State<FollowersCountBuilder> {
  int? _count;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant FollowersCountBuilder old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) {
      _count = null;
      _refresh();
    }
  }

  void _refresh() {
    final id = widget.userId;
    if (id == null || id.isEmpty) return;
    _count = FollowersCountService.instance.cached(id);
    FollowersCountService.instance.fresh(id).then((v) {
      if (mounted && v != null && v != _count) setState(() => _count = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hideUntilKnown && _count == null && widget.fallback <= 0) return const SizedBox(height: 16);
    return widget.builder(context, _count ?? widget.fallback);
  }
}
