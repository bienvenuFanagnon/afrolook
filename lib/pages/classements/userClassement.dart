import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/services/api/jeux_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
import 'package:afrotok/widgets/pseudo_tag.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_badge_widget.dart';
import '../component/showUserDetails.dart';
import '../pub/native_ad_widget.dart';

/// « Top Afrolook Stars » : les 10 comptes qui ont le plus de points. Les données viennent de l'API (`GET /users/top?by=points`), jamais de Firebase.
///
/// Les points de contribution : inscription 5, parrainer quelqu'un 5, aimer la publication d'un autre 1, s'abonner à un compte 4, inviter un ami 1 (une fois par cible).
/// La popularité est la part des points de toute l'application que détient le compte. Clair et sombre : toutes les couleurs viennent du thème.
class UserClassement extends StatefulWidget {
  const UserClassement({super.key});

  @override
  State<UserClassement> createState() => _UserClassementState();
}

class _UserClassementState extends State<UserClassement> {
  late UserAuthProvider authProvider;
  List<UserData> _top = [];
  Map<String, dynamic>? _mine;   // mes points et ma popularité, pour « Ma place »
  final Map<String, int> _rank = {};   // rang de chaque compte (donné par le serveur)
  final ScrollController _scroll = ScrollController();
  int? _nextOffset;   // début de la page suivante ; null = fin du classement (500 rangs au plus)
  bool _loadingMore = false;
  bool _loading = true;
  String? _error;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _scroll.addListener(() {
      // on charge la suite en approchant du bas de la liste
      if (_scroll.hasClients && _scroll.position.extentAfter < 500) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<({List<UserData> users, int? next})> _fetchPage(int offset) async {
    final res = await JeuxApi.client.get('/users/top', query: {'by': 'points', 'limit': _pageSize, 'offset': offset});
    final rows = JeuxApi.list(res);
    final users = <UserData>[];
    for (var i = 0; i < rows.length; i++) {
      final j = rows[i];
      final u = userSummaryFromApi(j);
      u.totalPoints = JeuxApi.asInt(j['points']);
      _rank['${u.id}'] = JeuxApi.asInt(j['rank']) > 0 ? JeuxApi.asInt(j['rank']) : offset + i + 1;
      users.add(u);
    }
    final next = res is Map ? res['next_offset'] : null;
    return (users: users, next: next is num ? next.toInt() : null);
  }

  /// Page suivante du classement (jusqu'au rang 500).
  Future<void> _loadMore() async {
    final off = _nextOffset;
    if (off == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _fetchPage(off);
      if (!mounted) return;
      setState(() {
        _top.addAll(page.users.where((u) => !_top.any((t) => t.id == u.id)));
        _nextOffset = page.next;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);   // un nouvel essai part au prochain défilement
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _rank.clear();
      final first = await _fetchPage(0);
      Map<String, dynamic>? mine;
      final me = authProvider.loginUserData.id;
      if (me != null && me.isNotEmpty) {
        try {
          mine = await UsersApi.publicProfile(me);
        } catch (_) {}   // « Ma place » est facultative
      }
      if (!mounted) return;
      setState(() {
        _top = first.users;
        _nextOffset = first.next;
        _mine = mine;
        _loading = false;
      });
    } catch (e) {
      printVm('Classement : $e');
      if (mounted) {
        setState(() {
          _error = context.tr('Impossible de charger le classement');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(context.tr('Top Afrolook Stars'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: _loading
          ? _shimmer(c)
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error_outline_rounded, size: 56, color: c.danger),
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: c.textPrimary, fontSize: 15)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: Text(context.tr('Réessayer'))),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                      _intro(c),
                      if (_mine != null) ...[const SizedBox(height: 12), _myPlace(c)],
                      const SizedBox(height: 12),
                      Container(
                        key: const ValueKey('top10_first_ad'),
                        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
                        child: const MrecAdWidget(),
                      ),
                      const SizedBox(height: 12),
                      if (_top.isEmpty) _empty(c) else for (var i = 0; i < _top.length; i++) _row(c, _top[i], _rank['${_top[i].id}'] ?? i + 1),
                      if (_loadingMore) const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4))),
                      if (!_loadingMore && _nextOffset != null) Center(child: TextButton(key: const ValueKey('top_more'), onPressed: _loadMore, child: Text(context.tr('Voir la suite')))),
                      if (_nextOffset == null && _top.length >= _pageSize) Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Center(child: Text(context.tr('Fin du classement'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)))),
                    ],
                  ),
                ),
    );
  }

  Widget _intro(AppColors c) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('Classement par points'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            context.tr('Tu gagnes des points en participant : inscription 5, parrainer quelqu\'un 5, aimer une publication 1, t\'abonner à un compte 4, inviter un ami 1. La popularité est ta part des points de toute l\'application.'),
            style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4),
          ),
        ]),
      );

  Widget _myPlace(AppColors c) {
    final points = (_mine?['points'] as num?)?.toInt() ?? 0;
    final pop = (_mine?['popularity'] as num?)?.toDouble() ?? 0;
    return Container(
      key: const ValueKey('my_place'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.primary.withOpacity(.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: c.primary.withOpacity(.5))),
      child: Row(children: [
        Icon(Icons.person_pin_rounded, color: c.primary, size: 30),
        const SizedBox(width: 12),
        Expanded(child: Text(context.tr('Mes points'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15))),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$points pts', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
          Text('${pop.toStringAsFixed(2)} %', style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _empty(AppColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [
          Icon(Icons.emoji_events_outlined, size: 56, color: c.textSecondary),
          const SizedBox(height: 12),
          Text(context.tr('Aucun point pour le moment'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text(context.tr('Aime des publications, abonne-toi et invite des amis pour gagner des points.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        ]),
      );

  Widget _row(AppColors c, UserData u, int rank) {
    final medal = switch (rank) { 1 => const Color(0xFFFFC400), 2 => const Color(0xFF9AA3AA), 3 => const Color(0xFFCD7F32), _ => null };
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    return GestureDetector(
      key: ValueKey('top_row_$rank'),
      onTap: () => showUserDetailsModalDialog(u, w, h, context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: medal ?? c.border, width: medal != null ? 1.6 : 1)),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: medal ?? c.border.withOpacity(.6)),
            child: medal != null ? const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20) : Text('$rank', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 24,
            backgroundColor: c.border,
            backgroundImage: (u.imageUrl ?? '').isNotEmpty ? NetworkImage(u.imageUrl!) : null,
            child: (u.imageUrl ?? '').isEmpty ? Icon(Icons.person_rounded, color: c.textSecondary) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: PseudoTag(label: '@${u.pseudo ?? ''}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                UserBadgeWidget(user: u, size: 15),
              ]),
              const SizedBox(height: 3),
              Text('${u.followersCount} ${context.tr('abonnés')} · ${(u.popularite ?? 0).toStringAsFixed(2)} %', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(20)),
            child: Text('${u.totalPoints} pts', style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
        ]),
      ),
    );
  }

  Widget _shimmer(AppColors c) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: c.border,
          highlightColor: c.surface,
          child: Container(height: 70, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16))),
        ),
      );
}
