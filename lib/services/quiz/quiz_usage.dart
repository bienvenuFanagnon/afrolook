import 'dart:async';

import 'package:flutter/widgets.dart';

import 'quiz_service.dart';

/// Mesure le temps passé dans le quiz (écran ouvert et application au premier plan) et le
/// signale au serveur environ une fois par minute, pour les statistiques de l'admin.
class QuizUsageTracker with WidgetsBindingObserver {
  QuizUsageTracker();
  final Stopwatch _watch = Stopwatch();
  Timer? _timer;
  int _sent = 0;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _watch.start();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _flush());
  }

  void stop() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _watch.stop();
    _flush();
  }

  void _flush() {
    final total = _watch.elapsed.inSeconds;
    final delta = total - _sent;
    if (delta >= 5) {
      _sent = total;
      QuizService.instance.ping(delta);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_watch.isRunning) _watch.start();
    } else if (state == AppLifecycleState.paused) {
      _watch.stop();
      _flush();
    }
  }
}
