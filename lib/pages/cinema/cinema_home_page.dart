import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/api/cinema_api.dart';
import '../../theme/app_colors.dart';
import 'cinema_admin_page.dart';
import 'cinema_player_page.dart';
import 'cinema_title_page.dart';
import 'cinema_widgets.dart';

/// Accueil de Cartoon Cinéma (21/11/2026) : à la une (annonce en image), pas encore vus, à continuer, séries, films, gratuits.
///  - À chaque visite, tant que les notifications du cinéma ne sont pas activées : fenêtre « Ne ratez aucun épisode ».
///  - Mesures : la visite (et d'où elle vient) puis le temps passé sur la page, envoyé régulièrement.
///  - Bouton de gestion pour l'équipe, selon ses droits.
class CinemaHomePage extends StatefulWidget {
  const CinemaHomePage({super.key, this.source = 'nav'});

  /// D'où vient la visite : nav (bouton du haut), feed (extrait du fil), notif, menu.
  final String source;

  /// Nombre d'épisodes pas encore vus, partagé avec le bouton Cinéma de l'accueil (rafraîchi à chaque visite).
  static final ValueNotifier<int> unseen = ValueNotifier<int>(0);

  static Future<void> refreshUnseen() async {
    try {
      unseen.value = await CinemaApi.unseen();
    } catch (_) {}
  }

  @override
  State<CinemaHomePage> createState() => _CinemaHomePageState();
}

class _CinemaHomePageState extends State<CinemaHomePage> {
  Map<String, dynamic>? _data;
  String? _error;
  String _filter = 'all';
  CinemaRights _rights = const CinemaRights();
  String? _visitId;
  final Stopwatch _watch = Stopwatch();
  Timer? _ping;
  bool _promptShown = false;

  @override
  void initState() {
    super.initState();
    _watch.start();
    _startVisit();
    _load();
    CinemaApi.rights().then((r) {
      if (mounted) setState(() => _rights = r);
    });
  }

  Future<void> _startVisit() async {
    try {
      _visitId = await CinemaApi.visit(widget.source);
      _ping = Timer.periodic(const Duration(seconds: 30), (_) => _sendPing());
    } catch (_) {}
  }

  void _sendPing() {
    final id = _visitId;
    if (id != null) CinemaApi.visitPing(id, _watch.elapsed.inSeconds).catchError((_) {});
  }

  @override
  void dispose() {
    _ping?.cancel();
    _sendPing();
    CinemaHomePage.refreshUnseen();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await CinemaApi.home();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
      CinemaHomePage.unseen.value = (d['unseen_count'] as num?)?.toInt() ?? 0;
      if (d['notifications_on'] != true && !_promptShown) {
        _promptShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _askNotifications());
      }
    } catch (e) {
      if (mounted) setState(() => _error = CinemaApi.message(e, fallback: 'Le cinéma ne répond pas. Réessaie.'));
    }
  }

  /// Fenêtre affichée à chaque visite tant que les notifications du cinéma ne sont pas activées.
  Future<void> _askNotifications() async {
    if (!mounted) return;
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 64, height: 64, decoration: const BoxDecoration(color: Color(0xFFFFD400), shape: BoxShape.circle),
                child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF121212), size: 32)),
            const SizedBox(height: 12),
            Text(ctx.tr('Ne ratez aucun épisode'), textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(ctx.tr('Activez les notifications : vous serez prévenu à chaque nouvel épisode et chaque nouveau film de Cartoon Cinéma.'),
                textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD400), foregroundColor: const Color(0xFF121212), padding: const EdgeInsets.symmetric(vertical: 13)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('Activer les notifications'), style: const TextStyle(fontWeight: FontWeight.w800)),
            )),
            const SizedBox(height: 6),
            SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Plus tard'), style: TextStyle(color: c.textSecondary)))),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
    try {
      await CinemaApi.setNotifications(true);
      if (mounted) {
        setState(() => _data?['notifications_on'] = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Notifications activées : vous serez prévenu à chaque nouvel épisode.'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CinemaApi.message(e))));
    }
  }

  void _openTitle(Map<String, dynamic> t) => Navigator.push(context, MaterialPageRoute(builder: (_) => CinemaTitlePage(titleId: '${t['id']}'))).then((_) => _load());

  void _openEpisode(Map<String, dynamic> e) => Navigator.push(context, MaterialPageRoute(builder: (_) => CinemaPlayerPage(episodeId: '${e['id']}'))).then((_) => _load());

  List<Map<String, dynamic>> _list(String key) => ((_data?[key] as List?) ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        titleSpacing: 0,
        title: Row(children: [const CinemaLogo(size: 28), const SizedBox(width: 8), Text(context.tr('Cartoon Cinéma'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))]),
        actions: [
          IconButton(
            tooltip: context.tr('Notifications'),
            icon: Icon(_data?['notifications_on'] == true ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
            onPressed: () async {
              if (_data?['notifications_on'] == true) {
                await CinemaApi.setNotifications(false).catchError((_) {});
                if (mounted) setState(() => _data?['notifications_on'] = false);
              } else {
                _askNotifications();
              }
            },
          ),
          if (_rights.any)
            IconButton(
              tooltip: context.tr('Gérer le cinéma'),
              icon: const Icon(Icons.admin_panel_settings_rounded),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CinemaAdminPage(rights: _rights))).then((_) => _load()),
            ),
        ],
      ),
      body: _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, style: TextStyle(color: c.textPrimary)),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _load, child: Text(context.tr('Réessayer'))),
            ]))
          : _data == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: _load, child: _content(c)),
    );
  }

  Widget _content(AppColors c) {
    final featured = _list('featured');
    final unseen = _list('unseen');
    final cont = _list('continue');
    final series = _list('series');
    final films = _list('films');
    final free = _list('free');
    final empty = featured.isEmpty && series.isEmpty && films.isEmpty;
    Widget hRow(List<Widget> children) => SizedBox(
          height: children.isEmpty ? 0 : null,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final w in children) Padding(padding: const EdgeInsets.only(right: 10), child: w)]),
          ),
        );
    final chips = [('all', 'Tout'), ('series', 'Séries'), ('films', 'Films'), ('free', 'Gratuit')];
    return ListView(padding: const EdgeInsets.only(bottom: 28), children: [
      SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(14, 8, 14, 4), children: [
          for (final (k, label) in chips)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(context.tr(label)),
                selected: _filter == k,
                onSelected: (_) => setState(() => _filter = k),
                selectedColor: const Color(0xFFFFD400),
                labelStyle: TextStyle(color: _filter == k ? const Color(0xFF121212) : c.textPrimary, fontWeight: FontWeight.w700),
                backgroundColor: c.surface,
                side: BorderSide(color: _filter == k ? Colors.transparent : c.border),
                showCheckmark: false,
              ),
            ),
        ]),
      ),
      if (empty)
        Padding(
          padding: const EdgeInsets.all(30),
          child: Column(children: [
            Icon(Icons.movie_filter_outlined, color: c.textSecondary, size: 48),
            const SizedBox(height: 10),
            Text(context.tr('Les premiers épisodes arrivent bientôt.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
          ]),
        ),
      if (_filter == 'all' && featured.isNotEmpty) _hero(c, featured.first),
      if (_filter == 'all' && unseen.isNotEmpty) ...[
        CinemaRowTitle(context.tr('Pas encore vus'), trailing: '${_data?['unseen_count'] ?? unseen.length}'),
        hRow([for (final e in unseen) CinemaEpisodeThumb(ep: e, onTap: () => _openEpisode(e))]),
      ],
      if (_filter == 'all' && cont.isNotEmpty) ...[
        CinemaRowTitle(context.tr('Continuer à regarder')),
        hRow([for (final e in cont) CinemaEpisodeThumb(ep: e, onTap: () => _openEpisode(e))]),
      ],
      if ((_filter == 'all' || _filter == 'series') && series.isNotEmpty) ...[
        CinemaRowTitle(context.tr('Séries')),
        hRow([for (final t in series) CinemaPoster(title: t, onTap: () => _openTitle(t))]),
      ],
      if ((_filter == 'all' || _filter == 'films') && films.isNotEmpty) ...[
        CinemaRowTitle(context.tr('Films')),
        hRow([for (final t in films) CinemaPoster(title: t, onTap: () => _openTitle(t))]),
      ],
      if ((_filter == 'all' || _filter == 'free') && free.isNotEmpty) ...[
        CinemaRowTitle(context.tr('Gratuits')),
        hRow([for (final e in free) CinemaEpisodeThumb(ep: e, onTap: () => _openEpisode(e))]),
      ],
    ]);
  }

  Widget _hero(AppColors c, Map<String, dynamic> t) {
    return GestureDetector(
      onTap: () => _openTitle(t),
      child: SizedBox(
        height: 260,
        child: Stack(fit: StackFit.expand, children: [
          CinemaImage(t['banner_url'] as String? ?? t['poster_url'] as String?, radius: 0),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xD0000000)], stops: [.35, 1]))),
          Positioned(
            left: 14, right: 14, bottom: 14,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CinemaTag(context.tr(t['kind'] == 'film' ? 'Film' : 'Série')),
              const SizedBox(height: 6),
              Text('${t['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.05)),
              if ((t['genre'] as String?)?.isNotEmpty == true) Text('${t['genre']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD400), foregroundColor: const Color(0xFF121212)),
                onPressed: () => _openTitle(t),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(context.tr('Regarder'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
