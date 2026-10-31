/// Les gains de vues sont calculés par le serveur (publications non monétisées exclues) : GET /wallet/earnings/views.
/// Plus de lecture côté application.
class ViewEarningsFilter {
  static Future<int> nonMonetizedViews(String userId) async => 0;
}
