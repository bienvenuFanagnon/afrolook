import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/api/post_diffusion.dart';
import '../services/api/posts_api.dart';
import '../theme/app_colors.dart';

/// Carte « Diffusion » d'une publication (vagues de diffusion, 08/11/2026) : ouverte par l'option « Diffusion » du menu du post, visible par TOUS
/// (pour qu'on sache que la fonction existe). Chiffres de la publication seulement, jamais de noms de personnes.
Future<void> showPostDiffusionSheet(BuildContext context, String postId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PostDiffusionSheet(postId: postId),
  );
}

/// Contenu de la fenêtre : vague atteinte, personnes touchées, part regardée, partages, et un mot sur l'état (en test, plaît, discrète, au sommet).
class PostDiffusionSheet extends StatefulWidget {
  const PostDiffusionSheet({super.key, required this.postId, this.loader});
  final String postId;

  /// Remplace l'appel à l'API (tests).
  final Future<PostDiffusion?> Function(String id)? loader;

  @override
  State<PostDiffusionSheet> createState() => _PostDiffusionSheetState();
}

class _PostDiffusionSheetState extends State<PostDiffusionSheet> {
  late final Future<PostDiffusion?> _future = (widget.loader ?? PostsApi.diffusion)(widget.postId);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(color: colors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(
        top: false,
        child: FutureBuilder<PostDiffusion?>(
          future: _future,
          builder: (context, snap) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: colors.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 14),
                Row(children: [
                  Icon(Icons.rocket_launch_outlined, color: colors.accentText, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.tr('Diffusion de cette publication'), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16))),
                ]),
                const SizedBox(height: 12),
                if (snap.connectionState != ConnectionState.done)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                else if (snap.hasError)
                  _note(colors, context.tr('Impossible de charger la diffusion. Réessaie plus tard.'))
                else if (snap.data == null)
                  _note(colors, context.tr('Pas encore dans les vagues de diffusion.'))
                else
                  ..._card(context, colors, snap.data!),
                const SizedBox(height: 12),
                Text(context.tr('Cette carte est visible par tous : chaque publication peut aller plus loin si elle plaît.'),
                    style: TextStyle(color: colors.textSecondary, fontSize: 11.5, height: 1.5)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _note(AppColors colors, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: TextStyle(color: colors.textSecondary, fontSize: 13.5, height: 1.5)),
      );

  /// Texte du bas selon l'état, et couleur (vert = plaît, neutre = test ou discret).
  (String, Color, Color) _verdict(BuildContext context, AppColors colors, PostDiffusion d) {
    switch (d.state) {
      case 'promising':
        return (context.tr('Elle plaît : prochaine vague bientôt'), colors.success.withOpacity(0.12), colors.success);
      case 'top':
        return (context.tr("Au sommet : elle est dans l'onglet Viral"), colors.success.withOpacity(0.12), colors.success);
      case 'stopped':
        return (context.tr('Restée discrète : ses abonnés la voient toujours'), colors.textSecondary.withOpacity(0.10), colors.textSecondary);
      default:
        return (context.tr('En cours de test'), colors.textSecondary.withOpacity(0.10), colors.textSecondary);
    }
  }

  List<Widget> _card(BuildContext context, AppColors colors, PostDiffusion d) {
    final (text, bg, fg) = _verdict(context, colors, d);
    return [
      // une barre de 5 vagues : les vagues atteintes sont pleines
      Row(children: [
        for (var i = 1; i <= d.levels; i++)
          Expanded(
            child: Container(
              key: ValueKey('wave_step_$i'),
              height: 8,
              margin: EdgeInsets.only(right: i == d.levels ? 0 : 4),
              decoration: BoxDecoration(
                color: (d.state == 'top' || i <= d.level) ? colors.success : colors.textSecondary.withOpacity(0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      Text('${context.tr('Vague')} ${d.state == 'top' ? d.levels : d.level} / ${d.levels}', style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
      const SizedBox(height: 10),
      _line(colors, context.tr('Montrée à'), '${_n(d.shownTotal)} ${context.tr('personnes')}'),
      _line(colors, context.tr('Dont hors des abonnés'), _n(d.shownOutside)),
      if (d.isVideo && d.finishedPct != null) _line(colors, context.tr("Regardée presque jusqu'au bout"), '${d.finishedPct} %'),
      if (d.isVideo && d.loopsPct != null) _line(colors, context.tr('Revue en boucle'), '${d.loopsPct} %'),
      _line(colors, context.tr('Partages'), _n(d.shares)),
      const SizedBox(height: 10),
      Container(
        key: const ValueKey('diffusion_verdict'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    ];
  }

  Widget _line(AppColors colors, String label, String value) => Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.textSecondary.withOpacity(0.15)))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13))),
          const SizedBox(width: 12),
          Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
      );

  /// 1 600 → « 1 600 » (espace insécable fine entre milliers).
  String _n(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }
}
