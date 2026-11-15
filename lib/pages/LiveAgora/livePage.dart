import 'package:afrotok/pages/liveshop/live_pinned_product.dart';
import 'package:afrotok/l10n/tr.dart';
import 'live_voice.dart';
import 'package:afrotok/services/api/wallet_api.dart';
import 'package:afrotok/services/api/api_identity.dart';
import 'package:afrotok/services/api/live_trial.dart';
import 'package:afrotok/services/api/live_ticket.dart';
import 'package:afrotok/services/api/live_display.dart';
import 'package:afrotok/services/api/live_stage.dart';
import 'live_stage_ui.dart';
import 'live_report_page.dart';
import 'live_game_ui.dart';
import 'live_quiz_ui.dart';
import 'package:afrotok/pages/user/userAbonnementPage.dart' show AbonnementScreen;
import 'live_caps.dart';
import 'live_market_ui.dart';
import 'live_clips_page.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
import '../../widgets/music/music_overlay.dart';
import 'package:afrotok/widgets/pseudo_tag.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
// models/live_models.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/services/api/chat_api.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:afrotok/utils/platform_guard.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:flutter/services.dart';
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
import 'package:image_picker/image_picker.dart';
import '../../services/api/argent_upload.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import '../../services/api/music_api.dart';
import '../../utils/media_cdn.dart';
import '../studio/montage/montage_music.dart' show kStudioTracks, StudioTrack;


import '../../models/model_data.dart';
import '../../services/linkService.dart';
import '../../services/sessions/session_checker_service.dart';
import '../paiement/newDepot.dart';
import '../coins/coin_recharge_screen.dart';
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
import 'package:afrotok/utils/tx_amount.dart';
import 'package:afrotok/widgets/coin_balances_row.dart';

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

class _LivePageState extends State<LivePage> with SingleTickerProviderStateMixin, MusicSuspendMixin {

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

  /// Live sans caméra : aucun moteur Agora (donc aucune minute décomptée) ; un aperçu (image ou courte vidéo en boucle) reste à l'écran,
  /// le reste du live (commentaires, jeux, marché, cadeaux) fonctionne comme d'habitude. Coupure sur inactivité côté serveur.
  bool get _noCam => widget.postLive.noCamera;
  VideoPlayerController? _previewVideo;
  Timer? _noCamTimer;
  Timer? _noCamTick;
  int? _idleLeft;            // secondes avant l'arrêt pour inactivité, lues sur l'API
  DateTime? _idleAt;         // instant de cette lecture
  int _commentsTotal = 0;    // commentaires reçus depuis l'ouverture (l'hôte les rapporte avec son signal : ils comptent comme une interaction)
  bool _commentsFirst = true;
  DateTime _lastCommentBeat = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isInitialized = false;
  bool _isFrontCamera = true;
  int _numberOfCameras = 0;

  // STATISTIQUES
  int _viewerCount = 0;
  int _totalviewerCount = 0;
  int _giftCount = 0;
  int _likeCount = 0;
  // ── Musique du live (piste gratuite d'Afrolook jouée chez chaque spectateur, sans passer par Agora ; elle s'arrête quand la personne quitte le live) ──
  ap.AudioPlayer? _musicPlayer;
  ap.AudioPlayer? _previewPlayer;   // écoute d'un extrait par l'hôte avant de choisir (jamais envoyé aux spectateurs)
  String? _previewId;
  Map<String, dynamic>? _music;
  String? _musicKey;
  int _musicGen = 0;
  double _musicVolume = .7;
  bool _musicMuted = false;

  // ── Épingles : texte et image, placement choisi par l'hôte ──
  String _pinPlace = 'left';    // left | right
  String _pinLayout = 'side';   // side (image à côté du texte) | below (image en dessous)
  String? _pinnedTextDoc;
  bool _pinnedTextFromDoc = false;

  int _gamesCount = 0;   // jeux déjà faits dans ce live (le bouton « Historique des jeux » reste là même quand l'hôte a retiré le jeu de l'écran)
  final Set<String> _closedGames = {};   // jeux terminés que cette personne a fermés (le résultat reste à l'écran jusqu'au prochain jeu, sauf si on le ferme)
  final Set<int> _speakingUids = {};   // numéros Agora dont la voix s'entend (0 = moi) : animation sur les vignettes de la scène
  bool _hostMutedMe = false;           // l'hôte a coupé mon micro : je ne peux pas le rétablir moi-même
  final Set<int> _remoteVideoOn = {};   // numéros Agora dont la vidéo arrive vraiment (décodée) : sinon la tuile montre l'avatar, jamais un simple fond noir

  List<String> _recentGiftIds = [];   // cadeaux envoyés récemment par cette personne (affichés en premier dans le panneau), gardés sur le téléphone
  int _lastLikeCount = -1;                  // dernier compteur lu sur le live : une hausse = des cœurs à montrer
  int _ownLikesUncounted = 0;               // mes propres « j'aime » pas encore retrouvés dans le compteur (déjà montrés tout de suite)
  DateTime _lastLikeWrite = DateTime.fromMillisecondsSinceEpoch(0);
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
  bool _isLandscapeMode = false;
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

  // JEUX : objectif, duel, défi, sondage (lus toutes les 5 secondes)
  LiveGame? _game;
  Map<String, dynamic>? _goal;
  Map<String, dynamic>? _market;            // marché en direct : étals et tours (null hors marché)
  bool get _isMarket => widget.postLive.typeSession == 'market';
  bool get _isActiveVendor => !widget.isHost && ((_market?['mine'] as Map?)?['status'] == 'active');
  String? _giftTarget;                     // présentateur qui reçoit mes cadeaux pendant un duel ou un défi
  Timer? _gameTimer;
  bool _gameFast = false;

  // SCÈNE À PLUSIEURS : invités en vidéo ou en audio, demandes et invitations validées par l'hôte
  LiveStageState _stage = const LiveStageState();
  Timer? _stageTimer;
  final Set<int> _remoteUids = {};          // tous les flux distants (hôte et invités)
  int? _myAgoraUid;
  String _myStageMedia = 'video';           // ce que je publie sur scène : video ou audio
  bool _onStageApi = false;                 // l'API dit que je suis sur scène (le document du live ne le sait pas)
  final Set<String> _seenInvites = {};
  bool _stageBusy = false;
  bool get _ticketAudioOnly => _ticket?.audioOnly == true;
  bool get _canRaiseHand => !widget.isHost && !_onStageApi && _stage.enabled && _stage.maxVideo + _stage.maxAudio > 0 && !_ticketRequired && _isInitialized;

  // AFFICHAGE : ce que l'hôte laisse voir aux spectateurs (l'hôte voit toujours tout)
  LiveDisplay _display = LiveDisplay.complete;
  bool get _showReactionCounts => widget.isHost || _display.reactions;
  bool get _showCoinsInfo => widget.isHost || _display.coins;
  bool get _showMessages => widget.isHost || _display.messages;

  // BILLET (minutes d'Agora : quand le gratuit du mois est épuisé, le spectateur prend un billet de 15 minutes ; l'hôte paie ses frais de diffusion)
  LiveTicket? _ticket;                 // ce qui couvre le spectateur (billet, essai, passe) ; null tant que le gratuit dure
  LiveTicketOffer? _ticketOffer;       // prix du billet, connu dès que le serveur le demande
  bool _ticketRequired = false;        // écran « billet à payer »
  String? _joinError;                  // la connexion au live a échoué (autre raison que le billet) : on le dit, au lieu de tourner sans fin
  Timer? _joinWatchdog;
  bool _hadPaidTicket = false;         // un billet a déjà été payé dans ce live (texte « Billet terminé »)
  bool _ticketLeftChannel = false;     // le spectateur a quitté le canal Agora à la fin de son billet (rejoint après paiement)
  bool _ticketBusy = false;
  int _ticketSecondsLeft = 1 << 30;
  Timer? _ticketTimer;
  Timer? _watchTimer;                  // battement du spectateur : le serveur compte ses minutes
  LiveHostFee? _hostFee;               // hôte : frais de diffusion (mode billet)
  Timer? _hostFeeTimer;
  bool _hostFeeBusy = false;

  // HEARTBEAT (host uniquement — maintient le live actif)
  Timer? _heartbeatTimer;
  // Durée maximale du live (30 min, 60 min admin) et fin détectée à distance
  Timer? _durationTimer;
  bool _durationWarned = false;
  int? _durationOverride;          // durée mise à jour après une prolongation payante
  bool _tokenAsHost = false;       // rôle du jeton Agora en cours (pour le renouveler)
  bool _extensionOffered = false;
  Timer? _voiceTimer;             // hôte : surveille l'arrivée de vocaux de spectateurs
  int _voiceNew = 0;

  int get _liveMinutes => _durationOverride ?? widget.postLive.safeLiveDurationMinutes;
  bool _endHandled = false;

  /// L'hôte a quitté sans terminer : le live est en pause (« L'hôte revient bientôt »), il reste ouvert et se termine seul après 15 minutes sans signal.
  bool _awayMarked = false;
  Timer? _pausePollTimer;

  /// Image épinglée par l'hôte (les spectateurs la touchent pour la voir en grand).
  String? _pinnedImageUrl;

  /// Filtres de beauté de l'hôte (Agora), réglages de 0 à 1.
  bool _beautyOn = false;
  double _beautySmooth = .5;
  double _beautyLight = .4;
  double _beautyRed = .1;
  double _beautySharp = .3;

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
    _isFollowing = authProvider.loginUserData.followingIds?.contains(widget.postLive.hostId) == true;

    if (widget.isHost) {
      _startHeartbeat();
      _startDurationLimit();
      _startVoiceWatch();
      _resumeIfAway();
    } else {
      // pendant la pause de l'hôte, le serveur peut terminer le live seul (15 minutes sans signal) : on le vérifie sans attendre un message de Firestore
      _pausePollTimer = Timer.periodic(const Duration(seconds: 45), (_) => _checkEndedWhilePaused());
    }

    // Vérification de la session Firebase avant toute connexion Agora/Firestore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SessionCheckerService.checkSessionAndShowModalIfNeeded(
        context: context,
        authProvider: authProvider,
      );
    });

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
    // 14/11/2026 : l'ancien « essai avec uid=1 » au bout de 3 s est supprimé. Pour l'hôte, il posait une vidéo distante
    // inexistante en plein écran (écran noir sans aucun widget, constaté sur téléphone : setupRemoteVideoEx uid 1).
    // L'identifiant de l'hôte vient de l'arrivée dans le salon (onUserJoined) et de la scène (_refreshMainUid).
    _setupCamera();
    if (_noCam) {
      _joinAsSpectator();
      _isInitialized = true;
      _initNoCamera();
    } else {
      _armJoinWatchdog();
      _initAgora();
      if (widget.postLive.audioOnly) _initPreviewVideo();   // salon audio : l'aperçu (image ou vidéo) s'affiche derrière les voix
    }

    _setupFirestoreListeners();
    _setupLikesListener(); // ← AJOUTEZ CETTE LIGNE
    _loadRecentGifts();
    _initLiveOptions();
    _fetchHostData();
    _initializeTrialSystem();
    _setupFreeAccess();
    _initHostFee();
    _initDisplay();
    _startStagePolling();
    _startGamePolling();
    if (_isMarket) _pollMarket();

    // if (widget.isHost) {
    //   _startPaymentTimer();
    // }

    if (widget.isInvited) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // _showJoinOptions();
      });
    }

    _setupTypingListener();

    // Autoriser la rotation paysage uniquement pour les spectateurs
    if (!widget.isHost) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }


  Future<void> _removeUserFromSpectators() async {
    try {
      final currentUserId = ApiIdentity.myId;
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
    _spawnHearts(3);   // visible tout de suite, sans attendre le réseau
    if (DateTime.now().difference(_lastLikeWrite).inMilliseconds < 400) return;
    _lastLikeWrite = DateTime.now();
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      // le compteur du live d'abord : il fait monter le chiffre et les cœurs chez tout le monde (même si l'historique ci-dessous échoue)
      _ownLikesUncounted++;
      await _firestore.collection('lives').doc(widget.liveId).update({'likeCount': FieldValue.increment(1)});
      // historique des « j'aime » (sans bloquer ni faire échouer le reste)
      _firestore.collection('live_likes').add({
        'liveId': widget.liveId,
        'userId': (ApiIdentity.myId ?? user.uid),
        'username': authProvider.loginUserData.pseudo ?? 'Utilisateur',
        'userImage': authProvider.loginUserData.imageUrl ?? '',
        'timestamp': DateTime.now(),
      }).catchError((Object e) {
        printVm("⚠️ Historique des j'aime non enregistré : $e");
        return _firestore.collection('live_likes').doc();
      });
    } catch (e) {
      printVm("❌ Erreur envoi like partagé: $e");
    }
  }

/// Fait monter [n] cœurs (bas à droite, comme TikTok). Sert aux touchers de cette personne (tout de suite) et à ceux des autres (hausse du compteur du live).
  void _spawnHearts(int n) {
    final base = 'h_${DateTime.now().microsecondsSinceEpoch}';
    for (var i = 0; i < n; i++) {
      Future.delayed(Duration(milliseconds: i * 110), () {
        if (!mounted) return;
        final id = '${base}_$i';
        setState(() => _likeEffects.add(LikeEffect(id: id, userId: '', username: '', userImage: '', timestamp: DateTime.now())));
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) setState(() => _likeEffects.removeWhere((e) => e.id == id));
        });
      });
    }
  }

  /// Le compteur du live a monté : les « j'aime » des AUTRES personnes (les miens sont déjà montrés) font monter des cœurs ici aussi.
  void _onLikeCountChanged(int count) {
    if (_lastLikeCount >= 0 && count > _lastLikeCount) {
      final delta = count - _lastLikeCount;
      final mine = _ownLikesUncounted.clamp(0, delta);
      _ownLikesUncounted -= mine;
      final others = delta - mine;
      if (others > 0) _spawnHearts(others.clamp(1, 6));
    }
    _lastLikeCount = count;
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
    final currentUserId = ApiIdentity.myId;
    return widget.isHost ||
        _isParticipant ||
        authProvider.loginUserData.role == UserRole.ADM.name ||
        _participants.contains(currentUserId);
  }

  /// Accès libre (hôte, participant, administrateur, entrée payée) : rien à écrire, le serveur (API) tient les droits d'accès.
  Future<void> _grantFreeAccess() async {
    if (ApiIdentity.myId == null || !mounted) return;

    setState(() {
      _remainingTrialMinutes = 999;
      _remainingTrialSeconds = 0;
    });

    _removeRestrictions();
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

    if (ApiIdentity.myId == null) return;

    // L'essai est chronométré par le serveur (le chrono démarre à la première demande de jeton ; le jeton est refusé
    // en 402 quand il est fini) : on lit `me.trial` (temps restant) et on affiche le compte à rebours.
    // Sans bloc `trial`, on part de la durée offerte (le serveur refuse le jeton au bon moment).
    int seconds = widget.postLive.freeTrialMinutes * 60;
    try {
      final live = await LivesApi.get(widget.liveId);
      final me = live['me'];
      if (me is Map && me['has_entry'] == true) {
        await _grantFreeAccess(); // entrée déjà payée
        return;
      }
      final trial = LiveTrial.fromLive(live);
      if (trial != null) {
        if (trial.expired) {
          _applyTrial(trial);
          return;
        }
        seconds = trial.secondsLeft;
      }
    } catch (e) {
      printVm("❌ Erreur lecture de l'essai gratuit: $e");
    }
    if (!mounted) return;
    setState(() {
      _remainingTrialMinutes = seconds ~/ 60;
      _remainingTrialSeconds = seconds % 60;
    });
    _startTrialTimer();
  }

  /// Recale le compte à rebours sur ce que dit le serveur (réponse du jeton, détail du live ou refus 402).
  /// À 0 (essai fini), affiche le verrou « Temps d'essai écoulé » et le paiement de l'entrée.
  void _applyTrial(LiveTrial trial) {
    if (!mounted || _shouldSkipTrial()) return;
    if (trial.expired || trial.secondsLeft <= 0) {
      _trialTimer?.cancel();
      setState(() {
        _remainingTrialMinutes = 0;
        _remainingTrialSeconds = 0;
      });
      _onTrialTimeExpired();
      return;
    }
    setState(() {
      _remainingTrialMinutes = trial.secondsLeft ~/ 60;
      _remainingTrialSeconds = trial.secondsLeft % 60;
    });
    _startTrialTimer();
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
    });
  }

  void _onTrialTimeExpired() {
    if (_shouldSkipTrial() || _showTrialOverlay) return;
    if (!widget.postLive.isPaidLive) {
      // live gratuit en mode billet : l'essai offert par l'hôte est fini → on quitte le canal et on propose le billet de 15 minutes (une seule fenêtre)
      _trialTimer?.cancel();
      _onTicketExpired();
      return;
    }

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
        if (!_noCam) _engine.muteAllRemoteAudioStreams(true);
        setState(() => _isAudioRestricted = true);
        break;
      case 'reduce':
        if (!_noCam) _engine.adjustPlaybackSignalVolume(widget.postLive.audioReductionPercent);
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
    if (!_noCam) _engine.muteAllRemoteAudioStreams(false);
    if (!_noCam) _engine.adjustPlaybackSignalVolume(100);
    setState(() {
      _isAudioRestricted = false;
      _isVideoBlurred = false;
      _showTrialOverlay = false;
    });
  }

  // ==================== JEUX DU LIVE ====================

  void _startGamePolling() {
    _gameTimer?.cancel();
    _pollGame();
    _gameTimer = Timer.periodic(Duration(seconds: _game?.kind == 'quiz' && _game?.active == true ? 2 : 5), (_) => _pollGame());
  }

  Future<void> _pollGame() async {
    if (!mounted || _endHandled || _ticketRequired) return;
    try {
      final r = await LivesApi.game(widget.liveId);
      if (!mounted) return;
      setState(() {
        _game = r['game'] is Map ? LiveGame(Map<String, dynamic>.from(r['game'] as Map)) : null;
        _goal = r['goal'] is Map ? Map<String, dynamic>.from(r['goal'] as Map) : null;
        _gamesCount = (r['games_count'] as num?)?.toInt() ?? _gamesCount;
        if (_game?.isMatch == true && (_giftTarget == null || !_game!.players.any((p) => p.id == _giftTarget))) _giftTarget = _game!.players.isNotEmpty ? _game!.players.first.id : null;
        if (_game == null) _giftTarget = null;
      });
      // le quiz demande une lecture plus rapide (une question toutes les 19 secondes), retour à 5 s ensuite
      final fast = _game?.kind == 'quiz' && _game?.active == true;
      if (fast != _gameFast) {
        _gameFast = fast;
        _startGamePolling();
      }
      if (_isMarket) await _pollMarket();
    } catch (_) {}
  }

  /// Barre de l'objectif du live, sous les pièces reçues.
  Widget _buildGoalBar() {
    final g = _goal;
    if (g == null) return const SizedBox.shrink();
    final from = (g['from'] as num?)?.toInt() ?? 0;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 130,
      left: 16,
      child: LiveGoalBar(title: '${g['title']}', progress: (_giftCoinsTotal - from).clamp(0, 1 << 30), target: (g['target'] as num?)?.toInt() ?? 0),
    );
  }

  /// Le jeu en cours (duel, défi, sondage) en haut de l'écran.
  Widget _buildGameCard() {
    final g = _game;
    final t = widget.postLive.typeSession;
    if (g == null && _isMarket && _market != null) {
      return _flowed(
        child: LiveMarketPanel(state: _market!, isHost: widget.isHost, onBook: _marketBook, onCancel: () => _marketCall(() => LivesApi.marketCancel(widget.liveId)), onReady: _marketReady, onNext: () => _marketCall(() => LivesApi.marketNext(widget.liveId))),
      );
    }
    if (g == null && widget.isHost && (t == 'duel' || t == 'challenge' || t == 'story' || t == 'quiz')) {
      // duel ou défi choisi au lancement : en attendant les présentateurs, une aide courte
      return _flowed(
        child: GestureDetector(
          onTap: () => _openGames(t),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withOpacity(.62), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF9A825).withOpacity(.6))),
            child: Text(
              t == 'duel'
                  ? context.tr('Invite ton adversaire sur scène (bouton Inviter), puis touche ici pour lancer le duel.')
                  : t == 'challenge'
                      ? context.tr('Invite tes présentateurs sur scène (bouton Inviter), puis touche ici pour lancer le défi.')
                      : t == 'story'
                          ? context.tr('Touche ici pour lancer ton conte : tu poses la question, le public vote la suite avec des pièces.')
                          : context.tr('Touche ici pour lancer ton quiz : tes questions, ta cagnotte, jouer est gratuit pour le public.'),
              style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
            ),
          ),
        ),
      );
    }
    if (g == null) return const SizedBox.shrink();
    if (!g.active && _closedGames.contains(g.id)) return const SizedBox.shrink();
    final quiz2 = g.kind == 'quiz' && (g.quiz['v'] as num?)?.toInt() == 2;
    return _flowed(
      child: Stack(clipBehavior: Clip.none, children: [quiz2
          ? LiveQuizPanel(
              game: g,
              isHost: widget.isHost,
              onAnswer: _quizAnswer,
              onSendQuestion: widget.isHost ? _sendQuizQuestion : null,
              // image épinglée par l'hôte : montrée dans le quiz (questions sur l'image), touchée = agrandie
              imageUrl: _hasPinImage ? _pinnedImageUrl : null,
              onOpenImage: _openPinnedImage,
              // croix dans l'en-tête du quiz (posée par-dessus, elle cachait les boutons du son et de réduction)
              onClose: (!g.active || widget.isHost) ? () => widget.isHost ? _dismissGame(g) : setState(() => _closedGames.add(g.id)) : null,
              // classement sur toutes les questions (les 20 premiers) : remise de prix lors des événements
              onShowRanking: () => showQuizRankingSheet(context, LivesApi.quizRanking(widget.liveId, gameId: g.id), isHost: widget.isHost),
            )
          : LiveGameCard(
        game: g,
        isHost: widget.isHost,
        target: _giftTarget,
        onTarget: (id) => setState(() => _giftTarget = id),
        onVote: _vote,
        onStoryVote: _storyVote,
        onAnswer: _quizAnswer,
      ),
        // croix : l'hôte arrête le jeu et le retire de l'écran de tout le monde ; chaque spectateur peut fermer un jeu terminé chez lui (il reste dans l'historique)
        if (!quiz2 && (!g.active || widget.isHost))
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => widget.isHost ? _dismissGame(g) : setState(() => _closedGames.add(g.id)),
              child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white70, size: 15)),
            ),
          ),
      ]),
    );
  }

  /// Conte : un vote coûte 10 pièces.
  Future<void> _storyVote(int option) async {
    try {
      final r = await LivesApi.storyVote(widget.liveId, option);
      if (mounted) setState(() => _game = LiveGame(r));
      await CoinCheckout.refreshBalance(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isInsufficientCoins) {
        await CoinCheckout.insufficient(context, _game?.voteCoins ?? 10);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {}
  }

  /// Quiz : réponse à la question en cours. Renvoie `false` si elle n'a pas été prise (le joueur peut retoucher) ; la raison s'affiche.
  Future<bool> _quizAnswer(int option) async {
    try {
      final r = await LivesApi.quizAnswer(widget.liveId, option);
      if (mounted) setState(() => _game = LiveGame(r));
      return true;
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == 'question_closed' ? context.tr('Trop tard : le temps de cette question est fini.') : e.message)));
      return false;
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Ta réponse n\'est pas partie. Vérifie ta connexion et retouche.'))));
      return false;
    }
  }

  /// Réglages du quiz de ce live (choisis à la création), gardés pour les questions envoyées en direct.
  QuizSettings? _quizSettings;

  /// Quiz en direct : l'hôte écrit et envoie la question suivante (temps et somme à gagner modifiables à chaque fois).
  Future<void> _sendQuizQuestion() async {
    final s = _quizSettings ?? QuizSettings();
    final q = await showQuizQuestionEditor(context, defSeconds: s.seconds, defPot: s.pot, okLabel: 'Envoyer la question', showPot: !s.physical);
    if (q == null || !mounted) return;
    try {
      final r = await LivesApi.gameQuestion(widget.liveId, q.toJson());
      if (mounted) setState(() => _game = LiveGame(r));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isInsufficientCoins) {
        await CoinCheckout.insufficient(context, (e.details['coins'] as num?)?.toInt() ?? 0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {}
  }

  // ---- marché en direct ----

  Future<void> _pollMarket() async {
    try {
      final m = await LivesApi.market(widget.liveId);
      if (mounted) setState(() => _market = m);
    } catch (_) {}
  }

  Future<void> _marketCall(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {}
    await _pollMarket();
  }

  Future<void> _marketBook() async {
    final rent = ((_market?['config'] as Map?)?['rent_coins'] as num?)?.toInt() ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('Louer un étal')),
        content: Text(ctx.tr('Tu passeras à ton tour, en vidéo, avec tes articles. Le loyer de {r} pièces n\'est payé que quand tu réponds « prêt » : rien avant, et rien si tu ne viens pas.', {'r': CoinCheckout.fmt(rent)})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Réserver'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await LivesApi.marketBook(widget.liveId);
    } on ApiException catch (e) {
      if (mounted) {
        if (e.isInsufficientCoins) {
          await CoinCheckout.insufficient(context, rent);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    } catch (_) {}
    await _pollMarket();
  }

  Future<void> _marketReady() async {
    try {
      await LivesApi.marketReady(widget.liveId);
      await CoinCheckout.refreshBalance(context);
    } on ApiException catch (e) {
      if (mounted) {
        if (e.isInsufficientCoins) {
          await CoinCheckout.insufficient(context, (e.details['coins'] as num?)?.toInt() ?? 0);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    } catch (_) {}
    await _pollMarket();
    await _pollStage();   // le serveur vient de me mettre sur scène : je publie ma vidéo
  }

  /// Prime des clips : l'hôte fixe la prime par clip retenu (0 pour fermer), puis ouvre la liste des clips.
  Future<void> _openClips() async {
    final v = await askFields(context, title: context.tr('Clips rémunérés'), fields: [(label: context.tr('Prime par clip retenu (pièces, 0 pour fermer)'), hint: '100', number: true, initial: '100')], ok: 'Enregistrer');
    if (v == null) return;
    try {
      await LivesApi.update(widget.liveId, {'clip_bounty_coins': (int.tryParse(v[0]) ?? 0).clamp(0, 5000)});
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => LiveClipsPage(liveId: widget.liveId)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {}
  }

  Future<void> _vote(int option) async {
    try {
      final r = await LivesApi.gameVote(widget.liveId, option);
      if (mounted) setState(() => _game = LiveGame(r));
    } catch (_) {}
  }

  /// Menu « Jeux du live » de l'hôte.
  Future<void> _openGames([String? only]) async {
    final direct = {'duel', 'challenge', 'story', 'quiz'}.contains(only) ? only : null;   // type choisi à la création : on va droit au jeu
    final k = direct ?? await showGamesMenu(context, hasStageGuests: _stage.videoSpeakers.isNotEmpty, gameActive: _game?.active == true, allowed: _caps.games);
    if (k == null || !mounted) return;
    try {
      switch (k) {
        case 'goal':
          final v = await askFields(context, title: context.tr('Objectif du live'), fields: [
            (label: context.tr('Ce que tu fais à l\'objectif'), hint: context.tr('Je chante'), number: false, initial: ''),
            (label: context.tr('Pièces à atteindre'), hint: '5000', number: true, initial: '5000'),
          ]);
          if (v == null || v[0].length < 2) return;
          await LivesApi.update(widget.liveId, {'goal': {'title': v[0], 'target': int.tryParse(v[1]) ?? 5000}});
          break;
        case 'duel':
          final sp = _stage.videoSpeakers;
          if (sp.isEmpty) return;
          final opp = sp.length == 1 ? sp.first : await _pickSpeaker(sp);
          if (opp == null) return;
          await LivesApi.gameStart(widget.liveId, {'kind': 'duel', 'opponent_id': opp.user.id});
          break;
        case 'challenge':
          final sp = _stage.videoSpeakers;
          if (sp.isEmpty) return;
          final v = await askFields(context, title: context.tr('Défi à plusieurs'), fields: [(label: context.tr('Objectif en pièces'), hint: '2000', number: true, initial: '2000')]);
          if (v == null) return;
          await LivesApi.gameStart(widget.liveId, {'kind': 'challenge', 'players': [for (final s in sp) s.user.id], 'goal': int.tryParse(v[0]) ?? 2000});
          break;
        case 'poll':
          final v = await askFields(context, title: context.tr('Sondage'), fields: [
            (label: context.tr('Question'), hint: context.tr('Quelle chanson ensuite ?'), number: false, initial: ''),
            (label: context.tr('Choix 1'), hint: '', number: false, initial: ''),
            (label: context.tr('Choix 2'), hint: '', number: false, initial: ''),
            (label: context.tr('Choix 3 (facultatif)'), hint: '', number: false, initial: ''),
          ], minuteChoices: kPollMinuteChoices, initialMinutes: 2);
          if (v == null) return;
          final poll = pollFromFields(v);   // durée choisie par l'hôte : 1, 2, 5, 10 ou 30 minutes
          await LivesApi.gameStart(widget.liveId, {'kind': 'poll', 'question': poll.question, 'options': poll.options, 'minutes': poll.minutes});
          break;
        case 'draw':
          final v = await askFields(context, title: context.tr('Tirage au sort'), fields: [(label: context.tr('Pièces mises en jeu'), hint: '100', number: true, initial: '100')], ok: 'Tirer au sort');
          if (v == null) return;
          final candidates = _spectators.where((u) => u != widget.postLive.hostId).toList();
          final r = await LivesApi.gameDraw(widget.liveId, int.tryParse(v[0]) ?? 0, candidates);
          final w = r['winner'] is Map ? '@${(r['winner'] as Map)['username']}' : '';
          _sendComment(context.tr('🎉 {w} gagne {n} pièces au tirage au sort !', {'w': w, 'n': '${r['coins']}'}));
          if (mounted) showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(ctx.tr('Gagnant du tirage')), content: Text('$w · ${r['coins']} ${ctx.tr('pièces')}'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
          break;
        case 'story':
          final st = await askFields(context, title: context.tr('Conte interactif'), fields: [
            (label: context.tr('Où en est l\'histoire ? Que fait le héros ?'), hint: context.tr('Il trouve un coffre. Que fait-il ?'), number: false, initial: ''),
            (label: context.tr('Choix A'), hint: '', number: false, initial: ''),
            (label: context.tr('Choix B'), hint: '', number: false, initial: ''),
            (label: context.tr('Choix C (facultatif)'), hint: '', number: false, initial: ''),
          ], ok: 'Lancer le vote');
          if (st == null) return;
          await LivesApi.gameStart(widget.liveId, {'kind': 'story', 'question': st[0], 'options': [for (final o in st.skip(1)) if (o.isNotEmpty) o], 'minutes': 1});
          break;
        case 'quiz':
          // réglages choisis à la création du live, et plan de l'hôte lu sur le serveur (la liste préparée est réservée au Gold)
          Map<String, dynamic> live = const {};
          Map<String, dynamic> lim = const {};
          Map<String, dynamic>? packs;
          try {
            final both = await Future.wait([LivesApi.get(widget.liveId), LivesApi.limits()]);
            live = both[0];
            lim = both[1];
          } catch (_) {}
          try {
            packs = await LivesApi.quizPacks();   // questions d'Afrolook : section masquée si le serveur ne répond pas
          } catch (_) {}
          if (!mounted) return;
          final settings = QuizSettings.fromOptions(live['options']);
          final picked = await showQuizLaunchSheet(context, settings: settings, isGold: lim['plan'] == 'gold', packs: packs,
              onUpgrade: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AbonnementScreen())));
          if (picked == null || !mounted) return;
          _quizSettings = picked.settings;
          final s = picked.settings;
          await LivesApi.gameStart(widget.liveId, {
            'kind': 'quiz', 'mode': picked.mode, 'winners': s.winners, 'seconds': s.seconds, 'pot': s.pot, 'theme': s.theme,
            if (picked.pack != null) 'pack': {'theme': picked.pack!.theme, 'count': picked.pack!.count}
            else if (picked.mode == 'planned') 'questions': [for (final q in s.questions) q.toJson()],
          });
          await _pollGame();
          // en direct : on écrit tout de suite la première question
          if (picked.mode == 'live' && mounted) await _sendQuizQuestion();
          break;
        case 'clips':
          await _openClips();
          break;
        case 'questions':
          await _showQuestions();
          break;
        case 'end':
          await LivesApi.gameDismiss(widget.liveId);   // arrête le jeu et le retire de l'écran de tous (reste dans l'historique)
          if (_game != null) _closedGames.add(_game!.id);
          break;
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.isInsufficientCoins) {
          await CoinCheckout.insufficient(context, (e.details['coins'] as num?)?.toInt() ?? 0);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    } catch (_) {}
    await _pollGame();
  }

  /// L'hôte arrête le jeu (s'il tourne encore) et le retire de l'écran de tout le monde ; il reste dans l'historique des jeux.
  Future<void> _dismissGame(LiveGame g) async {
    if (g.active) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('Arrêter ce jeu ?')),
          content: Text(ctx.tr('Le jeu s\'arrête et disparaît de l\'écran de tout le monde. Tu le retrouves dans l\'historique des jeux.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Garder'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Arrêter et retirer'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await LivesApi.gameDismiss(widget.liveId);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } catch (_) {}
    if (mounted) setState(() => _closedGames.add(g.id));
    await _pollGame();
  }

  Future<StageSpeaker?> _pickSpeaker(List<StageSpeaker> sp) => showDialog<StageSpeaker>(
        context: context,
        builder: (ctx) => SimpleDialog(title: Text(ctx.tr('Ton adversaire')), children: [
          for (final s in sp) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, s), child: Text('@${s.user.username}')),
        ]),
      );

  /// Questions du public : l'hôte lit et en épingle une (elle s'affiche à tous comme le texte épinglé).
  Future<void> _showQuestions() async {
    final qs = await LivesApi.questions(widget.liveId);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => SafeArea(
        child: qs.isEmpty
            ? Padding(padding: const EdgeInsets.all(24), child: Text(ctx.tr('Aucune question pour le moment. Les spectateurs posent leur question avec le bouton « ? » à droite de leur écran ; elle apparaît ici et tu peux l\'épingler.'), style: const TextStyle(color: Colors.white70, height: 1.4)))
            : ListView(shrinkWrap: true, children: [
                for (final q in qs)
                  ListTile(
                    title: Text('${q['text']}', style: const TextStyle(color: Colors.white)),
                    subtitle: Text('@${q['username']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await LivesApi.pinQuestion(widget.liveId, '${q['id']}').catchError((_) {});
                      },
                      child: Text(ctx.tr('Épingler')),
                    ),
                  ),
              ]),
      ),
    );
  }

  /// Le public pose une question à l'hôte.
  Future<void> _askQuestion() async {
    final v = await askFields(context, title: context.tr('Poser une question'), fields: [(label: context.tr('Ta question'), hint: '', number: false, initial: '')], ok: 'Envoyer');
    if (v == null || v[0].length < 3) return;
    try {
      await LivesApi.ask(widget.liveId, v[0]);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Question envoyée à l\'hôte.'))));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.status == 429 ? context.tr('Une question toutes les 30 secondes.') : e.message)));
    } catch (_) {}
  }

  // ==================== SCÈNE À PLUSIEURS ====================

  /// Le flux principal est celui de l'hôte (son numéro Agora est publié par le serveur) ; à défaut, le premier flux qui n'est pas celui d'un invité.
  void _refreshMainUid() {
    final host = _stage.hostAgoraUid;
    if (host != null && _remoteUids.contains(host)) {
      _remoteUid = host;
      return;
    }
    final guests = _stage.speakers.map((s) => s.agoraUid).whereType<int>().toSet();
    final others = _remoteUids.where((u) => !guests.contains(u));
    _remoteUid = others.isNotEmpty ? others.first : null;
  }

  /// Interroge la scène toutes les 8 secondes (places, demandes, invitations, personnes sur scène).
  void _startStagePolling() {
    _stageTimer?.cancel();
    _gameTimer?.cancel();
    _pollStage();
    _stageTimer = Timer.periodic(const Duration(seconds: 8), (_) => _pollStage());
  }

  Future<void> _pollStage() async {
    if (!mounted || _endHandled || _ticketRequired) return;
    try {
      final st = LiveStageState.fromJson(await LivesApi.stage(widget.liveId));
      if (!mounted) return;
      setState(() {
        _stage = st;
        _refreshMainUid();
      });
      await _reactToStage(st);
    } on ApiException catch (e) {
      if (e.status == 410) _stageTimer?.cancel();
    } catch (_) {}
  }

  /// Une demande acceptée me met sur scène (je publie), une invitation s'affiche, un retrait me fait descendre.
  Future<void> _reactToStage(LiveStageState st) async {
    if (widget.isHost) return;
    final me = ApiIdentity.myId;
    if (st.onStage && !_onStageApi) {
      final mine = st.speakers.where((s) => s.user.id == me);
      _myStageMedia = mine.isNotEmpty ? mine.first.media : 'video';
      await _becomeParticipant();
    } else if (!st.onStage && _onStageApi) {
      await _stepDown();
    }
    final mineNow = st.speakers.where((s) => s.user.id == me);
    if (mineNow.isNotEmpty && _onStageApi) await _applyHostMute(mineNow.first.hostMuted);
    final inv = st.mine;
    if (inv != null && inv.isInvite && _seenInvites.add(inv.id)) _askInvite(inv);
  }

  Future<void> _becomeParticipant() async {
    if (_stageBusy) return;
    _stageBusy = true;
    try {
      _ticketTimer?.cancel();
      _onStageApi = true;
      if (mounted) {
        setState(() {
          _isParticipant = true;
          _ticketRequired = false;
          _ticketSecondsLeft = 1 << 30;
        });
      }
      await _reinitializeAgora();
      await _grantFreeAccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Tu es sur scène : tout le monde te voit et t\'entend.'))));
      }
    } catch (e) {
      printVm('❌ Erreur passage sur scène: $e');
    } finally {
      _stageBusy = false;
    }
  }

  Future<void> _stepDown() async {
    if (_stageBusy) return;
    _stageBusy = true;
    try {
      _onStageApi = false;
      _hostMutedMe = false;
      _isMicrophoneMuted = false;
      if (mounted) setState(() => _isParticipant = _participants.contains(ApiIdentity.myId));
      await _reinitializeAgora();
    } catch (e) {
      printVm('❌ Erreur descente de scène: $e');
    } finally {
      _stageBusy = false;
    }
  }

  /// Invitation de l'hôte : gratuite, le spectateur accepte ou décline.
  Future<void> _askInvite(StageRequest inv) async {
    if (!mounted) return;
    final host = '@${_hostData.pseudo ?? widget.hostName}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('{h} t\'invite sur scène', {'h': host})),
        content: Text(inv.media == 'video'
            ? ctx.tr('Tu seras vu (caméra) et entendu par tous les spectateurs. C\'est gratuit.')
            : ctx.tr('Tu seras entendu (micro seul) par tous les spectateurs. C\'est gratuit.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Plus tard'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Monter'))),
        ],
      ),
    );
    try {
      await LivesApi.stageAnswerInvite(widget.liveId, inv.id, accept: ok == true);
      await _pollStage();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {}
  }

  /// « Monter sur scène » : feuille vidéo / audio, puis demande envoyée à l'hôte (rien n'est débité avant son accord).
  Future<void> _raiseHand() async {
    final st = _stage;
    if (st.mine != null) {
      final cancel = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('Demande envoyée')),
          content: Text(ctx.tr('L\'hôte a 2 minutes pour répondre. Veux-tu retirer ta demande ?')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Garder'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Retirer'))),
          ],
        ),
      );
      if (cancel == true) {
        await LivesApi.stageCancel(widget.liveId).catchError((_) {});
        await _pollStage();
      }
      return;
    }
    final coins = CoinSplit.of(authProvider.loginUserData);
    final media = await showRaiseHandSheet(
      context,
      hostName: '@${_hostData.pseudo ?? widget.hostName}',
      placeCoins: st.placeCoins,
      depot: coins.depot,
      earned: coins.gagnees,
      videoFull: st.videoFull || widget.postLive.audioOnly,
      audioFull: st.audioFull,
    );
    if (media == null || !mounted) return;
    try {
      await LivesApi.stageRequest(widget.liveId, media);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Demande envoyée à l\'hôte.'))));
      await _pollStage();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isInsufficientCoins) {
        await CoinCheckout.insufficient(context, st.placeCoins);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == 'stage_full' ? context.tr('Il n\'y a plus de place sur scène.') : e.message)));
      }
    } catch (_) {}
  }

  /// L'hôte accepte ou refuse une demande.
  Future<void> _decideRequest(StageRequest r, bool accept) async {
    try {
      await LivesApi.stageDecide(widget.liveId, r.id, accept: accept);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.code == 'viewer_insufficient'
                ? context.tr('Cette personne n\'a plus assez de pièces pour sa place.')
                : e.code == 'stage_full'
                    ? context.tr('Il n\'y a plus de place sur scène.')
                    : e.message)));
      }
    } catch (_) {}
    await _pollStage();
  }

  Future<void> _inviteToStage(StageUser u, String media) async {
    try {
      await LivesApi.stageInvite(widget.liveId, u.id, media);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Invitation envoyée à @{u}.', {'u': u.username}))));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == 'stage_full' ? context.tr('Il n\'y a plus de place sur scène.') : e.message)));
    } catch (_) {}
    await _pollStage();
  }

  Future<void> _removeFromStage(String userId) async {
    if (userId.isEmpty) return;
    try {
      await LivesApi.stageRemove(widget.liveId, userId);
    } catch (_) {}
    await _pollStage();
  }

  /// Personnes de la scène dont la voix s'entend maintenant (mon propre micro compte seulement s'il n'est pas coupé).
  Set<String> _speakingUserIds() {
    final me = ApiIdentity.myId;
    return {
      for (final s in _stage.speakers)
        if ((s.user.id == me && _speakingUids.contains(0) && !_isMicrophoneMuted) || (s.agoraUid != null && _speakingUids.contains(s.agoraUid))) s.user.id,
    };
  }

  /// L'hôte coupe ou rétablit le micro d'une personne sur scène : son application coupe son micro, plus personne ne l'entend.
  Future<void> _muteOnStage(StageSpeaker s) async {
    final mute = !s.hostMuted;
    try {
      await LivesApi.stageMute(widget.liveId, s.user.id, mute);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mute ? context.tr('Micro de @{u} coupé.', {'u': s.user.username}) : context.tr('Micro de @{u} rétabli.', {'u': s.user.username}))));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {}
    await _pollStage();
  }

  /// L'hôte a coupé (ou rétabli) mon micro : je le coupe ici, et je ne peux le rétablir moi-même que lorsqu'il l'autorise.
  Future<void> _applyHostMute(bool muted) async {
    if (muted == _hostMutedMe) return;
    _hostMutedMe = muted;
    try {
      if (_isInitialized) await _engine.muteLocalAudioStream(muted);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isMicrophoneMuted = muted);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(muted ? context.tr('L\'hôte a coupé ton micro.') : context.tr('L\'hôte a rétabli ton micro.'))));
  }

  /// Vignette d'une personne sur scène : sa propre vidéo reste dans l'aperçu en bas ; celle d'un autre vient du flux Agora de son numéro.
  Widget? _stageVideoTile(StageSpeaker s) {
    // avatar derrière la vidéo : visible tant que les images n'arrivent pas (caméra coupée, connexion en cours), à la place d'un fond noir
    Widget avatar() => Center(child: StageAvatar(user: s.user, size: 46));
    if (s.user.id == ApiIdentity.myId) {
      // ma propre vignette : mon aperçu local (le même flux que la petite fenêtre du bas)
      if (!_isInitialized || _noCam || (!widget.isHost && _myStageMedia != 'video')) return avatar();
      return Stack(fit: StackFit.expand, children: [
        avatar(),
        AgoraVideoView(controller: VideoViewController(rtcEngine: _engine, canvas: const VideoCanvas(uid: 0), useFlutterTexture: true, useAndroidSurfaceView: false)),
      ]);
    }
    final uid = s.agoraUid;
    if (uid == null || !_remoteUids.contains(uid) || !_isInitialized || _ticketAudioOnly) return avatar();
    return Stack(fit: StackFit.expand, children: [
      avatar(),
      AgoraVideoView(
        key: ValueKey('stage_$uid'),
        controller: VideoViewController.remote(rtcEngine: _engine, canvas: VideoCanvas(uid: uid), connection: RtcConnection(channelId: widget.liveId), useFlutterTexture: true, useAndroidSurfaceView: false),
      ),
      if (!_remoteVideoOn.contains(uid)) const Positioned(top: 4, left: 4, child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 15)),
    ]);
  }

  /// La scène : bande des invités en vidéo, avatars des invités en audio, places (maquette « La scène à plusieurs »).
  Widget _buildStageStrip() {
    if (_stage.speakers.isEmpty || widget.postLive.audioOnly) return const SizedBox.shrink();
    return _flowed(
      child: LiveStageStrip(
        stage: _stage,
        isHost: widget.isHost,
        myUserId: ApiIdentity.myId,
        videoTile: _stageVideoTile,
        speaking: _speakingUserIds(),
        onMute: widget.isHost ? _muteOnStage : null,
        onRemove: (s) => _removeFromStage(s.user.id),
        onFreeSlot: () {
          setState(() => _showUsersPanel = true);
          _fetchAllUsers();
        },
      ),
    );
  }

  // ==================== AFFICHAGE DU LIVE ====================

  /// Lit le réglage d'affichage du live (`options.display`) ; le temps réel (document du live) le met ensuite à jour.
  Future<void> _initDisplay() async {
    try {
      final live = await LivesApi.get(widget.liveId);
      final o = live['options'];
      if (o is Map && o['display'] != null && mounted) setState(() => _display = LiveDisplay.fromJson(o['display']));
    } catch (_) {}
  }

  /// Enregistre l'affichage : API (durable) et document du live (les spectateurs le voient tout de suite).
  Future<void> _saveDisplay(LiveDisplay d) async {
    setState(() => _display = d);
    try {
      await LivesApi.update(widget.liveId, {'display': d.toJson()});
    } catch (e) {
      printVm('⚠️ Affichage non enregistré : $e');
    }
    try {
      await _firestore.collection('lives').doc(widget.liveId).update({'display': d.toJson()});
    } catch (_) {}
  }

  /// Feuille « Affichage du live » : préréglages, aperçu et interrupteurs (spectateurs toujours affichés, en petit).
  void _showDisplaySheet() {
    var d = _display;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Widget row(String title, String? sub, bool value, ValueChanged<bool>? onChanged) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    if (sub != null) Text(sub, style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 10.5)),
                  ]),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: const Color(0xFFF9A825),
                  inactiveTrackColor: const Color(0xFF4A4A46),
                ),
              ]),
            );
        Widget preview() {
          Widget bar(double w, double h, double a, {double? left, double? right, double? top, double? bottom}) => Positioned(
              left: left, right: right, top: top, bottom: bottom,
              child: Container(width: w, height: h, decoration: BoxDecoration(color: Colors.white.withOpacity(a), borderRadius: BorderRadius.circular(h / 2))));
          return Container(
            width: 96,
            height: 190,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3A3A37)),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF31503A), Color(0xFF0B0B0B)]),
            ),
            child: Stack(children: [
              bar(30, 7, .4, right: 5, top: 6),
              bar(46, 12, .4, left: 5, top: 18),
              bar(26, 10, .55, right: 5, top: 18),
              if (d.coins) bar(40, 9, .45, left: 5, top: 34),
              if (d.messages) bar(58, 10, .25, left: 5, bottom: 34),
              bar(86, 14, .3, left: 5, bottom: 8),
            ]),
          );
        }

        final notes = {
          'essential': context.tr('« Essentiel » replie les compteurs en une seule pastille (spectateurs), garde les pièces reçues et le classement, et laisse le reste à un toucher de distance.'),
          'complete': context.tr('« Complet » montre aussi les « j\'aime » et les partages sous leurs boutons.'),
          'shop': context.tr('« Vente » libère l\'image pour tes produits : ni pièces ni compteurs, seulement les messages.'),
          'duel': context.tr('« Duel » garde les compteurs utiles pour un défi : « j\'aime », partages, pièces reçues et messages.'),
          'clean': context.tr('« Épuré » ne laisse que la pastille des spectateurs : l\'image est libre.'),
          'custom': context.tr('Réglage personnalisé.'),
        };
        return Container(
          padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(ctx).padding.bottom + 18),
          decoration: const BoxDecoration(color: Color(0xFF1A1A1A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF4A4A46), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              Text(context.tr('Affichage du live'), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                context.tr('Choisis ce que tes spectateurs voient à l\'écran. Plus il y a de compteurs, moins l\'image est libre. Les gains restent toujours visibles pour toi dans « Menu ».'),
                style: const TextStyle(color: Color(0xFFCFCFCA), fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 11),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final p in LiveDisplay.presets)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: GestureDetector(
                        onTap: () => setSheet(() => d = LiveDisplay.byName(p)),
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: d.preset == p ? const Color(0xFF2A2312) : const Color(0xFF242424),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(color: d.preset == p ? const Color(0xFFF9A825) : const Color(0xFF3A3A37), width: d.preset == p ? 2 : 1),
                          ),
                          child: Text(context.tr(LiveDisplay.label(p)), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 11),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                preview(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(children: [
                    row(context.tr('Spectateurs'), context.tr('Toujours affiché, en petit'), true, null),
                    row(context.tr('J\'aime et partages'), context.tr('Sous les boutons, jamais en double'), d.reactions, (v) => setSheet(() => d = d.copyWith(reactions: v))),
                    row(context.tr('Pièces reçues et classement'), context.tr('Une seule fois, sous le profil'), d.coins, (v) => setSheet(() => d = d.copyWith(coins: v))),
                    row(context.tr('Messages'), null, d.messages, (v) => setSheet(() => d = d.copyWith(messages: v))),
                  ]),
                ),
              ]),
              const SizedBox(height: 11),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(12)),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: context.tr('Réglé pour toi : '), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  TextSpan(text: notes[d.preset] ?? notes['custom']!, style: const TextStyle(color: Color(0xFFCFCFCA))),
                ]), style: const TextStyle(fontSize: 12, height: 1.45)),
              ),
              const SizedBox(height: 11),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _saveDisplay(d);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF9A825), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                  child: Text(context.tr('Enregistrer'), style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // ==================== BILLET : MINUTES D'AGORA ====================

  /// Pièces du solde de la personne (affichées dans le rappel).
  int get _myCoins => authProvider.loginUserData.giftCoinsBalance ?? 0;

  /// Ce qui couvre le spectateur a changé (réponse du jeton) : lance le minuteur, ou l'arrête quand le gratuit dure encore.
  void _applyTicket(LiveTicket? t) {
    if (!mounted || widget.isHost || _shouldSkipTrial()) return;
    _ticket = t;
    _ticketTimer?.cancel();
    if (t?.endsAt == null) {
      setState(() {
        _ticketSecondsLeft = 1 << 30;
        _ticketRequired = false;
      });
      return;
    }
    if (t!.by == 'ticket' || t.by == 'offered') {
      _hadPaidTicket = true;
      if (_showTrialOverlay) {
        _trialTimer?.cancel();
        _removeRestrictions();
      }
    }
    if (t.audioOnly) {
      // « son seul » : la vidéo reçue est coupée (Agora facture alors l'audio seul)
      try {
        if (!_noCam) _engine.muteAllRemoteVideoStreams(true);
      } catch (_) {}
    }
    setState(() {
      _ticketSecondsLeft = t.secondsLeft;
      _ticketRequired = false;
    });
    if (_ticketOffer == null) {
      // le prix du billet sert au rappel de la dernière minute
      LivesApi.get(widget.liveId).then((l) {
        final o = LiveTicketOffer.fromLive(l);
        if (o != null && mounted) setState(() => _ticketOffer = o);
      }).catchError((_) {});
    }
    _ticketTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final s = _ticket?.secondsLeft ?? (1 << 30);
      setState(() => _ticketSecondsLeft = s);
      if (s <= 0) {
        timer.cancel();
        _onTicketExpired();
      }
    });
  }

  /// Le serveur demande un billet (402 `ticket_required`) : prix lus dans la réponse, écran « billet à payer ».
  void _showTicketRequired(Map<String, dynamic> details) {
    if (!mounted) return;
    _ticketTimer?.cancel();
    setState(() {
      _ticketOffer = LiveTicketOffer.fromDetails(details) ?? _ticketOffer;
      _ticketSecondsLeft = 0;
      _ticketRequired = true;
    });
  }

  /// Fin du billet, de l'essai ou du passe : on quitte le canal tout de suite (Afrolook ne paie jamais Agora au-delà du gratuit) et on propose le billet.
  Future<void> _onTicketExpired() async {
    if (_ticketRequired || _endHandled || widget.isHost) return;
    try {
      if (!_noCam) await _engine.leaveChannel();
      _ticketLeftChannel = true;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _remoteUid = null;
      _ticketRequired = true;
    });
    if (_ticketOffer == null) {
      try {
        _ticketOffer = LiveTicketOffer.fromLive(await LivesApi.get(widget.liveId));
        if (mounted) setState(() {});
      } catch (_) {}
    }
  }

  /// Battement du spectateur toutes les 45 s : le serveur compte ses minutes, et répond 402 dès que son billet est fini.
  void _startWatchTimer() {
    if (widget.isHost || _shouldSkipTrial() || (_watchTimer?.isActive ?? false)) return;
    _watchTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
      if (!mounted || _ticketRequired || _ticketLeftChannel) return;
      try {
        final r = await LivesApi.watch(widget.liveId);
        final t = LiveTicketOffer.fromLive({'me': {'ticket': r['ticket']}});
        if (t != null && mounted) _ticketOffer = t;
      } on ApiException catch (e) {
        if (e.status == 402 && e.code == 'ticket_required') _showTicketRequired(e.details);
        if (e.status == 410 && !widget.isHost) await _onLiveEndedRemotely();
      } catch (_) {}
    });
  }

  /// Paie un billet (« son seul » : [audio] vrai). Rejoint le canal s'il avait été quitté, sinon renouvelle le jeton pour prolonger.
  Future<void> _payTicket({bool audio = false}) async {
    final o = _ticketOffer;
    if (o == null || _ticketBusy) return;
    _ticketBusy = true;
    try {
      final ok = await CoinCheckout.pay(context,
          kind: 'live_ticket',
          refId: widget.liveId,
          coins: audio ? o.audioCoins : o.coins,
          label: audio ? context.tr('Billet « son seul »') : context.tr('Billet de live'),
          audio: audio ? true : null);
      if (!ok || !mounted) return;
      _hadPaidTicket = true;
      _trialTimer?.cancel();
      _removeRestrictions();   // ferme « Temps d'essai écoulé » s'il était resté ouvert, rend le son et l'image
      if (!_isInitialized || _ticketLeftChannel) {
        _ticketLeftChannel = false;
        await _joinAfterPayment();   // redemande le jeton (qui porte la fin du billet) et rejoint
      } else {
        final r = await LivesApi.token(widget.liveId, uid: 0, role: 'audience');
        await _engine.renewToken(r['token'] as String);
        _applyTicket(LiveTicket.fromToken(r['ticket']));
      }
      if (mounted) {
        setState(() {
          _ticketRequired = false;
          _showTrialOverlay = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Billet payé : bon live !'))));
      }
    } catch (e) {
      printVm("❌ Erreur paiement du billet: $e");
    } finally {
      _ticketBusy = false;
    }
  }

  // ---- hôte : frais de diffusion (mode billet) ----

  /// Lit les frais de diffusion de l'hôte (live démarré en mode billet) et surveille leur échéance.
  Future<void> _initHostFee() async {
    if (!widget.isHost) return;
    try {
      final live = await LivesApi.get(widget.liveId);
      final me = live['me'];
      _setHostFee(LiveHostFee.fromJson(me is Map ? me['host_fee'] : null));
    } catch (_) {}
  }

  void _setHostFee(LiveHostFee? fee) {
    if (!mounted) return;
    _hostFeeTimer?.cancel();
    setState(() => _hostFee = fee);
    if (fee == null) return;
    _hostFeeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _hostFee == null) return;
      if (_hostFee!.secondsLeft <= 61) setState(() {});   // n'actualise l'écran que pour le rappel (dernière minute)
    });
  }

  /// L'hôte paie 15 minutes de frais de diffusion de plus.
  Future<void> _payHostFee() async {
    final f = _hostFee;
    if (f == null || _hostFeeBusy) return;
    _hostFeeBusy = true;
    try {
      final ok = await CoinCheckout.pay(context, kind: 'live_host_fee', refId: widget.liveId, coins: f.coins, label: context.tr('Frais de diffusion'));
      if (!ok || !mounted) return;
      final live = await LivesApi.get(widget.liveId);
      final me = live['me'];
      _setHostFee(LiveHostFee.fromJson(me is Map ? me['host_fee'] : null));
    } catch (e) {
      printVm("❌ Erreur paiement des frais de diffusion: $e");
    } finally {
      _hostFeeBusy = false;
    }
  }

  /// Rappel affiché une minute avant la fin d'un billet, d'un essai ou des frais de diffusion : même style que les boutons du live.
  Widget _buildTicketReminder() {
    final host = widget.isHost;
    final left = host ? (_hostFee?.secondsLeft ?? 1 << 30) : _ticketSecondsLeft;
    if (left > 60 || left <= 0 || (!host && (_ticketRequired || _ticketOffer == null))) return const SizedBox.shrink();
    final coins = host ? (_hostFee?.coins ?? 0) : (_ticketOffer?.coins ?? 0);
    final minutes = _ticketOffer?.minutes ?? 15;
    final byTrial = !host && _ticket?.by == 'trial';
    final title = host
        ? context.tr('Frais de diffusion : il reste {s} secondes', {'s': '$left'})
        : byTrial
            ? context.tr('Il reste {s} secondes d\'essai gratuit', {'s': '$left'})
            : context.tr('Il reste {s} secondes sur ton billet', {'s': '$left'});
    final body = host
        ? context.tr('Sans paiement, ton live s\'arrête. Payer {p} pièces ajoute 15 minutes. Ton solde : {b} pièces.', {'p': CoinCheckout.fmt(coins), 'b': CoinCheckout.fmt(_myCoins)})
        : byTrial
            ? context.tr('Ensuite, un billet de {p} pièces pour continuer {m} minutes. Ton solde : {b} pièces.', {'p': CoinCheckout.fmt(coins), 'm': '$minutes', 'b': CoinCheckout.fmt(_myCoins)})
            : context.tr('Prolonge de {m} minutes pour {p} pièces. Ton solde : {b} pièces.', {'p': CoinCheckout.fmt(coins), 'm': '$minutes', 'b': CoinCheckout.fmt(_myCoins)});
    final payLabel = host
        ? context.tr('Payer : {p} pièces', {'p': CoinCheckout.fmt(coins)})
        : byTrial
            ? context.tr('Payer maintenant : {p} pièces', {'p': CoinCheckout.fmt(coins)})
            : context.tr('Prolonger : {p} pièces', {'p': CoinCheckout.fmt(coins)});
    return Positioned(
      left: 16,
      right: 16,
      bottom: 128,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.78),
          border: Border.all(color: const Color(0xFFF9A825)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(body, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: host ? _payHostFee : _payTicket,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9A825),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: Text(payLabel, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: host ? _endLive : _leaveLive,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: Text(host ? context.tr('Terminer') : context.tr('Quitter'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  /// Écran « billet à payer » : même fond, même icône et mêmes boutons que l'écran d'essai écoulé ; seuls les textes et le prix changent.
  Widget _buildTicketOverlay() {
    final o = _ticketOffer;
    final coins = o?.coins ?? 0;
    final minutes = o?.minutes ?? 15;
    return Container(
      color: Colors.black.withOpacity(0.8),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock, size: 64, color: Color(0xFFF9A825)),
            const SizedBox(height: 20),
            Text(
              _hadPaidTicket ? context.tr('Billet terminé') : context.tr('Temps d\'essai écoulé'),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              o == null
                  ? context.tr('Chargement du prix du billet…')
                  : context.tr('Les minutes gratuites du mois sont épuisées. Payez {p} pièces pour continuer à regarder pendant {m} minutes.', {'p': CoinCheckout.fmt(coins), 'm': '$minutes'}),
              style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: o == null ? null : () => _payTicket(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF9A825),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: Text(
                context.tr('Payer le billet : {p} pièces', {'p': CoinCheckout.fmt(coins)}),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            if (o != null && !o.isAudioRoom) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _payTicket(audio: true),
                child: Text(context.tr('Son seul : {p} pièces', {'p': CoinCheckout.fmt(o.audioCoins)}),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 6),
            TextButton(
              onPressed: _leaveLive,
              child: Text(context.tr('Quitter le live'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
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

      // Paiement en pièces (serveur) : débit, 70 % à l'hôte en Pièces gagnées, parrainages, part de l'app
      final paymentSuccess = await CoinCheckout.pay(context,
          kind: 'live_entry',
          refId: widget.liveId,
          coins: widget.postLive.participationFeeCoins,
          label: tr('Accès au live privé'));

      if (paymentSuccess) {

        // L'entrée payée est enregistrée par le serveur (paiement en pièces) : rien à écrire ici.
        _trialTimer?.cancel();
        _removeRestrictions();
        setState(() {
          _remainingTrialMinutes = 999;
          _remainingTrialSeconds = 0;
          _showTrialOverlay = false;
        });
        // Entrée payée : le jeton avait été refusé à la fin de l'essai, on le redemande (l'essai vaut alors `null`) et on rejoint.
        if (!_isInitialized) await _joinAfterPayment();

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Accès au live activé !')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      printVm("❌ Erreur paiement participation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Erreur lors du paiement')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Après le paiement de l'entrée : redemande le jeton à l'API et rejoint le canal (le premier jeton avait été refusé en 402).
  Future<void> _joinAfterPayment() async {
    try {
      final token = await _getAgoraToken(channelName: widget.liveId, uid: 0, isHost: false);
      if (token == null) return;
      await _engine.joinChannel(
        token: token,
        channelId: widget.liveId,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleAudience,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
      _joinAsSpectator();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      printVm("❌ Erreur reconnexion après paiement: $e");
    }
  }

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
          onTokenPrivilegeWillExpire: (connection, token) => _renewAgoraToken(connection.localUid),
          onRequestToken: (connection) => _renewAgoraToken(connection.localUid),
          onJoinChannelSuccess: (connection, elapsed) {
            printVm("✅ Rejoint le canal avec succès - UID: ${connection.localUid}");
            setState(() => _localUserJoined = true);
            // l'hôte et les personnes sur scène indiquent leur numéro Agora : les autres savent quelle vignette est la leur
            final u = connection.localUid;
            if (u != null && u > 0 && (widget.isHost || _isParticipant)) {
              _myAgoraUid = u;
              LivesApi.stageUid(widget.liveId, u).catchError((_) {});
            }
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            printVm("👤 Utilisateur rejoint: $remoteUid");
            setState(() {
              _remoteUids.add(remoteUid);
              _refreshMainUid();
            });
          },
          onUserOffline: (connection, remoteUid, reason) {
            printVm("👋 Utilisateur parti: $remoteUid");
            setState(() {
              _remoteUids.remove(remoteUid);
              _refreshMainUid();
            });
          },
          onCameraReady: () {
            printVm("📷 Caméra prête");
          },
          onAudioVolumeIndication: (connection, speakers, speakerNumber, totalVolume) {
            if (!mounted) return;
            final now = <int>{for (final s in speakers) if ((s.volume ?? 0) > 25) (s.uid ?? 0)};
            if (now.length == _speakingUids.length && now.containsAll(_speakingUids)) return;
            setState(() => _speakingUids
              ..clear()
              ..addAll(now));
          },
          onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
            printVm("📹 État vidéo UID $remoteUid: $state ($reason)");
            if (!mounted) return;
            setState(() {
              if (state == RemoteVideoState.remoteVideoStateDecoding) {
                _remoteVideoOn.add(remoteUid);
              } else if (state == RemoteVideoState.remoteVideoStateStopped || state == RemoteVideoState.remoteVideoStateFailed) {
                _remoteVideoOn.remove(remoteUid);
              }
            });
          },
        ),
      );

      if (widget.postLive.audioOnly) {
        await _engine.disableVideo();   // salon audio : que des voix, Agora ne facture que l'audio
      } else {
        await _engine.enableVideo();
      }
      // qui parle : le moteur signale le volume de chaque voix (animation sur les vignettes, pour l'hôte comme pour tous)
      try {
        await _engine.enableAudioVolumeIndication(interval: 400, smooth: 3, reportVad: true);
      } catch (_) {}
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

      if (!widget.postLive.audioOnly && (widget.isHost || (_isParticipant && _myStageMedia == 'video'))) {
        await _engine.startPreview();
        if (_beautyOn) await _applyBeauty();
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
          publishCameraTrack: !widget.postLive.audioOnly && (widget.isHost || (_isParticipant && _myStageMedia == 'video')),
          publishMicrophoneTrack: widget.isHost || _isParticipant,
          autoSubscribeAudio: true,
          autoSubscribeVideo: !_ticketAudioOnly && !widget.postLive.audioOnly,   // billet « son seul » : aucune vidéo reçue (Agora facture alors l'audio seul)
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
          onTokenPrivilegeWillExpire: (connection, token) => _renewAgoraToken(connection.localUid),
          onRequestToken: (connection) => _renewAgoraToken(connection.localUid),
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
            printVm("📹 État vidéo UID $remoteUid: $state ($reason)");
            if (!mounted) return;
            setState(() {
              if (state == RemoteVideoState.remoteVideoStateDecoding) {
                _remoteVideoOn.add(remoteUid);
              } else if (state == RemoteVideoState.remoteVideoStateStopped || state == RemoteVideoState.remoteVideoStateFailed) {
                _remoteVideoOn.remove(remoteUid);
              }
            });
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
        if (_beautyOn) await _applyBeauty();
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
      // Jeton généré par l'API : refusé sur un live payant sans entrée payée (402 entry_required)
      _tokenAsHost = isHost;
      final result = await LivesApi.token(widget.liveId, uid: uid, role: isHost ? 'host' : 'audience');
      // Pendant l'essai, la réponse porte `trial` : on recale le compte à rebours sur le serveur (le chrono démarre ici).
      final trial = LiveTrial.fromJson(result['trial']);
      if (trial != null && !trial.expired) _applyTrial(trial);
      if (!isHost) {
        _applyTicket(LiveTicket.fromToken(result['ticket']));
        _startWatchTimer();
      }
      return result['token'] as String;
    } catch (e) {
      printVm("❌ Erreur récupération token Agora: $e");
      if (e is ApiException && e.status == 402 && e.code == 'ticket_required' && mounted) {
        // Gratuit du mois épuisé et pas de billet : écran « billet à payer »
        _showTicketRequired(e.details);
      } else if (e is ApiException && e.status == 402 && mounted) {
        // Essai gratuit terminé côté serveur (`details.trial` : seconds_left 0, expired vrai) : entrée à payer
        _applyTrial(LiveTrial.fromJson(e.details['trial']) ??
            const LiveTrial(minutes: 0, secondsLeft: 0, expired: true));
      } else if (e is ApiException && e.status == 410 && mounted && !isHost) {
        _onLiveEndedRemotely();
      } else if (mounted && !_ticketRequired) {
        setState(() => _joinError = e is ApiException && e.message.isNotEmpty ? e.message : tr('Connexion au live impossible pour le moment. Vérifie ta connexion et réessaie.'));
      }
      return null;
    }
  }

  // ==================== PARTAGE D'ÉCRAN ====================

  Future<void> _toggleScreenSharing() async {
    await _confirmAction(
      _isScreenSharing ? tr("arrêter le partage d'écran") : tr("partager l'écran"),
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
      // l'hôte peut quitter l'application pour partager un autre écran : le serveur ne termine pas le live pour inactivité tant qu'il partage
      if (widget.isHost) LivesApi.update(widget.liveId, {'screen_sharing': true}).catchError((_) => <String, dynamic>{});
      await _updateScreenSharingState(isSharing: true, sharerId: ApiIdentity.myId!);
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
      if (widget.isHost) LivesApi.update(widget.liveId, {'screen_sharing': false}).catchError((_) => <String, dynamic>{});
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
      _isMicrophoneMuted ? tr("activer le micro") : tr("désactiver le micro"),
          () async {
        if (!(widget.isHost || _isParticipant)) return;
        if (!widget.isHost && _hostMutedMe && _isMicrophoneMuted) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('L\'hôte a coupé ton micro : demande-lui de le rétablir.'))));
          return;
        }

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
      tr("changer de caméra"),
          () async {
        try {
          if (_numberOfCameras < 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('Une seule caméra disponible'))),
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


  /// Les cœurs des autres viennent du compteur du live (`_onLikeCountChanged`) : plus fiable que l'écoute de la collection `live_likes`, qui ne répondait pas toujours.
  void _setupLikesListener() {}




  void _sendComment(String message, {String type = 'text', String? giftId, String? voiceNoteId, int? voiceSeconds}) {
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
          'userId': (ApiIdentity.myId ?? user.uid),
          'username': authProvider.loginUserData.pseudo ?? 'Utilisateur',
          'userImage': authProvider.loginUserData.imageUrl ?? '',
          'message': message,
          'timestamp': DateTime.now(),
          'type': type,
          'giftId': giftId,
          if (voiceNoteId != null) 'voiceNoteId': voiceNoteId,
          if (voiceSeconds != null) 'voiceSeconds': voiceSeconds,
        });
      }
    } catch (e) {
      printVm("❌ Erreur envoi commentaire: $e");
    }
  }

  Gift? _lastGift;   // dernier cadeau envoyé : seul raccourci affiché sous le chat (garde la vue des messages dégagée)

  void _toast(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 3)));
  }

  Future<void> _loadRecentGifts() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (mounted) setState(() => _recentGiftIds = p.getStringList('live_recent_gifts') ?? []);
    } catch (_) {}
  }

  Future<void> _rememberGift(Gift gift) async {
    _recentGiftIds = [gift.id, ..._recentGiftIds.where((x) => x != gift.id)].take(8).toList();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('live_recent_gifts', _recentGiftIds);
    } catch (_) {}
  }

  void _showGiftEffect(Gift gift) {
    setState(() {
      _giftEffects.add(GiftEffect(id: DateTime.now().millisecondsSinceEpoch, gift: gift, x: Random().nextDouble() * 0.6 + 0.2));
      _showGiftPanel = false;
    });
  }

  Future<void> _sendGift(Gift gift) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      // l'hôte ne peut pas s'offrir un cadeau (règle du serveur) : on lui montre l'animation, et on le lui dit
      if (widget.isHost) {
        _showGiftEffect(gift);
        _toast(tr('Aperçu : tu es l\'hôte, rien n\'est envoyé. Tes spectateurs te l\'offriront.'));
        return;
      }
      if (mounted) setState(() => _lastGift = gift);

      final coinsAmount = gift.price.toInt();

      // Débit, 70 % à l'hôte, parrainages et part de l'app : calculés par le serveur (sendLiveGift)
      try {
        await LivesApi.gift(widget.liveId, coins: coinsAmount, icon: gift.icon, label: gift.name, targetId: (_game?.active == true && _game!.isMatch) ? (_giftTarget ?? widget.postLive.hostId) : null);
      } on ApiException catch (e) {
        if (e.isInsufficientCoins) {
          if (mounted) await CoinCheckout.insufficient(context, coinsAmount);
          return;
        }
        // chaque refus est expliqué (live terminé, compte à vérifier, hôte…) : un toucher ne reste jamais sans réponse
        printVm('❌ Cadeau refusé : ${e.code} ${e.message}');
        _toast(e.code == 'email_unverified' ? tr('Vérifie ton adresse e-mail pour envoyer des cadeaux.') : e.message);
        return;
      }
      if (mounted) CoinCheckout.refreshBalance(context);
      _rememberGift(gift);

      _sendComment(
        'a envoyé ${gift.name} ${gift.icon} ($coinsAmount pcs)',
        type: 'gift',
        giftId: gift.id,
      );
      _showGiftEffect(gift);
    } catch (e) {
      printVm('❌ Erreur envoi cadeau: $e');
      _toast(tr('Le cadeau n\'a pas pu être envoyé. Vérifie ta connexion et réessaie.'));
    }
  }

  // ==================== GESTION FIREBASE STREAM ====================

  void _setupFirestoreListeners() {
    _liveSubscription = _firestore.collection('lives').doc(widget.liveId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        if (data['isLive'] == false && !_endHandled) {
          _confirmEndedBeforeLeaving();
          return;
        }
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

        _onLikeCountChanged((data['likeCount'] as num?)?.toInt() ?? 0);
        if (data['pin'] is Map) {
          final pm = data['pin'] as Map;
          _pinPlace = '${pm['place'] ?? 'left'}' == 'right' ? 'right' : 'left';
          _pinLayout = '${pm['layout'] ?? 'side'}' == 'below' ? 'below' : 'side';
        }
        _pinnedTextDoc = data['pinnedText'] as String?;
        _pinnedTextFromDoc = true;
        if (data.containsKey('music')) {
          final mm = data['music'];
          _syncMusic(mm is Map ? Map<String, dynamic>.from(mm) : null);
        }
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
          _pinnedImageUrl = data['pinnedImageUrl'] as String?;
          if (data['display'] is Map) _display = LiveDisplay.fromJson(data['display']);
          _topDonors = topDonors;
          final currentUserId = ApiIdentity.myId;
          _isParticipant = _onStageApi || (currentUserId != null && _participants.contains(currentUserId));
        });
      }

      // Muter les flux audio si le live est en pause
      if (_isLivePaused && !widget.isHost) {
        if (!_noCam) _engine.muteAllRemoteAudioStreams(true);
      } else if (!_isLivePaused && !widget.isHost) {
        if (!_noCam) _engine.muteAllRemoteAudioStreams(false);
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
      // live sans caméra : les commentaires NOUVEAUX sont une interaction ; l'hôte les signale tout de suite (au plus toutes les 20 s) pour relancer le décompte d'inactivité
      if (_noCam) {
        if (_commentsFirst) {
          _commentsFirst = false;
        } else {
          final added = snapshot.docChanges.where((c) => c.type == DocumentChangeType.added).length;
          if (added > 0) {
            _commentsTotal += added;
            if (widget.isHost && DateTime.now().difference(_lastCommentBeat).inSeconds >= 20) {
              _lastCommentBeat = DateTime.now();
              _sendHeartbeat();
            }
          }
        }
      }
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
      _firestore.collection('live_typing').doc(ApiIdentity.myId ?? user.uid).set({
        'liveId': widget.liveId,
        'userId': (ApiIdentity.myId ?? user.uid),
        'username': authProvider.loginUserData.pseudo ?? 'Utilisateur',
        'timestamp': DateTime.now(),
      });
    }
  }

  void _stopTyping() {
    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection('live_typing').doc(ApiIdentity.myId ?? user.uid).delete();
    }
  }

  // ==================== GESTION UTILISATEURS ====================

  Future<void> _fetchHostData() async {
    try {
      final host = userFromApi(await UsersApi.publicProfile(widget.postLive.hostId!));
      if (mounted) {
        setState(() {
          _hostData = host;
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
      final profiles = await UsersApi.lookup(allUserIds.toList());
      final List<UserData> users = profiles.map((j) => userFromApi(j)).toList();

      if (mounted) setState(() => _allUsers = users);
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
        await liveProvider.joinAsParticipant(widget.liveId, ApiIdentity.myId!);
        setState(() => _isParticipant = true);
        await _reinitializeAgora();
        await _grantFreeAccess();
        return;
      }

      // Paiement en pièces (serveur)
      final paymentSuccess = await CoinCheckout.pay(context,
          kind: 'live_participant', refId: widget.liveId, priceFcfa: 100, label: 'Participer au live');

      if (paymentSuccess) {
        await liveProvider.joinAsParticipant(widget.liveId, ApiIdentity.myId!);
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
        // await liveProvider.joinAsSpectator(widget.liveId, ApiIdentity.myId!);
        await _grantFreeAccess();
        // return;
      }

      await liveProvider.joinAsSpectator(widget.liveId, ApiIdentity.myId!);
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

  void _confirmEndLive() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(tr('Terminer le live?'), style: TextStyle(color: Colors.white)),
          content: Text(tr('Voulez-vous vraiment terminer votre live ? Les spectateurs seront déconnectés et les commandes en cours resteront à traiter.'), style: TextStyle(color: Colors.white70)),
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

  void _startHeartbeat() {
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) => _sendHeartbeat());
  }

  /// Termine le live à la fin de sa durée (la vidéo est facturée à la minute), avec un avertissement 2 minutes avant et la possibilité de PAYER pour continuer.
  void _startDurationLimit() {
    _durationTimer = Timer.periodic(const Duration(seconds: 15), (t) {
      if (!mounted || _endHandled) { t.cancel(); return; }
      final endAt = widget.postLive.startTime.add(Duration(minutes: _liveMinutes));
      final remaining = endAt.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        t.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Durée maximale atteinte ({m} min) : fin du live.', {'m': '$_liveMinutes'}))),
        );
        _endLive();
      } else if (remaining <= const Duration(minutes: 2) && !_durationWarned) {
        _durationWarned = true;
        _offerExtension();
      }
    });
  }

  /// Hôte : toutes les 20 secondes, regarde s'il y a de nouveaux vocaux de spectateurs ; alerte discrète + pastille sur le menu.
  void _startVoiceWatch() {
    _voiceTimer = Timer.periodic(const Duration(seconds: 20), (t) async {
      if (!mounted || _endHandled) { t.cancel(); return; }
      try {
        final s = await LivesApi.voiceStatus(widget.liveId);
        final n = (s['new_count'] as num?)?.toInt() ?? 0;
        if (!mounted) return;
        if (n > _voiceNew) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(context.tr("Nouveau vocal d'un spectateur : ouvre le menu du live.")),
          ));
        }
        if (n != _voiceNew) setState(() => _voiceNew = n);
      } catch (_) {}
    });
  }

  /// À 2 minutes de la fin : proposer de continuer en payant (prix, durée et nombre de prolongations fixés par le serveur).
  Future<void> _offerExtension() async {
    if (_extensionOffered || !mounted) return;
    _extensionOffered = true;
    try {
      final lim = await LivesApi.limits();
      final ext = Map<String, dynamic>.from(lim['extension'] as Map? ?? {});
      final live = await LivesApi.get(widget.liveId);
      final used = (live['extensions_count'] as num?)?.toInt() ?? 0;
      final max = (ext['max'] as num?)?.toInt() ?? 0;
      int coins = (ext['coins'] as num?)?.toInt() ?? 0;
      try {
        coins = await WalletApi.instance.quote('live_extension', refId: widget.liveId);   // prix du moment : il suit le nombre de spectateurs
      } catch (_) {}
      final minutes = (ext['minutes'] as num?)?.toInt() ?? 60;
      if (!mounted) return;
      if (ext['free'] == true || used >= max || coins <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 6),
          backgroundColor: Colors.orange,
          content: Text(context.tr('Ton live se termine dans 2 minutes (durée maximale : {m} min).', {'m': '$_liveMinutes'})),
        ));
        return;
      }
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('Ton live arrive à sa fin')),
          content: Text(ctx.tr('Il se termine dans 2 minutes. Continue encore {m} min pour {p}.', {'m': '$minutes', 'p': CoinCheckout.coinsLabel(coins)})),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Terminer à l\'heure'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Prolonger'))),
          ],
        ),
      );
      if (go != true || !mounted) return;
      final ok = await CoinCheckout.pay(context, kind: 'live_extension', refId: widget.liveId, coins: coins, label: context.tr('Prolonger le live'));
      if (!ok || !mounted) return;
      final fresh = await LivesApi.get(widget.liveId);
      setState(() {
        _durationOverride = (fresh['duration_minutes'] as num?)?.toInt() ?? (_liveMinutes + minutes);
        _durationWarned = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Live prolongé de {m} min.', {'m': '$minutes'}))));
    } catch (e) {
      printVm('⚠️ Prolongation impossible : $e');
    } finally {
      _extensionOffered = false;
    }
  }

  /// Le jeton Agora s'arrête à la fin prévue du live : on en redemande un avant l'échéance (accordé tant que le live n'est pas fini, prolongations comprises).
  Future<void> _renewAgoraToken(int? uid) async {
    if (_endHandled) return;
    try {
      final r = await LivesApi.token(widget.liveId, uid: uid ?? 0, role: _tokenAsHost ? 'host' : 'audience');
      await _engine.renewToken(r['token'] as String);
      if (!_tokenAsHost) _applyTicket(LiveTicket.fromToken(r['ticket']));
    } on ApiException catch (e) {
      if (e.status == 410 && mounted && !widget.isHost) await _onLiveEndedRemotely();
      if (e.status == 402 && e.code == 'ticket_required' && mounted && !widget.isHost) _showTicketRequired(e.details);
    } catch (e) {
      printVm('⚠️ Renouvellement du jeton impossible : $e');
    }
  }

  bool _checkingEnd = false;
  DateTime? _apiSaysLiveUntil;

  /// Firestore dit « terminé » : on demande à l'API, qui fait foi (elle termine seule un live sans signal). Si elle dit « en direct », l'état Firestore est faux
  /// (reste d'un ancien arrêt, application fermée…) : l'hôte le répare au lieu d'être renvoyé sur le bilan (live « fantôme » qui bloquait la création d'un nouveau live).
  Future<void> _confirmEndedBeforeLeaving() async {
    if (_endHandled || _checkingEnd) return;
    final until = _apiSaysLiveUntil;
    if (until != null && DateTime.now().isBefore(until)) return;   // vérifié il y a moins d'une minute : on ne redemande pas
    _checkingEnd = true;
    try {
      final l = await LivesApi.get(widget.liveId);
      if (l['is_live'] == true) {
        _apiSaysLiveUntil = DateTime.now().add(const Duration(minutes: 1));
        if (widget.isHost) {
          try {
            await _firestore.collection('lives').doc(widget.liveId).update({'isLive': true, 'endTime': FieldValue.delete()});
          } catch (_) {}
        }
        return;
      }
    } catch (_) {
      // API injoignable : on garde l'ancien comportement (fin du live)
    } finally {
      _checkingEnd = false;
    }
    if (mounted && !_endHandled) await _onLiveEndedRemotely();
  }

  /// Le live a été terminé ailleurs (durée maximale, inactivité, nouveau live de l'hôte).
  Future<void> _onLiveEndedRemotely() async {
    if (_endHandled) return;
    _endHandled = true;
    try {
      context.read<LiveProvider>().removeLive(widget.liveId);   // il ne doit plus apparaître « en direct » dans les listes ni dans le fil
    } catch (_) {}
    _durationTimer?.cancel();
    _heartbeatTimer?.cancel();
    try {
      if (!_noCam) await _engine.leaveChannel();
    } catch (_) {}
    if (!mounted) return;
    if (widget.isHost) {
      _showLiveEndStats();
      return;
    }
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Live terminé')),
        content: Text(tr('Ce live est terminé. Merci d\'avoir regardé !')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  void _sendHeartbeat() {
    _firestore.collection('lives').doc(widget.liveId).update({
      'lastHeartbeatAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
    if (widget.isHost) {
      // l'API termine un live sans signal ; en mode billet elle rappelle aussi l'échéance des frais de diffusion
      LivesApi.heartbeat(widget.liveId, viewers: _viewerCount, likes: _likeCount, comments: _noCam ? _commentsTotal : null).then((r) {
        if (_noCam) _setIdle(r['idle_seconds_left']);
        final fee = LiveHostFee.fromJson(r['host_fee']);
        if (fee != null) _setHostFee(fee);
      }).catchError((_) {});
    }
  }

  void _endLive() async {
    if (_endHandled) return;
    _endHandled = true;
    _durationTimer?.cancel();
    try {
      if (widget.isHost) {
        try {
          await LivesApi.end(widget.liveId);
        } catch (_) {}
      }
      await _firestore.collection('lives').doc(widget.liveId).update({
        'isLive': false,
        'endTime': DateTime.now(),
      });

      if (!_noCam) await _engine.leaveChannel();
      if (!_noCam) await _engine.release();

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

  /// Fin du live de l'hôte : bilan complet (gains, chiffres, plus généreux), à la place de l'ancienne fenêtre.
  void _showLiveEndStats() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => LiveReportPage(liveId: widget.liveId, fallbackCoins: _giftCoinsTotal, fallbackTitle: widget.postLive.title),
    ));
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
    if (widget.isHost) {
      _confirmHostExit();   // l'hôte confirme d'abord : rester, quitter en pause ou terminer
      return;
    }
    try {
      if (!widget.isHost) {
        await _firestore.collection('lives').doc(widget.liveId).update({
          'viewerCount': FieldValue.increment(-1),
          'spectators': FieldValue.arrayRemove([ApiIdentity.myId!]),
        });
      }
      Navigator.pop(context);
    } catch (e) {
      printVm("❌ Erreur sortie live: $e");
    }
  }

  Future<void> _reinitializeAgora() async {
    try {
      // les vues vidéo (aperçu de l'invité, vignettes) sont retirées AVANT de libérer le moteur, puis recréées sur le nouveau : sinon elles restent liées à l'ancien et l'aperçu reste vide
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _remoteVideoOn.clear();
          _speakingUids.clear();
        });
      }
      _remoteUids.clear();
      _remoteUid = null;
      if (!_noCam) await _engine.leaveChannel();
      if (!_noCam) await _engine.release();
      await _initAgora();
      // mon micro reste coupé si l'hôte l'a coupé
      _isMicrophoneMuted = _hostMutedMe;
      if (_hostMutedMe && _isInitialized) await _engine.muteLocalAudioStream(true);
    } catch (e) {
      printVm("❌ Erreur réinitialisation Agora: $e");
    }
  }

  void _shareLive() {
    showResponsiveBottomSheet(
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
            Text(tr('Partager ce live'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
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
              title: Text(tr('Envoyer dans un chat'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: Text(tr('Conversations ou groupes'), style: TextStyle(color: Colors.white54, fontSize: 12)),
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
              title: Text(tr('Partager le lien'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: Text(tr('WhatsApp, réseaux sociaux...'), style: TextStyle(color: Colors.white54, fontSize: 12)),
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
    showResponsiveBottomSheet(
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
  Widget build(BuildContext context) => PopScope(
        // l'hôte n'est jamais sorti d'un coup : « Quitter, je reviens » ou « Terminer le live » (le live ne se coupe plus tout seul à la sortie)
        canPop: !widget.isHost || _endHandled || _awayMarked,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmHostExit();
        },
        child: _buildScaffold(context),
      );

  /// L'hôte veut quitter : on lui demande, et on lui dit ce qui se passe (le live reste ouvert 15 minutes, pas de coupure instantanée).
  Future<void> _confirmHostExit() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(tr('Quitter ton live ?'), style: const TextStyle(color: Colors.white)),
        content: Text(
          tr('Ton live ne sera pas coupé tout de suite : il reste ouvert 15 minutes en pause. Reviens avant pour le reprendre (Mes lives), sinon il se terminera seul. Tes spectateurs verront « L\'hôte revient bientôt ».'),
          style: const TextStyle(color: Colors.white70, height: 1.35),
        ),
        actions: [
          TextButton(key: const ValueKey('live_exit_stay'), onPressed: () => Navigator.pop(ctx, 'stay'), child: Text(tr('Rester'), style: const TextStyle(color: Colors.white70))),
          TextButton(key: const ValueKey('live_exit_away'), onPressed: () => Navigator.pop(ctx, 'away'), child: Text(tr('Quitter, je reviens'), style: const TextStyle(color: Color(0xFFF9A825)))),
          TextButton(key: const ValueKey('live_exit_end'), onPressed: () => Navigator.pop(ctx, 'end'), child: Text(tr('Terminer le live'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'away') {
      await _markAway();
      if (mounted) Navigator.pop(context);
    } else if (choice == 'end') {
      _endLive();
    }
  }

  /// Met le live en pause pour les spectateurs et relance le compte des 15 minutes (serveur) ; ne termine rien.
  Future<void> _markAway() async {
    if (_awayMarked || !widget.isHost || _endHandled) return;
    _awayMarked = true;
    final msg = tr("L'hôte revient bientôt");
    try {
      await LivesApi.update(widget.liveId, {'is_paused': true, 'pause_message': msg});
    } catch (_) {}
    try {
      await _firestore.collection('lives').doc(widget.liveId).update({'isPaused': true, 'pauseMessage': msg});
    } catch (_) {}
  }

  /// L'hôte revient dans son live : la pause est levée.
  Future<void> _resumeIfAway() async {
    try {
      await LivesApi.update(widget.liveId, {'is_paused': false, 'pause_message': null});
    } catch (_) {}
    try {
      await _firestore.collection('lives').doc(widget.liveId).update({'isPaused': false, 'pauseMessage': null});
    } catch (_) {}
  }

  /// Spectateur : le live est en pause, l'hôte a-t-il fini par ne pas revenir ? (le serveur l'a alors terminé)
  Future<void> _checkEndedWhilePaused() async {
    if (!mounted || _endHandled || !_isLivePaused || widget.isHost) return;
    try {
      final l = await LivesApi.get(widget.liveId);
      if (l['is_live'] == false) await _onLiveEndedRemotely();
    } catch (_) {}
  }

  // ==================== IMAGE ÉPINGLÉE (hôte) ====================

  /// L'hôte épingle une image de sa galerie (ou change/retire celle qui est posée) : les spectateurs la voient en vignette et la touchent pour l'agrandir.
  Future<void> _pinImage() async {
    if (_pinnedImageUrl != null) {
      final c = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF1A1A2E),
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(key: const ValueKey('pin_image_change'), leading: const Icon(Icons.image_rounded, color: Colors.white), title: Text(tr("Changer l'image"), style: const TextStyle(color: Colors.white)), onTap: () => Navigator.pop(ctx, 'change')),
            ListTile(key: const ValueKey('pin_image_remove'), leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), title: Text(tr("Retirer l'image"), style: const TextStyle(color: Colors.redAccent)), onTap: () => Navigator.pop(ctx, 'remove')),
          ]),
        ),
      );
      if (c == 'remove') return _setPinnedImage(null);
      if (c != 'change') return;
    }
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x == null || !mounted) return;
    try {
      final bytes = await x.readAsBytes();
      final id = await ArgentUpload.bytes(bytes, contentType: ArgentUpload.sniffImageType(bytes, path: x.path));
      await _setPinnedImage(id);
    } catch (e) {
      printVm("❌ Erreur image épinglée: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("L'image n'a pas pu être épinglée. Réessaie."))));
    }
  }

  Future<void> _setPinnedImage(String? uploadId) async {
    final r = await LivesApi.update(widget.liveId, {'pinned_image_upload_id': uploadId});
    final url = r['pinned_image_url'] as String?;
    try {
      await _firestore.collection('lives').doc(widget.liveId).update({'pinnedImageUrl': url ?? FieldValue.delete()});
    } catch (_) {}
    if (mounted) setState(() => _pinnedImageUrl = url);
  }

  void _openPinnedImage() {
    final url = _pinnedImageUrl;
    if (url == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(children: [
          Positioned.fill(child: InteractiveViewer(minScale: 1, maxScale: 5, child: Center(child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48))))),
          Positioned(top: MediaQuery.of(ctx).padding.top + 8, right: 12, child: IconButton(key: const ValueKey('pinned_image_close'), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28), onPressed: () => Navigator.pop(ctx))),
        ]),
      ),
    );
  }

  // ==================== LIVE SANS CAMÉRA ====================

  /// Démarre l'aperçu (vidéo en boucle, sans son) et la surveillance de l'API : fin du live (inactivité ou durée) et décompte d'inactivité.
  void _initNoCamera() {
    _initPreviewVideo();
    _pollNoCamera();
    _noCamTimer = Timer.periodic(const Duration(seconds: 15), (_) => _pollNoCamera());
    _noCamTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.isHost && (_idleSecondsNow ?? 9999) <= 130) setState(() {});
    });
  }

  /// Aperçu vidéo en boucle (sans son) : live sans caméra ou salon audio.
  void _initPreviewVideo() {
    final url = widget.postLive.previewUrl;
    if (widget.postLive.previewKind == 'video' && url != null && url.isNotEmpty) {
      final c = VideoPlayerController.networkUrl(Uri.parse(url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      _previewVideo = c;
      c.initialize().then((_) {
        c.setLooping(true);
        c.setVolume(0);
        c.play();
        if (mounted) setState(() {});
      }).catchError((_) {});
    }
  }

  void _setIdle(dynamic v) {
    _idleLeft = (v as num?)?.toInt();
    _idleAt = DateTime.now();
  }

  int? get _idleSecondsNow {
    final left = _idleLeft;
    final at = _idleAt;
    if (left == null || at == null) return null;
    return (left - DateTime.now().difference(at).inSeconds).clamp(0, 1 << 30);
  }

  Future<void> _pollNoCamera() async {
    if (!mounted || _endHandled) return;
    try {
      final l = await LivesApi.get(widget.liveId);
      if (l['is_live'] == false) {
        await _onLiveEndedRemotely();
        return;
      }
      _setIdle(l['idle_seconds_left']);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Widget _buildNoCameraBackdrop() {
    final v = _previewVideo;
    final img = widget.postLive.previewKind == 'image' && (widget.postLive.previewUrl ?? '').isNotEmpty ? widget.postLive.previewUrl! : (widget.postLive.displayImage ?? '');
    return Stack(fit: StackFit.expand, children: [
      Container(color: const Color(0xFF0B0B0B)),
      if (v != null && v.value.isInitialized)
        FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: v.value.size.width, height: v.value.size.height, child: VideoPlayer(v)))
      else if (img.isNotEmpty)
        Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())
      else
        // aucune image ni vidéo choisie par l'hôte : l'application illustre la page elle-même (scène animée, au thème du quiz s'il y en a un)
        QuizStageBackground(theme: '${_game?.kind == 'quiz' ? (_game!.quiz['theme'] ?? 'scene') : 'scene'}'),
      // voile sombre : les widgets du live restent lisibles sur n'importe quel aperçu
      Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(.35), Colors.black.withOpacity(.15), Colors.black.withOpacity(.55)]))),
    ]);
  }

  /// « Sans interaction, ton live s'arrête dans M:SS » : visible pour l'hôte dans les 2 dernières minutes avant l'arrêt.
  Widget _buildIdleBanner() {
    final left = _idleSecondsNow;
    if (left == null || left > 120) return const SizedBox.shrink();
    final m = left ~/ 60;
    final sec = (left % 60).toString().padLeft(2, '0');
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.of(context).padding.top + 120,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.78), border: Border.all(color: const Color(0xFFF9A825)), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.timer_outlined, color: Color(0xFFF9A825)),
          const SizedBox(width: 10),
          Expanded(child: Text(context.tr('Personne n\'interagit : ton live s\'arrête dans {t}. Lance un jeu, écris un message ou pose une question pour le garder ouvert.', {'t': '$m:$sec'}), style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35))),
        ]),
      ),
    );
  }

  // ==================== ÉPINGLES (texte + image) ====================

  String? get _pinText {
    final t = _pinnedTextFromDoc ? _pinnedTextDoc : widget.postLive.pinnedText;
    return (t == null || t.trim().isEmpty) ? null : t;
  }

  bool get _hasPinImage => (_pinnedImageUrl ?? '').isNotEmpty;
  bool get _pinRight => _pinPlace == 'right';

  /// Le panneau du nouveau quiz est à l'écran (il montre lui-même l'image épinglée).
  bool get _quiz2Shown {
    final g = _game;
    return g != null && g.kind == 'quiz' && (g.quiz['v'] as num?)?.toInt() == 2 && !(!g.active && _closedGames.contains(g.id));
  }
  bool get _isQuizLive => widget.postLive.typeSession == 'quiz' || _game?.kind == 'quiz';
  bool get _hasGames => const {'duel', 'challenge', 'quiz', 'story'}.contains(widget.postLive.typeSession) || _game != null || _gamesCount > 0;

  /// Hauteur des épingles placées à GAUCHE : la carte de jeu descend d'autant, elle ne passe jamais dessous (ni dessus).
  double get _leftPinHeight {
    if (_pinRight) return 0;
    final t = _pinText != null;
    final i = _hasPinImage;
    if (!t && !i) return 0;
    if (t && i) return _pinLayout == 'side' ? 84 : 136;
    return t ? 58 : 78;
  }

  /// Ce que chaque type de live peut montrer et utiliser (vitrine, étals, jeux autorisés) : une seule règle, jamais de bloc en trop.
  LiveCaps get _caps => LiveCaps.of(widget.postLive.typeSession, audioOnly: widget.postLive.audioOnly, noCamera: _noCam);

  /// Les blocs du haut de l'écran sont rangés dans UNE colonne (`_buildTopStack`) : chacun prend la place sous le précédent, sans jamais se superposer.
  /// Cette fonction rend le bloc tel quel (les anciens positionnements sont ignorés).
  Widget _flowed({double? top, double? left, double? right, required Widget child}) => child;

  /// Haut de la colonne : sous les pièces reçues, et sous la barre d'objectif quand il y en a une.
  double get _stackTop => MediaQuery.of(context).padding.top + (_goal != null ? 188 : 136);

  double _topStackH = 0;
  final GlobalKey _topStackKey = GlobalKey();
  final ValueNotifier<bool> _topScrolled = ValueNotifier<bool>(false);
  late final ScrollController _topScroll = ScrollController()
    ..addListener(() {
      final on = _topScroll.hasClients && _topScroll.offset > 12;
      if (on != _topScrolled.value) _topScrolled.value = on;
    });

  /// Petit résumé collé en haut de la colonne dès qu'on a défilé : une ligne, juste le nécessaire (jeu en cours, étals, scène) ; un toucher remonte en haut.
  Widget _stickySummary() {
    final parts = <String>[];
    final g = _game;
    if (g != null && g.active) {
      parts.add(switch (g.kind) { 'duel' => tr('Duel'), 'challenge' => tr('Défi'), 'quiz' => tr('Quiz'), 'poll' => tr('Sondage'), 'story' => tr('Conte'), _ => tr('Jeu') } + ' ' + tr('en cours'));
    }
    if (_isMarket && _market != null) {
      final stalls = ((_market!['stalls'] as List?) ?? const []).whereType<Map>().toList();
      final live = stalls.where((s) => s['status'] == 'active').toList();
      final who = live.isEmpty ? '' : '@${(live.first['vendor'] as Map?)?['username'] ?? ''}';
      parts.add(live.isEmpty ? tr('Étals : {n} vendeur(s)', {'n': stalls.length}) : tr('En vente : {w}', {'w': who}));
    }
    if (_stage.speakers.isNotEmpty) parts.add(tr('{n} sur scène', {'n': _stage.speakers.length}));
    return GestureDetector(
      key: const ValueKey('top_sticky_summary'),
      onTap: () => _topScroll.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOut),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.78), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF9A825).withOpacity(0.5))),
        child: Row(children: [
          const Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFFF9A825), size: 18),
          const SizedBox(width: 4),
          Expanded(child: Text(parts.isEmpty ? tr('Revenir en haut') : parts.join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }

  Widget _buildTopStack() {
    final size = MediaQuery.of(context).size;
    final footerH = MediaQuery.of(context).padding.bottom + 62 + (widget.isHost || _isParticipant ? 92 : 0) + (!widget.isHost && _gifts.isNotEmpty ? 30 : 0);
    final maxH = size.height - _stackTop - footerH - 34 - 110;   // on garde toujours 110 px pour la discussion
    final blocks = <Widget>[
      _buildPinnedLeft(),
      _buildGameCard(),
      _buildLeaderboard(),
      // vitrine : vente en direct (l'hôte vend) ou marché (seul le vendeur dont c'est le tour gère ses articles : l'hôte d'un marché n'est pas obligé d'être vendeur, il voit seulement ce qui est épinglé)
      if (_caps.showcase) LivePinnedProduct(liveId: widget.liveId, isHost: _isMarket ? _isActiveVendor : (widget.isHost || _isActiveVendor), canOpen: _isMarket ? _isActiveVendor : true),
      _buildStageStrip(),
    ].where((w) => !(w is SizedBox && w.width == 0 && w.height == 0)).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final h = _topStackKey.currentContext?.size?.height ?? 0;
      if (mounted && (h - _topStackH).abs() > 2) setState(() => _topStackH = h);
    });
    if (blocks.isEmpty) {
      if (_topStackH != 0) _topStackH = 0;
      return const SizedBox.shrink();
    }
    return Positioned(
      top: _stackTop,
      left: 16,
      right: _gameRight,
      child: ConstrainedBox(
        key: _topStackKey,
        constraints: BoxConstraints(maxHeight: maxH < 120 ? 120 : maxH),
        child: Stack(children: [
          SingleChildScrollView(
            controller: _topScroll,
            physics: const ClampingScrollPhysics(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              for (final b in blocks) Padding(padding: const EdgeInsets.only(bottom: 8), child: b),
            ]),
          ),
          Positioned(top: 0, left: 0, right: 0, child: ValueListenableBuilder<bool>(valueListenable: _topScrolled, builder: (_, on, __) => on ? _stickySummary() : const SizedBox.shrink())),
        ]),
      ),
    );
  }

  /// Marge droite de la carte de jeu : plus large quand des épingles sont rangées dans la colonne de droite.
  double get _gameRight => (_pinRight && (_pinText != null || _hasPinImage)) ? 112 : 70;

  Widget _pinnedTextBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: Color(0xFFF9A825), width: 3))),
      child: Row(children: [
        Expanded(child: Text(_pinText ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), maxLines: _pinRight ? 5 : 3, overflow: TextOverflow.ellipsis)),
        if (widget.isHost) GestureDetector(onTap: _togglePinnedTextEditor, child: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.edit_rounded, color: Colors.white38, size: 14))),
      ]),
    );
  }

  Widget _pinnedImageBox() {
    final url = _pinnedImageUrl ?? '';
    return GestureDetector(
      key: const ValueKey('pinned_image'),
      onTap: _openPinnedImage,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF9A825), width: 2), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(fit: StackFit.expand, children: [
            Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF333333))),
            const Positioned(right: 3, bottom: 3, child: Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 16, shadows: [Shadow(color: Colors.black87, blurRadius: 4)])),
          ]),
        ),
      ),
    );
  }

  /// Épingles placées à gauche (texte et image côte à côte, ou image sous le texte).
  Widget _buildPinnedLeft() {
    if (_pinRight) return const SizedBox.shrink();
    final hasT = _pinText != null;
    final hasI = _hasPinImage && !_quiz2Shown;   // pendant un quiz, l'image est dans le panneau du quiz
    if (!hasT && !hasI) return const SizedBox.shrink();
    Widget content;
    if (hasT && hasI) {
      content = _pinLayout == 'side'
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _pinnedTextBox()), const SizedBox(width: 8), _pinnedImageBox()])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_pinnedTextBox(), const SizedBox(height: 6), _pinnedImageBox()]);
    } else {
      content = Align(alignment: Alignment.centerLeft, child: hasT ? _pinnedTextBox() : _pinnedImageBox());
    }
    return _flowed(child: content);
  }

  /// Bas de la colonne de droite : historique du quiz, épingles placées à droite.
  List<Widget> _rightColumnExtras() {
    return [
      if (_hasGames) ...[
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _openGamesHistory,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.history_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(context.tr('Historique'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
            ]),
          ),
        ),
      ],
      if (_pinRight && (_pinText != null || _hasPinImage)) ...[
        const SizedBox(height: 10),
        if (_pinText != null) SizedBox(width: 104, child: _pinnedTextBox()),
        if (_pinText != null && _hasPinImage) const SizedBox(height: 6),
        if (_hasPinImage && !_quiz2Shown) _pinnedImageBox(),
      ],
    ];
  }

  /// Historique de tous les jeux du live (résultat, gagnant, gains) ; pour un quiz, un bouton ouvre les questions et les réponses.
  void _openGamesHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LiveGamesHistorySheet(future: LivesApi.gameResults(widget.liveId), onQuiz: () {
        Navigator.pop(ctx);
        _openQuizHistory();
      }),
    );
  }

  void _openQuizHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LiveQuizHistorySheet(
        future: LivesApi.quizHistory(widget.liveId),
        onRanking: (gameId) => showQuizRankingSheet(context, LivesApi.quizRanking(widget.liveId, gameId: gameId), isHost: widget.isHost),
      ),
    );
  }

  /// L'hôte choisit où ranger ses épingles (gauche ou droite) et comment (image à côté du texte ou en dessous). Tous les spectateurs le voient tout de suite.
  Future<void> _showPinPlaceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Widget choice(String label, bool on, VoidCallback tap) => Expanded(
              child: GestureDetector(
                onTap: tap,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: on ? const Color(0xFFF9A825) : Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(14)),
                  child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: on ? Colors.black : Colors.white70, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ),
            );
        void change({String? place, String? layout}) {
          setSheet(() {
            _pinPlace = place ?? _pinPlace;
            _pinLayout = layout ?? _pinLayout;
          });
          setState(() {});
          _savePin();
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ctx.tr('Placement des épingles'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(ctx.tr('Ton texte et ton image épinglés : où les ranger sur l\'écran ?'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 14),
              Text(ctx.tr('Côté'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              Row(children: [choice(ctx.tr('À gauche'), _pinPlace == 'left', () => change(place: 'left')), choice(ctx.tr('À droite'), _pinPlace == 'right', () => change(place: 'right'))]),
              const SizedBox(height: 10),
              Text(ctx.tr('Image'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              Row(children: [choice(ctx.tr('À côté du texte'), _pinLayout == 'side', () => change(layout: 'side')), choice(ctx.tr('Sous le texte'), _pinLayout == 'below', () => change(layout: 'below'))]),
              const SizedBox(height: 6),
              Text(ctx.tr('À droite, le texte et l\'image se rangent l\'un sous l\'autre sous le menu.'), style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _savePin() async {
    try {
      await LivesApi.update(widget.liveId, {'pin': {'place': _pinPlace, 'layout': _pinLayout}});
    } catch (_) {}
    try {
      await _firestore.collection('lives').doc(widget.liveId).update({'pin': {'place': _pinPlace, 'layout': _pinLayout}});
    } catch (_) {}
  }

  // ==================== MUSIQUE DU LIVE ====================

  /// Au départ : placement des épingles et musique en cours, lus sur l'API (une personne qui arrive en retard prend le live en cours de route).
  Future<void> _initLiveOptions() async {
    try {
      final l = await LivesApi.get(widget.liveId);
      final o = l['options'];
      if (o is Map) {
        final pin = o['pin'];
        if (pin is Map && mounted) {
          setState(() {
            _pinPlace = '${pin['place'] ?? 'left'}' == 'right' ? 'right' : 'left';
            _pinLayout = '${pin['layout'] ?? 'side'}' == 'below' ? 'below' : 'side';
          });
        }
        final m = o['music'];
        if (m is Map) _syncMusic(Map<String, dynamic>.from(m));
      }
    } catch (_) {}
  }

  /// Contexte audio de la musique : aucun focus audio demandé (Agora le garde pour les voix) et haut-parleur ; sans cela la lecture pouvait rester muette pendant un live.
  static ap.AudioContext get _musicContext => ap.AudioContext(
        android: const ap.AudioContextAndroid(contentType: ap.AndroidContentType.music, usageType: ap.AndroidUsageType.media, audioFocus: ap.AndroidAudioFocus.none),
        iOS: ap.AudioContextIOS(category: ap.AVAudioSessionCategory.playAndRecord, options: const [ap.AVAudioSessionOptions.mixWithOthers, ap.AVAudioSessionOptions.defaultToSpeaker]),
      );

  /// Écoute d'un extrait (hôte) : un toucher lance, un second arrête ; une piste introuvable est dite clairement.
  Future<bool> _previewTrack(String id) async {
    try {
      if (_previewId == id) {
        await _previewPlayer?.stop();
        _previewId = null;
        return true;
      }
      final url = MediaCdn.url(await MusicApi.freeTrackUrl(id));
      final p = _previewPlayer ??= ap.AudioPlayer();
      await p.stop();
      await p.setAudioContext(_musicContext);
      await p.setReleaseMode(ap.ReleaseMode.stop);
      await p.setVolume(.9);
      await p.play(ap.UrlSource(url));
      _previewId = id;
      return true;
    } catch (e) {
      printVm('⚠️ Écoute de la musique impossible : $e');
      _previewId = null;
      _toast(tr('Cette musique n\'est pas disponible pour le moment.'));
      return false;
    }
  }

  Future<void> _stopPreview() async {
    _previewId = null;
    try {
      await _previewPlayer?.stop();
    } catch (_) {}
  }

  Future<void> _stopMusic() async {
    _musicGen++;
    _musicKey = null;
    try {
      await _musicPlayer?.stop();
    } catch (_) {}
  }

  /// Cale la lecture sur l'état du live : même piste, même instant (heure de départ du serveur), à la maison du volume de CHAQUE personne.
  Future<void> _syncMusic(Map<String, dynamic>? m) async {
    if (!mounted) return;
    if (m == null) {
      if (_music != null) setState(() => _music = null);
      await _stopMusic();
      return;
    }
    final id = '${m['id']}';
    final startedAt = (m['started_at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    final key = '$id@$startedAt';
    if (key == _musicKey) {
      if (_music == null) setState(() => _music = m);
      return;
    }
    setState(() => _music = m);
    _musicKey = key;
    final gen = ++_musicGen;
    try {
      final url = MediaCdn.url(await MusicApi.freeTrackUrl(id));
      if (!mounted || gen != _musicGen) return;
      final dur = (m['duration_ms'] as num?)?.toInt() ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - startedAt;
      final offset = dur > 0 && elapsed > 0 ? elapsed % dur : 0;
      final p = _musicPlayer ??= ap.AudioPlayer();
      await p.stop();
      await p.setAudioContext(_musicContext);
      await p.setReleaseMode(ap.ReleaseMode.loop);
      await p.setVolume(_musicMuted ? 0 : _musicVolume);
      if (!mounted || gen != _musicGen) return;
      await p.play(ap.UrlSource(url), position: Duration(milliseconds: offset));
      if (!mounted || gen != _musicGen) {
        await p.stop();
        return;
      }
      if (!widget.isHost) LivesApi.musicAck(widget.liveId, key, true).catchError((_) {});   // « j'entends la musique » : l'hôte le voit
    } catch (e) {
      printVm('⚠️ Musique du live impossible : $e');
      if (!widget.isHost) LivesApi.musicAck(widget.liveId, key, false).catchError((_) {});
      if (widget.isHost) _toast(tr('La musique ne peut pas être lue sur ton téléphone pour le moment.'));
    }
  }

  Future<void> _setMusicVolume({double? volume, bool? muted}) async {
    _musicVolume = volume ?? _musicVolume;
    _musicMuted = muted ?? _musicMuted;
    try {
      await _musicPlayer?.setVolume(_musicMuted ? 0 : _musicVolume);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Widget _buildMusicChip() {
    return GestureDetector(
      onTap: _openMusicSheet,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF9A825).withOpacity(.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.music_note_rounded, color: Color(0xFFF9A825), size: 13),
          const SizedBox(width: 4),
          Flexible(child: Text('${_music?['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10.5))),
          const SizedBox(width: 4),
          Icon(_musicMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white70, size: 13),
        ]),
      ),
    );
  }

  /// Feuille de la musique : volume et sourdine pour chaque personne (son propre téléphone) ; l'hôte choisit, change ou arrête la musique.
  Future<void> _openMusicSheet() async {
    final acks = ValueNotifier<Map<String, dynamic>?>(null);
    Future<void> loadAcks() async {
      if (!widget.isHost || _music == null) return;
      try {
        acks.value = await LivesApi.musicAcks(widget.liveId);
      } catch (_) {}
    }

    loadAcks();
    final poll = Timer.periodic(const Duration(seconds: 4), (_) => loadAcks());
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final playing = _music != null;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ctx.tr('Musique du live'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(playing ? '♪ ${_music!['title']}' : ctx.tr('Aucune musique pour le moment.'), style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 13.5, fontWeight: FontWeight.w600)),
              if (playing) ...[
                const SizedBox(height: 10),
                Row(children: [
                  IconButton(
                    icon: Icon(_musicMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white),
                    onPressed: () {
                      _setMusicVolume(muted: !_musicMuted);
                      setSheet(() {});
                    },
                  ),
                  Expanded(
                    child: Slider(
                      value: _musicMuted ? 0 : _musicVolume,
                      min: 0,
                      max: 1,
                      activeColor: const Color(0xFFF9A825),
                      onChanged: (v) {
                        _setMusicVolume(volume: v, muted: v == 0);
                        setSheet(() {});
                      },
                    ),
                  ),
                ]),
                Text(ctx.tr('Le volume ne règle que ton téléphone.'), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                if (widget.isHost)
                  ValueListenableBuilder<Map<String, dynamic>?>(
                    valueListenable: acks,
                    builder: (_, a, __) {
                      final l = (a?['listening'] as num?)?.toInt() ?? 0;
                      final f = (a?['failed'] as num?)?.toInt() ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          Icon(f > 0 ? Icons.warning_amber_rounded : Icons.headphones_rounded, color: f > 0 ? const Color(0xFFFFB74D) : const Color(0xFF69F0AE), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              a == null ? ctx.tr('Vérification de ce que les spectateurs entendent…') : '${ctx.tr('Entendue par')} $l ${ctx.tr('spectateur(s)')}${f > 0 ? ' · $f ${ctx.tr('n\'arrivent pas à la lire')}' : ''}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
              ],
              if (widget.isHost) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF9A825), foregroundColor: Colors.black),
                      icon: const Icon(Icons.library_music_rounded),
                      label: Text(playing ? ctx.tr('Changer') : ctx.tr('Choisir une musique')),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _pickMusic();
                      },
                    ),
                  ),
                  if (playing) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _hostSetMusic(null);
                      },
                      child: Text(ctx.tr('Arrêter')),
                    ),
                  ],
                ]),
                const SizedBox(height: 6),
                Text(ctx.tr('Musiques gratuites d\'Afrolook, jouées chez tous tes spectateurs.'), style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ]),
          ),
        );
      }),
    );
    poll.cancel();
    acks.dispose();
  }

  Future<void> _pickMusic() async {
    final t = await showModalBottomSheet<StudioTrack>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        var q = '';
        String? playingId;
        return StatefulBuilder(builder: (ctx, setSheet) {
          final list = [for (final x in kStudioTracks) if (q.isEmpty || x.title.toLowerCase().contains(q) || x.section.toLowerCase().contains(q)) x];
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * .75,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: ctx.tr('Chercher une musique (titre, ambiance)'), hintStyle: const TextStyle(color: Colors.white38), prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54), filled: true, fillColor: Colors.white.withOpacity(.07), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                  onChanged: (v) => setSheet(() => q = v.trim().toLowerCase()),
                ),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 6), child: Align(alignment: Alignment.centerLeft, child: Text(ctx.tr('Touche ▶ pour écouter (toi seul), puis touche la ligne pour la choisir.'), style: const TextStyle(color: Colors.white38, fontSize: 11)))),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final x = list[i];
                    final min = (x.durationMs / 60000).floor();
                    final sec = ((x.durationMs % 60000) / 1000).round().toString().padLeft(2, '0');
                    return ListTile(
                      leading: Text(x.emoji, style: const TextStyle(fontSize: 24)),
                      title: Text(x.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      subtitle: Text('${x.section} · $min:$sec', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: IconButton(
                        key: ValueKey('music_preview_${x.id}'),
                        icon: Icon(playingId == x.id ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, color: const Color(0xFFF9A825), size: 30),
                        onPressed: () async {
                          final ok = await _previewTrack(x.id);
                          setSheet(() => playingId = ok && _previewId == x.id ? x.id : null);
                        },
                      ),
                      onTap: () async {
                        await _stopPreview();
                        if (ctx.mounted) Navigator.pop(ctx, x);
                      },
                    );
                  },
                ),
              ),
            ]),
          );
        });
      },
    );
    await _stopPreview();
    if (t != null) await _hostSetMusic(t);
  }

  /// L'hôte lance (ou arrête) une musique : l'API garde la référence (heure de départ du serveur), Firestore la diffuse tout de suite à tous.
  Future<void> _hostSetMusic(StudioTrack? t) async {
    try {
      if (t == null) {
        await LivesApi.update(widget.liveId, {'music': null});
        await _firestore.collection('lives').doc(widget.liveId).update({'music': null});
        await _syncMusic(null);
        return;
      }
      try {
        await MusicApi.freeTrackUrl(t.id);   // on ne diffuse jamais une piste introuvable sur le stockage
      } catch (_) {
        _toast(tr('Cette musique n\'est pas disponible pour le moment.'));
        return;
      }
      final r = await LivesApi.update(widget.liveId, {'music': {'id': t.id, 'title': t.title, 'duration_ms': t.durationMs}});
      final m = (r['options'] as Map?)?['music'];
      if (m is Map) {
        final mm = Map<String, dynamic>.from(m);
        await _firestore.collection('lives').doc(widget.liveId).update({'music': mm});
        await _syncMusic(mm);
      }
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast(tr('La musique n\'a pas pu être changée. Réessaie.'));
    }
  }

  Widget _buildPinnedImage() {
    final url = _pinnedImageUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.of(context).padding.top + 190,
      left: 16,
      child: GestureDetector(
        key: const ValueKey('pinned_image'),
        onTap: _openPinnedImage,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF9A825), width: 2), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(fit: StackFit.expand, children: [
              Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF333333))),
              const Positioned(right: 3, bottom: 3, child: Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 16, shadows: [Shadow(color: Colors.black87, blurRadius: 4)])),
            ]),
          ),
        ),
      ),
    );
  }

  // ==================== FILTRES DE BEAUTÉ (hôte) ====================

  Future<void> _applyBeauty() async {
    try {
      await _engine.setBeautyEffectOptions(
        enabled: _beautyOn,
        options: BeautyOptions(
          lighteningContrastLevel: LighteningContrastLevel.lighteningContrastNormal,
          lighteningLevel: _beautyLight,
          smoothnessLevel: _beautySmooth,
          rednessLevel: _beautyRed,
          sharpnessLevel: _beautySharp,
        ),
      );
    } catch (e) {
      printVm('⚠️ Filtres de beauté indisponibles : $e');
    }
  }

  void _showBeautySheet() {
    const presets = <(String, double, double, double, double)>[
      ('Aucun', 0, 0, 0, 0),
      ('Naturel', .4, .3, .05, .3),
      ('Doux', .7, .4, .1, .2),
      ('Éclatant', .5, .7, .15, .5),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget slider(String label, double v, ValueChanged<double> onChanged, Key key) => Row(children: [
                SizedBox(width: 78, child: Text(tr(label), style: const TextStyle(color: Colors.white70, fontSize: 13))),
                Expanded(child: Slider(key: key, value: v, min: 0, max: 1, activeColor: const Color(0xFFF9A825), onChanged: onChanged)),
              ]);
          void change(void Function() f) {
            setSheet(f);
            setState(() {});
            _beautyOn = _beautySmooth + _beautyLight + _beautyRed + _beautySharp > 0;
            _applyBeauty();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Filtres du live'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  for (final pr in presets)
                    ActionChip(
                      key: ValueKey('beauty_${pr.$1}'),
                      label: Text(tr(pr.$1)),
                      onPressed: () => change(() {
                        _beautySmooth = pr.$2;
                        _beautyLight = pr.$3;
                        _beautyRed = pr.$4;
                        _beautySharp = pr.$5;
                      }),
                    ),
                ]),
                const SizedBox(height: 6),
                slider('Lissage', _beautySmooth, (v) => change(() => _beautySmooth = v), const ValueKey('beauty_smooth')),
                slider('Éclat', _beautyLight, (v) => change(() => _beautyLight = v), const ValueKey('beauty_light')),
                slider('Teint', _beautyRed, (v) => change(() => _beautyRed = v), const ValueKey('beauty_red')),
                slider('Netteté', _beautySharp, (v) => change(() => _beautySharp = v), const ValueKey('beauty_sharp')),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // chaque toucher sur l'écran envoie un cœur, hôte compris (les boutons gardent leurs propres touchers)
        behavior: HitTestBehavior.opaque,   // même une zone vide (sans vidéo derrière) reçoit le toucher : un cœur part
        onTapDown: _onTap,
        // fit: expand = la pile prend tout l'écran même sans vidéo distante. Sans cela (seul enfant non positionné = SizedBox.shrink), elle s'écrasait à 0×0 :
        // tous les widgets positionnés tombaient hors cadre et l'écran paraissait noir (arbre de rendu lu sur le téléphone, 14/11/2026).
        child: Stack(
          fit: StackFit.expand,
          children: [
            // VIDÉO PRINCIPALE
            _buildVideoSection(),

            // OVERLAY TEMPS ESSAI (portrait uniquement)
            if (!isLandscape && widget.postLive.isPaidLive && _showTrialOverlay && !_shouldSkipTrial())
              _buildTrialOverlay(),

            // OVERLAY BILLET (gratuit du mois épuisé) : au même endroit que l'écran d'essai, sous les boutons du haut
            if (!isLandscape && _ticketRequired && !widget.isHost) _buildTicketOverlay(),

            // BOUTON TOGGLE UI (portrait uniquement)
            if (!isLandscape)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                child: _buildToggleUIButton(),
              ),

            // BOUTON PAYSAGE — spectateurs uniquement, portrait uniquement
            // Positionné en dessous du badge "LIVE Afrolook" (right:16) pour éviter la superposition
            if (!isLandscape && !widget.isHost && !_isParticipant)
              Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                right: 16,
                child: GestureDetector(
                  onTap: () => SystemChrome.setPreferredOrientations([
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.screen_rotation_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),

            // INTERFACE UTILISATEUR COMPLÈTE (portrait uniquement)
            if (_showUI && !isLandscape) ..._buildUIOverlay(),

            // CONTRÔLES MINIMAUX EN PAYSAGE (spectateurs uniquement)
            if (isLandscape && !widget.isHost) _buildLandscapeControls(context),

            // EFFETS ANIMÉS (toujours visibles)
            ..._buildTikTokLikeEffects(),
            ..._buildGiftEffects(),

            // live sans caméra : avertissement avant l'arrêt pour inactivité (hôte)
            if (!isLandscape && _noCam && widget.isHost) _buildIdleBanner(),

            // RAPPEL DE LA DERNIÈRE MINUTE (billet, essai, frais de diffusion de l'hôte)
            if (!isLandscape && _showUI) _buildTicketReminder(),

            // LOADING
            if (!_isInitialized && !_ticketRequired) (_joinError != null ? _buildJoinErrorOverlay() : _buildLoadingOverlay()),
          ],
        ),
      ),
    );
  }

  /// Contrôles minimaux affichés en mode paysage pour les spectateurs.
  Widget _buildLandscapeControls(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        // Bouton retour portrait — coin supérieur droit
        Positioned(
          top: top + 8,
          right: 12,
          child: GestureDetector(
            onTap: () {
              // Retour portrait en autorisant à nouveau la rotation ensuite
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Icon(Icons.screen_rotation_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
        // Compteur vues + likes — coin supérieur gauche
        Positioned(
          top: top + 8,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text('$_viewerCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 14),
                const SizedBox(width: 4),
                Text('$_likeCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        // Bouton like — coin inférieur droit
        Positioned(
          bottom: 20,
          right: 20,
          child: GestureDetector(
            onTap: _sendLike,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.pinkAccent.withOpacity(0.4)),
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 22),
            ),
          ),
        ),
      ],
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
      _buildCoinsChip(),
      _buildGoalBar(),
      _buildTopStack(),
      _buildViewerInfo(),
      if (_showMessages) _buildCommentsSection(),
      _buildFooter(),
      if (_showMessages) _buildTypingIndicator(),
      if (_showGiftPanel)
        GiftPanelWidget(
          gifts: _gifts,
          recentIds: _recentGiftIds,
          isHost: widget.isHost,
          onGiftSelected: _sendGift,
          onClose: () => setState(() => _showGiftPanel = false),
        ),
      if (_showUsersPanel)
        LiveParticipantsPanel(
          stage: _stage,
          isHost: widget.isHost,
          totalCount: _allUsers.length,
          viewers: [
            for (final u in _allUsers)
              if (u.id != null && u.id != widget.postLive.hostId && !_stage.speakers.any((sp) => sp.user.id == u.id))
                StageUser(id: u.id!, username: u.pseudo ?? '', avatarUrl: u.imageUrl),
          ],
          onClose: () => setState(() => _showUsersPanel = false),
          onDecide: _decideRequest,
          onInvite: (u, m) => _inviteToStage(u, widget.postLive.audioOnly ? 'audio' : m),
          onRemove: (sp) => _removeFromStage(sp.user.id),
        ),
      if (_showPinnedTextEditor)
        PinnedTextEditorWidget(
          controller: _pinnedTextController,
          onSave: _updatePinnedText,
          onCancel: () => setState(() => _showPinnedTextEditor = false),
        ),
    ];
  }

  /// Pièces reçues : une seule fois, sous le profil de l'hôte (le classement des donateurs est juste dessous).
  Widget _buildCoinsChip() {
    if (!_showCoinsInfo) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.of(context).padding.top + 102,
      left: 16,
      child: _buildInfoChip(icon: Icons.stars_rounded, value: context.tr('{n} pcs reçues', {'n': CoinCheckout.fmt(_giftCoinsTotal)}), color: const Color(0xFFF9A825)),
    );
  }

  Widget _buildLeaderboard() {
    if (_topDonors.isEmpty || !_showCoinsInfo || _game != null || _caps.showcase) return const SizedBox.shrink();
    return _flowed(
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
                  CircleAvatar(onBackgroundImageError: (_, __) {}, backgroundImage: NetworkImage(imageUrl), radius: 9, backgroundColor: Colors.white24),
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
              _pauseMessage ?? tr("L'hôte a mis le live en pause"),
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
            Text(tr('Réactivation automatique…'), style: TextStyle(color: Colors.white38, fontSize: 12)),
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
    if (widget.postLive.audioOnly) return _buildSalonView();
    if (_noCam) return _buildNoCameraBackdrop();
    return Stack(
      children: [
        if (_remoteUid != null)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(channelId: widget.liveId),
              // rendu par texture Flutter (pas de vue native) : une vue native Agora faisait noircir tout l'écran de Flutter sur certains téléphones
              useFlutterTexture: true,
              useAndroidSurfaceView: false,
            ),
          ),
        if (_remoteUid == null)
          const SizedBox.shrink(),


        if (_isVideoBlurred)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),

        if ((widget.isHost || _isParticipant) && !_isScreenSharing && !widget.postLive.audioOnly && (widget.isHost || _myStageMedia == 'video'))
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 166,
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
                  useFlutterTexture: true,
                  useAndroidSurfaceView: false,
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

  /// Salon audio : pas d'image, seulement les voix. L'hôte et les personnes sur scène en grands ronds, le reste du public en petit.
  Widget _buildSalonView() {
    final hasPreview = (widget.postLive.previewUrl ?? '').isNotEmpty;
    return Stack(fit: StackFit.expand, children: [
      if (hasPreview) _buildNoCameraBackdrop(),
      _buildSalonContent(hasPreview),
    ]);
  }

  Widget _buildSalonContent(bool hasPreview) {
    final speakers = _stage.speakers;
    Widget circle(String? url, String name, String role, {bool host = false}) => SizedBox(
          width: 82,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, border: host ? Border.all(color: const Color(0xFF69F0AE), width: 3) : null),
              child: CircleAvatar(
                backgroundColor: const Color(0xFF3B6A47),
                backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
                onBackgroundImageError: url != null && url.isNotEmpty ? (_, __) {} : null,
                child: url != null && url.isNotEmpty ? null : Text(name.isEmpty ? '?' : name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 5),
            Text('@$name', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            Text(role, style: const TextStyle(color: Colors.white54, fontSize: 9.5)),
          ]),
        );
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: hasPreview ? const [Color(0x883A2F55), Color(0xAA1B1530), Color(0xCC0B0B0B)] : const [Color(0xFF3A2F55), Color(0xFF1B1530), Color(0xFF0B0B0B)])),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 190, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.postLive.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.25)),
          const SizedBox(height: 16),
          Text(tr('Sur scène').toUpperCase(), style: const TextStyle(color: Color(0xFFFFE14D), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 14, children: [
            circle(widget.hostImage, _hostData.pseudo ?? widget.hostName, tr('Hôte'), host: true),
            for (final s in speakers) circle(s.user.avatarUrl, s.user.username, tr('Invité')),
          ]),
        ]),
      ),
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
              CircleAvatar(onBackgroundImageError: (_, __) {}, 
                backgroundImage: NetworkImage(widget.hostImage),
                radius: 18,
                backgroundColor: Colors.white24,
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PseudoTag(label: '@${_hostData.pseudo ?? widget.hostName}',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  Text(
                    '${_hostData.followersCount} abonnés',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
              if (!widget.isHost) ...[
                SizedBox(width: 10),
                GestureDetector(
                  onTap: () async {
                    if (_isFollowing) return;
                    setState(() => _isFollowing = true);
                    try {
                      final host = (_hostData.id != null && _hostData.id!.isNotEmpty)
                          ? _hostData
                          : (UserData()
                            ..id = widget.postLive.hostId
                            ..pseudo = widget.postLive.hostName
                            ..imageUrl = widget.postLive.hostImage);
                      await authProvider.abonner(host, context);
                    } catch (_) {
                      if (mounted) setState(() => _isFollowing = false);
                    }
                  },
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
      // Profil public lu dans l'API
      final userData = userFromApi(await UsersApi.publicProfile(userId));

      if (mounted) {
        // Récupérer les dimensions de l'écran
        final double width = MediaQuery.of(context).size.width;
        final double height = MediaQuery.of(context).size.height;

        // Appeler la fonction d'affichage des détails
        showUserDetailsModalDialog(userData, width, height, context);

        // Optionnel : Mettre à jour l'état du follow si nécessaire
        // setState(() => _isFollowing = !_isFollowing);
      }
    } catch (e) {
      printVm("❌ Erreur récupération utilisateur: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(UsersApi.message(e, fallback: tr('Impossible de charger ce profil pour le moment.'))),
          backgroundColor: Colors.red,
          action: SnackBarAction(label: tr('Réessayer'), textColor: Colors.white, onPressed: () => _showUserDetailsById(userId)),
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
          // Un chiffre = un seul endroit : spectateurs ici ; pièces reçues sous le profil ; « j'aime » et partages sous leurs boutons
          _buildInfoChip(icon: Icons.people_rounded, value: '$_viewerCount/$_totalviewerCount'),
          if (_music != null) ...[const SizedBox(height: 8), _buildMusicChip()],
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
          // Minuteur du billet : le MÊME petit minuteur que l'essai gratuit (orange, rouge sous 2 minutes) ; une seule fois si l'essai d'un live payant l'affiche déjà
          if (!widget.isHost && _ticketSecondsLeft < (1 << 29) && !_ticketRequired && !(widget.postLive.isPaidLive && _remainingTrialMinutes < 999 && !_shouldSkipTrial()))
            Container(
              margin: EdgeInsets.only(top: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _ticketSecondsLeft < 120 ? Colors.red.withOpacity(0.9) : Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_rounded, color: Colors.white, size: 11),
                  SizedBox(width: 3),
                  Text(
                    '${(_ticketSecondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_ticketSecondsLeft % 60).toString().padLeft(2, '0')}',
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
                widget.isHost ? tr('HÔTE') : authProvider.loginUserData.role == UserRole.ADM.name ? 'ADMIN' : 'PARTICIPANT',
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: .8),
              ),
            ),
          // Menu de l'hôte : « Terminer le live » est rangé ici (jamais un bouton rouge isolé) pour ne pas arrêter le live par erreur
          if (widget.isHost || authProvider.loginUserData.role == UserRole.ADM.name) ...[
            SizedBox(height: 10),
            PopupMenuButton<String>(
              tooltip: tr('Menu du live'),
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (v) {
                if (v == 'end') _confirmEndLive();
                if (v == 'voice' && widget.isHost) showLiveVoiceInbox(context, widget.liveId);
                if (v == 'display' && widget.isHost) _showDisplaySheet();
                if (v == 'games' && widget.isHost) _openGames();
                if (v == 'music' && widget.isHost) _openMusicSheet();
                if (v == 'pins' && widget.isHost) _showPinPlaceSheet();
              },
              itemBuilder: (ctx) => [
                if (widget.isHost)
                  PopupMenuItem<String>(
                    value: 'voice',
                    child: Row(children: [
                      const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(_voiceNew > 0 ? '${context.tr('Vocaux des spectateurs')} ($_voiceNew)' : context.tr('Vocaux des spectateurs'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                if (widget.isHost)
                  PopupMenuItem<String>(
                    value: 'games',
                    child: Row(children: [
                      const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(context.tr('Jeux du live'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                if (widget.isHost)
                  PopupMenuItem<String>(
                    value: 'music',
                    child: Row(children: [
                      const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(context.tr('Musique du live'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                if (widget.isHost)
                  PopupMenuItem<String>(
                    value: 'pins',
                    child: Row(children: [
                      const Icon(Icons.push_pin_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(context.tr('Placement des épingles'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                if (widget.isHost)
                  PopupMenuItem<String>(
                    value: 'display',
                    child: Row(children: [
                      const Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(context.tr('Affichage du live'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                PopupMenuItem<String>(
                  value: 'end',
                  child: Row(children: [
                    Icon(Icons.stop_circle_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text(tr('Terminer le live'), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.more_horiz_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                    if (_voiceNew > 0) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.circle, color: Colors.redAccent, size: 9)),
                  ],
                ),
              ),
            ),
          ],
          // Spectateur (y compris un administrateur qui regarde le live d'un autre) : bouton « message vocal à l'hôte » (30 s au plus, écouté par l'hôte seul)
          if (!widget.isHost && !_isParticipant) ...[
            const SizedBox(height: 10),
            LiveVoiceButton(
              liveId: widget.liveId,
              onSent: (id, seconds) => _sendComment(tr("a envoyé un message vocal à l'hôte"), type: 'voice', voiceNoteId: id, voiceSeconds: seconds),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _askQuestion,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                child: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
          ..._rightColumnExtras(),
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
    final footerH = MediaQuery.of(context).padding.bottom + 62 + (widget.isHost || _isParticipant ? 92 : 0) + (!widget.isHost && _gifts.isNotEmpty ? 30 : 0);
    var listHeight = MediaQuery.of(context).size.height * 0.30;
    if (_topStackH > 0) {
      // la liste des messages s'arrête sous la colonne du haut (jeu, vitrine, étals, scène) au lieu de la recouvrir
      final room = MediaQuery.of(context).size.height - footerH - 34 - (_stackTop + _topStackH + 8);
      listHeight = room < 70 ? 70 : (room < listHeight ? room : listHeight);
    }
    return Positioned(
      bottom: footerH,
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
                _showComments ? tr('Fermer les messages') : tr('Afficher les messages'),
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
                        CircleAvatar(onBackgroundImageError: (comment.userImage.isNotEmpty
                              ? NetworkImage(comment.userImage)
                              : null) != null ? (Object _, StackTrace? __) {} : null, 
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
                              comment.type == 'voice' && comment.voiceNoteId != null
                                  ? VoiceChatBadge(noteId: comment.voiceNoteId!, seconds: comment.voiceSeconds ?? 0, isHost: widget.isHost)
                                  : Text(
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
    final myCoins = CoinSplit.of(authProvider.loginUserData);
    final quickGifts = _gifts.isEmpty ? <Gift>[] : [_lastGift ?? _gifts.first];
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 6, 16, MediaQuery.of(context).padding.bottom + 8),
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
            // Solde pièces + dernier cadeau envoyé : une seule petite rangée, poussée à droite, pour ne pas cacher les messages
            if (!widget.isHost && (quickGifts.isNotEmpty || _canRaiseHand))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, color: Color(0xFFF9A825), size: 12),
                          const SizedBox(width: 4),
                          Text('${TxAmount.fmt(myCoins.depot)} · ${TxAmount.fmt(myCoins.gagnees)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ...quickGifts.map((gift) => GestureDetector(
                      onTap: () => _sendGift(gift),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(gift.icon, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 3),
                            Text('${gift.price.toInt()}', style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    )),
                    if (_canRaiseHand) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _raiseHand,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFFFE14D), borderRadius: BorderRadius.circular(12)),
                          child: Text(_stage.mine != null ? tr('Demande envoyée') : tr('Monter sur scène'), style: const TextStyle(color: Color(0xFF121212), fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            // Barre principale
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!_showMessages) const Spacer(),
                if (_showMessages) Expanded(
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
                              hintText: tr('Envoyer un message...'),
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
                _buildFooterAction(icon: Icons.favorite_rounded, color: Colors.pinkAccent, label: _showReactionCounts ? '$_likeCount' : tr('J\'aime'), onTap: _sendLike),
                SizedBox(width: 6),
                _buildFooterAction(icon: Icons.stars_rounded, color: Color(0xFFF9A825), label: 'Cadeau', onTap: () => setState(() => _showGiftPanel = true)),
                SizedBox(width: 6),
                _buildFooterAction(icon: Icons.people_rounded, color: Colors.white70, label: tr('Public'), onTap: _toggleUsersPanel),
                SizedBox(width: 6),
                _buildFooterAction(icon: Icons.share_rounded, color: Colors.blueAccent, label: _showReactionCounts ? '$_shareCount' : tr('Partager'), onTap: _shareLive),
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
    if (_noCam) {
      if (!widget.isHost) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: _buildCtrlBtn(icon: Icons.push_pin_rounded, label: tr('Image'), onTap: _pinImage, active: _pinnedImageUrl == null),
      );
    }
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
            label: _isScreenSharing ? tr('Arrêter') : tr('Écran'),
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
          if (!_isScreenSharing && !widget.postLive.audioOnly && (widget.isHost || _myStageMedia == 'video')) ...[
            const SizedBox(width: 20),
            _buildCtrlBtn(
              icon: Icons.cameraswitch_rounded,
              label: tr('Caméra'),
              onTap: _switchCamera,
            ),
            if (widget.isHost) ...[
              const SizedBox(width: 20),
              _buildCtrlBtn(
                icon: Icons.auto_awesome_rounded,
                label: tr('Filtres'),
                onTap: _showBeautySheet,
                active: !_beautyOn,
              ),
              const SizedBox(width: 20),
              _buildCtrlBtn(
                icon: Icons.push_pin_rounded,
                label: tr('Image'),
                onTap: _pinImage,
                active: _pinnedImageUrl == null,
              ),
            ],
          ],
          // Scène à plusieurs : l'hôte invite (pastille = demandes en attente) ; un invité peut descendre
          if (widget.isHost && _stage.enabled) ...[
            const SizedBox(width: 20),
            _buildInviteButton(),
          ],
          if (!widget.isHost && _onStageApi) ...[
            const SizedBox(width: 20),
            _buildCtrlBtn(icon: Icons.logout_rounded, label: tr('Descendre'), onTap: () => _removeFromStage(ApiIdentity.myId ?? ''), active: true),
          ],
        ],
      ),
    );
  }

  /// Bouton « Inviter » (jaune) : ouvre la liste des participants ; la pastille rouge compte les demandes en attente.
  Widget _buildInviteButton() {
    final n = _stage.requests.length;
    return GestureDetector(
      onTap: () {
        setState(() => _showUsersPanel = true);
        _fetchAllUsers();
      },
      child: Stack(clipBehavior: Clip.none, children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFFF9A825), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFF9A825))),
            child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF121212), size: 20),
          ),
          const SizedBox(height: 4),
          Text(tr('Inviter'), style: const TextStyle(color: Color(0xFFFFE14D), fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
        if (n > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFD92D3A), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFF111111), width: 2)),
              child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
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
              context.tr('Temps d\'essai écoulé'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              context.tr('Payez {p} pour continuer à regarder', {'p': CoinCheckout.coinsLabel(widget.postLive.participationFeeCoins)}),
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
                context.tr('Payer l\'entrée : {n} pièces', {'n': CoinCheckout.fmt(widget.postLive.participationFeeCoins)}),
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 12),
            TextButton(
              onPressed: _leaveLive,
              child: Text(
                context.tr('Quitter le live'),
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

  /// La connexion au live a échoué : la raison, « Réessayer » et « Quitter le live » (jamais une roue qui tourne sans fin).
  Widget _buildJoinErrorOverlay() {
    return Container(
      key: const ValueKey('live_join_error'),
      color: Colors.black.withOpacity(0.85),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFF9A825)),
          const SizedBox(height: 16),
          Text(tr('Impossible de rejoindre le live'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(_joinError ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.4), textAlign: TextAlign.center),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _retryJoin,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF9A825), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
            child: Text(tr('Réessayer'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          TextButton(onPressed: _leaveLive, child: Text(tr('Quitter le live'), style: const TextStyle(color: Colors.white70))),
        ]),
      ),
    );
  }

  /// Nouvelle tentative de connexion (le moteur vidéo est recréé, le jeton redemandé).
  Future<void> _retryJoin() async {
    setState(() => _joinError = null);
    _armJoinWatchdog();
    await _reinitializeAgora();
  }

  /// Sans connexion au bout de 25 secondes (et sans billet à payer) : on l'explique au lieu de laisser tourner.
  void _armJoinWatchdog() {
    _joinWatchdog?.cancel();
    _joinWatchdog = Timer(const Duration(seconds: 25), () {
      if (mounted && !_isInitialized && !_ticketRequired && _joinError == null && !_endHandled) {
        setState(() => _joinError = tr('La connexion au live prend trop de temps. Vérifie ta connexion et réessaie.'));
      }
    });
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
    // L'hôte quitte la page sans avoir terminé (retour, fermeture) : le live n'est PLUS coupé tout de suite. Il passe en pause (« L'hôte revient bientôt »)
    // et le serveur le termine seul après 15 minutes sans signal de l'hôte.
    if (widget.isHost && !_endHandled) {
      _markAway();
    }
    _pausePollTimer?.cancel();
    _removeUserFromSpectators();
    _heartbeatTimer?.cancel();
    _durationTimer?.cancel();
    _voiceTimer?.cancel();
    _trialTimer?.cancel();
    _ticketTimer?.cancel();
    _watchTimer?.cancel();
    _hostFeeTimer?.cancel();
    _stageTimer?.cancel();
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

    _noCamTimer?.cancel();
    _noCamTick?.cancel();
    _previewVideo?.dispose();
    _musicGen++;
    _joinWatchdog?.cancel();
    _topScroll.dispose();
    _topScrolled.dispose();
    _musicPlayer?.stop();
    _musicPlayer?.dispose();
    _previewPlayer?.stop();
    _previewPlayer?.dispose();
    if (!_noCam) {
      _engine.leaveChannel();
      _engine.release();
    }
    _commentController.dispose();
    _pinnedTextController.dispose();
    // Restaurer portrait au départ du live
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
  final String? voiceNoteId;   // type « voice » : identifiant du vocal (écoutable par l'hôte seul)
  final int? voiceSeconds;

  LiveComment({
    required this.liveId,
    required this.userId,
    required this.username,
    required this.userImage,
    required this.message,
    required this.timestamp,
    required this.type,
    this.giftId,
    this.voiceNoteId,
    this.voiceSeconds,
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
      voiceNoteId: map['voiceNoteId'] as String?,
      voiceSeconds: (map['voiceSeconds'] as num?)?.toInt(),
    );
  }
}

