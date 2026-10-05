import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/tr.dart';
import '../../../theme/app_colors.dart';

/// Thème d'une unité du parcours (une unité = 5 niveaux d'un même thème).
class QuizTheme {
  const QuizTheme(this.key, this.label, this.icon, this.color);
  final String key, label;
  final IconData icon;
  final Color color;

  String name(BuildContext context) => context.tr(label);
}

const List<QuizTheme> kQuizThemes = [
  QuizTheme('courage', 'Courage et héros', Icons.local_fire_department_rounded, Color(0xFFFF7A3D)),
  QuizTheme('oeuvres', 'Œuvres et livres', Icons.menu_book_rounded, Color(0xFF9B6BFF)),
  QuizTheme('musique', 'Musique', Icons.music_note_rounded, Color(0xFFFF5C9E)),
  QuizTheme('football', 'Football', Icons.sports_soccer_rounded, Color(0xFF2ECC71)),
  QuizTheme('histoire', "Histoire d'Afrique", Icons.account_balance_rounded, Color(0xFFE0A526)),
  QuizTheme('geographie', 'Géographie', Icons.public_rounded, Color(0xFF3FA7FF)),
  QuizTheme('culture', 'Culture et traditions', Icons.diversity_3_rounded, Color(0xFFE5484D)),
  QuizTheme('sciences', 'Sciences et inventions', Icons.science_rounded, Color(0xFF1FC8B4)),
];

/// Unité (0..39) d'un niveau (1..200).
int quizUnitOf(int level) => (level - 1) ~/ 5;
QuizTheme quizThemeOfUnit(int unit) => kQuizThemes[unit % kQuizThemes.length];
QuizTheme quizThemeByKey(String key) => kQuizThemes.firstWhere((t) => t.key == key, orElse: () => kQuizThemes.first);

/// Drapeau d'un pays à partir de son code ISO (« TG » → 🇹🇬).
String quizFlag(String code) {
  if (code.length != 2) return '🌍';
  final up = code.toUpperCase();
  return String.fromCharCodes(up.codeUnits.map((c) => 0x1F1E6 + (c - 0x41)));
}

/// Petite pastille d'information (série, cœurs, points).
class QuizPill extends StatelessWidget {
  const QuizPill({super.key, required this.icon, required this.label, required this.color, this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: c.textPrimary)),
        ]),
      ),
    );
  }
}

/// Bulle de dialogue de la mascotte, avec une petite pointe côté mascotte.
class QuizBubble extends StatelessWidget {
  const QuizBubble({super.key, required this.child, this.tailOnLeft = true});
  final Widget child;
  final bool tailOnLeft;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border, width: 1.5),
        ),
        child: child,
      ),
      Positioned(
        left: tailOnLeft ? -7 : null,
        right: tailOnLeft ? null : -7,
        top: 22,
        child: Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(
                left: tailOnLeft ? BorderSide(color: c.border, width: 1.5) : BorderSide.none,
                bottom: BorderSide(color: c.border, width: 1.5),
                right: tailOnLeft ? BorderSide.none : BorderSide(color: c.border, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Gros bouton « 3D » : il s'enfonce quand on le touche.
class QuizChunkyButton extends StatefulWidget {
  const QuizChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.textColor,
    this.icon,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color? color, textColor;
  final IconData? icon;
  final bool loading;

  @override
  State<QuizChunkyButton> createState() => _QuizChunkyButtonState();
}

class _QuizChunkyButtonState extends State<QuizChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = widget.onPressed != null && !widget.loading;
    final base = widget.color ?? c.primary;
    final face = enabled ? base : c.surfaceVariant;
    final edge = enabled ? Color.lerp(base, Colors.black, 0.28)! : c.border;
    final fg = enabled ? (widget.textColor ?? c.onPrimary) : c.textSecondary;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: EdgeInsets.only(top: _down ? 4 : 0, bottom: _down ? 0 : 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: face,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: edge, offset: Offset(0, _down ? 0 : 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (widget.loading)
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
          else ...[
            if (widget.icon != null) ...[Icon(widget.icon, size: 20, color: fg), const SizedBox(width: 8)],
            Flexible(
              child: Text(
                widget.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.6),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

enum QuizOptionState { idle, selected, correct, wrong, dimmed }

/// Une réponse possible.
class QuizOption extends StatelessWidget {
  const QuizOption({super.key, required this.letter, required this.text, required this.state, required this.onTap, this.checking = false});
  final String letter, text;
  final QuizOptionState state;
  final VoidCallback? onTap;

  /// La réponse est en cours de vérification : la case pulse et un petit cercle tourne à la place de la lettre.
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Color bg = c.surface;
    Color border = c.border;
    Color badgeBg = c.surfaceVariant;
    Color badgeFg = c.textSecondary;
    Color fg = c.textPrimary;
    switch (state) {
      case QuizOptionState.selected:
        border = c.info;
        bg = c.info.withOpacity(0.12);
        badgeBg = c.info;
        badgeFg = Colors.white;
        break;
      case QuizOptionState.correct:
        border = c.primary;
        bg = c.primary.withOpacity(0.16);
        badgeBg = c.primary;
        badgeFg = c.onPrimary;
        break;
      case QuizOptionState.wrong:
        border = c.danger;
        bg = c.danger.withOpacity(0.14);
        badgeBg = c.danger;
        badgeFg = Colors.white;
        break;
      case QuizOptionState.dimmed:
        fg = c.textSecondary;
        break;
      case QuizOptionState.idle:
        break;
    }
    final waiting = checking && state == QuizOptionState.selected;
    final tile = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 2),
          boxShadow: [BoxShadow(color: border.withOpacity(0.9), offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(9)),
            child: state == QuizOptionState.correct
                ? Icon(Icons.check_rounded, size: 18, color: badgeFg)
                : state == QuizOptionState.wrong
                    ? Icon(Icons.close_rounded, size: 18, color: badgeFg)
                    : waiting
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : Text(letter, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: badgeFg)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: fg, height: 1.25))),
        ]),
      ),
    );
    return waiting ? _Pulse(child: tile) : tile;
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: Tween(begin: 0.55, end: 1.0).animate(_c), child: widget.child);
}

/// « Je vérifie ta réponse… » : petite attente animée entre le choix et le verdict.
class QuizChecking extends StatefulWidget {
  const QuizChecking({super.key});

  @override
  State<QuizChecking> createState() => _QuizCheckingState();
}

class _QuizCheckingState extends State<QuizChecking> {
  static const _texts = ['Je vérifie ta réponse…', 'Je consulte les sages…', 'Verdict dans un instant…'];
  Timer? _t;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _texts.length);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = _texts[_i];
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Column(children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a), child: child)),
          child: Text(context.tr(text), key: ValueKey(text), style: TextStyle(color: c.info, fontWeight: FontWeight.w800, fontSize: 13.5)),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(minHeight: 4, backgroundColor: c.surfaceVariant, valueColor: AlwaysStoppedAnimation(c.info)),
        ),
      ]),
    );
  }
}

/// « 2 h 05 », « 12:30 »… pour le prochain cœur.
String quizClock(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

void quizToast(BuildContext context, String message, {bool error = false}) {
  final c = AppColors.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: error ? c.danger : c.primary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
}
