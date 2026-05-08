// models/coin_pack.dart
class CoinPack {
  final int coins;
  final double priceFcfa;
  final String icon;
  final String label;
  final bool isPopular;
  final String? popularLabel;

  CoinPack({
    required this.coins,
    required this.priceFcfa,
    this.icon = '🪙',
    this.label = '',
    this.isPopular = false,
    this.popularLabel,
  });

  String get displayLabel => label.isNotEmpty ? label : '$coins pièces';
  String get displayPrice => '${priceFcfa.toInt()} FCFA';
  int get fcfaPerCoin => (priceFcfa / coins).ceil();

  static List<CoinPack> get defaultPacks => [
    CoinPack(coins: 5, priceFcfa: 2, icon: '🌟', label: 'Mini'),
    CoinPack(coins: 25, priceFcfa: 10, icon: '❤️', label: 'Cœur'),
    CoinPack(coins: 50, priceFcfa: 20, icon: '💎', label: 'Diamant'),
    CoinPack(coins: 100, priceFcfa: 40, icon: '👑', label: 'Couronne'),
    CoinPack(coins: 250, priceFcfa: 100, icon: '🚗', label: 'Voiture'),
    CoinPack(coins: 500, priceFcfa: 200, icon: '🏠', label: 'Maison'),
    CoinPack(coins: 1000, priceFcfa: 400, icon: '🚀', label: 'Fusée'),
    CoinPack(coins: 2500, priceFcfa: 1000, icon: '⭐', label: 'Étoile filante'),
    CoinPack(coins: 5000, priceFcfa: 2000, icon: '🏆', label: 'Trophée'),
    CoinPack(coins: 10000, priceFcfa: 4000, icon: '💎', label: 'Diamant rose'),
    CoinPack(coins: 25000, priceFcfa: 10000, icon: '👑', label: 'Couronne royale'),
    CoinPack(coins: 50000, priceFcfa: 20000, icon: '💎', label: 'Diamant noir'),
    CoinPack(coins: 100000, priceFcfa: 40000, icon: '🏰', label: 'Château'),
    CoinPack(coins: 250000, priceFcfa: 100000, icon: '💎', label: 'Trésor'),
  ];

  // Packs pour la recharge (avec mise en avant)
  static List<CoinPack> get rechargePacks => [
    CoinPack(coins: 500, priceFcfa: 200, icon: '🪙', label: 'Pack Découverte'),
    CoinPack(coins: 1000, priceFcfa: 400, icon: '⭐', label: 'Pack Starter'),
    CoinPack(coins: 2500, priceFcfa: 1000, icon: '🌟', label: 'Pack Bronze'),
    CoinPack(coins: 5000, priceFcfa: 2000, icon: '🔥', label: 'Pack Silver', isPopular: true, popularLabel: 'POPULAIRE'),
    CoinPack(coins: 12500, priceFcfa: 5000, icon: '💎', label: 'Pack Gold', isPopular: true, popularLabel: '⭐ RECOMMANDÉ'),
    CoinPack(coins: 25000, priceFcfa: 10000, icon: '👑', label: 'Pack Platinum'),
    CoinPack(coins: 50000, priceFcfa: 20000, icon: '🏆', label: 'Pack Diamond'),
    CoinPack(coins: 125000, priceFcfa: 50000, icon: '💎', label: 'Pack Legend'),
    CoinPack(coins: 250000, priceFcfa: 100000, icon: '👑', label: 'Pack Ultimate'),
  ];

  // Packs pour les cadeaux (dialog)
  static List<CoinPack> get giftPacks => [
    CoinPack(coins: 5, priceFcfa: 2, icon: '🌟', label: 'Petit cœur'),
    CoinPack(coins: 25, priceFcfa: 10, icon: '❤️', label: 'Cœur'),
    CoinPack(coins: 50, priceFcfa: 20, icon: '💎', label: 'Diamant'),
    CoinPack(coins: 100, priceFcfa: 40, icon: '👑', label: 'Couronne'),
    CoinPack(coins: 250, priceFcfa: 100, icon: '🚗', label: 'Voiture'),
    CoinPack(coins: 500, priceFcfa: 200, icon: '🏠', label: 'Maison'),
    CoinPack(coins: 1000, priceFcfa: 400, icon: '🚀', label: 'Fusée'),
    CoinPack(coins: 2500, priceFcfa: 1000, icon: '⭐', label: 'Étoile filante'),
    CoinPack(coins: 5000, priceFcfa: 2000, icon: '🏆', label: 'Trophée'),
    CoinPack(coins: 10000, priceFcfa: 4000, icon: '💎', label: 'Diamant rose'),
    CoinPack(coins: 25000, priceFcfa: 10000, icon: '👑', label: 'Couronne royale'),
    CoinPack(coins: 50000, priceFcfa: 20000, icon: '💎', label: 'Diamant noir'),
    CoinPack(coins: 100000, priceFcfa: 40000, icon: '🏰', label: 'Château'),
    CoinPack(coins: 250000, priceFcfa: 100000, icon: '💎', label: 'Trésor'),
  ];
}