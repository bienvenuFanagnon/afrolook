import 'package:flutter/material.dart';

import '../../services/music_queue.dart';
import '../../services/stream_counts.dart';

/// Nombre d'écoutes d'un titre (« 🎧 1,2 k écoutes »), en direct. Affiché partout où un titre apparaît.
class StreamsText extends StatefulWidget {
  const StreamsText({super.key, required this.track, required this.color, this.fontSize = 11, this.icon = true, this.weight = FontWeight.w600});
  final MusicTrack track;
  final Color color;
  final double fontSize;
  final bool icon;
  final FontWeight weight;

  @override
  State<StreamsText> createState() => _StreamsTextState();
}

class _StreamsTextState extends State<StreamsText> {
  @override
  void initState() {
    super.initState();
    StreamCounts.listen(widget.track);
  }

  @override
  void didUpdateWidget(StreamsText old) {
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

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Map<String, int>>(
        valueListenable: StreamCounts.counts,
        builder: (_, __, ___) => Row(mainAxisSize: MainAxisSize.min, children: [
          if (widget.icon) ...[
            Icon(Icons.headphones_rounded, size: widget.fontSize + 2, color: widget.color),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(StreamCounts.label(StreamCounts.of(widget.track)), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: widget.color, fontSize: widget.fontSize, fontWeight: widget.weight)),
          ),
        ]),
      );
}
