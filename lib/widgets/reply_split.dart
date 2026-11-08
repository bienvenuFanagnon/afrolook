import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../pages/studio/montage/montage_state.dart';

/// Disposition choisie pour une réponse en vidéo (caméra, puis Studio) : `tb` haut/bas, `sbs` côte à côte, `bar` bandeau ; null = plein écran (vidéo épinglée dans un coin).
class ReplyLayout {
  ReplyLayout._();

  static final ValueNotifier<String?> id = ValueNotifier<String?>(null);
  static final ValueNotifier<bool> swap = ValueNotifier<bool>(false);

  static void clear() {
    id.value = null;
    swap.value = false;
  }
}

/// Aperçu en direct d'une réponse à deux vidéos : la vidéo d'origine (muette, jouée au début de l'enregistrement) dans sa place, et la caméra dans l'autre, cadrée comme le serveur
/// la recadrera (le centre de l'image remplit la place). [camera] est l'aperçu plein cadre de la caméra, au format 9:16.
class ReplySplitPreview extends StatefulWidget {
  const ReplySplitPreview({super.key, required this.camera, required this.videoUrl, required this.layout, required this.swap, required this.recording});

  final Widget camera;
  final String videoUrl;
  final String layout;
  final bool swap;
  final bool recording;

  @override
  State<ReplySplitPreview> createState() => _ReplySplitPreviewState();
}

class _ReplySplitPreviewState extends State<ReplySplitPreview> {
  VideoPlayerController? _v;

  @override
  void initState() {
    super.initState();
    final v = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _v = v;
    v.initialize().then((_) async {
      await v.setVolume(0);
      await v.setLooping(true);
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  @override
  void didUpdateWidget(ReplySplitPreview old) {
    super.didUpdateWidget(old);
    final v = _v;
    if (v == null || !v.value.isInitialized || old.recording == widget.recording) return;
    if (widget.recording) {
      v.seekTo(Duration.zero).then((_) => v.play());
    } else {
      v.pause();
    }
  }

  @override
  void dispose() {
    _v?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = montageLayoutFracs(widget.layout, widget.swap, 9 / 16);
    if (f == null) return widget.camera;
    final v = _v;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      Rect px(Rect r) => Rect.fromLTWH(r.left * w, r.top * h, r.width * w, r.height * h);
      final o = px(f.origin), m = px(f.me);
      return Stack(children: [
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        Positioned.fromRect(
          rect: o,
          child: ClipRect(
            child: (v != null && v.value.isInitialized)
                ? FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: v.value.size.width, height: v.value.size.height, child: VideoPlayer(v)))
                : const Center(child: CircularProgressIndicator(color: Colors.white54)),
          ),
        ),
        // la caméra : plein cadre, centrée sur sa place puis coupée à cette place
        Positioned.fromRect(
          rect: m,
          child: ClipRect(
            child: OverflowBox(
              minWidth: w,
              maxWidth: w,
              minHeight: h,
              maxHeight: h,
              child: widget.camera,   // centré dans sa place par OverflowBox : le centre de la caméra tombe au centre de la place
            ),
          ),
        ),
      ]);
    });
  }
}
