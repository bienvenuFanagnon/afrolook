import 'dart:convert';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Point d'accès unique à la nouvelle API (Laravel). Tout est éteint par défaut : tant que Remote Config n'active pas un module
/// (clé `api_modules`, ex. {"channels": true}), l'application continue de lire Firebase comme avant.
class ApiGateway {
  ApiGateway._();
  static final ApiGateway instance = ApiGateway._();

  static const _defaultBaseUrl = 'https://api.afrolookmedia.com/v1';

  final ApiModules modules = ApiModules();
  ApiClient? _client;

  /// À appeler après `RemoteConfigService.initialize()` (et à chaque rafraîchissement de Remote Config).
  void refresh() {
    try {
      final rc = FirebaseRemoteConfig.instance;
      final raw = rc.getString('api_modules');
      modules.update(raw.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(raw) as Map));
      final url = rc.getString('api_base_url');
      _client = null; // recréé avec l'adresse à jour
      _baseUrl = url.isEmpty ? _defaultBaseUrl : url;
    } catch (e) {
      modules.update(const {}); // en cas de doute : ancien système
      if (kDebugMode) debugPrint('ApiGateway: configuration illisible, ancien système conservé ($e)');
    }
  }

  String _baseUrl = _defaultBaseUrl;

  bool useApi(String module) => FirebaseAuth.instance.currentUser != null && modules.useApi(module);

  ApiClient get client => _client ??= ApiClient(
        baseUrl: _baseUrl,
        token: ({bool forceRefresh = false}) async => FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh),
        appCheck: () async {
          try {
            return await FirebaseAppCheck.instance.getToken();
          } catch (_) {
            return null;
          }
        },
      );
}
