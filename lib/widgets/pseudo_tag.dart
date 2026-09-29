import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Affichage signature des pseudos Afrolook : « capsule » avec le @ dans un médaillon doré
/// et les points du pseudo en or. Le pseudo stocké reste `olivier.bernard` ; seul l'affichage change.
///
/// [label] peut commencer par « @ » ; s'il ne ressemble pas à un pseudo (texte libre, canal « # »…),
/// il est affiché tel quel.
class PseudoTag extends StatelessWidget {
  final String label;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const PseudoTag({super.key, required this.label, this.style, this.maxLines, this.overflow, this.textAlign});

  /// Le texte est-il un pseudo à mettre en capsule (« @xxx » sans espace) ?
  static bool isPseudoLabel(String s) => RegExp(r'^@[A-Za-z0-9._\-]+$').hasMatch(s);

  static Color _gold(AppColors c) => c.isDark ? const Color(0xFFF5C542) : const Color(0xFFD99A00);

  @override
  Widget build(BuildContext context) {
    if (!isPseudoLabel(label)) {
      return Text(label, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
    }
    final c = AppColors.of(context);
    final base = style ?? const TextStyle();
    final fs = base.fontSize ?? 14;
    final txtColor = base.color ?? c.textPrimary;
    // Texte clair (fond vidéo, bandeaux sombres) : capsule translucide sombre
    final onDark = txtColor.computeLuminance() > 0.8;
    final gold = _gold(c);
    final name = label.substring(1);
    final parts = name.split('.');

    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) spans.add(TextSpan(text: '.', style: TextStyle(color: gold, fontWeight: FontWeight.w900)));
      spans.add(TextSpan(text: parts[i]));
    }

    final medal = fs * 1.35;
    return Container(
      padding: EdgeInsets.fromLTRB(fs * .2, fs * .16, fs * .7, fs * .16),
      decoration: BoxDecoration(
        color: onDark ? Colors.black.withOpacity(.4) : c.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: onDark ? Colors.white24 : c.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: medal,
          height: medal,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: gold, shape: BoxShape.circle),
          child: Text('@', style: TextStyle(color: const Color(0xFF2B1A00), fontSize: fs * .82, fontWeight: FontWeight.w900, height: 1)),
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
