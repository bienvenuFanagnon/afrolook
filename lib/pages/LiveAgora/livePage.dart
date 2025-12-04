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


import ' live_widgets.dart';
import '../../models/model_data.dart';
import '../../services/linkService.dart';
import '../paiement/newDepot.dart';
import 'livesAgora.dart';

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
  List<String> _participants = [];
  List<String> _spectators = [];
  List<LiveComment> _comments = [];
  int _shareCount = 0;
  double _paidParticipationTotal = 0.0;

  // ÉTAT INTERFACE
  bool _showUI = true;
  bool _showGiftPanel = false;
  bool _showPaymentWarning = false;
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
  Timer? _paymentWarningTimer;
  final int _liveDurationMinutes = 30; // ← CHANGEZ ICI POUR MODIFIER LA DURÉE
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
    print("🎬 Initialisation LivePage - Live ${widget.postLive.isPaidLive ? 'PAYANT' : 'GRATUIT'}");

    authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    _likeAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    print("🎬 Initialisation de LivePage - isHost: ${widget.isHost}");

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
        print("⚠️ remoteUid toujours null, tentative avec uid=1");
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

    if (widget.isHost) {
      _initializeHostTimer();
    }

    if (widget.isInvited) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // _showJoinOptions();
      });
    }

    _setupTypingListener();
  }


// Ajout dans _LivePageState
  // ==================== GESTION TEMPS PERSISTANT SIMPLIFIÉE ====================
  void _initializeHostTimer() async {
    if (!widget.isHost) return;

    try {
      final liveDoc = await _firestore.collection('lives').doc(widget.liveId).get();
      if (liveDoc.exists) {
        final data = liveDoc.data()!;

        // Si déjà en attente de paiement
        if (data['paymentRequired'] == true) {
          setState(() => _showPaymentWarning = true);
          return;
        }

        // Récupérer la durée depuis PostLive (30 ou 60 minutes)
        final liveDurationMinutes = widget.postLive.safeLiveDurationMinutes;

        // Calculer le temps écoulé depuis le début ou dernier paiement
        final referenceTime = data['lastPaymentTime'] ?? data['startTime'];
        if (referenceTime == null) return;

        final referenceDateTime = (referenceTime as Timestamp).toDate();
        final now = DateTime.now();

        final elapsedMinutes = now.difference(referenceDateTime).inMinutes;
        final remainingMinutes = max(0, liveDurationMinutes - elapsedMinutes);

        print("⏰ $elapsedMinutes min écoulées, $remainingMinutes min restantes sur $liveDurationMinutes min");
        print("🎯 Type live: ${_isHostPremium ? 'PREMIUM' : 'GRATUIT'} (${liveDurationMinutes}min)");

        _startPaymentTimer(remainingMinutes, liveDurationMinutes);
      }
    } catch (e) {
      print("❌ Erreur initialisation timer: $e");
      _startPaymentTimer();
    }
  }
  Future<void> _initializeHostTimer2() async {
    if (!widget.isHost) return;

    try {
      final liveDoc = await _firestore.collection('lives').doc(widget.liveId).get();
      if (liveDoc.exists) {
        final data = liveDoc.data()!;

        // Si déjà en attente de paiement
        if (data['paymentRequired'] == true) {
          setState(() => _showPaymentWarning = true);
          return;
        }

        // Calculer le temps écoulé depuis le début ou dernier paiement
        final referenceTime = data['lastPaymentTime'] ?? data['startTime'];
        if (referenceTime == null) return;

        final referenceDateTime = (referenceTime as Timestamp).toDate();
        final now = DateTime.now();

        final elapsedMinutes = now.difference(referenceDateTime).inMinutes;
        final remainingMinutes = max(0, _liveDurationMinutes - elapsedMinutes);

        print("⏰ $elapsedMinutes min écoulées, $remainingMinutes min restantes sur $_liveDurationMinutes min");

        _startPaymentTimer(remainingMinutes);
      }
    } catch (e) {
      print("❌ Erreur initialisation timer: $e");
      _startPaymentTimer();
    }
  }
  void _startPaymentTimer([int? remainingMinutes, int? totalDuration]) {
    if (!widget.isHost) return;

    _paymentWarningTimer?.cancel();

    // Utiliser la durée du PostLive
    final liveDurationMinutes = totalDuration ?? widget.postLive.safeLiveDurationMinutes;
    final minutes = remainingMinutes ?? liveDurationMinutes;

    print("⏰ Timer configuré: $minutes minutes sur $liveDurationMinutes");
    print("💰 Montant: ${liveDurationMinutes == 60 ? '200' : '100'} FCFA");

    // Si temps écoulé, demander paiement immédiatement
    if (minutes <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestPayment();
      });
      return;
    }

    _paymentWarningTimer = Timer(Duration(minutes: minutes), () {
      _requestPayment();
    });
  }
  void _requestPayment() async {
    try {
      // Calculer le prix selon la durée
      final liveDurationMinutes = widget.postLive.safeLiveDurationMinutes;
      final amount = liveDurationMinutes == 60 ? 200.0 : 100.0; // 200 FCFA pour 60min, 100 pour 30min

      await _firestore.collection('lives').doc(widget.liveId).update({
        'paymentRequired': true,
        'paymentRequestTime': DateTime.now(),
        'isPaused': true,
        'pauseMessage': "Temps écoulé - En attente de prolongement ($liveDurationMinutes min)",
      });

      setState(() => _showPaymentWarning = true);

      // Optionnel : Muter les flux de l'hôte immédiatement
      if (widget.isHost) {
        await _engine.muteLocalAudioStream(true);
        await _engine.muteLocalVideoStream(true);
      }

      print("💰 Demande de paiement: $amount FCFA pour ${liveDurationMinutes}min");

    } catch (e) {
      print("❌ Erreur demande paiement: $e");
    }
  }

  void _handlePayment() async {
    try {
      final userProvider = context.read<UserAuthProvider>();
      final liveDurationMinutes = widget.postLive.safeLiveDurationMinutes;
      final amount = liveDurationMinutes == 60 ? 200.0 : 100.0;

      bool paymentSuccess = await userProvider.deductFromBalance(context, amount);

      if (paymentSuccess) {
        userProvider.incrementAppGain(amount);

        final now = DateTime.now();
        await _firestore.collection('lives').doc(widget.liveId).update({
          'paymentRequired': false,
          'paymentRequestTime': null,
          'lastPaymentTime': now,
          'isPaused': false,
          'pauseMessage': null,
        });

        // Réactiver les flux si hôte
        if (widget.isHost) {
          await _engine.muteLocalAudioStream(false);
          await _engine.muteLocalVideoStream(false);
        }

        setState(() => _showPaymentWarning = false);
        _startPaymentTimer(liveDurationMinutes, liveDurationMinutes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paiement de ${amount.toInt()} FCFA accepté! Live prolongé de $liveDurationMinutes min'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _endLive();
      }
    } catch (e) {
      print("❌ Erreur traitement paiement: $e");
    }
  }
// Mettez à jour le message d'alerte
  Widget _buildPaymentWarning() {
    final liveDuration = widget.postLive.safeLiveDurationMinutes;
    final amount = liveDuration == 60 ? 200.0 : 100.0;

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
            SizedBox(height: 8),
            Text(
              'Live ${liveDuration} minutes',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Payez ${amount.toInt()} FCFA pour continuer votre live pendant ${liveDuration} minutes supplémentaires',
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
                  child: Text('Payer ${amount.toInt()} FCFA',
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
  Future<void> _removeUserFromSpectators() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId != null && !widget.isHost && !_isParticipant) {
        await _firestore.collection('lives').doc(widget.liveId).update({
          'spectators': FieldValue.arrayRemove([currentUserId]),
          'viewerCount': FieldValue.increment(-1),
        });
        print("✅ Utilisateur retiré des spectateurs");
      }
    } catch (e) {
      print("❌ Erreur retrait des spectateurs: $e");
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
      print("❌ Erreur envoi like partagé: $e");
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
      print("❌ Erreur accord accès libre: $e");
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
      print("❌ Erreur initialisation système essai: $e");
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
      print("❌ Erreur mise à jour temps visionnage: $e");
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
      print("❌ Erreur paiement participation: $e");
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
      print("❌ Erreur configuration caméra: $e");
    }
  }

  Future<void> _initAgora() async {
    try {
      print("🔊 Demande des permissions Agora...");
      await [Permission.microphone, Permission.camera].request();

      print("🚀 Création du moteur Agora...");
      _engine = createAgoraRtcEngine();

      await _engine.initialize(RtcEngineContext(
        appId: "957063f627aa471581a52d4160f7c054",
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
          onCameraReady: () {
            print("📷 Caméra prête");
          },
          onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
            print("📹 État vidéo UID $remoteUid: $state");
          },
        ),
      );

      await _engine.enableVideo();

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
      print("✅ Agora initialisé - Live: ${isPremium ? 'PREMIUM' : 'STANDARD'}");
      print("   📹 Résolution: ${isPremium ? '1280x720 (HD)' : '640x360 (SD)'}");
      print("   ⚡ Latence: ${isPremium ? 'Ultra Low (500ms)' : 'Low (2000ms)'}");
      print("   🎯 Hôte: ${_isHostPremium ? 'PREMIUM' : 'STANDARD'}");
      print("   ⏰ Durée: ${widget.postLive.safeLiveDurationMinutes} minutes");

    } catch (e) {
      print("💥 Erreur lors de l'initialisation Agora: $e");
    }
  }

  Future<void> _initAgora2() async {
    try {
      print("🔊 Demande des permissions Agora...");
      await [Permission.microphone, Permission.camera].request();

      print("🚀 Création du moteur Agora...");
      _engine = createAgoraRtcEngine();

      await _engine.initialize(RtcEngineContext(
        appId: "957063f627aa471581a52d4160f7c054",
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
          onCameraReady: () {
            print("📷 Caméra prête");
          },
          // onCameraFocusAreaChanged: () {
          //   print("🔍 Zone de focus caméra changée");
          // },
          onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
            print("📹 État vidéo UID $remoteUid: $state");
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
      print("💥 Erreur lors de l'initialisation Agora: $e");
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
          print("❌ Erreur partage écran: $e");
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
      print("❌ Erreur démarrage partage écran: $e");
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
      print("❌ Erreur arrêt partage écran: $e");
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
      print("❌ Erreur mise à jour état partage écran: $e");
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
          print("❌ Erreur contrôle micro: $e");
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
          print("❌ Erreur basculement caméra: $e");
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
          final likeEffect = LikeEffect(
            id: doc.doc.id,
            userId: data['userId'],
            username: data['username'],
            userImage: data['userImage'] ?? '',
            timestamp: (data['timestamp'] as Timestamp).toDate(),
          );

          setState(() {
            _likeEffects.add(likeEffect);
          });

          // Supprimer l'effet après l'animation
          Future.delayed(Duration(milliseconds: 2500), () {
            if (mounted) {
              setState(() {
                _likeEffects.removeWhere((effect) => effect.id == doc.doc.id);
              });
            }
          });
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
      print("❌ Erreur envoi commentaire: $e");
    }
  }

  void _sendGift(Gift gift) async {
    try {
      final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final userBalance = userProvider.loginUserData!.votre_solde_principal!;

      if (userBalance < gift.price) {
        _showInsufficientBalanceDialog();
        return;
      }

      final paymentSuccess = await userProvider.deductFromBalance(context, gift.price);

      if (paymentSuccess) {
        User? user = _auth.currentUser;
        if (user != null) {
          _sendComment(
            'a envoyé ${gift.name} ${gift.icon}',
            type: 'gift',
            giftId: gift.id,
          );

          final hostShare = gift.price * 0.7;


          await _firestore.collection('lives').doc(widget.liveId).update({
            'giftTotal': FieldValue.increment(hostShare),
            'giftCount': FieldValue.increment(1),
          });

          await _firestore.collection('Users').doc(widget.postLive.hostId).update({
            'votre_solde_principal': FieldValue.increment(hostShare),
          });

          if(userProvider.loginUserData!.codeParrain!=null){
            final appShare = gift.price * 0.25;
            userProvider.incrementAppGain(appShare);
            userProvider.ajouterCommissionParrain(codeParrainage: userProvider.loginUserData!.codeParrain!, montant: gift.price);

          }else{
            final appShare = gift.price * 0.3;
            userProvider.incrementAppGain(appShare);
          }


          setState(() {
            _giftEffects.add(GiftEffect(
              id: DateTime.now().millisecondsSinceEpoch,
              gift: gift,
              x: Random().nextDouble() * 0.6 + 0.2,
            ));
          });

          setState(() => _showGiftPanel = false);
        }
      }
    } catch (e) {
      print("❌ Erreur envoi cadeau: $e");
    }
  }

  // ==================== GESTION FIREBASE STREAM ====================

  void _setupFirestoreListeners() {
    _liveSubscription = _firestore.collection('lives').doc(widget.liveId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        setState(() {
          _viewerCount = data['viewerCount'] ?? 0;
          _giftCount = data['giftCount'] ?? 0;
          _giftTotal = (data['giftTotal'] ?? 0).toDouble();
          _participants = List<String>.from(data['participants'] ?? []);
          _totalviewerCount = List<String>.from(data['totalspectateurs'] ?? []).length;
          _spectators = List<String>.from(data['spectators'] ?? []);
          _likeCount = data['likeCount'] ?? 0;
          _shareCount = data['shareCount'] ?? 0;
          _paidParticipationTotal = (data['paidParticipationTotal'] ?? 0).toDouble();

          // ⭐ NOUVEAU : État de pause synchronisé
          _showPaymentWarning = data['paymentRequired'] == true;
          _isLivePaused = data['isPaused'] == true;
          _pauseMessage = data['pauseMessage'] as String?;

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
      print("❌ Erreur récupération données hôte: $e");
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
      print("❌ Erreur récupération utilisateurs: $e");
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
      print("❌ Erreur mise à jour texte épinglé: $e");
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
      print("❌ Erreur rejoindre comme participant: $e");
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
      print("❌ Erreur rejoindre comme spectateur: $e");
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
  //     print("❌ Erreur demande paiement: $e");
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
  //     print("❌ Erreur traitement paiement: $e");
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

      Navigator.pop(context);
    } catch (e) {
      print("❌ Erreur fin du live: $e");
    }
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
      print("❌ Erreur sortie live: $e");
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

  void _shareLive() {
    final AppLinkService _appLinkService = AppLinkService();
    _appLinkService.shareContent(
      type: AppLinkType.live,
      id: widget.liveId!,
      message: " 🎥🔥 ${widget.postLive.title}",
      mediaUrl: "${widget.postLive.hostImage}",
    );
    _incrementShareCount();
  }

  void _incrementShareCount() async {
    try {
      await _firestore.collection('lives').doc(widget.liveId).update({
        'shareCount': FieldValue.increment(1),
      });
    } catch (e) {
      print("❌ Erreur incrémentation partages: $e");
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

            // BOUTON TOGGLE COMMENTS (TOUJOURS VISIBLE MÊME SI _showUI = false)
            if (_showUI) _buildToggleCommentsButton(),

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
      _buildCommentsSection(),
      _buildFooter(),
      _buildTypingIndicator(),
      if (_showGiftPanel)
        GiftPanelWidget(
          gifts: _gifts,
          onGiftSelected: _sendGift,
          onClose: () => setState(() => _showGiftPanel = false),
        ),
      if (_showPaymentWarning&&widget.isHost) _buildPaymentWarning(),
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
  Widget _buildPausedOverlay() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône selon rôle
            Icon(
              widget.isHost ? Icons.timer_off : Icons.pause_circle_filled,
              size: 80,
              color: Color(0xFFF9A825),
            ),
            SizedBox(height: 20),

            // Titre
            Text(
              widget.isHost ? 'Temps écoulé' : 'Live en pause',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),

            // Message (utilise celui de Firestore ou un par défaut)
            Text(
              _pauseMessage ??
                  (widget.isHost
                      ? 'Payez pour continuer la diffusion'
                      : 'L\'hôte renouvelle son temps de live'),
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),

            // Boutons différents selon rôle
            if (widget.isHost)
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _handlePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF9A825),
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    child: Text('Payer 100 FCFA',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 12),
                  TextButton(
                    onPressed: _endLive,
                    child: Text('Arrêter le live', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              )
            else
            // Pour spectateurs : juste un indicateur d'attente
              Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFFF9A825)),
                  SizedBox(height: 16),
                  Text('Réactivation automatique...',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildVideoSection() {

    // ⭐ PRIORITÉ : Afficher écran de pause si live en pause
    if (_isLivePaused&&!widget.isHost) {
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
          Text("_remoteUid: ${_remoteUid}"),


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
                Text('En attente du stream...', style: TextStyle(color: Colors.white)),
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
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          _showUI ? Icons.visibility_off : Icons.visibility,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildAppName() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 16,
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle)
          ),
          SizedBox(width: 6),
          Text('Afrolook Live',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [Shadow(offset: Offset(2.0, 2.0), blurRadius: 4.0, color: Colors.black38)]
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 50,
      left: 16,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child:   GestureDetector(
          onTap: () {
            _showHostDetails();
            setState(() => _isFollowing = !_isFollowing);
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
                      "@${_hostData.pseudo ?? widget.hostName}",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                  Text(
                      '${_hostData.userAbonnesIds?.length ?? 0} abonnés',
                      style: TextStyle(color: Colors.white70, fontSize: 12)
                  ),
                  if (widget.isHost)
                    Text('Hôte du live', style: TextStyle(color: Color(0xFFF9A825), fontSize: 12)),
                ],
              ),
              SizedBox(width: 12),
              if (!widget.isHost)
                GestureDetector(
                  onTap: () {
                    _showHostDetails();
                    setState(() => _isFollowing = !_isFollowing);
                  },
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
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ),
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
        print("❌ Utilisateur non trouvé avec l'ID: $userId");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Utilisateur non trouvé'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("❌ Erreur récupération utilisateur: $e");
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
          _buildInfoChip(icon: Icons.people, value: '$_viewerCount/$_totalviewerCount'),
          SizedBox(height: 8),
          _buildInfoChip(icon: Icons.favorite, value: '$_likeCount', color: Colors.pink),
          SizedBox(height: 8),
          _buildInfoChip(
              icon: Icons.card_giftcard,
              // value: '${(_giftTotal).toInt()} - ${(_paidParticipationTotal).toInt()} FCFA',
              value: '${(_giftTotal + _paidParticipationTotal).toInt()} FCFA',
              color: Color(0xFFF9A825)
          ),
          SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              _shareLive();
            },
              child: _buildInfoChip(icon: Icons.share, value: '$_shareCount', color: Colors.blue)),

          if (widget.postLive.isPaidLive && _remainingTrialMinutes < 999 && !_shouldSkipTrial())
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _remainingTrialMinutes < 2 ? Colors.red : Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_remainingTrialMinutes.toString().padLeft(2, '0')}:${_remainingTrialSeconds.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),

          if (_shouldSkipTrial() && widget.postLive.isPaidLive)
            Container(
              margin: EdgeInsets.only(top: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.isHost ? 'HÔTE' :
                authProvider.loginUserData.role == UserRole.ADM.name ? 'ADMIN' : 'PARTICIPANT',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),

          if (widget.isHost || authProvider.loginUserData.role == UserRole.ADM.name) ...[
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

  Widget _buildInfoChip({required IconData icon, required String value, Color color = Colors.white70}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 4),
          Text(value, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
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
      right: 120,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFF9A825), width: 2),
        ),
        child: Row(
          children: [
            Icon(Icons.push_pin, color: Color(0xFFF9A825), size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.postLive.pinnedText!,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.isHost)
              GestureDetector(
                onTap: _togglePinnedTextEditor,
                child: Icon(Icons.edit, color: Colors.white70, size: 16),
              ),
          ],
        ),
      ),
    );
  }
  bool _showComments = true;
  Widget _buildToggleCommentsButton() {
    return Positioned(
      bottom: 80,
      left: 8 + MediaQuery.of(context).size.width * 0.4 + 8,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showComments = !_showComments;
          });
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _showComments ? Icons.comment : Icons.comment_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
  Widget _buildCommentsSection() {
    if (!_showComments) {
      return SizedBox.shrink(); // Ne rien afficher quand désactivé
    }

    return Positioned(
      bottom: 80,
      left: 8,
      width: widget.isHost? MediaQuery.of(context).size.width * 0.7:MediaQuery.of(context).size.width * 0.7,
      height:  MediaQuery.of(context).size.height * 0.35,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // En-tête de la section
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                // color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Commentaires',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showComments = false;
                      });
                    },
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),

            // Liste des commentaires
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  // color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: ListView.builder(
                  controller: _commentsScrollController,
                  // SUPPRIMEZ reverse: true pour afficher du haut vers le bas
                  shrinkWrap: true,
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
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
                                  maxLines: 3,
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
            ),
          ],
        ),
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
        child: Column(
          children: [
            if (widget.isHost || _isParticipant) _buildParticipantControls(),
            Row(
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
                            onChanged: (text) {
                              if (text.isNotEmpty) _startTyping();
                              else _stopTyping();
                            },
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
                      SizedBox(height: 1),
                      Text('$_likeCount', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _showGiftPanel = true),
                  child: Column(
                    children: [
                      Icon(Icons.card_giftcard, color: Color(0xFFF9A825), size: 28),
                      SizedBox(height: 1),
                      Text('Cadeau', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleUsersPanel,
                  child:Column(
                    children: [
                      Icon(Icons.people, color: Colors.white, size: 28),
                      SizedBox(height: 1),
                      Text('$_viewerCount', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                GestureDetector(
                  onTap: _shareLive,
                  child:Column(
                    children: [
                      Icon(Icons.share, color: Colors.blue, size: 28),
                      SizedBox(height: 1),
                      Text('$_shareCount', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantControls() {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: _toggleScreenSharing,
            child: Column(
              children: [
                Icon(
                  _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                  color: _isScreenSharing ? Colors.red : Colors.white,
                  size: 24,
                ),
                Text(
                  _isScreenSharing ? 'Arrêter' : 'Écran',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _toggleMicrophone,
            child: Column(
              children: [
                Icon(
                  _isMicrophoneMuted ? Icons.mic_off : Icons.mic,
                  color: _isMicrophoneMuted ? Colors.red : Colors.white,
                  size: 24,
                ),
                Text('Micro', style: TextStyle(color: Colors.white, fontSize: 10)),
              ],
            ),
          ),
          if (!_isScreenSharing)
            GestureDetector(
              onTap: _switchCamera,
              child: Column(
                children: [
                  Icon(Icons.cameraswitch, color: Colors.white, size: 24),
                  Text('Caméra', style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (_typingUsers.isEmpty) return SizedBox.shrink();

    return Positioned(
      bottom: 140,
      left: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text('✍️', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Text(
                '${_typingUsers.values.join(', ')} écrit...',
                style: TextStyle(color: Colors.white, fontSize: 12)
            ),
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
    _paymentWarningTimer?.cancel();
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

