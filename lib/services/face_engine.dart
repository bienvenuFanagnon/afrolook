import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'beauty.dart';
import 'face_filters.dart';

/// Moteur maison d'effets de visage (Android) : caméra, suivi du visage (478 points), déformations, beauté, masques et enregistrement, tout en direct.
/// Disponible dans les APK de test pour l'instant ; l'ancienne caméra reste en secours partout ailleurs.
class FaceEngine {
  FaceEngine._();

  static const _channel = MethodChannel('afrolook/face_engine');
  static const _viewType = 'afrolook/face_engine_view';

  static bool get enabled => !kIsWeb && Platform.isAndroid && const bool.fromEnvironment('TEST_BUILD');

  /// Déformations du moteur (une seule à la fois ; elles se combinent avec la beauté et un masque).
  static const deformations = [
    ('bigeyes', '👀'),
    ('bigmouth', '👄'),
    ('bignose', '👃'),
    ('slimface', '🫥'),
  ];

  static Widget view({required bool front}) => PlatformViewLink(
        viewType: _viewType,
        surfaceFactory: (context, controller) => AndroidViewSurface(controller: controller as AndroidViewController, gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{}, hitTestBehavior: PlatformViewHitTestBehavior.transparent),
        onCreatePlatformView: (params) => PlatformViewsService.initExpensiveAndroidView(id: params.id, viewType: _viewType, layoutDirection: TextDirection.ltr, creationParams: {'front': front}, creationParamsCodec: const StandardMessageCodec(), onFocus: () => params.onFocusChanged(true))
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create(),
      );

  /// Looks de couleur (se combinent avec la beauté, les déformations et les masques).
  static const looks = [
    ('Sans look', 0),
    ('Noir & blanc', 1),
    ('Sépia', 2),
    ('Vintage', 3),
    ('Cinéma', 4),
    ('Néon', 5),
    ('Pop', 6),
  ];

  static Future<void> setLook(int look) => _channel.invokeMethod('setLook', {'look': look});

  static Future<void> setFront(bool front) => _channel.invokeMethod('setFront', {'front': front});

  static Future<void> setPoints(bool show) => _channel.invokeMethod('setPoints', {'show': show});

  static Future<void> setDeformation(String name) => _channel.invokeMethod('setEffect', {'name': name});

  static Future<void> setBeauty(BeautyLevel b) => _channel.invokeMethod('setBeauty', {'smooth': b.smooth, 'bright': b.glow, 'warm': b.warm});

  /// Où se pose chaque masque sur le visage : ancre, taille (en largeur de visage) et décalage vertical (en hauteur de visage).
  static ({String anchor, double size, double dy})? placement(FaceFilter f) => switch (f) {
        FaceFilter.glasses => (anchor: 'eyes', size: 0.95, dy: 0.0),
        FaceFilter.crown => (anchor: 'top', size: 0.8, dy: 0.0),
        FaceFilter.nose => (anchor: 'nose', size: 0.26, dy: 0.0),
        FaceFilter.hearts => (anchor: 'corner', size: 0.4, dy: 0.0),
        FaceFilter.monkey || FaceFilter.cat || FaceFilter.robot || FaceFilter.clown => (anchor: 'face', size: 1.45, dy: 0.0),
        FaceFilter.hero || FaceFilter.bar => (anchor: 'eyes', size: 1.3, dy: 0.0),
        FaceFilter.none || FaceFilter.blur => null,
      };

  /// Pose (ou retire) le masque [f] : le dessin est fabriqué ici (même dessin que l'ancienne caméra), le moteur le colle au visage.
  static Future<void> setMask(FaceFilter f) async {
    final p = placement(f);
    if (p == null) {
      await _channel.invokeMethod('setOverlay', {'anchor': 'none', 'size': 1.0, 'dy': 0.0});
      return;
    }
    final png = await FaceFilters.filterPng(f, 512);
    await _channel.invokeMethod('setOverlay', {'png': Uint8List.fromList(png), 'anchor': p.anchor, 'size': p.size, 'dy': p.dy});
  }

  static Future<String?> takePhoto(String path) => _channel.invokeMethod<String>('takePhoto', {'path': path});

  static Future<void> startRecording(String path, {required bool audio}) => _channel.invokeMethod('startRecording', {'path': path, 'audio': audio});

  static Future<String?> stopRecording() => _channel.invokeMethod<String>('stopRecording');

  static Future<Map<dynamic, dynamic>> status() async => (await _channel.invokeMethod('status')) as Map<dynamic, dynamic>;
}
