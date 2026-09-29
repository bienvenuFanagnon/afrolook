import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/app_colors.dart';
import '../utils/pseudo_format.dart';
import 'canal_tag.dart';
import 'pseudo_tag.dart';

/// Aperçu en direct du rendu final d'un pseudo (capsule) ou d'un nom de canal (badge),
/// à afficher sous le champ de saisie : l'utilisateur voit exactement ce que les autres verront.
class NamePreview extends StatelessWidget {
  final TextEditingController controller;
  final bool canal;

  const NamePreview({super.key, required this.controller, this.canal = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final min = canal ? kCanalMinLength : kPseudoMinLength;
    final max = canal ? kCanalMaxLength : kPseudoMaxLength;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (ctx, v, _) {
        final n = normalizePseudo(v.text);
        final tooShort = n.isNotEmpty && n.length < min;
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tooShort ? c.warning : c.border),
          ),
          child: Row(children: [
            Text(ctx.tr('Aperçu'), style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: n.isEmpty
                    ? Text(canal ? '#mon.canal' : '@prenom.nom',
                        style: TextStyle(color: c.textSecondary.withOpacity(.6), fontSize: 14, fontWeight: FontWeight.w700))
                    : (canal
                        ? CanalTag(label: '#$n', style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800))
                        : PseudoTag(label: '@$n', style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800))),
              ),
            ),
            Text('${n.length}/$max',
                style: TextStyle(color: tooShort ? c.warning : c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ]),
        );
      },
    );
  }
}
