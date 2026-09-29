/// Format unique des compteurs (abonnés…) : feed et pages de détails affichent le même texte.
String formatCompactCount(int count) {
  if (count < 1000) return count.toString();
  if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
  return '${(count / 1000000).toStringAsFixed(1)}M';
}
