import 'package:cloud_firestore/cloud_firestore.dart';

/// Palier de rémunération des vues selon le score créateur.
class ScoreTier {
  final double minScore;
  final double multiplier; // fraction du taux de base (0–1)
  final String label;

  const ScoreTier({required this.minScore, required this.multiplier, required this.label});

  factory ScoreTier.fromJson(Map<String, dynamic> j) => ScoreTier(
        minScore: (j['minScore'] as num?)?.toDouble() ?? 0,
        multiplier: (j['multiplier'] as num?)?.toDouble() ?? 0,
        label: j['label'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'minScore': minScore, 'multiplier': multiplier, 'label': label};
}

/// Barème de rémunération des vues — source unique : Firestore `config/monetization`,
/// lue aussi par la Cloud Function cashViewEarnings (encaissement).
/// Valeurs par défaut identiques à functions/src/posts/viewEarnings.ts.
class MonetizationConfig {
  static const double defaultBaseViewRate = 1.0; // FCFA max par vue
  static const List<ScoreTier> defaultTiers = [
    ScoreTier(minScore: 80, multiplier: 1.00, label: 'Élite'),
    ScoreTier(minScore: 50, multiplier: 0.80, label: 'Expert'),
    ScoreTier(minScore: 25, multiplier: 0.60, label: 'Avancé'),
    ScoreTier(minScore: 10, multiplier: 0.40, label: 'Standard'),
    ScoreTier(minScore: 0, multiplier: 0.20, label: 'Débutant'),
  ];

  static double baseViewRate = defaultBaseViewRate;
  static List<ScoreTier> tiers = defaultTiers;
  static DateTime? _loadedAt;

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('config').doc('monetization');

  /// Charge le barème (mis en cache 30 min). Garde les valeurs par défaut en cas d'erreur.
  static Future<void> load({bool force = false}) async {
    if (!force && _loadedAt != null && DateTime.now().difference(_loadedAt!) < const Duration(minutes: 30)) {
      return;
    }
    try {
      final data = (await _doc.get()).data() ?? {};
      baseViewRate = (data['baseViewRate'] as num?)?.toDouble() ?? defaultBaseViewRate;
      final raw = data['scoreTiers'] as List?;
      tiers = raw != null && raw.isNotEmpty
          ? (raw.map((e) => ScoreTier.fromJson(Map<String, dynamic>.from(e as Map))).toList()
            ..sort((a, b) => b.minScore.compareTo(a.minScore)))
          : defaultTiers;
      _loadedAt = DateTime.now();
    } catch (_) {}
  }

  /// Enregistre le barème (admin). Les paiements suivants l'utilisent immédiatement.
  static Future<void> save({required double base, required List<ScoreTier> newTiers, String? adminId}) async {
    final sorted = [...newTiers]..sort((a, b) => b.minScore.compareTo(a.minScore));
    await _doc.set({
      'baseViewRate': base,
      'scoreTiers': sorted.map((t) => t.toJson()).toList(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      if (adminId != null) 'updatedBy': adminId,
    }, SetOptions(merge: true));
    baseViewRate = base;
    tiers = sorted;
    _loadedAt = DateTime.now();
  }

  /// Palier correspondant au score (les paliers sont triés du plus haut au plus bas).
  static ScoreTier tierFor(double score) =>
      tiers.firstWhere((t) => score >= t.minScore, orElse: () => tiers.last);

  /// FCFA par vue pour ce score.
  static double ratePerView(double score) => baseViewRate * tierFor(score).multiplier;
}
