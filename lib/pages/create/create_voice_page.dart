import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../l10n/tr.dart';
import '../../services/api/studio_trim_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/api_error_dialogs.dart';
import 'trim_sheet.dart';

/// Audio choisi dans le parcours : enregistré avec le micro de l'application ([recorded] = « Fait sur Afrolook ») ou pris dans les fichiers du téléphone.
/// [cover] : pochette choisie (facultative), publiée comme image du post audio.
class CreateVoiceResult {
  const CreateVoiceResult({required this.file, required this.seconds, required this.recorded, this.cover});
  final File file;
  final int seconds;
  final bool recorded;
  final File? cover;
}

/// Durée maximale d'un audio de post (secondes) et poids maximal d'un fichier importé.
const int kVoiceMaxSeconds = 180;
const int kVoiceMaxBytes = 10 * 1024 * 1024;

/// Enregistrement vocal du parcours « Créer un post » (écrans « Enregistrer » puis « Ton audio » de la proposition) : l'onde bouge pendant qu'on parle, un grand bouton
/// micro rouge, le temps « 0:48 / 3:00 ». Ensuite on réécoute, on peut couper dans le son (découpe faite par le serveur) et choisir une pochette, puis « Suivant ».
/// On peut aussi importer un fichier audio du téléphone (compté comme un média importé).
class CreateVoicePage extends StatefulWidget {
  const CreateVoicePage({super.key, this.allowPick = true});

  /// Choisir un fichier audio du téléphone (un média importé : limité chaque jour). Masqué quand la limite du jour est atteinte.
  final bool allowPick;

  @override
  State<CreateVoicePage> createState() => _CreateVoicePageState();
}

class _CreateVoicePageState extends State<CreateVoicePage> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  Timer? _timer;
  StreamSubscription<Amplitude>? _ampSub;
  bool _recording = false;
  bool _playing = false;
  bool _busy = false;
  int _seconds = 0;
  File? _file;
  File? _cover;
  bool _recorded = false;
  String? _error;
  Duration _pos = Duration.zero;

  /// Niveaux (0 à 1) pendant l'enregistrement, puis barres figées de l'onde affichée.
  final List<double> _levels = [];
  List<double> _bars = const [];

  static const _barCount = 34;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (kIsWeb) return;
    await _player.stop();
    if (!await Permission.microphone.request().isGranted) {
      setState(() => _error = context.tr('Autorise le micro pour t\'enregistrer.'));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voix_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000), path: path);
    } catch (_) {
      setState(() => _error = context.tr('Impossible de démarrer l\'enregistrement.'));
      return;
    }
    _levels.clear();
    _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 90)).listen((a) {
      // -45 dB (silence) → 0 ; 0 dB → 1
      final v = ((a.current + 45) / 45).clamp(0.0, 1.0);
      if (mounted) setState(() => _levels.add(v));
    });
    setState(() {
      _error = null;
      _recording = true;
      _seconds = 0;
      _file = null;
      _cover = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _seconds = t.tick);
      if (_seconds >= kVoiceMaxSeconds) _stop();
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _ampSub?.cancel();
    _ampSub = null;
    final path = await _recorder.stop();
    if (path == null || !await File(path).exists()) {
      if (mounted) setState(() => _recording = false);
      return;
    }
    if (mounted) {
      setState(() {
        _recording = false;
        _file = File(path);
        _recorded = true;
        _bars = _resample(_levels, _barCount);
      });
    }
  }

  /// Ramène les niveaux enregistrés à [n] barres (moyenne par tranche).
  static List<double> _resample(List<double> src, int n) {
    if (src.isEmpty) return List.filled(n, .3);
    return List.generate(n, (i) {
      final a = (i * src.length / n).floor();
      final b = math.max(a + 1, ((i + 1) * src.length / n).floor());
      final slice = src.sublist(a, math.min(b, src.length));
      return (slice.reduce((x, y) => x + y) / slice.length).clamp(.08, 1.0);
    });
  }

  /// Onde de remplacement (fichier importé) : motif régulier calculé à partir de la taille du fichier, toujours le même pour un même fichier.
  static List<double> _pattern(int seed, int n) {
    final r = math.Random(seed);
    return List.generate(n, (i) => (.25 + .75 * (math.sin(i / 3.2 + seed % 7).abs() * .6 + r.nextDouble() * .4)).clamp(.12, 1.0));
  }

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
    final path = r?.files.single.path;
    if (path == null) return;
    final size = r!.files.single.size;
    if (size > kVoiceMaxBytes) {
      setState(() => _error = context.tr('Fichier trop lourd (10 Mo au maximum).'));
      return;
    }
    // durée lue par le lecteur : un audio de plus de 3 minutes est refusé
    final probe = AudioPlayer();
    int secs = 0;
    try {
      await probe.setSourceDeviceFile(path);
      secs = (await probe.getDuration())?.inSeconds ?? 0;
    } catch (_) {}
    await probe.dispose();
    if (secs > kVoiceMaxSeconds) {
      setState(() => _error = context.tr('Audio trop long (3 minutes au maximum).'));
      return;
    }
    await _player.stop();
    setState(() {
      _error = null;
      _file = File(path);
      _seconds = secs;
      _recorded = false;
      _cover = null;
      _bars = _pattern(size, _barCount);
    });
  }

  Future<void> _togglePlay() async {
    if (_file == null) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(_file!.path));
    }
  }

  void _again() {
    _player.stop();
    setState(() {
      _file = null;
      _cover = null;
      _seconds = 0;
      _pos = Duration.zero;
      _bars = const [];
    });
  }

  /// Couper dans le son : le serveur garde seulement le passage choisi.
  Future<void> _trim() async {
    final f = _file;
    if (f == null || _busy) return;
    final total = _seconds * 1000;
    if (total < 2000) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Cet audio est trop court pour être coupé.'))));
      return;
    }
    await _player.pause();
    final picked = await showTrimSheet(context, totalMs: total, title: context.tr('Couper l\'audio'));
    if (!mounted || picked == null || (picked.start <= 0 && picked.end >= total - 50)) return;
    setState(() => _busy = true);
    try {
      final out = await StudioTrimApi.trim(f, isVideo: false, startMs: picked.start.round(), endMs: picked.end.round());
      if (!mounted) return;
      setState(() {
        _file = out;
        _seconds = ((picked.end - picked.start) / 1000).round();
        _pos = Duration.zero;
        _busy = false;
        _recorded = true; // coupé dans notre Studio : toujours « Fait sur Afrolook »
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      handleApiError(context, e, onRetry: _trim, fallback: context.tr('La découpe a échoué. Réessaie.'));
    }
  }

  Future<void> _pickCover() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1080, imageQuality: 85);
    if (x != null && mounted) setState(() => _cover = File(x.path));
  }

  String _mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hasFile = _file != null && !_recording;
    final barColor = c.isDark ? c.accent : c.accentText;
    final bars = _recording ? _liveBars() : (hasFile ? _bars : _idleBars());
    final progress = hasFile && _seconds > 0 ? (_pos.inMilliseconds / (_seconds * 1000)).clamp(0.0, 1.0) : 0.0;
    return PopScope(
      canPop: !hasFile,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && hasFile) _again(); // « ‹ » de « Ton audio » : on revient à l'enregistrement
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          foregroundColor: c.textPrimary,
          centerTitle: true,
          leading: hasFile
              ? IconButton(key: const ValueKey('voice_back'), icon: const Icon(Icons.chevron_left_rounded, size: 30), onPressed: _again)
              : IconButton(key: const ValueKey('voice_close'), icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
          title: Text(hasFile ? context.tr('Ton audio') : context.tr('Audio'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(children: [
              const Spacer(),
              GestureDetector(
                key: const ValueKey('voice_play'),
                behavior: HitTestBehavior.opaque,
                onTap: hasFile ? _togglePlay : null,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(height: 120, width: double.infinity, child: CustomPaint(painter: _WavePainter(bars, barColor, c.border, hasFile ? progress : -1))),
                  if (hasFile && !_playing)
                    Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle, color: c.surface.withValues(alpha: .92), border: Border.all(color: c.border)), child: Icon(Icons.play_arrow_rounded, color: c.textPrimary, size: 32)),
                ]),
              ),
              const SizedBox(height: 14),
              if (!hasFile)
                Text.rich(
                  key: const ValueKey('voice_timer'),
                  TextSpan(children: [
                    TextSpan(text: _mmss(_seconds), style: TextStyle(color: c.textPrimary, fontSize: 34, fontWeight: FontWeight.w800)),
                    TextSpan(text: ' / ${_mmss(kVoiceMaxSeconds)}', style: TextStyle(color: c.textSecondary, fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
                )
              else ...[
                ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress, minHeight: 5, color: barColor, backgroundColor: c.surfaceVariant)),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _Pill(key: const ValueKey('voice_trim'), label: context.tr('Couper'), selected: false, onTap: _busy ? null : _trim),
                  const SizedBox(width: 10),
                  _Pill(key: const ValueKey('voice_cover'), label: _cover == null ? context.tr('Pochette') : context.tr('Pochette ✓'), selected: _cover != null, onTap: _busy ? null : _pickCover),
                ]),
              ],
              const SizedBox(height: 26),
              if (!hasFile)
                GestureDetector(
                  key: const ValueKey('voice_rec'),
                  onTap: kIsWeb ? null : (_recording ? _stop : _start),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _recording ? 100 : 90,
                    height: _recording ? 100 : 90,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c.danger, boxShadow: [BoxShadow(color: c.danger.withValues(alpha: .35), blurRadius: 24)]),
                    child: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded, size: 42, color: Colors.white),
                  ),
                ),
              if (!hasFile && !_recording)
                Padding(padding: const EdgeInsets.only(top: 12), child: Text(context.tr('Appuie sur le micro et parle'), style: TextStyle(color: c.textSecondary, fontSize: 14))),
              if (_recording)
                Padding(padding: const EdgeInsets.only(top: 12), child: Text(context.tr('Je t\'écoute… (3 minutes au maximum)'), style: TextStyle(color: c.textSecondary, fontSize: 14))),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.danger, fontSize: 13)),
              ],
              const Spacer(),
              if (!hasFile && !_recording && !kIsWeb && widget.allowPick)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    key: const ValueKey('voice_pick'),
                    onPressed: _pick,
                    style: FilledButton.styleFrom(backgroundColor: c.surfaceVariant, foregroundColor: c.textPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(context.tr('Importer un fichier'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  ),
                ),
              if (hasFile)
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        key: const ValueKey('voice_again'),
                        onPressed: _busy ? null : _again,
                        style: FilledButton.styleFrom(backgroundColor: c.surfaceVariant, foregroundColor: c.textPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: Text(context.tr('Refaire'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        key: const ValueKey('voice_next'),
                        onPressed: _busy
                            ? null
                            : () async {
                                await _player.stop();
                                if (mounted) Navigator.of(context).pop(CreateVoiceResult(file: _file!, seconds: _seconds, recorded: _recorded, cover: _cover));
                              },
                        style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: _busy
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: c.onAccent))
                            : Text(context.tr('Suivant'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ),
                  ),
                ]),
            ]),
          ),
        ),
      ),
    );
  }

  /// Barres vivantes pendant l'enregistrement : les derniers niveaux du micro, de gauche à droite.
  List<double> _liveBars() {
    final tail = _levels.length > _barCount ? _levels.sublist(_levels.length - _barCount) : _levels;
    return [...List.filled(_barCount - tail.length, .06), ...tail.map((v) => math.max(.06, v))];
  }

  /// Onde au repos (rien d'enregistré) : motif calme, comme la proposition.
  List<double> _idleBars() => List.generate(_barCount, (i) => .18 + .5 * (math.sin(i / 2.4).abs()) * (1 - (i - _barCount / 2).abs() / (_barCount / 2) * .6));
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.bars, this.color, this.rest, this.progress);

  final List<double> bars;
  final Color color;
  final Color rest;

  /// 0 à 1 pendant la lecture (les barres déjà lues sont colorées) ; négatif = toutes colorées.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final n = bars.length;
    final slot = size.width / n;
    final w = math.min(6.0, slot * .55);
    for (var i = 0; i < n; i++) {
      final h = math.max(6.0, bars[i] * size.height);
      final x = slot * i + slot / 2;
      final played = progress < 0 || (i + .5) / n <= progress;
      final p = Paint()
        ..color = played ? color : rest
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, size.height / 2 - h / 2), Offset(x, size.height / 2 + h / 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.bars != bars || old.progress != progress || old.color != color;
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(color: selected ? c.accent : c.surfaceVariant, borderRadius: BorderRadius.circular(99), border: Border.all(color: selected ? c.accent : c.border)),
        child: Text(label, style: TextStyle(color: selected ? c.onAccent : c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
