import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/music_likes.dart';
import '../../services/music_queue.dart';
import '../../services/stream_counts.dart';

/// Cœur « j'aime » d'un titre avec son nombre, en direct ; un toucher aime ou n'aime plus. Affiché partout où un titre apparaît, à côté des écoutes
/// ([StreamsText]). Le cœur devient rouge quand on a aimé, et rebondit au toucher.
class MusicLikeButton extends StatefulWidget {
  const MusicLikeButton({super.key, required this.track, required this.color, this.fontSize = 11, this.weight = FontWeight.w600});
  final MusicTrack track;
  final Color color;
  final double fontSize;
  final FontWeight weight;

  @override
  State<MusicLikeButton> createState() => _MusicLikeButtonState();
}

class _MusicLikeButtonState extends State<MusicLikeButton> {
  bool _pulse = false;

  @override
  void initState() {
    super.initState();
    MusicLikes.start();
    StreamCounts.listen(widget.track);
  }

  @override
  void didUpdateWidget(MusicLikeButton old) {
    super.didUpdateWidget(old);
    if (old.track.key != widget.track.key) {
      StreamCounts.release(old.track);
      StreamCounts.listen(widget.track);
    }
  }

  @override
  void dispose() {
    StreamCounts.release(widget.track);
    super.dispose();
  }

  void _tap() {
    HapticFeedback.selectionClick();
    setState(() => _pulse = true);
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _pulse = false);
    });
    MusicLikes.toggle(widget.track);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: MusicLikes.keys,
      builder: (_, __, ___) => ValueListenableBuilder<Map<String, int>>(
        valueListenable: StreamCounts.likes,
        builder: (_, __, ___) {
          final liked = MusicLikes.isLiked(widget.track);
          final n = StreamCounts.likesOf(widget.track);
          final tint = liked ? const Color(0xFFFF4D6D) : widget.color;
          return InkWell(
            onTap: _tap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedScale(
                  scale: _pulse ? 1.3 : 1,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  child: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: widget.fontSize + 4, color: tint),
                ),
                const SizedBox(width: 3),
                Flexible(child: Text(MusicLikes.fmt(n), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tint, fontSize: widget.fontSize, fontWeight: widget.weight))),
              ]),
            ),
          );
        },
      ),
    );
  }
}
