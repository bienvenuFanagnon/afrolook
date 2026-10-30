/// Erreur de l'API : { code, message, details }. `code` est stable (à tester dans l'application), `message` est déjà en français.
class ApiException implements Exception {
  ApiException({required this.status, required this.code, required this.message, this.details = const {}});

  final int status;
  final String code;
  final String message;
  final Map<String, dynamic> details;

  bool get isUnauthorized => status == 401;
  bool get isNotFound => status == 404;
  bool get isInsufficientCoins => status == 402 && code == 'insufficient_coins';

  /// Pièces manquantes ou prix demandé, quand l'API le précise.
  int? get coins => details['coins'] is num ? (details['coins'] as num).toInt() : null;

  /// Pas de réseau, délai dépassé ou réponse illisible (status 0).
  bool get isNetwork => status == 0;

  @override
  String toString() => 'ApiException($status, $code): $message';
}
