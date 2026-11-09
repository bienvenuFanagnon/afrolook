import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../l10n/tr.dart';
import '../models/post_widget.dart';
import '../theme/app_colors.dart';
import 'post_widget_view.dart';
import 'widgets_sheet.dart';

/// Calque des widgets en cours d'ajout (sondage, question, lien…) posé sur le média : UN SEUL composant pour l'éditeur de création ET le Studio de montage,
/// pour que les widgets restent visibles, déplaçables et supprimables partout, quel que soit le média choisi ou modifié.
/// On glisse pour déplacer, on pince pour redimensionner ; toucher le widget ou son bouton « ⋮ » ouvre ses options (taille − / +, durée, modifier, supprimer).
class DraftWidgetsLayer extends StatefulWidget {
  const DraftWidgetsLayer({super.key, this.mediaAspect, this.videoSeconds, this.onBeforeChange});

  /// Format réel du média affiché en entier (largeur / hauteur) ; null = le calque occupe tout l'espace.
  final double? mediaAspect;

  /// Durée de la vidéo en secondes, ou null si le média n'est pas une vidéo (ou pas encore lue) : sert au réglage « Visible de… à… ».
  final double? Function()? videoSeconds;

  /// Appelé juste avant une modification (pour garder l'état précédent et pouvoir annuler).
  final VoidCallback? onBeforeChange;

  @override
  State<DraftWidgetsLayer> createState() => _DraftWidgetsLayerState();
}

class _DraftWidgetsLayerState extends State<DraftWidgetsLayer> {
  PostWidget? _sel;
  double _scaleStart = 1;

  void _refresh() => PostWidgetsLink.drafts.value = [...PostWidgetsLink.drafts.value];

  void _scale(PostWidget w, double delta) {
    w.scale = (w.scale + delta).clamp(.6, 1.6);
    _refresh();
  }

  Future<void> _edit(PostWidget w) async {
    final n = await editWidget(context, w.kind, existing: w);
    if (n != null) {
      widget.onBeforeChange?.call();
      PostWidgetsLink.replace(w, n);
      if (mounted) setState(() => _sel = n);
    }
  }

  void _delete(PostWidget w) {
    widget.onBeforeChange?.call();
    PostWidgetsLink.remove(w);
    setState(() => _sel = null);
  }

  /// « Visible de… à… » : le widget n'apparaît que dans cette partie de la vidéo (par défaut, toute la durée).
  Future<void> _editRange(PostWidget w) async {
    final total = widget.videoSeconds?.call() ?? 0;
    if (total < 1) return;
    var range = RangeValues((w.start ?? 0).clamp(0, total).toDouble(), (w.end ?? total).clamp(0, total).toDouble());
    final c = AppColors.of(context);
    final res = await showDialog<RangeValues?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: c.surface,
          title: Text(context.tr('Visible de… à…'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${range.start.toStringAsFixed(1)} s  →  ${range.end.toStringAsFixed(1)} s', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700)),
            RangeSlider(key: const ValueKey('range_slider'), values: range, min: 0, max: total, divisions: (total * 2).round().clamp(1, 600), onChanged: (r) => setS(() => range = r)),
          ]),
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            TextButton(key: const ValueKey('range_all'), onPressed: () => Navigator.pop(ctx, const RangeValues(-1, -1)), child: Text(context.tr('Toute la durée'))),
            TextButton(key: const ValueKey('range_ok'), onPressed: () => Navigator.pop(ctx, range), child: Text(context.tr('Valider'))),
          ],
        ),
      ),
    );
    if (res == null) return;
    widget.onBeforeChange?.call();
    if (res.start < 0 || (res.start <= 0.05 && res.end >= total - 0.05)) {
      w.start = null;
      w.end = null;
    } else {
      w.start = res.start;
      w.end = (res.end - res.start) < 0.5 ? res.start + 0.5 : res.end;
    }
    _refresh();
  }

  /// Options d'un widget (feuille du bas, sûre au toucher) : taille − / +, « Visible de… à… » (vidéo), modifier, supprimer.
  /// Elles s'ouvrent en touchant le widget ou son bouton « ⋮ ». Ce bouton n'existe que dans ce calque d'édition : il n'est dans aucun rendu (montage, téléchargement, publication).
  Future<void> _options(PostWidget w) async {
    final c = AppColors.of(context);
    final hasVideo = (widget.videoSeconds?.call() ?? 0) >= 1;
    setState(() => _sel = w);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Widget row(Key k, IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
                key: k,
                leading: Icon(icon, color: color ?? c.textPrimary),
                title: Text(context.tr(label), style: TextStyle(color: color ?? c.textPrimary, fontWeight: FontWeight.w700)),
                onTap: onTap,
              );
          return SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Container(width: 38, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 6),
              ListTile(
                leading: Icon(Icons.aspect_ratio_rounded, color: c.textPrimary),
                title: Text(context.tr('Taille'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(key: const ValueKey('wm_smaller'), icon: const Icon(Icons.remove_circle_outline_rounded), color: c.textPrimary, iconSize: 30, onPressed: () => setS(() => _scale(w, -.15))),
                  IconButton(key: const ValueKey('wm_bigger'), icon: const Icon(Icons.add_circle_outline_rounded), color: c.textPrimary, iconSize: 30, onPressed: () => setS(() => _scale(w, .15))),
                ]),
              ),
              if (hasVideo)
                row(const ValueKey('wm_range'), Icons.timelapse_rounded, 'Visible de… à…', () {
                  Navigator.pop(ctx);
                  _editRange(w);
                }, color: (w.start != null || w.end != null) ? c.accentText : null),
              row(const ValueKey('wm_edit'), Icons.edit_rounded, 'Modifier', () {
                Navigator.pop(ctx);
                _edit(w);
              }),
              row(const ValueKey('wm_delete'), Icons.delete_outline_rounded, 'Supprimer', () {
                Navigator.pop(ctx);
                _delete(w);
              }, color: Colors.redAccent),
              const SizedBox(height: 8),
            ]),
          );
        },
      ),
    );
  }

  /// Le bouton « ⋮ » posé sur chaque widget (coin haut droit, dans sa zone touchable). Il garde une taille fixe quel que soit l'agrandissement du widget.
  Widget _dots(PostWidget w, int index) => Transform.scale(
        scale: 1 / w.scale,
        alignment: Alignment.topRight,
        child: GestureDetector(
          key: ValueKey('wm_dots_$index'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _options(w),
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: Color(0xCC000000), shape: BoxShape.circle),
            child: const Icon(Icons.more_vert_rounded, size: 22, color: Colors.white),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PostWidget>>(
      valueListenable: PostWidgetsLink.drafts,
      builder: (context, list, _) => LayoutBuilder(
        builder: (context, box) {
          final frame = mediaFrame(Size(box.maxWidth, box.maxHeight), widget.mediaAspect);   // les positions se comptent dans le cadre du média
          return Stack(clipBehavior: Clip.none, children: [
            // toucher le fond désélectionne (seulement quand un widget est sélectionné : sinon les gestes passent au média)
            if (_sel != null) Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => setState(() => _sel = null))),
            for (final w in list)
              Positioned.fill(
                child: Align(
                  alignment: widgetAlignment(w, Size(box.maxWidth, box.maxHeight), frame),
                  child: GestureDetector(
                    key: ValueKey('draft_widget_${list.indexOf(w)}'),
                    behavior: HitTestBehavior.opaque,   // le widget dessous ignore les touchers (aperçu) : sans zone propre, on ne pouvait ni le toucher, ni le déplacer, ni le supprimer
                    onTap: () => _options(w),   // toucher le widget ouvre ses options (avant, les commandes en haut du cadre ne réagissaient pas)
                    onScaleStart: (_) {
                      _scaleStart = w.scale;
                      if (!identical(_sel, w)) setState(() => _sel = w);
                    },
                    onScaleUpdate: (d) {
                      w.x = (w.x + d.focalPointDelta.dx / frame.width).clamp(.04, .96);
                      w.y = (w.y + d.focalPointDelta.dy / frame.height).clamp(.04, .96);
                      if (d.pointerCount > 1) w.scale = (_scaleStart * d.scale).clamp(.6, 1.6);
                      _refresh();
                    },
                    child: Container(
                      decoration: identical(_sel, w) ? BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white, width: 1.5)) : null,
                      // le « ⋮ » est dans le calque d'édition seulement (jamais dans le rendu) ; il suit le widget et garde sa taille
                      child: Transform.scale(
                        scale: w.scale,
                        child: Stack(children: [
                          IgnorePointer(child: PostWidgetView(widget: w, preview: true)),
                          Positioned(top: 2, right: 2, child: _dots(w, list.indexOf(w))),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// Les widgets en cours d'ajout TELS QU'ILS SERONT VUS après la publication, pour l'aperçu final avant de poster : à leur place et à leur taille, sans aucune commande
/// (pas de « ⋮ »), sans réagir aux touchers. Avec une vidéo ([video]), un widget réglé « Visible de… à… » n'apparaît que dans cette partie, comme après la publication.
/// [mediaAspect] : format du média affiché en entier (largeur / hauteur) ; null = tout l'espace.
class DraftWidgetsPreview extends StatelessWidget {
  const DraftWidgetsPreview({super.key, this.mediaAspect, this.video});
  final double? mediaAspect;
  final VideoPlayerController? video;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<List<PostWidget>>(
        valueListenable: PostWidgetsLink.drafts,
        builder: (context, list, _) {
          if (list.isEmpty) return const SizedBox.shrink();
          Widget layer() => LayoutBuilder(builder: (context, box) {
                final size = Size(box.maxWidth, box.maxHeight);
                final frame = mediaFrame(size, mediaAspect);
                final now = video == null ? null : video!.value.position.inMilliseconds / 1000;
                return Stack(clipBehavior: Clip.none, children: [
                  for (final w in list)
                    if (now == null || ((w.start == null || now >= w.start!) && (w.end == null || now <= w.end!)))
                      Positioned.fill(
                        child: Align(
                          alignment: widgetAlignment(w, size, frame),
                          child: Transform.scale(scale: w.scale, child: PostWidgetView(key: ValueKey('preview_widget_${list.indexOf(w)}'), widget: w, preview: true)),
                        ),
                      ),
                ]);
              });
          // vidéo : le calque suit la position de lecture (apparition et disparition des widgets réglés dans le temps)
          return video == null ? layer() : ValueListenableBuilder<VideoPlayerValue>(valueListenable: video!, builder: (_, __, ___) => layer());
        },
      ),
    );
  }
}
