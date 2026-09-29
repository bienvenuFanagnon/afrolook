import 'package:flutter/material.dart';

import 'canal_tag.dart';
import 'pseudo_tag.dart';

/// Affiche un nom selon son type : « #canal » en badge carré vert, « @pseudo » en capsule dorée,
/// tout autre texte tel quel.
class NameTag extends StatelessWidget {
  final String label;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool bordered;

  const NameTag({super.key, required this.label, this.style, this.maxLines, this.overflow, this.textAlign, this.bordered = true});

  @override
  Widget build(BuildContext context) {
    if (CanalTag.isCanalLabel(label)) {
      return CanalTag(label: label, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign, bordered: bordered);
    }
    if (PseudoTag.isPseudoLabel(label)) {
      return PseudoTag(label: label, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
    }
    return Text(label, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
  }
}
