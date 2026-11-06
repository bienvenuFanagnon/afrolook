import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/tr.dart';
import '../../services/api/studio_face_overlay_api.dart';
import '../../services/face_filters.dart';
import 'face_filter_page.dart';
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
  const CreateCameraPage({super.key, this.startOnPhoto = false, this.maxSeconds = 60});

  final bool startOnPhoto;
  final int maxSeconds;

  @override
  State<CreateCameraPage> createState() => _CreateCameraPageState();
}

class _CreateCameraPageState extends State<CreateCameraPage> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  CameraController? _ctrl;
  int _camIndex = 0;
  bool _photoMode = false;
  bool _torch = false;

  // ── Filtres de visage en direct (Android) ──
  FaceFilter _filter = FaceFilter.none;
  bool _streaming = false;
  bool _frameBusy = false;
  int _lastFrameMs = 0;
  Size? _liveSize;
  List<FaceBox> _liveFaces = const [];
  final List<FaceTrackPoint> _track = []; // trajectoire du visage pendant le tournage
  final Stopwatch _recWatch = Stopwatch();
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

  Future<void> _pickFilter(FaceFilter f) async {
    setState(() {
      _filter = f;
      if (f == FaceFilter.none) _liveFaces = const [];
    });
    await _syncStream();
  }

  /// Lit les images de la caméra seulement quand un filtre est choisi (sinon aucun coût).
  Future<void> _syncStream() async {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized || !FaceFilters.available) return;
    try {
      if (_filter != FaceFilter.none && !_streaming) {
        _streaming = true;
        await c.startImageStream(_onFrame);
      } else if (_filter == FaceFilter.none && _streaming && !_recording) {
        _streaming = false;
        await c.stopImageStream();
      }
    } catch (_) {
      _streaming = false;
    }
  }

  Future<void> _onFrame(CameraImage img) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_frameBusy || now - _lastFrameMs < 140 || !mounted) return;
    _frameBusy = true;
    _lastFrameMs = now;
    try {
      final r = await FaceFilters.detectFrame(img, _cameras[_camIndex].sensorOrientation);
      if (!mounted || r == null) return;
      setState(() {
        _liveSize = r.size;
        _liveFaces = r.faces;
      });
      if (_recording) {
        // seul le plus grand visage est suivi dans la vidéo
        final main = r.faces.isEmpty ? null : (r.faces.toList()..sort((a, b) => (b.rect.width * b.rect.height).compareTo(a.rect.width * a.rect.height))).first;
        final a = main == null ? null : FaceFilters.anchor(main, _filter);
        _track.add(FaceTrackPoint(_recWatch.elapsedMilliseconds, a == null ? null : (a.center.dx / r.size.width).clamp(-0.4, 1.4), a == null ? null : (a.center.dy / r.size.height).clamp(-0.4, 1.4)));
        if (a != null) _trackSize = a.size / r.size.width;
      }
    } finally {
      _frameBusy = false;
    }
  }

  Future<void> _flip() async {
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

  Future<void> _shutter() async {
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
          final chosen = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => FaceFilterPage(path: det.path, size: det.size, faces: det.faces, initial: _filter)));
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
    if (c == null) return;
    try {
      HapticFeedback.mediumImpact();
      _track.clear();
      _recWatch
        ..reset()
        ..start();
      await c.startVideoRecording();
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
    if (c == null || !_recording) return;
    setState(() {
      _recording = false;
      _busy = true;
    });
    try {
      final f = await c.stopVideoRecording();
      _recWatch.stop();
      if (!mounted) return;
      // un clip de moins d'une seconde n'a pas de sens : on recommence
      if (_elapsedMs < 1000) {
        setState(() => _busy = false);
        return;
      }
      var path = f.path;
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

  Future<String> _burnFilter(String path) async {
    try {
      final probe = VideoPlayerController.file(File(path));
      await probe.initialize();
      final videoW = probe.value.size.width;
      await probe.dispose();
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

  Widget _camera(AppColors c) {
    final ctrl = _ctrl;
    final ready = ctrl != null && ctrl.value.isInitialized;
    final remaining = ((_limit * 1000 - _elapsedMs) / 1000).ceil().clamp(0, _limit);
    return Stack(fit: StackFit.expand, children: [
      if (ready)
        ClipRect(
          child: Transform.scale(
            scale: _coverScale(ctrl),
            child: Center(child: CameraPreview(ctrl, child: _liveOverlay(ctrl))),
          ),
        )
      else
        const Center(child: CircularProgressIndicator(color: Colors.white)),
      // dégradés haut et bas : les boutons restent lisibles sur n'importe quelle image
      const Positioned(top: 0, left: 0, right: 0, height: 130, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xAA000000), Color(0x00000000)])))),
      const Positioned(bottom: 0, left: 0, right: 0, height: 260, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xCC000000), Color(0x00000000)])))),
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
              _round(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded, _toggleTorch, active: _torch),
              const SizedBox(width: 8),
              _round(Icons.cameraswitch_rounded, _flip),
            ]),
          ),
          const Spacer(),
          if (FaceFilters.available && !_busy)
            SizedBox(
              key: const ValueKey('face_filters'),
              height: 46,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
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
    ]);
  }

  /// Le filtre posé en direct sur l'aperçu (dans le même cadre que l'image, donc au bon endroit) ; la caméra avant est affichée en miroir.
  Widget? _liveOverlay(CameraController ctrl) {
    final s = _liveSize;
    if (_filter == FaceFilter.none || s == null || _liveFaces.isEmpty) return null;
    final front = _cameras[_camIndex].lensDirection == CameraLensDirection.front;
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
