import 'package:flutter/material.dart';
import 'responsive_layout.dart';

/// Conteneur centré horizontalement avec largeur maximale configurable.
/// Sur mobile, la contrainte est ignorée (pleine largeur).
class CenteredContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const CenteredContent({
    Key? key,
    required this.child,
    this.maxWidth = AppLayout.maxFeedWidth,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget result = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );
    if (padding != null) result = Padding(padding: padding!, child: result);
    return Align(alignment: Alignment.topCenter, child: result);
  }
}
