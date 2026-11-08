import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/post_widget.dart';
import '../theme/app_colors.dart';
import 'post_widget_view.dart';
import 'widgets_sheet.dart';

/// Calque des widgets en cours d'ajout (sondage, question, lien…) posé sur le média : UN SEUL composant pour l'éditeur de création ET le Studio de montage,
/// pour que les widgets restent visibles, déplaçables et supprimables partout, quel que soit le média choisi ou modifié.
/// On glisse pour déplacer, on pince (ou − / +) pour redimensionner, on touche pour afficher les commandes (durée, modifier, supprimer).
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

  Widget _ctl(Key k, IconData icon, VoidCallback onTap, {Color bg = Colors.black87, Color fg = Colors.white}) => GestureDetector(
        key: k,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
          child: Icon(icon, size: 18, color: fg),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PostWidget>>(
      valueListenable: PostWidgetsLink.drafts,
      builder: (context, list, _) => LayoutBuilder(
        builder: (context, box) {
          final frame = mediaFrame(Size(box.maxWidth, box.maxHeight), widget.mediaAspect);   // les positions se comptent dans le cadre du média
          final hasVideo = (widget.videoSeconds?.call() ?? 0) >= 1;
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
                    onTap: () => setState(() => _sel = identical(_sel, w) ? null : w),
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
                      child: Transform.scale(scale: w.scale, child: IgnorePointer(child: PostWidgetView(widget: w, preview: true))),
                    ),
                  ),
                ),
              ),
            // commandes du widget sélectionné : une barre en haut du cadre, DANS la zone touchable (au-dessus du widget elles ne recevaient aucun toucher)
            if (_sel != null && list.any((e) => identical(e, _sel)))
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(24)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _ctl(const ValueKey('wm_smaller'), Icons.remove_rounded, () => _scale(_sel!, -.15)),
                      _ctl(const ValueKey('wm_bigger'), Icons.add_rounded, () => _scale(_sel!, .15)),
                      if (hasVideo) _ctl(const ValueKey('wm_range'), Icons.timelapse_rounded, () => _editRange(_sel!), bg: (_sel!.start != null || _sel!.end != null) ? const Color(0xFFFFC400) : Colors.black87, fg: (_sel!.start != null || _sel!.end != null) ? Colors.black : Colors.white),
                      _ctl(const ValueKey('wm_edit'), Icons.edit_rounded, () => _edit(_sel!)),
                      _ctl(const ValueKey('wm_delete'), Icons.delete_outline_rounded, () => _delete(_sel!), bg: Colors.redAccent),
                    ]),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
