import 'package:flutter/material.dart';

class NumbersWidget extends StatelessWidget {
  final int followers;
  final int points;
  final double taux;
  const NumbersWidget({required this.followers, required this.taux, required this.points, super.key});

  String _format(int n) {
    if (n < 1000) return n.toString();
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    return '${(n / 1000000).toStringAsFixed(1)}M';
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
        _stat(context, _format(points), 'Points', valueColor, labelColor),
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
