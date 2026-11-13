import 'package:intl/intl.dart';

/// Ancienneté d'un post : « il y a quelques secondes », « il y a 5 min », « il y a 3 h », « il y a 2 j »,
/// puis la date (jj/MM/aa) au-delà d'une semaine. Même format dans toutes les pages de détails.
/// [createdAt] peut être en microsecondes ou en millisecondes (les deux existent dans les données).
DateTime? epochToDateTime(int? value) {
  if (value == null || value <= 0) return null;
  return value > 9999999999999 ? DateTime.fromMicrosecondsSinceEpoch(value) : DateTime.fromMillisecondsSinceEpoch(value);
}

/// Date d'un post, d'un commentaire ou d'une réponse, quelle que soit l'unité du nombre reçu : microsecondes ou millisecondes ; null si la date est absente.
/// (Lire des millisecondes comme des microsecondes affichait le 21/01/1970 dans la page de commentaires.)
String postTimeAgo(int? createdAt) {
  final dateTime = epochToDateTime(createdAt);
  if (dateTime == null) return '';
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
