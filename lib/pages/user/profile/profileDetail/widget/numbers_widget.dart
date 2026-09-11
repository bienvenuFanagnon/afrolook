import 'package:flutter/material.dart';

class NumbersWidget extends StatelessWidget {
  final int followers;
  final double creatorScore;
  final double taux;
  const NumbersWidget({required this.followers, required this.taux, required this.creatorScore, super.key});

  String _format(int n) {
    if (n < 1000) return n.toString();
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }

  String _tierLabel(double score) {
    if (score >= 80) return 'Élite';
    if (score >= 50) return 'Expert';
    if (score >= 25) return 'Avancé';
    if (score >= 10) return 'Standard';
    return 'Débutant';
  }

  Color _tierColor(double score) {
    if (score >= 80) return const Color(0xFF22C55E);
    if (score >= 50) return const Color(0xFF3B82F6);
    if (score >= 25) return const Color(0xFFF97316);
    if (score >= 10) return const Color(0xFFF59E0B);
    return const Color(0xFF94A3B8);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = isDark ? const Color(0xFFFFD700) : const Color(0xFFE21221);
    final labelColor = Theme.of(context).textTheme.bodySmall?.color
        ?? (isDark ? Colors.white60 : Colors.black54);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stat(context, '${(taux / 100).toStringAsFixed(2)}%', 'Popularité', valueColor, labelColor),
        _divider(context),
        _stat(context, _format(followers), 'Abonné(s)', valueColor, labelColor),
        _divider(context),
        _stat(context, _tierLabel(creatorScore), 'Niveau créateur', _tierColor(creatorScore), labelColor),
      ],
    );
  }

  Widget _divider(BuildContext context) => Container(
    height: 30, width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    color: Theme.of(context).dividerColor,
  );

  Widget _stat(BuildContext context, String value, String label, Color valueColor, Color labelColor) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: valueColor)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 12, color: labelColor, fontWeight: FontWeight.w500)),
        ],
      );
}
