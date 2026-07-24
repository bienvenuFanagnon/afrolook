import 'package:flutter/material.dart';

/// Auto-scroll horizontal générique : prend n'importe quel itemBuilder,
/// duplique les items et défile en boucle infinie (style ticker).
class AutoScrollRow extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const AutoScrollRow({
    Key? key,
    required this.itemCount,
    required this.itemBuilder,
  }) : super(key: key);

  @override
  State<AutoScrollRow> createState() => _AutoScrollRowState();
}

class _AutoScrollRowState extends State<AutoScrollRow> {
  final ScrollController _ctrl = ScrollController();
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLoop());
  }

  @override
  void didUpdateWidget(AutoScrollRow old) {
    super.didUpdateWidget(old);
    if (old.itemCount != widget.itemCount && widget.itemCount > 0) {
      _running = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startLoop());
    }
  }

  Future<void> _startLoop() async {
    if (_running || !mounted || widget.itemCount == 0) return;
    _running = true;

    await Future.delayed(const Duration(milliseconds: 900));

    while (_running && mounted) {
      if (!_ctrl.hasClients) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }

      final maxExtent = _ctrl.position.maxScrollExtent;
      final viewportW = _ctrl.position.viewportDimension;

      // Largeur d'une copie = (contenu total) / 8 copies
      // = (maxExtent + viewportW) / 8
      // On scroll d'exactement une copie, puis on saute à 0 (raccord invisible)
      final oneCopyW = (maxExtent + viewportW) / 8;

      if (maxExtent <= 0 || oneCopyW <= 0) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      final ms = (oneCopyW / 40 * 1000).toInt().clamp(1500, 16000);
      try {
        await _ctrl.animateTo(oneCopyW, duration: Duration(milliseconds: ms), curve: Curves.linear);
      } catch (_) { break; }

      if (!_running || !mounted || !_ctrl.hasClients) break;
      await Future.delayed(const Duration(milliseconds: 350));
      if (!_running || !mounted || !_ctrl.hasClients) break;
      _ctrl.jumpTo(0);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _running = false;
  }

  @override
  void dispose() {
    _running = false;
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();
    // 8 copies garantissent que le contenu déborde toujours,
    // même avec 1 seul commentaire court
    return ListView.builder(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.itemCount * 8,
      itemBuilder: (ctx, i) => widget.itemBuilder(ctx, i % widget.itemCount),
    );
  }
}

/// Bande de suggestions de commentaires qui défile en boucle horizontale (style
/// ticker/marquee). Fonctionne même avec 1 ou 2 chips grâce à la duplication.
class MarqueeCommentChips extends StatefulWidget {
  final List<String> suggestions;
  final bool isLoading;
  final void Function(String) onTap;
  final Color chipColor;
  final Color borderColor;
  final Color textColor;
  final Color shimmerColor;

  const MarqueeCommentChips({
    Key? key,
    required this.suggestions,
    required this.isLoading,
    required this.onTap,
    required this.chipColor,
    required this.borderColor,
    required this.textColor,
    required this.shimmerColor,
  }) : super(key: key);

  @override
  State<MarqueeCommentChips> createState() => _MarqueeCommentChipsState();
}

class _MarqueeCommentChipsState extends State<MarqueeCommentChips> {
  final ScrollController _ctrl = ScrollController();
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLoop());
  }

  @override
  void didUpdateWidget(MarqueeCommentChips old) {
    super.didUpdateWidget(old);
    // Redémarre le marquee quand les suggestions changent (nouveau post)
    if (old.suggestions != widget.suggestions && widget.suggestions.isNotEmpty) {
      _running = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startLoop());
    }
  }

  Future<void> _startLoop() async {
    if (_running || !mounted || widget.suggestions.isEmpty) return;
    _running = true;

    // Pause initiale avant que le défilement commence
    await Future.delayed(const Duration(milliseconds: 1000));

    while (_running && mounted) {
      if (!_ctrl.hasClients) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }

      final totalMax = _ctrl.position.maxScrollExtent;
      // La moitié = exactement une copie de la liste (grâce à la duplication)
      final halfMax = totalMax / 2;

      if (halfMax <= 0) {
        // Pas encore de contenu défilable — réessayer
        await Future.delayed(const Duration(milliseconds: 400));
        continue;
      }

      // Défilement lent (~38 px/s) d'une copie complète
      final ms = (halfMax / 38 * 1000).toInt().clamp(1500, 14000);
      try {
        await _ctrl.animateTo(
          halfMax,
          duration: Duration(milliseconds: ms),
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }

      if (!_running || !mounted || !_ctrl.hasClients) break;
      await Future.delayed(const Duration(milliseconds: 350));
      if (!_running || !mounted || !_ctrl.hasClients) break;

      // Retour invisible au début (raccord parfait grâce à la duplication)
      _ctrl.jumpTo(0);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _running = false;
  }

  @override
  void dispose() {
    _running = false;
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Row(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(right: 6),
            width: 70,
            decoration: BoxDecoration(
              color: widget.shimmerColor,
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
      );
    }

    if (widget.suggestions.isEmpty) return const SizedBox.shrink();

    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, 0.80, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: _ctrl,
        scrollDirection: Axis.horizontal,
        // L'utilisateur ne scrolle pas manuellement (c'est le marquee qui contrôle)
        physics: const NeverScrollableScrollPhysics(),
        // Duplication de la liste pour boucle sans raccord visible
        itemCount: widget.suggestions.length * 2,
        itemBuilder: (_, i) {
          final text = widget.suggestions[i % widget.suggestions.length];
          return GestureDetector(
            onTap: () => widget.onTap(text),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: widget.chipColor,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: widget.borderColor),
              ),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 11, color: widget.textColor),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
