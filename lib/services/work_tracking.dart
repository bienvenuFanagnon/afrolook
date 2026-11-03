import 'dart:async';
import 'dart:math';

import 'package:afrotok/services/api/api_gateway.dart';
import 'package:flutter/widgets.dart';

/// Suivi de fréquentation de la page Travail (tâches) et de la page des missions de Partage, pour l'administration.
///
/// Une visite = un identifiant ; on envoie : l'ouverture, un signal de présence toutes les 20 secondes tant que la page est visible et l'application au premier plan,
/// les boutons touchés et les pubs plein écran réellement montrées. Le serveur compte le temps lui-même (plafonné) : l'application n'envoie jamais de durée.
/// Aucun effet sur l'argent ni sur l'écran : toute erreur est ignorée, rien n'attend la réponse.
class WorkTrack with WidgetsBindingObserver {
  WorkTrack._(this.page) : sid = _newSid();

  /// `work` (page Travail) ou `missions` (Partage et gagne).
  final String page;
  final String sid;
  Timer? _timer;
  bool _paused = false;
  bool _stopped = false;

  /// Visite en cours (la dernière page ouverte) : les pubs plein écran lui sont rattachées.
  static WorkTrack? _current;

  static String _newSid() {
    final r = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${List.generate(8, (_) => chars[r.nextInt(chars.length)]).join()}';
  }

  /// Ouvre la visite de la page [page] (à appeler dans initState).
  static WorkTrack start(String page) {
    final t = WorkTrack._(page);
    _current = t;
    WidgetsBinding.instance.addObserver(t);
    t._send('open');
    t._arm();
    return t;
  }

  void _arm() {
    _timer?.cancel();
    if (_stopped || _paused) return;
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _send('beat'));
  }

  /// Une autre page est ouverte par-dessus : le temps ne compte plus pour celle-ci.
  void pause() {
    _paused = true;
    _timer?.cancel();
  }

  void resume() {
    if (_stopped) return;
    _paused = false;
    _current = this;
    _send('beat');
    _arm();
  }

  /// Fin de la visite (à appeler dans dispose).
  void stop() {
    _stopped = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (identical(_current, this)) _current = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_paused) {
        _send('beat');
        _arm();
      }
    } else {
      _timer?.cancel();
    }
  }

  /// Bouton touché : `missions` (missions de partage), `tasks` (liste des tâches), `partner` (plateformes de tâches).
  void tap(String what) => _send('tap', what);

  /// Pub plein écran réellement montrée depuis la page ouverte : `tasks` (avant d'entrer), `mission` (avant une mission), `other`.
  static void ad(String kind) => _current?._send('ad', kind);

  void _send(String action, [String? what]) {
    if (_stopped) return;
    try {
      ApiGateway.instance.client.post('/work/track', body: {'sid': sid, 'page': page, 'action': action, if (what != null) 'what': what}).catchError((_) => null);
    } catch (_) {/* le suivi ne gêne jamais la personne */}
  }
}
