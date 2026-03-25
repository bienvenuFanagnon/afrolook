// lib/models/enums/coin_transaction_type.dart
enum CoinTransactionType {
  buy_coins,
  spend_subscription,
  spend_creator_subscription,
  spend_paid_content,
  spend_boost,
  earn_creator_subscription,
  earn_paid_content,
  convert_to_xof,
  refund;

  String get value => toString().split('.').last;

  static CoinTransactionType fromString(String value) {
    return values.firstWhere((e) => e.value == value);
  }
}

// lib/models/enums/transaction_status.dart
enum TransactionStatus {
  pending,
  success,
  failed,
  canceled,
  approved,
  rejected,
  paid,
  refunded;

  String get value => toString().split('.').last;

  static TransactionStatus fromString(String value) {
    return values.firstWhere((e) => e.value == value);
  }
}

// lib/models/enums/reaction_type.dart
enum ReactionType {
  like,
  love,
  unlike;

  String get value => toString().split('.').last;

  static ReactionType fromString(String value) {
    return values.firstWhere((e) => e.value == value);
  }
}

// lib/models/enums/media_type.dart
enum MediaType {
  image,
  video,
  text;

  String get value => toString().split('.').last;

  static MediaType fromString(String value) {
    return values.firstWhere((e) => e.value == value);
  }
}

// lib/models/enums/creator_type.dart
enum CreatorType {
  influencer,
  artist,
  educator,
  entertainer,
  other;

  String get value => toString().split('.').last;

  static CreatorType fromString(String value) {
    return values.firstWhere((e) => e.value == value);
  }
}

// lib/models/enums/message_type.dart
enum MessageType {
  text,
  image,
  audio,
    voice,
  custom,
  emoji;

  String get value => toString().split('.').last;

  static MessageType fromString(String value) {
    return values.firstWhere((e) => e.value == value);
  }
}