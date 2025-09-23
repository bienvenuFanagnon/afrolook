// models/live_models.dart
import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';


import '../../models/model_data.dart';
import '../../services/linkService.dart';
import '../paiement/newDepot.dart';

class PostLive {
  final String? liveId;
  final String? hostId;
  final String? hostName;
  final String? hostImage;
  final String title;
  int viewerCount;
  int? giftCount;
  final DateTime startTime;
  DateTime? endTime;
  bool isLive;
  double giftTotal;
  final List<LiveGift> gifts;
  bool paymentRequired;
  DateTime? paymentRequestTime;
  final List<String> invitedUsers;
  final List<String> participants;
  final List<String> spectators;
  final double participationFee;
  bool earningsWithdrawn;
  DateTime? withdrawalDate;
  String? withdrawalTransactionId;

  PostLive({
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
    this.gifts = const [],
    this.paymentRequired = false,
    this.paymentRequestTime,
    this.invitedUsers = const [],
    this.participants = const [],
    this.spectators = const [],
    this.participationFee = 100.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'liveId': liveId,
      'hostId': hostId,
      'hostName': hostName,
      'hostImage': hostImage,
      'title': title,
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
      'participationFee': participationFee,
      'earningsWithdrawn': earningsWithdrawn,
      'withdrawalDate': withdrawalDate,
      'withdrawalTransactionId': withdrawalTransactionId,
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
      // giftCount: map['giftCount'] ?? 0,
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
      participationFee: map['participationFee']?.toDouble() ?? 100.0,

      earningsWithdrawn: map['earningsWithdrawn'] ?? false,
      withdrawalDate: map['withdrawalDate']?.toDate(),
      withdrawalTransactionId: map['withdrawalTransactionId'],
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

class Gift {
  final String id;
  final String name;
  final double price;
  final String icon;
  final Color color;

  Gift({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
    required this.color,
  });
}


// providers/live_provider.dart


class LiveProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<PostLive> _activeLives = [];
  Map<String, Timer> _liveTimers = {};


  List<PostLive> _allLives = []; // Liste pour tous les lives

  List<PostLive> get allLives => _allLives;
  List<PostLive> get activeLives => _activeLives;

  // Récupérer tous les lives, peu importe leur statut
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
          print("Impossible de convertir le live ${doc.data()}: $e");
          // On ignore ce live pour ne pas bloquer la liste
        }
      }



      print("Liste des lives: ${_allLives.length}");

      // Filtrer les lives actifs
      // _activeLives = _allLives.where((live) => live.isLive).toList();
      // _activeLives = _allLives;

      notifyListeners();
    } catch (e) {
      print("Erreur lors du chargement des lives: $e");
    }
  }

  // Récupérer seulement les lives actifs
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
          // On ignore ce live pour ne pas bloquer la liste
        }
      }

      notifyListeners();
    } catch (e) {
      print("Erreur lors du chargement des lives actifs: $e");
    }
  }


  Future<void> inviteUserToLive(String liveId, String userId) async {
    try {
      await _firestore.collection('lives').doc(liveId).update({
        'invitedUsers': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      print("Erreur lors de l'invitation: $e");
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
          return true;
        }
      }
      return false;
    } catch (e) {
      print("Erreur lors de la participation: $e");
      return false;
    }
  }

  Future<void> joinAsSpectator(String liveId, String userId) async {
    try {
      await _firestore.collection('lives').doc(liveId).update({
        'spectators': FieldValue.arrayUnion([userId]),
        'viewerCount': FieldValue.increment(1),
      });
    } catch (e) {
      print("Erreur lors de l'ajout du spectateur: $e");
    }
  }

  Future<void> leaveLive(String liveId, String userId) async {
    try {
      await _firestore.collection('lives').doc(liveId).update({
        'participants': FieldValue.arrayRemove([userId]),
        'spectators': FieldValue.arrayRemove([userId]),
        'viewerCount': FieldValue.increment(-1),
      });
    } catch (e) {
      print("Erreur lors de la sortie du live: $e");
    }
  }

  void startLiveTimer(String liveId, int durationMinutes, Function onTimeExpired) {
    stopLiveTimer(liveId);
    _liveTimers[liveId] = Timer(Duration(minutes: durationMinutes), () {
      onTimeExpired();
      stopLiveTimer(liveId);
    });
  }

  void stopLiveTimer(String liveId) {
    if (_liveTimers.containsKey(liveId)) {
      _liveTimers[liveId]!.cancel();
      _liveTimers.remove(liveId);
    }
  }

  @override
  void dispose() {
    _liveTimers.values.forEach((timer) => timer.cancel());
    _liveTimers.clear();
    super.dispose();
  }
}





// pages/create_live_page.dart


class JoinLiveDialog extends StatelessWidget {
  final String liveId;
  final VoidCallback onJoinAsParticipant;
  final VoidCallback onJoinAsSpectator;

  const JoinLiveDialog({
    Key? key,
    required this.liveId,
    required this.onJoinAsParticipant,
    required this.onJoinAsSpectator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rejoindre le Live',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text('Vous avez été invité à participer à ce live',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: onJoinAsParticipant,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF9A825),
                minimumSize: Size(200, 50),
              ),
              child: Text('Participer (100 FCFA)', style: TextStyle(color: Colors.black)),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: onJoinAsSpectator,
              child: Text('Regarder seulement', style: TextStyle(color: Color(0xFFF9A825))),
            ),
          ],
        ),
      ),
    );
  }
}


class LivePage extends StatefulWidget {
  final String liveId;
  final PostLive postLive;
  final bool isHost;
  final String hostName;
  final String hostImage;
  final bool isInvited;

  const LivePage({
    Key? key,
    required this.liveId,
    required this.isHost,
    required this.hostName,
    required this.hostImage,
    required this.isInvited, required this.postLive,
  }) : super(key: key);

  @override
  _LivePageState createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _commentController = TextEditingController();

  int? _remoteUid;
  bool _localUserJoined = false;
  late RtcEngine _engine;
  int _viewerCount = 0;
  int _giftCount = 0;
  List<LiveComment> _comments = [];
  bool _showGiftPanel = false;
  bool _showPaymentWarning = false;
  Timer? _paymentWarningTimer;
  bool _isFollowing = false;
  double _giftTotal = 0.0;
  List<String> _participants = [];
  List<String> _spectators = [];
  bool _isParticipant = false;
  bool _hostJoined = false;
  bool _isInitialized = false;
  bool _isFullScreen = false;
  int _likeCount = 0;
  int _subscriberCount = 0;
  String _hostUsername = '';
  UserData _hostData = UserData();
  Timer? _likeEffectTimer;
  final List<LikeEffect> _likeEffects = [];
  final List<GiftEffect> _giftEffects = [];
  double _commentsHeight = 0.3; // Hauteur initiale des commentaires
  final ScrollController _commentsScrollController = ScrollController();

  // Stream subscriptions
  StreamSubscription<DocumentSnapshot>? _liveSubscription;
  StreamSubscription<QuerySnapshot>? _commentsSubscription;
  StreamSubscription<DocumentSnapshot>? _hostSubscription;



  @override
  void initState() {
    super.initState();
    print("🎬 Initialisation de LivePage - isHost: ${widget.isHost}");
 
    _initAgora();
    _setupFirestoreListeners();
    _fetchHostData();

    if (widget.isHost) {
      _startPaymentTimer();
    }

    if (widget.isInvited) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showJoinOptions();
      });
    }

    // Démarrer le timer pour les effets de like automatiques
    _startLikeEffectTimer();
  }

  Future<void> _joinAsParticipant() async {
    try {
      final authProvider = context.read<UserAuthProvider>();
      final liveProvider = context.read<LiveProvider>();

      if (authProvider.loginUserData!.votre_solde_principal! < 100) {
        _showPaymentRequiredDialog();
        return;
      }

      final paymentSuccess = await authProvider.deductFromBalance(context,100.0);

      if (paymentSuccess) {
        authProvider.incrementAppGain(100);
        await liveProvider.joinAsParticipant(widget.liveId, authProvider.userId!);
        setState(() {
          _isParticipant = true;
        });
        await _reinitializeAgora();
      }
    } catch (e) {
      print("❌ Erreur rejoindre comme participant: $e");
    }
  }

  Future<void> _joinAsSpectator() async {
    try {
      final liveProvider = context.read<LiveProvider>();
      await liveProvider.joinAsSpectator(widget.liveId, _auth.currentUser!.uid);
      print("👀 Rejoint comme spectateur");
    } catch (e) {
      print("❌ Erreur rejoindre comme spectateur: $e");
    }
  }

  Future<void> _reinitializeAgora() async {
    try {
      await _engine.leaveChannel();
      await _engine.release();
      await _initAgora();
    } catch (e) {
      print("❌ Erreur réinitialisation Agora: $e");
    }
  }

  void _showPaymentRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Solde insuffisant', style: TextStyle(color: Colors.white)),
        content: Text('Vous avez besoin de 100 FCFA pour participer au live.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Color(0xFFF9A825))),
          ),
        ],
      ),
    );
  }

  void _startPaymentTimer() {
    _paymentWarningTimer = Timer(const Duration(minutes: 55), () {
      _requestPayment();
    });
  }

  void _requestPayment() async {
    try {
      await _firestore.collection('lives').doc(widget.liveId).update({
        'paymentRequired': true,
        'paymentRequestTime': DateTime.now(),
      });

      setState(() {
        _showPaymentWarning = true;
      });
    } catch (e) {
      print("❌ Erreur demande paiement: $e");
    }
  }

  void _handlePayment() async {
    try {
      final userProvider = context.read<UserAuthProvider>();
      bool paymentSuccess = await userProvider.deductFromBalance(context,100.0);

      if (paymentSuccess) {
        userProvider.incrementAppGain(100);

        await _firestore.collection('lives').doc(widget.liveId).update({
          'paymentRequired': false,
          'paymentRequestTime': null,
        });

        setState(() {
          _showPaymentWarning = false;
        });
        _startPaymentTimer();
      } else {
        _endLive();
      }
    } catch (e) {
      print("❌ Erreur traitement paiement: $e");
    }
  }


  Future<void> _fetchHostData() async {
    try {
      final hostDoc = await _firestore.collection('Users').doc(widget.postLive.hostId).get();
      if (hostDoc.exists) {
        setState(() {
          _hostData = UserData.fromJson(hostDoc.data()!) ;
          _isFollowing = _hostData.userAbonnesIds?.contains(widget.postLive.hostId) ?? false;
          // _isFollowing = true;
          // _subscriberCount = _hostData['subscriberCount'] ?? 0;
          // _hostUsername = _hostData['username'] ?? widget.hostName;
        });
      }
    } catch (e) {
      print("❌ Erreur récupération données hôte: $e");
    }
  }
  Future<String?> _getAgoraToken({
    required String channelName,
    required int uid,
    required bool isHost,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('generateAgoraToken');
      final result = await callable.call({
        'channelName': channelName,
        'uid': uid.toString(),
        'role': isHost ? 'host' : 'audience',
      });

      return result.data['token'] as String;
    } catch (e) {
      print("❌ Erreur récupération token Agora: $e");
      return null;
    }
  }
  Future<void> _initAgora() async {
    try {
      print("🔊 Demande des permissions Agora...");
      await [Permission.microphone, Permission.camera].request();

      print("🚀 Création du moteur Agora...");
      _engine = createAgoraRtcEngine();

      await _engine.initialize(RtcEngineContext(
        appId: "957063f627aa471581a52d4160f7c054", // <- Juste l’App ID public
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // Configuration des handlers
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            print("✅ Rejoint le canal avec succès - UID: ${connection.localUid}");
            setState(() => _localUserJoined = true);
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            print("👤 Utilisateur rejoint: $remoteUid");
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            print("👋 Utilisateur parti: $remoteUid");
            setState(() => _remoteUid = null);
          },
        ),
      );

      await _engine.enableVideo();

      final role = widget.isHost || _isParticipant
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience;

      await _engine.setClientRole(role: role);

      if (widget.isHost || _isParticipant) {
        await _engine.startPreview();
      }

      // 🔑 Récupération du token depuis la Cloud Function
      final uid = 0; // Laisse Agora générer ou utilise Firebase UID hashé
      final token = await _getAgoraToken(
        channelName: widget.liveId,
        uid: uid,
        isHost: widget.isHost || _isParticipant,
      );

      if (token == null) {
        throw Exception("Impossible de générer un token Agora");
      }

      // 🔗 Rejoindre le canal avec token sécurisé
      await _engine.joinChannel(
        token: token,
        channelId: widget.liveId,
        uid: uid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: role,
          publishCameraTrack: widget.isHost || _isParticipant,
          publishMicrophoneTrack: widget.isHost || _isParticipant,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      setState(() => _isInitialized = true);
    } catch (e) {
      print("💥 Erreur lors de l'initialisation Agora: $e");
    }
  }


  void _setupFirestoreListeners() {
    print("🔥 Configuration des listeners Firestore...");

    // Listener pour les données du live
    _liveSubscription = _firestore.collection('lives').doc(widget.liveId).snapshots().listen(
          (snapshot) {
        try {
          if (snapshot.exists) {
            final data = snapshot.data()!;
            print("📊 Mise à jour des données du live: ${data['viewerCount']} spectateurs");

            setState(() {
              _viewerCount = data['viewerCount'] ?? 0;
              _giftCount = data['giftCount'] ?? 0;
              _giftTotal = (data['giftTotal'] ?? 0).toDouble();
              _participants = List<String>.from(data['participants'] ?? []);
              _spectators = List<String>.from(data['spectators'] ?? []);
              _likeCount = data['likeCount'] ?? 0;

              // Vérifier si l'utilisateur actuel est un participant
              final currentUserId = _auth.currentUser?.uid;
              _isParticipant = currentUserId != null && _participants.contains(currentUserId);
            });
          }
        } catch (e) {
          print("❌ Erreur traitement données live: $e");
        }
      },
      onError: (error) {
        print("❌ Erreur listener live: $error");
      },
    );

    // Listener pour les commentaires
    _commentsSubscription = _firestore
        .collection('livecomments')
        .where('liveId', isEqualTo: widget.liveId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen(
          (snapshot) {
        try {
          print("💬 ${snapshot.docs.length} commentaires chargés");
          setState(() {
            _comments = snapshot.docs.map((doc) {
              return LiveComment.fromMap(doc.data());
            }).toList();
          });

          // Faire défiler vers le bas pour voir les nouveaux commentaires
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_commentsScrollController.hasClients) {
              _commentsScrollController.animateTo(
                _commentsScrollController.position.maxScrollExtent,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        } catch (e) {
          print("❌ Erreur traitement commentaires: $e");
        }
      },
      onError: (error) {
        print("❌ Erreur listener commentaires: $error");
      },
    );

    // Incrémenter le compteur de viewers quand un utilisateur rejoint
    if (!widget.isHost) {
      _firestore.collection('lives').doc(widget.liveId).update({
        'viewerCount': FieldValue.increment(1),
        'spectators': FieldValue.arrayUnion([_auth.currentUser!.uid]),
      });
    }
  }

  void _startLikeEffectTimer() {
    _likeEffectTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (mounted && _viewerCount > 0) {
        setState(() {
          _likeEffects.add(LikeEffect(
            id: DateTime.now().millisecondsSinceEpoch,
            x: Random().nextDouble() * 0.8 + 0.1, // Position aléatoire en X
          ));
        });

        // Supprimer les effets après 3 secondes
        Future.delayed(Duration(seconds: 3), () {
          if (mounted && _likeEffects.isNotEmpty) {
            setState(() {
              _likeEffects.removeAt(0);
            });
          }
        });
      }
    });
  }

  // ... (autres méthodes comme _showJoinOptions, _joinAsParticipant, etc.)
  void _showJoinOptions() {
    showDialog(
      context: context,
      builder: (context) => JoinLiveDialog(
        liveId: widget.liveId,
        onJoinAsParticipant: _joinAsParticipant,
        onJoinAsSpectator: _joinAsSpectator,
      ),
    );
  }
  void _endLive() async {
    try {
      await _firestore.collection('lives').doc(widget.liveId).update({
        'isLive': false,
        'endTime': DateTime.now(),
      });

      // Quitter le canal Agora
      await _engine.leaveChannel();
      await _engine.release();

      Navigator.pop(context);
      print("🛑 Live terminé");
    } catch (e) {
      print("❌ Erreur fin du live: $e");
    }
  }
  void _toggleScreenMode() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  void _confirmEndLive() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Terminer le live?', style: TextStyle(color: Colors.white)),
          content: Text('Voulez-vous vraiment terminer votre live?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _endLive();
              },
              child: Text('Terminer', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _sendComment(String message, {String type = 'text', String? giftId}) {
    late UserAuthProvider authProvider =
    Provider.of<UserAuthProvider>(context, listen: false);

    try {
      User? user = _auth.currentUser;
      if (user != null && message.isNotEmpty) {
        // Limiter à 20 mots maximum
        final words = message.split(' ');
        if (words.length > 20) {
          message = words.take(20).join(' ') + '...';
        }

        _firestore.collection('livecomments').add({
          'liveId': widget.liveId,
          'userId': user.uid,
          'username': authProvider.loginUserData.pseudo! ?? 'Utilisateur',
          'userImage': authProvider.loginUserData.imageUrl! ?? '',
          'message': message,
          'timestamp': DateTime.now(),
          'type': type,
          'giftId': giftId,
        });
        print("💬 Commentaire envoyé: $message");
      }
    } catch (e) {
      print("❌ Erreur envoi commentaire: $e");
    }
  }

  void _sendLike() {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        _firestore.collection('lives').doc(widget.liveId).update({
          'likeCount': FieldValue.increment(1),
        });

        setState(() {
          _likeEffects.add(LikeEffect(
            id: DateTime.now().millisecondsSinceEpoch,
            x: 0.5, // Position centrale
          ));
        });

        // Supprimer l'effet après 3 secondes
        Future.delayed(Duration(seconds: 3), () {
          if (mounted && _likeEffects.isNotEmpty) {
            setState(() {
              _likeEffects.removeAt(0);
            });
          }
        });
      }
    } catch (e) {
      print("❌ Erreur envoi like: $e");
    }
  }

  void _sendGift(Gift gift) async {
    print("❌ _sendGift");

    try {
      final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final userBalance = userProvider.loginUserData!.votre_solde_principal!;

      if (userBalance < gift.price) {
        print("❌ Solde insuffisant");

        _showInsufficientBalanceDialog();
        return;
      }

      final paymentSuccess = await userProvider.deductFromBalance(context,gift.price);
      print("❌ _sendGift3");

      if (paymentSuccess) {
        User? user = _auth.currentUser;
        if (user != null) {
          _sendComment(
            'a envoyé ${gift.name} - ${gift.icon}',
            type: 'gift',
            giftId: gift.id,
          );

          _firestore.collection('lives').doc(widget.liveId).update({
            'giftTotal': FieldValue.increment((gift.price*0.7)),
            'giftCount': FieldValue.increment(1),
            'gifts': FieldValue.arrayUnion([{
              'giftId': gift.id,
              'senderId': user.uid,
              'senderName': userProvider.loginUserData!.pseudo ?? 'Utilisateur',
              'timestamp': DateTime.now(),
              'price': gift.price,
            }])
          });
          userProvider.incrementAppGain(gift.price*0.3);

          // Ajouter l'effet de cadeau
          setState(() {
            _giftEffects.add(GiftEffect(
              id: DateTime.now().millisecondsSinceEpoch,
              gift: gift,
              x: Random().nextDouble() * 0.6 + 0.2, // Position aléatoire
            ));
          });

          // Supprimer l'effet après 5 secondes
          Future.delayed(Duration(seconds: 5), () {
            if (mounted && _giftEffects.isNotEmpty) {
              setState(() {
                _giftEffects.removeAt(0);
              });
            }
          });

          setState(() {
            _showGiftPanel = false;
          });

          print("🎁 Cadeau envoyé: ${gift.name}");
        }
      }
    } catch (e) {
      print("❌ Erreur envoi cadeau: $e");
    }
  }

  void _showInsufficientBalanceDialog() {
    print("❌ Solde insuffisant");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Solde insuffisant', style: TextStyle(color: Colors.white)),
        content: Text('Votre solde est insuffisant pour envoyer ce cadeau. Voulez-vous recharger?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Plus tard', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Naviguer vers la page de recharge
              Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen()));
            },
            child: Text('Recharger', style: TextStyle(color: Color(0xFFF9A825))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    print("🧹 Nettoyage LivePage...");

    _liveSubscription?.cancel();
    _commentsSubscription?.cancel();
    _hostSubscription?.cancel();
    _paymentWarningTimer?.cancel();
    _likeEffectTimer?.cancel();
    _commentsScrollController.dispose();

    _engine.leaveChannel();
    _engine.release();
    _commentController.dispose();

    // Décrémenter le compteur de viewers quand un utilisateur quitte
    if (!widget.isHost) {
      // _firestore.collection('lives').doc(widget.liveId).update({
      //   'viewerCount': FieldValue.increment(-1),
      //   'spectators': FieldValue.arrayRemove([_auth.currentUser!.uid]),
      // });
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Live video
          _buildVideoSection(),

          // App name in top right
          _buildAppName(),

          // Host info and controls
          _buildHostOverlay(),

          // Viewer count & like count
          _buildViewerInfo(),

          // Comments section
          _buildCommentsSection(),

          // Footer with message, like, gift, share
          _buildFooter(),

          // Gift panel
          if (_showGiftPanel) _buildGiftPanel(),

          // Payment warning overlay
          if (_showPaymentWarning) _buildPaymentWarning(),

          // Like effects
          ..._buildLikeEffects(),

          // Gift effects
          ..._buildGiftEffects(),

          // Debug info (à enlever en production)
          if (!_isInitialized) _buildLoadingOverlay(),
        ],
      ),
    );
  }
  Future<void> _toggleFollow() async {
    setState(() {
      _isFollowing = !_isFollowing;
    });

    if(_isFollowing==false){
      // Mise à jour atomique dans Firestore
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(_hostData.id)
          .update({
        'userAbonnesIds': FieldValue.arrayUnion([_hostData.id]),
        'abonnes': FieldValue.increment(1),
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });
    }

    // Logique Firebase pour follow à ajouter
  }
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFF9A825)),
            SizedBox(height: 16),
            Text(
              'Connexion au live en cours...',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              'Live ID: ${widget.liveId}',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  final List<Gift> _gifts = [
    Gift(id: '1', name: 'Rose', price: 10, icon: '🌹', color: Colors.pink),
    Gift(id: '2', name: 'Coeur', price: 25, icon: '❤️', color: Colors.red),
    Gift(id: '3', name: 'Couronne', price: 50, icon: '👑', color: Colors.yellow),
    Gift(id: '4', name: 'Diamant', price: 100, icon: '💎', color: Colors.blue),
    Gift(id: '5', name: 'Ferrari', price: 200, icon: '🏎️', color: Colors.redAccent),
    Gift(id: '6', name: 'Étoile', price: 300, icon: '⭐', color: Colors.orange),
    Gift(id: '7', name: 'Chocolat', price: 500, icon: '🍫', color: Colors.brown),
    Gift(id: '8', name: 'Coffre', price: 700, icon: '🧰', color: Colors.green),
    Gift(id: '9', name: 'Cactus', price: 1500, icon: '🌵', color: Colors.teal),
    Gift(id: '10', name: 'Pizza', price: 2000, icon: '🍕', color: Colors.deepOrange),
    Gift(id: '11', name: 'Glace', price: 2500, icon: '🍦', color: Colors.lightBlue),
    Gift(id: '12', name: 'Laptop', price: 5000, icon: '💻', color: Colors.blueGrey),
    Gift(id: '13', name: 'Voiture', price: 7000, icon: '🚗', color: Colors.red),
    Gift(id: '14', name: 'Maison', price: 10000, icon: '🏠', color: Colors.brown),
    Gift(id: '15', name: 'Jet', price: 15000, icon: '🛩️', color: Colors.grey),
    Gift(id: '16', name: 'Yacht', price: 20000, icon: '🛥️', color: Colors.blue),
    Gift(id: '17', name: 'Château', price: 30000, icon: '🏰', color: Colors.deepPurple),
    Gift(id: '18', name: 'Diamant Rare', price: 50000, icon: '💎', color: Colors.cyan),
    Gift(id: '19', name: 'Ferrari Rouge', price: 75000, icon: '🏎️', color: Colors.redAccent),
    Gift(id: '20', name: 'Lamborghini', price: 100000, icon: '🚗', color: Colors.orange),
  ];

  Widget _buildGiftPanel() {
    final height = MediaQuery.of(context).size.height * 0.6; // 60% de l'écran

    return Stack(
      children: [
        // Fond semi-transparent
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _showGiftPanel = false),
            child: Container(color: Colors.black54),
          ),
        ),

        // Panel de cadeaux
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Header avec bouton fermer
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Envoyer un cadeau',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() => _showGiftPanel = false),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _gifts.length,
                    itemBuilder: (context, index) {
                      final gift = _gifts[index];
                      return GestureDetector(
                        onTap: () => _sendGift(gift),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: gift.color, width: 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(gift.icon, style: TextStyle(fontSize: 24)),
                              SizedBox(height: 4),
                              Text(gift.name,
                                  style: TextStyle(color: Colors.white, fontSize: 10),
                                  textAlign: TextAlign.center),
                              SizedBox(height: 2),
                              Text('${gift.price.toInt()} FCFA',
                                  style: TextStyle(color: Color(0xFFF9A825), fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentWarning() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      padding: EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer, size: 64, color: Color(0xFFF9A825)),
            SizedBox(height: 20),
            Text(
              'Temps de live écoulé',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Payez 100 FCFA pour continuer votre live pendant 1 heure supplémentaire',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _handlePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF9A825),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text('Payer 100 FCFA',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: _endLive,
                  child: Text('Arrêter', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection() {
    if (!_isInitialized) {
      return Center(child: CircularProgressIndicator(color: Color(0xFFF9A825)));
    }

    return Stack(
      children: [
        // Vidéo distante (spectateurs)
        if (_remoteUid != null)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(channelId: widget.liveId),
            ),
          ),

        // Vidéo locale (hôte/participant)
        if (widget.isHost || _isParticipant)
          Positioned(
            bottom: _isFullScreen ? 16 : 100,
            right: 16,
            child: GestureDetector(
              onTap: _toggleScreenMode,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                width: _isFullScreen ? MediaQuery.of(context).size.width : 120,
                height: _isFullScreen ? MediaQuery.of(context).size.height : 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_isFullScreen ? 0 : 12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          ),

        // Message d'attente
        if (_remoteUid == null && !widget.isHost && !_isParticipant)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('En attente du stream...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAppName() {
    return Positioned(
      top: 40,
      right: 16,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6),
          Text(
            'Afrolook Live',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              foreground: Paint()..shader = LinearGradient(
                colors: <Color>[Colors.greenAccent, Colors.green],
              ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
              shadows: [
                Shadow(
                  offset: Offset(2.0, 2.0),
                  blurRadius: 4.0,
                  color: Colors.black38,
                ),
              ],
            ),
          ),

          // Text(
          //   'Afrolook Live',
          //   style: TextStyle(
          //     color: Colors.green,
          //     fontWeight: FontWeight.w900,
          //     fontSize: 16,
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildHostOverlay() {

    return Positioned(
      top: 50,
      left: 16,
      child: GestureDetector(
        onTap: () {
          double h = MediaQuery.of(context).size.height;
          double w = MediaQuery.of(context).size.width;
          showUserDetailsModalDialog(_hostData, w, h, context);
        },
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.hostImage),
              radius: 20,
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "@${_hostData.pseudo}",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_hostData.userAbonnesIds!.length} abonnés',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (widget.isHost)
                  Text(
                    'Hôte du live',
                    style: TextStyle(color: Color(0xFFF9A825), fontSize: 12),
                  ),
              ],
            ),
            SizedBox(width: 12),
            if (!widget.isHost)
              GestureDetector(
                onTap: _toggleFollow,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isFollowing ? Colors.grey : Color(0xFFF9A825),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isFollowing ? 'Suivi' : 'Suivre',
                    style: TextStyle(
                      color: _isFollowing ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerInfo() {
    return Positioned(
      top: 100,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Viewer count
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.people, color: Colors.white70, size: 16),
                SizedBox(width: 4),
                Text(
                  '$_viewerCount',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          // Like count
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite, color: Colors.pink, size: 12),
                SizedBox(width: 4),
                Text(
                  '$_likeCount',
                  style: TextStyle(color: Colors.white70,fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          // Gift total
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.card_giftcard, color: Color(0xFFF9A825), size: 16),
                SizedBox(width: 4),
                Text(
                  // '${_giftTotal.toInt()} FCFA',
                  '${_giftCount} : ${_giftTotal.toInt()} FCFA',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold,fontSize: 12),
                ),
              ],
            ),
          ),
          if (widget.isHost) ...[
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _confirmEndLive,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'Arrêter',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    final screenHeight = MediaQuery.of(context).size.height;
    final commentsHeight = widget.isHost ? screenHeight * 0.4 : screenHeight * 0.3;

    return Positioned(
      bottom: 80,
      left: 8,
      width: MediaQuery.of(context).size.width * 0.7,
      height: commentsHeight,
      child: Column(
        children: [
          // Drag handle for resizing
          if (!widget.isHost)
            GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  _commentsHeight = (_commentsHeight - details.delta.dy / screenHeight).clamp(0.2, 0.5);
                });
              },
              child: Container(
                height: 20,
                width: double.infinity,
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.builder(
                controller: _commentsScrollController,
                reverse: true,
                shrinkWrap: true,
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  return _buildCommentItem(comment);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(LiveComment comment) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(comment.userImage),
            radius: 12,
          ),
          SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.username,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  comment.message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Envoyer un message...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: Color(0xFFF9A825), size: 20),
                      onPressed: () {
                        if (_commentController.text.isNotEmpty) {
                          _sendComment(_commentController.text);
                          _commentController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),
            GestureDetector(
              onTap: _sendLike,
              child: Column(
                children: [
                  Icon(Icons.favorite, color: Colors.red, size: 28),
                  SizedBox(height: 2),
                  Text(
                    '$_likeCount',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            GestureDetector(
              onTap: () => setState(() => _showGiftPanel = true),
              child: Column(
                children: [
                  Icon(Icons.card_giftcard, color: Color(0xFFF9A825), size: 28),
                  SizedBox(height: 2),
                  Text(
                    'Cadeau',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                final AppLinkService _appLinkService = AppLinkService();
                _appLinkService.shareContent(
                  type: AppLinkType.live,
                  id: widget.liveId!,
                  message: " 🎥🔥 ${widget.postLive.title}",
                  mediaUrl: "${widget.postLive.hostImage}",
                );
                //
                // _appLinkService.shareLink(
                //   AppLinkType.live,
                //   widget.liveId!,
                //   message: '🔥🎥 LIVE EN COURS ! 🎥🔥 ${widget.postLive.title} 💫 Ne rate pas ce direct exceptionnel sur Afrolook ! 🚀⭐️',                );
                //
                }, // Logique de partage
              child: Icon(Icons.share, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLikeEffects() {
    return _likeEffects.map((effect) {
      return Positioned(
        left: effect.x * MediaQuery.of(context).size.width,
        bottom: 100 + (DateTime.now().millisecondsSinceEpoch % 100) * 2,
        child: LikeAnimation(
          child: Icon(Icons.favorite, color: Colors.pink, size: 30),
        ),
      );
    }).toList();
  }

  List<Widget> _buildGiftEffects() {
    return _giftEffects.map((effect) {
      return Positioned(
        left: effect.x * MediaQuery.of(context).size.width,
        bottom: 150 + (DateTime.now().millisecondsSinceEpoch % 100) * 2,
        child: GiftAnimation(
          gift: effect.gift,
        ),
      );
    }).toList();
  }

// ... (autres méthodes comme _buildGiftPanel, _buildPaymentWarning, etc.)
}

// Classes pour les effets
class LikeEffect {
  final int id;
  final double x;

  LikeEffect({required this.id, required this.x});
}

class GiftEffect {
  final int id;
  final Gift gift;
  final double x;

  GiftEffect({required this.id, required this.gift, required this.x});
}

// Widget d'animation pour les likes
class LikeAnimation extends StatefulWidget {
  final Widget child;

  const LikeAnimation({Key? key, required this.child}) : super(key: key);

  @override
  _LikeAnimationState createState() => _LikeAnimationState();
}

class _LikeAnimationState extends State<LikeAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _controller.reset();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

// Widget d'animation pour les cadeaux
class GiftAnimation extends StatefulWidget {
  final Gift gift;

  const GiftAnimation({Key? key, required this.gift}) : super(key: key);

  @override
  _GiftAnimationState createState() => _GiftAnimationState();
}

class _GiftAnimationState extends State<GiftAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _positionAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(0, -0.5),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _positionAnimation,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(widget.gift.icon, style: TextStyle(fontSize: 24)),
                    SizedBox(height: 4),
                    Text(
                      widget.gift.name,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}