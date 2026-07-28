import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final RemoteConfigService instance = RemoteConfigService._();
  RemoteConfigService._();

  final FirebaseRemoteConfig _rc = FirebaseRemoteConfig.instance;

  // Clés disponibles + valeurs par défaut (true = page active, false = maintenance)
  static const Map<String, dynamic> _defaults = {
    'app_active': true,
    'page_marketing_active': true,
    'page_challenge_mois_active': true,
  };

  Future<void> initialize() async {
    try {
      await _rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await _rc.setDefaults(_defaults);
      await _rc.fetchAndActivate();
      printVm('✅ RemoteConfig initialisé : ${_rc.getAll().map((k, v) => MapEntry(k, v.asBool()))}');
    } catch (e) {
      printVm('⚠️ RemoteConfig fallback sur valeurs par défaut : $e');
    }
  }

  bool isPageActive(String key) {
    if (!_defaults.containsKey(key)) return true;
    return _rc.getBool(key);
  }
}
