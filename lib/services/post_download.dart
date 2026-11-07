import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/admob_service.dart';
import '../ads/gold_gate.dart';
import '../l10n/tr.dart';
import '../models/model_data.dart';
import '../pages/studio/montage/montage_export.dart';
import '../providers/authProvider.dart';

/// Téléchargement du média d'une publication (vidéo, audio, images). Le propriétaire télécharge librement ; les autres regardent des pubs (3 par défaut) ou paient des pièces,
/// ou ont Gold. Une fois le fichier enregistré, une pub plein écran s'affiche si elle existe, sans jamais être obligatoire.
/// Les vidéos et les images créées dans le Studio portent la signature « Afrolook + @pseudo » de leur créateur : elle reste dans le fichier téléchargé.
class PostDownload {
  PostDownload._();

  /// Médias téléchargeables d'une publication : (adresse, nature).
  static List<({String url, String kind})> mediaOf(Post p) {
    final main = (p.url_media ?? '').trim();
    final images = [for (final u in (p.images ?? const <String>[])) if (u.trim().isNotEmpty) u.trim()];
    final type = (p.dataType ?? '').toUpperCase();
    if (type == PostDataType.IMAGE.name) {
      final all = images.isNotEmpty ? images : (main.isNotEmpty ? [main] : <String>[]);
      return [for (final u in all) (url: u, kind: 'image')];
    }
    if (main.isEmpty) return const [];
    if (type == PostDataType.AUDIO.name) return [(url: main, kind: 'audio')];
    if (type == PostDataType.VIDEO.name || main.contains('.mp4') || main.contains('.mov')) return [(url: main, kind: 'video')];
    return const [];
  }

  static bool canDownload(Post p) => mediaOf(p).isNotEmpty && p.isAdvertisement != true;

  static void _say(BuildContext context, String m) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  /// Lance le téléchargement : porte (propriétaire libre, sinon pubs / pièces / Gold), puis enregistrement dans la galerie (partage pour l'audio).
  static Future<void> start(BuildContext context, Post post) async {
    final items = mediaOf(post);
    if (items.isEmpty) {
      _say(context, context.tr('Cette publication n\'a aucun média à télécharger.'));
      return;
    }
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final me = auth.loginUserData;
    final owner = me.id != null && post.user_id == me.id;
    if (!owner) {
      if (post.id == null || !await GoldGate.download(context, me.id ?? '', postId: post.id!)) return;
      if (!context.mounted) return;
    }
    _say(context, context.tr('Téléchargement en cours…'));
    var saved = 0;
    String? audioPath;
    try {
      final dir = await getTemporaryDirectory();
      for (final it in items) {
        final r = await http.get(Uri.parse(auth.convertToCdnUrl(it.url, auth.appDefaultData))).timeout(const Duration(minutes: 3));
        if (r.statusCode != 200) continue;
        final ext = it.kind == 'video' ? 'mp4' : it.kind == 'audio' ? 'm4a' : 'jpg';
        final f = await File('${dir.path}/afrolook_${DateTime.now().microsecondsSinceEpoch}.$ext').writeAsBytes(r.bodyBytes, flush: true);
        if (it.kind == 'audio') {
          audioPath = f.path;
          saved++;
        } else if (await MontageExport.saveToGallery(f, video: it.kind == 'video')) {
          saved++;
        }
      }
    } catch (_) {
      if (context.mounted) _say(context, context.tr('Le téléchargement a échoué. Vérifie ta connexion et réessaie.'));
      return;
    }
    if (!context.mounted) return;
    if (audioPath != null) {
      await Share.shareXFiles([XFile(audioPath)], text: context.tr('Audio téléchargé depuis Afrolook'));
    }
    if (saved == 0) {
      _say(context, context.tr('Impossible d\'enregistrer : autorise l\'accès aux photos dans les réglages du téléphone.'));
      return;
    }
    _say(context, audioPath != null ? context.tr('Audio prêt : choisis où l\'enregistrer.') : context.tr('Téléchargé dans ta galerie (album Afrolook).'));
    // pub plein écran après le téléchargement, si elle existe : jamais obligatoire, jamais bloquante
    try {
      await AdmobService.showInterstitialAndWait(me, maxPerDay: 6, capKey: 'ad_inter_download', warmup: false);
    } catch (_) {}
  }
}
