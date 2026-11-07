import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/model_data.dart';
import '../services/api/posts_api.dart';
import '../theme/app_colors.dart';

/// Ce à quoi la personne répond (quel que soit le type du post d'origine : texte, image, vidéo, audio).
class ReplyInfo {
  const ReplyInfo({required this.postId, required this.pseudo, required this.kind, required this.excerpt, this.thumbUrl});
  final String postId;
  final String pseudo;

  /// `video`, `image`, `audio` ou `text`.
  final String kind;
  final String excerpt;
  final String? thumbUrl;

  static ReplyInfo fromPost(Post p) {
    final type = (p.dataType ?? '').toUpperCase();
    final kind = type == PostDataType.VIDEO.name ? 'video' : type == PostDataType.IMAGE.name ? 'image' : type == PostDataType.AUDIO.name ? 'audio' : 'text';
    final firstImage = (p.images ?? const <String>[]).where((u) => u.trim().isNotEmpty).firstOrNull;
    final thumb = kind == 'video' ? p.thumbnail : (kind == 'image' ? (firstImage ?? p.url_media) : null);
    final text = (p.description ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    return ReplyInfo(postId: p.id ?? '', pseudo: (p.user?.pseudo ?? '').trim(), kind: kind, excerpt: text.length > 70 ? '${text.substring(0, 70)}…' : text, thumbUrl: (thumb ?? '').isEmpty ? null : thumb);
  }
}

/// Bandeau « Tu réponds à @pseudo » posé sur TOUS les écrans du parcours de réponse (caméra, éditeur, aperçu, nouveau post) : la personne sait à quelle publication elle répond
/// du début à la fin. Il se charge tout seul d'après l'identifiant mémorisé par [PostReplyLink] ; il n'affiche rien hors d'une réponse.
class ReplyBanner extends StatefulWidget {
  const ReplyBanner({super.key, this.dark = true});

  /// Sur une image (caméra, éditeur, aperçu) : fond sombre translucide et texte clair ; sinon couleurs du thème.
  final bool dark;

  /// Les informations de la publication à laquelle on répond (partagées par tous les écrans du parcours).
  static final ValueNotifier<ReplyInfo?> info = ValueNotifier<ReplyInfo?>(null);
  static String? _loadingFor;

  /// Charge (une fois) la publication d'origine. Sans effet si [postId] est vide ou déjà chargé.
  static Future<void> load(String? postId) async {
    if (postId == null || postId.isEmpty) {
      info.value = null;
      _loadingFor = null;
      return;
    }
    if (info.value?.postId == postId || _loadingFor == postId) return;
    _loadingFor = postId;
    try {
      final p = await PostsApi.get(postId);
      if (p != null && _loadingFor == postId) info.value = ReplyInfo.fromPost(p..id ??= postId);
    } catch (_) {
      // sans le détail, le bandeau reste simple : « Tu réponds à une publication »
      if (_loadingFor == postId) info.value = ReplyInfo(postId: postId, pseudo: '', kind: 'text', excerpt: '');
    } finally {
      if (_loadingFor == postId) _loadingFor = null;
    }
  }

  static void clear() {
    info.value = null;
    _loadingFor = null;
  }

  @override
  State<ReplyBanner> createState() => _ReplyBannerState();
}

class _ReplyBannerState extends State<ReplyBanner> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReplyInfo?>(
      valueListenable: ReplyBanner.info,
      builder: (context, i, _) {
        if (i == null) return const SizedBox.shrink();
        final c = AppColors.of(context);
        final fg = widget.dark ? Colors.white : c.textPrimary;
        final sub = widget.dark ? const Color(0xCCFFFFFF) : c.textSecondary;
        final icon = switch (i.kind) {
          'video' => Icons.videocam_rounded,
          'image' => Icons.photo_rounded,
          'audio' => Icons.graphic_eq_rounded,
          _ => Icons.notes_rounded,
        };
        final kindLabel = switch (i.kind) {
          'video' => context.tr('Vidéo'),
          'image' => context.tr('Image'),
          'audio' => context.tr('Audio'),
          _ => context.tr('Texte'),
        };
        return Container(
          key: const ValueKey('reply_banner'),
          padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
          decoration: BoxDecoration(
            color: widget.dark ? const Color(0xB3000000) : c.surface,
            borderRadius: BorderRadius.circular(14),
            border: widget.dark ? null : Border.all(color: c.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 36,
                height: 36,
                child: i.thumbUrl != null
                    ? Image.network(i.thumbUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: const Color(0x33FFFFFF), child: Icon(icon, color: fg, size: 18)))
                    : ColoredBox(color: widget.dark ? const Color(0x33FFFFFF) : c.surfaceVariant, child: Icon(icon, color: fg, size: 18)),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  i.pseudo.isEmpty ? context.tr('Tu réponds à une publication') : context.tr('Tu réponds à @{p}', {'p': i.pseudo}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
                Text(
                  i.excerpt.isEmpty ? kindLabel : '$kindLabel · ${i.excerpt}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: sub, fontSize: 11.5),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}
