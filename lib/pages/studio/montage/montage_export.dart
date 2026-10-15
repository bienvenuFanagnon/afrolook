import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'montage_canvas.dart';
import 'montage_state.dart';

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

  /// Vidéo prête à publier. [setT] fige l'animation à l'instant demandé et attend le dessin.
  static Future<File> video({
    required MontageKeys keys,
    required MontageState s,
    required String? videoPath,
    required String? videoAsset,
    required Future<void> Function(double t) setT,
    required void Function(String step) onStep,
    required int maxSeconds,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Connecte-toi pour créer une vidéo.');
    final jobId = const Uuid().v4().replaceAll('-', '').substring(0, 20);
    final dir = FirebaseStorage.instance.ref('studio_uploads/$uid/$jobId');
    final uploads = <Future<void>>[];
    void up(String name, Uint8List bytes, String type) => uploads.add(dir.child(name).putData(bytes, SettableMetadata(contentType: type)).then((_) {}));

    onStep('Préparation du fond…');
    final isVideo = s.hasVideo;
    if (isVideo) {
      final f = videoPath != null ? File(videoPath) : await assetToFile(videoAsset!, 'mp4');
      uploads.add(dir.child('base.mp4').putFile(f, SettableMetadata(contentType: 'video/mp4')).then((_) {}));
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
    up('top.png', await png(keys.foreground, 720), 'image/png');

    onStep('Envoi…');
    await Future.wait(uploads);

    onStep('Montage de la vidéo…');
    final res = await FirebaseFunctions.instance
        .httpsCallable('renderStudioMontage', options: HttpsCallableOptions(timeout: const Duration(minutes: 5)))
        .call({
      'jobId': jobId,
      'baseType': isVideo ? 'video' : 'image',
      'fxFrames': frames,
      'fxFps': fxFps,
      'format': s.post ? 'post' : 'story',
      'maxSeconds': maxSeconds,
      'saturation': s.template.saturation,
      'brightness': s.template.brightness,
      'hasUnder': isVideo,
    });
    final url = (res.data as Map)['url'] as String;

    onStep('Téléchargement…');
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw StateError('Téléchargement impossible');
    return tempFile(r.bodyBytes, 'mp4');
  }
}
