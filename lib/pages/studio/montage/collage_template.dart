// Modèles « collage » (09/11/2026) : 2 à 5 photos de la personne posées dans une mise en page, avec une étiquette par case (« AVANT » / « APRÈS », un mois…) et un titre.
// Le résultat est UNE image que l'éditeur habituel reprend (texte, musique, effets, widgets).

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

import '../../../services/collage_layouts.dart';

class CollageScript {
  const CollageScript({required this.layout, required this.labels, this.caption = '', this.tones = const [], this.center = '', this.handle = false, this.profile = false});

  /// Mise en page (identifiant de `CollageLayouts`) ; le nombre de cases est `labels.length`.
  final String layout;

  /// Étiquette de chaque case (vide = aucune).
  final List<String> labels;

  /// Titre posé en bas de l'image.
  final String caption;

  /// Couleur de l'étiquette de chaque case : `y` jaune (défaut), `r` rouge, `g` vert.
  final List<String> tones;

  /// Texte posé au milieu de l'image (entre deux photos l'une sur l'autre), vide = aucun.
  final String center;

  /// Une poignée (trait + rond à flèches) sur la ligne qui sépare les deux photos : le curseur avant / après.
  final bool handle;

  /// Le drapeau du pays et le vrai nombre d'abonnés de la personne, en pastilles (« Mon année en 5 photos »).
  final bool profile;

  int get slots => labels.length;
}

/// Scripts des modèles collage, par identifiant de modèle du catalogue.
CollageScript? collageScriptFor(String templateId) {
  final next = DateTime.now().month >= 9 ? DateTime.now().year + 1 : DateTime.now().year;
  final end = next - 1;
  switch (templateId) {
    case 'multi_avant_apres':
      return const CollageScript(layout: 'sbs', labels: ['Jour 1', 'Jour 30'], tones: ['y', 'g'], caption: 'Ma transformation', handle: true);
    case 'multi_toi_lui':
      return const CollageScript(layout: 'sbs', labels: ['Toi', 'Lui'], tones: ['y', 'r'], caption: 'Qui gagne ?');
    case 'multi_boutique':
      return const CollageScript(layout: 'left1_3', labels: ['12 500 FCFA', '-20 %', '★ 4,8 · 126 avis', ''], tones: ['g', 'r', 'y', 'y'], caption: 'Commande sur WhatsApp 👇');
    case 'multi_recette':
      return const CollageScript(layout: 'left1_3', labels: ['25 min · 4 pers.', 'Ingrédient 1', 'Ingrédient 2', 'Ingrédient 3'], tones: ['y', 'g', 'g', 'g'], caption: 'Recette express 🍲');
    case 'multi_duo':
      return const CollageScript(layout: 'tb', labels: ['', ''], caption: 'Nous deux 💞');
    case 'multi_cinq_moments':
      return CollageScript(layout: 'top1_4', labels: const ['', '', '', '', ''], caption: '$end', profile: true);
    case 'dr_realite':
      return const CollageScript(layout: 'tb', labels: ['Moi', 'La réalité'], tones: ['y', 'r'], center: 'Attente / Réalité');
    case 'dr_salaire':
      return const CollageScript(layout: 'sbs', labels: ['0 FCFA', '150 000 FCFA'], tones: ['r', 'g'], caption: 'La vie change en 24 h');
    case 'fa_page':
      return CollageScript(layout: 'sbs', labels: ['$end · la dure année', '$next · je construis'], tones: const ['r', 'g'], caption: 'Je tourne la page.');
    case 'dr_entendu':
      return const CollageScript(layout: 'tb', labels: ['CE QUE J’AI DIT', 'CE QU’ILS ONT ENTENDU'], caption: 'Incompréhension 🗣️');
    case 'vie_retrouv':
      return const CollageScript(layout: 'sbs', labels: ['IL Y A 10 ANS', 'AUJOURD’HUI'], caption: 'Retrouvailles 🤗');
    case 'vie_famille':
      return const CollageScript(layout: 'left1', labels: ['', '', ''], caption: 'Ma famille 👨‍👩‍👧');
    case 'vie_age':
      return const CollageScript(layout: 'sbs', labels: ['L’AN DERNIER', 'AUJOURD’HUI'], caption: 'Un an de plus 🎂');
    case 'vie_maison':
      return const CollageScript(layout: 'sbs', labels: ['AVANT', 'APRÈS'], caption: 'Nouvelle maison 🏠');
    case 'multi_quatre_saisons':
      return CollageScript(layout: 'grid', labels: const ['MARS', 'JUIN', 'SEPTEMBRE', 'DÉCEMBRE'], caption: 'Mon année $end en 4 photos');
  }
  return null;
}

/// Identifiants des modèles du catalogue qui sont des collages.
const kCollageTemplateIds = {'fa_page', 'multi_toi_lui', 'multi_boutique', 'multi_recette', 'multi_avant_apres', 'multi_duo', 'multi_cinq_moments', 'multi_quatre_saisons', 'dr_realite', 'dr_salaire', 'dr_entendu', 'vie_retrouv', 'vie_famille', 'vie_age', 'vie_maison'};

class CollageTemplateRender {
  CollageTemplateRender._();

  /// Dessine le collage (format 4:5) : photos recadrées au centre, étiquettes en haut de chaque case, titre en bas. Rend les octets PNG.
  static Future<Uint8List> png(List<Uint8List> photos, CollageScript s, {List<String>? labels, String? caption, String? center, String? flagCode, int? followers, int width = 1080}) async {
    final n = photos.length;
    final cells = CollageLayouts.withGap(CollageLayouts.cells0(s.layout, n), .012);
    final height = (width / CollageLayouts.aspect).round();
    final w = width.toDouble();
    final h = height.toDouble();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF111111));
    for (var i = 0; i < n; i++) {
      final cell = cells[i];
      final dst = Rect.fromLTWH(cell.left * w, cell.top * h, cell.width * w, cell.height * h);
      try {
        final codec = await ui.instantiateImageCodec(photos[i], targetWidth: 1600);
        final img = (await codec.getNextFrame()).image;
        c.drawImageRect(img, CollageLayouts.coverSource(img.width.toDouble(), img.height.toDouble(), dst.width, dst.height), dst, Paint()..filterQuality = FilterQuality.high);
        img.dispose();
      } catch (_) {
        // photo illisible : la case reste sombre
      }
      final label = ((labels != null && i < labels.length) ? labels[i] : (i < s.labels.length ? s.labels[i] : '')).trim();
      if (label.isNotEmpty) {
        final tone = i < s.tones.length ? s.tones[i] : 'y';
        final bg = switch (tone) { 'r' => const Color(0xFFE53935), 'g' => const Color(0xFF2E9E4F), _ => const Color(0xFFFFD400) };
        final fg = tone == 'y' ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
        final tp = TextPainter(
          text: TextSpan(text: label, style: TextStyle(color: fg, fontSize: width * (label.length > 14 ? .032 : .04), fontWeight: FontWeight.w900, letterSpacing: width * .003)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: dst.width - 24);
        final pad = width * .016;
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(dst.left + 14, dst.top + 14, tp.width + pad * 2, tp.height + pad), Radius.circular(width * .014));
        c.drawRRect(r, Paint()..color = bg);
        tp.paint(c, Offset(r.left + pad, r.top + pad / 2));
      }
    }
    // curseur avant / après : un trait blanc sur la séparation et une poignée ronde à deux flèches
    if (s.handle) {
      final line = Paint()..color = const Color(0xFFFFFFFF)..strokeWidth = width * .006;
      final tb = s.layout == 'tb';
      c.drawLine(tb ? Offset(0, h / 2) : Offset(w / 2, 0), tb ? Offset(w, h / 2) : Offset(w / 2, h), line);
      final r = width * .05;
      c.drawCircle(Offset(w / 2, h / 2), r, Paint()..color = const Color(0xFFFFFFFF));
      final arrows = TextPainter(text: TextSpan(text: tb ? '▲▼' : '◀▶', style: TextStyle(color: const Color(0xFF000000), fontSize: r * .8, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
      arrows.paint(c, Offset(w / 2 - arrows.width / 2, h / 2 - arrows.height / 2));
    }
    // drapeau et abonnés de la personne (pastilles en bas à gauche, au-dessus du titre)
    if (s.profile) {
      var x = 18.0;
      final y0 = h * .79;
      void pill(String text, double size) {
        final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: size, fontWeight: FontWeight.w800)), textDirection: TextDirection.ltr)..layout();
        final pad = width * .016;
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, y0, tp.width + pad * 2, tp.height + pad), Radius.circular(width * .02));
        c.drawRRect(r, Paint()..color = const Color(0xB3000000));
        tp.paint(c, Offset(r.left + pad, r.top + pad / 2));
        x = r.right + 10;
      }
      if (flagCode != null && flagCode.length == 2) pill(String.fromCharCodes(flagCode.toUpperCase().codeUnits.map((u) => 0x1F1E6 + (u - 65))), width * .05);
      if (followers != null) pill(followers >= 1000 ? '${(followers / 1000).toStringAsFixed(1).replaceAll('.', ',')} k abonnés' : '$followers abonnés', width * .036);
    }
    // texte du milieu (« Attente / Réalité ») : blanc cerclé de noir, entre les deux photos
    final mid = (center ?? s.center).trim();
    if (mid.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: mid.toUpperCase(), style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: width * .075, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Color(0xFF000000), blurRadius: 12), Shadow(color: Color(0xFF000000), blurRadius: 4)])),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w - 80);
      tp.paint(c, Offset((w - tp.width) / 2, h / 2 - tp.height / 2));
    }
    final cap = (caption ?? s.caption).trim();
    if (cap.isNotEmpty) {
      c.drawRect(Rect.fromLTWH(0, h * .86, w, h * .14), Paint()..shader = ui.Gradient.linear(Offset(0, h * .86), Offset(0, h), const [Color(0x00000000), Color(0xCC000000)]));
      final tp = TextPainter(
        text: TextSpan(
          text: cap,
          style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: width * .06, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 10)]),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w - 80);
      tp.paint(c, Offset((w - tp.width) / 2, h - tp.height - h * .03));
    }
    final pic = rec.endRecording();
    final out = await pic.toImage(width, height);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    pic.dispose();
    return data!.buffer.asUint8List();
  }

  static Future<File> toFile(Uint8List png) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/collage_modele_${DateTime.now().microsecondsSinceEpoch}.png').writeAsBytes(png, flush: true);
  }
}
