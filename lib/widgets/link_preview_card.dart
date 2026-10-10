import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/tr.dart';

/// Première adresse web d'un texte (sans la ponctuation finale), ou null.
String? firstLinkIn(String? text) {
  final m = RegExp(r'https?://[^\s<>"\x27]+', caseSensitive: false).firstMatch(text ?? '');
  if (m == null) return null;
  return m.group(0)!.replaceAll(RegExp(r'[).,;:!?»”]+$'), '');
}

/// Demande à Afrolook (Cloud Function `fetchLinkPreview`) l'aperçu d'un lien : titre, description, image, auteur.
class LinkPreviewService {
  LinkPreviewService._();

  static final Map<String, Map<String, dynamic>?> _cache = {};

  /// Retourne l'aperçu, ou null si le lien n'en a pas ; lève une erreur si le serveur refuse ou ne répond pas.
  static Future<Map<String, dynamic>?> fetch(String url, {bool forCard = false}) async {
    final key = forCard ? 'card:$url' : url;
    if (_cache.containsKey(key)) return _cache[key];
    final res = await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('fetchLinkPreview', options: HttpsCallableOptions(timeout: const Duration(seconds: 25))).call({'url': url, if (forCard) 'purpose': 'card'});
    final raw = (res.data as Map?)?['preview'];
    final out = raw is Map ? Map<String, dynamic>.from(raw) : null;
    _cache[key] = out;
    return out;
  }
}

/// Carte d'aperçu d'un lien, comme sur un statut WhatsApp : image, site, titre, description. Un appui ouvre le lien.
/// Avec [onRemove], une croix permet de la retirer (page de création).
class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({super.key, required this.data, this.onRemove, this.margin = EdgeInsets.zero});

  final Map<String, dynamic> data;
  final VoidCallback? onRemove;
  final EdgeInsetsGeometry margin;

  String _s(String k) => (data[k] ?? '').toString();

  /// Un appui demande confirmation : le lien s'ouvre hors d'Afrolook (navigateur ou application du site : YouTube, TikTok…).
  Future<void> _open(BuildContext context) async {
    final u = Uri.tryParse(_s('url'));
    if (u == null || !(u.scheme == 'http' || u.scheme == 'https')) return;
    final site = _s('siteName').isNotEmpty ? _s('siteName') : u.host.replaceFirst('www.', '');
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.open_in_new_rounded),
        title: Text(ctx.tr('Quitter Afrolook ?')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ctx.tr('Tu vas être dirigé vers une autre application ou ton navigateur pour ouvrir ce lien ({site}).', {'site': site}), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(u.host.replaceFirst('www.', ''), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Continuer'))),
        ],
      ),
    );
    if (go != true) return;
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final url = Uri.tryParse(_s('url'));
    if (url == null || !(url.scheme == 'http' || url.scheme == 'https')) return const SizedBox.shrink();
    final image = _s('image');
    final title = _s('title');
    final desc = _s('description');
    final author = _s('author');
    final site = _s('siteName').isNotEmpty ? _s('siteName') : url.host.replaceFirst('www.', '');
    final isVideo = data['isVideo'] == true;
    const bg = Color(0xFF1B1D1F);
    return Padding(
      padding: margin,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (image.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(fit: StackFit.expand, children: [
                    CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2D30), child: Icon(Icons.link_rounded, color: Colors.white38, size: 40))),
                    if (isVideo)
                      Center(
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 1.5)),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                        ),
                      ),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(site.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF9AA0A6), fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.25)),
                  ],
                  if (author.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFBDC1C6), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                  if (desc.isNotEmpty && desc != title) ...[
                    const SizedBox(height: 4),
                    Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF9AA0A6), fontSize: 12, height: 1.3)),
                  ],
                  const SizedBox(height: 6),
                  Text(url.host.replaceFirst('www.', ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6F757B), fontSize: 11)),
                ]),
              ),
            ]),
            if (onRemove != null)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(width: 28, height: 28, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white, size: 18)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
