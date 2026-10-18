import 'package:flutter/material.dart';

import 'chronique_widgets.dart';
import 'chroniqueform.dart';

/// Taille du texte selon sa longueur : un mot d'esprit reste grand, un long récit devient lisible sans tout couvrir.
double chroniqueTextSize(int length) {
  if (length <= 80) return 28;
  if (length <= 200) return 23;
  if (length <= 450) return 19;
  if (length <= 800) return 17;
  return 15.5;
}

/// Durée d'affichage d'une chronique texte (ms) : environ 60 ms par caractère, de 5 à 45 secondes.
int chroniqueTextDurationMs(int length) => (length * 60 + 3000).clamp(5000, 45000);

/// Texte d'une chronique : centré s'il tient dans l'écran, sinon défilable avec un fondu en haut et en bas.
/// [onTouch] est appelé à chaque geste (la chronique suspend alors son minuteur pour laisser le temps de lire).
class ChroniqueTextView extends StatefulWidget {
  const ChroniqueTextView({super.key, required this.chronique, this.onTouch});
  final Chronique chronique;
  final VoidCallback? onTouch;

  @override
  State<ChroniqueTextView> createState() => _ChroniqueTextViewState();
}

class _ChroniqueTextViewState extends State<ChroniqueTextView> {
  final ScrollController _c = ScrollController();
  bool _scrollable = false;
  bool _atEnd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    _c.addListener(_measure);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted || !_c.hasClients) return;
    final max = _c.position.maxScrollExtent;
    final scrollable = max > 8;
    final end = !scrollable || _c.offset >= max - 8;
    if (scrollable != _scrollable || end != _atEnd) setState(() {
      _scrollable = scrollable;
      _atEnd = end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chronique;
    final bg = chroniqueBackground(c);
    final text = c.textContent ?? '';
    final dark = Color.lerp(bg, Colors.black, .5)!;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [bg, dark])),
      child: Stack(children: [
        Listener(
          onPointerDown: (_) => widget.onTouch?.call(),
          onPointerMove: (_) => widget.onTouch?.call(),
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              controller: _c,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(26, 118, 26, 128),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 246),
                child: Center(
                  child: Text(
                    text,
                    textAlign: _scrollable ? TextAlign.start : TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: chroniqueTextSize(text.length), fontWeight: FontWeight.w700, height: 1.38),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_scrollable) ...[
          Positioned(top: 0, left: 0, right: 0, height: 120, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [dark, dark.withValues(alpha: 0)])))))
          ,
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 150,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _atEnd ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [dark, dark.withValues(alpha: 0)]))),
              ),
            ),
          ),
          Positioned(
            bottom: 96,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _atEnd ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), borderRadius: BorderRadius.circular(99)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Faire défiler', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
