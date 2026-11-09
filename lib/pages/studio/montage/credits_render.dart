import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Le texte d'un générique de fin de film (10/11/2026), dessiné en UNE grande image transparente que le serveur fait monter lentement du bas au haut du film.
/// Une ligne de texte :
/// - « # Titre » : grand titre centré ;
/// - « Rôle · Nom » : le rôle en petites capitales dorées, le nom en blanc au-dessous (comme un vrai générique) ;
/// - une ligne vide : un espace ;
/// - toute autre ligne : texte blanc centré.
class CreditsRender {
  CreditsRender._();

  static const _gold = ui.Color(0xFFFFD400);

  /// Les lignes d'un générique pour le modèle [templateId] (« Le film de mon année ») ; l'année s'adapte à l'année qui finit.
  static List<String> defaultLines() {
    final end = DateTime.now().month >= 9 ? DateTime.now().year : DateTime.now().year - 1;
    return [
      '# MON ANNÉE $end',
      '',
      'Un film de · MOI',
      'Avec · MA FAMILLE',
      'Avec · MES AMIS',
      'Scénario · MES GALÈRES',
      'Rôle principal · MA FORCE',
      'Effets spéciaux · MES LARMES ET MES RIRES',
      'Musique · MES PLAYLISTS',
      '',
      'Merci d’avoir regardé',
      '',
      '# FIN',
    ];
  }

  /// Hauteur d'un bloc de texte et son dessin ; [k] = largeur / 720.
  static List<({TextPainter role, TextPainter text, double gap})> _blocks(List<String> lines, double k, double maxW) {
    final out = <({TextPainter role, TextPainter text, double gap})>[];
    TextPainter tp(String s, double size, ui.Color color, FontWeight w, {double spacing = 0}) => TextPainter(
          text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size * k, fontWeight: w, letterSpacing: spacing * k, height: 1.15, shadows: [Shadow(color: const ui.Color(0xE6000000), blurRadius: 10 * k, offset: ui.Offset(0, 2 * k))])),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxW);
    for (final raw in lines) {
      final l = raw.trimRight();
      if (l.trim().isEmpty) {
        out.add((role: tp('', 10, const ui.Color(0x00000000), FontWeight.w400), text: tp('', 10, const ui.Color(0x00000000), FontWeight.w400), gap: 60 * k));
      } else if (l.startsWith('#')) {
        out.add((role: tp('', 10, const ui.Color(0x00000000), FontWeight.w400), text: tp(l.substring(1).trim(), 74, const ui.Color(0xFFFFFFFF), FontWeight.w900, spacing: 2), gap: 30 * k));
      } else if (l.contains('·')) {
        final i = l.indexOf('·');
        out.add((role: tp(l.substring(0, i).trim().toUpperCase(), 26, _gold, FontWeight.w800, spacing: 5), text: tp(l.substring(i + 1).trim(), 46, const ui.Color(0xFFFFFFFF), FontWeight.w800), gap: 34 * k));
      } else {
        out.add((role: tp('', 10, const ui.Color(0x00000000), FontWeight.w400), text: tp(l.trim(), 40, const ui.Color(0xFFFFFFFF), FontWeight.w700), gap: 30 * k));
      }
    }
    return out;
  }

  /// Hauteur de l'image du texte (sans le cadre vide du début et de la fin), pour la largeur [width].
  static double heightFor(List<String> lines, {int width = 720}) {
    final k = width / 720;
    var h = 0.0;
    for (final b in _blocks(lines, k, width - 100 * k)) {
      h += b.role.height + (b.role.height > 0 ? 6 * k : 0) + b.text.height + b.gap;
    }
    return h;
  }

  /// PNG transparent du texte : [width] de large (720 = la largeur du film). Une marge d'une hauteur de cadre est ajoutée en haut et en bas pour que le texte entre et sorte en entier.
  static Future<Uint8List> png(List<String> lines, {int width = 720, double frameRatio = 16 / 9}) async {
    final k = width / 720;
    final blocks = _blocks(lines, k, width - 100 * k);
    final pad = width * frameRatio * .12;   // un peu de vide avant et après : le texte arrive et repart sans coupure
    var y = pad;
    var total = pad * 2;
    for (final b in blocks) {
      total += b.role.height + (b.role.height > 0 ? 6 * k : 0) + b.text.height + b.gap;
    }
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, ui.Rect.fromLTWH(0, 0, width.toDouble(), total));
    for (final b in blocks) {
      if (b.role.height > 0) {
        b.role.paint(c, ui.Offset((width - b.role.width) / 2, y));
        y += b.role.height + 6 * k;
      }
      b.text.paint(c, ui.Offset((width - b.text.width) / 2, y));
      y += b.text.height + b.gap;
    }
    final pic = rec.endRecording();
    final img = await pic.toImage(width, total.ceil());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    pic.dispose();
    return data!.buffer.asUint8List();
  }
}
