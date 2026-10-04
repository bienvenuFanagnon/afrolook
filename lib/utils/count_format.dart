/// Format unique des compteurs (abonnés…) : feed et pages de détails affichent le même texte.
/// 950 · 1.2K · 12K · 3.4M
String formatCompactCount(int count) {
  String trim(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  if (count < 1000) return count.toString();
  if (count < 999950) return '${trim(count / 1000)}K';
  if (count < 999950000) return '${trim(count / 1000000)}M';
  return '${trim(count / 1000000000)}B';
}
