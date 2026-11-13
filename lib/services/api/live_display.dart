/// Réglage « Affichage du live » : ce que l'hôte laisse voir à ses spectateurs. Chaque chiffre n'apparaît qu'une seule fois à l'écran :
/// spectateurs en pastille en haut à droite, pièces reçues sous le profil (avec le classement), « j'aime » et partages sous leurs boutons.
/// L'hôte voit toujours tout ; les spectateurs suivent ce réglage. Stocké dans `options.display` du live (API) et dans le document du live (temps réel).
class LiveDisplay {
  const LiveDisplay({required this.preset, required this.reactions, required this.coins, required this.messages});

  /// `essential` (par défaut), `complete`, `shop`, `duel`, `clean`.
  final String preset;

  /// Compteurs de « j'aime » et de partages sous leurs boutons.
  final bool reactions;

  /// Pièces reçues et classement sous le profil.
  final bool coins;

  /// Messages des spectateurs.
  final bool messages;

  static const presets = ['essential', 'complete', 'shop', 'duel', 'clean'];

  static const essential = LiveDisplay(preset: 'essential', reactions: false, coins: true, messages: true);
  static const complete = LiveDisplay(preset: 'complete', reactions: true, coins: true, messages: true);
  static const shop = LiveDisplay(preset: 'shop', reactions: false, coins: false, messages: true);
  static const duel = LiveDisplay(preset: 'duel', reactions: true, coins: true, messages: true);
  static const clean = LiveDisplay(preset: 'clean', reactions: false, coins: false, messages: false);

  static LiveDisplay byName(String name) => switch (name) {
        'complete' => complete,
        'shop' => shop,
        'duel' => duel,
        'clean' => clean,
        _ => essential,
      };

  /// Libellés des préréglages (clés du fichier de traduction).
  static String label(String preset) => switch (preset) {
        'complete' => 'Complet',
        'shop' => 'Vente',
        'duel' => 'Duel',
        'clean' => 'Épuré',
        _ => 'Essentiel',
      };

  LiveDisplay copyWith({bool? reactions, bool? coins, bool? messages}) =>
      LiveDisplay(preset: 'custom', reactions: reactions ?? this.reactions, coins: coins ?? this.coins, messages: messages ?? this.messages);

  Map<String, dynamic> toJson() => {'preset': preset, 'reactions': reactions, 'coins': coins, 'messages': messages};

  /// Lit le réglage ; sans réglage (anciens lives) : tout reste affiché comme avant.
  static LiveDisplay fromJson(Object? json) {
    if (json is! Map) return complete;
    final p = json['preset'];
    final base = p is String && presets.contains(p) ? byName(p) : complete;
    return LiveDisplay(
      preset: p is String ? p : base.preset,
      reactions: json['reactions'] is bool ? json['reactions'] as bool : base.reactions,
      coins: json['coins'] is bool ? json['coins'] as bool : base.coins,
      messages: json['messages'] is bool ? json['messages'] as bool : base.messages,
    );
  }

  @override
  bool operator ==(Object other) => other is LiveDisplay && other.preset == preset && other.reactions == reactions && other.coins == coins && other.messages == messages;

  @override
  int get hashCode => Object.hash(preset, reactions, coins, messages);
}
