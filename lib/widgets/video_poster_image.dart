import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/video_poster.dart';
import '../utils/media_cdn.dart';

/// Aperçu d'une vidéo, affiché tout de suite :
/// 1. l'image enregistrée à la création ([posterUrl], via le CDN, quelques Ko) ;
/// 2. sinon l'image déjà tirée de la vidéo (mémoire / disque) ;
/// 3. sinon elle est tirée de la vidéo une seule fois (2 à la fois au plus) pendant qu'on montre [placeholder].
class VideoPosterImage extends StatefulWidget {
  const VideoPosterImage({
    super.key,
    required this.cacheKey,
    this.posterUrl,
    this.videoUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  /// Identifiant stable de la vidéo (id du post / de la chronique).
  final String cacheKey;
  final String? posterUrl;
  final String? videoUrl;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  State<VideoPosterImage> createState() => _VideoPosterImageState();
}

class _VideoPosterImageState extends State<VideoPosterImage> {
  Uint8List? _bytes;

  bool get _hasPoster => (widget.posterUrl ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant VideoPosterImage old) {
    super.didUpdateWidget(old);
    if (old.cacheKey != widget.cacheKey || old.posterUrl != widget.posterUrl) {
      _bytes = null;
      _resolve();
    }
  }

  void _resolve() {
    if (_hasPoster) return;
    final url = widget.videoUrl;
    if (url == null || url.isEmpty) return;
    final key = widget.cacheKey;
    final hit = VideoPoster.peek(key);
    if (hit != null) {
      _bytes = hit;
      return;
    }
    VideoPoster.fromUrl(key, url).then((b) {
      if (mounted && b != null && widget.cacheKey == key) setState(() => _bytes = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final holder = widget.placeholder ?? const ColoredBox(color: Color(0xFF1A1A1A));
    if (_hasPoster) {
      return CachedNetworkImage(
        imageUrl: MediaCdn.url(widget.posterUrl),
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, __) => holder,
        errorWidget: (_, __, ___) => holder,
      );
    }
    if (_bytes != null) {
      return Image.memory(_bytes!, fit: widget.fit, width: double.infinity, height: double.infinity, gaplessPlayback: true);
    }
    return holder;
  }
}
