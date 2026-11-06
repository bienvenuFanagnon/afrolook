import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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
  int _rot = 0;
  bool _mirror = false;
  Map<dynamic, dynamic> _status = const {};
  Timer? _timer;

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
                    setState(() => _front = !_front);
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
                'Visage : ${faceOk ? 'suivi ✅' : 'non trouvé'}  ·  images analysées : ${_status['frames'] ?? 0}\nRotation : ${_status['rotation'] ?? '?'}°  ·  miroir : ${_status['mirror'] ?? '?'}${_status['error'] != null ? '\nErreur : ${_status['error']}' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OutlinedButton(
                key: const ValueKey('lab_rot'),
                onPressed: () async {
                  setState(() => _rot = (_rot + 90) % 360);
                  await _orient();
                },
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                child: Text('Tourner (+$_rot°)', style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 10),
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
