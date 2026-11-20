import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../l10n/tr.dart';
import '../../services/api/cinema_api.dart';
import '../../theme/app_colors.dart';
import '../user/userAbonnementPage.dart';
import 'cinema_widgets.dart';

/// Lecture d'un épisode de Cartoon Cinéma (21/11/2026).
///  - Flux HLS adaptatif : la qualité suit la connexion, la lecture reprend où la personne s'était arrêtée.
///  - Voix off : français par défaut (ou la voix choisie la dernière fois), avec un message qui montre les autres langues ; le changement
///    se fait sur place, sans revenir au début. Sous-titres par langue (fichiers WebVTT affichés par l'application).
///  - Sans Gold, un épisode Gold s'arrête à 15 secondes (le serveur ne donne pas la suite) : pub de 10 s, puis fenêtre « La suite avec Gold ».
///  - À la fin d'un épisode gratuit : la pub de 10 s (jamais pour les abonnés Gold).
///  - Impressions (une par personne), commentaires courts, progression envoyée régulièrement (vue comptée à 10 secondes).
class CinemaPlayerPage extends StatefulWidget {
  const CinemaPlayerPage({super.key, required this.episodeId});

  final String episodeId;

  @override
  State<CinemaPlayerPage> createState() => _CinemaPlayerPageState();
}

class _CinemaPlayerPageState extends State<CinemaPlayerPage> {
  VideoPlayerController? _video;
  Map<String, dynamic>? _play;
  Map<String, dynamic>? _ep;
  String? _error;
  bool _controls = true;
  Timer? _hide;
  Timer? _progressTimer;
  String? _lang;
  String? _subLang;
  bool _paywallShown = false;
  bool _endAdShown = false;
  VideoPlayerController? _ad;
  bool _adPlaying = false;
  bool _voiceHintShown = false;
  List<VideoAudioTrack> _tracks = const [];
  Map<String, int> _reactions = {};
  String? _myReaction;
  List<Map<String, dynamic>> _comments = [];
  String? _commentsCursor;
  bool _loadingComments = false;
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([CinemaApi.play(widget.episodeId), CinemaApi.episode(widget.episodeId)]);
      _play = results[0];
      _ep = results[1];
      _reactions = (Map<String, dynamic>.from((_ep!['reactions'] as Map?) ?? const {})).map((k, v) => MapEntry(k, (v as num).toInt()));
      _myReaction = _ep!['my_reaction'] as String?;
      _lang = (_play!['my_lang'] as String?) ?? (_play!['default_lang'] as String?) ?? 'fr';
      final c = VideoPlayerController.networkUrl(Uri.parse('${_play!['master_url']}'), formatHint: VideoFormat.hls);
      _video = c;
      await c.initialize();
      final resume = (_play!['resume_sec'] as num?)?.toInt() ?? 0;
      if (resume > 5) await c.seekTo(Duration(seconds: resume));
      c.addListener(_onTick);
      await _applyVoice();
      await c.play();
      _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _sendProgress());
      _scheduleHide();
      if (mounted) setState(() {});
      _loadComments();
    } catch (e) {
      if (mounted) setState(() => _error = CinemaApi.message(e, fallback: 'Lecture impossible. Vérifie ta connexion et réessaie.'));
    }
  }

  /// Sélectionne la piste son de la langue voulue (français par défaut) parmi celles du flux.
  Future<void> _applyVoice() async {
    final c = _video;
    if (c == null || !c.value.isInitialized) return;
    try {
      if (!c.isAudioTrackSupportAvailable()) return;
      _tracks = await c.getAudioTracks();
      final want = _lang ?? 'fr';
      final t = _tracks.where((t) => (t.language ?? '').toLowerCase().startsWith(want.toLowerCase())).firstOrNull;
      if (t != null && !t.isSelected) await c.selectAudioTrack(t.id);
    } catch (_) {
      // la lecture continue avec la piste par défaut du flux (le français)
    }
  }

  Future<void> _setVoice(String lang) async {
    setState(() => _lang = lang);
    await _applyVoice();
    _sendProgress();
  }

  Future<void> _setSubtitles(String? lang) async {
    final c = _video;
    if (c == null) return;
    setState(() => _subLang = lang);
    if (lang == null) {
      await c.setClosedCaptionFile(null);
      return;
    }
    final s = ((_play?['subtitles'] as List?) ?? const []).whereType<Map>().where((m) => m['lang'] == lang).firstOrNull;
    final url = s?['url'] as String?;
    if (url == null) return;
    await c.setClosedCaptionFile(http.get(Uri.parse(url)).then((r) => WebVTTCaptionFile(r.body)));
  }

  void _onTick() {
    final c = _video;
    if (c == null || !mounted) return;
    final preview = (_play?['preview_seconds'] as num?)?.toInt();
    // sans Gold : à 10 secondes (ou à la fin du court extrait servi), pause et proposition de l'abonnement
    if (preview != null && !_paywallShown && (c.value.position.inSeconds >= preview || (c.value.isCompleted && c.value.position.inSeconds > 0))) {
      _paywallShown = true;
      c.pause();
      _sendProgress();
      // pub de 10 s (si l'équipe en a mis une), puis la proposition de Gold
      WidgetsBinding.instance.addPostFrameCallback((_) => _playAd(then: _showPaywall));
    }
    // fin d'un épisode gratuit : la pub de 10 s, une seule fois (jamais pour les abonnés Gold : le serveur ne donne alors pas de pub)
    if (preview == null && !_endAdShown && _ep?['access'] == 'free' && c.value.isCompleted && c.value.position.inSeconds > 0) {
      _endAdShown = true;
      _sendProgress();
      WidgetsBinding.instance.addPostFrameCallback((_) => _playAd());
    }
    if (!_voiceHintShown && c.value.isPlaying && c.value.position.inSeconds >= 1) {
      _voiceHintShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showVoiceHint());
    }
    setState(() {});
  }

  void _showVoiceHint() {
    final audio = ((_play?['audio'] as List?) ?? const []).whereType<Map>().toList();
    if (audio.length < 2 || !mounted) return;
    final cur = audio.where((a) => a['lang'] == _lang).firstOrNull?['label'] ?? 'Français';
    final others = audio.where((a) => a['lang'] != _lang).map((a) => '${a['label']}').join(', ');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      content: Text(context.tr('Voix en {a} · Aussi disponible en {b}', {'a': '$cur', 'b': others})),
      action: SnackBarAction(label: context.tr('Changer'), onPressed: _openSettings),
    ));
  }

  /// Joue la vidéo de pub du cinéma (10 s, sans bouton pour passer), puis [then]. Sans pub configurée : [then] tout de suite.
  Future<void> _playAd({VoidCallback? then}) async {
    final url = _play?['ad_video_url'] as String?;
    if (url == null || url.isEmpty || !mounted) {
      then?.call();
      return;
    }
    final ad = VideoPlayerController.networkUrl(Uri.parse(url));
    _ad = ad;
    var done = false;
    void finish() {
      if (done) return;
      done = true;
      ad.dispose();
      if (mounted) setState(() {
        _ad = null;
        _adPlaying = false;
      });
      then?.call();
    }
    try {
      await ad.initialize();
      if (!mounted) return finish();
      ad.addListener(() {
        final d = ad.value.duration;
        if (ad.value.isCompleted || (d > Duration.zero && ad.value.position >= d)) finish();
        if (mounted && !done) setState(() {});
      });
      setState(() => _adPlaying = true);
      await ad.play();
      // garde-fou : jamais plus de 2 secondes au-delà de la durée annoncée de la pub
      Future.delayed(Duration(seconds: ((_play?['ad_seconds'] as num?)?.toInt() ?? 10) + 2), finish);
    } catch (_) {
      finish();
    }
  }

  Future<void> _sendProgress() async {
    final c = _video;
    if (c == null || !c.value.isInitialized) return;
    try {
      await CinemaApi.progress(widget.episodeId, c.value.position.inSeconds, durationSec: c.value.duration.inSeconds, lang: _lang);
    } catch (_) {}
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && (_video?.value.isPlaying ?? false)) setState(() => _controls = false);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    _progressTimer?.cancel();
    _sendProgress();
    _video?.removeListener(_onTick);
    _video?.dispose();
    _ad?.dispose();
    _commentCtrl.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Fenêtres ──

  Future<void> _showPaywall() async {
    if (!mounted) return;
    final c = AppColors.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(9)))),
            const SizedBox(height: 12),
            CinemaTag(ctx.tr('Afrolook Gold'), kind: 'gold', icon: Icons.workspace_premium_rounded),
            const SizedBox(height: 10),
            Text(ctx.tr('La suite avec Gold'), style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(ctx.tr('Vous avez vu les {a} premières secondes. Abonnez-vous pour regarder l\'épisode en entier.', {'a': _play?['preview_seconds'] ?? 10}),
                style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 10),
            for (final l in ['Tous les épisodes et films de Cartoon Cinéma', 'Les nouveaux épisodes dès leur sortie', 'Tous les avantages Gold d\'Afrolook'])
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
                Icon(Icons.check_circle_rounded, color: c.primary, size: 18), const SizedBox(width: 8),
                Expanded(child: Text(ctx.tr(l), style: TextStyle(color: c.textPrimary, fontSize: 13))),
              ])),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD400), foregroundColor: const Color(0xFF121212), padding: const EdgeInsets.symmetric(vertical: 13)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AbonnementScreen()));
              },
              child: Text(ctx.tr('Devenir Gold'), style: const TextStyle(fontWeight: FontWeight.w800)),
            )),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text(ctx.tr('Revoir les épisodes gratuits')),
            )),
          ]),
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    final c = AppColors.of(context);
    final audio = ((_play?['audio'] as List?) ?? const []).whereType<Map>().toList();
    final subs = ((_play?['subtitles'] as List?) ?? const []).whereType<Map>().toList();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Widget radio(bool on) => Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: on ? c.primary : c.textSecondary);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(9)))),
              const SizedBox(height: 12),
              Text(ctx.tr('Voix off'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
              Text(ctx.tr('Le changement se fait tout de suite, sans revenir au début.'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
              for (final a in audio)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: radio(a['lang'] == _lang),
                  title: Text('${a['label']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
                  subtitle: a['lang'] == 'fr' ? Text(ctx.tr('Par défaut'), style: TextStyle(color: c.textSecondary, fontSize: 11)) : null,
                  onTap: () {
                    _setVoice('${a['lang']}');
                    setSheet(() {});
                  },
                ),
              if (subs.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(ctx.tr('Sous-titres'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                ListTile(contentPadding: EdgeInsets.zero, leading: radio(_subLang == null), title: Text(ctx.tr('Aucun'), style: TextStyle(color: c.textPrimary)),
                    onTap: () { _setSubtitles(null); setSheet(() {}); }),
                for (final s in subs)
                  ListTile(contentPadding: EdgeInsets.zero, leading: radio(s['lang'] == _subLang), title: Text('${s['label']}', style: TextStyle(color: c.textPrimary)),
                      onTap: () { _setSubtitles('${s['lang']}'); setSheet(() {}); }),
              ],
            ]),
          ),
        );
      }),
    );
  }

  // ── Impressions et commentaires ──

  Future<void> _react(String kind) async {
    final prev = _myReaction;
    try {
      final r = _myReaction == kind ? await CinemaApi.unreact(widget.episodeId) : await CinemaApi.react(widget.episodeId, kind);
      setState(() {
        _reactions = (Map<String, dynamic>.from((r['reactions'] as Map?) ?? const {})).map((k, v) => MapEntry(k, (v as num).toInt()));
        _myReaction = r['my_reaction'] as String?;
      });
    } catch (e) {
      setState(() => _myReaction = prev);
    }
  }

  Future<void> _loadComments({bool more = false}) async {
    if (_loadingComments || (more && _commentsCursor == null)) return;
    _loadingComments = true;
    try {
      final r = await CinemaApi.comments(widget.episodeId, cursor: more ? _commentsCursor : null);
      if (mounted) setState(() {
        _comments = more ? [..._comments, ...r.items] : r.items;
        _commentsCursor = r.next;
      });
    } catch (_) {
    } finally {
      _loadingComments = false;
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final cm = await CinemaApi.comment(widget.episodeId, text);
      _commentCtrl.clear();
      setState(() => _comments = [cm, ..._comments]);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CinemaApi.message(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _commentMenu(Map<String, dynamic> cm) async {
    final mine = cm['is_mine'] == true;
    final c = AppColors.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (mine) ListTile(leading: Icon(Icons.delete_outline_rounded, color: c.danger), title: Text(ctx.tr('Supprimer'), style: TextStyle(color: c.danger)), onTap: () => Navigator.pop(ctx, 'delete')),
        if (!mine) ListTile(leading: Icon(Icons.flag_outlined, color: c.textPrimary), title: Text(ctx.tr('Signaler'), style: TextStyle(color: c.textPrimary)), onTap: () => Navigator.pop(ctx, 'report')),
      ])),
    );
    try {
      if (action == 'delete') {
        await CinemaApi.deleteComment('${cm['id']}');
        setState(() => _comments.removeWhere((x) => x['id'] == cm['id']));
      } else if (action == 'report') {
        await CinemaApi.reportComment('${cm['id']}');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Merci, le commentaire a été signalé.'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CinemaApi.message(e))));
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> cm) async {
    final like = cm['liked_by_me'] != true;
    try {
      final r = await CinemaApi.likeComment('${cm['id']}', like);
      setState(() {
        cm['liked_by_me'] = r['liked_by_me'];
        cm['likes_count'] = r['likes_count'];
      });
    } catch (_) {}
  }

  // ── Affichage ──

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final player = _buildPlayer(c, landscape);
    if (landscape) {
      return Scaffold(backgroundColor: Colors.black, body: Center(child: player));
    }
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(children: [
          player,
          Expanded(child: _error != null ? _errorView(c) : _details(c)),
        ]),
      ),
    );
  }

  Widget _errorView(AppColors c) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, color: c.textSecondary, size: 40),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () { setState(() => _error = null); _load(); }, child: Text(context.tr('Réessayer'))),
        ]),
      ));

  Widget _buildPlayer(AppColors c, bool landscape) {
    final v = _video;
    final ready = v != null && v.value.isInitialized;
    final ratio = ready && v.value.aspectRatio > 0 ? v.value.aspectRatio : 16 / 9;
    final pos = ready ? v.value.position : Duration.zero;
    final dur = ready ? v.value.duration : Duration.zero;
    final buffered = ready && v.value.buffered.isNotEmpty ? v.value.buffered.last.end : Duration.zero;
    double frac(Duration d) => dur.inMilliseconds > 0 ? (d.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
    final voiceLabel = ((_play?['audio'] as List?) ?? const []).whereType<Map>().where((a) => a['lang'] == _lang).firstOrNull?['label'];
    final ad = _ad;
    if (_adPlaying && ad != null && ad.value.isInitialized) {
      final left = (ad.value.duration - ad.value.position).inSeconds.clamp(0, 99);
      return Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: landscape ? ratio : 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            Center(child: AspectRatio(aspectRatio: ad.value.aspectRatio > 0 ? ad.value.aspectRatio : 16 / 9, child: VideoPlayer(ad))),
            Positioned(top: 10, left: 10, child: CinemaTag(context.tr('Publicité · {a} s', {'a': left}))),
          ]),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() => _controls = !_controls);
        if (_controls) _scheduleHide();
      },
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: landscape ? ratio : 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            if (ready) Center(child: AspectRatio(aspectRatio: ratio, child: VideoPlayer(v))) else const Center(child: CircularProgressIndicator(color: Color(0xFFFFD400))),
            if (ready && v.value.isBuffering) const Center(child: CircularProgressIndicator(color: Color(0xFFFFD400))),
            if (ready) Positioned(left: 16, right: 16, bottom: _controls ? 46 : 14, child: ClosedCaption(text: v.value.caption.text, textStyle: const TextStyle(fontSize: 15, color: Colors.white))),
            if (_controls)
              Container(
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xB3000000)], stops: [0, .3, .62, 1])),
                padding: const EdgeInsets.fromLTRB(4, 4, 10, 6),
                child: Column(children: [
                  Row(children: [
                    IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    Expanded(child: Text(_ep == null ? '' : context.tr('Ép. {a} · {b}', {'a': _ep!['number'], 'b': _ep!['name']}),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                    if (voiceLabel != null) _pill(Icons.record_voice_over_rounded, '$voiceLabel', _openSettings),
                    const SizedBox(width: 6),
                    _pill(Icons.tune_rounded, context.tr('Auto'), _openSettings),
                  ]),
                  const Spacer(),
                  if (ready)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(iconSize: 30, icon: const Icon(Icons.replay_10_rounded, color: Colors.white), onPressed: () => v.seekTo(pos - const Duration(seconds: 10))),
                      const SizedBox(width: 18),
                      IconButton(iconSize: 46, icon: Icon(v.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: Colors.white), onPressed: () {
                        v.value.isPlaying ? v.pause() : v.play();
                        _scheduleHide();
                      }),
                      const SizedBox(width: 18),
                      IconButton(iconSize: 30, icon: const Icon(Icons.forward_10_rounded, color: Colors.white), onPressed: () => v.seekTo(pos + const Duration(seconds: 10))),
                    ]),
                  const Spacer(),
                  if (ready) ...[
                    SizedBox(height: 14, child: LayoutBuilder(builder: (ctx, box) {
                      return GestureDetector(
                        onTapDown: (d) => v.seekTo(dur * (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0)),
                        child: Stack(alignment: Alignment.centerLeft, children: [
                          Container(height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(9))),
                          FractionallySizedBox(widthFactor: frac(buffered), child: Container(height: 4, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(9)))),
                          FractionallySizedBox(widthFactor: frac(pos), child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFFFD400), borderRadius: BorderRadius.circular(9)))),
                        ]),
                      );
                    })),
                    Row(children: [
                      Text(cinemaClock(pos), style: const TextStyle(color: Colors.white, fontSize: 11)),
                      const Spacer(),
                      Text('-${cinemaClock(dur - pos)}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(landscape ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white, size: 20),
                        onPressed: () {
                          if (landscape) {
                            SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                          } else {
                            SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
                            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                          }
                        },
                      ),
                    ]),
                  ],
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 14), const SizedBox(width: 4), Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))]),
        ),
      );

  Widget _details(AppColors c) {
    final ep = _ep;
    if (ep == null) return const SizedBox.shrink();
    final title = (ep['title'] as Map?) ?? const {};
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _loadComments(more: true);
        return false;
      },
      child: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 24), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${title['title'] ?? ''} · ${context.tr('Ép. {a}', {'a': ep['number']})}', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            Text('${ep['name'] ?? ''}', style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.visibility_rounded, size: 14, color: c.textSecondary), const SizedBox(width: 4),
              Text(context.tr('{a} vues', {'a': cinemaCount((ep['views_count'] as num?) ?? 0)}), style: TextStyle(color: c.textSecondary, fontSize: 12)),
              const SizedBox(width: 10),
              Icon(Icons.schedule_rounded, size: 14, color: c.textSecondary), const SizedBox(width: 4),
              Text(cinemaDuration((ep['duration_sec'] as num?)?.toInt() ?? 0), style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ]),
          ])),
          cinemaAccessTag(context, ep),
        ]),
        if ((ep['synopsis'] as String?)?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${ep['synopsis']}', style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final (kind, icon, color, label) in kCinemaReactions)
            GestureDetector(
              onTap: () => _react(kind),
              child: Column(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: _myReaction == kind ? c.primary : c.border, width: _myReaction == kind ? 2 : 1)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 3),
                Text(context.tr(label), style: TextStyle(color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                Text(cinemaCount(_reactions[kind] ?? 0), style: TextStyle(color: c.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            ),
        ]),
        const SizedBox(height: 18),
        Text(context.tr('Commentaires · {a}', {'a': ep['comments_count'] ?? _comments.length}), style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(
            controller: _commentCtrl,
            maxLength: 200,
            minLines: 1,
            maxLines: 3,
            style: TextStyle(color: c.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              counterText: '',
              hintText: context.tr('Un commentaire court…'),
              hintStyle: TextStyle(color: c.textSecondary),
              filled: true, fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide(color: c.border)),
            ),
          )),
          IconButton(onPressed: _sending ? null : _sendComment, icon: Icon(Icons.send_rounded, color: c.primary)),
        ]),
        const SizedBox(height: 6),
        for (final cm in _comments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 15, backgroundColor: c.surfaceVariant,
                  backgroundImage: ((cm['author'] as Map?)?['avatar_url'] as String?)?.isNotEmpty == true ? NetworkImage('${(cm['author'] as Map)['avatar_url']}') : null),
              const SizedBox(width: 9),
              Expanded(child: GestureDetector(
                onLongPress: () => _commentMenu(cm),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('@${(cm['author'] as Map?)?['username'] ?? ''}', style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
                  Text('${cm['body']}', style: TextStyle(color: c.textPrimary, fontSize: 13)),
                ]),
              )),
              GestureDetector(
                onTap: () => _toggleLike(cm),
                child: Column(children: [
                  Icon(cm['liked_by_me'] == true ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 18, color: cm['liked_by_me'] == true ? const Color(0xFFFF4D6A) : c.textSecondary),
                  Text('${cm['likes_count'] ?? 0}', style: TextStyle(color: c.textSecondary, fontSize: 10)),
                ]),
              ),
              IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.more_vert_rounded, size: 18, color: c.textSecondary), onPressed: () => _commentMenu(cm)),
            ]),
          ),
      ]),
    );
  }
}
