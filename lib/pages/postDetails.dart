import 'dart:async';
import 'dart:math';

import 'package:afrotok/pages/challenge/challengeDetails.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/home/homeWidget.dart';
import 'package:afrotok/pages/paiement/depotPaiment.dart';
import 'package:afrotok/pages/paiement/newDepot.dart';

import 'package:afrotok/pages/userPosts/postWidgets/postMenu.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postUserWidget.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postWidgetPage.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afrotok/constant/constColors.dart';
import 'package:afrotok/constant/iconGradient.dart';
import 'package:afrotok/constant/logo.dart';
import 'package:afrotok/constant/sizeText.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:afrotok/services/api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';

import 'package:intl/intl.dart';

import 'package:provider/provider.dart';

import 'package:skeletonizer/skeletonizer.dart';

import '../../providers/authProvider.dart';
import '../services/linkService.dart';
import 'canaux/detailsCanal.dart';

import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;

const _twitterDarkBg = Color(0xFF000000);
const _twitterCardBg = Color(0xFF16181C);
const _twitterTextPrimary = Color(0xFFFFFFFF);
const _twitterTextSecondary = Color(0xFF71767B);
const _twitterBlue = Color(0xFF1D9BF0);
const _twitterRed = Color(0xFFF91880);
const _twitterGreen = Color(0xFF00BA7C);
const _twitterYellow = Color(0xFFFFD400);
const _afroBlack = Color(0xFF000000);

class DetailsPost extends StatefulWidget {
  final Post post;

  DetailsPost({Key? key, required this.post}) : super(key: key);

  @override
  _DetailsPostState createState() => _DetailsPostState();
}

class _DetailsPostState extends State<DetailsPost>
    with SingleTickerProviderStateMixin {
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  int _selectedGiftIndex = 0;
  int _selectedRepostPrice = 25;

  // Variables pour le vote
  bool _hasVoted = false;
  bool _isVoting = false;
  List<String> _votersList = [];

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Stream pour les mises à jour en temps réel
  late Stream<DocumentSnapshot> _postStream;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Challenge? _challenge;
  bool _loadingChallenge = false;

  Future<void> _loadPostRelations() async {
    try {
      // Vérifier qu'on a des IDs
      final post = widget.post;
      if (post.user_id == null || post.canal_id == null) return;

      // Récupérer l'utilisateur
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(post.user_id)
          .get();

      if (userDoc.exists) {
        post.user = UserData.fromJson(userDoc.data()!); // Assurez-vous que User.fromJson existe
      }

      // Récupérer le canal
      final canalDoc = await FirebaseFirestore.instance
          .collection('Canaux')
          .doc(post.canal_id)
          .get();

      if (canalDoc.exists) {
        post.canal = Canal.fromJson(canalDoc.data()!); // Assurez-vous que Canal.fromJson existe
      }

      // Rebuild UI avec les données chargées
      if (mounted) setState(() {});
    } catch (e, stack) {
      debugPrint('❌ Erreur récupération user/canal: $e\n$stack');
    }
  }
  @override
  void initState() {
    super.initState();

    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadPostRelations();

    // Initialiser le stream pour les mises à jour en temps réel
    _postStream = firestore.collection('Posts').doc(widget.post.id).snapshots();


    // Charger le challenge si c'est un look challenge
    if (_isLookChallenge && widget.post.challenge_id != null) {
      _loadChallengeData();
    }
    // Vérifier si l'utilisateur a déjà voté
    _checkIfUserHasVoted();

    // Incrémenter les vues
    _incrementViews();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Vérifier si c'est un Look Challenge
  bool get _isLookChallenge {
    return widget.post.type == 'CHALLENGEPARTICIPATION';
  }

  Future<void> _checkIfUserHasVoted() async {
    try {
      final postDoc =
          await firestore.collection('Posts').doc(widget.post.id).get();
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

  Future<void> _incrementViews() async {
    try {
      if (!widget.post.users_vue_id!.contains(authProvider.loginUserData.id)) {
        // Mettre à jour localement
        setState(() {
          widget.post.vues = (widget.post.vues ?? 0) + 1;
          widget.post.users_vue_id!.add(authProvider.loginUserData.id!);
        });

        // Mettre à jour dans Firestore
        await firestore.collection('Posts').doc(widget.post.id).update({
          'vues': FieldValue.increment(1),
          'users_vue_id':
              FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(2),
        });
      }
    } catch (e) {
      print("Erreur incrémentation vues: $e");
    }
  }

  // FONCTIONNALITÉ DE VOTE
// Ajoutez ces variables au début de votre classe _DetailsPostState

// Méthode pour charger les données du challenge
  Future<void> _loadChallengeData() async {
    if (widget.post.challenge_id == null) return;

    setState(() {
      _loadingChallenge = true;
    });

    try {
      final challengeDoc = await firestore
          .collection('Challenges')
          .doc(widget.post.challenge_id)
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

  Future<void> _voteForLook() async {
    if (_hasVoted || _isVoting) return;

    final user = _auth.currentUser;
    if (user == null) {
      _showError(
          'CONNECTEZ-VOUS POUR POUVOIR VOTER\nVotre vote compte pour élire le gagnant !');
      return;
    }

    setState(() {
      _isVoting = true;
    });

    try {
      // Si c'est un look challenge, recharger les données d'abord
      if (_isLookChallenge && widget.post.challenge_id != null) {
        await _reloadChallengeData();

        // Vérifier à nouveau après rechargement
        if (_challenge == null) {
          _showError(
              'Impossible de charger les données du challenge. Veuillez réessayer.');
          return;
        }

        final now = DateTime.now().microsecondsSinceEpoch;

        // Vérifier si le challenge est terminé
        if (_challenge!.isTermine || now > (_challenge!.finishedAt ?? 0)) {
          _showError('CE CHALLENGE EST TERMINÉ\nMerci pour votre intérêt !');
          return;
        }

        if (_challenge!.aVote(user.uid)) {
          _showError(
              'VOUS AVEZ DÉJÀ VOTÉ DANS CE CHALLENGE\nMerci pour votre participation !');
          return;
        }

        if (!_challenge!.isEnCours) {
          _showError(
              'CE CHALLENGE N\'EST PLUS ACTIF\nLe vote n\'est pas possible actuellement.');
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
            title: Text('Confirmer votre vote',
                style: TextStyle(color: Colors.white)),
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
                child: Text('CONFIRMER MON VOTE',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        // Vote normal (sans challenge)
        await _processVoteNormal(user.uid);
      }
    } catch (e) {
      print("Erreur lors de la préparation du vote: $e");
      _showError('Erreur lors de la préparation du vote: $e');
    } finally {
      // Ne pas reset _isVoting ici car on veut le garder pendant le processus de vote
      // Il sera reset dans _processVoteWithChallenge ou _processVoteNormal
    }
  }

// Nouvelle méthode pour recharger les données du challenge
  Future<void> _reloadChallengeData() async {
    try {
      if (widget.post.challenge_id == null) return;

      // Afficher un indicateur de chargement si nécessaire
      if (mounted) {
        setState(() {
          _loadingChallenge = true;
        });
      }

      final challengeDoc = await firestore
          .collection('Challenges')
          .doc(widget.post.challenge_id)
          .get();

      if (challengeDoc.exists) {
        if (mounted) {
          setState(() {
            _challenge = Challenge.fromJson(challengeDoc.data()!)
              ..id = challengeDoc.id;
          });
        }
      } else {
        print('Challenge non trouvé: ${widget.post.challenge_id}');
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

// Mettre à jour _processVoteWithChallenge pour gérer les erreurs de rechargement
  Future<void> _processVoteWithChallenge(String userId) async {
    try {
      // Recharger une dernière fois avant le vote pour être sûr
      await _reloadChallengeData();

      if (_challenge == null) {
        throw Exception('Données du challenge non disponibles');
      }

      await firestore.runTransaction((transaction) async {
        // Vérifier à nouveau le challenge avec les données fraîches
        final challengeRef =
            firestore.collection('Challenges').doc(_challenge!.id!);
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

        final postRef = firestore.collection('Posts').doc(widget.post.id);
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
          widget.post.votesChallenge = (widget.post.votesChallenge ?? 0) + 1;
        });
      }

      // Envoyer une notification
      await authProvider.sendNotification(
        userIds: [widget.post.user!.oneIgnalUserid!],
        smallImage: authProvider.loginUserData.imageUrl!,
        send_user_id: authProvider.loginUserData.id!,
        recever_user_id: widget.post.user_id!,
        message:
            "🎉 @${authProvider.loginUserData.pseudo!} a voté pour votre look dans le challenge ${_challenge!.titre}!",
        type_notif: NotificationType.POST.name,
        post_id: widget.post.id!,
        post_type: PostDataType.IMAGE.name,
        chat_id: '',
      );

      // Récompense pour le vote
       postProvider.interactWithPostAndIncrementSolde(widget.post.id!,
          authProvider.loginUserData.id!, "vote_look", widget.post.user_id!);

      _showSuccess(
          'VOTE ENREGISTRÉ !\nMerci d\'avoir participé à l\'élection du gagnant.');
      _envoyerNotificationVote(userVotant:  authProvider.loginUserData!, userVote:widget.post!.user!);
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
        post_id: '',      // optionnel si tu n’as pas de post associé
        post_type: '',    // optionnel
        chat_id: '',      // optionnel
      );

      debugPrint("✅ Notification envoyée: $message");
    } catch (e, stack) {
      debugPrint("❌ Erreur envoi notification vote: $e\n$stack");
    }
  }

// Mettre à jour _processVoteNormal également
  Future<void> _processVoteNormal(String userId) async {
    try {
      // Mettre à jour Firestore
      await firestore.collection('Posts').doc(widget.post.id).update({
        'votes_challenge': FieldValue.increment(1),
        'users_votes_ids': FieldValue.arrayUnion([userId]),
        'popularity': FieldValue.increment(3),
      });

      // Mettre à jour l'état local
      if (mounted) {
        setState(() {
          _hasVoted = true;
          _votersList.add(userId);
          widget.post.votesChallenge = (widget.post.votesChallenge ?? 0) + 1;
        });
      }

      // Envoyer une notification au propriétaire du look
      await authProvider.sendNotification(
        userIds: [widget.post.user!.oneIgnalUserid!],
        smallImage: authProvider.loginUserData.imageUrl!,
        send_user_id: authProvider.loginUserData.id!,
        recever_user_id: widget.post.user_id!,
        message:
            "🎉 @${authProvider.loginUserData.pseudo!} a voté pour votre look !",
        type_notif: NotificationType.POST.name,
        post_id: widget.post.id!,
        post_type: PostDataType.IMAGE.name,
        chat_id: '',
      );

      // Récompense pour le vote
      await postProvider.interactWithPostAndIncrementSolde(widget.post.id!,
          authProvider.loginUserData.id!, "vote_look", widget.post.user_id!);

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

// Méthodes utilitaires nécessaires
  Future<double> _getSoldeUtilisateur(String userId) async {
    final doc = await firestore.collection('Users').doc(userId).get();
    return (doc.data()?['votre_solde_principal'] ?? 0).toDouble();
  }

  Future<void> _debiterUtilisateur(
      String userId, int montant, String raison) async {
    await firestore
        .collection('Users')
        .doc(userId)
        .update({'votre_solde_principal': FieldValue.increment(-montant)});
    String appDataId = authProvider.appDefaultData.id!;

    await firestore.collection('AppData').doc(appDataId).set({
      'solde_gain': FieldValue.increment(montant)
    }, SetOptions(merge: true));
    // Créer une transaction
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
        title:
            Text('SOLDE INSUFFISANT', style: TextStyle(color: Colors.yellow)),
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
              // Naviguer vers la page de recharge
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => DepositScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('RECHARGER MAINTENANT',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

// Mettre à jour la méthode _showVoteConfirmationDialog
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
                child: Text('Annuler',
                    style: TextStyle(color: _twitterTextSecondary)),
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
                child: Text('Annuler',
                    style: TextStyle(color: _twitterTextSecondary)),
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

  void _showVoteConfirmationDialog2() {
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
            'Vous allez voter pour ce look challenge. Cette action est irréversible',
            style: TextStyle(color: _twitterTextPrimary),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler',
                  style: TextStyle(color: _twitterTextSecondary)),
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

  String formatNumber(int number) {
    if (number >= 1000) {
      double nombre = number / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return number.toString();
    }
  }

  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) {
          return "il y a quelques secondes";
        } else {
          return "il y a ${difference.inMinutes} min";
        }
      } else {
        return "il y a ${difference.inHours} h";
      }
    } else if (difference.inDays < 7) {
      return "il y a ${difference.inDays} j";
    } else {
      return DateFormat('dd/MM/yy').format(dateTime);
    }
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  Future<void> _handleLike() async {
    try {
      if (!isIn(widget.post.users_love_id!, authProvider.loginUserData.id!)) {
        // Mettre à jour localement
        setState(() {
          widget.post.loves = widget.post.loves! + 1;
          widget.post.users_love_id!.add(authProvider.loginUserData.id!);
        });

        // Mettre à jour dans Firestore
        await firestore.collection('Posts').doc(widget.post.id).update({
          'loves': FieldValue.increment(1),
          'users_love_id':
              FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(3),
        });
        await authProvider.sendNotification(
            userIds: [widget.post.user!.oneIgnalUserid!],
            smallImage: "${authProvider.loginUserData.imageUrl!}",
            send_user_id: "${authProvider.loginUserData.id!}",
            recever_user_id: "${widget.post.user_id!}",
            message:
                "📢 @${authProvider.loginUserData.pseudo!} a aimé votre ${_isLookChallenge ? 'look' : 'post'}",
            type_notif: NotificationType.POST.name,
            post_id: "${widget.post!.id!}",
            post_type: PostDataType.IMAGE.name,
            chat_id: '');
        // Incrémenter le solde de l'utilisateur qui aime
        await postProvider.interactWithPostAndIncrementSolde(widget.post.id!,
            authProvider.loginUserData.id!, "like", widget.post.user_id!);

        // Animation
        _animationController.forward().then((_) {
          _animationController.reverse();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+2 points ajoutés à votre compte',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.green),
            ),
          ),
        );
      }
    } catch (e) {
      print("Erreur like: $e");
    }
  }

  Future<void> _createTransaction(
      String type, double montant, String description, String userid) async {
    try {
      final transaction = TransactionSolde()
        ..id = firestore.collection('TransactionSoldes').doc().id
        ..user_id = userid
        ..type = type
        ..statut = StatutTransaction.VALIDER.name
        ..description = description
        ..montant = montant
        ..methode_paiement = "cadeau"
        ..createdAt = DateTime.now().millisecondsSinceEpoch
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;

      await firestore
          .collection('TransactionSoldes')
          .doc(transaction.id)
          .set(transaction.toJson());
    } catch (e) {
      print("Erreur création transaction: $e");
    }
  }

  Future<void> _sendGift(double amount) async {
    try {
      setState(() => _isLoading = true);

      final firestore = FirebaseFirestore.instance;
      await authProvider.getAppData();
      // Récupérer l'utilisateur expéditeur à jour
      final senderSnap = await firestore
          .collection('Users')
          .doc(authProvider.loginUserData.id)
          .get();
      if (!senderSnap.exists) {
        throw Exception("Utilisateur expéditeur introuvable");
      }
      final senderData = senderSnap.data() as Map<String, dynamic>;
      final double senderBalance =
          (senderData['votre_solde_principal'] ?? 0.0).toDouble();

      // Vérifier le solde
      if (senderBalance >= amount) {
        final double gainDestinataire = amount * 0.5;
        final double gainApplication = amount * 0.5;

        // Débiter l'expéditeur
        await firestore
            .collection('Users')
            .doc(authProvider.loginUserData.id)
            .update({
          'votre_solde_principal': FieldValue.increment(-amount),
        });

        // Créditer le destinataire
        await firestore.collection('Users').doc(widget.post.user!.id).update({
          'votre_solde_principal': FieldValue.increment(gainDestinataire),
        });

        // Créditer l'application
        String appDataId = authProvider.appDefaultData.id!;
        await firestore.collection('AppData').doc(appDataId).update({
          'solde_gain': FieldValue.increment(gainApplication),
        });

        // Ajouter l'expéditeur à la liste des cadeaux du post
        await firestore.collection('Posts').doc(widget.post.id).update({
          'users_cadeau_id':
              FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(5),
        });

        // Créer les transactions
        await _createTransaction(
            TypeTransaction.DEPENSE.name,
            amount,
            "Cadeau envoyé à @${widget.post.user!.pseudo}",
            authProvider.loginUserData.id!);
        await _createTransaction(
            TypeTransaction.GAIN.name,
            gainDestinataire,
            "Cadeau reçu de @${authProvider.loginUserData.pseudo}",
            widget.post.user_id!);

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
          userIds: [widget.post.user!.oneIgnalUserid!],
          smallImage: "",
          send_user_id: "",
          recever_user_id: "${widget.post.user_id!}",
          message: "🎁 Vous avez reçu un cadeau de ${amount.toInt()} FCFA !",
          type_notif: NotificationType.POST.name,
          post_id: "${widget.post!.id!}",
          post_type: PostDataType.IMAGE.name,
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

  void _showGiftDialog() {
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
                            onTap: () =>
                                setState(() => _selectedGiftIndex = index),
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
                          child: Text('Annuler',
                              style: TextStyle(color: Colors.white)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _sendGift(giftPrices[_selectedGiftIndex]);
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

  List<double> giftPrices = [
    10,
    25,
    50,
    100,
    200,
    300,
    500,
    700,
    1500,
    2000,
    2500,
    5000,
    7000,
    10000,
    15000,
    20000,
    30000,
    50000,
    75000,
    100000
  ];

  List<String> giftIcons = [
    '🌹',
    '❤️',
    '👑',
    '💎',
    '🏎️',
    '⭐',
    '🍫',
    '🧰',
    '🌵',
    '🍕',
    '🍦',
    '💻',
    '🚗',
    '🏠',
    '🛩️',
    '🛥️',
    '🏰',
    '💎',
    '🏎️',
    '🚗'
  ];

  Future<void> _repostForCash() async {
    try {
      setState(() => _isLoading = true);

      final firestore = FirebaseFirestore.instance;

      // Récupérer l'utilisateur connecté à jour
      final userDoc = await firestore
          .collection('Users')
          .doc(authProvider.loginUserData.id)
          .get();
      final userData = userDoc.data();
      if (userData == null) throw Exception("Utilisateur introuvable !");
      final double soldeActuel =
          (userData['votre_solde_principal'] ?? 0.0).toDouble();

      if (soldeActuel >= _selectedRepostPrice) {
        // Débiter l'expéditeur
        await firestore
            .collection('Users')
            .doc(authProvider.loginUserData.id)
            .update({
          'votre_solde_principal': FieldValue.increment(-_selectedRepostPrice),
        });

        // Créditer l'application
        await firestore
            .collection('AppData')
            .doc(authProvider.appDefaultData.id!)
            .update({
          'solde_gain': FieldValue.increment(_selectedRepostPrice),
        });

        // Mettre à jour le post : ajouter l'utilisateur et remettre à jour la date
        await firestore.collection('Posts').doc(widget.post.id).update({
          'users_republier_id':
              FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(4),
          'created_at': DateTime.now().microsecondsSinceEpoch,
          'updated_at': DateTime.now().microsecondsSinceEpoch,
        });

        // Créer la transaction
        await _createTransaction(
          TypeTransaction.DEPENSE.name,
          _selectedRepostPrice.toDouble(),
          "Republication du post ${widget.post.id}",
          authProvider.loginUserData.id!,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              '🔝 Post republié pour $_selectedRepostPrice FCFA!',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      } else {
        _showInsufficientBalanceDialog();
      }
    } catch (e) {
      print("Erreur republication: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Erreur lors de la republication',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => DepositScreen()));
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

  void _showRepostDialog() {
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
            'Republier le Post',
            style: TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Republier ce post le mettra en avant dans le fil d\'actualité. Coût: 25 FCFA.',
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
                _repostForCash();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Republier', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserHeader(Post post) {
    final canal = post.canal;
    final user = post.user;

    return GestureDetector(
      onTap: () {
        if (canal != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      CanalDetails(canal: widget.post.canal!)));
        } else {
          double w = MediaQuery.of(context).size.width;
          double h = MediaQuery.of(context).size.height;
          showUserDetailsModalDialog(user!, w, h, context);
        }
      },
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(
                  canal?.urlImage ?? user?.imageUrl ?? '',
                ),
                radius: 25,
              ),
              // Badge vérifié
              // if ((canal?.isVerify ?? false) || (user?.isVerify ?? false))
              if ((canal?.isVerify ?? false) || (user?.isVerify ?? false))
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: _twitterDarkBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified,
                      color: _twitterBlue,
                      size: 14,
                    ),
                  ),
                ),
              // Badge Look Challenge
              if (_isLookChallenge)
                Positioned(
                  top: -2,
                  left: -2,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _twitterGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canal != null) ...[
                  Row(
                    children: [
                      Text(
                        '#${canal.titre ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 4),
                      if (canal.isVerify ?? false)
                        Icon(Icons.verified, color: _twitterBlue, size: 16),
                    ],
                  ),
                  Text(
                    '${canal.usersSuiviId!.length ?? 0} abonnés',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ] else if (user != null) ...[
                  Row(
                    children: [
                      Text(
                        '@${user.pseudo ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 4),
                      if (user.isVerify ?? false)
                        Icon(Icons.verified, color: _twitterBlue, size: 16),
                      SizedBox(width: 4),
                      if (_isLookChallenge)
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _twitterGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _twitterGreen),
                          ),
                          child: Text(
                            'LOOK',
                            style: TextStyle(
                              color: _twitterGreen,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${user.userAbonnesIds!.length ?? 0} abonnés${_isLookChallenge ? ' • ${post.votesChallenge ?? 0} votes' : ''}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    formaterDateTime(
                      DateTime.fromMicrosecondsSinceEpoch(post.createdAt ?? 0),
                    ),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showPostMenu(widget.post),
            child: Icon(
              Icons.more_horiz,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
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
                      style:
                          TextStyle(color: value ? Colors.green : Colors.red),
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
                    await deletePost(post, context);
                  } else {
                    post.status = PostStatus.SUPPRIMER.name;
                    await deletePost(post, context);
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
            Container(
                height: 0.5, color: _twitterTextSecondary.withOpacity(0.3)),
            SizedBox(height: 8),
            _buildMenuOption(Icons.cancel, "Annuler", _twitterTextSecondary,
                () {
              Navigator.pop(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(
      IconData icon, String text, Color color, VoidCallback onTap) {
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

  Widget _buildPostContent(Post post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.description != null && post.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              post.description!,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        if (post.images != null && post.images!.isNotEmpty)
          Container(
            height: 300,
            margin: EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
              border: _isLookChallenge
                  ? Border.all(color: _twitterGreen.withOpacity(0.3))
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: ImageSlideshow(
                initialPage: 0,
                indicatorColor:
                    _isLookChallenge ? _twitterGreen : Colors.yellow,
                indicatorBackgroundColor: Colors.grey,
                onPageChanged: (value) {
                  print('Page changed: $value');
                },
                isLoop: true,
                children: post!.images!
                    .map((imageUrl) => GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    FullScreenImage(imageUrl: imageUrl),
                              ),
                            );
                          },
                          child: Hero(
                            tag: imageUrl,
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[800],
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.yellow)),
                              ),
                              errorWidget: (context, url, error) =>
                                  Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }

  // NOUVELLE SECTION POUR LES LOOK CHALLENGES
  Widget _buildLookChallengeSection(Post post) {
    if (!_isLookChallenge) return SizedBox();

    return FutureBuilder<DocumentSnapshot>(
      future: widget.post.challenge_id != null
          ? firestore
              .collection('Challenges')
              .doc(widget.post.challenge_id)
              .get()
          : null,
      builder: (context, challengeSnapshot) {
        if (challengeSnapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 15),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _twitterCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _twitterGreen.withOpacity(0.3)),
            ),
            child: Center(
              child: CircularProgressIndicator(color: _twitterGreen),
            ),
          );
        }

        if (challengeSnapshot.hasError ||
            !challengeSnapshot.hasData ||
            !challengeSnapshot.data!.exists) {
          return _buildBasicChallengeSection(post);
        }

        // Récupérer le challenge
        final challengeData =
            challengeSnapshot.data!.data() as Map<String, dynamic>;
        final challenge = Challenge.fromJson(challengeData);
// Vérifier l'état du challenge
        final bool challengeTermine = challenge.isTermine ||
            DateTime.now().microsecondsSinceEpoch > (challenge.finishedAt ?? 0);
        final bool peutVoter = challenge.peutParticiper && !_hasVoted;
        return FutureBuilder<DocumentSnapshot>(
          future: challenge.postChallengeId != null
              ? firestore
                  .collection('Posts')
                  .doc(challenge.postChallengeId)
                  .get()
              : null,
          builder: (context, postChallengeSnapshot) {
            Post? postChallenge;
            if (postChallengeSnapshot.hasData &&
                postChallengeSnapshot.data!.exists) {
              final postData =
                  postChallengeSnapshot.data!.data() as Map<String, dynamic>;
              postChallenge = Post.fromJson(postData);
            }

            return Container(
              margin: EdgeInsets.symmetric(vertical: 15),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _twitterCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _twitterGreen.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête du challenge avec titre
                  Row(
                    children: [
                      Icon(Icons.emoji_events, color: _twitterGreen, size: 24),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LOOK CHALLENGE',
                              style: TextStyle(
                                color: _twitterGreen,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (challenge.titre != null &&
                                challenge.titre!.isNotEmpty)
                              Text(
                                challenge.titre!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Aperçu du post du challenge
                  if (postChallenge != null)
                    _buildChallengePostPreview(challenge, postChallenge),

                  // Statistiques du look
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildChallengeStatItem(
                        icon: Icons.how_to_vote,
                        value: '${post.votesChallenge ?? 0}',
                        label: 'Votes',
                        color: _twitterGreen,
                      ),
                      _buildChallengeStatItem(
                        icon: Icons.people,
                        // value: '${challenge.totalParticipants ?? 0}',
                        value: '${challenge.usersInscritsIds!.length ?? 0}',
                        label: 'Participants',
                        color: _twitterBlue,
                      ),
                      _buildChallengeStatItem(
                        icon: Icons.favorite,
                        value: '${post.loves ?? 0}',
                        label: 'Likes',
                        color: _twitterRed,
                      ),
                      _buildChallengeStatItem(
                        icon: Icons.trending_up,
                        value: '${post.popularity ?? 0}',
                        label: 'Popularité',
                        color: _twitterYellow,
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Description du challenge
                  if (challenge.description != null &&
                      challenge.description!.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📝 À propos du challenge',
                            style: TextStyle(
                              color: _twitterGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            challenge.description!,
                            style: TextStyle(
                              color: _twitterTextSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 12),
                  Column(
                    children: [
                      // Message d'incitation
                      if (!challengeTermine)
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '🎯 VOTER POUR CE LOOK',
                                style: TextStyle(
                                  color: _twitterGreen,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Votre vote aide ce participant à gagner le challenge !',
                                style: TextStyle(
                                  color: _twitterTextSecondary,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (!challenge.voteGratuit!)
                                Text(
                                  'Coût du vote: ${challenge.prixVote} FCFA',
                                  style: TextStyle(
                                    color: _twitterYellow,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '⏰ CE CHALLENGE EST TERMINÉ',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      SizedBox(height: 16),

                      // Boutons d'action
                      Row(
                        children: [
                          // Bouton de vote
                          if (peutVoter)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isVoting
                                    ? null
                                    : _showVoteConfirmationDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _twitterGreen,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: _isVoting
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.how_to_vote, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'VOTER',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            )
                          else
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _twitterGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _twitterGreen),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: _twitterGreen, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      _hasVoted
                                          ? 'DÉJÀ VOTÉ'
                                          : 'NON DISPONIBLE',
                                      style: TextStyle(
                                        color: _twitterGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          SizedBox(width: 12),

                          // Bouton pour voir le challenge
                          ElevatedButton(
                            onPressed: () {
                              if (challenge.id != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChallengeDetailPage(
                                        challengeId: challenge.id!),
                                  ),
                                );
                                print(
                                    'Navigation vers le challenge: ${challenge.id}');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _twitterBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Voir',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // // Message d'incitation au vote
                  // Container(
                  //   padding: EdgeInsets.all(12),
                  //   decoration: BoxDecoration(
                  //     color: Colors.black.withOpacity(0.3),
                  //     borderRadius: BorderRadius.circular(12),
                  //   ),
                  //   child: Column(
                  //     children: [
                  //       Text(
                  //         '🎯 VOTER POUR CE LOOK',
                  //         style: TextStyle(
                  //           color: _twitterGreen,
                  //           fontSize: 16,
                  //           fontWeight: FontWeight.bold,
                  //         ),
                  //         textAlign: TextAlign.center,
                  //       ),
                  //       SizedBox(height: 8),
                  //       Text(
                  //         'Votre vote aide ce participant à gagner le challenge !',
                  //         style: TextStyle(
                  //           color: _twitterTextSecondary,
                  //           fontSize: 14,
                  //         ),
                  //         textAlign: TextAlign.center,
                  //       ),
                  //       if (!challenge.voteGratuit!)
                  //         Text(
                  //           'Coût du vote: ${challenge.prixVote} FCFA',
                  //           style: TextStyle(
                  //             color: _twitterYellow,
                  //             fontSize: 12,
                  //             fontWeight: FontWeight.bold,
                  //           ),
                  //           textAlign: TextAlign.center,
                  //         ),
                  //     ],
                  //   ),
                  // ),
                  // SizedBox(height: 16),
                  //
                  // // Boutons d'action
                  // Row(
                  //   children: [
                  //     // Bouton de vote
                  //     if (!_hasVoted)
                  //       Expanded(
                  //         child: ElevatedButton(
                  //           onPressed: _isVoting ? null : _showVoteConfirmationDialog,
                  //           style: ElevatedButton.styleFrom(
                  //             backgroundColor: _twitterGreen,
                  //             shape: RoundedRectangleBorder(
                  //               borderRadius: BorderRadius.circular(20),
                  //             ),
                  //             padding: EdgeInsets.symmetric(vertical: 12),
                  //           ),
                  //           child: _isVoting
                  //               ? SizedBox(
                  //             width: 20,
                  //             height: 20,
                  //             child: CircularProgressIndicator(
                  //               strokeWidth: 2,
                  //               color: Colors.white,
                  //             ),
                  //           )
                  //               : Row(
                  //             mainAxisAlignment: MainAxisAlignment.center,
                  //             children: [
                  //               Icon(Icons.how_to_vote, size: 18),
                  //               SizedBox(width: 8),
                  //               Text(
                  //                 'VOTER',
                  //                 style: TextStyle(
                  //                   fontSize: 14,
                  //                   fontWeight: FontWeight.bold,
                  //                 ),
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //       )
                  //     else
                  //       Expanded(
                  //         child: Container(
                  //           padding: EdgeInsets.all(12),
                  //           decoration: BoxDecoration(
                  //             color: _twitterGreen.withOpacity(0.1),
                  //             borderRadius: BorderRadius.circular(12),
                  //             border: Border.all(color: _twitterGreen),
                  //           ),
                  //           child: Row(
                  //             mainAxisAlignment: MainAxisAlignment.center,
                  //             children: [
                  //               Icon(Icons.check_circle, color: _twitterGreen, size: 16),
                  //               SizedBox(width: 6),
                  //               Text(
                  //                 'DÉJÀ VOTÉ',
                  //                 style: TextStyle(
                  //                   color: _twitterGreen,
                  //                   fontSize: 12,
                  //                   fontWeight: FontWeight.bold,
                  //                 ),
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //       ),
                  //
                  //     SizedBox(width: 12),
                  //
                  //     // Bouton pour voir le challenge
                  //     ElevatedButton(
                  //       onPressed: () {
                  //         if (challenge.id != null) {
                  //           // Naviguer vers la page du challenge
                  //           Navigator.push(
                  //             context,
                  //             MaterialPageRoute(
                  //               builder: (context) => ChallengeDetailPage(challengeId: challenge.id!),
                  //             ),
                  //           );
                  //           print('Navigation vers le challenge: ${challenge.id}');
                  //           // TODO: Implémenter la navigation vers la page du challenge
                  //         }
                  //       },
                  //       style: ElevatedButton.styleFrom(
                  //         backgroundColor: _twitterBlue,
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(20),
                  //         ),
                  //         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  //       ),
                  //       child: Row(
                  //         mainAxisSize: MainAxisSize.min,
                  //         children: [
                  //           Icon(Icons.visibility, size: 16),
                  //           SizedBox(width: 6),
                  //           Text(
                  //             'Voir',
                  //             style: TextStyle(
                  //               fontSize: 12,
                  //               fontWeight: FontWeight.bold,
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //     ),
                  //   ],
                  // ),

                  // Liste des votants récents
                  if (_votersList.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Derniers votants',
                      style: TextStyle(
                        color: _twitterTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _votersList.length,
                        itemBuilder: (context, index) {
                          return FutureBuilder<DocumentSnapshot>(
                            future: firestore
                                .collection('Users')
                                .doc(_votersList[index])
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.exists) {
                                var userData = UserData.fromJson(snapshot.data!
                                    .data() as Map<String, dynamic>);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        backgroundImage: NetworkImage(
                                            userData.imageUrl ?? ''),
                                        radius: 15,
                                      ),
                                      SizedBox(height: 2),
                                      Text('🗳️',
                                          style: TextStyle(fontSize: 8)),
                                    ],
                                  ),
                                );
                              }
                              return SizedBox();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChallengePostPreview(Challenge challenge, Post postChallenge) {
    final hasImages =
        postChallenge.images != null && postChallenge.images!.isNotEmpty;
    final hasVideo =
        postChallenge.url_media != null && postChallenge.url_media!.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _twitterGreen.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Naviguer vers le post du challenge
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsPost(post: postChallenge),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.all(8),
              child: Row(
                children: [
                  // Miniature
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _twitterTextSecondary.withOpacity(0.1),
                    ),
                    child: _buildChallengePreviewThumbnail(postChallenge),
                  ),
                  SizedBox(width: 12),

                  // Informations
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Post du Challenge',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          challenge.titre ?? 'Challenge',
                          style: TextStyle(
                            color: _twitterTextSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap pour voir →',
                          style: TextStyle(
                            color: _twitterGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengePreviewThumbnail(Post post) {
    final hasImages = post.images != null && post.images!.isNotEmpty;
    final hasVideo = post.url_media != null && post.url_media!.isNotEmpty;

    if (hasImages) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: post.images!.first,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: _twitterTextSecondary.withOpacity(0.2),
            child: Icon(Icons.photo, color: _twitterTextSecondary, size: 20),
          ),
          errorWidget: (context, url, error) =>
              Icon(Icons.error, color: Colors.red, size: 20),
        ),
      );
    } else if (hasVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: _twitterTextSecondary.withOpacity(0.2),
          child: Icon(Icons.videocam, color: _twitterTextSecondary, size: 20),
        ),
      );
    } else {
      return Container(
        color: _twitterTextSecondary.withOpacity(0.2),
        child: Icon(Icons.article, color: _twitterTextSecondary, size: 20),
      );
    }
  }

  Widget _buildBasicChallengeSection(Post post) {
    // Section de fallback si le challenge n'est pas trouvé
    return Container(
      margin: EdgeInsets.symmetric(vertical: 15),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _twitterCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _twitterGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: _twitterGreen, size: 24),
              SizedBox(width: 8),
              Text(
                'LOOK CHALLENGE',
                style: TextStyle(
                  color: _twitterGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Statistiques de base
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildChallengeStatItem(
                icon: Icons.how_to_vote,
                value: '${post.votesChallenge ?? 0}',
                label: 'Votes',
                color: _twitterGreen,
              ),
              _buildChallengeStatItem(
                icon: Icons.visibility,
                value: '${post.vues ?? 0}',
                label: 'Vues',
                color: _twitterBlue,
              ),
              _buildChallengeStatItem(
                icon: Icons.favorite,
                value: '${post.loves ?? 0}',
                label: 'Likes',
                color: _twitterRed,
              ),
            ],
          ),
          SizedBox(height: 16),

          // Bouton de vote de base
          if (!_hasVoted)
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVoting ? null : _showVoteConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _twitterGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isVoting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.how_to_vote, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'VOTER POUR CE LOOK',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _twitterGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _twitterGreen),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: _twitterGreen, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Vous avez déjà voté pour ce look',
                    style: TextStyle(
                      color: _twitterGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChallengeStatItem(
      {required IconData icon,
      required String value,
      required String label,
      required Color color}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _twitterTextSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(Post post) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          icon: Icons.remove_red_eye,
          count: post.vues ?? 0,
          label: 'Vues',
        ),
        GestureDetector(
          onTap: _handleLike,
          child: _buildStatItem(
            icon: Icons.favorite,
            count: post.loves ?? 0,
            label: 'Likes',
            isLiked: isIn(post.users_love_id!, authProvider.loginUserData.id!),
          ),
        ),
        GestureDetector(
          onTap: () {
            firestore.collection('Posts').doc(widget.post.id).update({
              'popularity': FieldValue.increment(1),
            });
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostComments(post: widget.post),
              ),
            );
          },
          child: _buildStatItem(
            icon: Icons.comment,
            count: widget.post.comments ?? 0,
            label: 'Comments',
          ),
        ),
        GestureDetector(
          onTap: _showGiftDialog,
          child: _buildStatItem(
            icon: Icons.card_giftcard,
            count: post.users_cadeau_id?.length ?? 0,
            label: 'Cadeaux',
          ),
        ),
        GestureDetector(
          onTap: () async {
            final AppLinkService _appLinkService = AppLinkService();
            _appLinkService.shareContent(
              type: AppLinkType.post,
              id: widget.post.id!,
              message: " ${widget.post.description}",
              mediaUrl: widget.post.images!.isNotEmpty
                  ? "${widget.post.images!}"
                  : "",
            );
            await FirebaseFirestore.instance
                .collection('Posts')
                .doc(widget.post.id!)
                .update({
              'partage': FieldValue.increment(1),
            });
          },
          child: _buildStatItem(
            icon: Icons.share,
            count: post.partage ?? 0,
            label: 'Partages',
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
      {required IconData icon,
      required int count,
      required String label,
      bool isLiked = false}) {
    return Column(
      children: [
        Icon(icon, color: isLiked ? Colors.red : Colors.yellow, size: 20),
        SizedBox(height: 5),
        Text(
          formatNumber(count),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Post post) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 15),
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Bouton Like
          ScaleTransition(
            scale: _scaleAnimation,
            child: IconButton(
              icon: Icon(
                isIn(post.users_love_id!, authProvider.loginUserData.id!)
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: isIn(post.users_love_id!, authProvider.loginUserData.id!)
                    ? Colors.red
                    : Colors.white,
                size: 30,
              ),
              onPressed: _handleLike,
            ),
          ),

          // Bouton Commentaire
          IconButton(
            icon:
                Icon(Icons.chat_bubble_outline, color: Colors.white, size: 30),
            onPressed: () async {
              await firestore.collection('Posts').doc(widget.post.id).update({
                'popularity': FieldValue.increment(1),
              });
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostComments(post: widget.post),
                ),
              );
            },
          ),

          // Bouton Cadeau
          IconButton(
            icon: Icon(Icons.card_giftcard, color: Colors.yellow, size: 30),
            onPressed: _showGiftDialog,
          ),

          // Bouton Republier
          IconButton(
            icon: Icon(Icons.repeat, color: Colors.green, size: 30),
            onPressed: _showRepostDialog,
          ),

          // Bouton Partager
          IconButton(
            icon: Icon(Icons.share, color: Colors.white, size: 30),
            onPressed: () async {
              final AppLinkService _appLinkService = AppLinkService();
              _appLinkService.shareContent(
                type: AppLinkType.post,
                id: widget.post.id!,
                message: " ${widget.post.description}",
                mediaUrl: widget.post.images!.isNotEmpty
                    ? "${widget.post.images!}"
                    : "",
              );
              await FirebaseFirestore.instance
                  .collection('Posts')
                  .doc(widget.post.id!)
                  .update({
                'partage': FieldValue.increment(1),
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.yellow),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isLookChallenge ? 'Détails du Look Challenge' : 'Détails du Post',
          style: TextStyle(
              color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          Text(
            'Afrolook',
            style: TextStyle(
                color: Colors.green, fontWeight: FontWeight.bold, fontSize: 20),
          )
        ],
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _postStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Erreur de chargement',
                    style: TextStyle(color: Colors.white)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: Colors.yellow));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
                child: Text('Post non trouvé',
                    style: TextStyle(color: Colors.white)));
          }

          // Mettre à jour le post avec les données du stream
          final updatedPost =
              Post.fromJson(snapshot.data!.data() as Map<String, dynamic>);
          updatedPost.user =
              widget.post.user; // Conserver les données utilisateur
   updatedPost.canal =
              widget.post.canal; // Conserver les données utilisateur

          return _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.yellow))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserHeader(updatedPost),
                      SizedBox(height: 20),
                      _buildPostContent(updatedPost),

                      // SECTION LOOK CHALLENGE (uniquement pour les challenges)
                      if (_isLookChallenge)
                        _buildLookChallengeSection(updatedPost),

                      SizedBox(height: 20),
                      Divider(color: Colors.grey[700]),
                      _buildStatsRow(updatedPost),
                      Divider(color: Colors.grey[700]),
                      _buildActionButtons(updatedPost),

                      // Section des cadeaux récents
                      if (updatedPost.users_cadeau_id != null &&
                          updatedPost.users_cadeau_id!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Derniers cadeaux',
                                style: TextStyle(
                                  color: Colors.yellow,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 10),
                              Container(
                                height: 60,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount:
                                      updatedPost.users_cadeau_id!.length,
                                  itemBuilder: (context, index) {
                                    return FutureBuilder<DocumentSnapshot>(
                                      future: firestore
                                          .collection('Users')
                                          .doc(updatedPost
                                              .users_cadeau_id![index])
                                          .get(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData &&
                                            snapshot.data!.exists) {
                                          var userData = UserData.fromJson(
                                              snapshot.data!.data()
                                                  as Map<String, dynamic>);
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                right: 10),
                                            child: Column(
                                              children: [
                                                CircleAvatar(
                                                  backgroundImage: NetworkImage(
                                                      userData.imageUrl ?? ''),
                                                  radius: 15,
                                                ),
                                                SizedBox(height: 2),
                                                Text('🎁',
                                                    style:
                                                        TextStyle(fontSize: 8)),
                                              ],
                                            ),
                                          );
                                        }
                                        return SizedBox();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
        },
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({required this.imageUrl, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: imageUrl,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    CircularProgressIndicator(color: Colors.yellow),
                errorWidget: (context, url, error) =>
                    Icon(Icons.error, color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

