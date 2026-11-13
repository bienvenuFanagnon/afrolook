// models/live_models.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Timestamp (modèle) et état en direct d'un live (spectateurs, participants), qui reste sur Firebase
import 'package:afrotok/services/api/chat_api.dart';
import 'package:afrotok/services/api/lives_mapper.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';


class PostLive {
  final String? liveId;
  final String? hostId;
  final String? hostName;
  final String? hostImage;
  final String title;
  int viewerCount;
  int? giftCount;
  int? likeCount;
  final DateTime startTime;
  DateTime? endTime;
  bool isLive;
  double giftTotal;
  final List<LiveGift> gifts;
  bool paymentRequired;
  DateTime? paymentRequestTime;
  final List<String> invitedUsers;
  final List<String> totalspectateurs;
  final List<String> participants;
  final List<String> spectators;

  // NOUVEAUX CHAMPS POUR LIVE PAYANT
  final bool isPaidLive;
  final double participationFee; // équivalent FCFA (anciennes versions de l'app)
  /// Prix d'entrée du live privé en pièces (tout se paie en pièces depuis le 2026-09-27).
  final int? participationFeeCoinsRaw;
  final int freeTrialMinutes;

  /// Prix d'entrée en pièces : champ en pièces, sinon ancien prix FCFA × 2,5.
  int get participationFeeCoins => (participationFeeCoinsRaw ?? 0) > 0
      ? participationFeeCoinsRaw!
      : (participationFee * 2.5).ceil();

  // NOUVEAUX CHAMPS POUR COMPORTEMENT APRÈS ESSAI
  final String audioBehaviorAfterTrial;
  final int audioReductionPercent;
  final bool blurVideoAfterTrial;
  final bool showPaymentModalAfterTrial;

  // NOUVEAUX CHAMPS POUR FONCTIONNALITÉS AVANCÉES
  final String? pinnedText;
  final int shareCount;
  final double paidParticipationTotal;

  // NOUVEAU CHAMP POUR TEMPS DE VISIONNAGE
  final Map<String, dynamic> userWatchTime;

  // CHAMPS EXISTANTS
  bool earningsWithdrawn;
  DateTime? withdrawalDate;
  String? withdrawalTransactionId;

  final int? screenShareUid;
  final bool isScreenSharing;
  final String? screenSharerId;

  // NOUVEAU CHAMP : DURÉE DU LIVE POUR L'HÔTE
  final int? liveDurationMinutes; // ← AJOUTEZ CE CHAMP

  final bool isPaused;              // ← NOUVEAU
  final String? pauseMessage;       // ← NOUVEAU
  final int giftCoinsTotal;         // Pièces reçues en cadeaux
  final String? coverImage;         // Image de couverture du live (facultative)

  /// Type de live : `talk` (discussion), `shopping` (vente en direct), `duel` ou `challenge` (défi à plusieurs).
  final String typeSession;

  /// Le live a démarré alors que les minutes gratuites du mois étaient épuisées : les spectateurs prennent un billet.
  final bool ticketMode;
  final bool audioOnly;

  /// L'hôte offre l'entrée : il paie les billets de ses spectateurs.
  final bool offerEntry;

  /// Image à montrer pour ce live : sa couverture si l'hôte en a choisi une, sinon la photo de profil de l'hôte.
  String? get displayImage => (coverImage?.isNotEmpty == true) ? coverImage : hostImage;

  PostLive({
    // Champs existants
    this.earningsWithdrawn = false,
    this.withdrawalDate,
    this.withdrawalTransactionId,
    required this.liveId,
    required this.hostId,
    required this.hostName,
    required this.hostImage,
    required this.title,
    this.coverImage,
    this.viewerCount = 0,
    this.giftCount = 0,
    required this.startTime,
    this.endTime,
    this.isLive = true,
    this.giftTotal = 0,
    this.likeCount = 0,
    this.gifts = const [],
    this.paymentRequired = false,
    this.paymentRequestTime,
    this.invitedUsers = const [],
    this.participants = const [],
    this.spectators = const [],
    this.totalspectateurs = const [],

    // Nouveaux champs avec valeurs par défaut
    this.isPaidLive = false,
    this.participationFee = 100.0,
    this.participationFeeCoinsRaw,
    this.freeTrialMinutes = 1,

    // Comportement après essai
    this.audioBehaviorAfterTrial = 'reduce',
    this.audioReductionPercent = 50,
    this.blurVideoAfterTrial = true,
    this.showPaymentModalAfterTrial = true,

    // Fonctionnalités avancées
    this.pinnedText,
    this.shareCount = 0,
    this.paidParticipationTotal = 0.0,

    // Temps de visionnage
    this.userWatchTime = const {},

    // Partage d'écran
    this.screenShareUid,
    this.isScreenSharing = false,
    this.screenSharerId,

    // NOUVEAU : Durée du live avec valeur par défaut de 30 minutes
    this.liveDurationMinutes = 30, // ← VALEUR PAR DÉFAUT

    this.isPaused = false,          // ← NOUVEAU (valeur par défaut)
    this.pauseMessage,              // ← NOUVEAU (peut être null)
    this.giftCoinsTotal = 0,
    this.typeSession = 'talk',
    this.ticketMode = false,
    this.audioOnly = false,
    this.offerEntry = false,
  });

  // Méthode utilitaire pour obtenir la durée (gestion des null)
  int get safeLiveDurationMinutes => liveDurationMinutes ?? 30;

  Map<String, dynamic> toMap() {
    return {
      // Champs existants
      'liveId': liveId,
      'hostId': hostId,
      'hostName': hostName,
      'hostImage': hostImage,
      'title': title,
      'likeCount': likeCount,
      'viewerCount': viewerCount,
      'startTime': startTime,
      'endTime': endTime,
      'isLive': isLive,
      'giftTotal': giftTotal,
      'gifts': gifts.map((gift) => gift.toMap()).toList(),
      'paymentRequired': paymentRequired,
      'paymentRequestTime': paymentRequestTime,
      'invitedUsers': invitedUsers,
      'participants': participants,
      'spectators': spectators,
      'earningsWithdrawn': earningsWithdrawn,
      'withdrawalDate': withdrawalDate,
      'withdrawalTransactionId': withdrawalTransactionId,

      // Nouveaux champs
      'isPaidLive': isPaidLive,
      'participationFee': participationFee,
      if (participationFeeCoinsRaw != null) 'participationFeeCoins': participationFeeCoinsRaw,
      'freeTrialMinutes': freeTrialMinutes,
      'audioBehaviorAfterTrial': audioBehaviorAfterTrial,
      'audioReductionPercent': audioReductionPercent,
      'blurVideoAfterTrial': blurVideoAfterTrial,
      'showPaymentModalAfterTrial': showPaymentModalAfterTrial,
      'pinnedText': pinnedText,
      'shareCount': shareCount,
      'paidParticipationTotal': paidParticipationTotal,
      'userWatchTime': userWatchTime,

      // Partage d'écran
      'screenShareUid': screenShareUid,
      'isScreenSharing': isScreenSharing,
      'screenSharerId': screenSharerId,
      'totalspectateurs': totalspectateurs,

      // NOUVEAU CHAMP
      'liveDurationMinutes': liveDurationMinutes, // ← AJOUTEZ

      // ⭐ AJOUTER LES 2 NOUVEAUX CHAMPS
      'isPaused': isPaused,
      'pauseMessage': pauseMessage,
      'giftCoinsTotal': giftCoinsTotal,
      'coverImage': coverImage,
    };
  }

  factory PostLive.fromMap(Map<String, dynamic> map) {
    return PostLive(
      liveId: map['liveId'] ?? '',
      hostId: map['hostId'] ?? '',
      hostName: map['hostName'] ?? '',
      hostImage: map['hostImage'] ?? '',
      title: map['title'] ?? '',
      viewerCount: map['viewerCount'] ?? 0,
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: map['endTime'] != null ? (map['endTime'] as Timestamp).toDate() : null,
      isLive: map['isLive'] ?? true,
      giftTotal: map['giftTotal']?.toDouble() ?? 0.0,
      gifts: map['gifts'] != null
          ? List<LiveGift>.from((map['gifts'] as List).map((x) => LiveGift.fromMap(x)))
          : [],
      paymentRequired: map['paymentRequired'] ?? false,
      paymentRequestTime: map['paymentRequestTime'] != null
          ? (map['paymentRequestTime'] as Timestamp).toDate()
          : null,
      invitedUsers: map['invitedUsers'] != null
          ? List<String>.from(map['invitedUsers'])
          : [],
      participants: map['participants'] != null
          ? List<String>.from(map['participants'])
          : [],
      spectators: map['spectators'] != null
          ? List<String>.from(map['spectators'])
          : [],
      totalspectateurs: map['totalspectateurs'] != null
          ? List<String>.from(map['totalspectateurs'])
          : [],
      earningsWithdrawn: map['earningsWithdrawn'] ?? false,
      withdrawalDate: map['withdrawalDate']?.toDate(),
      withdrawalTransactionId: map['withdrawalTransactionId'],
      likeCount: map['likeCount'],

      // Nouveaux champs
      isPaidLive: map['isPaidLive'] ?? false,
      participationFee: map['participationFee']?.toDouble() ?? 100.0,
      participationFeeCoinsRaw: (map['participationFeeCoins'] as num?)?.toInt(),
      freeTrialMinutes: map['freeTrialMinutes'] ?? 1,
      audioBehaviorAfterTrial: map['audioBehaviorAfterTrial'] ?? 'reduce',
      audioReductionPercent: map['audioReductionPercent'] ?? 50,
      blurVideoAfterTrial: map['blurVideoAfterTrial'] ?? true,
      showPaymentModalAfterTrial: map['showPaymentModalAfterTrial'] ?? true,
      pinnedText: map['pinnedText'],
      shareCount: map['shareCount'] ?? 0,
      paidParticipationTotal: map['paidParticipationTotal']?.toDouble() ?? 0.0,
      userWatchTime: map['userWatchTime'] != null
          ? Map<String, dynamic>.from(map['userWatchTime'])
          : {},

      // Partage d'écran
      screenShareUid: map['screenShareUid'],
      isScreenSharing: map['isScreenSharing'] ?? false,
      screenSharerId: map['screenSharerId'],

      // NOUVEAU CHAMP (avec gestion null)
      liveDurationMinutes: map['liveDurationMinutes'] ?? 30, // ← AJOUTEZ

      // ⭐ AJOUTER LES 2 NOUVEAUX CHAMPS
      isPaused: map['isPaused'] ?? false,
      pauseMessage: map['pauseMessage'],
      giftCoinsTotal: (map['giftCoinsTotal'] as num?)?.toInt() ?? 0,
      coverImage: map['coverImage'] as String?,
    );
  }

  PostLive copyWith({
    int? screenShareUid,
    bool? isScreenSharing,
    String? screenSharerId,
    int? liveDurationMinutes, // ← AJOUTEZ
    // ... autres champs ...

    // ⭐ AJOUTER LES 2 NOUVEAUX PARAMÈTRES
    bool? isPaused,
    String? pauseMessage,
  }) {
    return PostLive(
      liveId: liveId,
      hostId: hostId,
      hostName: hostName,
      hostImage: hostImage,
      title: title,
      viewerCount: viewerCount,
      giftCount: giftCount,
      startTime: startTime,
      endTime: endTime,
      isLive: isLive,
      giftTotal: giftTotal,
      likeCount: likeCount,
      gifts: gifts,
      paymentRequired: paymentRequired,
      paymentRequestTime: paymentRequestTime,
      invitedUsers: invitedUsers,
      participants: participants,
      spectators: spectators,
      totalspectateurs: totalspectateurs,
      isPaidLive: isPaidLive,
      participationFee: participationFee,
      participationFeeCoinsRaw: participationFeeCoinsRaw,
      freeTrialMinutes: freeTrialMinutes,
      audioBehaviorAfterTrial: audioBehaviorAfterTrial,
      audioReductionPercent: audioReductionPercent,
      blurVideoAfterTrial: blurVideoAfterTrial,
      showPaymentModalAfterTrial: showPaymentModalAfterTrial,
      pinnedText: pinnedText,
      shareCount: shareCount,
      paidParticipationTotal: paidParticipationTotal,
      userWatchTime: userWatchTime,
      earningsWithdrawn: earningsWithdrawn,
      withdrawalDate: withdrawalDate,
      withdrawalTransactionId: withdrawalTransactionId,

      // Partage d'écran
      screenShareUid: screenShareUid ?? this.screenShareUid,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      screenSharerId: screenSharerId ?? this.screenSharerId,

      // NOUVEAU CHAMP
      liveDurationMinutes: liveDurationMinutes ?? this.liveDurationMinutes, // ← AJOUTEZ

      // ⭐ AJOUTER LES 2 NOUVEAUX CHAMPS
      isPaused: isPaused ?? this.isPaused,
      pauseMessage: pauseMessage ?? this.pauseMessage,
      giftCoinsTotal: giftCoinsTotal,
    );
  }
}

// models/live_stats.dart
class LiveStats {
  String userId;
  int monthlyLiveCount; // Nombre de lives ce mois
  DateTime monthStart; // Début du mois en cours
  int totalLiveCount; // Total des lives créés
  DateTime? lastLiveDate; // Date du dernier live
  Map<String, dynamic> qualityPreferences; // Préférences de qualité
  bool isPremium; // Si premium actif
  DateTime? premiumUntil; // Jusqu'à quand premium
  int maxMonthlyLives; // Nombre max de lives par mois
  String defaultQuality; // Qualité par défaut

  LiveStats({
    required this.userId,
    this.monthlyLiveCount = 0,
    required this.monthStart,
    this.totalLiveCount = 0,
    this.lastLiveDate,
    this.qualityPreferences = const {},
    this.isPremium = false,
    this.premiumUntil,
    this.maxMonthlyLives = 5,
    this.defaultQuality = 'standard',
  }){
    lastLiveDate ??=  DateTime.now();
    premiumUntil ??=  DateTime.now();

  }

  factory LiveStats.defaultForUser(String userId) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    return LiveStats(
      userId: userId,
      monthStart: monthStart,
      monthlyLiveCount: 0,
      totalLiveCount: 0,
      lastLiveDate: now,
      qualityPreferences: {
        'latency': 2000, // 2 secondes pour gratuit
        'quality': 'SD',
        'bitrate': 1000,
        'resolution': '480p',
      },
      isPremium: false,
      premiumUntil: now,
      maxMonthlyLives: 5,
      defaultQuality: 'standard',
    );
  }

  factory LiveStats.fromJson(Map<String, dynamic> json) {
    return LiveStats(
      userId: json['userId'],
      monthlyLiveCount: json['monthlyLiveCount'] ?? 0,
      monthStart: DateTime.parse(json['monthStart']),
      totalLiveCount: json['totalLiveCount'] ?? 0,
      lastLiveDate: DateTime.parse(json['lastLiveDate']),
      qualityPreferences: Map<String, dynamic>.from(json['qualityPreferences'] ?? {}),
      isPremium: json['isPremium'] ?? false,
      premiumUntil: DateTime.parse(json['premiumUntil']),
      maxMonthlyLives: json['maxMonthlyLives'] ?? 5,
      defaultQuality: json['defaultQuality'] ?? 'standard',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'monthlyLiveCount': monthlyLiveCount,
      'monthStart': monthStart.toIso8601String(),
      'totalLiveCount': totalLiveCount,
      'lastLiveDate': lastLiveDate!.toIso8601String(),
      'qualityPreferences': qualityPreferences,
      'isPremium': isPremium,
      'premiumUntil': premiumUntil!.toIso8601String(),
      'maxMonthlyLives': maxMonthlyLives,
      'defaultQuality': defaultQuality,
    };
  }

  // Vérifier si peut créer un live
  bool canCreateLive() {
    final now = DateTime.now();

    // Si le mois a changé, réinitialiser le compteur
    if (now.month != monthStart.month || now.year != monthStart.year) {
      monthlyLiveCount = 0;
      monthStart = DateTime(now.year, now.month, 1);
    }

    return monthlyLiveCount < maxMonthlyLives || isPremium;
  }

  // Nombre de lives restants
  int get remainingLives {
    return isPremium ? 999 : maxMonthlyLives - monthlyLiveCount;
  }

  // Incrémenter le compteur
  void incrementLiveCount() {
    monthlyLiveCount++;
    totalLiveCount++;
    lastLiveDate = DateTime.now();
  }

  // Mettre à jour pour premium
  void updateForPremium({required bool premium, DateTime? premiumUntil}) {
    isPremium = premium;
    if (premium) {
      maxMonthlyLives = 999; // Illimité pour premium
      defaultQuality = 'HD';
      qualityPreferences = {
        'latency': 500, // 500ms pour premium
        'quality': 'HD',
        'bitrate': 4000,
        'resolution': '720p',
      };
      if (premiumUntil != null) {
        this.premiumUntil = premiumUntil;
      }
    } else {
      maxMonthlyLives = 5; // 5 max pour gratuit
      defaultQuality = 'standard';
      qualityPreferences = {
        'latency': 2000, // 2 secondes pour gratuit
        'quality': 'SD',
        'bitrate': 1000,
        'resolution': '480p',
      };
    }
  }

  // Vérifier si premium actif
  bool get isPremiumActive {
    if (!isPremium) return false;
    return DateTime.now().isBefore(premiumUntil!);
  }

  // Obtenir la latence selon l'abonnement
  int get latency {
    if (isPremiumActive) {
      return qualityPreferences['latency'] ?? 500;
    }
    return qualityPreferences['latency'] ?? 2000;
  }

  // Obtenir la qualité
  String get quality {
    if (isPremiumActive) {
      return qualityPreferences['quality'] ?? 'HD';
    }
    return qualityPreferences['quality'] ?? 'SD';
  }
}



class LiveGift {
  final String giftId;
  final String senderId;
  final String senderName;
  final double price;
  final DateTime timestamp;
  final String giftType;

  LiveGift({
    required this.giftId,
    required this.senderId,
    required this.senderName,
    required this.price,
    required this.timestamp,
    required this.giftType,
  });

  /// Conversion objet → Map (pour Firestore)
  Map<String, dynamic> toMap() {
    return {
      'giftId': giftId,
      'senderId': senderId,
      'senderName': senderName,
      'price': price,
      'timestamp': Timestamp.fromDate(timestamp),
      'giftType': giftType,
    };
  }

  /// Conversion Map → Objet (depuis Firestore)
  factory LiveGift.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return LiveGift(
        giftId: '',
        senderId: '',
        senderName: '',
        price: 0.0,
        timestamp: DateTime.now(),
        giftType: '',
      );
    }

    return LiveGift(
      giftId: (map['giftId'] ?? '').toString(),
      senderId: (map['senderId'] ?? '').toString(),
      senderName: (map['senderName'] ?? '').toString(),
      price: (map['price'] != null)
          ? (map['price'] as num).toDouble()
          : 0.0,
      timestamp: (map['timestamp'] is Timestamp)
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] is DateTime)
          ? (map['timestamp'] as DateTime)
          : DateTime.now(),
      giftType: (map['giftType'] ?? '').toString(),
    );
  }
}


class LiveComment {
  final String liveId;
  final String userId;
  final String username;
  final String userImage;
  final String message;
  final DateTime timestamp;
  final String type;
  final String? giftId;

  LiveComment({
    required this.liveId,
    required this.userId,
    required this.username,
    required this.userImage,
    required this.message,
    required this.timestamp,
    required this.type,
    this.giftId,
  });

  Map<String, dynamic> toMap() {
    return {
      'liveId': liveId,
      'userId': userId,
      'username': username,
      'userImage': userImage,
      'message': message,
      'timestamp': timestamp,
      'type': type,
      'giftId': giftId,
    };
  }

  factory LiveComment.fromMap(Map<String, dynamic> map) {
    return LiveComment(
      liveId: map['liveId'],
      userId: map['userId'],
      username: map['username'],
      userImage: map['userImage'],
      message: map['message'],
      timestamp: map['timestamp'].toDate(),
      type: map['type'],
      // giftId: map['giftId'],
    );
  }
}



class LiveProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<PostLive> _activeLives = [];
  List<PostLive> _endedLives = [];
  List<PostLive> _allLives = [];
  Map<String, Timer> _liveTimers = {};

  // Pagination
  static const int batchSize = 8;
  static const int maxLives = 30;
  String? _lastAllLiveDoc; // curseurs de l'API
  String? _lastActiveLiveDoc;
  String? _lastEndedLiveDoc;
  final Map<String, ({String name, String image})> _hosts = {};
  bool _allLivesFinished = false;
  bool _activeLivesFinished = false;
  bool _endedLivesFinished = false;

  // Getters
  List<PostLive> get endedLives => _endedLives;
  List<PostLive> get allLives => _allLives;
  List<PostLive> get activeLives => _activeLives;

  // ==================== MÉTHODES DE RÉCUPÉRATION ====================
  Stream<int> getActiveLivesCountStream() async* {
    while (true) {
      try {
        final page = await LivesApi.list(status: 'live', limit: 50);
        yield page.items.length;
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }

  /// Dernière erreur de chargement des listes de lives (message en français), null si le dernier chargement a réussi : la page propose « Réessayer ».
  String? loadError;

  /// Nom et photo de l'hôte : fournis par l'API avec chaque live (`host`). Ce profil public ne sert que de secours si elle ne les envoie pas.
  Future<({String name, String image})> _host(String id) async {
    final c = _hosts[id];
    if (c != null) return c;
    try {
      final u = userFromApi(await UsersApi.publicProfile(id));
      return _hosts[id] = (name: u.pseudo ?? '', image: u.imageUrl ?? '');
    } catch (_) {
      return (name: '', image: '');
    }
  }

  /// Ajoute sans doublon : deux chargements lancés en même temps (ouverture de la page + rafraîchissement) renvoient la même page ; un live ne s'affiche qu'une fois.
  void _addUnique(List<PostLive> into, List<PostLive> items) {
    final seen = into.map((l) => l.liveId).toSet();
    for (final l in items) {
      if (l.liveId == null || seen.add(l.liveId)) into.add(l);
    }
  }

  Future<List<PostLive>> _convert(List<Map<String, dynamic>> rows) async {
    final out = <PostLive>[];
    for (final j in rows) {
      if (j['host'] is Map) {
        out.add(postLiveFromApi(j)); // nom et photo de l'hôte déjà fournis par l'API
      } else {
        final h = await _host('${j['host_id']}');
        out.add(postLiveFromApi(j, hostName: h.name, hostImage: h.image));
      }
    }
    return out;
  }

  Future<void> fetchAllLivesBatch({bool reset = false}) async {
    if (reset) {
      _allLives = [];
      _lastAllLiveDoc = null;
      _allLivesFinished = false;
    }
    if (_allLivesFinished) return;
    try {
      // en cours d'abord, puis terminés : deux listes de l'API
      final live = reset || _allLives.isEmpty ? await LivesApi.list(status: 'live', limit: batchSize) : null;
      if (live != null) _addUnique(_allLives, await _convert(live.items));
      final ended = await LivesApi.list(status: 'ended', cursor: _lastAllLiveDoc, limit: batchSize);
      _addUnique(_allLives, await _convert(ended.items));
      _lastAllLiveDoc = ended.next;
      if (ended.next == null || _allLives.length >= maxLives) _allLivesFinished = true;
      loadError = null;
      notifyListeners();
    } catch (e) {
      printVm("❌ Erreur lors du chargement des lives par batch: $e");
      loadError = ChatApi.message(e, fallback: 'Les lives ne se chargent pas pour le moment.');
      notifyListeners();
    }
  }

  Future<void> fetchEndedLivesBatch({bool reset = false}) async {
    if (reset) {
      _endedLives = [];
      _lastEndedLiveDoc = null;
      _endedLivesFinished = false;
    }
    if (_endedLivesFinished) return;
    try {
      final page = await LivesApi.list(status: 'ended', cursor: _lastEndedLiveDoc, limit: batchSize);
      _addUnique(_endedLives, await _convert(page.items));
      _lastEndedLiveDoc = page.next;
      if (page.next == null || _endedLives.length >= maxLives) _endedLivesFinished = true;
      loadError = null;
      notifyListeners();
    } catch (e) {
      printVm("Erreur lors du chargement des lives terminés par batch: $e");
      loadError = ChatApi.message(e, fallback: 'Les lives ne se chargent pas pour le moment.');
      notifyListeners();
    }
  }

  Future<void> fetchActiveLivesBatch({bool reset = false}) async {
    if (reset) {
      _activeLives = [];
      _lastActiveLiveDoc = null;
      _activeLivesFinished = false;
    }
    if (_activeLivesFinished) return;
    try {
      final page = await LivesApi.list(status: 'live', cursor: _lastActiveLiveDoc, limit: batchSize);
      _addUnique(_activeLives, await _convert(page.items));
      _lastActiveLiveDoc = page.next;
      if (page.next == null || _activeLives.length >= maxLives) _activeLivesFinished = true;
      loadError = null;
      notifyListeners();
    } catch (e) {
      printVm("Erreur lors du chargement des lives actifs par batch: $e");
      loadError = ChatApi.message(e, fallback: 'Les lives ne se chargent pas pour le moment.');
      notifyListeners();
    }
  }

  Future<void> fetchAllLives() async {
    _allLives = [];
    await fetchAllLivesBatch(reset: true);
  }

  Future<void> fetchActiveLives() async {
    try {
      final page = await LivesApi.list(status: 'live', limit: 3);
      _activeLives = await _convert(page.items);
      notifyListeners();
    } catch (e) {
      printVm("Erreur lors du chargement des lives actifs: $e");
    }
  }

  // ==================== NOUVELLES MÉTHODES ====================

  // L'essai gratuit et l'entrée payante d'un live sont tenus par le serveur (POST /lives/{id}/token, paiement en pièces) :
  // les anciennes écritures `userWatchTime` / `paidParticipationTotal` dans le document `lives/{id}` n'existent plus.

  Future<void> updatePinnedText(String liveId, String text) async {
    try {
      if (text.isEmpty) {
        await _firestore.collection('lives').doc(liveId).update({
          'pinnedText': FieldValue.delete(),
        });
        printVm("📌 Texte épinglé supprimé");
      } else {
        await _firestore.collection('lives').doc(liveId).update({
          'pinnedText': text,
        });
        printVm("📌 Texte épinglé mis à jour: $text");
      }
    } catch (e) {
      printVm("❌ Erreur mise à jour texte épinglé: $e");
      rethrow;
    }
  }

  Future<void> incrementShareCount(String liveId) async {
    try {
      await _firestore.collection('lives').doc(liveId).update({
        'shareCount': FieldValue.increment(1),
      });
      printVm("📤 Compteur partages incrémenté");
    } catch (e) {
      printVm("❌ Erreur incrémentation partages: $e");
    }
  }

  Future<void> inviteUserToLive(String liveId, String userId) async {
    try {
      await _firestore.collection('lives').doc(liveId).update({
        'invitedUsers': FieldValue.arrayUnion([userId]),
      });
      printVm("📨 Utilisateur $userId invité au live $liveId");
    } catch (e) {
      printVm("❌ Erreur lors de l'invitation: $e");
    }
  }

  Future<bool> joinAsParticipant(String liveId, String userId) async {
    try {
      final liveDoc = await _firestore.collection('lives').doc(liveId).get();
      if (liveDoc.exists) {
        final live = PostLive.fromMap(liveDoc.data()!);

        if (live.invitedUsers.contains(userId)) {
          await _firestore.collection('lives').doc(liveId).update({
            'participants': FieldValue.arrayUnion([userId]),
            'invitedUsers': FieldValue.arrayRemove([userId]),
          });
          printVm("🎤 Utilisateur $userId rejoint comme participant");
          return true;
        }
      }
      return false;
    } catch (e) {
      printVm("❌ Erreur lors de la participation: $e");
      return false;
    }
  }

  Future<void> joinAsSpectator(String liveId, String userId) async {
    try {
      await _firestore.collection('lives').doc(liveId).update({
        'totalspectateurs': FieldValue.arrayUnion([userId]),
        'spectators': FieldValue.arrayUnion([userId]),
        'viewerCount': FieldValue.increment(1),
      });
      printVm("👀 Utilisateur $userId rejoint comme spectateur");
    } catch (e) {
      printVm("❌ Erreur lors de l'ajout du spectateur: $e");
    }
  }

  Future<void> leaveLive(String liveId, String userId) async {
    try {
      await _firestore.collection('lives').doc(liveId).update({
        'participants': FieldValue.arrayRemove([userId]),
        'spectators': FieldValue.arrayRemove([userId]),
        'viewerCount': FieldValue.increment(-1),
      });
      printVm("🚪 Utilisateur $userId a quitté le live");
    } catch (e) {
      printVm("❌ Erreur lors de la sortie du live: $e");
    }
  }

  void startLiveTimer(String liveId, int durationMinutes, Function onTimeExpired) {
    stopLiveTimer(liveId);
    _liveTimers[liveId] = Timer(Duration(minutes: durationMinutes), () {
      onTimeExpired();
      stopLiveTimer(liveId);
    });
    printVm("⏰ Timer live démarré: $durationMinutes minutes");
  }

  void stopLiveTimer(String liveId) {
    if (_liveTimers.containsKey(liveId)) {
      _liveTimers[liveId]!.cancel();
      _liveTimers.remove(liveId);
      printVm("⏹️ Timer live arrêté");
    }
  }

  @override
  void dispose() {
    _liveTimers.values.forEach((timer) => timer.cancel());
    _liveTimers.clear();
    printVm("🧹 LiveProvider disposé");
    super.dispose();
  }
}








