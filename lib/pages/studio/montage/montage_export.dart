import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'dart:io';
import 'dart:ui' as ui;

import '../../../services/api/api_gateway.dart';
import '../../../services/api/argent_upload.dart';
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


  /// Fin animée Afrolook (version sobre, maquette validée le 07/11) : deux calques plein cadre, transparents, dessinés ici (texte traduit, police de l'application) ; le serveur fabrique le fond
  /// sombre, la silhouette blanche du logo et l'animation (et le QR de la publication au téléchargement), et les fait apparaître au bon moment. [W] × [H] = taille du film.
  /// [label] : « #canal » si la publication vient d'un canal, sinon « @pseudo ». Rend (« Afrolook » et capsule du nom, invitation et ligne « Gratuit · Gagne · Crée »).
  static Future<(Uint8List, Uint8List)> outroLayers({required String label, required int W, required int H}) async {
    final k = (W < H ? W : H) / 360.0;   // les mesures de la maquette sont données pour un film de 360 px sur son petit côté (720 px = deux fois plus)

    TextPainter text(String t, double size, FontWeight w, Color c, {double maxWidth = double.infinity}) {
      final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: c, fontSize: size * k, fontWeight: w, height: 1.0)), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…');
      tp.layout(maxWidth: maxWidth);
      return tp;
    }

    Future<Uint8List> finish(ui.PictureRecorder rec) async {
      final img = await rec.endRecording().toImage(W, H);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      return data!.buffer.asUint8List();
    }

    // 1) « Afrolook » puis la capsule au contour fin avec le nom (#canal ou @pseudo)
    final pillRec = ui.PictureRecorder();
    final pc = Canvas(pillRec);
    final brand = text('Afrolook', 19, FontWeight.w800, const Color(0xFFFFFFFF));
    brand.paint(pc, Offset((W - brand.width) / 2, H * .70 - 15 * k));
    final capW = W * .6;
    final capH = 34 * k;
    final capTop = H * .735;
    pc.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(W * .2, capTop, capW, capH), Radius.circular(capH / 2)), Paint()..color = const Color(0x8CFFFFFF)..style = PaintingStyle.stroke..strokeWidth = 1.2 * k);
    if (label.trim().isNotEmpty) {
      final name = text(label.trim(), 14, FontWeight.w700, const Color(0xFFFFFFFF), maxWidth: capW - 20 * k);
      name.paint(pc, Offset((W - name.width) / 2, capTop + (capH - name.height) / 2));
    }
    final pill = await finish(pillRec);

    // 2) invitation et ligne de promesses
    final tagRec = ui.PictureRecorder();
    final tc = Canvas(tagRec);
    final a = text(tr('Rejoins-nous sur Afrolook'), 12, FontWeight.w500, const Color(0xCCFFFFFF), maxWidth: W * .9);
    final inviteTop = capTop + capH + 20 * k;   // de l'air sous la capsule du nom, sur tous les formats
    a.paint(tc, Offset((W - a.width) / 2, inviteTop));
    final b = text(tr('Gratuit  ·  Gagne  ·  Crée'), 11, FontWeight.w500, const Color(0x8CFFFFFF), maxWidth: W * .9);
    b.paint(tc, Offset((W - b.width) / 2, inviteTop + a.height + 8 * k));
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
  static Future<File> still(MontageKeys keys) async {
    final p = await png(keys.all, 1080);
    return tempFile(await jpeg(p, 1080), 'jpg');
  }

  /// Attend la fin d'un montage lancé en mode asynchrone : « running » → on patiente, « done » → l'adresse de la vidéo, « failed » → l'erreur du serveur (message précis).
  static Future<String> _waitForMontage(String jobId, void Function(String step) onStep) async {
    final deadline = DateTime.now().add(const Duration(minutes: 10));
    var misses = 0;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      Map<String, dynamic> st;
      try {
        st = WalletApi.map(await ApiGateway.instance.client.get('/studio/montages/$jobId'));
        misses = 0;
      } on ApiException catch (e) {
        if (e.status == 404) throw ApiException(status: 404, code: 'montage_failed', message: 'Le montage a été perdu côté serveur. Réessaie.');
        if (++misses >= 5) rethrow;   // réseau instable : quelques ratés sont tolérés
        continue;
      }
      switch (st['status']) {
        case 'done':
          final data = st['data'];
          final url = data is Map ? (data['url'] ?? (data['data'] is Map ? (data['data'] as Map)['url'] : null)) : null;
          if (url is String && url.isNotEmpty) return url;
          throw ApiException(status: 500, code: 'montage_failed', message: 'Le montage est terminé mais la vidéo est introuvable. Réessaie.');
        case 'failed':
          throw ApiException(status: (st['http'] as num?)?.toInt() ?? 500, code: '${st['code'] ?? 'montage_failed'}', message: '${st['message'] ?? 'Le montage a échoué.'}');
        default:
          onStep('Montage de la vidéo…');
      }
    }
    throw ApiException(status: 504, code: 'montage_timeout', message: 'Le montage prend trop de temps. Réessaie avec une vidéo plus courte.');
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
    String? outroLabel,
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

    // fin animée Afrolook (vidéo seulement) : le nom (#canal ou @pseudo) et l'invitation sont dessinés ici, le serveur fait le reste
    final wantOutro = isVideo && s.outro;
    if (wantOutro) {
      try {
        final sz = s.filmSize;
        final l = await outroLayers(label: outroLabel ?? '', W: sz.$1, H: sz.$2);
        up('outro_pill.png', l.$1, 'image/png');
        up('outro_tag.png', l.$2, 'image/png');
      } catch (_) {}   // sans ces calques, le serveur n'ajoute pas la fin : la vidéo reste valable
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
      'async': true,   // le serveur répond tout de suite et travaille ensuite : l'avancement se lit ci-dessous (aucune limite de durée de requête)
      'job_id': jobId,
      'uploads': ids,
      'base_type': isVideo ? 'video' : 'image',
      'fx_frames': frames,
      'fx_fps': fxFps,
      'format': s.format,
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
    }, idempotencyKey: 'montage:$jobId:${const Uuid().v4().substring(0, 8)}', longJob: true);   // une clé par essai : un échec n'est jamais rejoué à la place d'un nouvel essai
    final first = WalletApi.map(res);
    // ancien serveur : la vidéo est déjà prête dans la réponse ; sinon on attend la fin du montage en demandant l'avancement toutes les 2 secondes
    final url = first['url'] is String ? first['url'] as String : await _waitForMontage(jobId, onStep);

    onStep('Téléchargement…');
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw StateError('Téléchargement impossible');
    return tempFile(r.bodyBytes, 'mp4');
  }
}
