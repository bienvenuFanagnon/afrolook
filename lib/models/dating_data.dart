

import 'enums.dart';
/* flutter pub run build_runner build */

///// Dating //////////
// lib/models/coin_package.dart
class CoinPackage {
  final String id;
  final String name;
  final int coinsAmount;
  final double priceXof;
  final bool isActive;
  final int createdAt;
  final int updatedAt;

  CoinPackage({
    required this.id,
    required this.name,
    required this.coinsAmount,
    required this.priceXof,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoinPackage.fromJson(Map<String, dynamic> json) {
    return CoinPackage(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      coinsAmount: json['coinsAmount'] ?? 0,
      priceXof: (json['priceXof'] as num?)?.toDouble() ?? 0.0,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coinsAmount': coinsAmount,
      'priceXof': priceXof,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  CoinPackage copyWith({
    String? id,
    String? name,
    int? coinsAmount,
    double? priceXof,
    bool? isActive,
    int? createdAt,
    int? updatedAt,
  }) {
    return CoinPackage(
      id: id ?? this.id,
      name: name ?? this.name,
      coinsAmount: coinsAmount ?? this.coinsAmount,
      priceXof: priceXof ?? this.priceXof,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// lib/models/user_coin_transaction.dart
class UserCoinTransaction {
  final String id;
  final String userId;
  final CoinTransactionType type;
  final int coinsAmount;
  final double xofAmount;
  final String referenceId;
  final String description;
  final TransactionStatus status;
  final int createdAt;
  final int updatedAt;

  UserCoinTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.coinsAmount,
    required this.xofAmount,
    required this.referenceId,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserCoinTransaction.fromJson(Map<String, dynamic> json) {
    return UserCoinTransaction(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      type: CoinTransactionType.fromString(json['type'] ?? 'buy_coins'),
      coinsAmount: json['coinsAmount'] ?? 0,
      xofAmount: (json['xofAmount'] as num?)?.toDouble() ?? 0.0,
      referenceId: json['referenceId']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: TransactionStatus.fromString(json['status'] ?? 'pending'),
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.value,
      'coinsAmount': coinsAmount,
      'xofAmount': xofAmount,
      'referenceId': referenceId,
      'description': description,
      'status': status.value,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  UserCoinTransaction copyWith({
    String? id,
    String? userId,
    CoinTransactionType? type,
    int? coinsAmount,
    double? xofAmount,
    String? referenceId,
    String? description,
    TransactionStatus? status,
    int? createdAt,
    int? updatedAt,
  }) {
    return UserCoinTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      coinsAmount: coinsAmount ?? this.coinsAmount,
      xofAmount: xofAmount ?? this.xofAmount,
      referenceId: referenceId ?? this.referenceId,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


// lib/models/creator_coin_wallet.dart
class CreatorCoinWallet {
  final String id;
  final String creatorId;
  final String userId;
  final int balanceCoins;
  final int totalEarnedCoins;
  final int totalConvertedCoins;
  final int updatedAt;
  final int createdAt;

  CreatorCoinWallet({
    required this.id,
    required this.creatorId,
    required this.userId,
    required this.balanceCoins,
    required this.totalEarnedCoins,
    required this.totalConvertedCoins,
    required this.updatedAt,
    required this.createdAt,
  });

  factory CreatorCoinWallet.fromJson(Map<String, dynamic> json) {
    return CreatorCoinWallet(
      id: json['id']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      balanceCoins: json['balanceCoins'] ?? 0,
      totalEarnedCoins: json['totalEarnedCoins'] ?? 0,
      totalConvertedCoins: json['totalConvertedCoins'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
      createdAt: json['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creatorId': creatorId,
      'userId': userId,
      'balanceCoins': balanceCoins,
      'totalEarnedCoins': totalEarnedCoins,
      'totalConvertedCoins': totalConvertedCoins,
      'updatedAt': updatedAt,
      'createdAt': createdAt,
    };
  }

  CreatorCoinWallet copyWith({
    String? id,
    String? creatorId,
    String? userId,
    int? balanceCoins,
    int? totalEarnedCoins,
    int? totalConvertedCoins,
    int? updatedAt,
    int? createdAt,
  }) {
    return CreatorCoinWallet(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      userId: userId ?? this.userId,
      balanceCoins: balanceCoins ?? this.balanceCoins,
      totalEarnedCoins: totalEarnedCoins ?? this.totalEarnedCoins,
      totalConvertedCoins: totalConvertedCoins ?? this.totalConvertedCoins,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


// lib/models/creator_coin_conversion.dart
class CreatorCoinConversion {
  final String id;
  final String creatorId;
  final String userId;
  final int coinsAmount;
  final double xofAmount;
  final double conversionRate;
  final TransactionStatus status;
  final int requestedAt;
  final int? validatedAt;
  final int createdAt;
  final int updatedAt;

  CreatorCoinConversion({
    required this.id,
    required this.creatorId,
    required this.userId,
    required this.coinsAmount,
    required this.xofAmount,
    required this.conversionRate,
    required this.status,
    required this.requestedAt,
    this.validatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CreatorCoinConversion.fromJson(Map<String, dynamic> json) {
    return CreatorCoinConversion(
      id: json['id']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      coinsAmount: json['coinsAmount'] ?? 0,
      xofAmount: (json['xofAmount'] as num?)?.toDouble() ?? 0.0,
      conversionRate: (json['conversionRate'] as num?)?.toDouble() ?? 2.5,
      status: TransactionStatus.fromString(json['status'] ?? 'pending'),
      requestedAt: json['requestedAt'] ?? 0,
      validatedAt: json['validatedAt'],
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creatorId': creatorId,
      'userId': userId,
      'coinsAmount': coinsAmount,
      'xofAmount': xofAmount,
      'conversionRate': conversionRate,
      'status': status.value,
      'requestedAt': requestedAt,
      'validatedAt': validatedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  CreatorCoinConversion copyWith({
    String? id,
    String? creatorId,
    String? userId,
    int? coinsAmount,
    double? xofAmount,
    double? conversionRate,
    TransactionStatus? status,
    int? requestedAt,
    int? validatedAt,
    int? createdAt,
    int? updatedAt,
  }) {
    return CreatorCoinConversion(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      userId: userId ?? this.userId,
      coinsAmount: coinsAmount ?? this.coinsAmount,
      xofAmount: xofAmount ?? this.xofAmount,
      conversionRate: conversionRate ?? this.conversionRate,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      validatedAt: validatedAt ?? this.validatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}



// lib/models/dating_profile.dart
// lib/models/dating_data.dart - Ajouter les champs pays et région

// lib/models/dating_data.dart

class DatingProfile {
  final String id;
  final String userId;
  final String pseudo;
  final String imageUrl;
  final List<String> photosUrls;
  final String bio;
  final int age;
  final String sexe;
  final String ville;
  final String pays;
  final String? profession;
  final List<String> centresInteret;
  final String rechercheSexe;
  final int rechercheAgeMin;
  final int rechercheAgeMax;
  final String recherchePays;
  final bool isVerified;
  final bool isActive;
  final bool isProfileComplete;
  final double completionPercentage;
  final bool createdByMigration;
  final int likesCount;
  final int coupsDeCoeurCount;
  final int connexionsCount;
  final int visitorsCount;
  final int createdAt;
  final int updatedAt;

  // Nouveaux champs pour la localisation
  final String? countryCode;
  final String? region;
  final String? city;

  // ✅ NOUVEAU CHAMP: Score de popularité
  final int popularityScore;

  DatingProfile({
    required this.id,
    required this.userId,
    required this.pseudo,
    required this.imageUrl,
    required this.photosUrls,
    required this.bio,
    required this.age,
    required this.sexe,
    required this.ville,
    required this.pays,
    this.profession,
    required this.centresInteret,
    required this.rechercheSexe,
    required this.rechercheAgeMin,
    required this.rechercheAgeMax,
    required this.recherchePays,
    required this.isVerified,
    required this.isActive,
    required this.isProfileComplete,
    required this.completionPercentage,
    required this.createdByMigration,
    required this.likesCount,
    required this.coupsDeCoeurCount,
    required this.connexionsCount,
    required this.visitorsCount,
    required this.createdAt,
    required this.updatedAt,
    this.countryCode,
    this.region,
    this.city,
    required this.popularityScore,
  });

  factory DatingProfile.fromJson(Map<String, dynamic> json) {
    return DatingProfile(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      pseudo: json['pseudo']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      photosUrls: (json['photosUrls'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      bio: json['bio']?.toString() ?? '',
      age: json['age'] ?? 0,
      sexe: json['sexe']?.toString() ?? '',
      ville: json['ville']?.toString() ?? '',
      pays: json['pays']?.toString() ?? '',
      profession: json['profession']?.toString(),
      centresInteret: (json['centresInteret'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      rechercheSexe: json['rechercheSexe']?.toString() ?? '',
      rechercheAgeMin: json['rechercheAgeMin'] ?? 0,
      rechercheAgeMax: json['rechercheAgeMax'] ?? 0,
      recherchePays: json['recherchePays']?.toString() ?? '',
      isVerified: json['isVerified'] ?? false,
      isActive: json['isActive'] ?? true,
      isProfileComplete: json['isProfileComplete'] ?? false,
      completionPercentage: (json['completionPercentage'] as num?)?.toDouble() ?? 0.0,
      createdByMigration: json['createdByMigration'] ?? false,
      likesCount: json['likesCount'] ?? 0,
      coupsDeCoeurCount: json['coupsDeCoeurCount'] ?? 0,
      connexionsCount: json['connexionsCount'] ?? 0,
      visitorsCount: json['visitorsCount'] ?? 0,
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
      countryCode: json['countryCode']?.toString(),
      region: json['region']?.toString(),
      city: json['city']?.toString(),
      popularityScore: json['popularityScore'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'pseudo': pseudo,
      'imageUrl': imageUrl,
      'photosUrls': photosUrls,
      'bio': bio,
      'age': age,
      'sexe': sexe,
      'ville': ville,
      'pays': pays,
      'profession': profession,
      'centresInteret': centresInteret,
      'rechercheSexe': rechercheSexe,
      'rechercheAgeMin': rechercheAgeMin,
      'rechercheAgeMax': rechercheAgeMax,
      'recherchePays': recherchePays,
      'isVerified': isVerified,
      'isActive': isActive,
      'isProfileComplete': isProfileComplete,
      'completionPercentage': completionPercentage,
      'createdByMigration': createdByMigration,
      'likesCount': likesCount,
      'coupsDeCoeurCount': coupsDeCoeurCount,
      'connexionsCount': connexionsCount,
      'visitorsCount': visitorsCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'countryCode': countryCode,
      'region': region,
      'city': city,
      'popularityScore': popularityScore,
    };
  }

  DatingProfile copyWith({
    String? id,
    String? userId,
    String? pseudo,
    String? imageUrl,
    List<String>? photosUrls,
    String? bio,
    int? age,
    String? sexe,
    String? ville,
    String? pays,
    String? profession,
    List<String>? centresInteret,
    String? rechercheSexe,
    int? rechercheAgeMin,
    int? rechercheAgeMax,
    String? recherchePays,
    bool? isVerified,
    bool? isActive,
    bool? isProfileComplete,
    double? completionPercentage,
    bool? createdByMigration,
    int? likesCount,
    int? coupsDeCoeurCount,
    int? connexionsCount,
    int? visitorsCount,
    int? createdAt,
    int? updatedAt,
    String? countryCode,
    String? region,
    String? city,
    int? popularityScore,
  }) {
    return DatingProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      pseudo: pseudo ?? this.pseudo,
      imageUrl: imageUrl ?? this.imageUrl,
      photosUrls: photosUrls ?? this.photosUrls,
      bio: bio ?? this.bio,
      age: age ?? this.age,
      sexe: sexe ?? this.sexe,
      ville: ville ?? this.ville,
      pays: pays ?? this.pays,
      profession: profession ?? this.profession,
      centresInteret: centresInteret ?? this.centresInteret,
      rechercheSexe: rechercheSexe ?? this.rechercheSexe,
      rechercheAgeMin: rechercheAgeMin ?? this.rechercheAgeMin,
      rechercheAgeMax: rechercheAgeMax ?? this.rechercheAgeMax,
      recherchePays: recherchePays ?? this.recherchePays,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      createdByMigration: createdByMigration ?? this.createdByMigration,
      likesCount: likesCount ?? this.likesCount,
      coupsDeCoeurCount: coupsDeCoeurCount ?? this.coupsDeCoeurCount,
      connexionsCount: connexionsCount ?? this.connexionsCount,
      visitorsCount: visitorsCount ?? this.visitorsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      countryCode: countryCode ?? this.countryCode,
      region: region ?? this.region,
      city: city ?? this.city,
      popularityScore: popularityScore ?? this.popularityScore,
    );
  }
}

// lib/models/dating_like.dart
class DatingLike {
  final String id;
  final String fromUserId;
  final String toUserId;
  final int createdAt;

  DatingLike({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.createdAt,
  });

  factory DatingLike.fromJson(Map<String, dynamic> json) {
    return DatingLike(
      id: json['id']?.toString() ?? '',
      fromUserId: json['fromUserId']?.toString() ?? '',
      toUserId: json['toUserId']?.toString() ?? '',
      createdAt: json['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'createdAt': createdAt,
    };
  }

  DatingLike copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    int? createdAt,
  }) {
    return DatingLike(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


// lib/models/dating_coup_de_coeur.dart
class DatingCoupDeCoeur {
  final String id;
  final String fromUserId;
  final String toUserId;
  final int createdAt;

  DatingCoupDeCoeur({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.createdAt,
  });

  factory DatingCoupDeCoeur.fromJson(Map<String, dynamic> json) {
    return DatingCoupDeCoeur(
      id: json['id']?.toString() ?? '',
      fromUserId: json['fromUserId']?.toString() ?? '',
      toUserId: json['toUserId']?.toString() ?? '',
      createdAt: json['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'createdAt': createdAt,
    };
  }

  DatingCoupDeCoeur copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    int? createdAt,
  }) {
    return DatingCoupDeCoeur(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


// lib/models/dating_connection.dart
class DatingConnection {
  final String id;
  final String userId1;
  final String userId2;
  final int createdAt;
  final int? lastMessageAt;
  final bool isActive;

  DatingConnection({
    required this.id,
    required this.userId1,
    required this.userId2,
    required this.createdAt,
    this.lastMessageAt,
    required this.isActive,
  });

  factory DatingConnection.fromJson(Map<String, dynamic> json) {
    return DatingConnection(
      id: json['id']?.toString() ?? '',
      userId1: json['userId1']?.toString() ?? '',
      userId2: json['userId2']?.toString() ?? '',
      createdAt: json['createdAt'] ?? 0,
      lastMessageAt: json['lastMessageAt'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId1': userId1,
      'userId2': userId2,
      'createdAt': createdAt,
      'lastMessageAt': lastMessageAt,
      'isActive': isActive,
    };
  }

  DatingConnection copyWith({
    String? id,
    String? userId1,
    String? userId2,
    int? createdAt,
    int? lastMessageAt,
    bool? isActive,
  }) {
    return DatingConnection(
      id: id ?? this.id,
      userId1: userId1 ?? this.userId1,
      userId2: userId2 ?? this.userId2,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      isActive: isActive ?? this.isActive,
    );
  }
}


// lib/models/dating_conversation.dart
class DatingConversation {
  final String id;
  final String connectionId;
  final String userId1;
  final String userId2;
  final String? lastMessage;
  final MessageType? lastMessageType;
  final String? lastMessageSenderId;
  final int? lastMessageAt;
  final int unreadCountUser1;
  final int unreadCountUser2;
  final int createdAt;
  final int updatedAt;

  DatingConversation({
    required this.id,
    required this.connectionId,
    required this.userId1,
    required this.userId2,
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageSenderId,
    this.lastMessageAt,
    required this.unreadCountUser1,
    required this.unreadCountUser2,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DatingConversation.fromJson(Map<String, dynamic> json) {
    return DatingConversation(
      id: json['id']?.toString() ?? '',
      connectionId: json['connectionId']?.toString() ?? '',
      userId1: json['userId1']?.toString() ?? '',
      userId2: json['userId2']?.toString() ?? '',
      lastMessage: json['lastMessage']?.toString(),
      lastMessageType: json['lastMessageType'] != null
          ? MessageType.fromString(json['lastMessageType'])
          : null,
      lastMessageSenderId: json['lastMessageSenderId']?.toString(),
      lastMessageAt: json['lastMessageAt'],
      unreadCountUser1: json['unreadCountUser1'] ?? 0,
      unreadCountUser2: json['unreadCountUser2'] ?? 0,
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'connectionId': connectionId,
      'userId1': userId1,
      'userId2': userId2,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType?.value,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageAt': lastMessageAt,
      'unreadCountUser1': unreadCountUser1,
      'unreadCountUser2': unreadCountUser2,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  DatingConversation copyWith({
    String? id,
    String? connectionId,
    String? userId1,
    String? userId2,
    String? lastMessage,
    MessageType? lastMessageType,
    String? lastMessageSenderId,
    int? lastMessageAt,
    int? unreadCountUser1,
    int? unreadCountUser2,
    int? createdAt,
    int? updatedAt,
  }) {
    return DatingConversation(
      id: id ?? this.id,
      connectionId: connectionId ?? this.connectionId,
      userId1: userId1 ?? this.userId1,
      userId2: userId2 ?? this.userId2,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCountUser1: unreadCountUser1 ?? this.unreadCountUser1,
      unreadCountUser2: unreadCountUser2 ?? this.unreadCountUser2,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


// lib/models/dating_message.dart
class DatingMessage {
  final String id;
  final String conversationId;
  final String senderUserId;
  final String receiverUserId;
  final MessageType type;
  final String? text;
  final String? mediaUrl;
  final String? replyToMessageId;
  final String? replyToMessageText;    // ✅ Nouveau champ
  final String? replyToMessageType;    // ✅ Nouveau champ (stocke le type original)
  final bool isRead;
  final int createdAt;
  final int updatedAt;

  DatingMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.receiverUserId,
    required this.type,
    this.text,
    this.mediaUrl,
    this.replyToMessageId,
    this.replyToMessageText,
    this.replyToMessageType,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DatingMessage.fromJson(Map<String, dynamic> json) {
    return DatingMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderUserId: json['senderUserId']?.toString() ?? '',
      receiverUserId: json['receiverUserId']?.toString() ?? '',
      type: MessageType.fromString(json['type'] ?? 'text'),
      text: json['text']?.toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      replyToMessageId: json['replyToMessageId']?.toString(),
      replyToMessageText: json['replyToMessageText']?.toString(),
      replyToMessageType: json['replyToMessageType']?.toString(),
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderUserId': senderUserId,
      'receiverUserId': receiverUserId,
      'type': type.value,
      'text': text,
      'mediaUrl': mediaUrl,
      'replyToMessageId': replyToMessageId,
      'replyToMessageText': replyToMessageText,
      'replyToMessageType': replyToMessageType,
      'isRead': isRead,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  DatingMessage copyWith({
    String? id,
    String? conversationId,
    String? senderUserId,
    String? receiverUserId,
    MessageType? type,
    String? text,
    String? mediaUrl,
    String? replyToMessageId,
    String? replyToMessageText,
    String? replyToMessageType,
    bool? isRead,
    int? createdAt,
    int? updatedAt,
  }) {
    return DatingMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderUserId: senderUserId ?? this.senderUserId,
      receiverUserId: receiverUserId ?? this.receiverUserId,
      type: type ?? this.type,
      text: text ?? this.text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessageText: replyToMessageText ?? this.replyToMessageText,
      replyToMessageType: replyToMessageType ?? this.replyToMessageType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
// lib/models/creator_profile.dart
class CreatorProfile {
  final String id;
  final String userId;
  final String pseudo;
  final String imageUrl;
  final String bio;
  final CreatorType creatorType;
  final bool isCreatorActive;
  final bool isVerified;
  final int subscribersCount;
  final int freeContentsCount;
  final int paidContentsCount;
  final int totalViews;
  final int totalInteractions;
  final int totalShares;
  final int createdAt;
  final int updatedAt;

  CreatorProfile({
    required this.id,
    required this.userId,
    required this.pseudo,
    required this.imageUrl,
    required this.bio,
    required this.creatorType,
    required this.isCreatorActive,
    required this.isVerified,
    required this.subscribersCount,
    required this.freeContentsCount,
    required this.paidContentsCount,
    required this.totalViews,
    required this.totalInteractions,
    required this.totalShares,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CreatorProfile.fromJson(Map<String, dynamic> json) {
    return CreatorProfile(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      pseudo: json['pseudo']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      creatorType: CreatorType.fromString(json['creatorType'] ?? 'other'),
      isCreatorActive: json['isCreatorActive'] ?? true,
      isVerified: json['isVerified'] ?? false,
      subscribersCount: json['subscribersCount'] ?? 0,
      freeContentsCount: json['freeContentsCount'] ?? 0,
      paidContentsCount: json['paidContentsCount'] ?? 0,
      totalViews: json['totalViews'] ?? 0,
      totalInteractions: json['totalInteractions'] ?? 0,
      totalShares: json['totalShares'] ?? 0,
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'pseudo': pseudo,
      'imageUrl': imageUrl,
      'bio': bio,
      'creatorType': creatorType.value,
      'isCreatorActive': isCreatorActive,
      'isVerified': isVerified,
      'subscribersCount': subscribersCount,
      'freeContentsCount': freeContentsCount,
      'paidContentsCount': paidContentsCount,
      'totalViews': totalViews,
      'totalInteractions': totalInteractions,
      'totalShares': totalShares,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  CreatorProfile copyWith({
    String? id,
    String? userId,
    String? pseudo,
    String? imageUrl,
    String? bio,
    CreatorType? creatorType,
    bool? isCreatorActive,
    bool? isVerified,
    int? subscribersCount,
    int? freeContentsCount,
    int? paidContentsCount,
    int? totalViews,
    int? totalInteractions,
    int? totalShares,
    int? createdAt,
    int? updatedAt,
  }) {
    return CreatorProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      pseudo: pseudo ?? this.pseudo,
      imageUrl: imageUrl ?? this.imageUrl,
      bio: bio ?? this.bio,
      creatorType: creatorType ?? this.creatorType,
      isCreatorActive: isCreatorActive ?? this.isCreatorActive,
      isVerified: isVerified ?? this.isVerified,
      subscribersCount: subscribersCount ?? this.subscribersCount,
      freeContentsCount: freeContentsCount ?? this.freeContentsCount,
      paidContentsCount: paidContentsCount ?? this.paidContentsCount,
      totalViews: totalViews ?? this.totalViews,
      totalInteractions: totalInteractions ?? this.totalInteractions,
      totalShares: totalShares ?? this.totalShares,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// lib/models/creator_subscription.dart
class CreatorSubscription {
  final String id;
  final String userId;
  final String creatorId;
  final int subscribedAt;
  final bool isActive;
  final bool notificationsEnabled;
  final bool isPaidSubscription;
  final int? paidCoinsAmount;
  final int createdAt;
  final int updatedAt;

  CreatorSubscription({
    required this.id,
    required this.userId,
    required this.creatorId,
    required this.subscribedAt,
    required this.isActive,
    required this.notificationsEnabled,
    required this.isPaidSubscription,
    this.paidCoinsAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CreatorSubscription.fromJson(Map<String, dynamic> json) {
    return CreatorSubscription(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? '',
      subscribedAt: json['subscribedAt'] ?? 0,
      isActive: json['isActive'] ?? true,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      isPaidSubscription: json['isPaidSubscription'] ?? false,
      paidCoinsAmount: json['paidCoinsAmount'],
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'creatorId': creatorId,
      'subscribedAt': subscribedAt,
      'isActive': isActive,
      'notificationsEnabled': notificationsEnabled,
      'isPaidSubscription': isPaidSubscription,
      'paidCoinsAmount': paidCoinsAmount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  CreatorSubscription copyWith({
    String? id,
    String? userId,
    String? creatorId,
    int? subscribedAt,
    bool? isActive,
    bool? notificationsEnabled,
    bool? isPaidSubscription,
    int? paidCoinsAmount,
    int? createdAt,
    int? updatedAt,
  }) {
    return CreatorSubscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      creatorId: creatorId ?? this.creatorId,
      subscribedAt: subscribedAt ?? this.subscribedAt,
      isActive: isActive ?? this.isActive,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isPaidSubscription: isPaidSubscription ?? this.isPaidSubscription,
      paidCoinsAmount: paidCoinsAmount ?? this.paidCoinsAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


// lib/models/creator_content.dart
class CreatorContent {
  final String id;
  final String creatorId;
  final String creatorUserId;
  final String titre;
  final String description;
  final String mediaUrl;
  final MediaType mediaType;
  final String? thumbnailUrl;
  final bool isPaid;
  final int? priceCoins;
  final String currency;
  final bool isPublished;
  final int likesCount;
  final int lovesCount;
  final int unlikesCount;
  final int viewsCount;
  final int interactionsCount;
  final int sharesCount;
  final int createdAt;
  final int updatedAt;

  CreatorContent({
    required this.id,
    required this.creatorId,
    required this.creatorUserId,
    required this.titre,
    required this.description,
    required this.mediaUrl,
    required this.mediaType,
    this.thumbnailUrl,
    required this.isPaid,
    this.priceCoins,
    required this.currency,
    required this.isPublished,
    required this.likesCount,
    required this.lovesCount,
    required this.unlikesCount,
    required this.viewsCount,
    required this.interactionsCount,
    required this.sharesCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CreatorContent.fromJson(Map<String, dynamic> json) {
    return CreatorContent(
      id: json['id']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? '',
      creatorUserId: json['creatorUserId']?.toString() ?? '',
      titre: json['titre']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString() ?? '',
      mediaType: MediaType.fromString(json['mediaType'] ?? 'text'),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      isPaid: json['isPaid'] ?? false,
      priceCoins: json['priceCoins'],
      currency: json['currency']?.toString() ?? 'coins',
      isPublished: json['isPublished'] ?? false,
      likesCount: json['likesCount'] ?? 0,
      lovesCount: json['lovesCount'] ?? 0,
      unlikesCount: json['unlikesCount'] ?? 0,
      viewsCount: json['viewsCount'] ?? 0,
      interactionsCount: json['interactionsCount'] ?? 0,
      sharesCount: json['sharesCount'] ?? 0,
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creatorId': creatorId,
      'creatorUserId': creatorUserId,
      'titre': titre,
      'description': description,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType.value,
      'thumbnailUrl': thumbnailUrl,
      'isPaid': isPaid,
      'priceCoins': priceCoins,
      'currency': currency,
      'isPublished': isPublished,
      'likesCount': likesCount,
      'lovesCount': lovesCount,
      'unlikesCount': unlikesCount,
      'viewsCount': viewsCount,
      'interactionsCount': interactionsCount,
      'sharesCount': sharesCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  CreatorContent copyWith({
    String? id,
    String? creatorId,
    String? creatorUserId,
    String? titre,
    String? description,
    String? mediaUrl,
    MediaType? mediaType,
    String? thumbnailUrl,
    bool? isPaid,
    int? priceCoins,
    String? currency,
    bool? isPublished,
    int? likesCount,
    int? lovesCount,
    int? unlikesCount,
    int? viewsCount,
    int? interactionsCount,
    int? sharesCount,
    int? createdAt,
    int? updatedAt,
  }) {
    return CreatorContent(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      creatorUserId: creatorUserId ?? this.creatorUserId,
      titre: titre ?? this.titre,
      description: description ?? this.description,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isPaid: isPaid ?? this.isPaid,
      priceCoins: priceCoins ?? this.priceCoins,
      currency: currency ?? this.currency,
      isPublished: isPublished ?? this.isPublished,
      likesCount: likesCount ?? this.likesCount,
      lovesCount: lovesCount ?? this.lovesCount,
      unlikesCount: unlikesCount ?? this.unlikesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      interactionsCount: interactionsCount ?? this.interactionsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}



// lib/models/creator_content_reaction.dart
class CreatorContentReaction {
  final String id;
  final String contentId;
  final String creatorId;
  final String userId;
  final ReactionType reactionType;
  final int createdAt;
  final int updatedAt;

  CreatorContentReaction({
    required this.id,
    required this.contentId,
    required this.creatorId,
    required this.userId,
    required this.reactionType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CreatorContentReaction.fromJson(Map<String, dynamic> json) {
    return CreatorContentReaction(
      id: json['id']?.toString() ?? '',
      contentId: json['contentId']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      reactionType: ReactionType.fromString(json['reactionType'] ?? 'like'),
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contentId': contentId,
      'creatorId': creatorId,
      'userId': userId,
      'reactionType': reactionType.value,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  CreatorContentReaction copyWith({
    String? id,
    String? contentId,
    String? creatorId,
    String? userId,
    ReactionType? reactionType,
    int? createdAt,
    int? updatedAt,
  }) {
    return CreatorContentReaction(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      creatorId: creatorId ?? this.creatorId,
      userId: userId ?? this.userId,
      reactionType: reactionType ?? this.reactionType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// lib/models/creator_content_view.dart
class CreatorContentView {
  final String id;
  final String contentId;
  final String creatorId;
  final String userId;
  final int viewedAt;

  CreatorContentView({
    required this.id,
    required this.contentId,
    required this.creatorId,
    required this.userId,
    required this.viewedAt,
  });

  factory CreatorContentView.fromJson(Map<String, dynamic> json) {
    return CreatorContentView(
      id: json['id']?.toString() ?? '',
      contentId: json['contentId']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      viewedAt: json['viewedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contentId': contentId,
      'creatorId': creatorId,
      'userId': userId,
      'viewedAt': viewedAt,
    };
  }

  CreatorContentView copyWith({
    String? id,
    String? contentId,
    String? creatorId,
    String? userId,
    int? viewedAt,
  }) {
    return CreatorContentView(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      creatorId: creatorId ?? this.creatorId,
      userId: userId ?? this.userId,
      viewedAt: viewedAt ?? this.viewedAt,
    );
  }
}

// lib/models/creator_content_purchase.dart
class CreatorContentPurchase {
  final String id;
  final String contentId;
  final String creatorId;
  final String buyerUserId;
  final int priceCoins;
  final int purchasedAt;
  final TransactionStatus status;
  final int createdAt;
  final int updatedAt;

  CreatorContentPurchase({
    required this.id,
    required this.contentId,
    required this.creatorId,
    required this.buyerUserId,
    required this.priceCoins,
    required this.purchasedAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CreatorContentPurchase.fromJson(Map<String, dynamic> json) {
    return CreatorContentPurchase(
      id: json['id']?.toString() ?? '',
      contentId: json['contentId']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? '',
      buyerUserId: json['buyerUserId']?.toString() ?? '',
      priceCoins: json['priceCoins'] ?? 0,
      purchasedAt: json['purchasedAt'] ?? 0,
      status: TransactionStatus.fromString(json['status'] ?? 'pending'),
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contentId': contentId,
      'creatorId': creatorId,
      'buyerUserId': buyerUserId,
      'priceCoins': priceCoins,
      'purchasedAt': purchasedAt,
      'status': status.value,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  CreatorContentPurchase copyWith({
    String? id,
    String? contentId,
    String? creatorId,
    String? buyerUserId,
    int? priceCoins,
    int? purchasedAt,
    TransactionStatus? status,
    int? createdAt,
    int? updatedAt,
  }) {
    return CreatorContentPurchase(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      creatorId: creatorId ?? this.creatorId,
      buyerUserId: buyerUserId ?? this.buyerUserId,
      priceCoins: priceCoins ?? this.priceCoins,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// lib/models/subscription_plan.dart
// lib/models/dating_data.dart - Mettre à jour SubscriptionPlan

class SubscriptionPlan {
  final String id;
  final String code;
  final String name;
  final String description;
  final int priceCoins;
  final int durationInDays;
  final List<String> features;
  final bool isActive;
  final int createdAt;
  final int updatedAt;

  // Nouveaux champs pour les limites
  final int defaultLikes;
  final int defaultSuperLikes;

  SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.priceCoins,
    required this.durationInDays,
    required this.features,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.defaultLikes,
    required this.defaultSuperLikes,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priceCoins: json['priceCoins'] ?? 0,
      durationInDays: json['durationInDays'] ?? 0,
      features: (json['features'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
      defaultLikes: json['defaultLikes'] ?? 10,
      defaultSuperLikes: json['defaultSuperLikes'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'priceCoins': priceCoins,
      'durationInDays': durationInDays,
      'features': features,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'defaultLikes': defaultLikes,
      'defaultSuperLikes': defaultSuperLikes,
    };
  }

  SubscriptionPlan copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    int? priceCoins,
    int? durationInDays,
    List<String>? features,
    bool? isActive,
    int? createdAt,
    int? updatedAt,
    int? defaultLikes,
    int? defaultSuperLikes,
  }) {
    return SubscriptionPlan(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      priceCoins: priceCoins ?? this.priceCoins,
      durationInDays: durationInDays ?? this.durationInDays,
      features: features ?? this.features,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      defaultLikes: defaultLikes ?? this.defaultLikes,
      defaultSuperLikes: defaultSuperLikes ?? this.defaultSuperLikes,
    );
  }
}
// lib/models/user_dating_subscription.dart
// lib/models/dating_data.dart - Mettre à jour UserDatingSubscription

class UserDatingSubscription {
  final String id;
  final String userId;
  final String planCode;
  final int priceCoins;
  final int startAt;
  final int endAt;
  final bool isActive;
  final int createdAt;
  final int updatedAt;
  final int remainingLikes;      // ✅ Nouveau champ
  final int remainingSuperLikes; // ✅ Nouveau champ
  final int lastResetDate;       // ✅ Nouveau champ (timestamp du dernier reset)

  UserDatingSubscription({
    required this.id,
    required this.userId,
    required this.planCode,
    required this.priceCoins,
    required this.startAt,
    required this.endAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.remainingLikes,
    required this.remainingSuperLikes,
    required this.lastResetDate,
  });

  factory UserDatingSubscription.fromJson(Map<String, dynamic> json) {
    return UserDatingSubscription(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      planCode: json['planCode']?.toString() ?? '',
      priceCoins: json['priceCoins'] ?? 0,
      startAt: json['startAt'] ?? 0,
      endAt: json['endAt'] ?? 0,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
      remainingLikes: json['remainingLikes'] ?? 0,
      remainingSuperLikes: json['remainingSuperLikes'] ?? 0,
      lastResetDate: json['lastResetDate'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'planCode': planCode,
      'priceCoins': priceCoins,
      'startAt': startAt,
      'endAt': endAt,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'remainingLikes': remainingLikes,
      'remainingSuperLikes': remainingSuperLikes,
      'lastResetDate': lastResetDate,
    };
  }

  UserDatingSubscription copyWith({
    String? id,
    String? userId,
    String? planCode,
    int? priceCoins,
    int? startAt,
    int? endAt,
    bool? isActive,
    int? createdAt,
    int? updatedAt,
    int? remainingLikes,
    int? remainingSuperLikes,
    int? lastResetDate,
  }) {
    return UserDatingSubscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planCode: planCode ?? this.planCode,
      priceCoins: priceCoins ?? this.priceCoins,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remainingLikes: remainingLikes ?? this.remainingLikes,
      remainingSuperLikes: remainingSuperLikes ?? this.remainingSuperLikes,
      lastResetDate: lastResetDate ?? this.lastResetDate,
    );
  }
}

// lib/models/dating_block.dart
class DatingBlock {
  final String id;
  final String blockerUserId;
  final String blockedUserId;
  final int createdAt;

  DatingBlock({
    required this.id,
    required this.blockerUserId,
    required this.blockedUserId,
    required this.createdAt,
  });

  factory DatingBlock.fromJson(Map<String, dynamic> json) {
    return DatingBlock(
      id: json['id']?.toString() ?? '',
      blockerUserId: json['blockerUserId']?.toString() ?? '',
      blockedUserId: json['blockedUserId']?.toString() ?? '',
      createdAt: json['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'blockerUserId': blockerUserId,
      'blockedUserId': blockedUserId,
      'createdAt': createdAt,
    };
  }

  DatingBlock copyWith({
    String? id,
    String? blockerUserId,
    String? blockedUserId,
    int? createdAt,
  }) {
    return DatingBlock(
      id: id ?? this.id,
      blockerUserId: blockerUserId ?? this.blockerUserId,
      blockedUserId: blockedUserId ?? this.blockedUserId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// lib/models/dating_report.dart
class DatingReport {
  final String id;
  final String reporterUserId;
  final String targetUserId;
  final String? messageId;
  final String reason;
  final String description;
  final int createdAt;

  DatingReport({
    required this.id,
    required this.reporterUserId,
    required this.targetUserId,
    this.messageId,
    required this.reason,
    required this.description,
    required this.createdAt,
  });

  factory DatingReport.fromJson(Map<String, dynamic> json) {
    return DatingReport(
      id: json['id']?.toString() ?? '',
      reporterUserId: json['reporterUserId']?.toString() ?? '',
      targetUserId: json['targetUserId']?.toString() ?? '',
      messageId: json['messageId']?.toString(),
      reason: json['reason']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAt: json['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporterUserId': reporterUserId,
      'targetUserId': targetUserId,
      'messageId': messageId,
      'reason': reason,
      'description': description,
      'createdAt': createdAt,
    };
  }

  DatingReport copyWith({
    String? id,
    String? reporterUserId,
    String? targetUserId,
    String? messageId,
    String? reason,
    String? description,
    int? createdAt,
  }) {
    return DatingReport(
      id: id ?? this.id,
      reporterUserId: reporterUserId ?? this.reporterUserId,
      targetUserId: targetUserId ?? this.targetUserId,
      messageId: messageId ?? this.messageId,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// lib/models/dating_profile_visit.dart
class DatingProfileVisit {
  final String id;
  final String visitorUserId;
  final String visitedUserId;
  final int createdAt;

  DatingProfileVisit({
    required this.id,
    required this.visitorUserId,
    required this.visitedUserId,
    required this.createdAt,
  });

  factory DatingProfileVisit.fromJson(Map<String, dynamic> json) {
    return DatingProfileVisit(
      id: json['id']?.toString() ?? '',
      visitorUserId: json['visitorUserId']?.toString() ?? '',
      visitedUserId: json['visitedUserId']?.toString() ?? '',
      createdAt: json['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitorUserId': visitorUserId,
      'visitedUserId': visitedUserId,
      'createdAt': createdAt,
    };
  }

  DatingProfileVisit copyWith({
    String? id,
    String? visitorUserId,
    String? visitedUserId,
    int? createdAt,
  }) {
    return DatingProfileVisit(
      id: id ?? this.id,
      visitorUserId: visitorUserId ?? this.visitorUserId,
      visitedUserId: visitedUserId ?? this.visitedUserId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// lib/models/dating_boost.dart
class DatingBoost {
  final String id;
  final String userId;
  final int priceCoins;
  final int startAt;
  final int endAt;
  final int createdAt;

  DatingBoost({
    required this.id,
    required this.userId,
    required this.priceCoins,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
  });

  factory DatingBoost.fromJson(Map<String, dynamic> json) {
    return DatingBoost(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      priceCoins: json['priceCoins'] ?? 0,
      startAt: json['startAt'] ?? 0,
      endAt: json['endAt'] ?? 0,
      createdAt: json['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'priceCoins': priceCoins,
      'startAt': startAt,
      'endAt': endAt,
      'createdAt': createdAt,
    };
  }

  DatingBoost copyWith({
    String? id,
    String? userId,
    int? priceCoins,
    int? startAt,
    int? endAt,
    int? createdAt,
  }) {
    return DatingBoost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      priceCoins: priceCoins ?? this.priceCoins,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// lib/models/dating_priority_interest.dart
class DatingPriorityInterest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final int priceCoins;
  final int createdAt;

  DatingPriorityInterest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.priceCoins,
    required this.createdAt,
  });

  factory DatingPriorityInterest.fromJson(Map<String, dynamic> json) {
    return DatingPriorityInterest(
      id: json['id']?.toString() ?? '',
      fromUserId: json['fromUserId']?.toString() ?? '',
      toUserId: json['toUserId']?.toString() ?? '',
      priceCoins: json['priceCoins'] ?? 0,
      createdAt: json['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'priceCoins': priceCoins,
      'createdAt': createdAt,
    };
  }

  DatingPriorityInterest copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    int? priceCoins,
    int? createdAt,
  }) {
    return DatingPriorityInterest(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      priceCoins: priceCoins ?? this.priceCoins,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// lib/models/creator_content_share.dart
class CreatorContentShare {
  final String id;
  final String contentId;
  final String creatorId;
  final String userId;
  final int sharedAt;

  CreatorContentShare({
    required this.id,
    required this.contentId,
    required this.creatorId,
    required this.userId,
    required this.sharedAt,
  });

  factory CreatorContentShare.fromJson(Map<String, dynamic> json) {
    return CreatorContentShare(
      id: json['id']?.toString() ?? '',
      contentId: json['contentId']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      sharedAt: json['sharedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contentId': contentId,
      'creatorId': creatorId,
      'userId': userId,
      'sharedAt': sharedAt,
    };
  }

  CreatorContentShare copyWith({
    String? id,
    String? contentId,
    String? creatorId,
    String? userId,
    int? sharedAt,
  }) {
    return CreatorContentShare(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      creatorId: creatorId ?? this.creatorId,
      userId: userId ?? this.userId,
      sharedAt: sharedAt ?? this.sharedAt,
    );
  }
}