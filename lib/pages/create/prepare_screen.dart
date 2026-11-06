import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../theme/app_colors.dart';

/// Écran « Préparation de ta vidéo » (écran 8 de la proposition) : pendant que le serveur assemble le modèle, la musique et les calques, un anneau, un message et une barre qui avance.
/// La barre est une ESTIMATION (environ [seconds] secondes) : elle s'arrête à 92 % tant que le serveur n'a pas répondu, puis l'écran se ferme tout seul.
class PrepareScreen extends StatefulWidget {
  const PrepareScreen({super.key, required this.step, this.video = true, this.seconds = 15});

  /// Texte de l'étape en cours (« Envoi… », « Montage de la vidéo… »).
  final ValueListenable<String> step;
  final bool video;
  final int seconds;

  @override
  State<PrepareScreen> createState() => _PrepareScreenState();
}

class _PrepareScreenState extends State<PrepareScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bar = AnimationController(vsync: this, duration: Duration(seconds: widget.seconds))..forward();

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = c.isDark ? c.accent : c.accentText;
    return ColoredBox(
      color: c.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 96, height: 96, child: CircularProgressIndicator(key: const ValueKey('prepare_ring'), strokeWidth: 7, color: color, backgroundColor: c.surfaceVariant)),
            const SizedBox(height: 28),
            Text(widget.video ? context.tr('Préparation de ta vidéo') : context.tr('Préparation de ton image'), textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              widget.video ? context.tr('Le modèle et la musique sont assemblés. Ça prend environ {n} secondes.', {'n': '${widget.seconds}'}) : context.tr('Ton image est assemblée. Ça prend quelques secondes.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 14.5, height: 1.4),
            ),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _bar,
              builder: (_, __) => ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(key: const ValueKey('prepare_bar'), value: Curves.easeOut.transform(_bar.value) * .92, minHeight: 6, color: color, backgroundColor: c.surfaceVariant)),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(valueListenable: widget.step, builder: (_, v, __) => Text(v, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
          ]),
        ),
      ),
    );
  }
}
