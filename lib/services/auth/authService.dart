import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';

import '../../pages/component/consoleWidget.dart';

class AuthService {
  late UserData loginUser2 = UserData();
  late UserData loginUser = UserData();
  late List<UserPhoneNumber> listNumber = [];
  late List<UserPseudo> listPseudo = [];
  late List<UserGlobalTag> listUserGlobalTag = [];
  late int codeError = 0;

  /// Réglages PUBLICS de l'application (`GET /v1/config`). Les clés, vérifications, compteurs et soldes globaux ne sont jamais envoyés aux clients.
  Future<AppDefaultData> getAppData() async {
    final appData = AppDefaultData();
    try {
      final cfg = Map<String, dynamic>.from(ApiClient.data(await ApiGateway.instance.client.get('/config')) as Map);
      final app = (cfg['app'] as Map?) ?? const {};
      appData.app_link = app['android_link'] as String?;
      appData.ios_link = app['ios_link'] as String?;
      appData.app_logo = (app['logo'] as String?) ?? appData.app_logo;
      appData.app_version_code = (app['version_code'] as num?)?.toInt() ?? appData.app_version_code;
      appData.app_version_code_officiel = (app['version_code_official'] as num?)?.toInt() ?? appData.app_version_code_officiel;
      if (app['use_cdn'] is bool) appData.useCDN = app['use_cdn'] as bool;
      final challenge = (cfg['challenge'] as Map?) ?? const {};
      final start = challenge['start_date'];
      if (start is num) appData.challengeStartDate = start.toInt();
    } catch (e) {
      printVm("Erreur lors de la lecture de la configuration : $e");
    }
    return appData;
  }
}
