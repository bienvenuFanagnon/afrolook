// models/live_models.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
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
import 'package:video_player/video_player.dart';


import '../../models/model_data.dart';
import '../../services/linkService.dart';
import '../paiement/newDepot.dart';
import 'live_widgets.dart';
import 'livesAgora.dart';
import '../../widgets/chat/generic_share_sheet.dart';

import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';

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
    required this.isInvited,
    required this.postLive,
  }) : super(key: key);

  @override
  _LivePageState createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> with SingleTickerProviderStateMixin {

  // NOUVEAUX ÉTATS
  String? _passiveStreamUrl; // L'URL HLS/RTMP pour les spectateurs passifs
  late VideoPlayerController _videoPlayerController; // Contrôleur pour lire le flux passif
  bool _isPassiveSpectator = false; // Vrai si l'utilisateur est un simple spectateur passif

  // 🔥 GETTER POUR VÉRIFIER SI L'HÔTE EST PREMIUM
  bool get _isHostPremium {
    // Vérifier l'abonnement de l'hôte depuis le provider
    return authProvider.loginUserData.abonnement?.estPremium ?? false;
  }

  // 🔥 GETTER POUR VÉRIFIER SI LE LIVE EST PREMIUM
  bool get _isLivePremium {
    // Un live est premium si sa durée est de 60 minutes
    return widget.postLive.safeLiveDurationMinutes == 60;
  }
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _pinnedTextController = TextEditingController();
  List<LikeEffect> _likeEffects = [];
  StreamSubscription? _likesSubscription;
  // AGORA
  int? _remoteUid;
  bool _localUserJoined = false;
  late RtcEngine _engine;
  bool _isInitialized = false;
  bool _isFrontCamera = true;
  int _numberOfCameras = 0;

  // STATISTIQUES
  int _viewerCount = 0;
  int _totalviewerCount = 0;
  int _giftCount = 0;
  int _likeCount = 0;
  double _giftTotal = 0.0;
  int _giftCoinsTotal = 0;
  List<String> _participants = [];
  List<String> _spectators = [];
  List<LiveComment> _comments = [];
  int _shareCount = 0;
  double _paidParticipationTotal = 0.0;
  List<Map<String, dynamic>> _topDonors = [];

  // ÉTAT INTERFACE
  bool _showUI = true;
  bool _showGiftPanel = false;
  bool _isParticipant = false;
  bool _isFollowing = false;
  bool _showUsersPanel = false;
  bool _showPinnedTextEditor = false;
  bool _isVideoBlurred = false;
  bool _isAudioRestricted = false;

  // TEMPS VISIONNAGE
  int _remainingTrialMinutes = 0;
  int _remainingTrialSeconds = 0;
  Timer? _trialTimer;
  bool _showTrialOverlay = false;

  // ANIMATIONS
  final List<GiftEffect> _giftEffects = [];
  final ScrollController _commentsScrollController = ScrollController();
  late AnimationController _likeAnimationController;

  // AUDIO & TYPING
  bool _isMicrophoneMuted = false;
  bool _isScreenSharing = false;
  Map<String, dynamic> _typingUsers = {};
  Timer? _typingTimer;
  bool _isLivePaused = false;
  String? _pauseMessage;
  // DONNÉES
  UserData _hostData = UserData();
  List<UserData> _allUsers = [];
  late UserAuthProvider authProvider;

  // SUBSCRIPTIONS
  StreamSubscription<DocumentSnapshot>? _liveSubscription;
  StreamSubscription<QuerySnapshot>? _commentsSubscription;
  StreamSubscription<QuerySnapshot>? _typingSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _usersSubscription;
  late VideoEncoderConfiguration _videoConfig;
  // LISTE DE CADEAUX
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


  @override
  void initState() {
    super.initState();
    printVm("🎬 Initialisation LivePage - Live ${widget.postLive.isPaidLive ? 'PAYANT' : 'GRATUIT'}");

    authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    _likeAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    printVm("🎬 Initialisation de LivePage - isHost: ${widget.isHost}");

    // Initialiser la configuration vidéo
    _videoConfig = VideoEncoderConfiguration();
// =========================================================================
    // CORRECTION MAJEURE: Init Agora SEULEMENT si l'utilisateur est actif
    // =========================================================================

    // final role = widget.isHost || widget.isInvited || _isParticipant;
    //
    // if (role) {
    //   _initAgora(); // Utilisateur ACTIF (Hôte ou participant) -> Utilise Agora ILS
    //   _setupCamera();
    //   // _initAgora();
    // } else {
    //   _isPassiveSpectator = true;
    //   _initPassiveStreaming(); // Utilisateur PASSIF (Spectateur) -> Utilise CDN/HLS
    // }
    // Après 3 secondes, si remoteUid est toujours null, essayez avec uid=1
    Future.delayed(Duration(seconds: 3), () {
      if (_remoteUid == null && mounted) {
        printVm("⚠️ remoteUid toujours null, tentative avec uid=1");
        setState(() {
          _remoteUid = 1; // Essayez avec l'UID probable de l'hôte
        });
      }
    });
    _setupCamera();
    _initAgora();

    _setupFirestoreListeners();
    _setupLikesListener(); // ← AJOUTEZ CETTE LIGNE
    _fetchHostData();
    _initializeTrialSystem();
    _setupFreeAccess();

    // if (widget.isHost) {
    //   _startPaymentTimer();
    // }

    if (widget.isInvited) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // _showJoinOptions();
      });
    }

    _setupTypingListener();
  }


  Future<void> _removeUserFromSpectators() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId != null && !widget.isHost && !_isParticipant) {
        await _firestore.collection('lives').doc(widget.liveId).update({
          'spectators': FieldValue.arrayRemove([currentUserId]),
          'viewerCount': FieldValue.increment(-1),
        });
        printVm("✅ Utilisateur retiré des spectateurs");
      }
    } catch (e) {
      printVm("❌ Erreur retrait des spectateurs: $e");
    }
  }
// Modifiez la méthode _onTap pour ignorer la position du tap
  void _onTap(TapDownDetails details) {
    _sendLike();
    // NE PAS appeler _addLikeEffect ici - les effets viennent maintenant de Firestore
  }

// Méthode pour envoyer le like (visible par tous)
  void _sendLike() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Envoyer le like à Firestore (visible par tous les spectateurs)
        await _firestore.collection('live_likes').add({
          'liveId': widget.liveId,
          'userId': user.uid,
          'username': authProvider.loginUserData.pseudo ?? 'Utilisateur',
          'userImage': authProvider.loginUserData.imageUrl ?? '',
          'timestamp': DateTime.now(),
        });

        // Optionnel: Mettre à jour le compteur de likes
        await _firestore.collection('lives').doc(widget.liveId).update({
          'likeCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      printVm("❌ Erreur envoi like partagé: $e");
    }
  }

// Modifiez la méthode pour construire les effets
  List<Widget> _buildTikTokLikeEffects() {
    return _likeEffects.map((effect) {
      return TikTokLikeEffect(
        effect: effect,
        key: ValueKey(effect.id),
      );
    }).toList();
  }

  // ==================== ACCÈS LIBRE POUR HÔTE/PARTICIPANTS/ADMIN ====================

  bool _shouldSkipTrial() {
    final currentUserId = _auth.currentUser?.uid;
    return widget.isHost ||
        _isParticipant ||
        authProvider.loginUserData.role == UserRole.ADM.name ||
        _participants.contains(currentUserId);
  }

  Future<void> _grantFreeAccess() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore.collection('lives').doc(widget.liveId).update({
        'userWatchTime.$currentUserId': 999,
      });

      setState(() {
        _remainingTrialMinutes = 999;
        _remainingTrialSeconds = 0;
      });

      _removeRestrictions();
    } catch (e) {
      printVm("❌ Erreur accord accès libre: $e");
    }
  }

  void _setupFreeAccess() {
    if (_shouldSkipTrial()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _grantFreeAccess();
      });
    }
  }

  // ==================== SYSTÈME TEMPS VISIONNAGE ====================

  void _initializeTrialSystem() async {
    if (!widget.postLive.isPaidLive || _shouldSkipTrial()) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final liveDoc = await _firestore.collection('lives').doc(widget.liveId).get();
      if (liveDoc.exists) {
        final data = liveDoc.data()!;
        final userWatchTime = Map<String, dynamic>.from(data['userWatchTime'] ?? {});
        int userRemainingTime = userWatchTime[currentUserId] ?? widget.postLive.freeTrialMinutes;

        setState(() {
          _remainingTrialMinutes = userRemainingTime;
          _remainingTrialSeconds = 0;
        });

        _startTrialTimer();
      }
    } catch (e) {
      printVm("❌ Erreur initialisation système essai: $e");
    }
  }

  void _startTrialTimer() {
    if (_shouldSkipTrial()) return;

    _trialTimer?.cancel();
    _trialTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        if (_remainingTrialSeconds > 0) {
          _remainingTrialSeconds--;
        } else {
          if (_remainingTrialMinutes > 0) {
            _remainingTrialMinutes--;
            _remainingTrialSeconds = 59;
          } else {
            _onTrialTimeExpired();
            timer.cancel();
          }
        }
      });

      if (timer.tick % 30 == 0) {
        _updateUserWatchTime();
      }
    });
  }

  void _onTrialTimeExpired() {
    if (_shouldSkipTrial()) return;

    _applyPostTrialRestrictions();
    setState(() {
      _showTrialOverlay = true;
    });

    if (widget.postLive.showPaymentModalAfterTrial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPaymentModal();
      });
    }
  }

  void _applyPostTrialRestrictions() {
    if (!_isInitialized) return;
    switch (widget.postLive.audioBehaviorAfterTrial) {
      case 'mute':
        _engine.muteAllRemoteAudioStreams(true);
        setState(() => _isAudioRestricted = true);
        break;
      case 'reduce':
        _engine.adjustPlaybackSignalVolume(widget.postLive.audioReductionPercent);
        setState(() => _isAudioRestricted = true);
        break;
      case 'keep':
        break;
    }

    if (widget.postLive.blurVideoAfterTrial) {
      setState(() => _isVideoBlurred = true);
    }
  }

  void _removeRestrictions() {
    if (!_isInitialized) return;
    _engine.muteAllRemoteAudioStreams(false);
    _engine.adjustPlaybackSignalVolume(100);
    setState(() {
      _isAudioRestricted = false;
      _isVideoBlurred = false;
      _showTrialOverlay = false;
    });
  }

  Future<void> _updateUserWatchTime() async {
    if (!widget.postLive.isPaidLive) return;
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final totalSeconds = (_remainingTrialMinutes * 60) + _remainingTrialSeconds;
      await _firestore.collection('lives').doc(widget.liveId).update({
        'userWatchTime.$currentUserId': totalSeconds ~/ 60,
      });
    } catch (e) {
      printVm("❌ Erreur mise à jour temps visionnage: $e");
    }
  }

  // ==================== SYSTÈME DE PAIEMENT CORRIGÉ ====================

  void _showPaymentModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentRequiredDialog(
        live: widget.postLive,
        onPayment: _processParticipationPayment,
        onLeave: () {
          Navigator.pop(context);
          _leaveLive();
        },
      ),
    );
  }

  Future<void> _processParticipationPayment() async {
    try {
      final amount = widget.postLive.participationFee;
      final userProvider = context.read<UserAuthProvider>();

      if (userProvider.loginUserData!.votre_solde_principal! < amount) {
        _showInsufficientBalanceDialog();
        return;
      }

      final paymentSuccess = await userProvider.deductFromBalance(context, amount);

      if (paymentSuccess) {
        final hostShare = amount * 0.7;

        // CORRECTION : Distribution correcte des fonds
        await _firestore.collection('lives').doc(widget.liveId).update({
          'paidParticipationTotal': FieldValue.increment(hostShare),
        });

        if(userProvider.loginUserData!.codeParrain!=null){
          final appShare = amount * 0.25;
          userProvider.incrementAppGain(appShare);
          userProvider.ajouterCadeauCommissionParrain(codeParrainage: userProvider.loginUserData!.codeParrain!, montant: amount);
          userProvider.ajouterCommissionParrainViaUserId(userId: widget.postLive.hostId!, montant: amount);

        }else{
          final appShare = amount * 0.75;
          userProvider.incrementAppGain(appShare);
          userProvider.ajouterCommissionParrainViaUserId(userId: widget.postLive.hostId!, montant: amount);

        }


        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId != null) {
          await _firestore.collection('lives').doc(widget.liveId).update({
            'userWatchTime.$currentUserId': 999,
          });
        }

        _removeRestrictions();
        setState(() {
          _remainingTrialMinutes = 999;
          _remainingTrialSeconds = 0;
        });

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accès au live activé !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      printVm("❌ Erreur paiement participation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du paiement'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Solde insuffisant', style: TextStyle(color: Colors.white)),
        content: Text('Votre solde est insuffisant. Voulez-vous recharger?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Plus tard', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen()));
            },
            child: Text('Recharger', style: TextStyle(color: Color(0xFFF9A825))),
          ),
        ],
      ),
    );
  }

  // ==================== GESTION AGORA ====================

  Future<void> _setupCamera() async {
    try {
      _numberOfCameras = 2;
    } catch (e) {
      printVm("❌ Erreur configuration caméra: $e");
    }
  }

  Future<void> _initAgora() async {
    try {
      printVm("🔊 Demande des permissions Agora...");
      await [Permission.microphone, Permission.camera].request();

      printVm("🚀 Création du moteur Agora...");
      _engine = createAgoraRtcEngine();

      await _engine.initialize(RtcEngineContext(
        appId: "957063f627aa471581a52d4160f7c054",
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // Configuration des handlers
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            printVm("✅ Rejoint le canal avec succès - UID: ${connection.localUid}");
            setState(() => _localUserJoined = true);
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            printVm("👤 Utilisateur rejoint: $remoteUid");
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            printVm("👋 Utilisateur parti: $remoteUid");
            setState(() => _remoteUid = null);
          },
          onCameraReady: () {
            printVm("📷 Caméra prête");
          },
          onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
            printVm("📹 État vidéo UID $remoteUid: $state");
          },
        ),
      );

      await _engine.enableVideo();
      printVm("Live premium : ${widget.postLive.toMap()}");
      printVm("Live premium : ${_isLivePremium}");

      // 🔥 CONFIGURATION SELON TYPE DE LIVE (PREMIUM OU STANDARD)
      final isPremium = _isLivePremium; // Utilise la durée du live

      // Configuration latence
      final latencyConfig = isPremium
          ? AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency
          : AudienceLatencyLevelType.audienceLatencyLevelLowLatency;

      // Configuration vidéo
      _videoConfig = VideoEncoderConfiguration(
        dimensions: isPremium
            ? const VideoDimensions(width: 1280, height: 720)  // HD pour live premium
            : const VideoDimensions(width: 640, height: 360), // SD pour live standard
        frameRate: isPremium ? 30 : 15,
        bitrate: isPremium ? 4000 : 1000,
        minBitrate: isPremium ? 2000 : 500,
        orientationMode: OrientationMode.orientationModeAdaptive,
        degradationPreference: isPremium
            ? DegradationPreference.maintainQuality
            : DegradationPreference.maintainFramerate,
        mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
      );

      await _engine.setVideoEncoderConfiguration(_videoConfig);

      final role = widget.isHost || _isParticipant
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience;

      await _engine.setClientRole(role: role);

      if (widget.isHost || _isParticipant) {
        await _engine.startPreview();
      }

      final uid = 0;
      final token = await _getAgoraToken(
        channelName: widget.liveId,
        uid: uid,
        isHost: widget.isHost || _isParticipant,
      );

      if (token == null) {
        throw Exception("Impossible de générer un token Agora");
      }

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
          audienceLatencyLevel: latencyConfig, // 🔥 Latence configurée
        ),
      );

      _joinAsSpectator();
      setState(() => _isInitialized = true);

      // Log de configuration
      printVm("✅ Agora initialisé - Live: ${isPremium ? 'PREMIUM' : 'STANDARD'}");
      printVm("   📹 Résolution: ${isPremium ? '1280x720 (HD)' : '640x360 (SD)'}");
      printVm("   ⚡ Latence: ${isPremium ? 'Ultra Low (500ms)' : 'Low (2000ms)'}");
      printVm("   🎯 Hôte: ${_isHostPremium ? 'PREMIUM' : 'STANDARD'}");
      printVm("   ⏰ Durée: ${widget.postLive.safeLiveDurationMinutes} minutes");

    } catch (e) {
      printVm("💥 Erreur lors de l'initialisation Agora: $e");
    }
  }

  Future<void> _initAgora2() async {
    try {
      printVm("🔊 Demande des permissions Agora...");
      await [Permission.microphone, Permission.camera].request();

      printVm("🚀 Création du moteur Agora...");
      _engine = createAgoraRtcEngine();

      await _engine.initialize(RtcEngineContext(
        appId: "957063f627aa471581a52d4160f7c054",
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // Configuration des handlers
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            printVm("✅ Rejoint le canal avec succès - UID: ${connection.localUid}");
            setState(() => _localUserJoined = true);
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            printVm("👤 Utilisateur rejoint: $remoteUid");
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            printVm("👋 Utilisateur parti: $remoteUid");
            setState(() => _remoteUid = null);
          },
          onCameraReady: () {
            printVm("📷 Caméra prête");
          },
          // onCameraFocusAreaChanged: () {
          //   printVm("🔍 Zone de focus caméra changée");
          // },
          onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
            printVm("📹 État vidéo UID $remoteUid: $state");
          },
        ),
      );

      await _engine.enableVideo();

      // Configuration vidéo améliorée
      _videoConfig = const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 360),
        frameRate: 15,
        bitrate: 0,
        minBitrate: 0,
        orientationMode: OrientationMode.orientationModeAdaptive,
        degradationPreference: DegradationPreference.maintainQuality,
        mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
      );

      await _engine.setVideoEncoderConfiguration(_videoConfig);

      final role = widget.isHost || _isParticipant
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience;

      await _engine.setClientRole(role: role);

      if (widget.isHost || _isParticipant) {
        await _engine.startPreview();
      }

      final uid = 0;
      final token = await _getAgoraToken(
        channelName: widget.liveId,
        uid: uid,
        isHost: widget.isHost || _isParticipant,
      );

      if (token == null) {
        throw Exception("Impossible de générer un token Agora");
      }

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
          audienceLatencyLevel: AudienceLatencyLevelType
              .audienceLatencyLevelLowLatency, // Coût réduit
        ),
      );
      _joinAsSpectator();
      setState(() => _isInitialized = true);
    } catch (e) {
      printVm("💥 Erreur lors de l'initialisation Agora: $e");
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
      printVm("❌ Erreur récupération token Agora: $e");
      return null;
    }
  }

  // ==================== PARTAGE D'ÉCRAN ====================

  Future<void> _toggleScreenSharing() async {
    await _confirmAction(
      _isScreenSharing ? "arrêter le partage d'écran" : "partager l'écran",
          () async {
        if (!(widget.isHost || _isParticipant)) return;

        try {
          if (_isScreenSharing) {
            await _stopScreenSharing();
          } else {
            await _startScreenSharing();
          }
        } catch (e) {
          printVm("❌ Erreur partage écran: $e");
        }
      },
    );
  }

  Future<void> _startScreenSharing() async {
    try {
      final parameters = ScreenCaptureParameters2(
        captureAudio: true,
        captureVideo: true,
      );

      await _engine.startScreenCapture(parameters);
      await _engine.updateChannelMediaOptions(ChannelMediaOptions(
        publishScreenCaptureVideo: true,
        publishScreenCaptureAudio: true,
        publishCameraTrack: false,
      ));

      setState(() => _isScreenSharing = true);
      await _updateScreenSharingState(isSharing: true, sharerId: _auth.currentUser!.uid);
    } catch (e) {
      printVm("❌ Erreur démarrage partage écran: $e");
    }
  }

  Future<void> _stopScreenSharing() async {
    try {
      await _engine.stopScreenCapture();
      await _engine.updateChannelMediaOptions(ChannelMediaOptions(
        publishScreenCaptureVideo: false,
        publishScreenCaptureAudio: false,
        publishCameraTrack: true,
      ));

      setState(() => _isScreenSharing = false);
      await _updateScreenSharingState(isSharing: false, sharerId: null);
    } catch (e) {
      printVm("❌ Erreur arrêt partage écran: $e");
    }
  }

  Future<void> _updateScreenSharingState({required bool isSharing, String? sharerId}) async {
    try {
      await _firestore.collection('lives').doc(widget.liveId).update({
        'isScreenSharing': isSharing,
        'screenSharerId': sharerId,
        'lastScreenSharingUpdate': DateTime.now(),
      });
    } catch (e) {
      printVm("❌ Erreur mise à jour état partage écran: $e");
    }
  }

  // ==================== CONTRÔLES AVEC CONFIRMATION ====================

  Future<void> _confirmAction(String action, Function onConfirm) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Confirmer $action', style: TextStyle(color: Colors.white)),
        content: Text('Voulez-vous vraiment $action ?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Confirmer', style: TextStyle(color: Color(0xFFF9A825))),
          ),
        ],
      ),
    );

    if (result == true) {
      onConfirm();
    }
  }

  Future<void> _toggleMicrophone() async {
    await _confirmAction(
      _isMicrophoneMuted ? "activer le micro" : "désactiver le micro",
          () async {
        if (!(widget.isHost || _isParticipant)) return;

        try {
          await _engine.muteLocalAudioStream(!_isMicrophoneMuted);
          setState(() => _isMicrophoneMuted = !_isMicrophoneMuted);
        } catch (e) {
          printVm("❌ Erreur contrôle micro: $e");
        }
      },
    );
  }

  Future<void> _switchCamera() async {
    await _confirmAction(
      "changer de caméra",
          () async {
        try {
          if (_numberOfCameras < 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Une seule caméra disponible')),
            );
            return;
          }

          await _engine.switchCamera();
          setState(() => _isFrontCamera = !_isFrontCamera);
        } catch (e) {
          printVm("❌ Erreur basculement caméra: $e");
        }
      },
    );
  }


  void _setupLikesListener() {
    _likesSubscription = _firestore
        .collection('live_likes')
        .where('liveId', isEqualTo: widget.liveId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data()!;
          final baseId = doc.doc.id;
          // Affiche 5 à 8 cœurs décalés dans le temps pour chaque like reçu
          final count = 5 + Random().nextInt(4);
          for (int i = 0; i < count; i++) {
            Future.delayed(Duration(milliseconds: i * 110), () {
              if (!mounted) return;
              final effectId = '${baseId}_$i';
              final effect = LikeEffect(
                id: effectId,
                userId: data['userId'] as String? ?? '',
                username: data['username'] as String? ?? '',
                userImage: data['userImage'] as String? ?? '',
                timestamp: (data['timestamp'] as Timestamp).toDate(),
              );
              setState(() => _likeEffects.add(effect));
              Future.delayed(const Duration(milliseconds: 1800), () {
                if (mounted) setState(() => _likeEffects.removeWhere((e) => e.id == effectId));
              });
            });
          }
        }
      }
    });
  }




  void _sendComment(String message, {String type = 'text', String? giftId}) {
    _stopTyping();

    try {
      User? user = _auth.currentUser;
      if (user != null && message.isNotEmpty) {
        final words = message.split(' ');
        if (words.length > 20) {
          message = words.take(20).join(' ') + '...';
        }

        _firestore.collection('livecomments').add({
          'liveId': widget.liveId,
          'userId': user.uid,
          'username': authProvider.loginUserData.pseudo ?? 'Utilisateur',
          'userImage': authProvider.loginUserData.imageUrl ?? '',
          'message': message,
          'timestamp': DateTime.now(),
          'type': type,
          'giftId': giftId,
        });
      }
    } catch (e) {
      printVm("❌ Erreur envoi commentaire: $e");
    }
  }

  void _sendGift(Gift gift) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final coinsAmount = gift.price.toInt();
      final senderRef = _firestore.collection('Users').doc(currentUser.uid);
      final hostRef = _firestore.collection('Users').doc(widget.postLive.hostId);
      final liveRef = _firestore.collection('lives').doc(widget.liveId);
      final appDataRef = _firestore.collection('AppData').doc(authProvider.appDefaultData.id);
      final now = DateTime.now().millisecondsSinceEpoch;

      // Vérifier le solde
      final senderDoc = await senderRef.get();
      final senderCoins = (senderDoc.data()?['giftCoinsBalance'] ?? 0) as int;
      if (senderCoins < coinsAmount) {
        _showInsufficientCoinsDialog();
        return;
      }

      final hostDoc = await hostRef.get();
      final hostCodeParrain = hostDoc.data()?['code_parrain'] as String?;
      final hostName = hostDoc.data()?['pseudo'] as String? ?? '';
      final me = authProvider.loginUserData;

      // Répartition :
      //   host a un parrain → host=75%, parrain=5%, app=~20%
      //   host sans parrain → host=70%, app=~30%
      final bool hasParrain = hostCodeParrain != null && hostCodeParrain.isNotEmpty;
      final int hostCoins = hasParrain
          ? (coinsAmount * 0.75).floor()
          : (coinsAmount * 0.70).floor();
      final int parrainCoins = hasParrain ? (coinsAmount * 0.05).floor() : 0;
      final int appCoins = coinsAmount - hostCoins - parrainCoins;

      await _firestore.runTransaction((tx) async {
        // 1. Débiter l'expéditeur
        tx.update(senderRef, {
          'giftCoinsBalance': FieldValue.increment(-coinsAmount),
          'totalGiftCoinsSpent': FieldValue.increment(coinsAmount),
        });
        // 2. Créditer le host
        tx.update(hostRef, {
          'giftCoinsBalance': FieldValue.increment(hostCoins),
          'totalCoinsEarnedFromGifts': FieldValue.increment(hostCoins),
        });
        // 3. Créditer l'application
        tx.update(appDataRef, {'solde_gain_pieces': FieldValue.increment(appCoins)});
        // 4. Mettre à jour le live
        tx.update(liveRef, {
          'giftCoinsTotal': FieldValue.increment(coinsAmount),
          'giftCount': FieldValue.increment(1),
          'giftLeaderboard.${currentUser.uid}': FieldValue.increment(coinsAmount),
          'giftLeaderboardMeta.${currentUser.uid}': {
            'pseudo': me.pseudo ?? '',
            'imageUrl': me.imageUrl ?? '',
          },
        });
        // 5. Transaction expéditeur (débit)
        final txSenderRef = _firestore.collection('TransactionSoldes').doc();
        tx.set(txSenderRef, (TransactionSolde()
          ..id = txSenderRef.id
          ..user_id = currentUser.uid
          ..type = TypeTransaction.CADEAU_PIECES.name
          ..statut = StatutTransaction.VALIDER.name
          ..description = 'Cadeau ${gift.icon} ${gift.name} ($coinsAmount pcs) en live à @$hostName'
          ..montant = coinsAmount.toDouble()
          ..methode_paiement = 'pieces'
          ..createdAt = now
          ..updatedAt = now).toJson());
        // 6. Transaction host (crédit)
        final txHostRef = _firestore.collection('TransactionSoldes').doc();
        tx.set(txHostRef, (TransactionSolde()
          ..id = txHostRef.id
          ..user_id = widget.postLive.hostId
          ..type = TypeTransaction.CADEAU_PIECES_RECU.name
          ..statut = StatutTransaction.VALIDER.name
          ..description = 'Cadeau ${gift.icon} reçu de @${me.pseudo ?? ''} en live ($hostCoins pcs)'
          ..montant = hostCoins.toDouble()
          ..methode_paiement = 'pieces'
          ..createdAt = now
          ..updatedAt = now).toJson());
      });

      // Paiement parrain en arrière-plan (avec sa propre transaction)
      if (hasParrain && parrainCoins > 0) {
        _payCommissionWithTx(
          codeParrain: hostCodeParrain!,
          coins: parrainCoins,
          sourceDescription: 'Commission parrainage sur cadeau live de $coinsAmount pcs',
        );
      }

      _sendComment(
        'a envoyé ${gift.name} ${gift.icon} ($coinsAmount pcs)',
        type: 'gift',
        giftId: gift.id,
      );

      setState(() {
        _giftEffects.add(GiftEffect(
          id: DateTime.now().millisecondsSinceEpoch,
          gift: gift,
          x: Random().nextDouble() * 0.6 + 0.2,
        ));
        _showGiftPanel = false;
      });
    } catch (e) {
      printVm('❌ Erreur envoi cadeau: $e');
    }
  }

  void _payCommissionWithTx({
    required String codeParrain,
    required int coins,
    required String sourceDescription,
  }) {
    Future.microtask(() async {
      try {
        final q = await _firestore
            .collection('Users')
            .where('code_parrainage', isEqualTo: codeParrain)
            .limit(1)
            .get();
        if (q.docs.isEmpty) return;
        final parrainDoc = q.docs.first;
        final parrainId = parrainDoc.id;
        final now = DateTime.now().millisecondsSinceEpoch;

        await _firestore.runTransaction((tx) async {
          tx.update(parrainDoc.reference, {
            'giftCoinsBalance': FieldValue.increment(coins),
            'totalCoinsEarnedFromSponsorship': FieldValue.increment(coins),
          });
          final txRef = _firestore.collection('TransactionSoldes').doc();
          tx.set(txRef, (TransactionSolde()
            ..id = txRef.id
            ..user_id = parrainId
            ..type = TypeTransaction.GAIN_PIECES.name
            ..statut = StatutTransaction.VALIDER.name
            ..description = '$sourceDescription ($coins pcs)'
            ..montant = coins.toDouble()
            ..methode_paiement = 'commission_parrainage'
            ..createdAt = now
            ..updatedAt = now).toJson());
        });
      } catch (_) {}
    });
  }

  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Pièces insuffisantes', style: TextStyle(color: Colors.white)),
        content: Text('Vous n\'avez pas assez de pièces pour envoyer ce cadeau.',
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

  // ==================== GESTION FIREBASE STREAM ====================

  void _setupFirestoreListeners() {
    _liveSubscription = _firestore.collection('lives').doc(widget.liveId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        // Leaderboard donateurs
        final leaderboardMap = Map<String, dynamic>.from(data['giftLeaderboard'] ?? {});
        final metaMap = Map<String, dynamic>.from(data['giftLeaderboardMeta'] ?? {});
        final sortedEntries = leaderboardMap.entries.toList()
          ..sort((a, b) => ((b.value as num?)?.toInt() ?? 0).compareTo((a.value as num?)?.toInt() ?? 0));
        final topDonors = sortedEntries.take(3).map((e) {
          final meta = metaMap[e.key] as Map<String, dynamic>? ?? {};
          return {
            'userId': e.key,
            'pseudo': meta['pseudo'] ?? '',
            'imageUrl': meta['imageUrl'] ?? '',
            'totalCoins': (e.value as num?)?.toInt() ?? 0,
          };
        }).toList();

        setState(() {
          _viewerCount = List<String>.from(data['spectators'] ?? []).length;
          _giftCount = data['giftCount'] ?? 0;
          _giftTotal = (data['giftTotal'] ?? 0).toDouble();
          _giftCoinsTotal = (data['giftCoinsTotal'] as num?)?.toInt() ?? 0;
          _participants = List<String>.from(data['participants'] ?? []);
          _totalviewerCount = List<String>.from(data['totalspectateurs'] ?? []).length;
          _spectators = List<String>.from(data['spectators'] ?? []);
          _likeCount = data['likeCount'] ?? 0;
          _shareCount = data['shareCount'] ?? 0;
          _paidParticipationTotal = (data['paidParticipationTotal'] ?? 0).toDouble();
          _isLivePaused = data['isPaused'] == true;
          _pauseMessage = data['pauseMessage'] as String?;
          _topDonors = topDonors;
          final currentUserId = _auth.currentUser?.uid;
          _isParticipant = currentUserId != null && _participants.contains(currentUserId);
        });
      }

      // Muter les flux audio si le live est en pause
      if (_isLivePaused && !widget.isHost) {
        _engine.muteAllRemoteAudioStreams(true);
      } else if (!_isLivePaused && !widget.isHost) {
        _engine.muteAllRemoteAudioStreams(false);
      }

    });

    _commentsSubscription = _firestore
        .collection('livecomments')
        .where('liveId', isEqualTo: widget.liveId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _comments = snapshot.docs.map((doc) => LiveComment.fromMap(doc.data())).toList();
      });
    });

    _usersSubscription = _firestore
        .collection('lives')
        .doc(widget.liveId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        setState(() {
          _participants = List<String>.from(data['participants'] ?? []);
          _spectators = List<String>.from(data['spectators'] ?? []);
        });
        _fetchAllUsers();
      }
    });
  }

  void _setupTypingListener() {
    _typingSubscription = _firestore
        .collection('live_typing')
        .where('liveId', isEqualTo: widget.liveId)
        .snapshots()
        .listen((snapshot) {
      Map<String, dynamic> newTypingUsers = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['timestamp'] != null) {
          final timestamp = (data['timestamp'] as Timestamp).toDate();
          if (DateTime.now().difference(timestamp).inSeconds < 3) {
            newTypingUsers[data['userId']] = data['username'];
          }
        }
      }
      setState(() => _typingUsers = newTypingUsers);
    });
  }

  void _startTyping() {
    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection('live_typing').doc(user.uid).set({
        'liveId': widget.liveId,
        'userId': user.uid,
        'username': authProvider.loginUserData.pseudo ?? 'Utilisateur',
        'timestamp': DateTime.now(),
      });
    }
  }

  void _stopTyping() {
    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection('live_typing').doc(user.uid).delete();
    }
  }

  // ==================== GESTION UTILISATEURS ====================

  Future<void> _fetchHostData() async {
    try {
      final hostDoc = await _firestore.collection('Users').doc(widget.postLive.hostId).get();
      if (hostDoc.exists) {
        setState(() {
          _hostData = UserData.fromJson(hostDoc.data()!);
        });
      }
    } catch (e) {
      printVm("❌ Erreur récupération données hôte: $e");
    }
  }

  void _toggleUsersPanel() {
    setState(() => _showUsersPanel = !_showUsersPanel);
    if (_showUsersPanel) {
      _fetchAllUsers();
    }
  }

  void _fetchAllUsers() async {
    try {
      final allUserIds = {..._participants, ..._spectators, widget.postLive.hostId!};
      List<UserData> users = [];

      for (final userId in allUserIds) {
        final userDoc = await _firestore.collection('Users').doc(userId).get();
        if (userDoc.exists) {
          users.add(UserData.fromJson(userDoc.data()!));
        }
      }

      setState(() => _allUsers = users);
    } catch (e) {
      printVm("❌ Erreur récupération utilisateurs: $e");
    }
  }

  // ==================== GESTION TEXTE ÉPINGLÉ ====================

  void _togglePinnedTextEditor() {
    setState(() {
      _showPinnedTextEditor = !_showPinnedTextEditor;
      if (_showPinnedTextEditor) {
        _pinnedTextController.text = widget.postLive.pinnedText ?? '';
      }
    });
  }

  Future<void> _updatePinnedText() async {
    try {
      if (_pinnedTextController.text.isEmpty) {
        await _firestore.collection('lives').doc(widget.liveId).update({
          'pinnedText': FieldValue.delete(),
        });
      } else {
        await _firestore.collection('lives').doc(widget.liveId).update({
          'pinnedText': _pinnedTextController.text,
        });
      }

      setState(() => _showPinnedTextEditor = false);
    } catch (e) {
      printVm("❌ Erreur mise à jour texte épinglé: $e");
    }
  }

  // ==================== GESTION REJOINDRE LIVE ====================

  Future<void> _joinAsParticipant() async {
    try {
      final authProvider = context.read<UserAuthProvider>();
      final liveProvider = context.read<LiveProvider>();

      if (authProvider.loginUserData.role == UserRole.ADM.name) {
        await liveProvider.joinAsParticipant(widget.liveId, authProvider.userId!);
        setState(() => _isParticipant = true);
        await _reinitializeAgora();
        await _grantFreeAccess();
        return;
      }

      if (authProvider.loginUserData!.votre_solde_principal! < 100) {
        _showPaymentRequiredDialog();
        return;
      }

      final paymentSuccess = await authProvider.deductFromBalance(context, 100.0);

      if (paymentSuccess) {
        authProvider.incrementAppGain(100);
        await liveProvider.joinAsParticipant(widget.liveId, authProvider.userId!);
        setState(() => _isParticipant = true);
        await _reinitializeAgora();
        await _grantFreeAccess();
      }
    } catch (e) {
      printVm("❌ Erreur rejoindre comme participant: $e");
    }
  }

  Future<void> _joinAsSpectator() async {
    try {
      final liveProvider = context.read<LiveProvider>();

      if (authProvider.loginUserData.role == UserRole.ADM.name) {
        // await liveProvider.joinAsSpectator(widget.liveId, _auth.currentUser!.uid);
        await _grantFreeAccess();
        // return;
      }

      await liveProvider.joinAsSpectator(widget.liveId, _auth.currentUser!.uid);
    } catch (e) {
      printVm("❌ Erreur rejoindre comme spectateur: $e");
    }
  }

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

  // ==================== GESTION FIN DE LIVE ====================

  // void _startPaymentTimer() {
  //   _paymentWarningTimer = Timer(const Duration(minutes: 30), () {
  //     _requestPayment();
  //   });
  // }
  //
  // void _requestPayment() async {
  //   try {
  //     await _firestore.collection('lives').doc(widget.liveId).update({
  //       'paymentRequired': true,
  //       'paymentRequestTime': DateTime.now(),
  //     });
  //
  //     setState(() => _showPaymentWarning = true);
  //   } catch (e) {
  //     printVm("❌ Erreur demande paiement: $e");
  //   }
  // }
  //
  // void _handlePayment() async {
  //   try {
  //     final userProvider = context.read<UserAuthProvider>();
  //     bool paymentSuccess = await userProvider.deductFromBalance(context, 100.0);
  //
  //     if (paymentSuccess) {
  //       userProvider.incrementAppGain(100);
  //
  //       await _firestore.collection('lives').doc(widget.liveId).update({
  //         'paymentRequired': false,
  //         'paymentRequestTime': null,
  //       });
  //
  //       setState(() => _showPaymentWarning = false);
  //       _startPaymentTimer();
  //     } else {
  //       _endLive();
  //     }
  //   } catch (e) {
  //     printVm("❌ Erreur traitement paiement: $e");
  //   }
  // }

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

  void _endLive() async {
    try {
      await _firestore.collection('lives').doc(widget.liveId).update({
        'isLive': false,
        'endTime': DateTime.now(),
      });

      await _engine.leaveChannel();
      await _engine.release();

      if (widget.isHost && mounted) {
        _showLiveEndStats();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      printVm("❌ Erreur fin du live: $e");
      if (mounted) Navigator.pop(context);
    }
  }

  void _showLiveEndStats() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Color(0xFFF9A825).withOpacity(0.4), width: 1.5),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: Color(0xFFF9A825).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.live_tv, color: Color(0xFFF9A825), size: 30),
              ),
              const SizedBox(height: 16),
              const Text('Live terminé 🎉',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 4),
              Text('Merci à tous vos spectateurs !',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 24),
              _buildStatRow(Icons.stars_rounded, 'Pièces reçues', '$_giftCoinsTotal pcs', const Color(0xFFF9A825)),
              const SizedBox(height: 12),
              _buildStatRow(Icons.favorite_rounded, 'Likes', '$_likeCount', Colors.pinkAccent),
              const SizedBox(height: 12),
              _buildStatRow(Icons.people_rounded, 'Spectateurs au total', '$_totalviewerCount', Colors.blueAccent),
              const SizedBox(height: 12),
              _buildStatRow(Icons.share_rounded, 'Partages', '$_shareCount', Colors.greenAccent),
              if (_topDonors.isNotEmpty) ...[
                const SizedBox(height: 16),
                Divider(color: Colors.white12),
                const SizedBox(height: 8),
                Text('Top donateurs', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._topDonors.asMap().entries.map((e) {
                  final idx = e.key;
                  final donor = e.value;
                  final medals = ['🥇', '🥈', '🥉'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(medals[idx], style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(donor['pseudo'] as String? ?? '', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${donor['totalCoins']} pcs', style: TextStyle(color: Color(0xFFF9A825), fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF9A825),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Fermer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const Spacer(),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _leaveLive() async {
    try {
      if (!widget.isHost) {
        await _firestore.collection('lives').doc(widget.liveId).update({
          'viewerCount': FieldValue.increment(-1),
          'spectators': FieldValue.arrayRemove([_auth.currentUser!.uid]),
        });
      }
      Navigator.pop(context);
    } catch (e) {
      printVm("❌ Erreur sortie live: $e");
    }
  }

  Future<void> _reinitializeAgora() async {
    try {
      await _engine.leaveChannel();
      await _engine.release();
      await _initAgora();
    } catch (e) {
      printVm("❌ Erreur réinitialisation Agora: $e");
    }
  }

  void _shareLive() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Partager ce live', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Text(widget.postLive.title, style: const TextStyle(color: Colors.white54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 20),
            // Option 1 : partager dans un chat
            ListTile(
              onTap: () {
                Navigator.pop(ctx);
                _shareLiveToChat();
              },
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Color(0xFFF9A825).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFF9A825), size: 22),
              ),
              title: const Text('Envoyer dans un chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: const Text('Conversations ou groupes', style: TextStyle(color: Colors.white54, fontSize: 12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            const SizedBox(height: 10),
            // Option 2 : lien externe
            ListTile(
              onTap: () {
                Navigator.pop(ctx);
                _shareLiveExternally();
              },
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.ios_share_rounded, color: Colors.blueAccent, size: 22),
              ),
              title: const Text('Partager le lien', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: const Text('WhatsApp, réseaux sociaux...', style: TextStyle(color: Colors.white54, fontSize: 12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ],
        ),
      ),
    );
  }

  void _shareLiveExternally() {
    final AppLinkService appLinkService = AppLinkService();
    appLinkService.shareContent(
      type: AppLinkType.live,
      id: widget.liveId,
      message: "🎥🔥 ${widget.postLive.title}",
      mediaUrl: widget.postLive.hostImage ?? '',
    );
    _incrementShareCount();
  }

  void _shareLiveToChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GenericShareSheet(
        itemId: widget.liveId,
        itemType: 'live',
        title: widget.postLive.title,
        subtitle: '@${widget.postLive.hostName ?? ''}',
        thumbnail: widget.postLive.hostImage ?? '',
        icon: Icons.live_tv_rounded,
      ),
    );
    _incrementShareCount();
  }

  void _incrementShareCount() async {
    try {
      await _firestore.collection('lives').doc(widget.liveId).update({
        'shareCount': FieldValue.increment(1),
      });
    } catch (e) {
      printVm("❌ Erreur incrémentation partages: $e");
    }
  }

  // ==================== WIDGETS PRINCIPAUX ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTap,
        onDoubleTapDown: _onTap,
        child: Stack(
          children: [
            // VIDÉO PRINCIPALE
            _buildVideoSection(),

            // OVERLAY TEMPS ESSAI
            if (widget.postLive.isPaidLive && _showTrialOverlay && !_shouldSkipTrial())
              _buildTrialOverlay(),

            // BOUTON TOGGLE UI (positionné pour être visible)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: _buildToggleUIButton(),
            ),

            // INTERFACE UTILISATEUR
            if (_showUI) ..._buildUIOverlay(),

            // EFFETS ANIMÉS (au-dessus de tout)
            ..._buildTikTokLikeEffects(),
            ..._buildGiftEffects(),

            // LOADING
            if (!_isInitialized) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }
  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     backgroundColor: Colors.black,
  //     body: GestureDetector(
  //       onTapDown: _onTap,
  //       onDoubleTapDown: _onTap,
  //       child: Stack(
  //         children: [
  //           // VIDÉO PRINCIPALE
  //           _buildVideoSection(),
  //
  //           // OVERLAY TEMPS ESSAI
  //           if (widget.postLive.isPaidLive && _showTrialOverlay && !_shouldSkipTrial())
  //             _buildTrialOverlay(),
  //
  //           // BOUTON TOGGLE UI (positionné pour être visible)
  //           Positioned(
  //             top: MediaQuery.of(context).padding.top + 10,
  //             left: 16,
  //             child: _buildToggleUIButton(),
  //           ),
  //
  //           // INTERFACE UTILISATEUR
  //           if (_showUI) ..._buildUIOverlay(),
  //
  //           // EFFETS ANIMÉS (au-dessus de tout)
  //           ..._buildTikTokLikeEffects(),
  //           ..._buildGiftEffects(),
  //
  //           // LOADING
  //           if (!_isInitialized) _buildLoadingOverlay(),
  //         ],
  //       ),
  //     ),
  //   );
  // }



  List<Widget> _buildUIOverlay() {
    return [
      _buildAppName(),
      _buildHostOverlay(),
      _buildViewerInfo(),
      _buildPinnedTextSection(),
      _buildLeaderboard(),
      _buildCommentsSection(),
      _buildFooter(),
      _buildTypingIndicator(),
      if (_showGiftPanel)
        GiftPanelWidget(
          gifts: _gifts,
          onGiftSelected: _sendGift,
          onClose: () => setState(() => _showGiftPanel = false),
        ),
      if (_showUsersPanel)
        UsersPanelWidget(
          users: _allUsers,
          hostId: widget.postLive.hostId!,
          participants: _participants,
          onClose: () => setState(() => _showUsersPanel = false),
        ),
      if (_showPinnedTextEditor)
        PinnedTextEditorWidget(
          controller: _pinnedTextController,
          onSave: _updatePinnedText,
          onCancel: () => setState(() => _showPinnedTextEditor = false),
        ),
    ];
  }

  Widget _buildLeaderboard() {
    if (_topDonors.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.of(context).padding.top + 185,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _topDonors.asMap().entries.map((e) {
          final idx = e.key;
          final donor = e.value;
          final medals = ['🥇', '🥈', '🥉'];
          final imageUrl = donor['imageUrl'] as String? ?? '';
          return Container(
            margin: EdgeInsets.only(bottom: 5),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFFF9A825).withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(medals[idx], style: TextStyle(fontSize: 12)),
                SizedBox(width: 4),
                if (imageUrl.isNotEmpty) ...[
                  CircleAvatar(backgroundImage: NetworkImage(imageUrl), radius: 9, backgroundColor: Colors.white24),
                  SizedBox(width: 4),
                ],
                Text(
                  donor['pseudo'] as String? ?? '',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 4),
                Text(
                  '${donor['totalCoins']}pcs',
                  style: TextStyle(color: Color(0xFFF9A825), fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  Widget _buildPausedOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0D1A), Color(0xFF1A1430)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFF9A825).withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF9A825).withOpacity(0.4), width: 1.5),
              ),
              child: const Icon(Icons.pause_rounded, size: 44, color: Color(0xFFF9A825)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Live en pause',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              _pauseMessage ?? "L'hôte a mis le live en pause",
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(const Color(0xFFF9A825).withOpacity(0.7)),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Réactivation automatique…', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }
  Widget _buildVideoSection() {
    // Moteur pas encore prêt → écran de chargement
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Color(0xFFF9A825)),
          ),
        ),
      );
    }

    // ⭐ PRIORITÉ : Afficher écran de pause si live en pause
    if (_isLivePaused && !widget.isHost) {
      return _buildPausedOverlay();
    }
    return Stack(
      children: [
        if (_remoteUid != null)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(channelId: widget.liveId),
            ),
          ),
        if (_remoteUid == null)
          const SizedBox.shrink(),


        if (_isVideoBlurred)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),

        if ((widget.isHost || _isParticipant) && !_isScreenSharing)
          Positioned(
            bottom: 100,
            right: 16,
            child: Container(
              width: 120,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
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

        if (_remoteUid == null && !widget.isHost && !_isParticipant)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Live en pause...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildToggleUIButton() {
    return GestureDetector(
      onTap: () => setState(() => _showUI = !_showUI),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Icon(
          _showUI ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: Colors.white70,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildAppName() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            ),
            SizedBox(width: 5),
            Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
            SizedBox(width: 5),
            Text('Afrolook', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildHostOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 50,
      left: 16,
      child: GestureDetector(
        onTap: _showHostDetails,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(widget.hostImage),
                radius: 18,
                backgroundColor: Colors.white24,
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@${_hostData.pseudo ?? widget.hostName}',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  Text(
                    '${_hostData.userAbonnesIds?.length ?? 0} abonnés',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
              if (!widget.isHost) ...[
                SizedBox(width: 10),
                GestureDetector(
                  onTap: () => setState(() => _isFollowing = !_isFollowing),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isFollowing ? Colors.white.withOpacity(0.12) : Color(0xFFF9A825),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _isFollowing ? 'Suivi ✓' : 'Suivre',
                      style: TextStyle(
                        color: _isFollowing ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _showUserDetailsById(String userId) async {
    try {
      // Récupérer les données de l'utilisateur depuis Firestore
      final userDoc = await _firestore.collection('Users').doc(userId).get();

      if (userDoc.exists) {
        // Convertir les données en UserData
        final userData = UserData.fromJson(userDoc.data()!);

        // Récupérer les dimensions de l'écran
        final double width = MediaQuery.of(context).size.width;
        final double height = MediaQuery.of(context).size.height;

        // Appeler la fonction d'affichage des détails
        showUserDetailsModalDialog(userData, width, height, context);

        // Optionnel : Mettre à jour l'état du follow si nécessaire
        // setState(() => _isFollowing = !_isFollowing);
      } else {
        printVm("❌ Utilisateur non trouvé avec l'ID: $userId");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Utilisateur non trouvé'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      printVm("❌ Erreur récupération utilisateur: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des informations'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// ==================== UTILISATION DANS VOTRE CODE ====================

// Exemple 1: Pour afficher les détails de l'hôte
  void _showHostDetails() {
    if (widget.postLive.hostId != null) {
      _showUserDetailsById(widget.postLive.hostId!);
    }
  }
  Widget _buildViewerInfo() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 50,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildInfoChip(icon: Icons.people_rounded, value: '$_viewerCount/$_totalviewerCount'),
          SizedBox(height: 6),
          _buildInfoChip(icon: Icons.favorite_rounded, value: '$_likeCount', color: Colors.pinkAccent),
          SizedBox(height: 6),
          _buildInfoChip(icon: Icons.stars_rounded, value: '$_giftCoinsTotal pcs', color: Color(0xFFF9A825)),
          SizedBox(height: 6),
          GestureDetector(
            onTap: _shareLive,
            child: _buildInfoChip(icon: Icons.share_rounded, value: '$_shareCount', color: Colors.blueAccent),
          ),
          // Timer essai
          if (widget.postLive.isPaidLive && _remainingTrialMinutes < 999 && !_shouldSkipTrial())
            Container(
              margin: EdgeInsets.only(top: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _remainingTrialMinutes < 2 ? Colors.red.withOpacity(0.9) : Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_rounded, color: Colors.white, size: 11),
                  SizedBox(width: 3),
                  Text(
                    '${_remainingTrialMinutes.toString().padLeft(2, '0')}:${_remainingTrialSeconds.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ],
              ),
            ),
          // Badge rôle
          if (_shouldSkipTrial() && widget.postLive.isPaidLive)
            Container(
              margin: EdgeInsets.only(top: 6),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.18),
                border: Border.all(color: Colors.green.withOpacity(0.45)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.isHost ? 'HÔTE' : authProvider.loginUserData.role == UserRole.ADM.name ? 'ADMIN' : 'PARTICIPANT',
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: .8),
              ),
            ),
          // Bouton arrêter
          if (widget.isHost || authProvider.loginUserData.role == UserRole.ADM.name) ...[
            SizedBox(height: 12),
            GestureDetector(
              onTap: _confirmEndLive,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stop_rounded, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text('Arrêter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String value, Color color = Colors.white70}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          SizedBox(width: 4),
          Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildPinnedTextSection() {
    if (widget.postLive.pinnedText == null || widget.postLive.pinnedText!.isEmpty) {
      return SizedBox.shrink();
    }
    return Positioned(
      top: MediaQuery.of(context).padding.top + 120,
      left: 16,
      right: 130,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: Color(0xFFF9A825), width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.postLive.pinnedText!,
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.isHost)
              GestureDetector(
                onTap: _togglePinnedTextEditor,
                child: Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.edit_rounded, color: Colors.white38, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
  bool _showComments = true;

  Widget _buildCommentsSection() {
    final listHeight = MediaQuery.of(context).size.height * 0.30;
    return Positioned(
      bottom: 82,
      left: 10,
      width: MediaQuery.of(context).size.width * 0.68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton texte juste au-dessus de la liste
          GestureDetector(
            onTap: () => setState(() => _showComments = !_showComments),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Text(
                _showComments ? 'Fermer les messages' : 'Afficher les messages',
                style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_showComments) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: listHeight,
              child: ListView.builder(
                controller: _commentsScrollController,
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  final isGift = comment.type == 'gift';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isGift
                          ? const Color(0xFFF9A825).withOpacity(0.12)
                          : Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: isGift
                          ? const Border(left: BorderSide(color: Color(0xFFF9A825), width: 2.5))
                          : Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundImage: comment.userImage.isNotEmpty
                              ? NetworkImage(comment.userImage)
                              : null,
                          backgroundColor: Colors.white24,
                          radius: 11,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment.username,
                                style: TextStyle(
                                  color: isGift ? const Color(0xFFF9A825) : Colors.white70,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                comment.message,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final myCoins = (authProvider.loginUserData.giftCoinsBalance ?? 0);
    final quickGifts = _gifts.take(3).toList();
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.92), Colors.transparent],
            stops: [0.0, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isHost || _isParticipant) _buildParticipantControls(),
            // Solde pièces + raccourcis cadeaux
            if (!widget.isHost && quickGifts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Color(0xFFF9A825).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Color(0xFFF9A825).withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded, color: Color(0xFFF9A825), size: 14),
                          SizedBox(width: 4),
                          Text('$myCoins pcs',
                              style: TextStyle(color: Color(0xFFF9A825), fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    ...quickGifts.map((gift) => GestureDetector(
                      onTap: () => _sendGift(gift),
                      child: Container(
                        margin: EdgeInsets.only(right: 6),
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(gift.icon, style: TextStyle(fontSize: 14)),
                            SizedBox(width: 3),
                            Text('${gift.price.toInt()}', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            // Barre principale
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            style: TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Envoyer un message...',
                              hintStyle: TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onChanged: (text) {
                              if (text.isNotEmpty) _startTyping();
                              else _stopTyping();
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send_rounded, color: Color(0xFFF9A825), size: 20),
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
                SizedBox(width: 10),
                _buildFooterAction(icon: Icons.favorite_rounded, color: Colors.pinkAccent, label: '$_likeCount', onTap: _sendLike),
                SizedBox(width: 6),
                _buildFooterAction(icon: Icons.stars_rounded, color: Color(0xFFF9A825), label: 'Cadeau', onTap: () => setState(() => _showGiftPanel = true)),
                SizedBox(width: 6),
                _buildFooterAction(icon: Icons.people_rounded, color: Colors.white70, label: '$_viewerCount', onTap: _toggleUsersPanel),
                SizedBox(width: 6),
                _buildFooterAction(icon: Icons.share_rounded, color: Colors.blueAccent, label: '$_shareCount', onTap: _shareLive),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterAction({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          SizedBox(height: 1),
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCtrlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = true,
    Color? activeColor,
  }) {
    final color = active ? (activeColor ?? Colors.white) : Colors.redAccent;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: active ? Colors.white.withOpacity(0.12) : Colors.red.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildParticipantControls() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCtrlBtn(
            icon: _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share_rounded,
            label: _isScreenSharing ? 'Arrêter' : 'Écran',
            onTap: _toggleScreenSharing,
            active: !_isScreenSharing,
          ),
          const SizedBox(width: 20),
          _buildCtrlBtn(
            icon: _isMicrophoneMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: 'Micro',
            onTap: _toggleMicrophone,
            active: !_isMicrophoneMuted,
          ),
          if (!_isScreenSharing) ...[
            const SizedBox(width: 20),
            _buildCtrlBtn(
              icon: Icons.cameraswitch_rounded,
              label: 'Caméra',
              onTap: _switchCamera,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (_typingUsers.isEmpty) return const SizedBox.shrink();
    final names = _typingUsers.values.take(2).join(', ');
    return Positioned(
      bottom: 144,
      left: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypingDots(),
            const SizedBox(width: 6),
            Text('$names écrit…', style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_clock, size: 64, color: Color(0xFFF9A825)),
            SizedBox(height: 20),
            Text(
              'Temps d\'essai écoulé',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Payez ${widget.postLive.participationFee.toInt()} FCFA pour continuer à regarder',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _showPaymentModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF9A825),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text(
                'Payer ${widget.postLive.participationFee.toInt()} FCFA',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 12),
            TextButton(
              onPressed: _leaveLive,
              child: Text(
                'Quitter le live',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildPaymentWarning() {
  //   return Container(
  //     color: Colors.black.withOpacity(0.9),
  //     padding: EdgeInsets.all(24),
  //     child: Center(
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Icon(Icons.timer, size: 64, color: Color(0xFFF9A825)),
  //           SizedBox(height: 20),
  //           Text(
  //             'Temps de live écoulé',
  //             style: TextStyle(
  //               color: Colors.white,
  //               fontSize: 20,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //           SizedBox(height: 12),
  //           Text(
  //             'Payez 100 FCFA pour continuer votre live pendant 1 heure supplémentaire',
  //             style: TextStyle(color: Colors.white70, fontSize: 14),
  //             textAlign: TextAlign.center,
  //           ),
  //           SizedBox(height: 24),
  //           Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //             children: [
  //               ElevatedButton(
  //                 onPressed: _handlePayment,
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: Color(0xFFF9A825),
  //                   padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  //                 ),
  //                 child: Text('Payer 100 FCFA',
  //                     style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
  //               ),
  //               TextButton(
  //                 onPressed: _endLive,
  //                 child: Text('Arrêter', style: TextStyle(color: Colors.white70)),
  //               ),
  //             ],
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFF9A825)),
            SizedBox(height: 16),
            Text('Connexion au live en cours...', style: TextStyle(color: Colors.white)),
            SizedBox(height: 8),
            Text('Live ID: ${widget.liveId}', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGiftEffects() {
    return _giftEffects.map((effect) {
      return Positioned(
        left: effect.x * MediaQuery.of(context).size.width,
        bottom: 150 + (DateTime.now().millisecondsSinceEpoch % 100) * 2,
        child: GiftAnimation(gift: effect.gift),
      );
    }).toList();
  }
  @override
  void dispose() {
    _removeUserFromSpectators();
    _trialTimer?.cancel();
    _typingTimer?.cancel();
    _liveSubscription?.cancel();
    _commentsSubscription?.cancel();
    _typingSubscription?.cancel();
    _usersSubscription?.cancel();
    _likesSubscription?.cancel(); // ← AJOUTEZ CETTE LIGNE
    _likeAnimationController.dispose();

    if (_isScreenSharing) {
      _stopScreenSharing();
    }

    _engine.leaveChannel();
    _engine.release();
    _commentController.dispose();
    _pinnedTextController.dispose();
    super.dispose();
  }
}



class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final opacity = ((_ctrl.value * 3 - i).clamp(0.0, 1.0) * (1 - (_ctrl.value * 3 - i - 1).clamp(0.0, 1.0))).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 4, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
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

  factory LiveComment.fromMap(Map<String, dynamic> map) {
    return LiveComment(
      liveId: map['liveId'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'Utilisateur',
      userImage: map['userImage'] ?? '',
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      type: map['type'] ?? 'text',
      giftId: map['giftId'],
    );
  }
}

