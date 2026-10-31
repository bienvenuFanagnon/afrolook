import 'dart:async';

import 'package:afrotok/services/api/regie_api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Comptage des vues et des clics de pub dans l'application : tout passe par le moteur d'Afrolook Ads (API : /ads/app/serve et /ads/app/event).
///
/// L'application garde son propre choix de l'annonce à afficher ; elle demande seulement au serveur un JETON DE COMPTAGE pour cette annonce.
/// Le serveur vérifie : application authentique (App Check), utilisateur connecté (jeton d'identité), annonce active, durée de visibilité,
/// plafond de 3 vues par annonce et par jour et par utilisateur, un clic par jeton. L'application n'écrit plus jamais de compteur elle-même :
/// modifier le code ne permet plus de gonfler les chiffres (les règles Firestore interdiront ensuite toute écriture de compteur).
class AdsEngineService {
  AdsEngineService._();
  static final AdsEngineService instance = AdsEngineService._();

  static const String _pub = 'afrolook';

  /// Dernier jeton obtenu pour chaque annonce (sert aussi au clic qui suit la vue).
  final Map<String, _Ticket> _tickets = {};
  final Map<String, DateTime> _lastView = {};

  /// Une annonce vient d'être affichée à l'utilisateur. Sans effet bloquant, jamais d'exception.
  void view(String adId, {String format = 'native', String slot = 'feed'}) {
    final last = _lastView[adId];
    if (last != null && DateTime.now().difference(last).inSeconds < 20) return; // même annonce re-déclenchée par un redessin
    _lastView[adId] = DateTime.now();
    if (_lastView.length > 300) _lastView.clear();
    unawaited(_view(adId, format, slot));
  }

  /// L'utilisateur vient d'appuyer sur l'annonce (bouton d'action).
  void click(String adId, {String format = 'native', String slot = 'feed'}) {
    unawaited(_click(adId, format, slot));
  }

  Future<void> _view(String adId, String format, String slot) async {
    try {
      final t = await _serve(adId, format, slot);
      if (t == null) return;
      _tickets[adId] = t;
      // le serveur compare ce délai à l'heure d'émission du jeton : une vue instantanée est refusée
      await Future.delayed(Duration(milliseconds: t.viewMs + 80));
      await _post(t, 'view', ms: t.viewMs + 80);
    } catch (e) {
      if (kDebugMode) debugPrint('AdsEngineService.view: $e');
    }
  }

  Future<void> _click(String adId, String format, String slot) async {
    try {
      var t = _tickets[adId];
      if (t == null || t.clicked || DateTime.now().difference(t.at).inMinutes >= 25) {
        t = await _serve(adId, format, slot);
        if (t == null) return;
        _tickets[adId] = t;
      }
      // un clic compte au plus tôt 1 seconde après l'émission du jeton
      final wait = 1200 - DateTime.now().difference(t.at).inMilliseconds;
      if (wait > 0) await Future.delayed(Duration(milliseconds: wait));
      t.clicked = true;
      await _post(t, 'click');
    } catch (e) {
      if (kDebugMode) debugPrint('AdsEngineService.click: $e');
    }
  }

  /// Le serveur choisit l'annonce (route de l'application, visiteur = compte connecté) ; le jeton est lié à CETTE annonce.
  /// Si le serveur en a choisi une autre que celle affichée, rien n'est compté (voir lacunes_api_regie_admin.md : paramètre `ad`).
  Future<_Ticket?> _serve(String adId, String format, String slot) async {
    if (FirebaseAuth.instance.currentUser == null) return null;
    final j = await RegieApi.adsServe({
      'pub': _pub, 'fmt': format, 'slot': slot.replaceAll(RegExp(r'[^a-z0-9_-]'), '').padRight(1, 'x'), 'ad': adId,
    });
    final ad = j['ad'];
    if (ad is! Map || ad['token'] is! String) return null;
    if ('${ad['id']}' != adId) return null;
    return _Ticket(token: ad['token'] as String, event: '', viewMs: (ad['viewMs'] as num?)?.toInt() ?? 1000);
  }

  Future<void> _post(_Ticket t, String kind, {int? ms}) async {
    await RegieApi.adsEvent({'t': t.token, 'e': kind, if (ms != null) 'ms': ms});
  }
}

class _Ticket {
  _Ticket({required this.token, required this.event, required this.viewMs}) : at = DateTime.now();
  final String token;
  final String event;
  final int viewMs;
  final DateTime at;
  bool clicked = false;
}
