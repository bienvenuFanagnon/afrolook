import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/ad_slot.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../../services/chronique_first_page.dart';
import '../../theme/app_colors.dart';
import '../pub/afrolook_inline_ad.dart';
import 'chronique_filters.dart';
import 'chronique_widgets.dart';
import 'chroniquedetails.dart';
import 'chroniqueform.dart';
import 'mychroniquepage.dart';

/// Liste des chroniques : anneaux, filtres, cartes sur deux colonnes, une pub toutes les 6 personnes.
/// Chargement par lots de 10, le curseur de la page suivante vient de la lecture elle-même (pas de lecture supplémentaire).
class ChroniqueHomePage extends StatefulWidget {
  final String? initialChroniqueId; // Pour la navigation depuis notification

  const ChroniqueHomePage({Key? key, this.initialChroniqueId}) : super(key: key);

  @override
  State<ChroniqueHomePage> createState() => _ChroniqueHomePageState();
}

class _ChroniqueHomePageState extends State<ChroniqueHomePage> with SingleTickerProviderStateMixin {
  static const int _batch = 10;
  static const int _perBlock = 6;

  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

  final Map<String, List<Chronique>> _groups = {};
  DocumentSnapshot? _last;
  bool _loading = false;
  bool _firstLoad = true;
  bool _hasMore = true;
  bool _error = false;
  ChroniqueFilter _filter = ChroniqueFilter.forYou;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    final warm = ChroniqueFirstPage.fresh();
    if (warm != null) {
      // Première page déjà lue par le fil : affichée tout de suite, sans lecture ; on ne va chercher que la suite
      for (final c in warm.items) {
        _groups.putIfAbsent(c.userId, () => []).add(c);
      }
      _last = warm.last;
      _hasMore = warm.hasMore;
      _firstLoad = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) precacheChroniqueImages(context, warm.items);
      });
      if (_hasMore) WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
      final id = widget.initialChroniqueId;
      if (id != null && id.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _openFromNotification(id));
    } else {
      _loadMore(reset: true);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _spin.dispose();
    super.dispose();
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading || (!_hasMore && !reset)) return;
    setState(() {
      _loading = true;
      _error = false;
      if (reset) {
        _groups.clear();
        _last = null;
        _hasMore = true;
      }
    });
    try {
      final page = await context.read<ChroniqueProvider>().getChroniquesPage(limit: _batch, after: _last);
      if (!mounted) return;
      setState(() {
        for (final c in page.items) {
          final g = _groups.putIfAbsent(c.userId, () => []);
          if (!g.any((x) => x.id == c.id)) g.add(c);
        }
        _last = page.last ?? _last;
        _hasMore = page.hasMore;
        _loading = false;
        _firstLoad = false;
      });
      if (reset && widget.initialChroniqueId != null && widget.initialChroniqueId!.isNotEmpty) {
        unawaited(_openFromNotification(widget.initialChroniqueId!));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _firstLoad = false;
          _error = true;
        });
      }
    }
  }

  Future<void> _openFromNotification(String id) async {
    for (final g in _groups.values) {
      if (g.any((c) => c.id == id)) {
        _open(g.firstWhere((c) => c.id == id), g);
        return;
      }
    }
    final c = await context.read<ChroniqueProvider>().getChroniqueById(id);
    if (c != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChroniqueDetailPage(initialChroniqueId: id)));
    }
  }

  void _open(Chronique start, List<Chronique> group, [List<List<Chronique>>? all]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChroniqueDetailPage(initialChroniqueId: start.id!, allGroups: all ?? _groups.values.toList(), startUserId: group.first.userId),
      ),
    );
  }

  void _create([ChroniqueType? type]) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddChroniquePage(initialType: type))).then((published) {
      if (published == true) _loadMore(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final auth = context.watch<UserAuthProvider>();
    final uid = auth.loginUserData.id;
    final followed = {...?auth.loginUserData.followingIds, ...?auth.loginUserData.friendsIds};
    final all = _groups.values.toList();
    final shown = applyChroniqueFilter(all, _filter, followedIds: followed, query: _search.text);
    final mine = all.where((g) => g.isNotEmpty && g.first.userId == uid).toList();
    final others = applyChroniqueFilter(all, ChroniqueFilter.forYou).where((g) => g.first.userId != uid).toList()
      ..sort((a, b) {
        final sa = chroniqueGroupSeen(a, uid) ? 1 : 0;
        final sb = chroniqueGroupSeen(b, uid) ? 1 : 0;
        return sa != sb ? sa - sb : b.first.createdAt.compareTo(a.first.createdAt);
      });
    final ordered = [...mine, ...others];
    final newCount = others.where((g) => !chroniqueGroupSeen(g, uid)).length;
    final reduce = MediaQuery.of(context).disableAnimations;

    // Peu de résultats après un filtre alors qu'il en reste à charger : on en charge d'autres
    if (!_firstLoad && !_loading && _hasMore && shown.length < _perBlock && _filter != ChroniqueFilter.forYou) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMore();
      });
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.primary,
          onRefresh: () => _loadMore(reset: true),
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(colors, others.length, newCount)),
              if (_searching) SliverToBoxAdapter(child: _searchField(colors)),
              if (_firstLoad)
                const SliverToBoxAdapter(child: ChroniqueRingsSkeleton())
              else
                SliverToBoxAdapter(child: _rings(mine, others, ordered, uid, reduce, colors)),
              SliverToBoxAdapter(child: _chips(colors)),
              if (_firstLoad)
                SliverToBoxAdapter(child: _skeletonGrid(colors))
              else if (all.isEmpty)
                SliverToBoxAdapter(child: _empty(colors, error: _error))
              else if (shown.isEmpty)
                SliverToBoxAdapter(child: _noResult(colors))
              else
                SliverList.builder(
                  itemCount: (shown.length / _perBlock).ceil(),
                  itemBuilder: (_, i) => _block(shown, i, ordered, uid, colors),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: _loading && !_firstLoad
                        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: colors.primary))
                        : (!_hasMore && all.isNotEmpty ? Text('Vous avez tout vu', style: TextStyle(color: colors.textSecondary, fontSize: 12)) : const SizedBox.shrink()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppColors colors, int count, int newCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 8),
      child: Row(children: [
        IconButton(onPressed: () => Navigator.maybePop(context), icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Chroniques', style: TextStyle(color: colors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, height: 1.05)),
            if (!_firstLoad)
              Text(
                count == 0 ? 'Rien d\'actif pour le moment' : '$count active${count > 1 ? 's' : ''}${newCount > 0 ? ' · $newCount nouvelle${newCount > 1 ? 's' : ''} pour toi' : ''}',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
          ]),
        ),
        _roundBtn(colors, _searching ? Icons.close_rounded : Icons.search_rounded, 'Rechercher', () {
          setState(() {
            _searching = !_searching;
            if (!_searching) _search.clear();
          });
        }),
        const SizedBox(width: 6),
        _roundBtn(colors, Icons.person_rounded, 'Mes chroniques', () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyChroniquesPage()))),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _create,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), gradient: const LinearGradient(colors: [kRingGreen, kRingLime, kRingYellow])),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 17, color: Color(0xFF07120B)),
              SizedBox(width: 4),
              Text('Créer', style: TextStyle(color: Color(0xFF07120B), fontWeight: FontWeight.w800, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _roundBtn(AppColors colors, IconData icon, String tip, VoidCallback onTap) => Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceVariant, shape: BoxShape.circle), child: Icon(icon, size: 18, color: colors.textPrimary)),
        ),
      );

  Widget _searchField(AppColors colors) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: TextField(
          controller: _search,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Chercher un pseudo',
            hintStyle: TextStyle(color: colors.textSecondary),
            prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary),
            filled: true,
            fillColor: colors.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
          ),
        ),
      );

  Widget _rings(List<List<Chronique>> mine, List<List<Chronique>> others, List<List<Chronique>> ordered, String? uid, bool reduce, AppColors colors) {
    return SizedBox(
      height: 98,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (mine.isEmpty) ChroniqueAddRing(onTap: _create, size: 62, label: 'Moi') else ChroniqueRing(group: mine.first, seen: false, size: 62, label: 'Moi', onTap: () => _open(mine.first.first, mine.first, ordered)),
          const SizedBox(width: 12),
          for (final g in others) ...[
            ChroniqueRing(group: g, seen: chroniqueGroupSeen(g, uid), spin: reduce ? null : _spin, size: 62, onTap: () => _open(g.first, g, ordered)),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _chips(AppColors colors) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        children: [
          for (final f in ChroniqueFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(chroniqueFilterLabel(f)),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
                showCheckmark: false,
                labelStyle: TextStyle(color: _filter == f ? colors.background : colors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5),
                backgroundColor: colors.surface,
                selectedColor: colors.textPrimary,
                side: BorderSide(color: _filter == f ? colors.textPrimary : colors.border),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  /// Bloc de 6 personnes sur deux colonnes, suivi d'une pub (au moins une pub si la liste a 2 personnes ou plus).
  Widget _block(List<List<Chronique>> shown, int index, List<List<Chronique>> ordered, String? uid, AppColors colors) {
    final from = index * _perBlock;
    final part = shown.skip(from).take(_perBlock).toList();
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < part.length; i++) {
      final g = part[i];
      final col = i.isEven ? left : right;
      final heights = i.isEven ? kChroniqueLeftHeights : kChroniqueRightHeights;
      col.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ChroniqueCard(group: g, seen: chroniqueGroupSeen(g, uid), height: heights[(i ~/ 2) % heights.length], onTap: () => _open(g.first, g, ordered)),
      ));
    }
    final isLast = from + _perBlock >= shown.length;
    final showAd = part.length == _perBlock || (isLast && index == 0 && part.length >= 2);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(children: left)),
          const SizedBox(width: 8),
          Expanded(child: Column(children: right)),
        ]),
        if (showAd) AdSlot(key: ValueKey('chroniques_ad_$index'), kind: AdSlotKind.list, own: () => const AfrolookInlineAd()),
      ]),
    );
  }

  Widget _skeletonGrid(AppColors colors) {
    Widget box(double h) => Container(height: h, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: colors.shimmerBase, borderRadius: BorderRadius.circular(18)));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(children: [for (final h in kChroniqueLeftHeights) box(h)])),
        const SizedBox(width: 8),
        Expanded(child: Column(children: [for (final h in kChroniqueRightHeights) box(h)])),
      ]),
    );
  }

  Widget _noResult(AppColors colors) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
        child: Column(children: [
          Icon(Icons.filter_list_off_rounded, size: 40, color: colors.textSecondary),
          const SizedBox(height: 10),
          Text('Aucune chronique pour ce filtre', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(_hasMore ? 'Recherche en cours…' : 'Essayez « Pour toi » pour tout voir.', textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
        ]),
      );

  Widget _empty(AppColors colors, {required bool error}) {
    Widget tile(IconData icon, String label, ChroniqueType t) => Expanded(
          child: GestureDetector(
            onTap: () => _create(t),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.border)),
              child: Column(children: [
                Icon(icon, color: colors.primary, size: 20),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
      child: Column(children: [
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(alignment: Alignment.center, children: [
            for (final inset in [0.0, 18.0, 36.0])
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(inset),
                  child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: inset == 18 ? colors.primary.withValues(alpha: .4) : colors.border, width: 2))),
                ),
              ),
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kRingGreen, kRingYellow])),
              child: const Icon(Icons.add_rounded, color: Color(0xFF07120B), size: 26),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Text(error ? 'Chargement impossible' : 'Sois le premier du jour', style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          error ? 'Vérifiez votre connexion puis réessayez.' : 'Une chronique dure 24 heures. Texte, photo, vidéo ou voix, avec ta musique si tu veux.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: error ? () => _loadMore(reset: true) : _create,
          icon: Icon(error ? Icons.refresh_rounded : Icons.add_rounded),
          label: Text(error ? 'Réessayer' : 'Créer ma chronique', style: const TextStyle(fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13)),
        ),
        if (!error) ...[
          const SizedBox(height: 18),
          Row(children: [
            tile(Icons.notes_rounded, 'Texte', ChroniqueType.TEXT),
            const SizedBox(width: 8),
            tile(Icons.image_rounded, 'Image', ChroniqueType.IMAGE),
            const SizedBox(width: 8),
            tile(Icons.videocam_rounded, 'Vidéo', ChroniqueType.VIDEO),
            const SizedBox(width: 8),
            tile(Icons.mic_rounded, 'Audio', ChroniqueType.AUDIO),
          ]),
        ],
      ]),
    );
  }
}
