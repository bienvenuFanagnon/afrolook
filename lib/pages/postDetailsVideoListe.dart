import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/challenge/challengeDetails.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/services/linkService.dart';

import 'canaux/detailsCanal.dart';

const _twitterDarkBg = Color(0xFF000000);
const _twitterCardBg = Color(0xFF16181C);
const _twitterTextPrimary = Color(0xFFFFFFFF);
const _twitterTextSecondary = Color(0xFF71767B);
const _twitterBlue = Color(0xFF1D9BF0);
const _twitterRed = Color(0xFFF91880);
const _twitterGreen = Color(0xFF00BA7C);
const _twitterYellow = Color(0xFFFFD400);

// Couleurs Afrolook
const _afroBlack = Color(0xFF000000);
const _afroGreen = Color(0xFF2ECC71);
const _afroYellow = Color(0xFFF1C40F);
const _afroRed = Color(0xFFE74C3C);
const _afroDarkGrey = Color(0xFF16181C);
const _afroLightGrey = Color(0xFF71767B);

class VideoTikTokPageDetails extends StatefulWidget {
  final Post initialPost;
  final bool isIn;

  const VideoTikTokPageDetails({Key? key, required this.initialPost,  this.isIn = false}) : super(key: key);

  @override
  _VideoTikTokPageDetailsState createState() => _VideoTikTokPageDetailsState();
}

class _VideoTikTokPageDetailsState extends State<VideoTikTokPageDetails> {
  late PageController _pageController;
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Paramètres de chargement
  final int _initialLimit = 5;
  final int _loadMoreLimit = 5;

  List<Post> _videoPosts = [];
  int _currentPage = 0;

  // Gestion des vidéos
  VideoPlayerController? _currentVideoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  // États de chargement
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreVideos = true;
  int _totalVideoCount = 1000;
  int _selectedGiftIndex = 0;
  int _selectedRepostPrice = 25;

  // Variables pour le vote
  bool _hasVoted = false;
  bool _isVoting = false;
  List<String> _votersList = [];
  Challenge? _challenge;
  bool _loadingChallenge = false;

  // Données pour la pagination intelligente
  List<String> _allVideoPostIds = [];
  List<String> _viewedVideoPostIds = [];
  DocumentSnapshot? _lastDocument;

  // Variables pour stocker les données récupérées individuellement
  UserData? _currentUser;
  Canal? _currentCanal;
  bool _isLoadingUser = false;
  bool _isLoadingCanal = false;

  List<double> giftPrices = [
    10, 25, 50, 100, 200, 300, 500, 700, 1500, 2000,
    2500, 5000, 7000, 10000, 15000, 20000, 30000,
    50000, 75000, 100000
  ];

  List<String> giftIcons = [
    '🌹','❤️','👑','💎','🏎️','⭐','🍫','🧰','🌵','🍕',
    '🍦','💻','🚗','🏠','🛩️','🛥️','🏰','💎','🏎️','🚗'
  ];

  // Stream pour les mises à jour en temps réel
  final Map<String, StreamSubscription<DocumentSnapshot>> _postSubscriptions = {};

  // Vérifier si c'est un Look Challenge
  bool get _isLookChallenge {
    return widget.initialPost.type == 'CHALLENGEPARTICIPATION';
  }

  // ==================== CONTRÔLE D'ACCÈS CANAL ====================

  // Vérifier si l'utilisateur a accès au contenu
  bool _hasAccessToContent(Post post) {
    final canal = post.canal ?? _currentCanal;
    if (canal != null) {
      final isPrivate = canal.isPrivate == true;
      final isSubscribed = canal.usersSuiviId?.contains(authProvider.loginUserData.id) ?? false;
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
      final isCurrentUser = authProvider.loginUserData.id == post.user_id;

      // Accès autorisé si :
      // - Le canal n'est pas privé
      // - OU l'utilisateur est abonné
      // - OU c'est un admin
      // - OU c'est l'utilisateur actuel
      if (!isPrivate || isSubscribed || isAdmin || isCurrentUser) {
        return true;
      }

      // Sinon, accès refusé
      return false;
    }

    // Si ce n'est pas un post de canal → accès libre
    return true;
  }

  // Vérifier si c'est un post de canal privé non accessible
  bool _isLockedContent(Post post) {
    final canal = post.canal ?? _currentCanal;
    if (canal != null) {
      final isPrivate = canal.isPrivate == true;
      final isSubscribed = canal.usersSuiviId?.contains(authProvider.loginUserData.id) ?? false;
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
      final isCurrentUser = authProvider.loginUserData.id == post.user_id;

      // Le contenu est verrouillé uniquement si :
      // - Le canal est privé
      // - L'utilisateur n'est pas abonné
      // - Et ce n'est pas un administrateur
      // - Et ce n'est pas l'utilisateur actuel
      return isPrivate && !isSubscribed && !isAdmin && !isCurrentUser;
    }
    return false;
  }

  Future<void> _loadPostRelations() async {
    try {
      // Vérifier qu'on a des IDs
      final post = widget.initialPost;
      if (post.user_id == null) return;

      // Récupérer l'utilisateur
      setState(() {
        _isLoadingUser = true;
      });
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(post.user_id)
          .get();

      if (userDoc.exists) {
        setState(() {
          _currentUser = UserData.fromJson(userDoc.data()!);
          post.user = _currentUser;
        });
      }

      // Récupérer le canal si canal_id existe
      if (post.canal_id != null && post.canal_id!.isNotEmpty) {
        setState(() {
          _isLoadingCanal = true;
        });
        final canalDoc = await FirebaseFirestore.instance
            .collection('Canaux')
            .doc(post.canal_id)
            .get();

        if (canalDoc.exists) {
          setState(() {
            _currentCanal = Canal.fromJson(canalDoc.data()!);
            post.canal = _currentCanal;
          });
        }
        setState(() {
          _isLoadingCanal = false;
        });
      }
      setState(() {
        _isLoadingUser = false;
      });

      // Rebuild UI avec les données chargées
      if (mounted) setState(() {});
    } catch (e, stack) {
      debugPrint('❌ Erreur récupération user/canal: $e\n$stack');
      setState(() {
        _isLoadingUser = false;
        _isLoadingCanal = false;
      });
    }
  }

  UserData? get currentUser {
    return widget.initialPost.user ?? _currentUser;
  }

  Canal? get currentCanal {
    return widget.initialPost.canal ?? _currentCanal;
  }

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    _loadPostRelations();
    _pageController = PageController();

    // Initialiser les fonctionnalités de challenge
    if (_isLookChallenge && widget.initialPost.challenge_id != null) {
      _loadChallengeData();
    }
    _checkIfUserHasVoted();
    _loadInitialVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeCurrentVideo();
    _postSubscriptions.forEach((key, subscription) => subscription.cancel());
    super.dispose();
  }

  void _disposeCurrentVideo() {
    _chewieController?.dispose();
    _currentVideoController?.dispose();
    setState(() {
      _isVideoInitialized = false;
    });
  }

  // ==================== FONCTIONNALITÉS CHALLENGE ET VOTE ====================

  Future<void> _checkIfUserHasVoted() async {
    try {
      final postDoc = await _firestore.collection('Posts').doc(widget.initialPost.id).get();
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        final voters = List<String>.from(data['users_votes_ids'] ?? []);
        setState(() {
          _hasVoted = voters.contains(authProvider.loginUserData.id);
          _votersList = voters;
        });
      }
    } catch (e) {
      print('Erreur lors de la vérification du vote: $e');
    }
  }

  Future<void> _loadChallengeData() async {
    if (widget.initialPost.challenge_id == null) return;

    setState(() {
      _loadingChallenge = true;
    });

    try {
      final challengeDoc = await _firestore
          .collection('Challenges')
          .doc(widget.initialPost.challenge_id)
          .get();
      if (challengeDoc.exists) {
        setState(() {
          _challenge = Challenge.fromJson(challengeDoc.data()!)
            ..id = challengeDoc.id;
        });
      }
    } catch (e) {
      print('Erreur chargement challenge: $e');
    } finally {
      setState(() {
        _loadingChallenge = false;
      });
    }
  }

  Future<void> _reloadChallengeData() async {
    try {
      if (widget.initialPost.challenge_id == null) return;

      if (mounted) {
        setState(() {
          _loadingChallenge = true;
        });
      }

      final challengeDoc = await _firestore
          .collection('Challenges')
          .doc(widget.initialPost.challenge_id)
          .get();

      if (challengeDoc.exists) {
        if (mounted) {
          setState(() {
            _challenge = Challenge.fromJson(challengeDoc.data()!)
              ..id = challengeDoc.id;
          });
        }
      } else {
        print('Challenge non trouvé: ${widget.initialPost.challenge_id}');
        if (mounted) {
          setState(() {
            _challenge = null;
          });
        }
      }
    } catch (e) {
      print('Erreur rechargement challenge: $e');
      if (mounted) {
        setState(() {
          _challenge = null;
        });
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _loadingChallenge = false;
        });
      }
    }
  }

  Future<void> _voteForLook() async {
    if (_hasVoted || _isVoting) return;

    final user = _auth.currentUser;
    if (user == null) {
      _showError('CONNECTEZ-VOUS POUR POUVOIR VOTER\nVotre vote compte pour élire le gagnant !');
      return;
    }

    setState(() {
      _isVoting = true;
    });

    try {
      // Si c'est un look challenge, recharger les données d'abord
      if (_isLookChallenge && widget.initialPost.challenge_id != null) {
        await _reloadChallengeData();

        // Vérifier à nouveau après rechargement
        if (_challenge == null) {
          _showError('Impossible de charger les données du challenge. Veuillez réessayer.');
          return;
        }

        final now = DateTime.now().microsecondsSinceEpoch;

        // Vérifier si le challenge est terminé
        if (_challenge!.isTermine || now > (_challenge!.finishedAt ?? 0)) {
          _showError('CE CHALLENGE EST TERMINÉ\nMerci pour votre intérêt !');
          return;
        }

        if (_challenge!.aVote(user.uid)) {
          _showError('VOUS AVEZ DÉJÀ VOTÉ DANS CE CHALLENGE\nMerci pour votre participation !');
          return;
        }

        if (!_challenge!.isEnCours) {
          _showError('CE CHALLENGE N\'EST PLUS ACTIF\nLe vote n\'est pas possible actuellement.');
          return;
        }

        // Vérifier le solde si vote payant
        if (!_challenge!.voteGratuit!) {
          final solde = await _getSoldeUtilisateur(user.uid);
          if (solde < _challenge!.prixVote!) {
            _showSoldeInsuffisant(_challenge!.prixVote! - solde.toInt());
            return;
          }
        }

        // Afficher la confirmation de vote
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text('Confirmer votre vote', style: TextStyle(color: Colors.white)),
            content: Text(
              !_challenge!.voteGratuit!
                  ? 'Êtes-vous sûr de vouloir voter pour ce look ?\n\nCe vote vous coûtera ${_challenge!.prixVote} FCFA.'
                  : 'Voulez-vous vraiment voter pour ce look ?\n\nVotre vote est gratuit et ne peut être changé.',
              style: TextStyle(color: Colors.grey[300]),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _isVoting = false;
                  });
                },
                child: Text('ANNULER', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _processVoteWithChallenge(user.uid);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('CONFIRMER MON VOTE', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        // Vote normal (sans challenge)
        // await _processVoteNormal(user.uid);
      }
    } catch (e) {
      print("Erreur lors de la préparation du vote: $e");
      _showError('Erreur lors de la préparation du vote: $e');
    }
  }

  Future<void> _processVoteWithChallenge(String userId) async {
    try {
      // Recharger une dernière fois avant le vote pour être sûr
      await _reloadChallengeData();

      if (_challenge == null) {
        throw Exception('Données du challenge non disponibles');
      }

      await _firestore.runTransaction((transaction) async {
        // Vérifier à nouveau le challenge avec les données fraîches
        final challengeRef = _firestore.collection('Challenges').doc(_challenge!.id!);
        final challengeDoc = await transaction.get(challengeRef);

        if (!challengeDoc.exists) throw Exception('Challenge non trouvé');

        final currentChallenge = Challenge.fromJson(challengeDoc.data()!);

        // Vérifications finales
        if (!currentChallenge.isEnCours) {
          throw Exception('Le challenge n\'est plus actif');
        }

        if (currentChallenge.aVote(userId)) {
          throw Exception('Vous avez déjà voté dans ce challenge');
        }

        final postRef = _firestore.collection('Posts').doc(widget.initialPost.id);
        final postDoc = await transaction.get(postRef);

        if (!postDoc.exists) throw Exception('Post non trouvé');

        // Débiter si vote payant
        if (!_challenge!.voteGratuit!) {
          await _debiterUtilisateur(userId, _challenge!.prixVote!,
              'Vote pour le challenge ${_challenge!.titre}');
        }

        // Mettre à jour le post
        transaction.update(postRef, {
          'votes_challenge': FieldValue.increment(1),
          'users_votes_ids': FieldValue.arrayUnion([userId]),
          'popularity': FieldValue.increment(3),
        });

        // Mettre à jour le challenge
        transaction.update(challengeRef, {
          'users_votants_ids': FieldValue.arrayUnion([userId]),
          'total_votes': FieldValue.increment(1),
          'updated_at': DateTime.now().microsecondsSinceEpoch
        });
      });

      // Mettre à jour l'état local
      if (mounted) {
        setState(() {
          _hasVoted = true;
          _votersList.add(userId);
          widget.initialPost.votesChallenge = (widget.initialPost.votesChallenge ?? 0) + 1;
        });
      }

      // Envoyer une notification
      await authProvider.sendNotification(
        userIds: [widget.initialPost.user!.oneIgnalUserid!],
        smallImage: authProvider.loginUserData.imageUrl!,
        send_user_id: authProvider.loginUserData.id!,
        recever_user_id: widget.initialPost.user_id!,
        message:
        "🎉 @${authProvider.loginUserData.pseudo!} a voté pour votre look dans le challenge ${_challenge!.titre}!",
        type_notif: NotificationType.POST.name,
        post_id: widget.initialPost.id!,
        post_type: PostDataType.VIDEO.name,
        chat_id: '',
      );

      // Récompense pour le vote
      await postProvider.interactWithPostAndIncrementSolde(widget.initialPost.id!,
          authProvider.loginUserData.id!, "vote_look", widget.initialPost.user_id!);

      _showSuccess('VOTE ENREGISTRÉ !\nMerci d\'avoir participé à l\'élection du gagnant.');
      _envoyerNotificationVote(userVotant:  authProvider.loginUserData!, userVote:widget.initialPost!.user!);

    } catch (e) {
      print("Erreur lors du vote avec challenge: $e");
      _showError('ERREUR LORS DU VOTE: ${e.toString()}\nVeuillez réessayer.');
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  Future<void> _processVoteNormal(String userId) async {
    try {
      // Mettre à jour Firestore
      await _firestore.collection('Posts').doc(widget.initialPost.id).update({
        'votes_challenge': FieldValue.increment(1),
        'users_votes_ids': FieldValue.arrayUnion([userId]),
        'popularity': FieldValue.increment(3),
      });

      // Mettre à jour l'état local
      if (mounted) {
        setState(() {
          _hasVoted = true;
          _votersList.add(userId);
          widget.initialPost.votesChallenge = (widget.initialPost.votesChallenge ?? 0) + 1;
        });
      }

      // Envoyer une notification au propriétaire du look
      await authProvider.sendNotification(
        userIds: [widget.initialPost.user!.oneIgnalUserid!],
        smallImage: authProvider.loginUserData.imageUrl!,
        send_user_id: authProvider.loginUserData.id!,
        recever_user_id: widget.initialPost.user_id!,
        message: "🎉 @${authProvider.loginUserData.pseudo!} a voté pour votre look !",
        type_notif: NotificationType.POST.name,
        post_id: widget.initialPost.id!,
        post_type: PostDataType.VIDEO.name,
        chat_id: '',
      );

      // Récompense pour le vote
      await postProvider.interactWithPostAndIncrementSolde(widget.initialPost.id!,
          authProvider.loginUserData.id!, "vote_look", widget.initialPost.user_id!);

      _showSuccess('🎉 Vote enregistré !');
    } catch (e) {
      print("Erreur lors du vote normal: $e");
      _showError('Erreur lors du vote: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  // Méthodes utilitaires pour le vote
  Future<double> _getSoldeUtilisateur(String userId) async {
    final doc = await _firestore.collection('Users').doc(userId).get();
    return (doc.data()?['votre_solde_principal'] ?? 0).toDouble();
  }

  Future<void> _debiterUtilisateur(String userId, int montant, String raison) async {
    await _firestore.collection('Users').doc(userId).update({
      'votre_solde_principal': FieldValue.increment(-montant)
    });
    String appDataId = authProvider.appDefaultData.id!;

    await _firestore.collection('AppData').doc(appDataId).set({
      'solde_gain': FieldValue.increment(montant)
    }, SetOptions(merge: true));
    await _createTransaction(
        TypeTransaction.DEPENSE.name, montant.toDouble(), raison, userId);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showSoldeInsuffisant(int montantManquant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('SOLDE INSUFFISANT', style: TextStyle(color: Colors.yellow)),
        content: Text(
          'Il vous manque $montantManquant FCFA pour pouvoir voter.\n\n'
              'Rechargez votre compte pour soutenir votre look préféré !',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('PLUS TARD', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => DepositScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('RECHARGER MAINTENANT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showVoteConfirmationDialog() {
    final user = _auth.currentUser;

    // Si c'est un look challenge avec vote payant
    if (_isLookChallenge && _challenge != null && !_challenge!.voteGratuit!) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: _twitterCardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _twitterGreen, width: 2),
            ),
            title: Text(
              '🎉 Voter pour ce Look',
              style: TextStyle(
                color: _twitterGreen,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              'Ce vote vous coûtera ${_challenge!.prixVote} FCFA.\n\n'
                  'Voulez-vous continuer ?',
              style: TextStyle(color: _twitterTextPrimary),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler', style: TextStyle(color: _twitterTextSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _voteForLook();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _twitterGreen,
                ),
                child: Text('Voter ${_challenge!.prixVote} FCFA',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    } else {
      // Dialogue de confirmation normal
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: _twitterCardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _twitterGreen, width: 2),
            ),
            title: Text(
              '🎉 Voter pour ce Look',
              style: TextStyle(
                color: _twitterGreen,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              'Vous allez voter pour ce look${_isLookChallenge ? ' challenge' : ''}. Cette action est irréversible${_isLookChallenge && _challenge != null ? ' et vous rapportera 3 points' : ''}!',
              style: TextStyle(color: _twitterTextPrimary),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler', style: TextStyle(color: _twitterTextSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _voteForLook();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _twitterGreen,
                ),
                child: Text('Voter', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _envoyerNotificationVote({
    required UserData userVotant,   // celui qui a voté
    required UserData userVote,     // celui qui reçoit le vote
  }) async
  {
    try {
      // Récupérer tous les IDs OneSignal des utilisateurs
      final userIds = await authProvider.getAllUsersOneSignaUserId();

      if (userIds.isEmpty) {
        debugPrint("⚠️ Aucun utilisateur à notifier.");
        return;
      }

      // Construire le message
      final message = "👏 ${userVotant.pseudo} a voté pour ${userVote.pseudo}!";

      await authProvider.sendNotification(
        userIds: userIds,
        smallImage: userVotant.imageUrl ?? '', // image de l'utilisateur qui a voté
        send_user_id: userVotant.id!,
        recever_user_id: userVote.id ?? "",
        message: message,
        type_notif: 'VOTE',
        post_id: '',      // optionnel si tu n'as pas de post associé
        post_type: '',    // optionnel
        chat_id: '',      // optionnel
      );

      debugPrint("✅ Notification envoyée: $message");
    } catch (e, stack) {
      debugPrint("❌ Erreur envoi notification vote: $e\n$stack");
    }
  }

  // ==================== GESTION DES VIDÉOS ====================

  Future<void> _loadInitialVideos() async {
    try {
      setState(() => _isLoading = true);

      // Charger les données nécessaires
      await Future.wait([
        _getTotalVideoCount(),
        _getAppData(),
        _getUserData(),
      ]);

      // Commencer avec la vidéo initiale
      _videoPosts = [widget.initialPost];

      // Marquer la vidéo initiale comme vue
      await _markPostAsSeen(widget.initialPost);

      // Charger les vidéos suivantes avec priorité aux non vues
      await _loadMoreVideos(isInitialLoad: true);

      // Initialiser la première vidéo
      if (_videoPosts.isNotEmpty) {
        _initializeVideo(_videoPosts.first);
      }
    } catch (e) {
      print('Erreur chargement initial: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getTotalVideoCount() async {
    try {
      final query = _firestore.collection('Posts')
          .where('postDataType', isEqualTo: PostDataType.VIDEO.name)
          .where('status', isEqualTo: PostStatus.VALIDE.name);

      final snapshot = await query.count().get();
      _totalVideoCount = snapshot.count ?? 1000;
      print('Nombre total de vidéos: $_totalVideoCount');
    } catch (e) {
      print('Erreur comptage vidéos: $e');
      _totalVideoCount = 1000;
    }
  }

  Future<void> _getAppData() async {
    try {
      final appDataRef = _firestore.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT');
      final appDataSnapshot = await appDataRef.get();

      if (appDataSnapshot.exists) {
        final appData = AppDefaultData.fromJson(appDataSnapshot.data() ?? {});
        _allVideoPostIds = appData.allPostIds?.where((id) => id.isNotEmpty).toList() ?? [];
        print('IDs vidéo disponibles: ${_allVideoPostIds.length}');
      }
    } catch (e) {
      print('Erreur récupération AppData: $e');
      _allVideoPostIds = [];
    }
  }

  Future<void> _getUserData() async {
    try {
      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) return;

      final userDoc = await _firestore.collection('Users').doc(currentUserId).get();
      if (userDoc.exists) {
        final userData = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
        _viewedVideoPostIds = userData.viewedPostIds?.where((id) => id.isNotEmpty).toList() ?? [];
        print('Vidéos déjà vues: ${_viewedVideoPostIds.length}');
      }
    } catch (e) {
      print('Erreur récupération UserData: $e');
      _viewedVideoPostIds = [];
    }
  }

  Future<void> _loadMoreVideos({bool isInitialLoad = false}) async {
    if (_isLoadingMore || !_hasMoreVideos) return;

    try {
      setState(() => _isLoadingMore = true);

      final currentUserId = authProvider.loginUserData.id;

      if (currentUserId != null && _allVideoPostIds.isNotEmpty) {
        await _loadVideosWithPriority(currentUserId, isInitialLoad);
      } else {
        await _loadVideosChronologically();
      }

      _hasMoreVideos = _videoPosts.length < _totalVideoCount;

    } catch (e) {
      print('Erreur chargement supplémentaire: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadVideosWithPriority(String currentUserId, bool isInitialLoad) async {
    final unseenVideoIds = _allVideoPostIds.where((postId) =>
    !_viewedVideoPostIds.contains(postId) &&
        !_videoPosts.any((post) => post.id == postId)
    ).toList();

    final seenVideoIds = _allVideoPostIds.where((postId) =>
    _viewedVideoPostIds.contains(postId) &&
        !_videoPosts.any((post) => post.id == postId)
    ).toList();

    print('📊 Vidéos non vues disponibles: ${unseenVideoIds.length}');
    print('📊 Vidéos déjà vues disponibles: ${seenVideoIds.length}');

    final limit = isInitialLoad ? _initialLimit - 1 : _loadMoreLimit;

    final unseenVideos = await _loadVideosByIds(unseenVideoIds, limit: limit, isSeen: false);
    print('✅ Vidéos non vues chargées: ${unseenVideos.length}');

    if (unseenVideos.length < limit) {
      final remainingLimit = limit - unseenVideos.length;
      final seenVideos = await _loadVideosByIds(seenVideoIds, limit: remainingLimit, isSeen: true);
      print('✅ Vidéos vues chargées: ${seenVideos.length}');

      _videoPosts.addAll([...unseenVideos, ...seenVideos]);
    } else {
      _videoPosts.addAll(unseenVideos);
    }

    for (final post in _videoPosts) {
      _subscribeToPostUpdates(post);
    }
  }

  Future<List<Post>> _loadVideosByIds(List<String> videoIds, {required int limit, required bool isSeen}) async {
    if (videoIds.isEmpty || limit <= 0) return [];

    final idsToLoad = videoIds.take(limit).toList();
    final videos = <Post>[];

    print('🔹 Chargement de ${idsToLoad.length} vidéos par ID');

    for (var i = 0; i < idsToLoad.length; i += 10) {
      final batchIds = idsToLoad.skip(i).take(10).where((id) => id.isNotEmpty).toList();
      if (batchIds.isEmpty) continue;

      try {
        final snapshot = await _firestore
            .collection('Posts')
            .where(FieldPath.documentId, whereIn: batchIds)
            .where('postDataType', isEqualTo: PostDataType.VIDEO.name)
            .get();

        for (var doc in snapshot.docs) {
          try {
            final post = Post.fromJson(doc.data() as Map<String, dynamic>);
            post.hasBeenSeenByCurrentUser = isSeen;
            videos.add(post);
          } catch (e) {
            print('⚠️ Erreur parsing vidéo ${doc.id}: $e');
          }
        }
      } catch (e) {
        print('❌ Erreur batch chargement vidéos: $e');
        for (final id in batchIds) {
          try {
            final doc = await _firestore.collection('Posts').doc(id).get();
            if (doc.exists) {
              final post = Post.fromJson(doc.data() as Map<String, dynamic>);
              post.hasBeenSeenByCurrentUser = isSeen;
              videos.add(post);
            }
          } catch (e) {
            print('❌ Erreur chargement vidéo $id: $e');
          }
        }
      }
    }

    return videos;
  }

  Future<void> _loadVideosChronologically() async {
    try {
      Query query = _firestore.collection('Posts')
          .where('postDataType', isEqualTo: PostDataType.VIDEO.name)
          .where('status', isEqualTo: PostStatus.VALIDE.name)
          .orderBy('created_at', descending: true);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.limit(_loadMoreLimit).get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      final newVideos = snapshot.docs.map((doc) {
        final post = Post.fromJson(doc.data() as Map<String, dynamic>);
        post.hasBeenSeenByCurrentUser = _viewedVideoPostIds.contains(post.id);
        _subscribeToPostUpdates(post);
        return post;
      }).toList();

      final existingIds = _videoPosts.map((v) => v.id).toSet();
      final uniqueNewVideos = newVideos.where((video) =>
      video.id != null && !existingIds.contains(video.id)).toList();

      _videoPosts.addAll(uniqueNewVideos);

    } catch (e) {
      print('❌ Erreur chargement chronologique: $e');
    }
  }

  void _subscribeToPostUpdates(Post post) {
    if (post.id == null || _postSubscriptions.containsKey(post.id)) return;

    final subscription = _firestore.collection('Posts').doc(post.id).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final updatedPost = Post.fromJson(snapshot.data() as Map<String, dynamic>);

        setState(() {
          final index = _videoPosts.indexWhere((p) => p.id == post.id);
          if (index != -1) {
            updatedPost.user = _videoPosts[index].user;
            updatedPost.canal = _videoPosts[index].canal;
            updatedPost.hasBeenSeenByCurrentUser = _videoPosts[index].hasBeenSeenByCurrentUser;
            _videoPosts[index] = updatedPost;
          }
        });
      }
    });

    _postSubscriptions[post.id!] = subscription;
  }

  Future<void> _initializeVideo(Post post) async {
    _disposeCurrentVideo();

    if (post.url_media == null || post.url_media!.isEmpty) {
      print('⚠️ Aucune URL média pour la vidéo ${post.id}');
      return;
    }

    try {
      print('🎬 Initialisation vidéo: ${post.url_media}');

      _currentVideoController = VideoPlayerController.network(post.url_media!);
      await _currentVideoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _currentVideoController!,
        autoPlay: true,
        looping: true,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: _afroGreen,
          handleColor: _afroGreen,
          backgroundColor: _afroLightGrey.withOpacity(0.3),
          bufferedColor: _afroLightGrey.withOpacity(0.1),
        ),
        placeholder: Container(
          color: _afroBlack,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: _afroGreen),
                SizedBox(height: 16),
                Text('Chargement...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
        autoInitialize: true,
      );

      setState(() => _isVideoInitialized = true);
      await _recordPostView(post);

    } catch (e) {
      print('❌ Erreur initialisation vidéo: $e');
      setState(() => _isVideoInitialized = false);
    }
  }

  Future<void> _markPostAsSeen(Post post) async {
    if (post.id == null) return;

    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    try {
      if (!_viewedVideoPostIds.contains(post.id)) {
        _viewedVideoPostIds.add(post.id!);

        await _firestore.collection('Users').doc(currentUserId).update({
          'viewedPostIds': FieldValue.arrayUnion([post.id]),
        });

        post.hasBeenSeenByCurrentUser = true;
      }
    } catch (e) {
      print('❌ Erreur marquage post comme vu: $e');
    }
  }

  Future<void> _recordPostView(Post post) async {
    if (post.id == null) return;

    try {
      await _markPostAsSeen(post);

      if (!post.users_vue_id!.contains(authProvider.loginUserData.id)) {
        await _firestore.collection('Posts').doc(post.id).update({
          'vues': FieldValue.increment(1),
          'users_vue_id': FieldValue.arrayUnion([authProvider.loginUserData.id!]),
        });

        post.vues = (post.vues ?? 0) + 1;
        post.users_vue_id!.add(authProvider.loginUserData.id!);
      }
    } catch (e) {
      print('❌ Erreur enregistrement vue: $e');
    }
  }

  // ==================== WIDGETS ====================

  Widget _buildVideoPlayer(Post post) {
    if (!_isVideoInitialized) {
      return _buildVideoPlaceholder(post);
    }

    return Stack(
      children: [
        Chewie(controller: _chewieController!),
      ],
    );
  }

  Widget _buildVideoPlaceholder(Post post) {
    return Container(
      color: _afroBlack,
      child: Stack(
        children: [
          if (post.images != null && post.images!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: post.images!.first,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          else
            Container(
              color: _afroDarkGrey,
              child: Center(
                child: Icon(Icons.videocam, color: _afroLightGrey, size: 80),
              ),
            ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: _afroGreen),
                SizedBox(height: 16),
                Text(
                  'Chargement de la vidéo...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedContent(Post post) {
    final canal = post.canal ?? _currentCanal;
    final isPrivate = canal?.isPrivate == true;
    final subscriptionPrice = canal?.subscriptionPrice ?? 0;

    return Container(
      color: _afroBlack,
      child: Stack(
        children: [
          // Image de fond floutée
          if (post.images != null && post.images!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: post.images!.first,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.7),
              colorBlendMode: BlendMode.darken,
            )
          else
            Container(
              color: _afroDarkGrey,
            ),

          // Overlay de contenu verrouillé
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock,
                        color: _afroYellow,
                        size: 80,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Contenu Verrouillé',
                        style: TextStyle(
                          color: _afroYellow,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      Text(
                        isPrivate
                            ? 'Ce contenu est réservé aux abonnés du canal.\nAbonnez-vous pour accéder à cette vidéo et à tout le contenu exclusif.'
                            : 'Ce contenu est réservé aux abonnés du canal.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 30),
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.symmetric(horizontal: 40),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _afroYellow,
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          onPressed: () {
                            if (canal != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CanalDetails(canal: canal),
                                ),
                              );
                            }

                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_open, size: 24),
                              SizedBox(width: 12),
                              Text(
                                isPrivate
                                    ? 'S\'ABONNER - ${subscriptionPrice.toInt()} FCFA'
                                    : 'SUIVRE LE CANAL',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Retour',
                          style: TextStyle(
                            color: _afroGreen,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLookChallengeSection(Post post) {
    if (!_isLookChallenge) return SizedBox();

    return Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _twitterGreen),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: _twitterGreen, size: 20),
                SizedBox(width: 8),
                Text(
                  'LOOK CHALLENGE',
                  style: TextStyle(
                    color: _twitterGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.arrow_back, color: Colors.yellow),
                ),

                Text(
                  '${post.votesChallenge ?? 0} votes',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                if (!_hasVoted && _challenge != null && _challenge!.isEnCours)
                  ElevatedButton(
                    onPressed: _isVoting ? null : _showVoteConfirmationDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _twitterGreen,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: _isVoting
                        ? SizedBox(
                      width: 16,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      'VOTER',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white
                      ),
                    ),
                  )
                else if (_hasVoted)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _twitterGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _twitterGreen),
                    ),
                    child: Text(
                      'DÉJÀ VOTÉ',
                      style: TextStyle(
                        color: _twitterGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(Post post) {
    final user = post.user;
    final canal = post.canal;

    return Positioned(
      bottom: 120,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canal != null) ...[
            GestureDetector(
              onTap: () {
                if (canal != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CanalDetails(canal: canal),
                    ),
                  );
                }
              },
              child: Text(
                '#${canal.titre ?? ''}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              '${canal.usersSuiviId?.length ?? 0} abonnés',
              style: TextStyle(color: Colors.white),
            ),
          ] else if (user != null) ...[
            GestureDetector(
              onTap: () {
                if (user != null) {
  showUserDetailsModalDialog(user, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
                }
              },
              child: Text(
                '@${user.pseudo ?? ''}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              '${user.userAbonnesIds?.length ?? 0} abonnés',
              style: TextStyle(color: Colors.white),
            ),
          ],
          SizedBox(height: 8),
          if (post.description != null)
            Container(
              constraints: BoxConstraints(maxWidth: 250),
              child: Text(
                post.description!,
                style: TextStyle(color: Colors.white),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Post post) {
    final isLiked = post.users_love_id!.contains(authProvider.loginUserData.id);
    final hasAccess = _hasAccessToContent(post);

    return Positioned(
      right: 16,
      bottom: 120,
      child: Column(
        children: [
          // Avatar utilisateur
          post.type == PostType.CHALLENGE.name ? SizedBox.shrink() : GestureDetector(
            onTap: () {

              final user = post.user??_currentUser;


              if (user != null) {
              showUserDetailsModalDialog(user, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
              }
                        },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: _afroGreen, width: 2),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 25,
                backgroundImage: NetworkImage(
                post.canal?.urlImage ??    post.user?.imageUrl ??'',
                ),
              ),
            ),
          ),
          post.type == PostType.CHALLENGE.name ? SizedBox.shrink() : SizedBox(height: 20),

          // Like
          Column(
            children: [
              if (_isLookChallenge)
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        _hasVoted ? Icons.how_to_vote : Icons.how_to_vote_outlined,
                        color: _hasVoted ? _twitterGreen : Colors.white,
                        size: 35,
                      ),
                      onPressed: hasAccess ? _voteForLook : null,
                    ),
                    Text(
                      _formatCount(post.votesChallenge ?? 0),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? _afroRed : Colors.white,
                  size: 35,
                ),
                onPressed: hasAccess ? () => _handleLike(post) : null,
              ),
              Text(
                _formatCount(post.loves ?? 0),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // Commentaires
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 35),
                onPressed: hasAccess ? () => _showCommentsModal(post) : null,
              ),
              Text(
                _formatCount(post.comments ?? 0),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // Cadeaux
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.card_giftcard, color: _afroYellow, size: 35),
                onPressed: hasAccess ? () => _showGiftDialog(post) : null,
              ),
              Text(
                _formatCount(post.users_cadeau_id?.length ?? 0),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // Vue
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 35),
                onPressed: hasAccess ? () {} : null,
              ),
              Text(
                _formatCount(post.vues ?? 0),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // Partager
          IconButton(
            icon: Icon(Icons.share, color: Colors.white, size: 35),
            onPressed: hasAccess ? () => _sharePost(post) : null,
          ),

          // Menu
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white, size: 35),
            onPressed: hasAccess ? () => _showPostMenu(post) : null,
          ),
        ],
      ),
    );
  }

  // ==================== MÉTHODES D'INTERACTION ====================

  Future<void> _handleLike(Post post) async {
    try {
      if (!post.users_love_id!.contains(authProvider.loginUserData.id)) {
        await _firestore.collection('Posts').doc(post.id).update({
          'loves': FieldValue.increment(1),
          'users_love_id': FieldValue.arrayUnion([authProvider.loginUserData.id!]),
        });

        await postProvider.interactWithPostAndIncrementSolde(
            post.id!,
            authProvider.loginUserData.id!,
            "like",
            post.user_id!
        );
      }
    } catch (e) {
      print('Erreur like: $e');
    }
  }

  void _showCommentsModal(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: _afroBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Commentaires',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PostComments(post: post),
            ),
          ],
        ),
      ),
    );
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.yellow, width: 2),
          ),
          title: Text(
            'Solde Insuffisant',
            style: TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Votre solde est insuffisant pour effectuer cette action. Veuillez recharger votre compte.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Recharger', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  void _showGiftDialog(Post post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final height = MediaQuery.of(context).size.height * 0.6;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.yellow, width: 2),
              ),
              child: Container(
                height: height,
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Envoyer un Cadeau',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Choisissez le montant en FCFA',
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 12),
                    Expanded(
                      child: GridView.builder(
                        physics: BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: giftPrices.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => setState(() => _selectedGiftIndex = index),
                            child: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _selectedGiftIndex == index
                                    ? Colors.green
                                    : Colors.grey[800],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedGiftIndex == index
                                      ? Colors.yellow
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    giftIcons[index],
                                    style: TextStyle(fontSize: 24),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    '${giftPrices[index].toInt()} FCFA',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Votre solde: ${authProvider.loginUserData.votre_solde_principal?.toInt() ?? 0} FCFA',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Annuler', style: TextStyle(color: Colors.white)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _sendGift(giftPrices[_selectedGiftIndex], post);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Envoyer',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendGift(double amount, Post post) async {
    try {
      setState(() => _isLoading = true);

      final firestore = FirebaseFirestore.instance;
      await authProvider.getAppData();

      final senderSnap = await firestore.collection('Users').doc(authProvider.loginUserData.id).get();
      if (!senderSnap.exists) {
        throw Exception("Utilisateur expéditeur introuvable");
      }

      final senderData = senderSnap.data() as Map<String, dynamic>;
      final double senderBalance = (senderData['votre_solde_principal'] ?? 0.0).toDouble();

      if (senderBalance >= amount) {
        final double gainDestinataire = amount * 0.5;
        final double gainApplication = amount * 0.5;

        await firestore.collection('Users').doc(authProvider.loginUserData.id).update({
          'votre_solde_principal': FieldValue.increment(-amount),
        });

        await firestore.collection('Users').doc(post.user!.id).update({
          'votre_solde_principal': FieldValue.increment(gainDestinataire),
        });

        String appDataId = authProvider.appDefaultData.id!;
        await firestore.collection('AppData').doc(appDataId).update({
          'solde_gain': FieldValue.increment(gainApplication),
        });

        await firestore.collection('Posts').doc(post.id).update({
          'users_cadeau_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(5),
        });

        await _createTransaction(TypeTransaction.DEPENSE.name, amount, "Cadeau envoyé à @${post.user!.pseudo}", authProvider.loginUserData.id!);
        await _createTransaction(TypeTransaction.GAIN.name, gainDestinataire, "Cadeau reçu de @${authProvider.loginUserData.pseudo}", post.user_id!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              '🎁 Cadeau de ${amount.toInt()} FCFA envoyé avec succès!',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );

        await authProvider.sendNotification(
          userIds: [post.user!.oneIgnalUserid!],
          smallImage: "",
          send_user_id: "",
          recever_user_id: "${post.user_id!}",
          message: "🎁 Vous avez reçu un cadeau de ${amount.toInt()} FCFA !",
          type_notif: NotificationType.POST.name,
          post_id: "${post.id!}",
          post_type: PostDataType.VIDEO.name,
          chat_id: '',
        );
      } else {
        _showInsufficientBalanceDialog();
      }
    } catch (e) {
      print("Erreur envoi cadeau: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Erreur lors de l\'envoi du cadeau',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createTransaction(String type, double montant, String description, String userid) async {
    try {
      final transaction = TransactionSolde()
        ..id = _firestore.collection('TransactionSoldes').doc().id
        ..user_id = userid
        ..type = type
        ..statut = StatutTransaction.VALIDER.name
        ..description = description
        ..montant = montant
        ..methode_paiement = "cadeau"
        ..createdAt = DateTime.now().millisecondsSinceEpoch
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;

      await _firestore.collection('TransactionSoldes').doc(transaction.id).set(transaction.toJson());
    } catch (e) {
      print("Erreur création transaction: $e");
    }
  }

  Future<void> _sharePost(Post post) async {
    final AppLinkService _appLinkService = AppLinkService();
    _appLinkService.shareContent(
      type: AppLinkType.post,
      id: post.id!,
      message: post.description ?? "",
      mediaUrl: post.url_media ?? "",
    );
  }

  void _showPostMenu(Post post) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: _twitterCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.user_id != authProvider.loginUserData.id)
              _buildMenuOption(
                Icons.flag,
                "Signaler",
                _twitterTextPrimary,
                    () async {
                  post.status = PostStatus.SIGNALER.name;
                  final value = await postProvider.updateVuePost(post, context);
                  Navigator.pop(context);

                  final snackBar = SnackBar(
                    content: Text(
                      value ? 'Post signalé !' : 'Échec du signalement !',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: value ? Colors.green : Colors.red),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
              ),

            if (post.user!.id == authProvider.loginUserData.id ||
                authProvider.loginUserData.role == UserRole.ADM.name)
              _buildMenuOption(
                Icons.delete,
                "Supprimer",
                Colors.red,
                    () async {
                  if (authProvider.loginUserData.role == UserRole.ADM.name) {
                    await _deletePost(post, context);
                  } else {
                    post.status = PostStatus.SUPPRIMER.name;
                    await _deletePost(post, context);
                  }
                  Navigator.pop(context);

                  final snackBar = SnackBar(
                    content: Text(
                      'Post supprimé !',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
              ),

            SizedBox(height: 8),
            Container(height: 0.5, color: _twitterTextSecondary.withOpacity(0.3)),
            SizedBox(height: 8),

            _buildMenuOption(Icons.cancel, "Annuler", _twitterTextSecondary, () {
              Navigator.pop(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String text, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 12),
              Text(text, style: TextStyle(color: color, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePost(Post post, BuildContext context) async {
    try {
      final canDelete = authProvider.loginUserData.role == UserRole.ADM.name ||
          (post.type == PostType.POST.name &&
              post.user?.id == authProvider.loginUserData.id);

      if (!canDelete) return;

      await _firestore.collection('Posts').doc(post.id).delete();
      // 🔹 Retirer l'ID de allPostIds
      final appDefaultRef = _firestore.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT'); // Remplace par ton docId réel

      await appDefaultRef.update({
        'allPostIds': FieldValue.arrayRemove([post.id]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Post supprimé !',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Échec de la suppression !',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
      print('Erreur suppression post: $e');
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  // ==================== BUILD PRINCIPAL ====================

  Widget _buildVideoPage(Post post) {
    final isLocked = _isLockedContent(post);
    final hasAccess = _hasAccessToContent(post);

    if (isLocked) {
      return _buildLockedContent(post);
    }

    return Stack(
      children: [
        // Lecteur vidéo
        _buildVideoPlayer(post),

        // Informations utilisateur
        _buildUserInfo(post),

        // Section Look Challenge
        _buildLookChallengeSection(post),

        // Boutons d'action
        _buildActionButtons(post),
        if (widget.isIn)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.arrow_back, color: Colors.yellow),
                ),
                Text(
                  'Afrolook',
                  style: TextStyle(
                    color: _afroGreen,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        // Indicateur de chargement suivant
        if (_isLoadingMore)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(color: _afroGreen),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _afroBlack,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _afroGreen))
          : PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _videoPosts.length + (_hasMoreVideos ? 1 : 0),
        onPageChanged: (index) async {
          if (index >= _videoPosts.length - 2 && _hasMoreVideos && !_isLoadingMore) {
            await _loadMoreVideos();
          }

          if (index < _videoPosts.length) {
            setState(() => _currentPage = index);
            _initializeVideo(_videoPosts[index]);
          }
        },
        itemBuilder: (context, index) {
          if (index >= _videoPosts.length) {
            return Center(
              child: CircularProgressIndicator(color: _afroGreen),
            );
          }

          final post = _videoPosts[index];
          return _buildVideoPage(post);
        },
      ),
    );
  }
}


// import 'dart:async';
// import 'dart:math';
// import 'package:afrotok/pages/challenge/challengeDetails.dart';
// import 'package:afrotok/pages/paiement/newDepot.dart';
// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';
// import 'package:chewie/chewie.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:provider/provider.dart';
// import 'package:afrotok/models/model_data.dart';
// import 'package:afrotok/providers/authProvider.dart';
// import 'package:afrotok/providers/postProvider.dart';
// import 'package:afrotok/pages/postComments.dart';
// import 'package:afrotok/services/linkService.dart';
//
// const _twitterDarkBg = Color(0xFF000000);
// const _twitterCardBg = Color(0xFF16181C);
// const _twitterTextPrimary = Color(0xFFFFFFFF);
// const _twitterTextSecondary = Color(0xFF71767B);
// const _twitterBlue = Color(0xFF1D9BF0);
// const _twitterRed = Color(0xFFF91880);
// const _twitterGreen = Color(0xFF00BA7C);
// const _twitterYellow = Color(0xFFFFD400);
//
// // Couleurs Afrolook
// const _afroBlack = Color(0xFF000000);
// const _afroGreen = Color(0xFF2ECC71);
// const _afroYellow = Color(0xFFF1C40F);
// const _afroRed = Color(0xFFE74C3C);
// const _afroDarkGrey = Color(0xFF16181C);
// const _afroLightGrey = Color(0xFF71767B);
//
// class VideoTikTokPageDetails extends StatefulWidget {
//   final Post initialPost;
//   final bool isIn;
//
//   const VideoTikTokPageDetails({Key? key, required this.initialPost,  this.isIn = false}) : super(key: key);
//
//   @override
//   _VideoTikTokPageDetailsState createState() => _VideoTikTokPageDetailsState();
// }
//
// class _VideoTikTokPageDetailsState extends State<VideoTikTokPageDetails> {
//   late PageController _pageController;
//   late UserAuthProvider authProvider;
//   late PostProvider postProvider;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   // Paramètres de chargement
//   final int _initialLimit = 5;
//   final int _loadMoreLimit = 5;
//
//   List<Post> _videoPosts = [];
//   int _currentPage = 0;
//
//   // Gestion des vidéos
//   VideoPlayerController? _currentVideoController;
//   ChewieController? _chewieController;
//   bool _isVideoInitialized = false;
//
//   // États de chargement
//   bool _isLoading = true;
//   bool _isLoadingMore = false;
//   bool _hasMoreVideos = true;
//   int _totalVideoCount = 1000;
//   int _selectedGiftIndex = 0;
//   int _selectedRepostPrice = 25;
//
//   // Variables pour le vote
//   bool _hasVoted = false;
//   bool _isVoting = false;
//   List<String> _votersList = [];
//   Challenge? _challenge;
//   bool _loadingChallenge = false;
//
//   // Données pour la pagination intelligente
//   List<String> _allVideoPostIds = [];
//   List<String> _viewedVideoPostIds = [];
//   DocumentSnapshot? _lastDocument;
//
//   List<double> giftPrices = [
//     10, 25, 50, 100, 200, 300, 500, 700, 1500, 2000,
//     2500, 5000, 7000, 10000, 15000, 20000, 30000,
//     50000, 75000, 100000
//   ];
//
//   List<String> giftIcons = [
//     '🌹','❤️','👑','💎','🏎️','⭐','🍫','🧰','🌵','🍕',
//     '🍦','💻','🚗','🏠','🛩️','🛥️','🏰','💎','🏎️','🚗'
//   ];
//
//   // Stream pour les mises à jour en temps réel
//   final Map<String, StreamSubscription<DocumentSnapshot>> _postSubscriptions = {};
//
//   // Vérifier si c'est un Look Challenge
//   bool get _isLookChallenge {
//     return widget.initialPost.type == 'CHALLENGEPARTICIPATION';
//   }
//   Future<void> _envoyerNotificationVote({
//     required UserData userVotant,   // celui qui a voté
//     required UserData userVote,     // celui qui reçoit le vote
//   }) async
//   {
//     try {
//       // Récupérer tous les IDs OneSignal des utilisateurs
//       final userIds = await authProvider.getAllUsersOneSignaUserId();
//
//       if (userIds.isEmpty) {
//         debugPrint("⚠️ Aucun utilisateur à notifier.");
//         return;
//       }
//
//       // Construire le message
//       final message = "👏 ${userVotant.pseudo} a voté pour ${userVote.pseudo}!";
//
//       await authProvider.sendNotification(
//         userIds: userIds,
//         smallImage: userVotant.imageUrl ?? '', // image de l'utilisateur qui a voté
//         send_user_id: userVotant.id!,
//         recever_user_id: userVote.id ?? "",
//         message: message,
//         type_notif: 'VOTE',
//         post_id: '',      // optionnel si tu n’as pas de post associé
//         post_type: '',    // optionnel
//         chat_id: '',      // optionnel
//       );
//
//       debugPrint("✅ Notification envoyée: $message");
//     } catch (e, stack) {
//       debugPrint("❌ Erreur envoi notification vote: $e\n$stack");
//     }
//   }
//   Future<void> _loadPostRelations() async {
//     try {
//       // Vérifier qu'on a des IDs
//       final post = widget.initialPost;
//       if (post.user_id == null || post.canal_id == null) return;
//
//       // Récupérer l'utilisateur
//       final userDoc = await FirebaseFirestore.instance
//           .collection('Users')
//           .doc(post.user_id)
//           .get();
//
//       if (userDoc.exists) {
//         post.user = UserData.fromJson(userDoc.data()!); // Assurez-vous que User.fromJson existe
//       }
//
//       // Récupérer le canal
//       final canalDoc = await FirebaseFirestore.instance
//           .collection('Canaux')
//           .doc(post.canal_id)
//           .get();
//
//       if (canalDoc.exists) {
//         post.canal = Canal.fromJson(canalDoc.data()!); // Assurez-vous que Canal.fromJson existe
//       }
//
//       // Rebuild UI avec les données chargées
//       if (mounted) setState(() {});
//     } catch (e, stack) {
//       debugPrint('❌ Erreur récupération user/canal: $e\n$stack');
//     }
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     postProvider = Provider.of<PostProvider>(context, listen: false);
//     _loadPostRelations();
//     _pageController = PageController();
//
//     // Initialiser les fonctionnalités de challenge
//     if (_isLookChallenge && widget.initialPost.challenge_id != null) {
//       _loadChallengeData();
//     }
//     _checkIfUserHasVoted();
//     _loadInitialVideos();
//   }
//
//   @override
//   void dispose() {
//     _pageController.dispose();
//     _disposeCurrentVideo();
//     _postSubscriptions.forEach((key, subscription) => subscription.cancel());
//     super.dispose();
//   }
//
//   void _disposeCurrentVideo() {
//     _chewieController?.dispose();
//     _currentVideoController?.dispose();
//     setState(() {
//       _isVideoInitialized = false;
//     });
//   }
//
//   // ==================== FONCTIONNALITÉS CHALLENGE ET VOTE ====================
//
//   Future<void> _checkIfUserHasVoted() async {
//     try {
//       final postDoc = await _firestore.collection('Posts').doc(widget.initialPost.id).get();
//       if (postDoc.exists) {
//         final data = postDoc.data() as Map<String, dynamic>;
//         final voters = List<String>.from(data['users_votes_ids'] ?? []);
//         setState(() {
//           _hasVoted = voters.contains(authProvider.loginUserData.id);
//           _votersList = voters;
//         });
//       }
//     } catch (e) {
//       print('Erreur lors de la vérification du vote: $e');
//     }
//   }
//
//   Future<void> _loadChallengeData() async {
//     if (widget.initialPost.challenge_id == null) return;
//
//     setState(() {
//       _loadingChallenge = true;
//     });
//
//     try {
//       final challengeDoc = await _firestore
//           .collection('Challenges')
//           .doc(widget.initialPost.challenge_id)
//           .get();
//       if (challengeDoc.exists) {
//         setState(() {
//           _challenge = Challenge.fromJson(challengeDoc.data()!)
//             ..id = challengeDoc.id;
//         });
//       }
//     } catch (e) {
//       print('Erreur chargement challenge: $e');
//     } finally {
//       setState(() {
//         _loadingChallenge = false;
//       });
//     }
//   }
//
//   Future<void> _reloadChallengeData() async {
//     try {
//       if (widget.initialPost.challenge_id == null) return;
//
//       if (mounted) {
//         setState(() {
//           _loadingChallenge = true;
//         });
//       }
//
//       final challengeDoc = await _firestore
//           .collection('Challenges')
//           .doc(widget.initialPost.challenge_id)
//           .get();
//
//       if (challengeDoc.exists) {
//         if (mounted) {
//           setState(() {
//             _challenge = Challenge.fromJson(challengeDoc.data()!)
//               ..id = challengeDoc.id;
//           });
//         }
//       } else {
//         print('Challenge non trouvé: ${widget.initialPost.challenge_id}');
//         if (mounted) {
//           setState(() {
//             _challenge = null;
//           });
//         }
//       }
//     } catch (e) {
//       print('Erreur rechargement challenge: $e');
//       if (mounted) {
//         setState(() {
//           _challenge = null;
//         });
//       }
//       rethrow;
//     } finally {
//       if (mounted) {
//         setState(() {
//           _loadingChallenge = false;
//         });
//       }
//     }
//   }
//
//   Future<void> _voteForLook() async {
//     if (_hasVoted || _isVoting) return;
//
//     final user = _auth.currentUser;
//     if (user == null) {
//       _showError('CONNECTEZ-VOUS POUR POUVOIR VOTER\nVotre vote compte pour élire le gagnant !');
//       return;
//     }
//
//     setState(() {
//       _isVoting = true;
//     });
//
//     try {
//       // Si c'est un look challenge, recharger les données d'abord
//       if (_isLookChallenge && widget.initialPost.challenge_id != null) {
//         await _reloadChallengeData();
//
//         // Vérifier à nouveau après rechargement
//         if (_challenge == null) {
//           _showError('Impossible de charger les données du challenge. Veuillez réessayer.');
//           return;
//         }
//
//         final now = DateTime.now().microsecondsSinceEpoch;
//
//         // Vérifier si le challenge est terminé
//         if (_challenge!.isTermine || now > (_challenge!.finishedAt ?? 0)) {
//           _showError('CE CHALLENGE EST TERMINÉ\nMerci pour votre intérêt !');
//           return;
//         }
//
//         if (_challenge!.aVote(user.uid)) {
//           _showError('VOUS AVEZ DÉJÀ VOTÉ DANS CE CHALLENGE\nMerci pour votre participation !');
//           return;
//         }
//
//         if (!_challenge!.isEnCours) {
//           _showError('CE CHALLENGE N\'EST PLUS ACTIF\nLe vote n\'est pas possible actuellement.');
//           return;
//         }
//
//         // Vérifier le solde si vote payant
//         if (!_challenge!.voteGratuit!) {
//           final solde = await _getSoldeUtilisateur(user.uid);
//           if (solde < _challenge!.prixVote!) {
//             _showSoldeInsuffisant(_challenge!.prixVote! - solde.toInt());
//             return;
//           }
//         }
//
//         // Afficher la confirmation de vote
//         showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             backgroundColor: Colors.grey[900],
//             title: Text('Confirmer votre vote', style: TextStyle(color: Colors.white)),
//             content: Text(
//               !_challenge!.voteGratuit!
//                   ? 'Êtes-vous sûr de vouloir voter pour ce look ?\n\nCe vote vous coûtera ${_challenge!.prixVote} FCFA.'
//                   : 'Voulez-vous vraiment voter pour ce look ?\n\nVotre vote est gratuit et ne peut être changé.',
//               style: TextStyle(color: Colors.grey[300]),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   setState(() {
//                     _isVoting = false;
//                   });
//                 },
//                 child: Text('ANNULER', style: TextStyle(color: Colors.grey)),
//               ),
//               ElevatedButton(
//                 onPressed: () async {
//                   Navigator.pop(context);
//                   await _processVoteWithChallenge(user.uid);
//                 },
//                 style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                 child: Text('CONFIRMER MON VOTE', style: TextStyle(color: Colors.white)),
//               ),
//             ],
//           ),
//         );
//       } else {
//         // Vote normal (sans challenge)
//         // await _processVoteNormal(user.uid);
//       }
//     } catch (e) {
//       print("Erreur lors de la préparation du vote: $e");
//       _showError('Erreur lors de la préparation du vote: $e');
//     }
//   }
//
//   Future<void> _processVoteWithChallenge(String userId) async {
//     try {
//       // Recharger une dernière fois avant le vote pour être sûr
//       await _reloadChallengeData();
//
//       if (_challenge == null) {
//         throw Exception('Données du challenge non disponibles');
//       }
//
//       await _firestore.runTransaction((transaction) async {
//         // Vérifier à nouveau le challenge avec les données fraîches
//         final challengeRef = _firestore.collection('Challenges').doc(_challenge!.id!);
//         final challengeDoc = await transaction.get(challengeRef);
//
//         if (!challengeDoc.exists) throw Exception('Challenge non trouvé');
//
//         final currentChallenge = Challenge.fromJson(challengeDoc.data()!);
//
//         // Vérifications finales
//         if (!currentChallenge.isEnCours) {
//           throw Exception('Le challenge n\'est plus actif');
//         }
//
//         if (currentChallenge.aVote(userId)) {
//           throw Exception('Vous avez déjà voté dans ce challenge');
//         }
//
//         final postRef = _firestore.collection('Posts').doc(widget.initialPost.id);
//         final postDoc = await transaction.get(postRef);
//
//         if (!postDoc.exists) throw Exception('Post non trouvé');
//
//         // Débiter si vote payant
//         if (!_challenge!.voteGratuit!) {
//           await _debiterUtilisateur(userId, _challenge!.prixVote!,
//               'Vote pour le challenge ${_challenge!.titre}');
//         }
//
//         // Mettre à jour le post
//         transaction.update(postRef, {
//           'votes_challenge': FieldValue.increment(1),
//           'users_votes_ids': FieldValue.arrayUnion([userId]),
//           'popularity': FieldValue.increment(3),
//         });
//
//         // Mettre à jour le challenge
//         transaction.update(challengeRef, {
//           'users_votants_ids': FieldValue.arrayUnion([userId]),
//           'total_votes': FieldValue.increment(1),
//           'updated_at': DateTime.now().microsecondsSinceEpoch
//         });
//       });
//
//       // Mettre à jour l'état local
//       if (mounted) {
//         setState(() {
//           _hasVoted = true;
//           _votersList.add(userId);
//           widget.initialPost.votesChallenge = (widget.initialPost.votesChallenge ?? 0) + 1;
//         });
//       }
//
//       // Envoyer une notification
//       await authProvider.sendNotification(
//         userIds: [widget.initialPost.user!.oneIgnalUserid!],
//         smallImage: authProvider.loginUserData.imageUrl!,
//         send_user_id: authProvider.loginUserData.id!,
//         recever_user_id: widget.initialPost.user_id!,
//         message:
//         "🎉 @${authProvider.loginUserData.pseudo!} a voté pour votre look dans le challenge ${_challenge!.titre}!",
//         type_notif: NotificationType.POST.name,
//         post_id: widget.initialPost.id!,
//         post_type: PostDataType.VIDEO.name,
//         chat_id: '',
//       );
//
//       // Récompense pour le vote
//       await postProvider.interactWithPostAndIncrementSolde(widget.initialPost.id!,
//           authProvider.loginUserData.id!, "vote_look", widget.initialPost.user_id!);
//
//       _showSuccess('VOTE ENREGISTRÉ !\nMerci d\'avoir participé à l\'élection du gagnant.');
//       _envoyerNotificationVote(userVotant:  authProvider.loginUserData!, userVote:widget.initialPost!.user!);
//
//     } catch (e) {
//       print("Erreur lors du vote avec challenge: $e");
//       _showError('ERREUR LORS DU VOTE: ${e.toString()}\nVeuillez réessayer.');
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isVoting = false;
//         });
//       }
//     }
//   }
//
//   Future<void> _processVoteNormal(String userId) async {
//     try {
//       // Mettre à jour Firestore
//       await _firestore.collection('Posts').doc(widget.initialPost.id).update({
//         'votes_challenge': FieldValue.increment(1),
//         'users_votes_ids': FieldValue.arrayUnion([userId]),
//         'popularity': FieldValue.increment(3),
//       });
//
//       // Mettre à jour l'état local
//       if (mounted) {
//         setState(() {
//           _hasVoted = true;
//           _votersList.add(userId);
//           widget.initialPost.votesChallenge = (widget.initialPost.votesChallenge ?? 0) + 1;
//         });
//       }
//
//       // Envoyer une notification au propriétaire du look
//       await authProvider.sendNotification(
//         userIds: [widget.initialPost.user!.oneIgnalUserid!],
//         smallImage: authProvider.loginUserData.imageUrl!,
//         send_user_id: authProvider.loginUserData.id!,
//         recever_user_id: widget.initialPost.user_id!,
//         message: "🎉 @${authProvider.loginUserData.pseudo!} a voté pour votre look !",
//         type_notif: NotificationType.POST.name,
//         post_id: widget.initialPost.id!,
//         post_type: PostDataType.VIDEO.name,
//         chat_id: '',
//       );
//
//       // Récompense pour le vote
//       await postProvider.interactWithPostAndIncrementSolde(widget.initialPost.id!,
//           authProvider.loginUserData.id!, "vote_look", widget.initialPost.user_id!);
//
//       _showSuccess('🎉 Vote enregistré !');
//     } catch (e) {
//       print("Erreur lors du vote normal: $e");
//       _showError('Erreur lors du vote: ${e.toString()}');
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isVoting = false;
//         });
//       }
//     }
//   }
//
//   // Méthodes utilitaires pour le vote
//   Future<double> _getSoldeUtilisateur(String userId) async {
//     final doc = await _firestore.collection('Users').doc(userId).get();
//     return (doc.data()?['votre_solde_principal'] ?? 0).toDouble();
//   }
//
//   Future<void> _debiterUtilisateur(String userId, int montant, String raison) async {
//     await _firestore.collection('Users').doc(userId).update({
//       'votre_solde_principal': FieldValue.increment(-montant)
//     });
//     String appDataId = authProvider.appDefaultData.id!;
//
//     await _firestore.collection('AppData').doc(appDataId).set({
//       'solde_gain': FieldValue.increment(montant)
//     }, SetOptions(merge: true));
//     await _createTransaction(
//         TypeTransaction.DEPENSE.name, montant.toDouble(), raison, userId);
//   }
//
//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message, style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.red,
//         duration: Duration(seconds: 4),
//       ),
//     );
//   }
//
//   void _showSuccess(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message, style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.green,
//         duration: Duration(seconds: 4),
//       ),
//     );
//   }
//
//   void _showSoldeInsuffisant(int montantManquant) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         title: Text('SOLDE INSUFFISANT', style: TextStyle(color: Colors.yellow)),
//         content: Text(
//           'Il vous manque $montantManquant FCFA pour pouvoir voter.\n\n'
//               'Rechargez votre compte pour soutenir votre look préféré !',
//           style: TextStyle(color: Colors.grey[300]),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('PLUS TARD', style: TextStyle(color: Colors.grey)),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               Navigator.push(context,
//                   MaterialPageRoute(builder: (context) => DepositScreen()));
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//             child: Text('RECHARGER MAINTENANT', style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showVoteConfirmationDialog() {
//     final user = _auth.currentUser;
//
//     // Si c'est un look challenge avec vote payant
//     if (_isLookChallenge && _challenge != null && !_challenge!.voteGratuit!) {
//       showDialog(
//         context: context,
//         builder: (BuildContext context) {
//           return AlertDialog(
//             backgroundColor: _twitterCardBg,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20),
//               side: BorderSide(color: _twitterGreen, width: 2),
//             ),
//             title: Text(
//               '🎉 Voter pour ce Look',
//               style: TextStyle(
//                 color: _twitterGreen,
//                 fontWeight: FontWeight.bold,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             content: Text(
//               'Ce vote vous coûtera ${_challenge!.prixVote} FCFA.\n\n'
//                   'Voulez-vous continuer ?',
//               style: TextStyle(color: _twitterTextPrimary),
//               textAlign: TextAlign.center,
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text('Annuler', style: TextStyle(color: _twitterTextSecondary)),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   _voteForLook();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _twitterGreen,
//                 ),
//                 child: Text('Voter ${_challenge!.prixVote} FCFA',
//                     style: TextStyle(color: Colors.white)),
//               ),
//             ],
//           );
//         },
//       );
//     } else {
//       // Dialogue de confirmation normal
//       showDialog(
//         context: context,
//         builder: (BuildContext context) {
//           return AlertDialog(
//             backgroundColor: _twitterCardBg,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20),
//               side: BorderSide(color: _twitterGreen, width: 2),
//             ),
//             title: Text(
//               '🎉 Voter pour ce Look',
//               style: TextStyle(
//                 color: _twitterGreen,
//                 fontWeight: FontWeight.bold,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             content: Text(
//               'Vous allez voter pour ce look${_isLookChallenge ? ' challenge' : ''}. Cette action est irréversible${_isLookChallenge && _challenge != null ? ' et vous rapportera 3 points' : ''}!',
//               style: TextStyle(color: _twitterTextPrimary),
//               textAlign: TextAlign.center,
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text('Annuler', style: TextStyle(color: _twitterTextSecondary)),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   _voteForLook();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _twitterGreen,
//                 ),
//                 child: Text('Voter', style: TextStyle(color: Colors.white)),
//               ),
//             ],
//           );
//         },
//       );
//     }
//   }
//
//   // ==================== GESTION DES VIDÉOS ====================
//
//   Future<void> _loadInitialVideos() async {
//     try {
//       setState(() => _isLoading = true);
//
//       // Charger les données nécessaires
//       await Future.wait([
//         _getTotalVideoCount(),
//         _getAppData(),
//         _getUserData(),
//       ]);
//
//       // Commencer avec la vidéo initiale
//       _videoPosts = [widget.initialPost];
//
//       // Marquer la vidéo initiale comme vue
//       await _markPostAsSeen(widget.initialPost);
//
//       // Charger les vidéos suivantes avec priorité aux non vues
//       await _loadMoreVideos(isInitialLoad: true);
//
//       // Initialiser la première vidéo
//       if (_videoPosts.isNotEmpty) {
//         _initializeVideo(_videoPosts.first);
//       }
//     } catch (e) {
//       print('Erreur chargement initial: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   Future<void> _getTotalVideoCount() async {
//     try {
//       final query = _firestore.collection('Posts')
//           .where('postDataType', isEqualTo: PostDataType.VIDEO.name)
//           .where('status', isEqualTo: PostStatus.VALIDE.name);
//
//       final snapshot = await query.count().get();
//       _totalVideoCount = snapshot.count ?? 1000;
//       print('Nombre total de vidéos: $_totalVideoCount');
//     } catch (e) {
//       print('Erreur comptage vidéos: $e');
//       _totalVideoCount = 1000;
//     }
//   }
//
//   Future<void> _getAppData() async {
//     try {
//       final appDataRef = _firestore.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT');
//       final appDataSnapshot = await appDataRef.get();
//
//       if (appDataSnapshot.exists) {
//         final appData = AppDefaultData.fromJson(appDataSnapshot.data() ?? {});
//         _allVideoPostIds = appData.allPostIds?.where((id) => id.isNotEmpty).toList() ?? [];
//         print('IDs vidéo disponibles: ${_allVideoPostIds.length}');
//       }
//     } catch (e) {
//       print('Erreur récupération AppData: $e');
//       _allVideoPostIds = [];
//     }
//   }
//
//   Future<void> _getUserData() async {
//     try {
//       final currentUserId = authProvider.loginUserData.id;
//       if (currentUserId == null) return;
//
//       final userDoc = await _firestore.collection('Users').doc(currentUserId).get();
//       if (userDoc.exists) {
//         final userData = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
//         _viewedVideoPostIds = userData.viewedPostIds?.where((id) => id.isNotEmpty).toList() ?? [];
//         print('Vidéos déjà vues: ${_viewedVideoPostIds.length}');
//       }
//     } catch (e) {
//       print('Erreur récupération UserData: $e');
//       _viewedVideoPostIds = [];
//     }
//   }
//
//   Future<void> _loadMoreVideos({bool isInitialLoad = false}) async {
//     if (_isLoadingMore || !_hasMoreVideos) return;
//
//     try {
//       setState(() => _isLoadingMore = true);
//
//       final currentUserId = authProvider.loginUserData.id;
//
//       if (currentUserId != null && _allVideoPostIds.isNotEmpty) {
//         await _loadVideosWithPriority(currentUserId, isInitialLoad);
//       } else {
//         await _loadVideosChronologically();
//       }
//
//       _hasMoreVideos = _videoPosts.length < _totalVideoCount;
//
//     } catch (e) {
//       print('Erreur chargement supplémentaire: $e');
//     } finally {
//       setState(() => _isLoadingMore = false);
//     }
//   }
//
//   Future<void> _loadVideosWithPriority(String currentUserId, bool isInitialLoad) async {
//     final unseenVideoIds = _allVideoPostIds.where((postId) =>
//     !_viewedVideoPostIds.contains(postId) &&
//         !_videoPosts.any((post) => post.id == postId)
//     ).toList();
//
//     final seenVideoIds = _allVideoPostIds.where((postId) =>
//     _viewedVideoPostIds.contains(postId) &&
//         !_videoPosts.any((post) => post.id == postId)
//     ).toList();
//
//     print('📊 Vidéos non vues disponibles: ${unseenVideoIds.length}');
//     print('📊 Vidéos déjà vues disponibles: ${seenVideoIds.length}');
//
//     final limit = isInitialLoad ? _initialLimit - 1 : _loadMoreLimit;
//
//     final unseenVideos = await _loadVideosByIds(unseenVideoIds, limit: limit, isSeen: false);
//     print('✅ Vidéos non vues chargées: ${unseenVideos.length}');
//
//     if (unseenVideos.length < limit) {
//       final remainingLimit = limit - unseenVideos.length;
//       final seenVideos = await _loadVideosByIds(seenVideoIds, limit: remainingLimit, isSeen: true);
//       print('✅ Vidéos vues chargées: ${seenVideos.length}');
//
//       _videoPosts.addAll([...unseenVideos, ...seenVideos]);
//     } else {
//       _videoPosts.addAll(unseenVideos);
//     }
//
//     for (final post in _videoPosts) {
//       _subscribeToPostUpdates(post);
//     }
//   }
//
//   Future<List<Post>> _loadVideosByIds(List<String> videoIds, {required int limit, required bool isSeen}) async {
//     if (videoIds.isEmpty || limit <= 0) return [];
//
//     final idsToLoad = videoIds.take(limit).toList();
//     final videos = <Post>[];
//
//     print('🔹 Chargement de ${idsToLoad.length} vidéos par ID');
//
//     for (var i = 0; i < idsToLoad.length; i += 10) {
//       final batchIds = idsToLoad.skip(i).take(10).where((id) => id.isNotEmpty).toList();
//       if (batchIds.isEmpty) continue;
//
//       try {
//         final snapshot = await _firestore
//             .collection('Posts')
//             .where(FieldPath.documentId, whereIn: batchIds)
//             .where('postDataType', isEqualTo: PostDataType.VIDEO.name)
//             .get();
//
//         for (var doc in snapshot.docs) {
//           try {
//             final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//             post.hasBeenSeenByCurrentUser = isSeen;
//             videos.add(post);
//           } catch (e) {
//             print('⚠️ Erreur parsing vidéo ${doc.id}: $e');
//           }
//         }
//       } catch (e) {
//         print('❌ Erreur batch chargement vidéos: $e');
//         for (final id in batchIds) {
//           try {
//             final doc = await _firestore.collection('Posts').doc(id).get();
//             if (doc.exists) {
//               final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//               post.hasBeenSeenByCurrentUser = isSeen;
//               videos.add(post);
//             }
//           } catch (e) {
//             print('❌ Erreur chargement vidéo $id: $e');
//           }
//         }
//       }
//     }
//
//     return videos;
//   }
//
//   Future<void> _loadVideosChronologically() async {
//     try {
//       Query query = _firestore.collection('Posts')
//           .where('postDataType', isEqualTo: PostDataType.VIDEO.name)
//           .where('status', isEqualTo: PostStatus.VALIDE.name)
//           .orderBy('created_at', descending: true);
//
//       if (_lastDocument != null) {
//         query = query.startAfterDocument(_lastDocument!);
//       }
//
//       final snapshot = await query.limit(_loadMoreLimit).get();
//
//       if (snapshot.docs.isNotEmpty) {
//         _lastDocument = snapshot.docs.last;
//       }
//
//       final newVideos = snapshot.docs.map((doc) {
//         final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//         post.hasBeenSeenByCurrentUser = _viewedVideoPostIds.contains(post.id);
//         _subscribeToPostUpdates(post);
//         return post;
//       }).toList();
//
//       final existingIds = _videoPosts.map((v) => v.id).toSet();
//       final uniqueNewVideos = newVideos.where((video) =>
//       video.id != null && !existingIds.contains(video.id)).toList();
//
//       _videoPosts.addAll(uniqueNewVideos);
//
//     } catch (e) {
//       print('❌ Erreur chargement chronologique: $e');
//     }
//   }
//
//   void _subscribeToPostUpdates(Post post) {
//     if (post.id == null || _postSubscriptions.containsKey(post.id)) return;
//
//     final subscription = _firestore.collection('Posts').doc(post.id).snapshots().listen((snapshot) {
//       if (snapshot.exists && mounted) {
//         final updatedPost = Post.fromJson(snapshot.data() as Map<String, dynamic>);
//
//         setState(() {
//           final index = _videoPosts.indexWhere((p) => p.id == post.id);
//           if (index != -1) {
//             updatedPost.user = _videoPosts[index].user;
//             updatedPost.canal = _videoPosts[index].canal;
//             updatedPost.hasBeenSeenByCurrentUser = _videoPosts[index].hasBeenSeenByCurrentUser;
//             _videoPosts[index] = updatedPost;
//           }
//         });
//       }
//     });
//
//     _postSubscriptions[post.id!] = subscription;
//   }
//
//   Future<void> _initializeVideo(Post post) async {
//     _disposeCurrentVideo();
//
//     if (post.url_media == null || post.url_media!.isEmpty) {
//       print('⚠️ Aucune URL média pour la vidéo ${post.id}');
//       return;
//     }
//
//     try {
//       print('🎬 Initialisation vidéo: ${post.url_media}');
//
//       _currentVideoController = VideoPlayerController.network(post.url_media!);
//       await _currentVideoController!.initialize();
//
//       _chewieController = ChewieController(
//         videoPlayerController: _currentVideoController!,
//         autoPlay: true,
//         looping: true,
//         showControls: false,
//         allowFullScreen: false,
//         allowMuting: true,
//         materialProgressColors: ChewieProgressColors(
//           playedColor: _afroGreen,
//           handleColor: _afroGreen,
//           backgroundColor: _afroLightGrey.withOpacity(0.3),
//           bufferedColor: _afroLightGrey.withOpacity(0.1),
//         ),
//         placeholder: Container(
//           color: _afroBlack,
//           child: Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 CircularProgressIndicator(color: _afroGreen),
//                 SizedBox(height: 16),
//                 Text('Chargement...', style: TextStyle(color: Colors.white)),
//               ],
//             ),
//           ),
//         ),
//         autoInitialize: true,
//       );
//
//       setState(() => _isVideoInitialized = true);
//       await _recordPostView(post);
//
//     } catch (e) {
//       print('❌ Erreur initialisation vidéo: $e');
//       setState(() => _isVideoInitialized = false);
//     }
//   }
//
//   Future<void> _markPostAsSeen(Post post) async {
//     if (post.id == null) return;
//
//     final currentUserId = authProvider.loginUserData.id;
//     if (currentUserId == null) return;
//
//     try {
//       if (!_viewedVideoPostIds.contains(post.id)) {
//         _viewedVideoPostIds.add(post.id!);
//
//         await _firestore.collection('Users').doc(currentUserId).update({
//           'viewedPostIds': FieldValue.arrayUnion([post.id]),
//         });
//
//         post.hasBeenSeenByCurrentUser = true;
//       }
//     } catch (e) {
//       print('❌ Erreur marquage post comme vu: $e');
//     }
//   }
//
//   Future<void> _recordPostView(Post post) async {
//     if (post.id == null) return;
//
//     try {
//       await _markPostAsSeen(post);
//
//       if (!post.users_vue_id!.contains(authProvider.loginUserData.id)) {
//         await _firestore.collection('Posts').doc(post.id).update({
//           'vues': FieldValue.increment(1),
//           'users_vue_id': FieldValue.arrayUnion([authProvider.loginUserData.id!]),
//         });
//
//         post.vues = (post.vues ?? 0) + 1;
//         post.users_vue_id!.add(authProvider.loginUserData.id!);
//       }
//     } catch (e) {
//       print('❌ Erreur enregistrement vue: $e');
//     }
//   }
//
//   // ==================== WIDGETS ====================
//
//   Widget _buildVideoPlayer(Post post) {
//     if (!_isVideoInitialized) {
//       return _buildVideoPlaceholder(post);
//     }
//
//     return Stack(
//       children: [
//         Chewie(controller: _chewieController!),
//
//         // Positioned.fill(
//         //   child: GestureDetector(
//         //     onTap: () {
//         //       if (_chewieController?.isPlaying ?? false) {
//         //         _chewieController?.pause();
//         //       } else {
//         //         _chewieController?.play();
//         //       }
//         //     },
//         //     child: Container(
//         //       color: Colors.transparent,
//         //       child: Center(
//         //         child: AnimatedOpacity(
//         //           opacity: _chewieController?.isPlaying ?? false ? 0.0 : 1.0,
//         //           duration: Duration(milliseconds: 300),
//         //           child: Container(
//         //             padding: EdgeInsets.all(20),
//         //             decoration: BoxDecoration(
//         //               color: Colors.black.withOpacity(0.5),
//         //               shape: BoxShape.circle,
//         //             ),
//         //             child: Icon(
//         //               Icons.play_arrow,
//         //               color: Colors.white,
//         //               size: 60,
//         //             ),
//         //           ),
//         //         ),
//         //       ),
//         //     ),
//         //   ),
//         // ),
//       ],
//     );
//   }
//
//   Widget _buildVideoPlaceholder(Post post) {
//     return Container(
//       color: _afroBlack,
//       child: Stack(
//         children: [
//           if (post.images != null && post.images!.isNotEmpty)
//             CachedNetworkImage(
//               imageUrl: post.images!.first,
//               fit: BoxFit.cover,
//               width: double.infinity,
//               height: double.infinity,
//             )
//           else
//             Container(
//               color: _afroDarkGrey,
//               child: Center(
//                 child: Icon(Icons.videocam, color: _afroLightGrey, size: 80),
//               ),
//             ),
//
//           Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 CircularProgressIndicator(color: _afroGreen),
//                 SizedBox(height: 16),
//                 Text(
//                   'Chargement de la vidéo...',
//                   style: TextStyle(color: Colors.white),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLookChallengeSection(Post post) {
//     if (!_isLookChallenge) return SizedBox();
//
//     return Positioned(
//       top: 0,
//       left: 16,
//       right: 16,
//       child: Container(
//         padding: EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.black.withOpacity(0.7),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: _twitterGreen),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(Icons.emoji_events, color: _twitterGreen, size: 20),
//                 SizedBox(width: 8),
//                 Text(
//                   'LOOK CHALLENGE',
//                   style: TextStyle(
//                     color: _twitterGreen,
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 8),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 IconButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                   },
//                   icon: Icon(Icons.arrow_back, color: Colors.yellow),
//                 ),
//
//                 Text(
//                   '${post.votesChallenge ?? 0} votes',
//                   style: TextStyle(color: Colors.white, fontSize: 12),
//                 ),
//                 if (!_hasVoted && _challenge != null && _challenge!.isEnCours)
//                   ElevatedButton(
//                     onPressed: _isVoting ? null : _showVoteConfirmationDialog,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: _twitterGreen,
//                       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                     ),
//                     child: _isVoting
//                         ? SizedBox(
//                       width: 16,
//                       height: 10,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Colors.white,
//                       ),
//                     )
//                         : Text(
//                       'VOTER',
//                       style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.white
//                       ),
//                     ),
//                   )
//                 else if (_hasVoted)
//                   Container(
//                     padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                     decoration: BoxDecoration(
//                       color: _twitterGreen.withOpacity(0.2),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: _twitterGreen),
//                     ),
//                     child: Text(
//                       'DÉJÀ VOTÉ',
//                       style: TextStyle(
//                         color: _twitterGreen,
//                         fontSize: 10,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildUserInfo(Post post) {
//     final user = post.user;
//     final canal = post.canal;
//
//     return Positioned(
//       bottom: 120,
//       left: 16,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           if (canal != null) ...[
//             Text(
//               '#${canal.titre ?? ''}',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//             Text(
//               '${canal.usersSuiviId?.length ?? 0} abonnés',
//               style: TextStyle(color: Colors.white),
//             ),
//           ] else if (user != null) ...[
//             Text(
//               '@${user.pseudo ?? ''}',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//             Text(
//               '${user.userAbonnesIds?.length ?? 0} abonnés',
//               style: TextStyle(color: Colors.white),
//             ),
//           ],
//           SizedBox(height: 8),
//           if (post.description != null)
//             Container(
//               constraints: BoxConstraints(maxWidth: 250),
//               child: Text(
//                 post.description!,
//                 style: TextStyle(color: Colors.white),
//                 maxLines: 3,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildActionButtons(Post post) {
//     final isLiked = post.users_love_id!.contains(authProvider.loginUserData.id);
//
//     return Positioned(
//       right: 16,
//       bottom: 120,
//       child: Column(
//         children: [
//           // Avatar utilisateur
//           post.type == PostType.CHALLENGE.name?SizedBox.shrink():  GestureDetector(
//             onTap: () {
//               // Navigation vers le profil
//             },
//             child: Container(
//               decoration: BoxDecoration(
//                 border: Border.all(color: _afroGreen, width: 2),
//                 shape: BoxShape.circle,
//               ),
//               child: CircleAvatar(
//                 radius: 25,
//                 backgroundImage: NetworkImage(
//                   post.user?.imageUrl ?? post.canal?.urlImage ?? '',
//                 ),
//               ),
//             ),
//           ),
//           post.type == PostType.CHALLENGE.name?SizedBox.shrink(): SizedBox(height: 20),
//
//           // Like
//           Column(
//     spacing: 5,
//             children: [
//               if (_isLookChallenge)
//                 Column(
//                   children: [
//                     IconButton(
//                       icon: Icon(
//                         _hasVoted ? Icons.how_to_vote : Icons.how_to_vote_outlined,
//                         color: _hasVoted ? _twitterGreen : Colors.white,
//                         size: 35,
//                       ),
//                       onPressed: _voteForLook,
//                     ),
//                     Text(
//                       _formatCount(post.votesChallenge ?? 0),
//                       style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                     ),
//                   ],
//                 ),
//               IconButton(
//                 icon: Icon(
//                   isLiked ? Icons.favorite : Icons.favorite_border,
//                   color: isLiked ? _afroRed : Colors.white,
//                   size: 35,
//                 ),
//                 onPressed: () => _handleLike(post),
//               ),
//               Text(
//                 _formatCount(post.loves ?? 0),
//                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//
//           // Vote (uniquement pour les challenges)
//
//           // if (_isLookChallenge) SizedBox(height: 10),
//
//           // Commentaires
//           Column(
//             children: [
//               IconButton(
//                 icon: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 35),
//                 onPressed: () => _showCommentsModal(post),
//               ),
//               Text(
//                 _formatCount(post.comments ?? 0),
//                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//
//           // Cadeaux
//           Column(
//             children: [
//               IconButton(
//                 icon: Icon(Icons.card_giftcard, color: _afroYellow, size: 35),
//                 onPressed: () => _showGiftDialog(post),
//               ),
//               Text(
//                 _formatCount(post.users_cadeau_id?.length ?? 0),
//                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//
//           // Vue
//           Column(
//             children: [
//               IconButton(
//                 icon: Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 35),
//                 onPressed: () {},
//               ),
//               Text(
//                 _formatCount(post.vues ?? 0),
//                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//
//           // Partager
//           IconButton(
//             icon: Icon(Icons.share, color: Colors.white, size: 35),
//             onPressed: () => _sharePost(post),
//           ),
//
//           // Menu
//           IconButton(
//             icon: Icon(Icons.more_vert, color: Colors.white, size: 35),
//             onPressed: () => _showPostMenu(post),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ==================== MÉTHODES D'INTERACTION ====================
//
//   Future<void> _handleLike(Post post) async {
//     try {
//       if (!post.users_love_id!.contains(authProvider.loginUserData.id)) {
//         await _firestore.collection('Posts').doc(post.id).update({
//           'loves': FieldValue.increment(1),
//           'users_love_id': FieldValue.arrayUnion([authProvider.loginUserData.id!]),
//         });
//
//         await postProvider.interactWithPostAndIncrementSolde(
//             post.id!,
//             authProvider.loginUserData.id!,
//             "like",
//             post.user_id!
//         );
//       }
//     } catch (e) {
//       print('Erreur like: $e');
//     }
//   }
//
//   void _showCommentsModal(Post post) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => Container(
//         height: MediaQuery.of(context).size.height * 0.85,
//         decoration: BoxDecoration(
//           color: _afroBlack,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         child: Column(
//           children: [
//             Container(
//               padding: EdgeInsets.all(16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'Commentaires',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   IconButton(
//                     icon: Icon(Icons.close, color: Colors.white),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: PostComments(post: post),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _showInsufficientBalanceDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           backgroundColor: Colors.black,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//             side: BorderSide(color: Colors.yellow, width: 2),
//           ),
//           title: Text(
//             'Solde Insuffisant',
//             style: TextStyle(
//               color: Colors.yellow,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           content: Text(
//             'Votre solde est insuffisant pour effectuer cette action. Veuillez recharger votre compte.',
//             style: TextStyle(color: Colors.white),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text('Annuler', style: TextStyle(color: Colors.white)),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen()));
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green,
//               ),
//               child: Text('Recharger', style: TextStyle(color: Colors.black)),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   void _showGiftDialog(Post post) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         final height = MediaQuery.of(context).size.height * 0.6;
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return Dialog(
//               backgroundColor: Colors.black,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20),
//                 side: BorderSide(color: Colors.yellow, width: 2),
//               ),
//               child: Container(
//                 height: height,
//                 padding: EdgeInsets.all(16),
//                 child: Column(
//                   children: [
//                     Text(
//                       'Envoyer un Cadeau',
//                       style: TextStyle(
//                         color: Colors.yellow,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 20,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     SizedBox(height: 12),
//                     Text(
//                       'Choisissez le montant en FCFA',
//                       style: TextStyle(color: Colors.white),
//                     ),
//                     SizedBox(height: 12),
//                     Expanded(
//                       child: GridView.builder(
//                         physics: BouncingScrollPhysics(),
//                         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: 3,
//                           crossAxisSpacing: 10,
//                           mainAxisSpacing: 10,
//                           childAspectRatio: 0.8,
//                         ),
//                         itemCount: giftPrices.length,
//                         itemBuilder: (context, index) {
//                           return GestureDetector(
//                             onTap: () => setState(() => _selectedGiftIndex = index),
//                             child: Container(
//                               padding: EdgeInsets.all(10),
//                               decoration: BoxDecoration(
//                                 color: _selectedGiftIndex == index
//                                     ? Colors.green
//                                     : Colors.grey[800],
//                                 borderRadius: BorderRadius.circular(10),
//                                 border: Border.all(
//                                   color: _selectedGiftIndex == index
//                                       ? Colors.yellow
//                                       : Colors.transparent,
//                                   width: 1,
//                                 ),
//                               ),
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Text(
//                                     giftIcons[index],
//                                     style: TextStyle(fontSize: 24),
//                                   ),
//                                   SizedBox(height: 5),
//                                   Text(
//                                     '${giftPrices[index].toInt()} FCFA',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                     textAlign: TextAlign.center,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                     SizedBox(height: 12),
//                     Text(
//                       'Votre solde: ${authProvider.loginUserData.votre_solde_principal?.toInt() ?? 0} FCFA',
//                       style: TextStyle(
//                         color: Colors.yellow,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     SizedBox(height: 12),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         TextButton(
//                           onPressed: () => Navigator.pop(context),
//                           child: Text('Annuler', style: TextStyle(color: Colors.white)),
//                         ),
//                         ElevatedButton(
//                           onPressed: () {
//                             Navigator.pop(context);
//                             _sendGift(giftPrices[_selectedGiftIndex], post);
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                           ),
//                           child: Text(
//                             'Envoyer',
//                             style: TextStyle(color: Colors.black),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   Future<void> _sendGift(double amount, Post post) async {
//     try {
//       setState(() => _isLoading = true);
//
//       final firestore = FirebaseFirestore.instance;
//       await authProvider.getAppData();
//
//       final senderSnap = await firestore.collection('Users').doc(authProvider.loginUserData.id).get();
//       if (!senderSnap.exists) {
//         throw Exception("Utilisateur expéditeur introuvable");
//       }
//
//       final senderData = senderSnap.data() as Map<String, dynamic>;
//       final double senderBalance = (senderData['votre_solde_principal'] ?? 0.0).toDouble();
//
//       if (senderBalance >= amount) {
//         final double gainDestinataire = amount * 0.5;
//         final double gainApplication = amount * 0.5;
//
//         await firestore.collection('Users').doc(authProvider.loginUserData.id).update({
//           'votre_solde_principal': FieldValue.increment(-amount),
//         });
//
//         await firestore.collection('Users').doc(post.user!.id).update({
//           'votre_solde_principal': FieldValue.increment(gainDestinataire),
//         });
//
//         String appDataId = authProvider.appDefaultData.id!;
//         await firestore.collection('AppData').doc(appDataId).update({
//           'solde_gain': FieldValue.increment(gainApplication),
//         });
//
//         await firestore.collection('Posts').doc(post.id).update({
//           'users_cadeau_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
//           'popularity': FieldValue.increment(5),
//         });
//
//         await _createTransaction(TypeTransaction.DEPENSE.name, amount, "Cadeau envoyé à @${post.user!.pseudo}", authProvider.loginUserData.id!);
//         await _createTransaction(TypeTransaction.GAIN.name, gainDestinataire, "Cadeau reçu de @${authProvider.loginUserData.pseudo}", post.user_id!);
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             backgroundColor: Colors.green,
//             content: Text(
//               '🎁 Cadeau de ${amount.toInt()} FCFA envoyé avec succès!',
//               style: TextStyle(color: Colors.white),
//             ),
//           ),
//         );
//
//         await authProvider.sendNotification(
//           userIds: [post.user!.oneIgnalUserid!],
//           smallImage: "",
//           send_user_id: "",
//           recever_user_id: "${post.user_id!}",
//           message: "🎁 Vous avez reçu un cadeau de ${amount.toInt()} FCFA !",
//           type_notif: NotificationType.POST.name,
//           post_id: "${post.id!}",
//           post_type: PostDataType.VIDEO.name,
//           chat_id: '',
//         );
//       } else {
//         _showInsufficientBalanceDialog();
//       }
//     } catch (e) {
//       print("Erreur envoi cadeau: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.red,
//           content: Text(
//             'Erreur lors de l\'envoi du cadeau',
//             style: TextStyle(color: Colors.white),
//           ),
//         ),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   Future<void> _createTransaction(String type, double montant, String description, String userid) async {
//     try {
//       final transaction = TransactionSolde()
//         ..id = _firestore.collection('TransactionSoldes').doc().id
//         ..user_id = userid
//         ..type = type
//         ..statut = StatutTransaction.VALIDER.name
//         ..description = description
//         ..montant = montant
//         ..methode_paiement = "cadeau"
//         ..createdAt = DateTime.now().millisecondsSinceEpoch
//         ..updatedAt = DateTime.now().millisecondsSinceEpoch;
//
//       await _firestore.collection('TransactionSoldes').doc(transaction.id).set(transaction.toJson());
//     } catch (e) {
//       print("Erreur création transaction: $e");
//     }
//   }
//
//   Future<void> _sharePost(Post post) async {
//     final AppLinkService _appLinkService = AppLinkService();
//     _appLinkService.shareContent(
//       type: AppLinkType.post,
//       id: post.id!,
//       message: post.description ?? "",
//       mediaUrl: post.url_media ?? "",
//     );
//   }
//
//   void _showPostMenu(Post post) {
//     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final postProvider = Provider.of<PostProvider>(context, listen: false);
//
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: _twitterCardBg,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (context) => Container(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             if (post.user_id != authProvider.loginUserData.id)
//               _buildMenuOption(
//                 Icons.flag,
//                 "Signaler",
//                 _twitterTextPrimary,
//                     () async {
//                   post.status = PostStatus.SIGNALER.name;
//                   final value = await postProvider.updateVuePost(post, context);
//                   Navigator.pop(context);
//
//                   final snackBar = SnackBar(
//                     content: Text(
//                       value ? 'Post signalé !' : 'Échec du signalement !',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: value ? Colors.green : Colors.red),
//                     ),
//                   );
//                   ScaffoldMessenger.of(context).showSnackBar(snackBar);
//                 },
//               ),
//
//             if (post.user!.id == authProvider.loginUserData.id ||
//                 authProvider.loginUserData.role == UserRole.ADM.name)
//               _buildMenuOption(
//                 Icons.delete,
//                 "Supprimer",
//                 Colors.red,
//                     () async {
//                   if (authProvider.loginUserData.role == UserRole.ADM.name) {
//                     await _deletePost(post, context);
//                   } else {
//                     post.status = PostStatus.SUPPRIMER.name;
//                     await _deletePost(post, context);
//                   }
//                   Navigator.pop(context);
//
//                   final snackBar = SnackBar(
//                     content: Text(
//                       'Post supprimé !',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: Colors.green),
//                     ),
//                   );
//                   ScaffoldMessenger.of(context).showSnackBar(snackBar);
//                 },
//               ),
//
//             SizedBox(height: 8),
//             Container(height: 0.5, color: _twitterTextSecondary.withOpacity(0.3)),
//             SizedBox(height: 8),
//
//             _buildMenuOption(Icons.cancel, "Annuler", _twitterTextSecondary, () {
//               Navigator.pop(context);
//             }),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildMenuOption(IconData icon, String text, Color color, VoidCallback onTap) {
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: onTap,
//         child: Container(
//           padding: EdgeInsets.symmetric(vertical: 16),
//           child: Row(
//             children: [
//               Icon(icon, color: color, size: 20),
//               SizedBox(width: 12),
//               Text(text, style: TextStyle(color: color, fontSize: 16)),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Future<void> _deletePost(Post post, BuildContext context) async {
//     try {
//       final canDelete = authProvider.loginUserData.role == UserRole.ADM.name ||
//           (post.type == PostType.POST.name &&
//               post.user?.id == authProvider.loginUserData.id);
//
//       if (!canDelete) return;
//
//       await _firestore.collection('Posts').doc(post.id).delete();
//       // 🔹 Retirer l'ID de allPostIds
//       final appDefaultRef = _firestore.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT'); // Remplace par ton docId réel
//
//       await appDefaultRef.update({
//         'allPostIds': FieldValue.arrayRemove([post.id]),
//       });
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Post supprimé !',
//             textAlign: TextAlign.center,
//             style: TextStyle(color: Colors.green),
//           ),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Échec de la suppression !',
//             textAlign: TextAlign.center,
//             style: TextStyle(color: Colors.red),
//           ),
//         ),
//       );
//       print('Erreur suppression post: $e');
//     }
//   }
//
//   String _formatCount(int count) {
//     if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
//     if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
//     return count.toString();
//   }
//
//   // ==================== BUILD PRINCIPAL ====================
//
//   Widget _buildVideoPage(Post post) {
//     return Stack(
//       children: [
//         // Lecteur vidéo
//         _buildVideoPlayer(post),
//
//
//
//         // Informations utilisateur
//         _buildUserInfo(post),
//
//         // Section Look Challenge
//         _buildLookChallengeSection(post),
//
//         // Boutons d'action
//         _buildActionButtons(post),
//         if (widget.isIn)
//         Positioned(
//           top: MediaQuery.of(context).padding.top + 16,
//           left: 16,
//           child: Row(
//             children: [
//               IconButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                 },
//                 icon: Icon(Icons.arrow_back, color: Colors.yellow),
//               ),
//               Text(
//                 'Afrolook',
//                 style: TextStyle(
//                   color: _afroGreen,
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//         ),
//
//         // Indicateur de son
//         // if (!_isLookChallenge)
//         //
//         //   Positioned(
//         //   top: MediaQuery.of(context).padding.top + 16,
//         //   right: 16,
//         //   child: IconButton(
//         //     icon: Icon(
//         //       _chewieController?.videoPlayerController?.value?.volume == 0
//         //           ? Icons.volume_off
//         //           : Icons.volume_up,
//         //       color: Colors.white,
//         //       size: 30,
//         //     ),
//         //     onPressed: () {
//         //       final currentVolume = _chewieController?.videoPlayerController?.value?.volume ?? 1.0;
//         //       final newVolume = currentVolume == 0.0 ? 1.0 : 0.0;
//         //       _chewieController?.setVolume(newVolume);
//         //     },
//         //   ),
//         // ),      // En-tête avec logo Afrolook
//
//
//         // Indicateur de chargement suivant
//         if (_isLoadingMore)
//           Positioned(
//             bottom: 100,
//             left: 0,
//             right: 0,
//             child: Center(
//               child: CircularProgressIndicator(color: _afroGreen),
//             ),
//           ),
//       ],
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _afroBlack,
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator(color: _afroGreen))
//           : PageView.builder(
//         controller: _pageController,
//         scrollDirection: Axis.vertical,
//         itemCount: _videoPosts.length + (_hasMoreVideos ? 1 : 0),
//         onPageChanged: (index) async {
//           if (index >= _videoPosts.length - 2 && _hasMoreVideos && !_isLoadingMore) {
//             await _loadMoreVideos();
//           }
//
//           if (index < _videoPosts.length) {
//             setState(() => _currentPage = index);
//             _initializeVideo(_videoPosts[index]);
//           }
//         },
//         itemBuilder: (context, index) {
//           if (index >= _videoPosts.length) {
//             return Center(
//               child: CircularProgressIndicator(color: _afroGreen),
//             );
//           }
//
//           final post = _videoPosts[index];
//           return _buildVideoPage(post);
//         },
//       ),
//     );
//   }
// }