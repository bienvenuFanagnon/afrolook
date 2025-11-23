import 'package:cloud_firestore/cloud_firestore.dart';

class PriceHistory {
  final double price;
  final DateTime timestamp;
  final String? transactionType;
  final double? quantity;

  PriceHistory({
    required this.price,
    required this.timestamp,
    this.transactionType,
    this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'price': price,
      'timestamp': Timestamp.fromDate(timestamp),
      'transactionType': transactionType,
      'quantity': quantity,
    };
  }

  factory PriceHistory.fromMap(Map<String, dynamic> data) {
    return PriceHistory(
      price: (data['price'] ?? 0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      transactionType: data['transactionType'],
      quantity: data['quantity']?.toDouble(),
    );
  }
}

// Dans crypto_model.dart, ajoutez le champ emoji

class CryptoCurrency {
  final String id;
  final String symbol;
  final String name;
  final String imageUrl; // Contiendra l'emoji
  final double currentPrice;
  final double initialPrice;
  final double marketCap;
  final double circulatingSupply;
  final double totalSupply;
  final double dailyPriceChange;
  final double dailyVolume;
  final double dailyMaxChange;
  final double dailyMinChange;
  final DateTime lastUpdated;
  final List<PriceHistory> priceHistory;
  final String category;
  final int rank;
  final bool isTrending;
  final String emoji; // Nouveau champ dédié

  CryptoCurrency({
    required this.id,
    required this.symbol,
    required this.name,
    required this.imageUrl,
    required this.currentPrice,
    required this.initialPrice,
    required this.marketCap,
    required this.circulatingSupply,
    required this.totalSupply,
    this.dailyPriceChange = 0,
    this.dailyVolume = 0,
    this.dailyMaxChange = 0.2,
    this.dailyMinChange = -0.2,
    required this.lastUpdated,
    List<PriceHistory>? priceHistory,
    this.category = 'DeFi',
    this.rank = 0,
    this.isTrending = false,
    this.emoji = '🪙', // Valeur par défaut
  }) : priceHistory = priceHistory ?? [];

  factory CryptoCurrency.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    List<PriceHistory> priceHistory = [];
    if (data['priceHistory'] != null) {
      priceHistory = (data['priceHistory'] as List)
          .map((item) => PriceHistory.fromMap(item))
          .toList();
    }

    return CryptoCurrency(
      id: doc.id,
      symbol: data['symbol'] ?? '',
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      currentPrice: (data['currentPrice'] ?? 0).toDouble(),
      initialPrice: (data['initialPrice'] ?? 0).toDouble(),
      marketCap: (data['marketCap'] ?? 0).toDouble(),
      circulatingSupply: (data['circulatingSupply'] ?? 0).toDouble(),
      totalSupply: (data['totalSupply'] ?? 0).toDouble(),
      dailyPriceChange: (data['dailyPriceChange'] ?? 0).toDouble(),
      dailyVolume: (data['dailyVolume'] ?? 0).toDouble(),
      dailyMaxChange: (data['dailyMaxChange'] ?? 0.20).toDouble(),
      dailyMinChange: (data['dailyMinChange'] ?? -0.20).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      priceHistory: priceHistory,
      category: data['category'] ?? 'DeFi',
      rank: data['rank'] ?? 0,
      isTrending: data['isTrending'] ?? false,
      emoji: data['emoji'] ?? data['imageUrl'] ?? '🪙', // Fallback sur imageUrl si emoji n'existe pas
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'name': name,
      'imageUrl': imageUrl,
      'currentPrice': currentPrice,
      'initialPrice': initialPrice,
      'marketCap': marketCap,
      'circulatingSupply': circulatingSupply,
      'totalSupply': totalSupply,
      'dailyPriceChange': dailyPriceChange,
      'dailyVolume': dailyVolume,
      'dailyMaxChange': dailyMaxChange,
      'dailyMinChange': dailyMinChange,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'priceHistory': priceHistory.map((h) => h.toMap()).toList(),
      'category': category,
      'rank': rank,
      'isTrending': isTrending,
      'emoji': emoji, // Inclure l'emoji dans la sauvegarde
    };
  }

  CryptoCurrency copyWith({
    String? symbol,
    String? name,
    String? imageUrl,
    double? currentPrice,
    double? initialPrice,
    double? marketCap,
    double? circulatingSupply,
    double? totalSupply,
    double? dailyPriceChange,
    double? dailyVolume,
    double? dailyMaxChange,
    double? dailyMinChange,
    DateTime? lastUpdated,
    List<PriceHistory>? priceHistory,
    String? category,
    int? rank,
    bool? isTrending,
    String? emoji,
  }) {
    return CryptoCurrency(
      id: id,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      currentPrice: currentPrice ?? this.currentPrice,
      initialPrice: initialPrice ?? this.initialPrice,
      marketCap: marketCap ?? this.marketCap,
      circulatingSupply: circulatingSupply ?? this.circulatingSupply,
      totalSupply: totalSupply ?? this.totalSupply,
      dailyPriceChange: dailyPriceChange ?? this.dailyPriceChange,
      dailyVolume: dailyVolume ?? this.dailyVolume,
      dailyMaxChange: dailyMaxChange ?? this.dailyMaxChange,
      dailyMinChange: dailyMinChange ?? this.dailyMinChange,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      priceHistory: priceHistory ?? this.priceHistory,
      category: category ?? this.category,
      rank: rank ?? this.rank,
      isTrending: isTrending ?? this.isTrending,
      emoji: emoji ?? this.emoji,
    );
  }
}
class CryptoPortfolio {
  final String userId;
  double balance;
  List<OwnedCrypto> ownedCryptos;
  double totalValue;
  double dailyProfitLoss;
  double totalProfitLoss;

  CryptoPortfolio({
    required this.userId,
    required this.balance,
    required this.ownedCryptos,
    this.totalValue = 0,
    this.dailyProfitLoss = 0,
    this.totalProfitLoss = 0,
  });

  factory CryptoPortfolio.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return CryptoPortfolio(
      userId: doc.id,
      balance: (data['balance'] ?? 0).toDouble(),
      ownedCryptos: (data['ownedCryptos'] as List? ?? [])
          .map((e) => OwnedCrypto.fromMap(e))
          .toList(),
      totalValue: (data['totalValue'] ?? 0).toDouble(),
      dailyProfitLoss: (data['dailyProfitLoss'] ?? 0).toDouble(),
      totalProfitLoss: (data['totalProfitLoss'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'balance': balance,
      'ownedCryptos': ownedCryptos.map((e) => e.toMap()).toList(),
      'totalValue': totalValue,
      'dailyProfitLoss': dailyProfitLoss,
      'totalProfitLoss': totalProfitLoss,
    };
  }

  CryptoPortfolio copyWith({
    String? userId,
    double? balance,
    List<OwnedCrypto>? ownedCryptos,
    double? totalValue,
    double? dailyProfitLoss,
    double? totalProfitLoss,
  }) {
    return CryptoPortfolio(
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      ownedCryptos: ownedCryptos ?? this.ownedCryptos,
      totalValue: totalValue ?? this.totalValue,
      dailyProfitLoss: dailyProfitLoss ?? this.dailyProfitLoss,
      totalProfitLoss: totalProfitLoss ?? this.totalProfitLoss,
    );
  }
}

class OwnedCrypto {
  final String cryptoId;
  double quantity;
  double averageBuyPrice;
  double currentValue;
  double profitLoss;

  OwnedCrypto({
    required this.cryptoId,
    required this.quantity,
    required this.averageBuyPrice,
    this.currentValue = 0,
    this.profitLoss = 0,
  });

  factory OwnedCrypto.fromMap(Map<String, dynamic> map) {
    return OwnedCrypto(
      cryptoId: map['cryptoId'],
      quantity: (map['quantity'] ?? 0).toDouble(),
      averageBuyPrice: (map['averageBuyPrice'] ?? 0).toDouble(),
      currentValue: (map['currentValue'] ?? 0).toDouble(),
      profitLoss: (map['profitLoss'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cryptoId': cryptoId,
      'quantity': quantity,
      'averageBuyPrice': averageBuyPrice,
      'currentValue': currentValue,
      'profitLoss': profitLoss,
    };
  }

  OwnedCrypto copyWith({
    String? cryptoId,
    double? quantity,
    double? averageBuyPrice,
    double? currentValue,
    double? profitLoss,
  }) {
    return OwnedCrypto(
      cryptoId: cryptoId ?? this.cryptoId,
      quantity: quantity ?? this.quantity,
      averageBuyPrice: averageBuyPrice ?? this.averageBuyPrice,
      currentValue: currentValue ?? this.currentValue,
      profitLoss: profitLoss ?? this.profitLoss,
    );
  }
}

class CryptoTransaction {
  final String id;
  final String userId;
  final String cryptoId;
  final double unitPrice;
  final double quantity;
  final DateTime date;
  final TransactionType type;
  final double profit;
  final double commission;

  CryptoTransaction({
    required this.id,
    required this.userId,
    required this.cryptoId,
    required this.unitPrice,
    required this.quantity,
    required this.date,
    required this.type,
    required this.profit,
    required this.commission,
  });

  factory CryptoTransaction.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return CryptoTransaction(
      id: doc.id,
      userId: data['userId'],
      cryptoId: data['cryptoId'],
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      quantity: (data['quantity'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      type: data['type'] == 'buy' ? TransactionType.buy : TransactionType.sell,
      profit: (data['profit'] ?? 0).toDouble(),
      commission: (data['commission'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'cryptoId': cryptoId,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'date': Timestamp.fromDate(date),
      'type': type == TransactionType.buy ? 'buy' : 'sell',
      'profit': profit,
      'commission': commission,
    };
  }
}

enum TransactionType { buy, sell }