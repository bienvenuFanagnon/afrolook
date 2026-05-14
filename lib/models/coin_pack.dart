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
    CoinPack(coins: 500, priceFcfa: 250, icon: '🪙', label: 'Pack Découverte'),

    CoinPack(coins: 1200, priceFcfa: 500, icon: '⭐', label: 'Pack Starter'),

    CoinPack(coins: 2600, priceFcfa: 1000, icon: '🌟', label: 'Pack Bronze'),

    CoinPack(
      coins: 5500,
      priceFcfa: 2000,
      icon: '🔥',
      label: 'Pack Silver',
      isPopular: true,
      popularLabel: 'POPULAIRE',
    ),

    CoinPack(
      coins: 14500,
      priceFcfa: 5000,
      icon: '💎',
      label: 'Pack Gold',
      isPopular: true,
      popularLabel: '⭐ RECOMMANDÉ',
    ),

    CoinPack(coins: 32000, priceFcfa: 10000, icon: '👑', label: 'Pack Platinum'),

    CoinPack(coins: 70000, priceFcfa: 20000, icon: '🏆', label: 'Pack Diamond'),

    CoinPack(coins: 190000, priceFcfa: 50000, icon: '💎', label: 'Pack Legend'),

    CoinPack(coins: 420000, priceFcfa: 100000, icon: '👑', label: 'Pack Ultimate'),
  ];

  static List<CoinPack> get giftPacks => [
    CoinPack(coins: 5, priceFcfa: 2, icon: '🌟', label: 'Petit cœur'),

    CoinPack(coins: 15, priceFcfa: 6, icon: '🙂', label: 'Sourire'),

    CoinPack(coins: 25, priceFcfa: 10, icon: '👏', label: 'Ovations'),

    CoinPack(coins: 40, priceFcfa: 18, icon: '💪', label: 'Encouragement'),

    CoinPack(coins: 50, priceFcfa: 20, icon: '❤️', label: 'Cœur'),

    CoinPack(coins: 100, priceFcfa: 40, icon: '😂', label: 'Rire'),

    CoinPack(coins: 150, priceFcfa: 80, icon: '😢', label: 'Tristesse'),

    CoinPack(coins: 180, priceFcfa: 100, icon: '😭', label: 'Pleurs'),

    CoinPack(coins: 220, priceFcfa: 130, icon: '😳', label: 'Gêne'),

    CoinPack(coins: 250, priceFcfa: 180, icon: '😏', label: 'Moquerie'),

    CoinPack(coins: 350, priceFcfa: 250, icon: '💎', label: 'Diamant'),

    CoinPack(coins: 500, priceFcfa: 350, icon: '👑', label: 'Couronne'),

    CoinPack(coins: 1000, priceFcfa: 700, icon: '🚗', label: 'Voiture'),

    CoinPack(coins: 2500, priceFcfa: 1700, icon: '🏠', label: 'Maison'),

    CoinPack(coins: 5000, priceFcfa: 3200, icon: '🚀', label: 'Fusée'),

    CoinPack(coins: 10000, priceFcfa: 6000, icon: '☄️', label: 'Étoile filante'),

    CoinPack(coins: 25000, priceFcfa: 14000, icon: '🏆', label: 'Trophée'),

    CoinPack(coins: 50000, priceFcfa: 26000, icon: '🌸', label: 'Diamant rose'),

    CoinPack(coins: 100000, priceFcfa: 50000, icon: '🦁', label: 'Couronne royale'),

    CoinPack(coins: 250000, priceFcfa: 120000, icon: '🖤', label: 'Diamant noir'),

    CoinPack(coins: 500000, priceFcfa: 230000, icon: '🏰', label: 'Château'),

    CoinPack(coins: 1000000, priceFcfa: 450000, icon: '⚜️', label: 'Empire royal'),
  ];

}

// models/post_gift.dart
class PostGift {
  String? id;
  String? postId;
  String? senderId;
  String? receiverId;
  String? giftIcon;      // Emoji du cadeau (🌟, ❤️, 💎, etc.)
  String? giftLabel;     // Label du cadeau (Petit cœur, Diamant, etc.)
  int? coinsAmount;      // Nombre de pièces du cadeau
  int? quantity;         // Quantité de ce type de cadeau (pour agrégation)
  int? createdAt;

  // Pour l'affichage agrégé
  int? totalCount;       // Nombre total d'envois de ce type
  int? totalCoins;       // Total des pièces pour ce type

  PostGift({
    this.id,
    this.postId,
    this.senderId,
    this.receiverId,
    this.giftIcon,
    this.giftLabel,
    this.coinsAmount,
    this.quantity = 1,
    this.createdAt,
    this.totalCount,
    this.totalCoins,
  });

  PostGift.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    postId = json['postId'];
    senderId = json['senderId'];
    receiverId = json['receiverId'];
    giftIcon = json['giftIcon'];
    giftLabel = json['giftLabel'];
    coinsAmount = json['coinsAmount'];
    quantity = json['quantity'] ?? 1;
    createdAt = json['createdAt'];
    totalCount = json['totalCount'];
    totalCoins = json['totalCoins'];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'senderId': senderId,
      'giftIcon': giftIcon,
      'giftLabel': giftLabel,
      'coinsAmount': coinsAmount,
      'quantity': quantity,
      'createdAt': createdAt,
    };
  }

  // Constructeur pour l'agrégation
  PostGift.aggregated({
    this.giftIcon,
    this.giftLabel,
    this.coinsAmount,
    this.totalCount,
    this.totalCoins,
  });
}