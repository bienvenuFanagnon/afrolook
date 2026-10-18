import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../theme/app_colors.dart';
import '../studio/artist_marketplace.dart';
import '../studio/montage/montage_music.dart';
import '../studio/sound_countries.dart';
import 'chronique_music.dart';

String _mmss(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Choix de la musique d'une chronique, en une seule feuille : quatre onglets (gratuites, artistes, ma bibliothèque, ma voix),
/// liste avec écoute et prix, fenêtre sur l'onde pour couper l'extrait (5 à 30 s), volume, et pour une vidéo garder ou non son son d'origine.
/// Renvoie la musique réglée, ou null si on ferme sans choisir.
Future<ChroniqueMusic?> showChroniqueMusicSheet(BuildContext context, {required bool isVideo}) {
  return showModalBottomSheet<ChroniqueMusic>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _MusicSheet(isVideo: isVideo),
  );
}

/// Une ligne choisissable : de quoi construire la [ChroniqueMusic] une fois réglée.
class _Pick {
  _Pick({required this.key, required this.title, required this.subtitle, required this.durationMs, this.coins = 0, this.source, this.url, this.localPath});
  final String key;
  final String title;
  final String subtitle;
  final int durationMs;
  final int coins;
  final MontageMusic? source;
  final String? url;
  final String? localPath;
}

class _MusicSheet extends StatefulWidget {
  const _MusicSheet({required this.isVideo});
  final bool isVideo;

  @override
  State<_MusicSheet> createState() => _MusicSheetState();
}

class _MusicSheetState extends State<_MusicSheet> {
  static const _tabs = ['Gratuites', 'Artistes', 'Ma bibliothèque', 'Ma voix'];
  int _tab = 0;
  final TextEditingController _search = TextEditingController();

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  String? _playingKey;

  _Pick? _pick;
  int _start = 0;
  int _end = 0;
  double _volume = .7;
  bool _keepVideo = false;
  String? _busyKey;

  // Artistes / bibliothèque
  List<_Pick>? _artists;
  List<_Pick>? _library;
  bool _loadingArtists = false;
  bool _loadingLibrary = false;
  bool _errorArtists = false;
  bool _errorLibrary = false;

  // Ma voix
  AudioRecorder? _recorder;
  bool _recording = false;
  int _recMs = 0;
  Timer? _recTimer;

  @override
  void initState() {
    super.initState();
    _posSub = _player.onPositionChanged.listen((p) {
      if (_pick != null && _end > 0 && p.inMilliseconds >= _end && _playingKey == _pick!.key) _stopPlay();
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _recTimer?.cancel();
    _search.dispose();
    _player.dispose();
    _recorder?.dispose();
    super.dispose();
  }

  // ── Écoute ────────────────────────────────────────────────────────────────

  Future<void> _stopPlay() async {
    try {
      await _player.stop();
    } catch (_) {}
    if (mounted) setState(() => _playingKey = null);
  }

  Future<String?> _urlOf(_Pick p) async {
    if (p.url != null && p.url!.isNotEmpty) return p.url;
    if (p.source != null) return MontageMusicPlayer.urlOf(p.source!);
    return null;
  }

  Future<void> _togglePlay(_Pick p) async {
    if (_playingKey == p.key) return _stopPlay();
    await _stopPlay();
    setState(() => _busyKey = p.key);
    try {
      final start = _pick?.key == p.key ? _start : 0;
      final Source? src = p.localPath != null ? DeviceFileSource(p.localPath!) : (await _urlOf(p)) == null ? null : UrlSource((await _urlOf(p))!);
      if (src == null) throw StateError('source');
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(_volume);
      await _player.play(src, position: Duration(milliseconds: start));
      if (mounted) setState(() => _playingKey = p.key);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de lire ce son. Vérifiez votre connexion.')));
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  void _select(_Pick p) {
    _stopPlay();
    setState(() {
      _pick = p;
      _start = 0;
      _end = p.durationMs < ChroniqueMusic.maxClipMs ? p.durationMs : ChroniqueMusic.maxClipMs;
    });
  }

  // ── Chargements ───────────────────────────────────────────────────────────

  Future<void> _loadArtists() async {
    if (_artists != null || _loadingArtists) return;
    setState(() {
      _loadingArtists = true;
      _errorArtists = false;
    });
    try {
      final snap = await loadArtistSoundsSnapshot();
      if (!mounted) return;
      final sounds = SoundCountries.forViewer<ArtistSound>(
        [for (final d in snap.docs) ArtistSound.fromMap(d.data() as Map<String, dynamic>, d.id)],
        countries: (s) => s.availableCountries,
        owner: (s) => s.userId,
        viewerCountry: SoundCountries.viewerCountry(context),
      );
      setState(() => _artists = [for (final s in sounds) _fromSound(s)]);
    } catch (_) {
      if (mounted) setState(() => _errorArtists = true);
    } finally {
      if (mounted) setState(() => _loadingArtists = false);
    }
  }

  _Pick _fromSound(ArtistSound s) {
    final m = MontageMusic.artist(s);
    // Mêmes règles que partout : son gratuit = rien à payer ; son payant = prix d'utilisation (60 % pour l'artiste) ; ses propres sons sont gratuits
    final mine = s.userId == FirebaseAuth.instance.currentUser?.uid;
    return _Pick(key: 'artist:${s.id}', title: s.title, subtitle: '@${s.userPseudo}${(s.genre ?? '').isNotEmpty ? ' · ${s.genre}' : ''}${mine ? ' · mon son' : ''} · ${s.previewSec} s', durationMs: m.durationMs, coins: m.paid && !mine ? m.useCoins : 0, source: m, url: s.previewUrl);
  }

  /// Titres achetés : la liste ne lit que ma bibliothèque ; la fiche du son (extrait, prix) n'est lue qu'au choix d'un titre.
  Future<void> _loadLibrary() async {
    if (_library != null || _loadingLibrary) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _loadingLibrary = true;
      _errorLibrary = false;
    });
    try {
      final snap = await FirebaseFirestore.instance.collection('MusicLibrary').where('uid', isEqualTo: uid).limit(50).get();
      if (!mounted) return;
      setState(() => _library = [
            for (final d in snap.docs)
              _Pick(key: 'lib:${d.data()['soundId']}', title: '${d.data()['title'] ?? 'Titre'}', subtitle: '${(d.data()['userPseudo'] ?? '').toString().isEmpty ? 'Acheté' : '@${d.data()['userPseudo']}'} · acheté', durationMs: 0, url: null),
          ]);
    } catch (_) {
      if (mounted) setState(() => _errorLibrary = true);
    } finally {
      if (mounted) setState(() => _loadingLibrary = false);
    }
  }

  Future<void> _selectLibrary(_Pick p) async {
    setState(() => _busyKey = p.key);
    try {
      final id = p.key.substring(4);
      final doc = await FirebaseFirestore.instance.collection('artist_sounds').doc(id).get();
      if (!doc.exists || doc.data()!['status'] != 'validated' || ((doc.data()!['previewUrl'] ?? '') as String).isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce titre n\'est plus disponible.')));
        return;
      }
      final full = _fromSound(ArtistSound.fromMap(doc.data()!, doc.id));
      // on garde la ligne de la bibliothèque mais avec l'extrait, la durée et le prix réels
      _select(_Pick(key: p.key, title: full.title, subtitle: full.subtitle, durationMs: full.durationMs, coins: full.coins, source: full.source, url: full.url));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chargement impossible. Réessayez.')));
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  // ── Ma voix ───────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    await _stopPlay();
    _recorder ??= AudioRecorder();
    try {
      if (!await _recorder!.hasPermission()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Autorisez le micro pour enregistrer votre voix.')));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/chr_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder!.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() {
        _recording = true;
        _recMs = 0;
      });
      _recTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
        if (!mounted) return t.cancel();
        setState(() => _recMs += 200);
        if (_recMs >= ChroniqueMusic.maxClipMs) _stopRecording();
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enregistrement impossible.')));
    }
  }

  Future<void> _stopRecording() async {
    _recTimer?.cancel();
    final ms = _recMs;
    String? path;
    try {
      path = await _recorder?.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _recording = false);
    if (path == null || ms < 1500) {
      if (ms < 1500 && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enregistrement trop court.')));
      return;
    }
    _select(_Pick(key: 'voice:$path', title: 'Ma voix', subtitle: 'Enregistrement · ${_mmss(ms)}', durationMs: ms, localPath: path));
  }

  Future<void> _pickFile() async {
    await _stopPlay();
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
      final path = r?.files.firstOrNull?.path;
      if (path == null) return;
      if (await File(path).length() > 20 * 1024 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le fichier ne doit pas dépasser 20 Mo.')));
        return;
      }
      final probe = AudioPlayer();
      await probe.setSource(DeviceFileSource(path));
      final d = await probe.getDuration();
      await probe.dispose();
      final ms = d?.inMilliseconds ?? 0;
      if (ms < 3000) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fichier audio illisible ou trop court.')));
        return;
      }
      if (mounted) setState(() => _tab = 3);
      _select(_Pick(key: 'voice:$path', title: path.split('/').last, subtitle: 'Mon fichier · ${_mmss(ms)}', durationMs: ms, localPath: path));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fichier audio illisible.')));
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────

  Future<void> _confirm() async {
    final p = _pick;
    if (p == null) return;
    await _stopPlay();
    final ChroniqueMusic m;
    if (p.localPath != null) {
      m = ChroniqueMusic.voice(localPath: p.localPath!, durationMs: p.durationMs);
    } else {
      final url = await _urlOf(p);
      if (url == null || url.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cette musique est indisponible pour le moment.')));
        return;
      }
      m = ChroniqueMusic.from(p.source!, url);
    }
    m
      ..startMs = _start
      ..endMs = _end
      ..volume = _volume
      ..keepVideoSound = widget.isVideo && _keepVideo
      ..clamp();
    if (mounted) Navigator.pop(context, m);
  }

  // ── Interface ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      minChildSize: .5,
      maxChildSize: .96,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 10),
        Container(width: 38, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
          child: Row(children: [
            Expanded(child: Text('Choisir une musique', style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800))),
            TextButton.icon(
              onPressed: _pickFile,
              icon: Icon(Icons.smartphone_rounded, size: 18, color: c.primary),
              label: Text('Depuis mon téléphone', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
          ]),
        ),
        if (_tab < 3)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: TextStyle(color: c.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: _tab == 1 ? 'Chercher un titre, un artiste ou un style' : 'Chercher un titre',
                hintStyle: TextStyle(color: c.textSecondary, fontSize: 13.5),
                prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary, size: 20),
                suffixIcon: _search.text.isEmpty ? null : IconButton(icon: Icon(Icons.close_rounded, size: 18, color: c.textSecondary), onPressed: () => setState(_search.clear)),
                isDense: true,
                filled: true,
                fillColor: c.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
              ),
            ),
          ),
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: [
            for (var i = 0; i < _tabs.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _tab = i);
                    if (i == 1) _loadArtists();
                    if (i == 2) _loadLibrary();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: _tab == i ? c.textPrimary : Colors.transparent, borderRadius: BorderRadius.circular(99), border: Border.all(color: _tab == i ? c.textPrimary : c.border)),
                    child: Text(_tabs[i], style: TextStyle(color: _tab == i ? c.background : c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ),
              ),
          ]),
        ),
        Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), children: _body(c))),
        if (_pick != null) _settings(c),
      ]),
    );
  }

  String get _q => _search.text.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
  bool _match(_Pick p, [String extra = '']) => _q.isEmpty || '${p.title} ${p.subtitle} $extra'.toLowerCase().contains(_q);

  List<Widget> _body(AppColors c) {
    switch (_tab) {
      case 0:
        final free = [for (final t in kStudioTracks) _Pick(key: 'free:${t.id}', title: t.title, subtitle: '${t.mood} · ${_mmss(t.durationMs)}', durationMs: t.durationMs, source: MontageMusic.free(t))].where(_match).toList();
        return free.isEmpty ? [_state(c, false, false, 'Aucune musique ne correspond à « ${_search.text.trim()} ».', null)] : [for (final p in free) _row(c, p)];
      case 1:
        if (_artists == null) return [_state(c, _loadingArtists, _errorArtists, 'Aucun son d\'artiste pour l\'instant.', _loadArtists)];
        final found = _artists!.where(_match).toList();
        return found.isEmpty ? [_state(c, false, false, _q.isEmpty ? 'Aucun son d\'artiste pour l\'instant.' : 'Aucun son ne correspond à « ${_search.text.trim()} ».', null)] : [for (final p in found) _row(c, p)];
      case 2:
        if (FirebaseAuth.instance.currentUser == null) return [_state(c, false, false, 'Connectez-vous pour voir vos titres achetés.', null)];
        if (_library == null) {
          if (!_loadingLibrary && !_errorLibrary) WidgetsBinding.instance.addPostFrameCallback((_) => _loadLibrary());
          return [_state(c, _loadingLibrary, _errorLibrary, 'Aucun titre acheté pour l\'instant.', _loadLibrary)];
        }
        final mine = _library!.where(_match).toList();
        return mine.isEmpty ? [_state(c, false, false, _q.isEmpty ? 'Aucun titre acheté pour l\'instant.' : 'Aucun titre ne correspond à « ${_search.text.trim()} ».', null)] : [for (final p in mine) _row(c, p, library: true)];
      default:
        return [_voice(c)];
    }
  }

  Widget _state(AppColors c, bool loading, bool error, String empty, VoidCallback? retry) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: loading
              ? CircularProgressIndicator(color: c.primary)
              : error
                  ? TextButton.icon(onPressed: retry, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer'))
                  : Text(empty, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
        ),
      );

  Widget _row(AppColors c, _Pick p, {bool library = false}) {
    final selected = _pick?.key == p.key;
    final playing = _playingKey == p.key;
    return GestureDetector(
      onTap: library ? () => _selectLibrary(p) : () => _select(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(color: selected ? c.primary.withValues(alpha: .12) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          InkWell(
            onTap: library && p.url == null && p.source == null ? () => _selectLibrary(p) : () => _togglePlay(p),
            customBorder: const CircleBorder(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? c.primary : c.surfaceVariant),
              child: _busyKey == p.key
                  ? const Padding(padding: EdgeInsets.all(9), child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18, color: selected ? c.onPrimary : c.textPrimary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
              Text(p.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11)),
            ]),
          ),
          if (p.durationMs > 0 || !library)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: p.coins > 0 ? c.border : c.primary)),
              child: Text(p.coins > 0 ? '${p.coins} pièces' : 'Gratuit', style: TextStyle(color: p.coins > 0 ? c.textSecondary : c.primary, fontSize: 10.5, fontWeight: FontWeight.w800)),
            ),
        ]),
      ),
    );
  }

  Widget _voice(AppColors c) {
    final recorded = _pick?.localPath != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            GestureDetector(
              onTap: _recording ? _stopRecording : _startRecording,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _recording ? Colors.redAccent : c.primary, boxShadow: [BoxShadow(color: (_recording ? Colors.redAccent : c.primary).withValues(alpha: .4), blurRadius: 18)]),
                child: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 34),
              ),
            ),
            const SizedBox(height: 12),
            Text(_recording ? 'Enregistrement… ${_mmss(_recMs)} / 0:30' : (recorded ? 'Voix enregistrée · ${_mmss(_pick!.durationMs)}' : 'Appuyez pour enregistrer votre voix'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('30 secondes au plus, gratuit.', style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _recording ? null : _pickFile,
          icon: const Icon(Icons.audio_file_rounded, size: 18),
          label: const Text('Choisir un fichier audio', style: TextStyle(fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(foregroundColor: c.textPrimary, side: BorderSide(color: c.border), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
        if (recorded) ...[const SizedBox(height: 8), _row(c, _pick!)],
      ]),
    );
  }

  /// Onde, fenêtre de l'extrait, volume, son de la vidéo et bouton de validation.
  Widget _settings(AppColors c) {
    final p = _pick!;
    final dur = p.durationMs <= 0 ? 1 : p.durationMs;
    final maxSpan = dur < ChroniqueMusic.maxClipMs ? dur : ChroniqueMusic.maxClipMs;
    final bars = List<double>.generate(34, (i) => .25 + ((p.key.hashCode.abs() >> (i % 13)) % 7) / 9 + (i % 5) * .04);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom * .5),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 52,
          child: LayoutBuilder(builder: (_, box) {
            final w = box.maxWidth;
            return Stack(alignment: Alignment.center, children: [
              Container(decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(12))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  for (final b in bars) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: Container(height: 36 * b.clamp(.2, 1.0), decoration: BoxDecoration(color: c.textSecondary.withValues(alpha: .5), borderRadius: BorderRadius.circular(2))))),
                ]),
              ),
              Positioned(
                left: w * _start / dur,
                width: w * (_end - _start) / dur,
                top: 0,
                bottom: 0,
                child: IgnorePointer(child: Container(decoration: BoxDecoration(color: c.primary.withValues(alpha: .18), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.primary, width: 2)))),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 0, activeTrackColor: Colors.transparent, inactiveTrackColor: Colors.transparent, overlayShape: SliderComponentShape.noOverlay, rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 7), thumbColor: c.primary),
                child: RangeSlider(
                  values: RangeValues(_start.toDouble(), _end.toDouble().clamp(_start + 1, dur.toDouble())),
                  min: 0,
                  max: dur.toDouble(),
                  onChanged: p.durationMs <= 0
                      ? null
                      : (v) => setState(() {
                            var s = v.start.round();
                            var e = v.end.round();
                            if (e - s > maxSpan) {
                              if ((s - _start).abs() > (e - _end).abs()) {
                                e = s + maxSpan;
                              } else {
                                s = e - maxSpan;
                              }
                            }
                            final minLen = dur < ChroniqueMusic.minClipMs ? dur : ChroniqueMusic.minClipMs;
                            if (e - s < minLen) {
                              if ((s - _start).abs() > (e - _end).abs()) {
                                s = e - minLen;
                              } else {
                                e = s + minLen;
                              }
                            }
                            _start = s.clamp(0, dur);
                            _end = e.clamp(0, dur);
                          }),
                ),
              ),
            ]);
          }),
        ),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Début ${_mmss(_start)}', style: TextStyle(color: c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
          Text('Extrait de ${((_end - _start) / 1000).round()} s', style: TextStyle(color: c.textPrimary, fontSize: 10.5, fontWeight: FontWeight.w800)),
          Text('Fin ${_mmss(_end)}', style: TextStyle(color: c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ]),
        Row(children: [
          Text('Volume de la musique', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
          Expanded(child: Slider(value: _volume, min: .1, max: 1, activeColor: c.primary, onChanged: (v) => setState(() => _volume = v))),
          Text('${(_volume * 100).round()} %', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        if (widget.isVideo)
          Row(children: [
            Expanded(child: Text(_keepVideo ? 'Le son de la vidéo est gardé et mélangé' : 'La musique remplace le son de la vidéo', style: TextStyle(color: c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700))),
            Switch(value: _keepVideo, activeColor: c.primary, onChanged: (v) => setState(() => _keepVideo = v)),
          ]),
        if (p.coins > 0)
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Align(alignment: Alignment.centerLeft, child: Text('${p.coins} pièces seront débitées à la publication. L\'artiste en reçoit 60 %.', style: TextStyle(color: c.textSecondary, fontSize: 11.5)))),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _confirm,
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
            child: const Text('Utiliser cette musique', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }
}
