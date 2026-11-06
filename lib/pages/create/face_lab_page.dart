import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

/// Laboratoire du moteur maison d'effets de visage (Android, version d'essai, visible seulement dans les APK de test) :
/// caméra en direct avec déformations (gros yeux, grande bouche, gros nez, visage fin). Les boutons « Tourner » et « Miroir » servent à régler l'orientation
/// sur chaque téléphone pendant les essais ; l'état affiché en bas dit si le visage est bien suivi.
class FaceLabPage extends StatefulWidget {
  const FaceLabPage({super.key});

  static const available = bool.fromEnvironment('TEST_BUILD');

  @override
  State<FaceLabPage> createState() => _FaceLabPageState();
}

class _FaceLabPageState extends State<FaceLabPage> {
  static const _channel = MethodChannel('afrolook/face_engine');
  static const _viewType = 'afrolook/face_engine_view';

  bool _ready = false;
  bool _front = true;
  String _effect = 'none';
  int _rot = 90; // réglage par défaut mesuré : image droite avec miroir
  bool _points = true;
  bool _mirror = true; // sens « selfie » dès l'ouverture (caméra avant)
  bool _flipPts = true; // sens gauche/droite des points (réglage de secours si les points vont à l'envers)
  Map<dynamic, dynamic> _status = const {};
  Timer? _timer;
  bool _recording = false;
  String? _result;

  static const _effects = [
    ('none', 'Aucun', '🚫'),
    ('bigeyes', 'Gros yeux', '👀'),
    ('bigmouth', 'Grande bouche', '👄'),
    ('bignose', 'Gros nez', '👃'),
    ('slimface', 'Visage fin', '🫥'),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final cam = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _ready = cam.isGranted);
    // le labo est le seul endroit où les points de repère sont visibles
    Future<void>.delayed(const Duration(milliseconds: 900), () => _channel.invokeMethod('setPoints', {'show': true}).catchError((_) {}));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final s = await _channel.invokeMethod('status');
        if (mounted && s is Map) setState(() => _status = s);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _set(String effect) async {
    setState(() => _effect = effect);
    await _channel.invokeMethod('setEffect', {'name': effect});
  }

  Future<String> _tmp(String ext) async => '${(await getTemporaryDirectory()).path}/labo_${DateTime.now().millisecondsSinceEpoch}.$ext';

  Future<void> _photo() async {
    try {
      final out = await _channel.invokeMethod<String>('takePhoto', {'path': await _tmp('jpg')});
      if (!mounted) return;
      setState(() => _result = 'Photo : $out');
      await showDialog<void>(context: context, builder: (c) => Dialog(child: Image.file(File(out!))));
    } catch (e) {
      if (mounted) setState(() => _result = 'Photo impossible : $e');
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (!_recording) {
        await _channel.invokeMethod('startRecording', {'path': await _tmp('mp4'), 'audio': await Permission.microphone.request().isGranted});
        if (mounted) setState(() => _recording = true);
      } else {
        setState(() => _recording = false);
        final out = await _channel.invokeMethod<String>('stopRecording');
        if (!mounted) return;
        final size = File(out!).lengthSync();
        setState(() => _result = 'Vidéo : $out (${(size / 1024).round()} Ko)');
        final v = VideoPlayerController.file(File(out));
        await v.initialize();
        await v.setLooping(true);
        await v.play();
        if (!mounted) return;
        await showDialog<void>(context: context, builder: (c) => Dialog(child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v))));
        await v.dispose();
      }
    } catch (e) {
      if (mounted) setState(() {
        _recording = false;
        _result = 'Enregistrement impossible : $e';
      });
    }
  }

  Future<void> _orient() => _channel.invokeMethod('setOrientation', {'rotation': _rot, 'mirror': _mirror});

  @override
  Widget build(BuildContext context) {
    final faceOk = _status['face'] == true;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (_ready && !kIsWeb && Platform.isAndroid)
          PlatformViewLink(
            viewType: _viewType,
            surfaceFactory: (context, controller) => AndroidViewSurface(controller: controller as AndroidViewController, gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{}, hitTestBehavior: PlatformViewHitTestBehavior.transparent),
            onCreatePlatformView: (params) => PlatformViewsService.initExpensiveAndroidView(id: params.id, viewType: _viewType, layoutDirection: TextDirection.ltr, creationParams: {'front': _front}, creationParamsCodec: const StandardMessageCodec(), onFocus: () => params.onFocusChanged(true))
              ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
              ..create(),
          )
        else
          const Center(child: Text('Laboratoire disponible sur Android seulement (autorise la caméra).', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(children: [
                IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
                const Spacer(),
                const Text('Labo effets (essai)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  key: const ValueKey('lab_flip'),
                  onPressed: () async {
                    setState(() { _front = !_front; _mirror = _front; });
                    await _channel.invokeMethod('setFront', {'front': _front});
                  },
                  icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
                ),
              ]),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(12)),
              child: Text(
                'Visage : ${faceOk ? 'suivi ✅' : 'non trouvé'}  ·  ${_status['fps'] ?? 0} détections/s  ·  retard ${_status['latencyMs'] ?? 0} ms  ·  ${_status['gpu'] == true ? 'GPU' : 'processeur'}\nDétection : ${_status['detectRate'] ?? 0} %  ·  tremblement ${(_status['jitter'] ?? 0).toStringAsFixed(2)}  ·  erreur de prévision ${(_status['predErr'] ?? 0).toStringAsFixed(2)}\nRéglage appris : lissage ${(_status['alpha'] ?? 0).toStringAsFixed(2)}  ·  prévision ${(_status['predGain'] ?? 0).toStringAsFixed(2)}  ·  ${_status['learned'] ?? 0} images\nRotation : ${_status['rotation'] ?? '?'}°  ·  miroir : ${_status['mirror'] ?? '?'}${_status['error'] != null ? '\nErreur : ${_status['error']}' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
            if (_result != null)
              Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 0), child: Text(_result!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12))),
            const SizedBox(height: 8),
            Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
              OutlinedButton(
                key: const ValueKey('lab_points'),
                onPressed: () async {
                  setState(() => _points = !_points);
                  await _channel.invokeMethod('setPoints', {'show': _points});
                },
                style: OutlinedButton.styleFrom(side: BorderSide(color: _points ? const Color(0xFFFFC400) : Colors.white54)),
                child: Text(_points ? 'Points ✓' : 'Points', style: const TextStyle(color: Colors.white)),
              ),
              OutlinedButton(
                key: const ValueKey('lab_flip_points'),
                onPressed: () async {
                  setState(() => _flipPts = !_flipPts);
                  await _channel.invokeMethod('setFlipPoints', {'flip': _flipPts});
                },
                style: OutlinedButton.styleFrom(side: BorderSide(color: _flipPts ? const Color(0xFFFFC400) : Colors.white54)),
                child: Text('Points ⇄', style: const TextStyle(color: Colors.white)),
              ),
              IconButton.filled(key: const ValueKey('lab_photo'), onPressed: _recording ? null : _photo, icon: const Icon(Icons.photo_camera_rounded)),
              IconButton.filled(
                key: const ValueKey('lab_rec'),
                style: IconButton.styleFrom(backgroundColor: _recording ? Colors.white : const Color(0xFFE5383B)),
                onPressed: _toggleRecording,
                icon: Icon(_recording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded, color: _recording ? Colors.black : Colors.white),
              ),
              OutlinedButton(
                key: const ValueKey('lab_rot'),
                onPressed: () async {
                  setState(() => _rot = (_rot + 90) % 360);
                  await _orient();
                },
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                child: Text('Tourner (+$_rot°)', style: const TextStyle(color: Colors.white)),
              ),
              OutlinedButton(
                key: const ValueKey('lab_mirror'),
                onPressed: () async {
                  setState(() => _mirror = !_mirror);
                  await _orient();
                },
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                child: Text('Miroir ${_mirror ? 'inversé' : ''}', style: const TextStyle(color: Colors.white)),
              ),
            ]),
            SizedBox(
              height: 74,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(10), children: [
                for (final e in _effects)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey('lab_${e.$1}'),
                      label: Text('${e.$3} ${e.$2}', style: TextStyle(fontWeight: FontWeight.w700, color: _effect == e.$1 ? Colors.black : Colors.white)),
                      selected: _effect == e.$1,
                      selectedColor: const Color(0xFFFFC400),
                      backgroundColor: const Color(0x99000000),
                      side: BorderSide.none,
                      onSelected: (_) => _set(e.$1),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
