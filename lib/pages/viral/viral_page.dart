import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../l10n/tr.dart';
import '../../services/api/api_gateway.dart';
import '../../services/api/viral_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/feed/sections/feed_ad_widgets.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';

/// Page « 🔥 Viral » : les posts dont l'activité accélère en ce moment, aujourd'hui ou cette semaine. Visible par tous, même liste de cartes que « Pour toi ».
/// Un post qui reste à l'écran est compté comme vu : il sort du « +N » de l'onglet.
class ViralPage extends StatefulWidget {
  const ViralPage({super.key, this.initialWindow = '2h'});
  final String initialWindow;

  @override
  State<ViralPage> createState() => _ViralPageState();
}

class _ViralPageState extends State<ViralPage> {
  final _scroll = ScrollController();
  final _items = <ViralItem>[];
  late String _window = ViralApi.windows.contains(widget.initialWindow) ? widget.initialWindow : '2h';
  String? _next;
  bool _loading = false;
  bool _failed = false;
  bool _loaded = false;
  int _token = 0;

  static const _adEvery = 6;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _load();
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && _loaded && _next == null)) return;
    final token = reset ? ++_token : _token;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _items.clear();
        _next = null;
        _loaded = false;
      }
    });
    try {
      final page = await ViralApi.page(_window, cursor: reset ? null : _next);
      if (!mounted || token != _token) return;
      final known = _items.map((e) => e.post.id).toSet();
      setState(() {
        _items.addAll(page.items.where((e) => !known.contains(e.post.id)));
        _next = page.next;
        _loaded = true;
      });
    } catch (_) {
      if (mounted && token == _token) setState(() => _failed = true);
    } finally {
      if (mounted && token == _token) setState(() => _loading = false);
    }
  }

  void _pick(String w) {
    if (w == _window) return;
    setState(() => _window = w);
    _load(reset: true);
  }

  String _windowLabel(String w) => switch (w) { '2h' => context.tr('En ce moment'), '24h' => context.tr("Aujourd'hui"), _ => context.tr('Cette semaine') };

  String _speed(ViralItem it) => switch (_window) {
        '2h' => context.tr('+{n} interactions en 2 h', {'n': it.interactions}),
        '24h' => context.tr('+{n} interactions en 24 h', {'n': it.interactions}),
        _ => context.tr('+{n} interactions en 7 jours', {'n': it.interactions}),
      };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 18, color: colors.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text('🔥 ${context.tr('Viral')}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(children: [
              for (final w in ViralApi.windows) ...[
                ChoiceChip(
                  key: ValueKey('viral_window_$w'),
                  label: Text(_windowLabel(w), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: w == _window ? colors.onPrimary : colors.textPrimary)),
                  selected: w == _window,
                  selectedColor: colors.primary,
                  backgroundColor: colors.surface,
                  side: BorderSide(color: colors.border),
                  showCheckmark: false,
                  onSelected: (_) => _pick(w),
                ),
                const SizedBox(width: 8),
              ],
            ]),
          ),
        ),
      ),
      body: _body(colors, size),
    );
  }

  Widget _body(AppColors colors, Size size) {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && _failed) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.tr('Impossible de charger les posts viraux pour le moment.'), style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => _load(reset: true), child: Text(context.tr('Réessayer'))),
        ]),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(context.tr('Pas encore de post viral. Reviens bientôt !'), textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 14)),
        ),
      );
    }
    // pubs intercalées toutes les 6 cartes
    final rows = <Object>[];
    for (var i = 0; i < _items.length; i++) {
      rows.add(_items[i]);
      if ((i + 1) % _adEvery == 0) rows.add('viral_ad_${i ~/ _adEvery}');
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 80),
        itemCount: rows.length + (_loading || _next != null ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == rows.length) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
          final row = rows[i];
          if (row is String) return FeedUnifiedAdSlot(adKey: row);
          final it = row as ViralItem;
          final post = it.post;
          return VisibilityDetector(
            key: ValueKey('viral_vis_${post.id}'),
            onVisibilityChanged: (info) {
              // un post resté à l'écran est « vu » : le serveur le compte une seule fois et il sort du « +N »
              if (info.visibleFraction >= 0.6 && post.id != null) ApiGateway.instance.markViewed(post.id!);
            },
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Row(children: [
                  Container(
                    key: ValueKey('viral_badge_${post.id}'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(10)),
                    child: Text('🔥 ${context.tr('Viral')}', style: TextStyle(color: colors.onPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  if (it.interactions > 0) Flexible(child: Text(_speed(it), style: TextStyle(color: colors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                ]),
              ),
              HomePostUsersWidget(
                key: ValueKey('viral-${post.id}'),
                post: post,
                index: i,
                height: size.height * 0.6,
                width: size.width,
                isDegrade: true,
                suppressInlineAd: true,
              ),
            ]),
          );
        },
      ),
    );
  }
}
