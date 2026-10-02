import 'package:intl/intl.dart';

/// Ancienneté d'un post : « il y a quelques secondes », « il y a 5 min », « il y a 3 h », « il y a 2 j »,
/// puis la date (jj/MM/aa) au-delà d'une semaine. Même format dans toutes les pages de détails.
/// [createdAt] peut être en microsecondes ou en millisecondes (les deux existent dans les données).
String postTimeAgo(int? createdAt) {
  if (createdAt == null || createdAt <= 0) return '';
  final dateTime = createdAt > 9999999999999
      ? DateTime.fromMicrosecondsSinceEpoch(createdAt)
      : DateTime.fromMillisecondsSinceEpoch(createdAt);
  final difference = DateTime.now().difference(dateTime);
  if (difference.inDays < 1) {
    if (difference.inHours < 1) {
      if (difference.inMinutes < 1) return 'il y a quelques secondes';
      return 'il y a ${difference.inMinutes} min';
    }
    return 'il y a ${difference.inHours} h';
  }
  if (difference.inDays < 7) return 'il y a ${difference.inDays} j';
  return DateFormat('dd/MM/yy').format(dateTime);
}
