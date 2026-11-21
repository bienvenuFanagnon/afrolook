import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/api/jeux_api.dart';
import '../../services/api/post_mapper.dart';
import '../../theme/app_colors.dart';
import '../create/chronique_flow.dart';
import '../postDetails.dart';
import '../post_video_format_tel_details.dart';
import 'chronique_preview.dart';
import 'chroniqueform.dart' show ChroniqueType;

/// Post partagé en chronique (décision du propriétaire, 21/11/2026), comme sur TikTok et Facebook : la chronique montre un extrait (30 s au plus,
/// passage choisi par la personne) et un bouton « Voir le post complet ». On peut partager ses posts et ceux des autres ; les vues venues du
/// bouton comptent pour le post (ouverture normale du post).
class ChroniqueLinkedPost {
  ChroniqueLinkedPost._();

  static String? _id;

  static void set(String? id) => _id = id;

  /// À la publication : le post lié en attente, puis effacé (une seule chronique).
  static String? take() {
    final v = _id;
    _id = null;
    return v;
  }
}

/// Ouvre le post complet (vidéo verticale pour une vidéo, page du post sinon).
Future<void> openLinkedPost(BuildContext context, String postId) async {
  try {
    final post = postFromApi(JeuxApi.map(await JeuxApi.client.get('/posts/$postId')));
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => post.dataType == 'VIDEO' ? PostDetailsVideoFormatTel(initialPost: post) : DetailsPost(post: post),
    ));
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.tr('Ce post n\'est plus disponible.'))));
  }
}

/// Carte posée sur la chronique : « Post de @auteur » et le bouton « Voir le post complet ».
class ChroniqueLinkedPostCard extends StatelessWidget {
  const ChroniqueLinkedPostCard({super.key, required this.linked, this.onOpen});

  final Map<String, dynamic> linked;

  /// Appelé avant d'ouvrir le post (par exemple pour mettre la chronique en pause).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final author = (linked['author'] as Map?) ?? const {};
    final username = '${author['username'] ?? ''}';
    final id = '${linked['id'] ?? ''}';
    return GestureDetector(
      onTap: id.isEmpty
          ? null
          : () {
              onOpen?.call();
              openLinkedPost(context, id);
            },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 9, 9),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .62), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
        child: Row(children: [
          const Icon(Icons.article_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(
            username.isEmpty ? context.tr('Extrait d\'un post') : context.tr('Extrait d\'un post de @{a}', {'a': username}),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
          )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xFFFFD400), borderRadius: BorderRadius.circular(10)),
            child: Text(context.tr('Voir le post complet'), style: const TextStyle(color: Color(0xFF121212), fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

/// « Partager en chronique » depuis le menu d'un post : vidéo (passage de 30 s au plus choisi par la personne), image, ou texte ; aperçu, puis publication
/// avec le lien vers le post. Jamais depuis le web (rien ne se publie depuis /app/).
Future<void> shareAsChronique(BuildContext context, Post post) async {
  if (kIsWeb || post.id == null) return;
  final c = AppColors.of(context);
  final type = post.dataType == 'VIDEO'
      ? ChroniqueType.VIDEO
      : (post.dataType == 'IMAGE' && ((post.images?.isNotEmpty ?? false) || (post.url_media?.isNotEmpty ?? false)) ? ChroniqueType.IMAGE : ChroniqueType.TEXT);
  final text = (post.description ?? '').trim();
  if (type == ChroniqueType.TEXT && text.isEmpty) return;

  File? media;
  VideoPlayerController? vc;
  if (type != ChroniqueType.TEXT) {
    final url = type == ChroniqueType.VIDEO ? post.url_media : ((post.images?.isNotEmpty ?? false) ? post.images!.first : post.url_media);
    if (url == null || url.isEmpty) return;
    // téléchargement du média du post (fenêtre d'attente)
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.accent)),
              const SizedBox(width: 14),
              Material(color: Colors.transparent, child: Text(context.tr('Préparation de la chronique…'), style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      ),
    );
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 3));
      if (r.statusCode != 200) throw StateError('téléchargement');
      final dir = await getTemporaryDirectory();
      media = await File('${dir.path}/chronique_post_${DateTime.now().millisecondsSinceEpoch}.${type == ChroniqueType.VIDEO ? 'mp4' : 'jpg'}').writeAsBytes(r.bodyBytes, flush: true);
    } catch (_) {
      media = null;
    }
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (media == null) {
      if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.tr('Impossible de récupérer le média de ce post. Réessaie.'))));
      return;
    }
    if (type == ChroniqueType.VIDEO) {
      vc = VideoPlayerController.file(media);
      try {
        await vc.initialize();
      } catch (_) {
        await vc.dispose();
        vc = null;
      }
      // vidéo de plus de 30 s : la personne choisit le passage montré dans la chronique
      if (vc != null && vc.value.duration.inSeconds > ChroniqueFlow.maxVideoSeconds + 1) {
        final totalMs = vc.value.duration.inMilliseconds;
        await vc.dispose();
        vc = null;
        if (!context.mounted) return;
        final cut = await ChroniqueFlow.cutToMax(context, media, totalMs);
        if (cut == null) return;
        media = cut;
        vc = VideoPlayerController.file(media);
        try {
          await vc.initialize();
        } catch (_) {
          await vc.dispose();
          vc = null;
        }
      }
    }
  }
  if (!context.mounted) {
    await vc?.dispose();
    return;
  }

  // aperçu, puis publication avec le lien vers le post complet
  final caption = type == ChroniqueType.TEXT ? (text.length > 2000 ? text.substring(0, 2000) : text) : '';
  final me = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ChroniquePreviewPage(
      type: type,
      pseudo: me.pseudo ?? '',
      avatarUrl: me.imageUrl,
      text: caption,
      backgroundColor: type == ChroniqueType.TEXT ? const Color(0xFF1B8A3C) : null,
      mediaFile: media,
      videoController: vc,
    ),
  ));
  await vc?.dispose();
  if (ok != true || !context.mounted) return;
  ChroniqueLinkedPost.set(post.id);
  final published = await ChroniquePublisher.publish(context, type: type, text: caption, media: media);
  if (!published) ChroniqueLinkedPost.set(null);
}
