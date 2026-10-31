import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// TRANSITOIRE : la mesure des lectures Firestore est coupée (plus aucun envoi au serveur, plus de compteur). Ce fichier ne garde que les
/// extensions `getM` / `snapshotsM` pour que les écrans pas encore migrés compilent ; il pourra être supprimé dès qu'aucun fichier ne les utilise.
///
/// Ancienne description : mesure des lectures Firestore par source (diagnostic temporaire, tâche #94).
///
/// Chaque lecture passe par `getM('fichier.dart:ligne')` ou `snapshotsM('fichier.dart:ligne')` (mêmes résultats que `get()` / `snapshots()`),
/// qui comptent les documents reçus du serveur. Les lectures venant du cache de l'appareil ou de nos propres écritures sont gratuites et ne
/// sont pas comptées. Toutes les 10 minutes (et quand l'application passe en arrière-plan), les 60 sources les plus actives sont envoyées au
/// serveur (`readStatsReport`), qui les additionne par jour. L'écran admin « Mesure des lectures » montre la session en cours et le total du jour.
class ReadMeter with WidgetsBindingObserver {
  ReadMeter._();
  static final ReadMeter instance = ReadMeter._();

  static const int maxTagsPerReport = 60;
  static const Duration every = Duration(minutes: 10);

  /// Coupé à distance (`AppConfig/readMeter.enabled = false`) : plus aucun envoi et plus de comptage.
  static bool enabled = false;

  /// Lectures de la session en cours (écran admin).
  final Map<String, int> session = {};
  final Map<String, int> _pending = {};
  Timer? _timer;
  bool _started = false;

  /// À appeler une fois connecté (accueil).
  void start() {
    if (_started || kIsWeb || !enabled) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(every, (_) => flush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) unawaited(flush());
  }

  static void add(String tag, int n) {
    if (!enabled || n <= 0) return;
    instance.session[tag] = (instance.session[tag] ?? 0) + n;
    instance._pending[tag] = (instance._pending[tag] ?? 0) + n;
  }

  /// Lecture d'une requête : un document par résultat reçu du serveur, une lecture au minimum (requête vide).
  static void countQuery(String tag, QuerySnapshot s) {
    if (s.metadata.isFromCache || s.metadata.hasPendingWrites) return;
    add(tag, s.docs.isEmpty ? 1 : s.docs.length);
  }

  /// Écoute : le premier instantané compte tous les documents, les suivants seulement ceux qui ont changé.
  static void countChanges(String tag, QuerySnapshot s, {required bool first}) {
    if (s.metadata.isFromCache || s.metadata.hasPendingWrites) return;
    final n = first ? s.docs.length : s.docChanges.length;
    add(tag, n == 0 && first ? 1 : n);
  }

  static void countDoc(String tag, DocumentSnapshot s) {
    if (s.metadata.isFromCache || s.metadata.hasPendingWrites) return;
    add(tag, 1);
  }

  /// Les [max] sources les plus actives d'un ensemble de compteurs.
  @visibleForTesting
  static Map<String, int> top(Map<String, int> all, {int max = maxTagsPerReport}) {
    final e = all.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return {for (final x in e.take(max)) x.key: x.value};
  }

  /// Plus d'envoi : la mesure est coupée.
  Future<void> flush() async {
    _pending.clear();
  }
}

/// Mêmes résultats que `get()`, avec comptage des lectures.
extension QueryReadMeter<T extends Object?> on Query<T> {
  Future<QuerySnapshot<T>> getM(String tag) async {
    final s = await get();
    ReadMeter.countQuery(tag, s);
    return s;
  }

  Stream<QuerySnapshot<T>> snapshotsM(String tag) {
    var first = true;
    return snapshots().map((s) {
      ReadMeter.countChanges(tag, s, first: first);
      first = false;
      return s;
    });
  }
}

extension DocReadMeter<T extends Object?> on DocumentReference<T> {
  Future<DocumentSnapshot<T>> getM(String tag) async {
    final s = await get();
    ReadMeter.countDoc(tag, s);
    return s;
  }

  Stream<DocumentSnapshot<T>> snapshotsM(String tag) {
    return snapshots().map((s) {
      ReadMeter.countDoc(tag, s);
      return s;
    });
  }
}

/// Comptage d'un agrégat (`count()`, `sum()`…) : facturé une lecture par tranche de 1 000 entrées d'index, comptée ici pour une.
extension AggregateReadMeter on AggregateQuery {
  Future<AggregateQuerySnapshot> getM(String tag) async {
    final s = await get();
    ReadMeter.add(tag, 1);
    return s;
  }
}
