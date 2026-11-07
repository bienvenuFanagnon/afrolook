import 'dart:io';
import 'dart:typed_data';

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
import '../theme/app_colors.dart';
import 'api/studio_watermark_api.dart';
import 'watermark.dart';

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

  /// Feuille « Choisis les images à télécharger » : une grille de miniatures, toutes cochées au départ ; on décoche celles qu'on ne veut pas. Rend la sélection (dans l'ordre du post), null si on annule.
  @visibleForTesting
  static Future<List<({String url, String kind})>?> chooseImages(BuildContext context, List<({String url, String kind})> items, String Function(String url) cdn) {
    final chosen = <int>{for (var i = 0; i < items.length; i++) i};
    return showModalBottomSheet<List<({String url, String kind})>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final c = AppColors.of(ctx);
          return Container(
            key: const ValueKey('download_pick'),
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
            decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)))),
                  const SizedBox(height: 14),
                  Text(ctx.tr('Choisis les images à télécharger'), style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(ctx.tr('Chaque image téléchargée porte la signature Afrolook en bas.'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                  const SizedBox(height: 12),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                      itemBuilder: (_, i) {
                        final on = chosen.contains(i);
                        return GestureDetector(
                          key: ValueKey('pick_$i'),
                          onTap: () => setS(() => on ? chosen.remove(i) : chosen.add(i)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(fit: StackFit.expand, children: [
                              Image.network(cdn(items[i].url), fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: c.surfaceVariant, child: Icon(Icons.image_not_supported_outlined, color: c.textSecondary))),
                              if (!on) const ColoredBox(color: Color(0x88000000)),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: on ? c.accent : Colors.black45, border: Border.all(color: Colors.white, width: 1.5)),
                                  child: on ? Icon(Icons.check_rounded, size: 16, color: c.onAccent) : null,
                                ),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('Annuler')))),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        key: const ValueKey('download_go'),
                        onPressed: chosen.isEmpty ? null : () => Navigator.pop(ctx, [for (final i in (chosen.toList()..sort())) items[i]]),
                        style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent),
                        child: Text(ctx.tr('Télécharger {n}', {'n': '${chosen.length}'}), style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Lance le téléchargement : porte (propriétaire libre, sinon pubs / pièces / Gold), puis enregistrement dans la galerie (partage pour l'audio).
  static Future<void> start(BuildContext context, Post post) async {
    var items = mediaOf(post);
    if (items.isEmpty) {
      _say(context, context.tr('Cette publication n\'a aucun média à télécharger.'));
      return;
    }
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    // plusieurs images : la personne choisit celles qu'elle veut (avant la porte pubs / pièces : on ne paie que pour ce qu'on prend)
    if (items.length > 1 && items.every((i) => i.kind == 'image')) {
      final picked = await chooseImages(context, items, (u) => auth.convertToCdnUrl(u, auth.appDefaultData));
      if (picked == null || picked.isEmpty || !context.mounted) return;
      items = picked;
    }
    final me = auth.loginUserData;
    final owner = me.id != null && post.user_id == me.id;
    if (!owner) {
      if (post.id == null || !await GoldGate.download(context, me.id ?? '', postId: post.id!)) return;
      if (!context.mounted) return;
    }
    _say(context, context.tr('Téléchargement en cours…'));
    var saved = 0;
    var unsigned = 0;   // médias non livrés parce que la signature n'a pas pu être posée
    String? audioPath;
    try {
      final dir = await getTemporaryDirectory();
      for (final it in items) {
        var url = auth.convertToCdnUrl(it.url, auth.appDefaultData);
        // La signature Afrolook (logo + @pseudo du créateur) n'est PAS dans la vidéo ou l'image qu'on regarde dans l'application : elle est posée ici, sur la copie téléchargée (comme sur TikTok).
        // Vidéo : le serveur la pose (la vidéo signée change de coin) ; image : sur le téléphone. En cas d'échec, la copie est téléchargée sans signature : jamais de blocage.
        final pseudo = post.user?.pseudo ?? '';
        if (it.kind == 'video') {
          if (post.id == null) continue;
          try {
            url = await StudioWatermarkApi.signedDownload(post.id!, await Watermark.pillPng(pseudo));
          } catch (_) {
            unsigned++;
            continue;   // tout ce qui sort d'Afrolook est signé : sans signature, pas de fichier
          }
        }
        final r = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 3));
        if (r.statusCode != 200) continue;
        final ext = it.kind == 'video' ? 'mp4' : it.kind == 'audio' ? 'm4a' : 'jpg';
        Uint8List bytes = r.bodyBytes;
        if (it.kind == 'image') {
          try {
            bytes = await Watermark.signImageBytes(r.bodyBytes, pseudo, strict: true);
          } catch (_) {
            unsigned++;
            continue;
          }
        }
        final f = await File('${dir.path}/afrolook_${DateTime.now().microsecondsSinceEpoch}.$ext').writeAsBytes(bytes, flush: true);
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
    if (saved == 0 && unsigned > 0) {
      _say(context, context.tr('La signature Afrolook n\'a pas pu être ajoutée : réessaie dans un instant.'));
      return;
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
