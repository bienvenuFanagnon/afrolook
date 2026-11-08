import '../../widgets/reply_split.dart';
import '../../widgets/gold_badge.dart';
import '../../widgets/reply_banner.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/tr.dart';
import '../../services/api/studio_face_overlay_api.dart';
import '../../services/beauty.dart';
import '../../ads/gold_gate.dart';
import '../../providers/authProvider.dart';
import 'package:provider/provider.dart';
import '../../services/face_avatars.dart';
import '../studio/montage/montage_music.dart' show MontageMusic, MontageMusicPlayer;
import '../../services/face_engine.dart';
import '../../services/face_filters.dart';
import 'package:path_provider/path_provider.dart';
import 'beauty_sheet.dart';
import 'face_filter_page.dart';
import 'face_lab_page.dart';
import '../../theme/app_colors.dart';

/// Ce que la caméra rend : un fichier filmé ou photographié DANS l'application (origine « captured »), ou la demande d'ouvrir la galerie.
class CreateCaptureResult {
  const CreateCaptureResult.file(this.path, {required this.isVideo}) : openGallery = false;
  const CreateCaptureResult.gallery({required this.isVideo})
      : path = null,
        openGallery = true;

  final String? path;
  final bool isVideo;
  final bool openGallery;
}

/// Caméra d'Afrolook : vidéo (15, 30 ou 60 s) et photo dans le même écran, avec le style de l'application. Un seul toucher pour filmer, un second pour arrêter ;
/// la barre ronde montre le temps qui reste. Si la caméra n'est pas disponible (autorisation refusée, appareil sans caméra), on propose la caméra du téléphone.
class CreateCameraPage extends StatefulWidget {
  const CreateCameraPage({super.key, this.startOnPhoto = false, this.maxSeconds = 60, this.sound});

  final bool startOnPhoto;
  final int maxSeconds;

  /// Son à jouer pendant qu'on filme (« Créer avec ce son »).
  final MontageMusic? sound;

  @override
  State<CreateCameraPage> createState() => _CreateCameraPageState();
}

class _CreateCameraPageState extends State<CreateCameraPage> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  CameraController? _ctrl;
  int _camIndex = 0;
  bool _photoMode = false;
  bool _torch = false;

  // ── Moteur maison (Android, APK de test) : caméra, visage, beauté, masques et enregistrement par le moteur ──
  final bool _eng = FaceEngine.enabled;
  bool _engFront = true;
  final Set<String> _deforms = {}; // déformations du visage choisies (elles se combinent)
  int _look = 0; // look de couleur (0 = aucun)
  int _magic = -1; // effet magique choisi (index dans FaceEngine.magic), -1 = aucun
  String _gesture = 'mouth'; // geste qui déclenche l'effet magique
  String _group = 'none'; // groupe d'effets ouvert : face, color, mask, avatar, magic
  FaceAvatar? _avatar; // avatar choisi (copie les expressions)
  FaceSeg? _bg; // fond choisi (flou ou dégradé)
  FaceSeg? _hair; // couleur des cheveux
  FaceSeg? _cloth; // couleur des habits

  // ── Filtres de visage en direct (Android) ──
  FaceFilter _filter = FaceFilter.none;

  // Beauté : activée par défaut à un niveau naturel (le réglage est gardé tant que l'application reste ouverte)
  static BeautyLevel _savedBeauty = const BeautyLevel();
  static bool _savedBeautyOn = true;
  BeautyLevel _beauty = _savedBeauty;
  bool _beautyOn = _savedBeautyOn;
  BeautyLevel get _beautyNow => _beautyOn ? _beauty : const BeautyLevel.off();
  bool _streaming = false;
  bool _frameBusy = false;
  int _lastFrameMs = 0;
  Size? _liveSize;
  List<FaceBox> _liveFaces = const [];
  final List<FaceTrackPoint> _track = []; // trajectoire du filtre (ancre) pendant le tournage
  final List<FaceTrackPoint> _faceTrack = []; // trajectoire du centre du visage, pour adoucir la peau
  final Stopwatch _recWatch = Stopwatch();
  bool _moduleReady = false;
  bool _preparing = false; // téléchargement du module de visage en cours
  bool _prepFailed = false;
  String _prepState = 'PENDING';
  double? _prepValue;
  int _framesSeen = 0; // images reçues du flux (diagnostic des APK de test)
  String? _streamErr;
  String? _filterNote; // message affiché sur l'aperçu (préparation, visage non trouvé, erreur)
  int _detectFails = 0;
  double _trackSize = 0.3; // taille du filtre en fraction de la largeur de l'image
  bool _recording = false;
  bool _busy = false;
  String? _error;
  bool _denied = false;
  late int _limit = widget.maxSeconds.clamp(5, 60);
  int _elapsedMs = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _photoMode = widget.startOnPhoto;
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.sound != null) unawaited(MontageMusicPlayer.stop());
    _tick?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive && !_recording) {
      c.dispose();
      _ctrl = null;
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _ctrl == null && !_recording) {
      _start(_camIndex);
    }
  }

  Future<void> _init() async {
    try {
      final cam = await Permission.camera.request();
      final mic = await Permission.microphone.request();
      if (!cam.isGranted) {
        if (mounted) setState(() => _denied = true);
        return;
      }
      if (_eng) {
        _micOk = mic.isGranted;
        if (mounted) setState(() {});
        await _engSync();
        return;
      }
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _error = 'Aucune caméra trouvée sur cet appareil.');
        return;
      }
      _micOk = mic.isGranted;
      await _start(_cameras.indexWhere((d) => d.lensDirection == CameraLensDirection.front) >= 0 ? _frontOrZero() : 0);
    } catch (e) {
      if (mounted) setState(() => _error = 'La caméra n\'a pas pu démarrer.');
    }
  }

  bool _micOk = true;

  /// On commence par la caméra avant : on se filme d'abord.
  int _frontOrZero() {
    final i = _cameras.indexWhere((d) => d.lensDirection == CameraLensDirection.front);
    return i < 0 ? 0 : i;
  }

  Future<void> _start(int index) async {
    final old = _ctrl;
    _ctrl = null;
    await old?.dispose();
    final c = CameraController(_cameras[index], ResolutionPreset.high, enableAudio: _micOk, imageFormatGroup: FaceFilters.available ? ImageFormatGroup.nv21 : ImageFormatGroup.jpeg);
    try {
      await c.initialize();
      await c.setFlashMode(FlashMode.off);
      _torch = false;
    } catch (e) {
      await c.dispose();
      if (mounted) setState(() => _error = 'La caméra n\'a pas pu démarrer.');
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    _streaming = false;
    _liveFaces = const [];
    setState(() {
      _ctrl = c;
      _camIndex = index;
      _error = null;
    });
    _syncStream();
  }

  // ── Filtres en direct ────────────────────────────────────────────────────

  /// Moteur : envoie la beauté et le masque choisis (le moteur démarre avec la vue ; on réessaie un peu au début).
  Future<void> _engSync() async {
    for (var i = 0; i < 6; i++) {
      try {
        await FaceEngine.setBeauty(_beautyNow);
        await FaceEngine.setMask(_filter);
        await FaceEngine.setDeformations(_deforms);
        await FaceEngine.setLook(_look);
        await FaceEngine.setAvatar(_avatar);
        await FaceEngine.setSegment(background: _bg, hair: _hair, cloth: _cloth);
        await FaceEngine.setMagic(_magic < 0 ? null : FaceEngine.magic[_magic], _gesture);
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
  }

  /// Porte Gold d'une fonction : libre avec Gold ou une passe, sinon quelques pubs pour la journée (voir `GoldGate`).
  Future<bool> _gate(String key) => GoldGate.feature(context, context.read<UserAuthProvider>().loginUserData.id ?? '', key);

  Future<void> _pickMagic(int i) async {
    // effets d'argent (dollars, billets, pièces) : fonction à débloquer
    if (_magic != i && FaceEngine.magic[i].kind != 'icon' && !await _gate('money_gestures')) return;
    if (!mounted) return;
    setState(() => _magic = _magic == i ? -1 : i);
    try {
      await FaceEngine.setMagic(_magic < 0 ? null : FaceEngine.magic[_magic], _gesture);
    } catch (_) {}
  }

  Future<void> _pickGesture(String g) async {
    setState(() => _gesture = g);
    try {
      await FaceEngine.setMagic(_magic < 0 ? null : FaceEngine.magic[_magic], _gesture);
    } catch (_) {}
  }

  Future<void> _pickLook(int look) async {
    // tous les filtres couleur sont GRATUITS, néon, cinéma et pop compris
    if (!mounted) return;
    setState(() => _look = look);
    try {
      await FaceEngine.setLook(look);
    } catch (_) {}
  }

  Future<void> _pickSeg(String kind, FaceSeg? v) async {
    if (v != null) {
      final key = kind == 'hair' ? 'hair_color' : (kind == 'cloth' ? 'cloth_color' : (v.mode == 1 ? 'bg_blur' : 'bg_virtual'));
      if (!await _gate(key)) return;
      if (!mounted) return;
    }
    setState(() {
      switch (kind) {
        case 'bg':
          _bg = _bg?.label == v?.label ? null : v;
        case 'hair':
          _hair = _hair?.label == v?.label ? null : v;
        default:
          _cloth = _cloth?.label == v?.label ? null : v;
      }
    });
    try {
      await FaceEngine.setSegment(background: _bg, hair: _hair, cloth: _cloth);
    } catch (_) {}
  }

  Widget _swatchChip(String kind, FaceSeg v, FaceSeg? current, AppColors c, {bool background = false}) {
    final selected = current?.label == v.label;
    final fill = background && v.mode == 1
        ? const Color(0xFF8D99A6)
        : Color(v.color);
    final swatch = Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.4),
        gradient: background && v.mode == 2 ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(v.color), Color(v.color2)]) : null,
        color: background && v.mode == 2 ? null : fill,
      ),
      child: background && v.mode == 1 ? const Icon(Icons.blur_on_rounded, size: 12, color: Colors.white) : null,
    );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        key: ValueKey('${kind}_${v.label}'),
        avatar: swatch,
        label: Text(context.tr(v.label), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? c.onAccent : Colors.white)),
        selected: selected,
        showCheckmark: false,
        selectedColor: c.accent,
        backgroundColor: const Color(0x99000000),
        side: BorderSide.none,
        onSelected: _recording ? null : (_) => _pickSeg(kind, v),
      ),
    );
  }

  Future<void> _pickAvatar(FaceAvatar? a) async {
    if (a != null && _avatar?.key != a.key && !await _gate('avatars')) return;
    if (!mounted) return;
    setState(() => _avatar = _avatar?.key == a?.key ? null : a);
    try {
      await FaceEngine.setAvatar(_avatar);
    } catch (_) {}
  }

  Future<void> _toggleDeform(String key) async {
    if (!_deforms.contains(key) && !await _gate('face_deform')) return;
    if (!mounted) return;
    setState(() => _deforms.contains(key) ? _deforms.remove(key) : _deforms.add(key));
    try {
      await FaceEngine.setDeformations(_deforms);
    } catch (_) {}
  }

  Future<void> _applyPreset(FacePreset p, {bool free = false}) async {
    if (!free && !await _gate('face_deform')) return;
    if (!mounted) return;
    final same = _deforms.length == p.keys.length && _deforms.containsAll(p.keys);
    setState(() {
      _deforms.clear();
      if (!same) _deforms.addAll(p.keys);
    });
    try {
      await FaceEngine.setDeformations(_deforms);
    } catch (_) {}
  }

  void _toggleBeauty() {
    setState(() => _beautyOn = !_beautyOn);
    _savedBeautyOn = _beautyOn;
    _syncStream();
  }

  Future<void> _openBeauty() async {
    final r = await showBeautySheet(context, _beauty, onChanged: (b) => setState(() {
          _beauty = b;
          _beautyOn = true;
        }));
    if (!mounted) return;
    setState(() {
      if (r != null) {
        _beauty = r;
        _beautyOn = true;
      }
    });
    _savedBeauty = _beauty;
    _savedBeautyOn = _beautyOn;
    _syncStream();
  }

  Future<void> _pickFilter(FaceFilter f) async {
    if (_eng) {
      setState(() => _filter = f);
      try {
        await FaceEngine.setMask(f);
      } catch (_) {}
      return;
    }
    setState(() {
      _filter = f;
      _filterNote = null;
      _detectFails = 0;
      if (f == FaceFilter.none) _liveFaces = const [];
    });
    if (f != FaceFilter.none && !_moduleReady) {
      // première utilisation : le téléphone télécharge le module de visage (Google Play) ; la progression est affichée
      await _prepareModule();
      if (!mounted) return;
      if (!_moduleReady) {
        setState(() {
          _filterNote = context.tr('Le filtre n\'est pas disponible sur ce téléphone pour le moment. Vérifie ta connexion puis réessaie.');
          _filter = FaceFilter.none;
        });
        return;
      }
    }
    await _syncStream();
  }

  /// Prépare le module de visage de Google Play (téléchargement la première fois) en montrant « Préparation du studio » et la progression.
  Future<void> _prepareModule() async {
    if (_preparing) {
      while (_preparing && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      return;
    }
    setState(() {
      _preparing = true;
      _prepFailed = false;
      _prepState = 'PENDING';
      _prepValue = null;
    });
    final ok = await FaceFilters.ensureReady(onProgress: (state, p) {
      if (mounted) setState(() {
        _prepState = state;
        _prepValue = p;
      });
    });
    _moduleReady = ok;
    if (mounted) setState(() {
      _preparing = false;
      _prepFailed = !ok;
    });
  }

  /// Carte « Préparation du studio » : visible tant que le module de visage se télécharge (avec le pourcentage), puis message et bouton Réessayer si ça échoue.
  Widget _prepCard(AppColors c) {
    final pct = _prepValue == null ? null : (_prepValue! * 100).round();
    final detail = _prepFailed
        ? context.tr('Le module de visage n\'a pas pu être téléchargé. Vérifie ta connexion.')
        : switch (_prepState) {
            'DOWNLOADING' => pct == null ? context.tr('Téléchargement du module de visage…') : context.tr('Téléchargement du module de visage : {p} %', {'p': '$pct'}),
            'INSTALLING' => context.tr('Installation du module de visage…'),
            'PAUSED' => context.tr('Téléchargement en pause (connexion ?)'),
            _ => context.tr('Vérification du module de visage…'),
          };
    return Positioned(
      left: 24,
      right: 24,
      top: 200,
      child: Container(
        key: const ValueKey('studio_prep'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xDD15171A), borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.tr('Préparation du studio'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (!_prepFailed) LinearProgressIndicator(value: _prepValue, minHeight: 6, color: c.accent, backgroundColor: Colors.white24),
          const SizedBox(height: 10),
          Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (_prepFailed) ...[
            const SizedBox(height: 10),
            FilledButton(key: const ValueKey('studio_prep_retry'), onPressed: _prepareModule, style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent), child: Text(context.tr('Réessayer'))),
          ],
        ]),
      ),
    );
  }

  /// Lit les images de la caméra seulement si un filtre est choisi ou si la peau doit être adoucie (sinon aucun coût).
  bool get _needsStream => _filter != FaceFilter.none || (_beautyNow.smooth > 0 && FaceFilters.available);

  Future<void> _syncStream() async {
    if (_eng) {
      try {
        await FaceEngine.setBeauty(_beautyNow);
      } catch (_) {}
      return;
    }
    final c = _ctrl;
    if (c == null || !c.value.isInitialized || !FaceFilters.available) return;
    try {
      if (_needsStream && !_moduleReady) await _prepareModule();
      if (!mounted) return;
      if (_needsStream && _moduleReady && !_streaming) {
        _streaming = true;
        await c.startImageStream(_onFrame);
      } else if (!_needsStream && _streaming && !_recording) {
        _streaming = false;
        await c.stopImageStream();
      }
    } catch (e) {
      _streaming = false;
      _streamErr = '$e';
    }
  }

  Future<void> _onFrame(CameraImage img) async {
    _framesSeen++;
    // le diagnostic (APK de test) se rafraîchit même quand la détection échoue ou ne trouve rien
    if (_framesSeen % 5 == 0 && mounted) setState(() {});
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_frameBusy || now - _lastFrameMs < 140 || !mounted) return;
    _frameBusy = true;
    _lastFrameMs = now;
    try {
      final r = await FaceFilters.detectFrame(img, _cameras[_camIndex].sensorOrientation);
      if (!mounted) return;
      if (r == null) {
        // la détection échoue : après quelques essais on le dit au lieu de rester muet
        if (++_detectFails == 6 && _filter != FaceFilter.none) setState(() => _filterNote = context.tr('Le filtre ne peut pas suivre ton visage : {err}', {'err': FaceFilters.lastError ?? '?'}));
        return;
      }
      _detectFails = 0;
      setState(() {
        _liveSize = r.size;
        _liveFaces = r.faces;
        _filterNote = _filter != FaceFilter.none && r.faces.isEmpty ? context.tr('Place ton visage devant la caméra') : null;
      });
      if (_recording) {
        // seul le plus grand visage est suivi dans la vidéo
        final main = r.faces.isEmpty ? null : (r.faces.toList()..sort((a, b) => (b.rect.width * b.rect.height).compareTo(a.rect.width * a.rect.height))).first;
        final a = main == null ? null : FaceFilters.anchor(main, _filter);
        _faceTrack.add(FaceTrackPoint(_recWatch.elapsedMilliseconds, main == null ? null : (main.rect.center.dx / r.size.width).clamp(-0.4, 1.4), main == null ? null : (main.rect.center.dy / r.size.height).clamp(-0.4, 1.4)));
        _track.add(FaceTrackPoint(_recWatch.elapsedMilliseconds, a == null ? null : (a.center.dx / r.size.width).clamp(-0.4, 1.4), a == null ? null : (a.center.dy / r.size.height).clamp(-0.4, 1.4)));
        if (a != null) _trackSize = a.size / r.size.width;
      }
    } finally {
      _frameBusy = false;
    }
  }

  Future<void> _flip() async {
    if (_eng) {
      if (_recording || _busy) return;
      HapticFeedback.selectionClick();
      setState(() => _engFront = !_engFront);
      try {
        await FaceEngine.setFront(_engFront);
      } catch (_) {}
      return;
    }
    if (_cameras.length < 2 || _recording || _busy) return;
    HapticFeedback.selectionClick();
    await _start((_camIndex + 1) % _cameras.length);
  }

  Future<void> _toggleTorch() async {
    final c = _ctrl;
    if (c == null) return;
    try {
      _torch = !_torch;
      await c.setFlashMode(_torch ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } catch (_) {
      _torch = false;
    }
  }

  Future<String> _engTmp(String ext) async => '${(await getTemporaryDirectory()).path}/afrolook_${DateTime.now().millisecondsSinceEpoch}.$ext';

  Future<void> _shutter() async {
    if (_eng) {
      if (_busy) return;
      if (_photoMode) {
        setState(() => _busy = true);
        try {
          HapticFeedback.mediumImpact();
          final out = await FaceEngine.takePhoto(await _engTmp('jpg'));
          if (mounted && out != null) Navigator.pop(context, CreateCaptureResult.file(out, isVideo: false));
          if (mounted && out == null) setState(() => _busy = false);
        } catch (_) {
          if (mounted) setState(() => _busy = false);
        }
        return;
      }
      _recording ? await _stopRecording() : await _startRecording();
      return;
    }
    final c = _ctrl;
    if (c == null || !c.value.isInitialized || _busy) return;
    if (_photoMode) {
      setState(() => _busy = true);
      try {
        HapticFeedback.mediumImpact();
        final f = await c.takePicture();
        var path = f.path;
        // Android : aperçu de la photo avec les filtres de visage AVANT de la garder (si la détection échoue, on garde la photo telle quelle)
        final det = await FaceFilters.detect(path);
        if (det != null && mounted) {
          final chosen = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => FaceFilterPage(path: det.path, size: det.size, faces: det.faces, initial: _filter, initialBeauty: _beautyNow)));
          if (!mounted) return;
          if (chosen == null) {
            setState(() => _busy = false); // « Reprendre » : retour à la caméra
            return;
          }
          path = chosen;
        }
        if (mounted) Navigator.pop(context, CreateCaptureResult.file(path, isVideo: false));
      } catch (_) {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    _recording ? await _stopRecording() : await _startRecording();
  }

  Future<void> _startRecording() async {
    final c = _ctrl;
    if (c == null && !_eng) return;
    try {
      HapticFeedback.mediumImpact();
      _track.clear();
      _faceTrack.clear();
      _recWatch
        ..reset()
        ..start();
      if (widget.sound != null) await MontageMusicPlayer.play(widget.sound!);   // le son joue pendant le tournage (casque conseillé)
      if (_eng) {
        await FaceEngine.startRecording(await _engTmp('mp4'), audio: _micOk);
      } else {
        await c!.startVideoRecording();
      }
      _elapsedMs = 0;
      _tick = Timer.periodic(const Duration(milliseconds: 100), (t) {
        _elapsedMs += 100;
        if (_elapsedMs >= _limit * 1000) {
          t.cancel();
          _stopRecording();
        } else if (mounted) {
          setState(() {});
        }
      });
      setState(() => _recording = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'L\'enregistrement n\'a pas pu démarrer.');
    }
  }

  Future<void> _stopRecording() async {
    final c = _ctrl;
    _tick?.cancel();
    if (widget.sound != null) unawaited(MontageMusicPlayer.stop());
    if ((c == null && !_eng) || !_recording) return;
    setState(() {
      _recording = false;
      _busy = true;
    });
    try {
      if (_eng) {
        final out = await FaceEngine.stopRecording();
        _recWatch.stop();
        if (!mounted) return;
        if (_elapsedMs < 1000 || out == null) {
          setState(() => _busy = false);
          return;
        }
        Navigator.pop(context, CreateCaptureResult.file(out, isVideo: true));
        return;
      }
      final f = await c!.stopVideoRecording();
      _recWatch.stop();
      if (!mounted) return;
      // un clip de moins d'une seconde n'a pas de sens : on recommence
      if (_elapsedMs < 1000) {
        setState(() => _busy = false);
        return;
      }
      var path = f.path;
      // beauté : couleurs et peau adoucie (le serveur suit le visage noté pendant le tournage) ; en cas d'échec la vidéo est gardée telle quelle
      if (!_beautyNow.isOff) {
        path = await _burnBeauty(path);
        if (!mounted) return;
      }
      // filtre de visage choisi : le serveur le pose sur la trajectoire du visage ; en cas d'échec la vidéo est gardée telle quelle
      if (_filter != FaceFilter.none && _track.any((p) => p.x != null)) {
        path = await _burnFilter(path);
        if (!mounted) return;
      }
      Navigator.pop(context, CreateCaptureResult.file(path, isVideo: true));
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _burnBeauty(String path) async {
    try {
      final out = await StudioBeautyApi.apply(File(path), _beautyNow, List.of(_faceTrack));
      return out.path;
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('La beauté n\'a pas pu être appliquée : vidéo gardée telle quelle.'))));
      return path;
    }
  }

  Future<String> _burnFilter(String path) async {
    try {
      final probe = VideoPlayerController.file(File(path));
      await probe.initialize();
      final videoW = probe.value.size.width;
      await probe.dispose();
      // visage flouté : le serveur floute la zone suivie ; sinon il pose le dessin du filtre
      if (FaceFilters.isBlur(_filter)) {
        final out = await StudioBeautyApi.apply(File(path), const BeautyLevel.off(), List.of(_faceTrack), coverBlurSize: _trackSize.clamp(.15, .9));
        return out.path;
      }
      final png = await FaceFilters.filterPng(_filter, (_trackSize * videoW).round());
      final out = await StudioFaceOverlayApi.apply(File(path), png, List.of(_track));
      return out.path;
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Le filtre n\'a pas pu être posé : vidéo gardée sans filtre.'))));
      return path;
    }
  }

  /// Repli : la caméra du téléphone (autorisation refusée, appareil particulier).
  Future<void> _systemCamera() async {
    final picker = ImagePicker();
    if (_photoMode) {
      final x = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 92);
      if (x != null && mounted) Navigator.pop(context, CreateCaptureResult.file(x.path, isVideo: false));
    } else {
      final x = await picker.pickVideo(source: ImageSource.camera, maxDuration: Duration(seconds: _limit));
      if (x != null && mounted) Navigator.pop(context, CreateCaptureResult.file(x.path, isVideo: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.dark;
    return Scaffold(
      backgroundColor: Colors.black,
      body: _denied || _error != null ? _fallback(c) : _camera(c),
    );
  }

  Widget _fallback(AppColors c) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.videocam_off_rounded, size: 56, color: c.textSecondary),
          const SizedBox(height: 14),
          Text(_denied ? context.tr('Autorise la caméra pour te filmer') : context.tr(_error ?? ''), textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(context.tr('Tu peux aussi utiliser la caméra de ton téléphone.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          if (_denied) FilledButton(onPressed: openAppSettings, child: Text(context.tr('Ouvrir les réglages'))),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _systemCamera, child: Text(context.tr('Caméra du téléphone'))),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Retour'))),
        ]),
      ),
    );
  }

  /// Réponse à une vidéo : l'aperçu devient deux vidéos (celle d'origine et la caméra) selon la disposition choisie.
  Widget _splitWrap(Widget cam) => ValueListenableBuilder<String?>(
        valueListenable: ReplyLayout.id,
        builder: (context, id, _) => ValueListenableBuilder<bool>(
          valueListenable: ReplyLayout.swap,
          builder: (context, swap, _) {
            final url = ReplyBanner.info.value?.videoUrl;
            if (id == null || url == null || widget.startOnPhoto) return cam;
            return ReplySplitPreview(key: ValueKey('split_$url'), camera: cam, videoUrl: url, layout: id, swap: swap, recording: _recording);
          },
        ),
      );

  /// Choix de la disposition de la réponse (seulement pour répondre à une vidéo, hors enregistrement).
  Widget _layoutChips() => ValueListenableBuilder<ReplyInfo?>(
        valueListenable: ReplyBanner.info,
        builder: (context, info, _) {
          if (info?.videoUrl == null || _recording || widget.startOnPhoto) return const SizedBox.shrink();
          return ValueListenableBuilder<String?>(
            valueListenable: ReplyLayout.id,
            builder: (context, id, _) => SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), children: [
                for (final e in [(null, context.tr('Plein écran')), ('tb', context.tr('Haut / bas')), ('sbs', context.tr('Côte à côte')), ('bar', context.tr('Bandeau'))])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(key: ValueKey('reply_layout_${e.$1 ?? 'full'}'), label: Text(e.$2), selected: id == e.$1, onSelected: (_) => ReplyLayout.id.value = e.$1),
                  ),
                if (id != null)
                  ActionChip(key: const ValueKey('reply_layout_swap'), avatar: const Icon(Icons.swap_vert_rounded, size: 18), label: Text(context.tr('Inverser')), onPressed: () => ReplyLayout.swap.value = !ReplyLayout.swap.value),
              ]),
            ),
          );
        },
      );

  Widget _camera(AppColors c) {
    final ctrl = _ctrl;
    final ready = _eng || (ctrl != null && ctrl.value.isInitialized);
    final remaining = ((_limit * 1000 - _elapsedMs) / 1000).ceil().clamp(0, _limit);
    return Stack(fit: StackFit.expand, children: [
      Positioned.fill(
        child: _splitWrap(
          _eng
              ? FaceEngine.view(front: _engFront)
              : ready
                  ? ClipRect(
                      child: Transform.scale(
                        scale: _coverScale(ctrl!),
                        child: Center(child: _beautyNow.hasColor ? ColorFiltered(colorFilter: _beautyNow.colorFilter, child: CameraPreview(ctrl, child: _liveOverlay(ctrl))) : CameraPreview(ctrl, child: _liveOverlay(ctrl))),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ),
      // dégradés haut et bas : les boutons restent lisibles sur n'importe quelle image
      const Positioned(top: 0, left: 0, right: 0, height: 130, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xAA000000), Color(0x00000000)])))),
      const Positioned(bottom: 0, left: 0, right: 0, height: 260, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xCC000000), Color(0x00000000)])))),
      if (_filterNote != null) _filterBanner(),
      if (_preparing || _prepFailed) _prepCard(c),
      if (const bool.fromEnvironment('TEST_BUILD') && FaceFilters.available && !_eng) _diagnostic(),
      SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(children: [
              _round(Icons.close_rounded, () => Navigator.pop(context)),
              const Spacer(),
              if (_recording)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle)),
                    const SizedBox(width: 7),
                    Text('0:${remaining.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  ]),
                ),
              const Spacer(),
              // laboratoire du moteur maison (APK de test seulement)
              if (FaceLabPage.available && FaceFilters.available)
                _round(Icons.science_rounded, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FaceLabPage()))),
              if (FaceLabPage.available && FaceFilters.available) const SizedBox(width: 8),
              if (!_eng) _round(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded, _toggleTorch, active: _torch),
              if (!_eng) const SizedBox(width: 8),
              _round(Icons.cameraswitch_rounded, _flip),
            ]),
          ),
          // réponse en vidéo : on rappelle à quelle publication on répond
          const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: Align(alignment: Alignment.centerLeft, child: ReplyBanner())),
          _layoutChips(),
          const Spacer(),
          if (_eng)
            (_busy ? const SizedBox.shrink() : _engineRail(c))
          else if (FaceFilters.available && !_busy)
            SizedBox(
              key: const ValueKey('face_filters'),
              height: 46,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onLongPress: _recording ? null : _openBeauty,
                    child: ChoiceChip(
                      key: const ValueKey('beauty_chip'),
                      label: Text(context.tr('✨ Beauté'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _beautyOn ? c.onAccent : Colors.white)),
                      selected: _beautyOn,
                      selectedColor: c.accent,
                      backgroundColor: const Color(0x99000000),
                      side: BorderSide.none,
                      onSelected: _recording ? null : (_) => _toggleBeauty(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    key: const ValueKey('beauty_tune'),
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(backgroundColor: const Color(0x99000000)),
                    onPressed: _recording ? null : _openBeauty,
                    icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                  ),
                ),
                for (final f in FaceFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey('live_${f.name}'),
                      label: Text(f == FaceFilter.none ? context.tr('Sans filtre') : FaceFilters.emoji(f), style: TextStyle(fontSize: f == FaceFilter.none ? 13 : 20, fontWeight: FontWeight.w700, color: _filter == f ? c.onAccent : Colors.white)),
                      selected: _filter == f,
                      selectedColor: c.accent,
                      backgroundColor: const Color(0x99000000),
                      side: BorderSide.none,
                      onSelected: _recording ? null : (_) => _pickFilter(f),
                    ),
                  ),
              ]),
            ),
          if (!_photoMode && !_recording)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final s in const [15, 30, 60])
                  if (s <= widget.maxSeconds) _chip('$s s', _limit == s, () => setState(() => _limit = s)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Galerie : possible, mais limitée à 2 médias par jour ; filmer ou se photographier ici n'a pas de limite
              GestureDetector(
                onTap: _recording ? null : () => Navigator.pop(context, CreateCaptureResult.gallery(isVideo: !_photoMode)),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2), color: const Color(0x55FFFFFF)),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 22),
                ),
              ),
              _shutterButton(c),
              const SizedBox(width: 46),
            ]),
          ),
          if (!_recording)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _mode(context.tr('VIDÉO'), !_photoMode, () => setState(() => _photoMode = false)),
                const SizedBox(width: 26),
                _mode(context.tr('PHOTO'), _photoMode, () => setState(() => _photoMode = true)),
              ]),
            )
          else
            const SizedBox(height: 14),
        ]),
      ),
      // après l'enregistrement : le traitement (fin du fichier, beauté, filtre) peut durer quelques secondes ; on le dit au lieu de laisser une image figée
      if (_busy && !_recording) _busyOverlay(),
    ]);
  }

  Widget _busyOverlay() => Positioned.fill(
        key: const ValueKey('camera_busy'),
        child: ColoredBox(
          color: const Color(0x99000000),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 38, height: 38, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
              const SizedBox(height: 14),
              Text(context.tr('Préparation de ta vidéo…'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
            ]),
          ),
        ),
      );

  // ── Barre du moteur : cinq groupes (Beauté, Visage, Couleur, Masques, Magie), chacun avec ses propres choix ──

  Widget _engChip({required Key key, required IconData icon, required String label, required bool selected, required VoidCallback? onTap, required AppColors c, String? gold}) {
    final lockedGold = GoldBadge.locked(gold);   // option réservée à Gold et encore fermée : pastille GOLD, un toucher propose Gold ou des pubs
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        key: key,
        avatar: Icon(icon, size: 18, color: selected ? c.onAccent : Colors.white),
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(context.tr(label), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? c.onAccent : Colors.white)),
          if (lockedGold) ...[const SizedBox(width: 6), const GoldBadge(compact: true)],
        ]),
        selected: selected,
        showCheckmark: false,
        selectedColor: c.accent,
        backgroundColor: const Color(0x99000000),
        side: BorderSide.none,
        onSelected: onTap == null ? null : (_) => onTap(),
      ),
    );
  }

  Widget _engineRail(AppColors c) {
    final off = _recording;
    Widget group(String key, IconData icon, String label, bool active) => _engChip(
          key: ValueKey('group_$key'),
          icon: icon,
          label: label,
          selected: _group == key || active,
          onTap: off ? null : () => setState(() => _group = _group == key ? 'none' : key),
          c: c,
        );
    final items = <Widget>[];
    switch (_group) {
      case 'face':
        for (var i = 0; i < FaceEngine.presets.length; i++) {
          final p = FaceEngine.presets[i];
          final free = i < FaceEngine.freePresets;   // les deux premiers sont gratuits, les autres affichent GOLD et ouvrent le choix pubs / Gold
          items.add(_engChip(key: ValueKey('preset_${p.label}'), icon: p.icon, label: p.label, selected: _deforms.length == p.keys.length && _deforms.containsAll(p.keys), onTap: off ? null : () => _applyPreset(p, free: free), c: c, gold: free ? null : 'face_deform'));
        }
        items.add(const Padding(padding: EdgeInsets.only(right: 8), child: SizedBox(height: 28, child: VerticalDivider(color: Colors.white38, width: 1))));
        for (final d in FaceEngine.deformations) {
          items.add(_engChip(key: ValueKey('deform_${d.key}'), icon: d.icon, label: d.label, selected: _deforms.contains(d.key), onTap: off ? null : () => _toggleDeform(d.key), c: c, gold: 'face_deform'));
        }
      case 'color':
        items.add(_engChip(key: const ValueKey('look_0'), icon: Icons.block_rounded, label: 'Aucun', selected: _look == 0, onTap: off ? null : () => _pickLook(0), c: c));
        for (final l in FaceEngine.looks) {
          items.add(_engChip(key: ValueKey('look_${l.id}'), icon: l.icon, label: l.label, selected: _look == l.id, onTap: off ? null : () => _pickLook(_look == l.id ? 0 : l.id), c: c));
        }
      case 'mask':
        items.add(_engChip(key: const ValueKey('mask_none'), icon: Icons.block_rounded, label: 'Aucun', selected: _filter == FaceFilter.none, onTap: off ? null : () => _pickFilter(FaceFilter.none), c: c));
        for (final f in FaceFilter.values) {
          if (f == FaceFilter.none || f == FaceFilter.blur) continue;
          items.add(_engChip(key: ValueKey('mask_${f.name}'), icon: FaceEngine.maskIcon(f), label: FaceEngine.maskLabel(f), selected: _filter == f, onTap: off ? null : () => _pickFilter(_filter == f ? FaceFilter.none : f), c: c));
        }
      case 'bg':
        items.add(_engChip(key: const ValueKey('bg_none'), icon: Icons.block_rounded, label: 'Aucun', selected: _bg == null, onTap: off ? null : () => _pickSeg('bg', _bg), c: c));
        for (final v in FaceEngine.backgrounds) {
          items.add(_swatchChip('bg', v, _bg, c, background: true));
        }
      case 'hair':
        items.add(_engChip(key: const ValueKey('hair_none'), icon: Icons.block_rounded, label: 'Aucune', selected: _hair == null, onTap: off ? null : () => _pickSeg('hair', _hair), c: c));
        for (final v in FaceEngine.hairColors) {
          items.add(_swatchChip('hair', v, _hair, c));
        }
      case 'cloth':
        items.add(_engChip(key: const ValueKey('cloth_none'), icon: Icons.block_rounded, label: 'Aucune', selected: _cloth == null, onTap: off ? null : () => _pickSeg('cloth', _cloth), c: c));
        for (final v in FaceEngine.clothColors) {
          items.add(_swatchChip('cloth', v, _cloth, c));
        }
      case 'avatar':
        items.add(_engChip(key: const ValueKey('avatar_none'), icon: Icons.block_rounded, label: 'Aucun', selected: _avatar == null, onTap: off ? null : () => _pickAvatar(null), c: c));
        for (final av in FaceAvatar.all) {
          items.add(_engChip(key: ValueKey('avatar_${av.key}'), icon: av.icon, label: av.label, selected: _avatar?.key == av.key, onTap: off ? null : () => _pickAvatar(av), c: c, gold: 'avatars'));
        }
      case 'magic':
        items.add(_engChip(key: const ValueKey('magic_none'), icon: Icons.block_rounded, label: 'Aucun', selected: _magic < 0, onTap: off ? null : () => _pickMagic(_magic < 0 ? 0 : _magic), c: c));
        for (var m = 0; m < FaceEngine.magic.length; m++) {
          final mg = FaceEngine.magic[m];
          items.add(_engChip(key: ValueKey('magic_$m'), icon: mg.icon, label: mg.label, selected: _magic == m, onTap: off ? null : () => _pickMagic(m), c: c, gold: mg.kind != 'icon' ? 'money_gestures' : null));
        }
    }
    final gesture = FaceEngine.gestures.firstWhere((g) => g.key == _gesture);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // un effet magique est choisi : on dit quel geste le déclenche, et on peut en changer
      if (_magic >= 0)
        Container(
          key: const ValueKey('gesture_hint'),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(gesture.icon, color: c.accent, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text('${context.tr('Pour déclencher')} ${context.tr(FaceEngine.magic[_magic].label).toLowerCase()} : ${context.tr(gesture.instruction)}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700))),
            ]),
            if (_group == 'magic') ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final g in FaceEngine.gestures)
                    _engChip(key: ValueKey('gesture_${g.key}'), icon: g.icon, label: g.label, selected: _gesture == g.key, onTap: off ? null : () => _pickGesture(g.key), c: c),
                ]),
              ),
            ],
          ]),
        ),
      if (items.isNotEmpty) SizedBox(key: const ValueKey('engine_items'), height: 46, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: items)),
      if (items.isNotEmpty) const SizedBox(height: 6),
      SizedBox(
        key: const ValueKey('face_filters'),
        height: 46,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onLongPress: off ? null : _openBeauty,
              child: ChoiceChip(
                key: const ValueKey('beauty_chip'),
                avatar: Icon(Icons.auto_awesome_rounded, size: 18, color: _beautyOn ? c.onAccent : Colors.white),
                label: Text(context.tr('Beauté'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _beautyOn ? c.onAccent : Colors.white)),
                selected: _beautyOn,
                showCheckmark: false,
                selectedColor: c.accent,
                backgroundColor: const Color(0x99000000),
                side: BorderSide.none,
                onSelected: off ? null : (_) => _toggleBeauty(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              key: const ValueKey('beauty_tune'),
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: const Color(0x99000000)),
              onPressed: off ? null : _openBeauty,
              icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
            ),
          ),
          group('face', Icons.face_retouching_natural_rounded, 'Visage', _deforms.isNotEmpty),
          group('color', Icons.palette_rounded, 'Couleur', _look != 0),
          group('mask', Icons.masks_rounded, 'Masques', _filter != FaceFilter.none),
          group('bg', Icons.wallpaper_rounded, 'Fond', _bg != null),
          group('hair', Icons.face_3_rounded, 'Cheveux', _hair != null),
          group('cloth', Icons.checkroom_rounded, 'Habits', _cloth != null),
          group('avatar', Icons.theater_comedy_rounded, 'Avatars', _avatar != null),
          group('magic', Icons.auto_fix_high_rounded, 'Magie', _magic >= 0),
        ]),
      ),
    ]);
  }

  /// Diagnostic des filtres (APK de test seulement) : dit à quelle étape le suivi du visage s'arrête.
  Widget _diagnostic() {
    final txt = 'flux ${_streaming ? 'démarré' : 'arrêté'} · module ${_moduleReady ? 'prêt' : 'absent'} · images $_framesSeen · visages ${_liveFaces.length}'
        '${_liveSize != null ? ' · taille ${_liveSize!.width.toInt()}×${_liveSize!.height.toInt()}' : ''}'
        '${_streamErr != null ? '\nflux : $_streamErr' : ''}${FaceFilters.lastError != null ? '\ndétection : ${FaceFilters.lastError}' : ''}';
    return Positioned(
      left: 8,
      right: 8,
      bottom: 300,
      child: IgnorePointer(child: Text(txt, textAlign: TextAlign.center, style: const TextStyle(color: Colors.yellowAccent, fontSize: 11, fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black, blurRadius: 3)]))),
    );
  }

  /// Petit message sur l'aperçu quand un filtre est choisi (préparation, visage non trouvé, erreur).
  Widget _filterBanner() {
    return Positioned(
      top: 70,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: Center(
          child: Container(
            key: const ValueKey('filter_note'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(99)),
            child: Text(_filterNote!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  /// Le filtre posé en direct sur l'aperçu (dans le même cadre que l'image, donc au bon endroit) ; la caméra avant est affichée en miroir.
  Widget? _liveOverlay(CameraController ctrl) {
    final s = _liveSize;
    if (_filter == FaceFilter.none || s == null || _liveFaces.isEmpty) return null;
    final front = _cameras[_camIndex].lensDirection == CameraLensDirection.front;
    final faces = [for (final f in _liveFaces) front ? f.mirrored(s.width) : f];
    if (FaceFilters.isBlur(_filter)) {
      // visage flouté en direct : le flou est appliqué sur la zone du visage, dans le même cadre que l'image
      return IgnorePointer(
        child: LayoutBuilder(builder: (context, box) {
          final k = box.maxWidth / s.width;
          return Stack(children: [
            for (final f in faces)
              Positioned(
                left: (f.rect.center.dx - f.rect.width * .575) * k,
                top: (f.rect.center.dy - f.rect.height * .6) * k,
                width: f.rect.width * 1.15 * k,
                height: f.rect.height * 1.2 * k,
                child: ClipOval(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: f.rect.width * .07 * k, sigmaY: f.rect.width * .07 * k, tileMode: TileMode.clamp), child: const SizedBox.expand())),
              ),
          ]);
        }),
      );
    }
    return IgnorePointer(child: CustomPaint(painter: _LivePainter(_liveFaces, s, _filter, front)));
  }

  double _coverScale(CameraController ctrl) {
    final size = MediaQuery.sizeOf(context);
    var scale = size.aspectRatio * ctrl.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return scale;
  }

  Widget _round(IconData icon, VoidCallback onTap, {bool active = false}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: active ? const Color(0xFFFFD400) : const Color(0x66000000), shape: BoxShape.circle),
          child: Icon(icon, color: active ? const Color(0xFF121212) : Colors.white, size: 22),
        ),
      );

  Widget _chip(String t, bool on, VoidCallback tap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: tap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: on ? const Color(0xFFFFD400) : const Color(0x66000000), borderRadius: BorderRadius.circular(99)),
            child: Text(t, style: TextStyle(color: on ? const Color(0xFF121212) : Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
        ),
      );

  Widget _mode(String t, bool on, VoidCallback tap) => GestureDetector(
        onTap: tap,
        child: Text(t, style: TextStyle(color: on ? const Color(0xFFFFD400) : Colors.white70, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
      );

  Widget _shutterButton(AppColors c) {
    final progress = _recording ? (_elapsedMs / (_limit * 1000)).clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      key: const ValueKey('shutter'),
      onTap: _shutter,
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 84,
            height: 84,
            child: CircularProgressIndicator(value: _recording ? progress : 1, strokeWidth: 5, color: _recording ? const Color(0xFFFFD400) : Colors.white, backgroundColor: const Color(0x44FFFFFF)),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _recording ? 34 : 64,
            height: _recording ? 34 : 64,
            decoration: BoxDecoration(color: _photoMode ? Colors.white : c.danger, borderRadius: BorderRadius.circular(_recording ? 9 : 40)),
          ),
        ]),
      ),
    );
  }
}


class _LivePainter extends CustomPainter {
  _LivePainter(this.faces, this.imageSize, this.filter, this.mirror);
  final List<FaceBox> faces;
  final Size imageSize;
  final FaceFilter filter;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / imageSize.width, size.height / imageSize.height);
    for (final f in faces) {
      FaceFilters.drawOn(canvas, mirror ? f.mirrored(imageSize.width) : f, filter);
    }
  }

  @override
  bool shouldRepaint(_LivePainter old) => true;
}
