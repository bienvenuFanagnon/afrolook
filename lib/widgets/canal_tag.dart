import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Affichage signature des canaux Afrolook : badge à coins carrés, # dans un carré vert,
/// points du nom en vert. Volontairement carré et vert pour ne jamais être confondu avec la
/// capsule ronde et dorée des pseudos ([PseudoTag]).
class CanalTag extends StatelessWidget {
  final String label;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const CanalTag({super.key, required this.label, this.style, this.maxLines, this.overflow, this.textAlign});

  /// Le texte est-il un nom de canal à mettre en badge (« #xxx » sans espace) ?
  static bool isCanalLabel(String s) => RegExp(r'^#(?=.*[A-Za-z])[A-Za-z0-9._\-]+$').hasMatch(s);

  @override
  Widget build(BuildContext context) {
    if (!isCanalLabel(label)) {
      return Text(label, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
    }
    final c = AppColors.of(context);
    final base = style ?? const TextStyle();
    final fs = base.fontSize ?? 14;
    final txtColor = base.color ?? c.textPrimary;
    final onDark = txtColor.computeLuminance() > 0.8;
    final green = c.primary;
    final parts = label.substring(1).split('.');

    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) spans.add(TextSpan(text: '.', style: TextStyle(color: green, fontWeight: FontWeight.w900)));
      spans.add(TextSpan(text: parts[i]));
    }

    final sq = fs * 1.3;
    return Container(
      padding: EdgeInsets.fromLTRB(fs * .18, fs * .14, fs * .6, fs * .14),
      decoration: BoxDecoration(
        color: onDark ? Colors.black.withOpacity(.4) : c.surfaceVariant,
        borderRadius: BorderRadius.circular(fs * .5),
        border: Border.all(color: green, width: 1.4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: sq,
          height: sq,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(fs * .3)),
          child: Text('#', style: TextStyle(color: c.onPrimary, fontSize: fs * .85, fontWeight: FontWeight.w900, height: 1)),
        ),
        SizedBox(width: fs * .4),
        Flexible(
          child: Text.rich(
            TextSpan(children: spans),
            style: base.copyWith(fontStyle: FontStyle.normal),
            maxLines: maxLines ?? 1,
            overflow: overflow ?? TextOverflow.ellipsis,
            textAlign: textAlign,
          ),
        ),
      ]),
    );
  }
}
