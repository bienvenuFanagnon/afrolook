import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/api/cinema_api.dart';
import '../../theme/app_colors.dart';
import 'cinema_player_page.dart';
import 'cinema_widgets.dart';

/// Page d'une série ou d'un film de Cartoon Cinéma (21/11/2026) : chiffres visibles par tous (vues, j'aime, commentaires), résumé, saisons et épisodes
/// (gratuit, ou 10 secondes puis Gold), reprise où la personne s'était arrêtée.
class CinemaTitlePage extends StatefulWidget {
  const CinemaTitlePage({super.key, required this.titleId});

  final String titleId;

  @override
  State<CinemaTitlePage> createState() => _CinemaTitlePageState();
}

class _CinemaTitlePageState extends State<CinemaTitlePage> {
  Map<String, dynamic>? _t;
  String? _error;
  int _season = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await CinemaApi.title(widget.titleId);
      if (!mounted) return;
      final seasons = ((t['seasons'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
      setState(() {
        _t = t;
        _error = null;
        if (seasons.isNotEmpty && !seasons.contains(_season)) _season = seasons.first;
      });
    } catch (e) {
      if (mounted) setState(() => _error = CinemaApi.message(e));
    }
  }

  List<Map<String, dynamic>> get _episodes => ((_t?['episodes'] as List?) ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

  void _play(Map<String, dynamic> e) => Navigator.push(context, MaterialPageRoute(builder: (_) => CinemaPlayerPage(episodeId: '${e['id']}'))).then((_) => _load());

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = _t;
    if (t == null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, elevation: 0),
        body: Center(child: _error != null ? Text(_error!, style: TextStyle(color: c.textPrimary)) : const CircularProgressIndicator()),
      );
    }
    final eps = _episodes;
    final seasons = ((t['seasons'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final shown = eps.where((e) => (e['season'] as num?)?.toInt() == _season).toList();
    // reprendre : le dernier épisode commencé et pas terminé, sinon le premier pas encore vu, sinon le premier
    final resume = eps.where((e) => (e['my_position_sec'] as num? ?? 0) > 0 && e['my_completed'] != true).lastOrNull ?? eps.where((e) => e['seen'] != true).firstOrNull ?? eps.firstOrNull;
    final film = t['kind'] == 'film';
    return Scaffold(
      backgroundColor: c.background,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            backgroundColor: c.surface,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(background: Stack(fit: StackFit.expand, children: [
              CinemaImage(t['banner_url'] as String? ?? t['poster_url'] as String?, radius: 0),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66000000), Color(0x00000000), Color(0x99000000)]))),
            ])),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t['title']}', style: TextStyle(color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  CinemaTag(context.tr(film ? 'Film' : 'Série')),
                  if ((t['genre'] as String?)?.isNotEmpty == true) Text('${t['genre']}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  if (!film) Text(context.tr('{a} épisodes', {'a': eps.length}), style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  if ((t['age_rating'] as String?)?.isNotEmpty == true) Text('${t['age_rating']}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _stat(c, cinemaCount((t['views_count'] as num?) ?? 0), context.tr('VUES')),
                  const SizedBox(width: 6),
                  _stat(c, cinemaCount((t['likes_count'] as num?) ?? 0), context.tr("J'AIME")),
                  const SizedBox(width: 6),
                  _stat(c, cinemaCount((t['comments_count'] as num?) ?? 0), context.tr('COMMENT.')),
                ]),
                const SizedBox(height: 10),
                if (resume != null)
                  SizedBox(width: double.infinity, child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD400), foregroundColor: const Color(0xFF121212), padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => _play(resume),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      film ? context.tr('Regarder') : ((resume['my_position_sec'] as num? ?? 0) > 0 ? context.tr('Reprendre · Ép. {a}', {'a': resume['number']}) : context.tr('Regarder · Ép. {a}', {'a': resume['number']})),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  )),
                if ((t['synopsis'] as String?)?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 10), child: Text('${t['synopsis']}', style: TextStyle(color: c.textSecondary, fontSize: 13))),
                if (seasons.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(spacing: 6, children: [
                      for (final s in seasons)
                        ChoiceChip(
                          label: Text(context.tr('Saison {a}', {'a': s})),
                          selected: s == _season,
                          showCheckmark: false,
                          selectedColor: const Color(0xFFFFD400),
                          labelStyle: TextStyle(color: s == _season ? const Color(0xFF121212) : c.textPrimary, fontWeight: FontWeight.w700),
                          onSelected: (_) => setState(() => _season = s),
                        ),
                    ]),
                  ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
          SliverList.builder(
            itemCount: shown.length,
            itemBuilder: (ctx, i) {
              final e = shown[i];
              final dur = (e['duration_sec'] as num?)?.toInt() ?? 0;
              final pos = (e['my_position_sec'] as num?)?.toInt() ?? 0;
              final locked = e['access'] != 'free';
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _play(e),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
                    child: Row(children: [
                      SizedBox(width: 108, height: 62, child: Stack(fit: StackFit.expand, children: [
                        CinemaImage(e['thumb_url'] as String?, radius: 10),
                        if (dur > 0 && pos > 0)
                          Positioned(left: 6, right: 6, bottom: 6, child: LinearProgressIndicator(value: (pos / dur).clamp(0.0, 1.0), minHeight: 3, color: const Color(0xFFFFD400), backgroundColor: Colors.white38)),
                      ])),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${e['number']}. ${e['name']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${cinemaDuration(dur)} · ${context.tr('{a} vues', {'a': cinemaCount((e['views_count'] as num?) ?? 0)})}', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                        const SizedBox(height: 4),
                        cinemaAccessTag(context, e),
                      ])),
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: locked ? const Color(0xFFFFD400) : c.primary, shape: BoxShape.circle),
                        child: Icon(locked ? Icons.lock_rounded : Icons.play_arrow_rounded, size: 18, color: locked ? const Color(0xFF121212) : c.onPrimary),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]),
      ),
    );
  }

  Widget _stat(AppColors c, String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
          child: Column(children: [
            Text(value, style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: c.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: .3)),
          ]),
        ),
      );
}
