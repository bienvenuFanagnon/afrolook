import 'dart:async';

import 'package:flutter/material.dart';

import '../../ads/ad_slot.dart';
import '../../l10n/tr.dart';
import '../../services/api/cinema_api.dart';
import '../../theme/app_colors.dart';
import '../pub/afrolook_inline_ad.dart';
import 'cinema_player_page.dart';
import 'cinema_title_page.dart';
import 'cinema_widgets.dart';

/// Recherche dans Cartoon Cinéma (21/11/2026) : séries et films (titre, résumé, genre), épisodes (nom, résumé, nom de la série).
class CinemaSearchPage extends StatefulWidget {
  const CinemaSearchPage({super.key});

  @override
  State<CinemaSearchPage> createState() => _CinemaSearchPageState();
}

class _CinemaSearchPageState extends State<CinemaSearchPage> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _titles = [];
  List<Map<String, dynamic>> _episodes = [];
  bool _loading = false;
  String _last = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v.trim()));
  }

  Future<void> _search(String q) async {
    if (q == _last) return;
    _last = q;
    if (q.length < 2) {
      setState(() {
        _titles = [];
        _episodes = [];
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await CinemaApi.search(q);
      if (!mounted || q != _last) return;
      setState(() {
        _titles = ((r['titles'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _episodes = ((r['episodes'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CinemaApi.message(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final q = _q.text.trim();
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        titleSpacing: 0,
        title: TextField(
          controller: _q,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => _search(v.trim()),
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: context.tr('Série, film, épisode, genre…'),
            hintStyle: TextStyle(color: c.textSecondary),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (q.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _q.clear();
                _search('');
              },
            ),
        ],
      ),
      body: _loading && _titles.isEmpty && _episodes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : q.length < 2
              ? _hint(c, Icons.search_rounded, context.tr('Cherchez une série, un film, un épisode ou un genre.'))
              : _titles.isEmpty && _episodes.isEmpty
                  ? _hint(c, Icons.movie_filter_outlined, context.tr('Aucun résultat pour « {a} ».', {'a': q}))
                  : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                      if (_titles.isNotEmpty) ...[
                        CinemaRowTitle(context.tr('Séries et films')),
                        SizedBox(
                          height: 230,
                          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: [
                            for (final t in _titles)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: CinemaPoster(title: t, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CinemaTitlePage(titleId: '${t['id']}')))),
                              ),
                          ]),
                        ),
                      ],
                      if (_episodes.isNotEmpty) CinemaRowTitle(context.tr('Épisodes')),
                      for (var i = 0; i < _episodes.length; i++) ...[
                        // une pub (Appodeal / AdMob, sinon Afrolook Ads ; jamais pour Gold) après le 4e résultat puis tous les 8
                        if (i == 4 || (i > 4 && (i - 4) % 8 == 0)) AdSlot(key: ValueKey('cinema_search_ad_$i'), kind: AdSlotKind.list, own: () => const AfrolookInlineAd(compact: true)),
                        _episodeTile(c, _episodes[i]),
                      ],
                    ]),
    );
  }

  Widget _hint(AppColors c, IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: c.textSecondary, size: 44),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
          ]),
        ),
      );

  Widget _episodeTile(AppColors c, Map<String, dynamic> e) => InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CinemaPlayerPage(episodeId: '${e['id']}'))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(children: [
            SizedBox(width: 120, height: 68, child: CinemaImage(e['thumb_url'] as String?, radius: 10)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e['title_name'] ?? ''} · ${context.tr('Ép. {a}', {'a': e['number']})}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
              Text('${e['name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Row(children: [
                cinemaAccessTag(context, e),
                const SizedBox(width: 8),
                Text(cinemaDuration((e['duration_sec'] as num?)?.toInt() ?? 0), style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
              ]),
            ])),
          ]),
        ),
      );
}
