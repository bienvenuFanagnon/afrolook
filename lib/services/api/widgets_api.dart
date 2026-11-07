import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiClient;

import '../../models/post_widget.dart';
import 'api_gateway.dart';
import 'wallet_api.dart';

/// Réponses du public aux widgets d'une publication (sondage, quiz, question, réaction, rappel).
class WidgetsApi {
  WidgetsApi._();

  /// Envoie la réponse ; rend le widget à jour (décomptes, ma réponse, bonne réponse d'un quiz). Lève l'erreur du serveur (par exemple « Tu as déjà répondu »).
  static Future<PostWidget?> respond(String widgetId, Object value) async {
    final r = await ApiGateway.instance.client.post('/widgets/$widgetId/respond', body: {'value': value});
    return PostWidget.fromApi(WalletApi.map(r));
  }

  /// Les réponses reçues par une question (pour l'AUTEUR de la publication) : (pseudo, texte).
  static Future<List<({String user, String text})>> responses(String widgetId) async {
    final r = await ApiGateway.instance.client.get('/widgets/$widgetId/responses');
    final data = ApiClient.data(r);
    return [
      for (final m in (data is List ? data : const []).whereType<Map>()) (user: '${(m['user'] is Map ? (m['user'] as Map)['username'] : null) ?? ''}', text: '${m['value'] ?? ''}'),
    ];
  }
}
