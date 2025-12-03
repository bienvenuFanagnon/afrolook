// models/live_models.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


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
  final double participationFee;
  final int freeTrialMinutes;

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
    );
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
  DocumentSnapshot? _lastAllLiveDoc;
  DocumentSnapshot? _lastActiveLiveDoc;
  DocumentSnapshot? _lastEndedLiveDoc;
  bool _allLivesFinished = false;
  bool _activeLivesFinished = false;
  bool _endedLivesFinished = false;

  // Getters
  List<PostLive> get endedLives => _endedLives;
  List<PostLive> get allLives => _allLives;
  List<PostLive> get activeLives => _activeLives;

  // ==================== MÉTHODES DE RÉCUPÉRATION ====================

  Future<void> fetchAllLivesBatch({bool reset = false}) async {
    if (reset) {
      _allLives = [];
      _lastAllLiveDoc = null;
      _allLivesFinished = false;
      print("🔄 Reset de tous les lives");
    }
    if (_allLivesFinished) {
      print("✅ Tous les lives déjà chargés");
      return;
    }
    // inal List<String> totalspectateurs ;
    // final List<String> participants;
    // final List<String> spectators;
    try {
      Query query = _firestore
          .collection('lives')
          .orderBy('isLive', descending: true)
          // .orderBy('totalspectateurs', descending: true)
          // .orderBy('spectators', descending: true)
          .orderBy('giftTotal', descending: true)
          .limit(batchSize);

      if (_lastAllLiveDoc != null) {
        query = query.startAfterDocument(_lastAllLiveDoc!);
        print("📥 Chargement supplémentaire de tous les lives");
      } else {
        print("📥 Premier chargement de tous les lives");
      }

      QuerySnapshot snapshot = await query.get();
      print("📊 ${snapshot.docs.length} lives récupérés");

      if (snapshot.docs.isEmpty) {
        _allLivesFinished = true;
        print("🏁 Fin du chargement - aucun live supplémentaire");
        return;
      }

      int activeCount = 0;
      int endedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final live = PostLive.fromMap(doc.data() as Map<String, dynamic>);
          _allLives.add(live);

          if (live.isLive) {
            activeCount++;
          } else {
            endedCount++;
          }

          print("✅ Live ajouté: ${live.title} - isLive: ${live.isLive} - giftTotal: ${live.giftTotal}");
        } catch (e) {
          print("❌ Impossible de convertir le live ${doc.id}: $e");
        }
      }

      _lastAllLiveDoc = snapshot.docs.last;

      if (_allLives.length >= maxLives) {
        _allLivesFinished = true;
        print("🏁 Limite maximale de lives atteinte: ${_allLives.length}");
      }

      print("📈 Statut final - Actifs: $activeCount, Terminés: $endedCount, Total: ${_allLives.length}");
      notifyListeners();

    } catch (e) {
      print("❌ Erreur lors du chargement des lives par batch: $e");
      if (reset) {
        _allLives = [];
        _lastAllLiveDoc = null;
        _allLivesFinished = false;
      }
    }
  }

  Future<void> fetchEndedLivesBatch({bool reset = false}) async {
    if (reset) {
      _endedLives = [];
      _lastEndedLiveDoc = null;
      _endedLivesFinished = false;
    }
    if (_endedLivesFinished) return;

    Query query = _firestore
        .collection('lives')
        .where('isLive', isEqualTo: false)
        .orderBy('startTime', descending: true)
        .limit(batchSize);

    if (_lastEndedLiveDoc != null) query = query.startAfterDocument(_lastEndedLiveDoc!);

    try {
      QuerySnapshot snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        _endedLivesFinished = true;
        return;
      }

      for (var doc in snapshot.docs) {
        try {
          final live = PostLive.fromMap(doc.data() as Map<String, dynamic>);
          _endedLives.add(live);
        } catch (e) {
          print("Impossible de convertir le live terminé ${doc.id}: $e");
        }
      }

      _lastEndedLiveDoc = snapshot.docs.last;

      if (_endedLives.length >= maxLives) _endedLivesFinished = true;

      notifyListeners();
    } catch (e) {
      print("Erreur lors du chargement des lives terminés par batch: $e");
    }
  }

  Future<void> fetchActiveLivesBatch({bool reset = false}) async {
    if (reset) {
      _activeLives = [];
      _lastActiveLiveDoc = null;
      _activeLivesFinished = false;
    }
    if (_activeLivesFinished) return;

    Query query = _firestore
        .collection('lives')
        .where('isLive', isEqualTo: true)
        .orderBy('giftTotal', descending: true)
        .limit(batchSize);

    if (_lastActiveLiveDoc != null) query = query.startAfterDocument(_lastActiveLiveDoc!);

    try {
      QuerySnapshot snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        _activeLivesFinished = true;
        return;
      }

      for (var doc in snapshot.docs) {
        try {
          final live = PostLive.fromMap(doc.data() as Map<String, dynamic>);
          _activeLives.add(live);
        } catch (e) {
          print("Impossible de convertir le live actif ${doc.id}: $e");
        }
      }

      _lastActiveLiveDoc = snapshot.docs.last;

      if (_activeLives.length >= maxLives) _activeLivesFinished = true;

      notifyListeners();
    } catch (e) {
      print("Erreur lors du chargement des lives actifs par batch: $e");
    }
  }

  Future<void> fetchAllLives() async {
    _allLives = [];
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('lives')
          .orderBy('startTime', descending: true)
          .get();
      for (var doc in snapshot.docs) {
        try {
          final live = PostLive.fromMap(doc.data() as Map<String, dynamic>);
          _allLives.add(live);
        } catch (e) {
          print("Impossible de convertir le live ${doc.id}: $e");
        }
      }
      print("Liste des lives: ${_allLives.length}");
      notifyListeners();
    } catch (e) {
      print("Erreur lors du chargement des lives: $e");
    }
  }

  Future<void> fetchActiveLives() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('lives')
          .where('isLive', isEqualTo: true)
          .orderBy('startTime', descending: true)
          .get();

      _activeLives = [];

      for (var doc in snapshot.docs) {
        try {
          final live = PostLive.fromMap(doc.data() as Map<String, dynamic>);
          _activeLives.add(live);
        } catch (e) {
          print("Impossible de convertir le live ${doc.id}: $e");
        }
      }

      notifyListeners();
    } catch (e) {
      print("Erreur lors du chargement des lives actifs: $e");
    }
  }

  // ==================== NOUVELLES MÉTHODES ====================

  Future<void> updateUserWatchTime(String liveId, String userId, int minutes) async {
    try {
      await _firestore.collection('lives').doc(liveId).update({
        'userWatchTime.$userId': minutes,
      });
      print("⏰ Temps visionnage mis à jour: $userId -> $minutes min");
    } catch (e) {
      print("❌ Erreur mise à jour temps visionnage: $e");
    }
  }

  Future<bool> checkUserPaymentStatus(String liveId, String userId) async {
    try {
      final doc = await _firestore.collection('lives').doc(liveId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final userWatchTime = Map<String, dynamic>.from(data['userWatchTime'] ?? {});
        final userTime = userWatchTime[userId] ?? 0;
        return userTime > 60;
      }
      return false;
    } catch (e) {
      print("❌ Erreur vérification statut paiement: $e");
      return false;
    }
  }

  Future<void> processParticipationPayment(String liveId, String userId, double amount) async {
    try {
      await _firestore.collection('lives').doc(liveId).update({
        'paidParticipationTotal': FieldValue.increment(amount),
        'giftTotal': FieldValue.increment(amount),
        'userWatchTime.$userId': 999,
      });
      print("💰 Paiement participation traité: $amount FCFA pour $userId");
    } catch (e) {
      print("❌ Erreur traitement paiement participation: $e");
      rethrow;
    }
  }

  Future<void> updatePinnedText(String liveId, String text) async {
    try {
      if (text.isEmpty) {
        await _firestore.collection('lives').doc(liveId).update({
          'pinnedText': FieldValue.delete(),
        });
        print("📌 Texte épinglé supprimé");
      } else {
        await _firestore.collection('lives').doc(liveId).update({
          'pinnedText': text,
        });
        print("📌 Texte épinglé mis à jour: $text");
      }
    } catch (e) {
      print("❌ Erreur mise à jour texte épinglé: $e");
      rethrow;
    }
  }

  Future<void> incrementShareCount(String liveId) async {
    try {
      await _firestore.collection('lives').doc(liveId).update({
        'shareCount': FieldValue.increment(1),
      });
      print("📤 Compteur partages incrémenté");
    } catch (e) {
      print("❌ Erreur incrémentation partages: $e");
    }
  }

  Future<void> inviteUserToLive(String liveId, String userId) async {
    try {
      await _firestore.collection('lives').doc(liveId).update({
        'invitedUsers': FieldValue.arrayUnion([userId]),
      });
      print("📨 Utilisateur $userId invité au live $liveId");
    } catch (e) {
      print("❌ Erreur lors de l'invitation: $e");
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
          print("🎤 Utilisateur $userId rejoint comme participant");
          return true;
        }
      }
      return false;
    } catch (e) {
      print("❌ Erreur lors de la participation: $e");
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
      print("👀 Utilisateur $userId rejoint comme spectateur");
    } catch (e) {
      print("❌ Erreur lors de l'ajout du spectateur: $e");
    }
  }

  Future<void> leaveLive(String liveId, String userId) async {
    try {
      await _firestore.collection('lives').doc(liveId).update({
        'participants': FieldValue.arrayRemove([userId]),
        'spectators': FieldValue.arrayRemove([userId]),
        'viewerCount': FieldValue.increment(-1),
      });
      print("🚪 Utilisateur $userId a quitté le live");
    } catch (e) {
      print("❌ Erreur lors de la sortie du live: $e");
    }
  }

  void startLiveTimer(String liveId, int durationMinutes, Function onTimeExpired) {
    stopLiveTimer(liveId);
    _liveTimers[liveId] = Timer(Duration(minutes: durationMinutes), () {
      onTimeExpired();
      stopLiveTimer(liveId);
    });
    print("⏰ Timer live démarré: $durationMinutes minutes");
  }

  void stopLiveTimer(String liveId) {
    if (_liveTimers.containsKey(liveId)) {
      _liveTimers[liveId]!.cancel();
      _liveTimers.remove(liveId);
      print("⏹️ Timer live arrêté");
    }
  }

  @override
  void dispose() {
    _liveTimers.values.forEach((timer) => timer.cancel());
    _liveTimers.clear();
    print("🧹 LiveProvider disposé");
    super.dispose();
  }
}
// class LiveProvider extends ChangeNotifier {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   List<PostLive> _activeLives = [];
//   Map<String, Timer> _liveTimers = {};
//
//   List<PostLive> _endedLives = []; // Nouvelle propriété
//   DocumentSnapshot? _lastEndedLiveDoc; // Nouveau document snapshot
//   bool _endedLivesFinished = false; // Nouveau flag
//   List<PostLive> get endedLives => _endedLives; // Nouveau getter
//
//   List<PostLive> _allLives = []; // Liste pour tous les lives
//
//   List<PostLive> get allLives => _allLives;
//   List<PostLive> get activeLives => _activeLives;
//
//   // Pagination batch
//   static const int batchSize = 8;
//   static const int maxLives = 30;
//
//   DocumentSnapshot? _lastAllLiveDoc;
//   DocumentSnapshot? _lastActiveLiveDoc;
//
//   bool _allLivesFinished = false;
//   bool _activeLivesFinished = false;
//
//   // ----------------- BATCH FETCH -----------------
//   Future<void> fetchAllLivesBatch({bool reset = false}) async {
//     if (reset) {
//       _allLives = [];
//       _lastAllLiveDoc = null;
//       _allLivesFinished = false;
//       print("🔄 Reset de tous les lives");
//     }
//     if (_allLivesFinished) {
//       print("✅ Tous les lives déjà chargés");
//       return;
//     }
//
//     try {
//       Query query = _firestore
//           .collection('lives')
//           .orderBy('isLive', descending: true) // Les lives actifs d'abord
//           .orderBy('giftTotal', descending: true) // Puis par montant
//           .limit(batchSize);
//
//       if (_lastAllLiveDoc != null) {
//         query = query.startAfterDocument(_lastAllLiveDoc!);
//         print("📥 Chargement supplémentaire de tous les lives");
//       } else {
//         print("📥 Premier chargement de tous les lives");
//       }
//
//       QuerySnapshot snapshot = await query.get();
//       print("📊 ${snapshot.docs.length} lives récupérés");
//
//       if (snapshot.docs.isEmpty) {
//         _allLivesFinished = true;
//         print("🏁 Fin du chargement - aucun live supplémentaire");
//         return;
//       }
//
//       int activeCount = 0;
//       int endedCount = 0;
//
//       for (var doc in snapshot.docs) {
//         try {
//           final live = PostLive.fromMap(doc.data() as Map<String, dynamic>);
//           _allLives.add(live);
//
//           if (live.isLive) {
//             activeCount++;
//           } else {
//             endedCount++;
//           }
//
//           print("✅ Live ajouté: ${live.title} - isLive: ${live.isLive} - giftTotal: ${live.giftTotal}");
//         } catch (e) {
//           print("❌ Impossible de convertir le live ${doc.id}: $e");
//         }
//       }
//
//       _lastAllLiveDoc = snapshot.docs.last;
//
//       if (_allLives.length >= maxLives) {
//         _allLivesFinished = true;
//         print("🏁 Limite maximale de lives atteinte: ${_allLives.length}");
//       }
//
//       print("📈 Statut final - Actifs: $activeCount, Terminés: $endedCount, Total: ${_allLives.length}");
//       notifyListeners();
//
//     } catch (e) {
//       print("❌ Erreur lors du chargement des lives par batch: $e");
//       // Réinitialiser en cas d'erreur pour permettre une nouvelle tentative
//       if (reset) {
//         _allLives = [];
//         _lastAllLiveDoc = null;
//         _allLivesFinished = false;
//       }
//     }
//   }
//
//   Future<void> fetchEndedLivesBatch({bool reset = false}) async {
//     if (reset) {
//       _endedLives = [];
//       _lastEndedLiveDoc = null;
//       _endedLivesFinished = false;
//     }
//     if (_endedLivesFinished) return;
//
//     Query query = _firestore
//         .collection('lives')
//         .where('isLive', isEqualTo: false)
//         .orderBy('startTime', descending: true) // Les plus récents d'abord
//         .limit(batchSize);
//
//     if (_lastEndedLiveDoc != null) query = query.startAfterDocument(_lastEndedLiveDoc!);
//
//     try {
//       QuerySnapshot snapshot = await query.get();
//       if (snapshot.docs.isEmpty) {
//         _endedLivesFinished = true;
//         return;
//       }
//
//       for (var doc in snapshot.docs) {
//         try {
//           final live = PostLive.fromMap(doc.data() as Map<String, dynamic>);
//           _endedLives.add(live);
//         } catch (e) {
//           print("Impossible de convertir le live terminé ${doc.id}: $e");
//         }
//       }
//
//       _lastEndedLiveDoc = snapshot.docs.last;
//
//       if (_endedLives.length >= maxLives) _endedLivesFinished = true;
//
//       notifyListeners();
//     } catch (e) {
//       print("Erreur lors du chargement des lives terminés par batch: $e");
//     }
//   }
//   Future<void> fetchActiveLivesBatch({bool reset = false}) async {
//     if (reset) {
//       _activeLives = [];
//       _lastActiveLiveDoc = null;
//       _activeLivesFinished = false;
//     }
//     if (_activeLivesFinished) return;
//
//     Query query = _firestore
//         .collection('lives')
//         .where('isLive', isEqualTo: true)
//         .orderBy('giftTotal', descending: true) // Trier par montant gagné
//         .limit(batchSize);
//
//     if (_lastActiveLiveDoc != null) query = query.startAfterDocument(_lastActiveLiveDoc!);
//
//     try {
//       QuerySnapshot snapshot = await query.get();
//       if (snapshot.docs.isEmpty) {
//         _activeLivesFinished = true;
//         return;
//       }
//
//       for (var doc in snapshot.docs) {
//         try {
//           final live = PostLive.fromMap(doc.data() as Map<String, dynamic>);
//           _activeLives.add(live);
//         } catch (e) {
//           print("Impossible de convertir le live actif ${doc.id}: $e");
//         }
//       }
//
//       _lastActiveLiveDoc = snapshot.docs.last;
//
//       if (_activeLives.length >= maxLives) _activeLivesFinished = true;
//
//       notifyListeners();
//     } catch (e) {
//       print("Erreur lors du chargement des lives actifs par batch: $e");
//     }
//   }
//
//
//   // Récupérer tous les lives, peu importe leur statut
//   Future<void> fetchAllLives() async {
//     _allLives = [];
//     try {
//       QuerySnapshot snapshot = await _firestore
//           .collection('lives')
//           .orderBy('startTime', descending: true)
//           .get();
//       for (var doc in snapshot.docs) {
//         try {
//           final live = PostLive.fromMap(doc.data() as Map<String, dynamic>);
//           _allLives.add(live);
//         } catch (e) {
//           print("Impossible de convertir le live ${doc.id}: $e");
//           print("Impossible de convertir le live ${doc.data()}: $e");
//           // On ignore ce live pour ne pas bloquer la liste
//         }
//       }
//
//
//
//       print("Liste des lives: ${_allLives.length}");
//
//       // Filtrer les lives actifs
//       // _activeLives = _allLives.where((live) => live.isLive).toList();
//       // _activeLives = _allLives;
//
//       notifyListeners();
//     } catch (e) {
//       print("Erreur lors du chargement des lives: $e");
//     }
//   }
//
//   // Récupérer seulement les lives actifs
//   Future<void> fetchActiveLives() async {
//     try {
//       QuerySnapshot snapshot = await _firestore
//           .collection('lives')
//           .where('isLive', isEqualTo: true)
//           .orderBy('startTime', descending: true)
//           .get();
//
//       _activeLives = [];
//
//       for (var doc in snapshot.docs) {
//         try {
//           final live = PostLive.fromMap(doc.data() as Map<String, dynamic>);
//           _activeLives.add(live);
//         } catch (e) {
//           print("Impossible de convertir le live ${doc.id}: $e");
//           // On ignore ce live pour ne pas bloquer la liste
//         }
//       }
//
//       notifyListeners();
//     } catch (e) {
//       print("Erreur lors du chargement des lives actifs: $e");
//     }
//   }
//
//
//   Future<void> inviteUserToLive(String liveId, String userId) async {
//     try {
//       await _firestore.collection('lives').doc(liveId).update({
//         'invitedUsers': FieldValue.arrayUnion([userId]),
//       });
//     } catch (e) {
//       print("Erreur lors de l'invitation: $e");
//     }
//   }
//
//   Future<bool> joinAsParticipant(String liveId, String userId) async {
//     try {
//       final liveDoc = await _firestore.collection('lives').doc(liveId).get();
//       if (liveDoc.exists) {
//         final live = PostLive.fromMap(liveDoc.data()!);
//
//         if (live.invitedUsers.contains(userId)) {
//           await _firestore.collection('lives').doc(liveId).update({
//             'participants': FieldValue.arrayUnion([userId]),
//             'invitedUsers': FieldValue.arrayRemove([userId]),
//           });
//           return true;
//         }
//       }
//       return false;
//     } catch (e) {
//       print("Erreur lors de la participation: $e");
//       return false;
//     }
//   }
//
//   Future<void> joinAsSpectator(String liveId, String userId) async {
//     try {
//       await _firestore.collection('lives').doc(liveId).update({
//         'spectators': FieldValue.arrayUnion([userId]),
//         'viewerCount': FieldValue.increment(1),
//       });
//     } catch (e) {
//       print("Erreur lors de l'ajout du spectateur: $e");
//     }
//   }
//
//   Future<void> leaveLive(String liveId, String userId) async {
//     try {
//       await _firestore.collection('lives').doc(liveId).update({
//         'participants': FieldValue.arrayRemove([userId]),
//         'spectators': FieldValue.arrayRemove([userId]),
//         'viewerCount': FieldValue.increment(-1),
//       });
//     } catch (e) {
//       print("Erreur lors de la sortie du live: $e");
//     }
//   }
//
//   void startLiveTimer(String liveId, int durationMinutes, Function onTimeExpired) {
//     stopLiveTimer(liveId);
//     _liveTimers[liveId] = Timer(Duration(minutes: durationMinutes), () {
//       onTimeExpired();
//       stopLiveTimer(liveId);
//     });
//   }
//
//   void stopLiveTimer(String liveId) {
//     if (_liveTimers.containsKey(liveId)) {
//       _liveTimers[liveId]!.cancel();
//       _liveTimers.remove(liveId);
//     }
//   }
//
//   @override
//   void dispose() {
//     _liveTimers.values.forEach((timer) => timer.cancel());
//     _liveTimers.clear();
//     super.dispose();
//   }
// }








