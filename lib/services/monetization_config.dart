import 'api/api_gateway.dart';

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

/// Barème de rémunération des vues — source unique : l'API (réglages publics `GET /config`, clé `monetization`),
/// la même que celle qui calcule l'encaissement.
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

  /// Charge le barème (mis en cache 30 min). Garde les valeurs par défaut en cas d'erreur ou si l'API ne le publie pas encore.
  static Future<void> load({bool force = false}) async {
    if (!force && _loadedAt != null && DateTime.now().difference(_loadedAt!) < const Duration(minutes: 30)) {
      return;
    }
    try {
      final r = await ApiGateway.instance.client.get('/config');
      final root = r is Map ? r['data'] : null;
      final data = root is Map && root['monetization'] is Map ? Map<String, dynamic>.from(root['monetization'] as Map) : <String, dynamic>{};
      // Format de l'API : base_rate_xof + tiers[{min_score, multiplier, label}] (ancien format baseViewRate / scoreTiers accepté)
      baseViewRate = ((data['base_rate_xof'] ?? data['baseViewRate']) as num?)?.toDouble() ?? defaultBaseViewRate;
      final raw = (data['tiers'] ?? data['scoreTiers']) as List?;
      tiers = raw != null && raw.isNotEmpty
          ? (raw.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              return ScoreTier.fromJson({'minScore': m['min_score'] ?? m['minScore'], 'multiplier': m['multiplier'], 'label': m['label']});
            }).toList()
            ..sort((a, b) => b.minScore.compareTo(a.minScore)))
          : defaultTiers;
      _loadedAt = DateTime.now();
    } catch (_) {}
  }

  /// Enregistre le barème (admin). PUT /admin/settings/monetization (droit « config.edit », connexion récente exigée) :
  /// l'erreur est transmise à l'écran.
  static Future<void> save({required double base, required List<ScoreTier> newTiers, String? adminId}) async {
    final sorted = [...newTiers]..sort((a, b) => b.minScore.compareTo(a.minScore));
    await ApiGateway.instance.client.put('/admin/settings/monetization', body: {
      'baseViewRate': base,
      'scoreTiers': sorted.map((t) => t.toJson()).toList(),
    });
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
