/// Ancienne migration unique des compteurs de messages non lus (Firestore). Les compteurs sont maintenant tenus par le serveur
/// (`GET /conversations/unread-count`) : plus rien à réinitialiser sur le téléphone. Fonction gardée pour ne pas casser l'appelant.
Future<void> runUnreadResetMigrationIfNeeded(String userId) async {}
