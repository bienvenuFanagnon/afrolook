import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Icons, IconData;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'beauty.dart';
import 'face_avatars.dart';
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

/// Un choix de fond (flou ou dégradé de couleurs) ou de couleur (cheveux, habits).
class FaceSeg {
  const FaceSeg(this.label, this.color, {this.color2 = 0, this.mode = 0, this.blur = 0.6});
  final String label;
  final int color; // couleur (ARGB) ; pour un fond : haut du dégradé
  final int color2; // bas du dégradé
  final int mode; // fond : 1 flou, 2 dégradé
  final double blur;
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
  const FaceMagic(this.label, this.icon, this.color, {this.kind = 'icon', this.text = '', this.color2 = 0xFFFFFFFF});
  final String label;
  final IconData icon;
  final int color;

  /// `icon` (une icône colorée), `note` (un billet de banque dessiné), `coin` (une pièce avec un symbole) ou `flame` (une flamme dessinée : le moteur la lance en jet de feu).
  final String kind;

  /// Symbole écrit sur le billet ou la pièce ($, FCFA, F).
  final String text;
  final int color2;
}

/// Moteur maison d'effets de visage (Android) : caméra, suivi du visage (478 points), déformations, beauté, masques et enregistrement, tout en direct.
/// Disponible dans les APK de test pour l'instant ; l'ancienne caméra reste en secours partout ailleurs.
class FaceEngine {
  FaceEngine._();

  static const _channel = MethodChannel('afrolook/face_engine');
  static const _viewType = 'afrolook/face_engine_view';

  /// Le moteur de filtres de visage maison est actif sur TOUS les Android (versions publiées comprises) ; l'iPhone garde l'ancienne liste de filtres.
  /// Interrupteur de secours : construire avec `--dart-define=NO_FACE_ENGINE=true` pour le couper sans toucher au code.
  static bool get enabled => !kIsWeb && Platform.isAndroid && !const bool.fromEnvironment('NO_FACE_ENGINE');

  // ── Visage : déformations qui se combinent ──
  static const deformations = [
    FaceDeform('bigeyes', 'Yeux', Icons.visibility_rounded),
    FaceDeform('bigmouth', 'Bouche', Icons.mic_external_on_rounded),
    FaceDeform('bignose', 'Nez', Icons.air_rounded),
    FaceDeform('bigears', 'Oreilles', Icons.hearing_rounded),
    FaceDeform('slimface', 'Visage fin', Icons.face_retouching_natural_rounded),
  ];

  /// Les deux premiers effets du groupe « Visage » (Elfe, Lapin) sont gratuits pour tout le monde ; les autres demandent Gold (ou des pubs).
  static const freePresets = 2;

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

  // ── Fond, cheveux, habits : la personne est séparée du reste (segmentation sur le téléphone) ──
  static const backgrounds = [
    FaceSeg('Flou léger', 0, mode: 1, blur: 0.25),
    FaceSeg('Flou fort', 0, mode: 1, blur: 0.9),
    FaceSeg('Studio', 0xFFEDEFF2, color2: 0xFF98A2AD, mode: 2),
    FaceSeg('Bureau', 0xFFF4F6FA, color2: 0xFFC3CEDF, mode: 2),
    FaceSeg('Savane', 0xFFFFC46B, color2: 0xFFB5532A, mode: 2),
    FaceSeg('Coucher de soleil', 0xFFFF8A3D, color2: 0xFF5B2A86, mode: 2),
    FaceSeg('Océan', 0xFF3FB6E8, color2: 0xFF0B4E7A, mode: 2),
    FaceSeg('Nuit', 0xFF1B2A5C, color2: 0xFF05070F, mode: 2),
    FaceSeg('Écran vert', 0xFF1FD14B, color2: 0xFF1FD14B, mode: 2),
  ];

  static const hairColors = [
    FaceSeg('Noir', 0xFF1B1B1B),
    FaceSeg('Brun', 0xFF5A3A22),
    FaceSeg('Blond', 0xFFE2C36B),
    FaceSeg('Roux', 0xFFB5532A),
    FaceSeg('Rose', 0xFFE86FA6),
    FaceSeg('Bleu', 0xFF3B7DDD),
    FaceSeg('Violet', 0xFF8E4FD6),
    FaceSeg('Vert', 0xFF2FA866),
    FaceSeg('Gris', 0xFFD3D3D3),
  ];

  static const clothColors = [
    FaceSeg('Rouge', 0xFFD62839),
    FaceSeg('Orange', 0xFFF28A1E),
    FaceSeg('Jaune', 0xFFFFC400),
    FaceSeg('Vert', 0xFF1E9E55),
    FaceSeg('Bleu', 0xFF2B6FD6),
    FaceSeg('Violet', 0xFF7B3FD0),
    FaceSeg('Rose', 0xFFE86FA6),
    FaceSeg('Noir', 0xFF151515),
    FaceSeg('Blanc', 0xFFF2F2F2),
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
    // flammes qui sortent de la bouche (dessinées par l'application, plus grosses et plus rapides que les autres effets)
    FaceMagic('Feu', Icons.local_fire_department_rounded, 0xFFFF6A00, kind: 'flame', color2: 0xFFFFD43B),
    FaceMagic('Notes', Icons.music_note_rounded, 0xFF7C4DFF),
    FaceMagic('Dollars', Icons.attach_money_rounded, 0xFF2E9E57, kind: 'note', text: '\$', color2: 0xFFBFE8C9),
    FaceMagic('Billets FCFA', Icons.payments_rounded, 0xFFE07B1F, kind: 'note', text: 'FCFA', color2: 0xFFFFE0B8),
    FaceMagic('Pièces FCFA', Icons.paid_rounded, 0xFFB8C0C8, kind: 'coin', text: 'F', color2: 0xFF5D6670),
    FaceMagic('Pièces dollar', Icons.monetization_on_rounded, 0xFFFFC400, kind: 'coin', text: '\$', color2: 0xFF8A6A00),
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

  /// Fond, couleur des cheveux et des habits (`null` = aucun effet).
  static Future<void> setSegment({FaceSeg? background, FaceSeg? hair, FaceSeg? cloth}) => _channel.invokeMethod('setSegment', {
        'bg': background?.mode ?? 0,
        'blur': background?.blur ?? 0.0,
        'bgA': background?.color ?? 0,
        'bgB': background?.color2 ?? 0,
        'hair': hair?.color ?? 0,
        'hairAmt': hair == null ? 0.0 : 0.85,
        'cloth': cloth?.color ?? 0,
        'clothAmt': cloth == null ? 0.0 : 0.8,
      });

  static Future<void> setFront(bool front) => _channel.invokeMethod('setFront', {'front': front});

  static Future<void> setPoints(bool show) => _channel.invokeMethod('setPoints', {'show': show});

  /// Plusieurs déformations en même temps (liste vide = aucune).
  static Future<void> setDeformations(Iterable<String> keys) => _channel.invokeMethod('setEffect', {'name': keys.isEmpty ? 'none' : keys.join(',')});

  static Future<void> setBeauty(BeautyLevel b) => _channel.invokeMethod('setBeauty', {'smooth': b.smooth, 'bright': b.glow, 'warm': b.warm});

  /// Où se pose chaque masque sur le visage : ancre, taille (en largeur de visage) et décalage vertical (en hauteur de visage).
  static ({String anchor, double size, double dy})? placement(FaceFilter f) => switch (f) {
        FaceFilter.glasses => (anchor: 'eyes', size: 0.95 * FaceFilters.maskBoost, dy: 0.0),
        FaceFilter.crown => (anchor: 'top', size: 0.8 * FaceFilters.maskBoost, dy: 0.0),
        FaceFilter.nose => (anchor: 'nose', size: 0.26 * FaceFilters.maskBoost, dy: 0.0),
        FaceFilter.hearts => (anchor: 'corner', size: 0.4 * FaceFilters.maskBoost, dy: 0.0),
        FaceFilter.monkey || FaceFilter.cat || FaceFilter.robot || FaceFilter.clown => (anchor: 'face', size: 1.45 * FaceFilters.maskBoost, dy: 0.0),
        FaceFilter.hero || FaceFilter.bar => (anchor: 'eyes', size: 1.3 * FaceFilters.maskBoost, dy: 0.0),
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

  /// Avatar : un personnage dont les yeux et la bouche font comme les vôtres (`null` = retire l'avatar).
  static Future<void> setAvatar(FaceAvatar? a) async {
    if (a == null) {
      await _channel.invokeMethod('setAvatar', {});
      return;
    }
    final png = await a.render();
    await _channel.invokeMethod('setAvatar', {'head': png[0], 'eye': png[1], 'mouth': png[2], 'headSize': a.headSize * FaceAvatar.sizeBoost, 'eyeScale': a.eyeScale, 'mouthScale': a.mouthScale});
  }

  /// Effet magique [m] déclenché par le geste [gesture] (`null` = rien).
  static Future<void> setMagic(FaceMagic? m, String gesture) async {
    if (m == null) {
      await _channel.invokeMethod('setParticles', {'trigger': 'none'});
      return;
    }
    final png = m.kind == 'icon' ? await iconPng(m.icon, Color(m.color), 96) : m.kind == 'flame' ? await flamePng(m, 160) : await moneyPng(m, 128);
    await _channel.invokeMethod('setParticles', {'trigger': gesture, 'png': png, 'style': m.kind == 'flame' ? 'fire' : 'stream'});
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

  /// Dessine une flamme (image carrée, pointe en haut) : trois couches, orange (couleur), jaune (couleur2) puis blanc chaud au cœur.
  static Future<Uint8List> flamePng(FaceMagic m, int size) async {
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    final w = size.toDouble();
    Path flame(double s, double dy) {
      final cx = w / 2;
      final top = w * (.06 + dy);
      final bottom = w * (.94 - (1 - s) * .1);
      final half = w * .34 * s;
      return Path()
        ..moveTo(cx, top)
        ..cubicTo(cx + half * .2, top + (bottom - top) * .3, cx + half * 1.25, top + (bottom - top) * .5, cx + half, bottom - (bottom - top) * .25)
        ..cubicTo(cx + half * .8, bottom + (bottom - top) * .02, cx - half * .8, bottom + (bottom - top) * .02, cx - half, bottom - (bottom - top) * .25)
        ..cubicTo(cx - half * 1.25, top + (bottom - top) * .5, cx - half * .2, top + (bottom - top) * .3, cx, top)
        ..close();
    }
    ui.Paint fill(int c) => ui.Paint()..color = Color(c)..isAntiAlias = true;
    canvas.drawPath(flame(1.0, 0), fill(m.color));
    canvas.drawPath(flame(.68, .22), fill(m.color2));
    canvas.drawPath(flame(.36, .46), fill(0xFFFFF6D6));
    final img = await rec.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Dessine un billet de banque ou une pièce (image carrée, le billet est centré) : dollars, FCFA, pièces.
  static Future<Uint8List> moneyPng(FaceMagic m, int size) async {
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    final w = size.toDouble();
    ui.Paint fill(int c) => ui.Paint()..color = Color(c)..isAntiAlias = true;
    ui.Paint line(int c, double sw) => ui.Paint()..color = Color(c)..style = ui.PaintingStyle.stroke..strokeWidth = sw..isAntiAlias = true;
    void label(String t, double fs, Offset center, int c) {
      final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontSize: fs, fontWeight: FontWeight.w900, color: Color(c))), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }

    if (m.kind == 'coin') {
      final c = Offset(w / 2, w / 2);
      canvas.drawCircle(c, w * .44, fill(m.color));
      canvas.drawCircle(c, w * .44, line(m.color2, w * .04));
      canvas.drawCircle(c, w * .33, line(m.color2, w * .02));
      label(m.text, w * (m.text.length > 1 ? .3 : .46), c, m.color2);
    } else {
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w / 2, w / 2), width: w * .96, height: w * .56), Radius.circular(w * .06));
      canvas.drawRRect(r, fill(m.color));
      canvas.drawRRect(r.deflate(w * .04), line(m.color2, w * .02));
      canvas.drawCircle(Offset(w / 2, w / 2), w * .16, fill(m.color2));
      label(m.text, w * (m.text.length > 1 ? .13 : .2), Offset(w / 2, w / 2), m.color);
      label(m.text, w * .08, Offset(w * .17, w * .27), m.color2);
      label(m.text, w * .08, Offset(w * .83, w * .73), m.color2);
    }
    final img = await rec.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static Future<String?> takePhoto(String path) => _channel.invokeMethod<String>('takePhoto', {'path': path});

  static Future<void> startRecording(String path, {required bool audio}) => _channel.invokeMethod('startRecording', {'path': path, 'audio': audio});

  static Future<String?> stopRecording() => _channel.invokeMethod<String>('stopRecording');

  static Future<Map<dynamic, dynamic>> status() async => (await _channel.invokeMethod('status')) as Map<dynamic, dynamic>;
}
