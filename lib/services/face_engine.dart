import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Icons, IconData;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'beauty.dart';
import 'face_filters.dart';

/// Une déformation du visage (elles se combinent entre elles).
class FaceDeform {
  const FaceDeform(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

/// Une combinaison prête à l'emploi : plusieurs déformations d'un coup (« Elfe », « Lapin »…).
class FacePreset {
  const FacePreset(this.label, this.icon, this.keys);
  final String label;
  final IconData icon;
  final List<String> keys;
}

/// Un look de couleur.
class FaceLook {
  const FaceLook(this.label, this.id, this.icon);
  final String label;
  final int id;
  final IconData icon;
}

/// Un geste qui déclenche un effet magique.
class FaceGesture {
  const FaceGesture(this.key, this.label, this.instruction, this.icon);
  final String key;
  final String label;
  final String instruction;
  final IconData icon;
}

/// Un effet magique : un petit dessin qui s'envole quand on fait le geste choisi.
class FaceMagic {
  const FaceMagic(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final int color;
}

/// Moteur maison d'effets de visage (Android) : caméra, suivi du visage (478 points), déformations, beauté, masques et enregistrement, tout en direct.
/// Disponible dans les APK de test pour l'instant ; l'ancienne caméra reste en secours partout ailleurs.
class FaceEngine {
  FaceEngine._();

  static const _channel = MethodChannel('afrolook/face_engine');
  static const _viewType = 'afrolook/face_engine_view';

  static bool get enabled => !kIsWeb && Platform.isAndroid && const bool.fromEnvironment('TEST_BUILD');

  // ── Visage : déformations qui se combinent ──
  static const deformations = [
    FaceDeform('bigeyes', 'Yeux', Icons.visibility_rounded),
    FaceDeform('bigmouth', 'Bouche', Icons.mic_external_on_rounded),
    FaceDeform('bignose', 'Nez', Icons.air_rounded),
    FaceDeform('bigears', 'Oreilles', Icons.hearing_rounded),
    FaceDeform('slimface', 'Visage fin', Icons.face_retouching_natural_rounded),
  ];

  static const presets = [
    FacePreset('Elfe', Icons.auto_awesome_rounded, ['bigears', 'bigeyes', 'slimface']),
    FacePreset('Lapin', Icons.cruelty_free_rounded, ['bigears', 'bignose', 'bigeyes']),
    FacePreset('Bébé', Icons.child_care_rounded, ['bigeyes', 'slimface']),
    FacePreset('Alien', Icons.rocket_launch_rounded, ['bigeyes', 'slimface', 'bigmouth']),
    FacePreset('Clown', Icons.sentiment_very_satisfied_rounded, ['bignose', 'bigmouth']),
    FacePreset('Géant', Icons.expand_rounded, ['bigears', 'bigmouth', 'bignose']),
  ];

  // ── Couleur : le néon est en première position ──
  static const looks = [
    FaceLook('Néon', 5, Icons.bolt_rounded),
    FaceLook('Noir & blanc', 1, Icons.contrast_rounded),
    FaceLook('Sépia', 2, Icons.filter_vintage_rounded),
    FaceLook('Vintage', 3, Icons.photo_camera_back_rounded),
    FaceLook('Cinéma', 4, Icons.movie_filter_rounded),
    FaceLook('Pop', 6, Icons.color_lens_rounded),
  ];

  // ── Masques : une vraie icône par masque ──
  static IconData maskIcon(FaceFilter f) => switch (f) {
        FaceFilter.glasses => Icons.remove_red_eye_rounded,
        FaceFilter.crown => Icons.workspace_premium_rounded,
        FaceFilter.nose => Icons.radio_button_checked_rounded,
        FaceFilter.hearts => Icons.favorite_rounded,
        FaceFilter.monkey => Icons.mood_rounded,
        FaceFilter.cat => Icons.pets_rounded,
        FaceFilter.robot => Icons.smart_toy_rounded,
        FaceFilter.clown => Icons.sentiment_very_satisfied_rounded,
        FaceFilter.hero => Icons.shield_rounded,
        FaceFilter.bar => Icons.horizontal_rule_rounded,
        FaceFilter.blur => Icons.blur_on_rounded,
        FaceFilter.none => Icons.block_rounded,
      };

  static String maskLabel(FaceFilter f) => switch (f) {
        FaceFilter.glasses => 'Lunettes',
        FaceFilter.crown => 'Couronne',
        FaceFilter.nose => 'Nez rouge',
        FaceFilter.hearts => 'Cœurs',
        FaceFilter.monkey => 'Singe',
        FaceFilter.cat => 'Chat',
        FaceFilter.robot => 'Robot',
        FaceFilter.clown => 'Clown',
        FaceFilter.hero => 'Héros',
        FaceFilter.bar => 'Barre',
        FaceFilter.blur => 'Flou',
        FaceFilter.none => 'Aucun',
      };

  // ── Magie : l'effet et le geste qui le déclenche se choisissent séparément ──
  static const magic = [
    FaceMagic('Cœurs', Icons.favorite_rounded, 0xFFFF3B5C),
    FaceMagic('Pièces', Icons.monetization_on_rounded, 0xFFFFC400),
    FaceMagic('Étoiles', Icons.star_rounded, 0xFFFFE066),
    FaceMagic('Notes', Icons.music_note_rounded, 0xFF7C4DFF),
  ];

  static const gestures = [
    FaceGesture('mouth', 'Bouche ouverte', 'Ouvre la bouche', Icons.sentiment_neutral_rounded),
    FaceGesture('smile', 'Sourire', 'Fais un grand sourire', Icons.sentiment_satisfied_alt_rounded),
    FaceGesture('brows', 'Sourcils levés', 'Lève les sourcils', Icons.expand_less_rounded),
    FaceGesture('blink', 'Clin d\'œil', 'Cligne des yeux', Icons.remove_red_eye_outlined),
    FaceGesture('turn', 'Tête tournée', 'Tourne la tête sur le côté', Icons.rotate_right_rounded),
  ];

  static Widget view({required bool front}) => PlatformViewLink(
        viewType: _viewType,
        surfaceFactory: (context, controller) => AndroidViewSurface(controller: controller as AndroidViewController, gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{}, hitTestBehavior: PlatformViewHitTestBehavior.transparent),
        onCreatePlatformView: (params) => PlatformViewsService.initExpensiveAndroidView(id: params.id, viewType: _viewType, layoutDirection: TextDirection.ltr, creationParams: {'front': front}, creationParamsCodec: const StandardMessageCodec(), onFocus: () => params.onFocusChanged(true))
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create(),
      );

  static Future<void> setLook(int look) => _channel.invokeMethod('setLook', {'look': look});

  static Future<void> setFront(bool front) => _channel.invokeMethod('setFront', {'front': front});

  static Future<void> setPoints(bool show) => _channel.invokeMethod('setPoints', {'show': show});

  /// Plusieurs déformations en même temps (liste vide = aucune).
  static Future<void> setDeformations(Iterable<String> keys) => _channel.invokeMethod('setEffect', {'name': keys.isEmpty ? 'none' : keys.join(',')});

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

  /// Effet magique [m] déclenché par le geste [gesture] (`null` = rien).
  static Future<void> setMagic(FaceMagic? m, String gesture) async {
    if (m == null) {
      await _channel.invokeMethod('setParticles', {'trigger': 'none'});
      return;
    }
    final png = await iconPng(m.icon, Color(m.color), 96);
    await _channel.invokeMethod('setParticles', {'trigger': gesture, 'png': png});
  }

  /// Dessine une icône de l'application en image (PNG) pour le moteur : plus d'emoji, de vraies icônes colorées.
  static Future<Uint8List> iconPng(IconData icon, Color color, int size) async {
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    final tp = TextPainter(
      text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontSize: size * 0.9, fontFamily: icon.fontFamily, package: icon.fontPackage, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    final img = await rec.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static Future<String?> takePhoto(String path) => _channel.invokeMethod<String>('takePhoto', {'path': path});

  static Future<void> startRecording(String path, {required bool audio}) => _channel.invokeMethod('startRecording', {'path': path, 'audio': audio});

  static Future<String?> stopRecording() => _channel.invokeMethod<String>('stopRecording');

  static Future<Map<dynamic, dynamic>> status() async => (await _channel.invokeMethod('status')) as Map<dynamic, dynamic>;
}
