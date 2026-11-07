import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'dart:io';
import 'dart:ui' as ui;

import '../../../services/api/api_gateway.dart';
import '../../../services/api/argent_upload.dart';
import '../../../services/watermark.dart';
import '../../../services/api/music_api.dart';
import '../../../services/api/wallet_api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/tr.dart';
import 'montage_canvas.dart';
import 'montage_state.dart';
import 'montage_stickers.dart';

// Calques envoyés au serveur (studio_uploads/{uid}/{jobId}/) :
// base.jpg (photo + teintes) ou base.mp4 + under.png (teintes), fx_000…029.png (effet), top.png (textes, filigrane).

/// Sorties d'un montage : image fixe (JPEG), ou vidéo MP4 assemblée par le serveur (renderStudioMontage).
class MontageExport {
  MontageExport._();

  static const fxFrames = 30;
  static const fxFps = 10;

  /// Capture d'un calque en PNG à la largeur voulue.
  static Future<Uint8List> png(GlobalKey key, double width) async {
    RenderRepaintBoundary? b;
    for (var i = 0; i < 10 && b == null; i++) {
      final o = key.currentContext?.findRenderObject();
      if (o is RenderRepaintBoundary && o.hasSize) {
        b = o;
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    }
    if (b == null) throw StateError('Calque introuvable');
    await WidgetsBinding.instance.endOfFrame;
    final img = await b.toImage(pixelRatio: width / b.size.width);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    if (data == null) throw StateError('Capture impossible');
    return data.buffer.asUint8List();
  }


  /// Fin animée Afrolook : deux calques plein cadre, transparents, dessinés ici (texte traduit, police de l'application) ; le serveur fabrique le décor,
  /// le logo et l'animation, et les fait apparaître au bon moment. [W] × [H] = taille du film. Rend (widget du @pseudo, phrase et pastilles).
  static Future<(Uint8List, Uint8List)> outroLayers({required String pseudo, required String? avatarUrl, required int W, required int H}) async {
    const gold = Color(0xFFFFD21F);
    final k = W / 262.0;   // les mesures de la maquette validée sont données pour un écran de 262 px de large

    Future<ui.Image?> avatar() async {
      if (avatarUrl == null || avatarUrl.isEmpty) return null;
      try {
        final r = await http.get(Uri.parse(avatarUrl)).timeout(const Duration(seconds: 8));
        if (r.statusCode != 200) return null;
        final codec = await ui.instantiateImageCodec(r.bodyBytes, targetWidth: (34 * k).round());
        return (await codec.getNextFrame()).image;
      } catch (_) {
        return null;
      }
    }

    TextPainter text(String t, double size, FontWeight w, Color c, {double maxWidth = double.infinity}) {
      final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: c, fontSize: size * k, fontWeight: w, height: 1.15)), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…');
      tp.layout(maxWidth: maxWidth);
      return tp;
    }

    Future<Uint8List> finish(ui.PictureRecorder rec) async {
      final img = await rec.endRecording().toImage(W, H);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      return data!.buffer.asUint8List();
    }

    // 1) widget du @pseudo : pastille blanche, photo cerclée de jaune, pastille « @ », @pseudo
    final pillRec = ui.PictureRecorder();
    final pc = Canvas(pillRec);
    final name = text(pseudo, 13, FontWeight.w800, const Color(0xFF14201A), maxWidth: W * .52);
    final av = await avatar();
    final h = 40 * k;
    final w = (5 + 30 + 8 + 18 + 6) * k + name.width + 14 * k;
    final left = (W - w) / 2;
    final top = H * .72;
    pc.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), Radius.circular(h / 2)), Paint()..color = const Color(0xF5FFFFFF));
    final ac = Offset(left + (5 + 17.5) * k, top + h / 2);
    if (av != null) {
      pc.save();
      pc.clipPath(Path()..addOval(Rect.fromCircle(center: ac, radius: 15 * k)));
      pc.drawImageRect(av, Rect.fromLTWH(0, 0, av.width.toDouble(), av.height.toDouble()), Rect.fromCircle(center: ac, radius: 15 * k), Paint());
      pc.restore();
    } else {
      pc.drawCircle(ac, 15 * k, Paint()..color = gold);
      final ini = text(pseudo.isEmpty ? 'A' : pseudo.characters.first.toUpperCase(), 14, FontWeight.w900, const Color(0xFF3A2C00));
      ini.paint(pc, ac - Offset(ini.width / 2, ini.height / 2));
    }
    pc.drawCircle(ac, 16 * k, Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 2 * k);
    final badge = Offset(left + (5 + 30 + 8 + 9) * k, top + h / 2);
    pc.drawCircle(badge, 9 * k, Paint()..color = gold);
    final at = text('@', 11, FontWeight.w900, const Color(0xFF3A2C00));
    at.paint(pc, badge - Offset(at.width / 2, at.height / 2));
    name.paint(pc, Offset(left + (5 + 30 + 8 + 18 + 6) * k, top + (h - name.height) / 2));
    final pill = await finish(pillRec);
    av?.dispose();

    // 2) invitation et trois pastilles (cadeaux, lives, musique)
    final tagRec = ui.PictureRecorder();
    final tc = Canvas(tagRec);
    final a = text(tr('Rejoins-moi sur Afrolook'), 12, FontWeight.w700, const Color(0xFFFFFFFF), maxWidth: W * .9);
    a.paint(tc, Offset((W - a.width) / 2, H * .80));
    final b = text(tr('Fait sur Afrolook'), 10, FontWeight.w500, const Color(0xB3FFFFFF), maxWidth: W * .9);
    b.paint(tc, Offset((W - b.width) / 2, H * .80 + a.height + 2 * k));
    final cy = H * .89;
    final stroke = Paint()..color = const Color(0xFFFFFFFF)..style = PaintingStyle.stroke..strokeWidth = 1.9 * k..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < 3; i++) {
      final c = Offset(W / 2 + (i - 1) * 36 * k, cy);
      tc.drawCircle(c, 13 * k, Paint()..color = const Color(0x24FFFFFF));
      tc.drawCircle(c, 13 * k, Paint()..color = const Color(0x40FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 1 * k);
      if (i == 0) {            // cadeau
        tc.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(0, 1.5 * k), width: 12 * k, height: 8 * k), Radius.circular(1.2 * k)), stroke);
        tc.drawLine(c + Offset(0, -2.5 * k), c + Offset(0, 5.5 * k), stroke);
        tc.drawLine(c + Offset(-6 * k, 1.5 * k), c + Offset(6 * k, 1.5 * k), stroke);
        tc.drawArc(Rect.fromCenter(center: c + Offset(-2 * k, -3.5 * k), width: 4 * k, height: 3 * k), 0, 6.28, false, stroke);
        tc.drawArc(Rect.fromCenter(center: c + Offset(2 * k, -3.5 * k), width: 4 * k, height: 3 * k), 0, 6.28, false, stroke);
      } else if (i == 1) {     // live
        tc.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(-1.5 * k, 0), width: 11 * k, height: 8 * k), Radius.circular(1.5 * k)), stroke);
        tc.drawPath(Path()..moveTo(c.dx + 4.5 * k, c.dy - 1.5 * k)..lineTo(c.dx + 8 * k, c.dy - 3.5 * k)..lineTo(c.dx + 8 * k, c.dy + 3.5 * k)..lineTo(c.dx + 4.5 * k, c.dy + 1.5 * k)..close(), stroke);
      } else {                 // musique
        tc.drawPath(Path()..moveTo(c.dx - 2 * k, c.dy + 4 * k)..lineTo(c.dx - 2 * k, c.dy - 5 * k)..lineTo(c.dx + 5 * k, c.dy - 6.5 * k)..lineTo(c.dx + 5 * k, c.dy + 2 * k), stroke);
        tc.drawCircle(c + Offset(-4 * k, 4.5 * k), 2.2 * k, stroke);
        tc.drawCircle(c + Offset(3 * k, 2.5 * k), 2.2 * k, stroke);
      }
    }
    final tag = await finish(tagRec);
    return (pill, tag);
  }

  static Future<Uint8List> jpeg(Uint8List png, int width, {int quality = 90}) async {
    try {
      return await FlutterImageCompress.compressWithList(png, minWidth: width, minHeight: width, quality: quality, format: CompressFormat.jpeg);
    } catch (_) {
      return png;
    }
  }

  static Future<File> tempFile(List<int> bytes, String ext) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/montage_${DateTime.now().microsecondsSinceEpoch}.$ext').writeAsBytes(bytes, flush: true);
  }

  static Future<File> assetToFile(String asset, String ext) async {
    final data = await rootBundle.load(asset);
    return tempFile(data.buffer.asUint8List(), ext);
  }

  /// Enregistre le montage (image ou vidéo) dans la galerie du téléphone, album « Afrolook ».
  static Future<bool> saveToGallery(File f, {required bool video}) async {
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        if (!await Gal.requestAccess(toAlbum: true)) return false;
      }
      if (video) {
        await Gal.putVideo(f.path, album: 'Afrolook');
      } else {
        await Gal.putImage(f.path, album: 'Afrolook');
      }
      return true;
    } on GalException {
      return false;
    }
  }

  /// Image fixe prête à publier (1080 px de large).
  static Future<File> still(MontageKeys keys, {String? pseudo}) async {
    final p = await png(keys.all, 1080);
    final bytes = await jpeg(p, 1080);
    // image créée dans le Studio : signée « Afrolook + @pseudo » (pastille fixe en bas à droite)
    return tempFile(pseudo == null ? bytes : await Watermark.signImageBytes(bytes, pseudo), 'jpg');
  }

  /// Vidéo prête à publier. [setT] fige l'animation à l'instant demandé et attend le dessin.
  static Future<File> video({
    required MontageKeys keys,
    required MontageState s,
    required String? videoPath,
    required String? videoAsset,
    required Future<void> Function(double t) setT,
    required void Function(String step) onStep,
    required int maxSeconds,
    void Function(int coins)? onPaid,
    void Function(String jobId)? onJob,
    String? jobId0,
    String? outroPseudo,
    String? outroAvatarUrl,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Connecte-toi pour créer une vidéo.');
    // même identifiant de montage à chaque nouvel essai : un son déjà payé pour ce montage n'est jamais débité une deuxième fois
    final jobId = jobId0 ?? const Uuid().v4().replaceAll('-', '').substring(0, 20);
    onJob?.call(jobId);
    final uploads = <String, Future<String>>{};
    void up(String name, Uint8List bytes, String type) => uploads[name] = ArgentUpload.bytes(bytes, contentType: type);

    onStep('Préparation du fond…');
    final isVideo = s.hasVideo;
    if (isVideo) {
      final f = videoPath != null ? File(videoPath) : await assetToFile(videoAsset!, 'mp4');
      up('base.mp4', await f.readAsBytes(), 'video/mp4');
      up('under.png', await png(keys.underlay, 540), 'image/png');
    } else {
      up('base.jpg', await jpeg(await png(keys.background, 720), 720, quality: 88), 'image/jpeg');
    }

    var frames = 0;
    if (s.animated && s.fxActive) {
      for (var i = 0; i < fxFrames; i++) {
        onStep('Animation ${i + 1}/$fxFrames…');
        await setT(i / fxFrames);
        up('fx_${i.toString().padLeft(3, '0')}.png', await png(keys.fx, 540), 'image/png');
      }
      frames = fxFrames;
    }
    await setT(.3);
    onStep('Textes et décor…');
    // messages affichés seulement un temps (vidéo) : un calque image par message, le calque principal n'en contient aucun
    final timedStickers = isVideo ? s.stickers.where((e) => e.timed).take(8).toList() : <MontageSticker>[];
    final timedMeta = <Map<String, dynamic>>[];
    try {
      s.exportExcludeTimed = timedStickers.isNotEmpty;
      if (timedStickers.isNotEmpty) await setT(.3);
      up('top.png', await png(keys.foreground, 720), 'image/png');
      for (var i = 0; i < timedStickers.length; i++) {
        s.exportOnlySticker = timedStickers[i].id;
        await setT(.3);
        up('timed_$i.png', await png(keys.foreground, 720), 'image/png');
        timedMeta.add({'key': 'timed_$i.png', 'start': timedStickers[i].startSec, 'end': timedStickers[i].endSec});
      }
    } finally {
      s.exportOnlySticker = null;
      s.exportExcludeTimed = false;
      if (timedStickers.isNotEmpty) await setT(.3);
    }

    // fin animée Afrolook (vidéo seulement) : le @pseudo et l'invitation sont dessinés ici, le serveur fait le reste
    final wantOutro = isVideo && s.outro;
    if (wantOutro) {
      try {
        final l = await outroLayers(pseudo: outroPseudo ?? '', avatarUrl: outroAvatarUrl, W: 720, H: s.post ? 900 : 1280);
        up('outro_pill.png', l.$1, 'image/png');
        up('outro_tag.png', l.$2, 'image/png');
      } catch (_) {}   // sans ces calques, le serveur n'ajoute pas la fin : la vidéo reste valable
    }
    // filigrane mobile « Afrolook + @pseudo » (change de coin comme sur TikTok), posé par le serveur sur toute vidéo du Studio
    if (isVideo) {
      try {
        up('wm.png', await Watermark.pillPng(outroPseudo ?? ''), 'image/png');
      } catch (_) {}
    }

    onStep('Envoi…');
    final ids = <String, String>{};
    for (final e in uploads.entries) {
      ids[e.key] = await e.value;
    }

    // Son d'un artiste : payé (ou tracé s'il est gratuit) par l'API avant le montage, avec l'identifiant du montage
    var paid = 0;
    final m = s.music;
    if (m != null && m.isArtist) {
      if (m.paid && m.useCoins > 0) {
        // un son déjà acheté (ou déjà réglé) ne se paie pas une deuxième fois : le serveur le trace sans débit ; sinon (402) on le paie maintenant
        var covered = false;
        try {
          await MusicApi.freeUse(m.id, jobId);
          covered = true;
        } on ApiException catch (e) {
          if (e.status != 402) rethrow;
        }
        if (!covered) {
          await MusicApi.buyUse(m.id, jobId);
          paid = m.useCoins;
        }
      } else {
        await MusicApi.freeUse(m.id, jobId);
      }
      if (paid > 0) onPaid?.call(paid);
    }

    onStep('Montage de la vidéo…');
    // POST /studio/montages : montage assemblé par le serveur (ffmpeg), calques envoyés par /uploads
    final res = await ApiGateway.instance.client.post('/studio/montages', body: {
      'job_id': jobId,
      'uploads': ids,
      'base_type': isVideo ? 'video' : 'image',
      'fx_frames': frames,
      'fx_fps': fxFps,
      'format': s.post ? 'post' : 'story',
      'max_seconds': maxSeconds,
      'saturation': s.saturation,
      'brightness': s.brightness,
      'has_under': isVideo,
      if (isVideo) 'outro': s.outro,
      if (timedMeta.isNotEmpty) 'timed': timedMeta,
      if (isVideo && s.pins.isNotEmpty) 'pins': [for (final p in s.pins.take(2)) p.toApi()],
      if (m != null) 'music': {'type': m.type, 'id': m.id, 'start_ms': s.musicStartMs, 'volume': s.musicVolume},
      'keep_audio': s.keepVideoAudio,
      if (s.keepVideoAudio) 'video_volume': s.videoVolume,
      if (s.keepVideoAudio && s.duckMusic) 'duck': true,
      if (!isVideo && m != null) 'seconds': s.musicSeconds.clamp(5, maxSeconds),
    }, idempotencyKey: 'montage:$jobId:${const Uuid().v4().substring(0, 8)}');   // une clé par essai : un échec n'est jamais rejoué à la place d'un nouvel essai
    final url = WalletApi.map(res)['url'] as String;

    onStep('Téléchargement…');
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw StateError('Téléchargement impossible');
    return tempFile(r.bodyBytes, 'mp4');
  }
}
