// challenge_detail_page.dart (version complète refaite)
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/entreprise/depot/depotPublicash.dart';
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import '../postDetailsVideoListe.dart';
import 'newChallenge.dart';

// challenge_detail_page.dart (version complète améliorée)
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/entreprise/depot/depotPublicash.dart';
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'newChallenge.dart';

class ChallengeDetailPage extends StatefulWidget {
  final String challengeId;

  const ChallengeDetailPage({Key? key, required this.challengeId}) : super(key: key);

  @override
  _ChallengeDetailPageState createState() => _ChallengeDetailPageState();
}

class _ChallengeDetailPageState extends State<ChallengeDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late UserAuthProvider authProvider;

  Challenge? _challenge;
  List<Post> _posts = [];
  List<UserData> _participants = [];
  bool _loading = true;
  int _currentTab = 0; // 0: Détails, 1: Participants, 2: Posts
  Timer? _statusTimer;
  StreamSubscription? _challengeSubscription;

  // Nouveaux états pour la gestion du gagnant et de l'aperçu
  Post? _postChallenge;
  Post? _postGagnant;
  bool _prixDejaEncaisser = false;

  @override
  void initState() {
    super.initState();
    _initializeChallenge();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _challengeSubscription?.cancel();
    super.dispose();
  }

  void _initializeChallenge() async {
    await _loadChallenge();
    _startStatusMonitoring();
    _listenToChallengeUpdates();
  }

  void _startStatusMonitoring() {
    _statusTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _checkAndUpdateChallengeStatus();
    });
  }

  void _listenToChallengeUpdates() {
    _challengeSubscription = _firestore
        .collection('Challenges')
        .doc(widget.challengeId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() {
          _challenge = Challenge.fromJson(snapshot.data()!)..id = snapshot.id;
        });
        _checkAndUpdateChallengeStatus();
        _loadPostChallenge();
        _loadPostGagnant();
      }
    });
  }

  Future<void> _checkAndUpdateChallengeStatus() async {
    if (_challenge == null) return;

    final now = DateTime.now().microsecondsSinceEpoch;
    String? newStatus;

    debugPrint("=== VÉRIFICATION STATUT ===");
    debugPrint("Statut actuel: ${_challenge!.statut}");
    debugPrint("Now: $now");
    debugPrint("EndInscriptionAt: ${_challenge!.endInscriptionAt}");
    debugPrint("FinishedAt: ${_challenge!.finishedAt}");
    debugPrint("PostsWinnerIds: ${_challenge!.postsWinnerIds}");

    if (_challenge!.statut == 'en_attente') {
      if (_challenge!.endInscriptionAt != null && now >= _challenge!.endInscriptionAt!) {
        newStatus = 'en_cours';
        debugPrint("🚀 Passage à EN COURS");
      }
    } else if (_challenge!.statut == 'en_cours') {
      if (_challenge!.finishedAt != null && now >= _challenge!.finishedAt!) {
        newStatus = 'termine';
        debugPrint("🏁 Passage à TERMINÉ");
      }
    }

    // CORRECTION PRINCIPALE : Si le challenge est terminé mais qu'aucun gagnant n'a été déterminé
    if (_challenge!.isTermine && (_challenge!.postsWinnerIds == null || _challenge!.postsWinnerIds!.isEmpty)) {
      debugPrint("🎯 Challenge terminé sans gagnant - Détermination du gagnant...");
      await _determinerGagnant();
      return; // On sort après avoir déterminé le gagnant
    }

    // Mise à jour normale du statut
    if (newStatus != null && newStatus != _challenge!.statut) {
      await _updateChallengeStatus(newStatus);
    }
  }

  Future<void> _updateChallengeStatus(String newStatus) async {
    try {
      Map<String, dynamic> updateData = {
        'statut': newStatus,
        'updated_at': DateTime.now().microsecondsSinceEpoch,
      };

      // Si le challenge passe à "terminé", on détermine le gagnant AVANT de mettre à jour
      if (newStatus == 'termine') {
        await _determinerGagnant();
      }

      await _firestore.collection('Challenges').doc(_challenge!.id!).update(updateData);

      debugPrint("✅ Statut mis à jour: $newStatus");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Le challenge est maintenant ${_getStatusText(newStatus)}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur mise à jour statut: $e');
    }
  }

  Future<void> _determinerGagnant() async {
    try {
      debugPrint("🎯 Détermination du gagnant du challenge...");

      // Récupérer tous les posts du challenge triés par votes décroissants
      final postsSnapshot = await _firestore
          .collection('Posts')
          .where('challenge_id', isEqualTo: _challenge!.id)
          .orderBy('votes_challenge', descending: true)
          .limit(1)
          .get();

      if (postsSnapshot.docs.isNotEmpty) {
        final postGagnantDoc = postsSnapshot.docs.first;
        final postGagnantId = postGagnantDoc.id;
        final votesGagnant = postGagnantDoc.data()['votes_challenge'] ?? 0;
        final userIdGagnant = postGagnantDoc.data()['user_id'];

        debugPrint("🏆 Post gagnant trouvé: $postGagnantId avec $votesGagnant votes");
        debugPrint("👤 User ID gagnant: $userIdGagnant");

        // Mettre à jour le challenge avec l'ID du post gagnant ET du user gagnant
        await _firestore.collection('Challenges').doc(_challenge!.id!).update({
          'posts_winner_ids': [postGagnantId],
          'user_gagnant_id': userIdGagnant,
          'prix_deja_encaisser': false, // Initialiser à false
          'updated_at': DateTime.now().microsecondsSinceEpoch,
        });

        debugPrint("✅ Gagnant enregistré: $postGagnantId (User: $userIdGagnant)");

        // Mettre à jour localement le challenge
        if (mounted) {
          setState(() {
            _challenge!.postsWinnerIds = [postGagnantId];
            _challenge!.userGagnantId = userIdGagnant;
            _challenge!.prixDejaEncaisser = false;
          });
        }

        // Charger les données du post gagnant pour l'affichage
        await _loadPostGagnant();

      } else {
        debugPrint("⚠️ Aucun post trouvé pour ce challenge - Pas de gagnant");
      }
    } catch (e) {
      debugPrint('❌ Erreur détermination gagnant: $e');
    }
  }
  Future<void> _loadChallenge() async {
    try {
      final challengeDoc = await _firestore.collection('Challenges').doc(widget.challengeId).get();
      if (challengeDoc.exists) {
        setState(() {
          _challenge = Challenge.fromJson(challengeDoc.data()!)..id = challengeDoc.id;
        });

        debugPrint("📋 Challenge chargé: ${_challenge!.titre}");
        debugPrint("📊 Statut: ${_challenge!.statut}");
        debugPrint("🏆 Posts winner IDs: ${_challenge!.postsWinnerIds}");
        debugPrint("🏆 isTermine: ${_challenge!.isTermine}");

        // CORRECTION : Vérifier immédiatement si le challenge est terminé sans gagnant
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _checkAndUpdateChallengeStatus(); // Cette ligne va maintenant détecter le cas "terminé sans gagnant"
        });

        // Charger les données supplémentaires
        await Future.wait([
          _loadPostChallenge(),
          _loadParticipants(),
          _loadPosts(),
          _checkPrixEncaisser(),
        ]);

        // Charger le gagnant si le challenge est terminé ET qu'il y a un gagnant
        if (_challenge!.isTermine && _challenge!.postsWinnerIds != null && _challenge!.postsWinnerIds!.isNotEmpty) {
          await _loadPostGagnant();
        }

      } else {
        throw Exception('Challenge non trouvé');
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement challenge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement du challenge'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  Future<void> _loadPostGagnant() async {
    try {
      if (_challenge?.isTermine == true &&
          _challenge?.postsWinnerIds != null &&
          _challenge!.postsWinnerIds!.isNotEmpty) {

        final postGagnantId = _challenge!.postsWinnerIds!.first;
        debugPrint("📥 Chargement du post gagnant: $postGagnantId");

        final postDoc = await _firestore.collection('Posts').doc(postGagnantId).get();

        if (postDoc.exists) {
          final post = Post.fromJson(postDoc.data()!)..id = postDoc.id;

          // Charger les données utilisateur du gagnant
          if (post.user_id != null) {
            final userDoc = await _firestore.collection('Users').doc(post.user_id).get();
            if (userDoc.exists) {
              post.user = UserData.fromJson(userDoc.data()!);
              debugPrint("👤 Utilisateur gagnant chargé: ${post.user!.pseudo}");
            }
          }

          setState(() {
            _postGagnant = post;
          });

          debugPrint("✅ Post gagnant chargé avec succès");
        } else {
          debugPrint("❌ Post gagnant non trouvé en base de données");
        }
      } else {
        debugPrint("ℹ️ Aucun gagnant à charger - postsWinnerIds vide ou challenge non terminé");
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement post gagnant: $e');
    }
  }

  // Future<void> _checkAndUpdateChallengeStatus() async {
  //   if (_challenge == null) return;
  //
  //   final now = DateTime.now().microsecondsSinceEpoch;
  //   String? newStatus;
  //
  //   debugPrint("=== VÉRIFICATION STATUT ===");
  //   debugPrint("Statut actuel: ${_challenge!.statut}");
  //   debugPrint("Now: $now");
  //   debugPrint("EndInscriptionAt: ${_challenge!.endInscriptionAt}");
  //   debugPrint("FinishedAt: ${_challenge!.finishedAt}");
  //
  //   if (_challenge!.statut == 'en_attente') {
  //     if (_challenge!.endInscriptionAt != null && now >= _challenge!.endInscriptionAt!) {
  //       newStatus = 'en_cours';
  //       debugPrint("🚀 Passage à EN COURS");
  //     }
  //   } else if (_challenge!.statut == 'en_cours') {
  //     if (_challenge!.finishedAt != null && now >= _challenge!.finishedAt!) {
  //       newStatus = 'termine';
  //       debugPrint("🏁 Passage à TERMINÉ");
  //     }
  //   }
  //
  //   if (newStatus != null && newStatus != _challenge!.statut) {
  //     await _updateChallengeStatus(newStatus);
  //   }
  // }
  //
  // Future<void> _updateChallengeStatus(String newStatus) async {
  //   try {
  //     await _firestore.collection('Challenges').doc(_challenge!.id!).update({
  //       'statut': newStatus,
  //       'updated_at': DateTime.now().microsecondsSinceEpoch,
  //     });
  //
  //     debugPrint("✅ Statut mis à jour: $newStatus");
  //
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Le challenge est maintenant ${_getStatusText(newStatus)}'),
  //           backgroundColor: Colors.green,
  //           duration: Duration(seconds: 3),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint('❌ Erreur mise à jour statut: $e');
  //   }
  // }
  // Future<void> _loadPostGagnant() async {
  //   try {
  //     if (_challenge?.isTermine == true &&
  //         _challenge?.postsWinnerIds != null &&
  //         _challenge!.postsWinnerIds!.isNotEmpty) {
  //
  //       final postGagnantId = _challenge!.postsWinnerIds!.first;
  //       final postDoc = await _firestore.collection('Posts').doc(postGagnantId).get();
  //
  //       if (postDoc.exists) {
  //         final post = Post.fromJson(postDoc.data()!)..id = postDoc.id;
  //
  //         // Charger les données utilisateur du gagnant
  //         if (post.user_id != null) {
  //           final userDoc = await _firestore.collection('Users').doc(post.user_id).get();
  //           if (userDoc.exists) {
  //             post.user = UserData.fromJson(userDoc.data()!);
  //           }
  //         }
  //
  //         setState(() {
  //           _postGagnant = post;
  //         });
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint('❌ Erreur chargement post gagnant: $e');
  //   }
  // }


  Future<void> _loadPostChallenge() async {
    try {
      if (_challenge?.postChallengeId != null && _challenge!.postChallengeId!.isNotEmpty) {
        final postDoc = await _firestore.collection('Posts').doc(_challenge!.postChallengeId!).get();
        if (postDoc.exists) {
          setState(() {
            _postChallenge = Post.fromJson(postDoc.data()!)..id = postDoc.id;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement post challenge: $e');
    }
  }


  Future<void> _checkPrixEncaisser() async {
    try {
      final user = _auth.currentUser;
      if (user != null && _challenge?.isTermine == true && _postGagnant != null) {
        // Vérification 1: Dans le challenge directement
        final challengeDoc = await _firestore.collection('Challenges').doc(_challenge!.id!).get();
        if (challengeDoc.exists) {
          final challengeData = challengeDoc.data();
          final prixDejaEncaisserChallenge = challengeData?['prix_deja_encaisser'] ?? false;
          final userGagnantId = challengeData?['user_gagnant_id'];

          // Vérification 2: Dans ChallengePaiements (sécurité supplémentaire)
          final result = await _firestore
              .collection('ChallengePaiements')
              .where('challenge_id', isEqualTo: _challenge!.id)
              .where('user_id', isEqualTo: user.uid)
              .where('statut', isEqualTo: 'paye')
              .limit(1)
              .get();

          final estGagnant = userGagnantId == user.uid;
          final dejaEncaisser = prixDejaEncaisserChallenge || result.docs.isNotEmpty;

          setState(() {
            _prixDejaEncaisser = dejaEncaisser && estGagnant;
          });

          debugPrint("💰 Vérification encaissement - Est gagnant: $estGagnant, Déjà encaissé: $dejaEncaisser");
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur vérification prix encaissé: $e');
    }
  }

  Future<void> _encaisserPrix() async {

    //    _showError(
    //         "⚠️ Ceci est une version de test.\n"
    //             "La fonctionnalité d'encaissement sera disponible dans la version complète."
    //     );
    final user = _auth.currentUser;
    if (user == null || _postGagnant == null || _challenge == null) {
      _showError('Données manquantes pour l\'encaissement');
      return;
    }
await  _checkPrixEncaisser();

    // VÉRIFICATION AVANT ENCAISSEMENT
    if (_prixDejaEncaisser) {
      _showError('Le prix a déjà été encaissé pour ce challenge');
      return;
    }
 printVm('_postGagnant user_id : ${_postGagnant!.user_id}');
 printVm('user.uid: ${user.uid}');
    // Vérifier que l'utilisateur est bien le gagnant
    if (_postGagnant!.user_id != user.uid) {
      _showError('Vous n\'êtes pas le gagnant de ce challenge');
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Encaissement du prix', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.yellow),
              SizedBox(height: 20),
              Text(
                'Traitement de votre gain de ${_challenge!.prix ?? 0} FCFA...',
                style: TextStyle(color: Colors.grey[300]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // TRANSACTION ROBUSTE
      // await _firestore.runTransaction((transaction) async {
      //   // 1. Vérifier que le prix n'a pas été encaissé entre-temps
      //   final challengeDoc = await transaction.get(_firestore.collection('Challenges').doc(_challenge!.id!));
      //   if (!challengeDoc.exists) {
      //     throw Exception('Challenge non trouvé');
      //   }
      //
      //   final challengeData = challengeDoc.data()!;
      //   final prixDejaEncaisser = challengeData['prix_deja_encaisser'] ?? false;
      //   final userGagnantId = challengeData['user_gagnant_id'];
      //
      //   if (prixDejaEncaisser) {
      //     throw Exception('Le prix a déjà été encaissé');
      //   }
      //   printVm('_postGagnant userGagnantId user_id : ${_postGagnant!.user_id}');
      //   printVm('user.uid: userGagnantId: ${user.uid}');
      //   if (userGagnantId != user.uid) {
      //     throw Exception('Vous n\'êtes pas le gagnant de ce challenge');
      //   }
      //
      //   final now = DateTime.now().microsecondsSinceEpoch;
      //
      //   // 2. Mettre à jour le challenge
      //   transaction.update(_firestore.collection('Challenges').doc(_challenge!.id!), {
      //     'prix_deja_encaisser': true,
      //     'date_encaissement': now,
      //     'updated_at': now,
      //   });
      //
      //   // 3. Enregistrer le paiement (sécurité)
      //   final paiementRef = _firestore.collection('ChallengePaiements').doc();
      //   transaction.set(paiementRef, {
      //     'id': paiementRef.id,
      //     'challenge_id': _challenge!.id,
      //     'user_id': user.uid,
      //     'post_id': _postGagnant!.id,
      //     'montant': _challenge!.prix,
      //     'statut': 'paye',
      //     'created_at': now,
      //     'updated_at': now,
      //   });
      //
      //   // 4. Enregistrer la transaction solde
      //   final transactionRef = _firestore.collection('TransactionSoldes').doc();
      //   transaction.set(transactionRef, {
      //     'id': transactionRef.id,
      //     'user_id': user.uid,
      //     'montant': _challenge!.prix,
      //     'type': TypeTransaction.GAIN.name,
      //     'description': 'Gain challenge: ${_challenge!.titre}',
      //     'createdAt': DateTime.now().millisecondsSinceEpoch,
      //     'statut': StatutTransaction.VALIDER.name,
      //   });
      //
      //   // 5. Créditer l'utilisateur
      //   final userDoc = await transaction.get(_firestore.collection('Users').doc(user.uid));
      //   if (!userDoc.exists) {
      //     throw Exception('Utilisateur non trouvé');
      //   }
      //
      //   final ancienSolde = (userDoc.data()!['votre_solde_principal'] ?? 0).toDouble();
      //   final nouveauSolde = ancienSolde + (_challenge!.prix ?? 0);
      //
      //   transaction.update(_firestore.collection('Users').doc(user.uid), {
      //     'votre_solde_principal': nouveauSolde,
      //   });
      //
      //   debugPrint("💰 Encaissement réussi - Ancien solde: $ancienSolde, Nouveau solde: $nouveauSolde");
      // });

      // Mettre à jour l'état local


      await _firestore.runTransaction((transaction) async {
        // 1. LIRE D'ABORD
        final challengeDocRef = _firestore.collection('Challenges').doc(_challenge!.id!);
        final userDocRef = _firestore.collection('Users').doc(user.uid);

        final challengeDoc = await transaction.get(challengeDocRef);
        if (!challengeDoc.exists) throw Exception('Challenge non trouvé');
        final challengeData = challengeDoc.data()!;
        final prixDejaEncaisser = challengeData['prix_deja_encaisser'] ?? false;
        final userGagnantId = challengeData['user_gagnant_id'];

        if (prixDejaEncaisser) throw Exception('Le prix a déjà été encaissé');
        if (userGagnantId != user.uid) throw Exception('Vous n\'êtes pas le gagnant');

        final userDoc = await transaction.get(userDocRef);
        if (!userDoc.exists) throw Exception('Utilisateur non trouvé');

        final ancienSolde = (userDoc.data()!['votre_solde_principal'] ?? 0).toDouble();
        final nouveauSolde = ancienSolde + (_challenge!.prix ?? 0);

        final now = DateTime.now().microsecondsSinceEpoch;

        // 2. ENSUITE ÉCRIRE
        transaction.update(challengeDocRef, {
          'prix_deja_encaisser': true,
          'date_encaissement': now,
          'updated_at': now,
        });

        final paiementRef = _firestore.collection('ChallengePaiements').doc();
        transaction.set(paiementRef, {
          'id': paiementRef.id,
          'challenge_id': _challenge!.id,
          'user_id': user.uid,
          'post_id': _postGagnant!.id,
          'montant': _challenge!.prix,
          'statut': 'paye',
          'created_at': now,
          'updated_at': now,
        });

        final transactionRef = _firestore.collection('TransactionSoldes').doc();
        transaction.set(transactionRef, {
          'id': transactionRef.id,
          'user_id': user.uid,
          'montant': _challenge!.prix,
          'type': TypeTransaction.GAIN.name,
          'description': 'Gain challenge: ${_challenge!.titre}',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'statut': StatutTransaction.VALIDER.name,
        });

        transaction.update(userDocRef, {
          'votre_solde_principal': nouveauSolde,
        });

        debugPrint("💰 Encaissement réussi - Ancien solde: $ancienSolde, Nouveau solde: $nouveauSolde");
      });

      if (mounted) {
        Navigator.pop(context); // Fermer le dialog de chargement
        setState(() {
          _prixDejaEncaisser = true;
          _challenge!.prixDejaEncaisser = true;
          _challenge!.dateEncaissement = DateTime.now().microsecondsSinceEpoch;
        });

        _showSuccess('FÉLICITATIONS !\nVotre gain de ${_challenge!.prix ?? 0} FCFA a été crédité sur votre compte.');
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError('Erreur lors de l\'encaissement: $e');
      }
      debugPrint('❌ Erreur transaction encaissement: $e');
    }
  }

  Future<void> _loadParticipants() async {
    try {
      if (_challenge?.usersInscritsIds?.isNotEmpty ?? false) {
        final usersSnapshot = await _firestore
            .collection('Users')
            .where(FieldPath.documentId, whereIn: _challenge!.usersInscritsIds!)
        .limit(4)
        
            .get();

        setState(() {
          _participants = usersSnapshot.docs
              .map((doc) => UserData.fromJson(doc.data()))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement participants: $e');
    }
  }

  Future<void> _loadPosts() async {
    try {
      final postsSnapshot = await _firestore
          .collection('Posts')
          .where('challenge_id', isEqualTo: widget.challengeId)
          .orderBy('votes_challenge', descending: true)
      .limit(4)
          .get();

      List<Post> posts = postsSnapshot.docs.map((doc) {
        final post = Post.fromJson(doc.data())..id = doc.id;
        return post;
      }).toList();

      // Charger les données utilisateur pour chaque post
      for (var post in posts) {
        if (post.user_id != null) {
          final userDoc = await _firestore.collection('Users').doc(post.user_id).get();
          if (userDoc.exists) {
            post.user = UserData.fromJson(userDoc.data()!);
          }
        }
      }

      setState(() {
        _posts = posts;
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement posts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    authProvider = Provider.of<UserAuthProvider>(context);

    if (_loading) {
      return _buildLoadingScreen();
    }

    if (_challenge == null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          _challenge!.titre ?? 'Détails du Challenge',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadChallenge,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Section gagnant (si challenge terminé)
          if (_challenge!.isTermine && _postGagnant != null)
            _buildGagnantSection(),

          // Section d'action principale
          _buildMainActionSection(),

          // Navigation par onglets
          _buildTabNavigation(),

          // Contenu des onglets
          Expanded(
            child: _buildCurrentTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildGagnantSection() {
    final user = _auth.currentUser;
    final estGagnant = user != null && _postGagnant?.user_id == user.uid;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: estGagnant ?
          [Colors.yellow.shade800, Colors.yellow.shade600] :
          [Colors.purple.shade800, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.yellow.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, size: 32, color: estGagnant ? Colors.black : Colors.white),
              SizedBox(width: 10),
              SizedBox(
                width: 250, // tu ajustes selon ton design
                child: Text(
                  estGagnant
                      ? 'FÉLICITATIONS ! VOUS AVEZ GAGNÉ !'
                      : 'CHALLENGE TERMINÉ - VOICI LE GAGNANT',
                  style: TextStyle(
                    color: estGagnant ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  maxLines: 2, // max 2 lignes
                  overflow: TextOverflow.visible,
                ),
              )
            ],
          ),
          SizedBox(height: 12),
          Text(
            estGagnant
                ? 'Vous avez remporté ${_challenge!.prix ?? 0} FCFA avec votre publication !'
                : 'Félicitations à ${_postGagnant?.user?.pseudo ?? 'le gagnant'} pour sa victoire !',
            style: TextStyle(
              color: estGagnant ? Colors.black87 : Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),

          if (estGagnant) ...[
            if (!_prixDejaEncaisser) ...[
              ElevatedButton(
                onPressed: _encaisserPrix,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.yellow,
                  minimumSize: Size(200, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attach_money, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'ENCASSER ${_challenge!.prix ?? 0} FCFA',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Cliquez pour recevoir votre gain',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'PRIX DÉJÀ ENCAISSÉ',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: _postGagnant?.user?.imageUrl != null
                        ? NetworkImage(_postGagnant!.user!.imageUrl!)
                        : null,
                    backgroundColor: Colors.white,
                    child: _postGagnant?.user?.imageUrl == null
                        ? Icon(Icons.person, color: Colors.purple)
                        : null,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _postGagnant?.user?.pseudo ?? 'Gagnant',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_postGagnant?.votesChallenge ?? 0} votes - ${_challenge!.prix ?? 0} FCFA gagnés',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _encaisserPrix2() async {
    final user = _auth.currentUser;
    if (user == null || _postGagnant == null || _challenge == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Encaissement du prix', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.yellow),
              SizedBox(height: 20),
              Text(
                'Traitement de votre gain de ${_challenge!.prix ?? 0} FCFA...',
                style: TextStyle(color: Colors.grey[300]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // Enregistrer le paiement
      await _firestore.collection('ChallengePaiements').add({
        'challenge_id': _challenge!.id,
        'user_id': user.uid,
        'post_id': _postGagnant!.id,
        'montant': _challenge!.prix,
        'statut': 'paye',
        'created_at': DateTime.now().microsecondsSinceEpoch,
        'updated_at': DateTime.now().microsecondsSinceEpoch,
      });
      await _firestore.collection('TransactionSoldes').add({
        'user_id': user.uid,
        'montant': _challenge!.prix,
        'type': TypeTransaction.GAIN.name,
        'description': 'Gain challenge: ${_challenge!.titre}',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'statut': StatutTransaction.VALIDER.name,
      });
      // Créditer l'utilisateur
      await _firestore.collection('Users').doc(user.uid).update({
        'votre_solde_principal': FieldValue.increment(_challenge!.prix ?? 0)
      });


      if (mounted) {
        Navigator.pop(context); // Fermer le dialog de chargement
        setState(() {
          _prixDejaEncaisser = true;
        });

        _showSuccess('FÉLICITATIONS !\nVotre gain de ${_challenge!.prix ?? 0} FCFA a été crédité sur votre compte.');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError('Erreur lors de l\'encaissement: $e');
      }
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Chargement...', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green)),
            SizedBox(height: 20),
            Text('Chargement du challenge...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Erreur', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.yellow),
            SizedBox(height: 20),
            Text(
              'Challenge non trouvé',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Ce challenge n\'existe pas ou a été supprimé',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: Text('RETOUR', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActionSection() {
    final user = _auth.currentUser;
    final isInscrit = _challenge!.isInscrit(user?.uid);
    final peutParticiper = _challenge!.peutParticiper;
    final aVote = _challenge!.aVote(user?.uid);

    // Si le challenge est terminé, on n'affiche pas les actions principales
    if (_challenge!.isTermine) {
      return SizedBox.shrink();
    }

    debugPrint("=== ÉTAT UTILISATEUR ===");
    debugPrint("Utilisateur: ${user?.uid}");
    debugPrint("Statut: ${_challenge!.statut}");
    debugPrint("Inscrit: $isInscrit");
    debugPrint("Peut participer: $peutParticiper");
    debugPrint("A voté: $aVote");
    debugPrint("Inscriptions ouvertes: ${_challenge!.inscriptionsOuvertes}");

    // Gestion selon le statut du challenge
    if (_challenge!.isEnAttente) {
      if (user == null) {
        return _buildNotConnectedMessage();
      } else if (!isInscrit && _challenge!.inscriptionsOuvertes) {
        return _buildInscriptionCallToAction();
      } else if (isInscrit) {
        return _buildAlreadyRegisteredMessage();
      } else if (!_challenge!.inscriptionsOuvertes) {
        return _buildRegistrationClosedMessage();
      }
    } else if (_challenge!.isEnCours) {
      if (user == null) {
        return _buildNotConnectedMessage();
      } else if (isInscrit && peutParticiper) {
        final aDejaPoste = _posts.any((post) => post.user_id == user.uid);
        if (aDejaPoste) {
          return _buildAlreadyPostedMessage();
        } else {
          return _buildPostParticipationCallToAction();
        }
      } else if (isInscrit && !peutParticiper) {
        return _buildParticipationClosedForUserMessage();
      } else {
        if (!aVote) {
          return _buildVoteCallToAction();
        } else {
          return _buildAlreadyVotedMessage();
        }
      }
    } else if (_challenge!.isAnnule) {
      return _buildChallengeCancelledMessage();
    }

    return SizedBox.shrink();
  }

  Widget _buildInscriptionCallToAction() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade800, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.app_registration, size: 32, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'INSCRIVEZ-VOUS MAINTENANT !',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Inscrivez-vous pour participer au challenge et tenter de gagner ${_challenge!.prix ?? 0} FCFA !',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _inscrireAuChallenge,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange,
              minimumSize: Size(250, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.app_registration, size: 24),
                SizedBox(width: 10),
                Text(
                  'S\'INSCRIRE AU CHALLENGE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          if (!_challenge!.participationGratuite!)
            Text(
              'Coût d\'inscription: ${_challenge!.prixParticipation} FCFA',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            )
          else
            Text(
              'INSCRIPTION GRATUITE',
              style: TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          SizedBox(height: 4),
          Text(
            'Période d\'inscription: ${_formatDate(_challenge!.startInscriptionAt)} - ${_formatDate(_challenge!.endInscriptionAt)}',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipationClosedForUserMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.9),
      ),
      child: Column(
        children: [
          Icon(Icons.schedule, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'CHALLENGE EN COURS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Vous êtes inscrit. La période de participation est terminée.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              setState(() { _currentTab = 2; });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
            ),
            child: Text('VOIR LES PARTICIPATIONS'),
          ),
        ],
      ),
    );
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null) return '--/--/----';
    final date = DateTime.fromMicrosecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yy').format(date);
  }

  Widget _buildNotConnectedMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.9),
      ),
      child: Column(
        children: [
          Icon(Icons.person_off, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'CONNECTEZ-VOUS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Connectez-vous pour participer ou voter',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPostParticipationCallToAction() {
    final user = _auth.currentUser;
    final aDejaPoste = _posts.any((post) => post.user_id == user?.uid);

    if (aDejaPoste) {
      return _buildAlreadyPostedMessage();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade800, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate, size: 32, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'PUBLIEZ VOTRE PARTICIPATION !',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Vous êtes inscrit. Postez maintenant votre contenu pour concourir !',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChallengePostPage(
                    challenge: _challenge,
                    isParticipation: true,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.purple,
              minimumSize: Size(250, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle, size: 24),
                SizedBox(width: 10),
                Text(
                  'PUBLIER MAINTENANT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Le challenge a débuté - Concourez pour gagner !',
            style: TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyPostedMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.9),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'PARTICIPATION PUBLIÉE !',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Votre contenu est en compétition. Bonne chance !',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              setState(() { _currentTab = 2; });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
            ),
            child: Text('VOIR MA PARTICIPATION'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyRegisteredMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 32, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'VOUS ÊTES INSCRIT !',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Préparez votre contenu. Le challenge débutera bientôt.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() { _currentTab = 1; });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                ),
                child: Text('VOIR LES PARTICIPANTS'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationClosedMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.9),
      ),
      child: Column(
        children: [
          Icon(Icons.schedule, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'INSCRIPTIONS FERMÉES',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Les inscriptions pour ce challenge sont terminées',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVoteCallToAction() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.how_to_vote, size: 32, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'VOTEZ POUR LES PARTICIPANTS !',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Vous n\'êtes pas inscrit. Soutenez les participants en votant pour votre favori !',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() { _currentTab = 2; });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.green,
              minimumSize: Size(250, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.how_to_vote, size: 24),
                SizedBox(width: 10),
                Text(
                  'VOTER MAINTENANT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          if (!_challenge!.voteGratuit!)
            Text(
              'Prix par vote: ${_challenge!.prixVote} FCFA',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            )
          else
            Text(
              'VOTE GRATUIT POUR TOUS',
              style: TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildAlreadyVotedMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.9),
      ),
      child: Column(
        children: [
          Icon(Icons.thumb_up, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'VOTE ENREGISTRÉ !',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Merci pour votre participation. Résultats bientôt disponibles.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCancelledMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.9),
      ),
      child: Column(
        children: [
          Icon(Icons.cancel, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'CHALLENGE ANNULÉ',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Ce challenge a été annulé',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _inscrireAuChallenge() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showError('CONNECTEZ-VOUS POUR VOUS INSCRIRE');
      return;
    }

    if (_challenge!.isInscrit(user.uid)) {
      _showError('VOUS ÊTES DÉJÀ INSCRIT À CE CHALLENGE');
      return;
    }

    if (!_challenge!.inscriptionsOuvertes) {
      _showError('LES INSCRIPTIONS SONT FERMÉES POUR CE CHALLENGE');
      return;
    }

    try {
      if (!_challenge!.participationGratuite!) {
        final solde = await _getSoldeUtilisateur(user.uid);
        if (solde < _challenge!.prixParticipation!) {
          _showSoldeInsuffisant(_challenge!.prixParticipation! - solde.toInt());
          return;
        }
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Confirmer l\'inscription', style: TextStyle(color: Colors.white)),
          content: Text(
            !_challenge!.participationGratuite!
                ? 'Êtes-vous sûr de vouloir vous inscrire à ce challenge ?\n\nCoût d\'inscription: ${_challenge!.prixParticipation} FCFA.'
                : 'Voulez-vous vous inscrire à ce challenge ?\n\nL\'inscription est gratuite.',
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ANNULER', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _processInscription(user.uid);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('CONFIRMER L\'INSCRIPTION', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Erreur lors de l\'inscription: $e');
    }
  }

  Future<void> _processInscription(String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final challengeRef = _firestore.collection('Challenges').doc(_challenge!.id!);
        final challengeDoc = await transaction.get(challengeRef);

        if (!challengeDoc.exists) throw Exception('Challenge non trouvé');

        final currentChallenge = Challenge.fromJson(challengeDoc.data()!);

        if (!currentChallenge.inscriptionsOuvertes || currentChallenge.isInscrit(userId)) {
          throw Exception('Inscription non autorisée');
        }

        if (!_challenge!.participationGratuite!) {
          await _debiterUtilisateur(userId, _challenge!.prixParticipation!, 'Inscription au challenge ${_challenge!.titre}');
        }

        transaction.update(challengeRef, {
          'users_inscrits_ids': FieldValue.arrayUnion([userId]),
          'total_participants': FieldValue.increment(1),
          'updated_at': DateTime.now().microsecondsSinceEpoch
        });
      });

      _showSuccess('INSCRIPTION RÉUSSIE !\nVous êtes maintenant inscrit au challenge.');

      await _loadChallenge();
      await _loadParticipants();

    } catch (e) {
      _showError('ERREUR LORS DE L\'INSCRIPTION: $e\nVeuillez réessayer.');
    }
  }

  Widget _buildTabNavigation2() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        children: [
          _buildTabItem(0, Icons.info, 'DÉTAILS'),
          _buildTabItem(1, Icons.people, 'PARTICIPANTS', _participants.length),
          _buildTabItem(2, Icons.photo_library, 'POSTS', _posts.length),
        ],
      ),
    );
  }

  Widget _buildTabItem(int tabIndex, IconData icon, String label, [int? count]) {
    final isSelected = _currentTab == tabIndex;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() { _currentTab = tabIndex; }),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected ? Colors.green : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon,
                        size: 20,
                        color: isSelected ? Colors.green : Colors.grey[400]
                    ),
                    if (count != null && count > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            count > 99 ? '99+' : count.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? Colors.green : Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_currentTab) {
      case 0: return _buildDetailsTab();
      case 1: return _buildParticipantsTab();
      case 2: return _buildPostsTab();
      default: return _buildDetailsTab();
    }
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aperçu du post du challenge
          if (_postChallenge != null)
            _buildChallengePreview(_postChallenge!),

          SizedBox(height: 20),
          _buildChallengeHeader(),
          SizedBox(height: 20),
          _buildPrizeSection(),
          SizedBox(height: 20),
          _buildChallengeStats(),
          SizedBox(height: 20),
          _buildChallengeTimeline(),
          SizedBox(height: 20),
          _buildRulesSection(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildChallengePreview(Post post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRÉSENTATION DU CHALLENGE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[900],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildPostPreviewContent(post),
          ),
        ),
        SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            if (post.id != null) {
              if (post.dataType == PostDataType.VIDEO.name) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoTikTokPage(initialPost: post),
                  ),
                );
              }else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsPost(post: post),
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 45),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility, size: 20),
              SizedBox(width: 8),
              Text('VOIR LES DÉTAILS DU POST'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostPreviewContent(Post post) {
    final hasImages = post.images != null && post.images!.isNotEmpty;
    final hasVideo = post.url_media != null && post.url_media!.isNotEmpty;

    if (hasImages) {
      return Stack(
        children: [
          CachedNetworkImage(
            imageUrl: post.images!.first,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (context, url) => Container(
              color: Colors.grey[800],
              child: Center(child: CircularProgressIndicator(color: Colors.green)),
            ),
            errorWidget: (context, url, error) => _buildDefaultPreview(),
          ),
          _buildMediaOverlay('IMAGE'),
        ],
      );
    } else if (hasVideo) {
      return FutureBuilder<Uint8List?>(
        future: _generateThumbnail(post.url_media!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: Colors.grey[800],
              child: Center(child: CircularProgressIndicator(color: Colors.green)),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Stack(
              children: [
                Container(
                  color: Colors.grey[800],
                  child: Center(
                    child: Icon(Icons.videocam, color: Colors.grey, size: 40),
                  ),
                ),
                _buildMediaOverlay('VIDÉO'),
              ],
            );
          }

          return Stack(
            children: [
              Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
              _buildMediaOverlay('VIDÉO'),
            ],
          );
        },
      );
    } else {
      return _buildDefaultPreview();
    }
  }

  Future<Uint8List?> _generateThumbnail(String videoUrl) async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
      );
      return uint8list;
    } catch (e) {
      debugPrint("Erreur génération thumbnail: $e");
      return null;
    }
  }

  Widget _buildMediaOverlay(String type) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          type,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultPreview() {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, color: Colors.grey, size: 40),
            SizedBox(height: 8),
            Text(
              'Challenge',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStatusColor()),
                ),
                child: Text(
                  _getStatusText(_challenge!.statut!),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Spacer(),
              if (_challenge!.participationGratuite!)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.yellow),
                  ),
                  child: Text(
                    'GRATUIT',
                    style: TextStyle(color: Colors.yellow, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            _challenge!.titre ?? 'Sans titre',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          if (_challenge!.description != null)
            Text(
              _challenge!.description!,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 16,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrizeSection() {
    return Card(
      color: Colors.grey[900],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.yellow, size: 24),
                SizedBox(width: 12),
                Text(
                  'PRIX À GAGNER',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.yellow.shade800, Colors.yellow.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.yellow.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '${_challenge!.prix ?? 0} FCFA',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  if (_challenge!.descriptionCadeaux != null)
                    Text(
                      _challenge!.descriptionCadeaux!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  if (_challenge!.typeCadeaux != null) ...[
                    SizedBox(height: 8),
                    Text(
                      'Type: ${_challenge!.typeCadeaux!}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeStats() {
    return Card(
      color: Colors.grey[900],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STATISTIQUES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisSpacing: 2,
              mainAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(Icons.people_alt, 'Participants', '${_challenge!.usersInscritsIds!.length
                    ?? 0}', Colors.green),
                _buildStatCard(Icons.how_to_vote, 'Votes totaux', '${_challenge!.totalVotes ?? 0}', Colors.blue),
                _buildStatCard(Icons.post_add, 'Publications', '${_posts.length}', Colors.orange),
                _buildStatCard(Icons.visibility, 'Vues', '${_challenge!.vues ?? 0}', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              SizedBox(height: 2),
              Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeTimeline() {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    final now = DateTime.now().microsecondsSinceEpoch;

    return Card(
      color: Colors.grey[900],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DÉROULEMENT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 16),
            _buildTimelineItem('Début inscriptions', _challenge!.startInscriptionAt, now),
            _buildTimelineItem('Fin inscriptions', _challenge!.endInscriptionAt, now),
            _buildTimelineItem('Fin du challenge', _challenge!.finishedAt, now),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(String label, int? timestamp, int now) {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    final isPassed = timestamp != null && now >= timestamp;
    final isCurrent = timestamp != null &&
        ((label.contains('Fin inscriptions') && _challenge!.isEnAttente) ||
            (label.contains('Fin du challenge') && _challenge!.isEnCours));

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.green.withOpacity(0.1) : Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? Colors.green : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isPassed ? Colors.green : (isCurrent ? Colors.green : Colors.grey),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isCurrent ? Colors.green : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (timestamp != null) ...[
                  SizedBox(height: 4),
                  Text(
                    dateFormat.format(DateTime.fromMicrosecondsSinceEpoch(timestamp)),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    isPassed ? 'Terminé' : (isCurrent ? 'En cours' : 'À venir'),
                    style: TextStyle(
                      color: isPassed ? Colors.green : (isCurrent ? Colors.yellow : Colors.grey),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesSection() {
    return Card(
      color: Colors.grey[900],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INFORMATIONS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 16),
            if (_challenge!.typeContenu != null)
              _buildInfoItem('Type de contenu', _challenge!.typeContenu!),
            _buildInfoItem(
                'Participation',
                _challenge!.participationGratuite!
                    ? 'GRATUITE'
                    : '${_challenge!.prixParticipation} FCFA'
            ),
            _buildInfoItem(
                'Vote',
                _challenge!.voteGratuit!
                    ? 'GRATUIT'
                    : '${_challenge!.prixVote} FCFA par vote'
            ),
            if (_challenge!.countryData != null)
              _buildInfoItem('Pays', _challenge!.countryData!['name'] ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.green),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: Colors.grey[300]),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: value.contains('GRATUIT') ? Colors.green : Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsTab2() {
    return _participants.isEmpty
        ? _buildEmptyState(
        Icons.people_outline,
        'Aucun participant',
        'Soyez le premier à participer à ce challenge !'
    )
        : ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final participant = _participants[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 22,
              backgroundImage: participant.imageUrl != null
                  ? NetworkImage(participant.imageUrl!)
                  : null,
              backgroundColor: Colors.grey[800],
              child: participant.imageUrl == null
                  ? Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
            title: Text(
              "@${participant.pseudo ?? 'Utilisateur'}",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Text(
                'INSCRIT',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }


// Dans la section _buildTabNavigation(), remplacez le widget existant par :
  Widget _buildTabNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        children: [
          _buildTabItem(0, Icons.info, 'DÉTAILS'),
          _buildTabItemWithModal(1, Icons.people, 'PARTICIPANTS', _participants.length),
          _buildTabItemWithModal(2, Icons.photo_library, 'POSTS', _posts.length),
        ],
      ),
    );
  }

// Nouvelle méthode pour les onglets avec modal
  Widget _buildTabItemWithModal(int tabIndex, IconData icon, String label, [int? count]) {
    final isSelected = _currentTab == tabIndex;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() { _currentTab = tabIndex; }),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected ? Colors.green : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon,
                        size: 20,
                        color: isSelected ? Colors.green : Colors.grey[400]
                    ),
                    if (count != null && count > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            count > 99 ? '99+' : count.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? Colors.green : Colors.grey[400],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (count != null && count > 5)
                      GestureDetector(
                        onTap: () {
                          if (tabIndex == 1) {
                            _showAllParticipantsModal();
                          } else if (tabIndex == 2) {
                            _showAllPostsModal();
                          }
                        },
                        child: Container(
                          margin: EdgeInsets.only(left: 4),
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green, width: 1),
                          ),
                          child: Text(
                            'Voir tout',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Méthode pour afficher le modal de tous les participants
  void _showAllParticipantsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header du modal
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.people, color: Colors.green, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'TOUS LES PARTICIPANTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildAllParticipantsContent(),
            ),
          ],
        ),
      ),
    );
  }

// Méthode pour afficher le modal de tous les posts
  void _showAllPostsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header du modal
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.photo_library, color: Colors.green, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'TOUTES LES PUBLICATIONS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildAllPostsContent(),
            ),
          ],
        ),
      ),
    );
  }

// Contenu du modal participants
  Widget _buildAllParticipantsContent() {
    // Charger tous les participants (méthode à implémenter)
    return FutureBuilder<List<UserData>>(
      future: _loadAllParticipants(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyModalState(
              Icons.people_outline,
              'Aucun participant',
              'Aucun utilisateur ne participe à ce challenge pour le moment.'
          );
        }

        final allParticipants = snapshot.data!;

        return GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // 3 colonnes pour une belle grille
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8, // ratio pour les cartes utilisateur
          ),
          itemCount: allParticipants.length,
          itemBuilder: (context, index) {
            return _buildParticipantGridItem(allParticipants[index]);
          },
        );
      },
    );
  }

// Contenu du modal posts
  Widget _buildAllPostsContent() {
    // Charger tous les posts (méthode à implémenter)
    return FutureBuilder<List<Post>>(
      future: _loadAllPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyModalState(
              Icons.photo_library,
              'Aucune publication',
              'Aucune publication pour ce challenge pour le moment.'
          );
        }

        final allPosts = snapshot.data!;

        return GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 colonnes pour les posts
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: allPosts.length,
          itemBuilder: (context, index) {
            return _buildPostGridItem(allPosts[index], index);
          },
        );
      },
    );
  }

// Widget pour un participant dans la grille du modal
  Widget _buildParticipantGridItem(UserData participant) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[800],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundImage: participant.imageUrl != null
                  ? NetworkImage(participant.imageUrl!)
                  : null,
              backgroundColor: Colors.grey[700],
              child: participant.imageUrl == null
                  ? Icon(Icons.person, color: Colors.white, size: 24)
                  : null,
            ),
          ),
          SizedBox(height: 8),
          // Pseudo
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              participant.pseudo ?? 'Utilisateur',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 4),
          // Badge participant
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green),
            ),
            child: Text(
              'PARTICIPANT',
              style: TextStyle(
                color: Colors.green,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

// État vide pour les modals
  Widget _buildEmptyModalState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[600]),
            SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

// Méthodes pour charger toutes les données (à ajouter à votre classe)
  Future<List<UserData>> _loadAllParticipants() async {
    try {
      if (_challenge?.usersInscritsIds?.isNotEmpty ?? false) {
        final usersSnapshot = await _firestore
            .collection('Users')
            .where(FieldPath.documentId, whereIn: _challenge!.usersInscritsIds!)
            .get();

        return usersSnapshot.docs
            .map((doc) => UserData.fromJson(doc.data()))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Erreur chargement tous les participants: $e');
      return [];
    }
  }

  Future<List<Post>> _loadAllPosts() async {
    try {
      final postsSnapshot = await _firestore
          .collection('Posts')
          .where('challenge_id', isEqualTo: widget.challengeId)
          .orderBy('votes_challenge', descending: true)
          .get();

      List<Post> posts = postsSnapshot.docs.map((doc) {
        final post = Post.fromJson(doc.data())..id = doc.id;
        return post;
      }).toList();

      // Charger les données utilisateur pour chaque post
      for (var post in posts) {
        if (post.user_id != null) {
          final userDoc = await _firestore.collection('Users').doc(post.user_id).get();
          if (userDoc.exists) {
            post.user = UserData.fromJson(userDoc.data()!);
          }
        }
      }

      return posts;
    } catch (e) {
      debugPrint('❌ Erreur chargement tous les posts: $e');
      return [];
    }
  }

// Dans vos méthodes _buildParticipantsTab() et _buildPostsTab(), limitez à 5 éléments
  Widget _buildParticipantsTab() {
    final displayedParticipants = _participants.take(4).toList();

    return displayedParticipants.isEmpty
        ? _buildEmptyState(
        Icons.people_outline,
        'Aucun participant',
        'Soyez le premier à participer à ce challenge !'
    )
        : Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: displayedParticipants.length,
            itemBuilder: (context, index) {
              final participant = displayedParticipants[index];
              return _buildParticipantListItem(participant);
            },
          ),
        ),
        // if (_participants.length > 5)
          Container(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _showAllParticipantsModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility, size: 20),
                  SizedBox(width: 8),
                  Text('VOIR TOUS LES PARTICIPANTS (${_participants.length})'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Ajoutez cette fonction dans votre classe _ChallengeDetailPageState
  Widget _buildParticipantListItem(UserData participant) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: CircleAvatar(
            radius: 20,
            backgroundImage: participant.imageUrl != null
                ? NetworkImage(participant.imageUrl!)
                : null,
            backgroundColor: Colors.grey[800],
            child: participant.imageUrl == null
                ? Icon(Icons.person, color: Colors.white, size: 18)
                : null,
          ),
        ),
        title: Text(
          "@${participant.pseudo ?? 'Utilisateur'}",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: participant.email != null
            ? Text(
          participant.email!,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        )
            : null,
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green),
          ),
          child: Text(
            'INSCRIT',
            style: TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostsTab() {
    final user = _auth.currentUser;
    final aVote = _challenge!.aVote(user?.uid);
    final displayedPosts = _posts.take(5).toList();

    if (displayedPosts.isEmpty) {
      return _buildEmptyState(
        _challenge!.isEnCours ? Icons.photo_library : Icons.schedule,
        _challenge!.isEnCours
            ? 'Aucune publication'
            : 'En attente du début du challenge',
        _challenge!.isEnCours
            ? 'Les participants publieront bientôt leurs contenus'
            : 'Revenez quand le challenge aura débuté',
      );
    }

    return Column(
      children: [
        if (_challenge!.isEnCours && !aVote && user != null)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: Colors.green)),
            ),
            child: Row(
              children: [
                Icon(Icons.how_to_vote, color: Colors.green),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Votez pour votre participant préféré !',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: displayedPosts.length,
            itemBuilder: (context, index) {
              return _buildPostGridItem(displayedPosts[index], index);
            },
          ),
        ),
        // if (_posts.length > 5)
          Container(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _showAllPostsModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library, size: 20),
                  SizedBox(width: 8),
                  Text('VOIR TOUTES LES PUBLICATIONS (${_posts.length})'),
                ],
              ),
            ),
          ),
      ],
    );
  }
  Widget _buildPostGridItem(Post post, int index) {
    final estGagnant = _challenge!.postsWinnerIds?.contains(post.id) ?? false;

    return GestureDetector(
      onTap: () {
        if (post.dataType == 'VIDEO') {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => VideoTikTokPage(initialPost: post)));
        } else {
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => DetailsPost(post: post)));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Image en arrière-plan qui occupe tout l'espace
              Container(
                height: double.infinity,
                width: double.infinity,
                child: (post.dataType == 'VIDEO' && post.url_media != null)
                    ? _buildVideoPreview(post)
                    : (post.images != null && post.images!.isNotEmpty)
                    ? _buildImagePreview(post)
                    : _buildDefaultPreview2(post),
              ),

              // Overlay sombre pour améliorer la lisibilité du texte
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),

              // Badge gagnant
              if (estGagnant)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, size: 16, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          "Gagnant",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Contenu texte superposé en bas
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom utilisateur avec ombre
                      Text(
                        post.user?.pseudo ?? "Utilisateur",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.8),
                              blurRadius: 4,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: 4),

                      // Description avec ombre
                      if (post.description != null && post.description!.isNotEmpty)
                        Text(
                          post.description!,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.8),
                                blurRadius: 4,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      SizedBox(height: 8),

                      // Stats en bas
                      Row(
                        children: [
                          // Votes
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.how_to_vote, size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  "${post.votesChallenge ?? 0}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 8),

                          // Commentaires
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.comment, size: 14, color: Colors.yellow),
                                SizedBox(width: 4),
                                Text(
                                  "${post.comments ?? 0}",
                                  style: TextStyle(
                                    color: Colors.white,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildPostItem(Post post, int index) {
    final user = _auth.currentUser;
    final aVotePourCePost = post.aVote(user?.uid ?? '');
    final peutVoter = _challenge!.isEnCours &&
        !_challenge!.aVote(user?.uid);
    final estGagnant = _challenge!.postsWinnerIds?.contains(post.id) ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header du post
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Position
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getRankColor(index),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundImage: post.user?.imageUrl != null
                      ? NetworkImage(post.user!.imageUrl!)
                      : null,
                  backgroundColor: Colors.grey[700],
                  child: post.user?.imageUrl == null
                      ? Icon(Icons.person, color: Colors.white, size: 16)
                      : null,
                ),
                SizedBox(width: 12),
                // Infos utilisateur
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.user?.pseudo ?? 'Utilisateur',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${post.votesChallenge ?? 0} votes',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badges
                if (estGagnant) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, size: 12, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          'GAGNANT',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                // Bouton vote
                if (_challenge!.isEnCours && peutVoter)
                  ElevatedButton(
                    onPressed: () => _voterPourPost(post),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: aVotePourCePost ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      minimumSize: Size(0, 0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            aVotePourCePost ? Icons.check : Icons.how_to_vote,
                            size: 14
                        ),
                        SizedBox(width: 4),
                        Text(
                          aVotePourCePost ? 'VOTÉ' : 'VOTER',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Contenu du post
          InkWell(
            onTap: () {
              if (post.id != null) {

    if (post.dataType == PostDataType.VIDEO.name) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoTikTokPage(initialPost: post),
        ),
      );
    }else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailsPost(post: post),
        ),
      );
    }

              }
            },
            child: Column(
              children: [
                // Aperçu média
                if (post.dataType == 'VIDEO' && post.url_media != null)
                  _buildVideoPreview(post)
                else if (post.images != null && post.images!.isNotEmpty)
                  _buildImagePreview(post)
                else
                  _buildDefaultPreview2(post),

                // Description
                if (post.description != null && post.description!.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      post.description!,
                      style: TextStyle(color: Colors.grey[300], fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // Actions
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.how_to_vote, size: 16, color: Colors.blue),
                      SizedBox(width: 6),
                      Text('${post.votesChallenge ?? 0}', style: TextStyle(color: Colors.white)),
                      SizedBox(width: 16),
                      Icon(Icons.comment, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Text('${post.comments ?? 0}', style: TextStyle(color: Colors.white)),
                      Spacer(),
                      Text(
                        'Voir le post →',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview(Post post) {
    return FutureBuilder<Uint8List?>(
      future: _generateThumbnail(post.url_media!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'Chargement...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          // Fallback si la génération du thumbnail échoue
          return _buildVideoPreviewFallback();
        }

        // Afficher le thumbnail généré
        return Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black,
            image: DecorationImage(
              image: MemoryImage(snapshot.data!),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              // Overlay sombre pour mieux voir l'icône play
              Container(
                color: Colors.black.withOpacity(0.3),
              ),
              // Icône play au centre
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              // Badge vidéo en haut à droite
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_outline, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'VIDÉO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Indication de clic
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Text(
                  'Cliquez pour regarder la vidéo',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoPreviewFallback() {
    return Container(
      width: double.infinity,
      height: 200,
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_filled, size: 50, color: Colors.white.withOpacity(0.7)),
                SizedBox(height: 8),
                Text(
                  'VIDÉO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Cliquez pour regarder',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text('VIDÉO', style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildImagePreview(Post post) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(post.images!.first),
          fit: BoxFit.cover,
        ),
      ),
      // child: Container(
      //   decoration: BoxDecoration(
      //     color: Colors.black.withOpacity(0.3),
      //   ),
      //   child: Center(
      //     child: Column(
      //       mainAxisAlignment: MainAxisAlignment.center,
      //       children: [
      //         Icon(Icons.photo, size: 40, color: Colors.white.withOpacity(0.8)),
      //         SizedBox(height: 8),
      //         Text(
      //           'IMAGE',
      //           style: TextStyle(
      //             color: Colors.white,
      //             fontWeight: FontWeight.bold,
      //             fontSize: 16,
      //           ),
      //         ),
      //         SizedBox(height: 4),
      //         Text(
      //           'Cliquez pour voir',
      //           style: TextStyle(color: Colors.white70, fontSize: 12),
      //         ),
      //       ],
      //     ),
      //   ),
      // ),
    );
  }

  Widget _buildDefaultPreview2(Post post) {
    return Container(
      width: double.infinity,
      height: 120,
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'PUBLICATION',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Cliquez pour voir les détails',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[600]),
            SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _voterPourPost(Post post) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showError('CONNECTEZ-VOUS POUR POUVOIR VOTER\nVotre vote compte pour élire le gagnant !');
      return;
    }

    if (_challenge!.aVote(user.uid)) {
      _showError('VOUS AVEZ DÉJÀ VOTÉ DANS CE CHALLENGE\nMerci pour votre participation !');
      return;
    }

    try {
      if (!_challenge!.voteGratuit!) {
        final solde = await _getSoldeUtilisateur(user.uid);
        if (solde < _challenge!.prixVote!) {
          _showSoldeInsuffisant(_challenge!.prixVote! - solde.toInt());
          return;
        }
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Confirmer votre vote', style: TextStyle(color: Colors.white)),
          content: Text(
            !_challenge!.voteGratuit!
                ? 'Êtes-vous sûr de vouloir voter pour ce participant ?\n\nCe vote vous coûtera ${_challenge!.prixVote} FCFA.'
                : 'Voulez-vous vraiment voter pour ce participant ?\n\nVotre vote est gratuit et ne peut être changé.',
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ANNULER', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _processVote(post, user.uid);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('CONFIRMER MON VOTE', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Erreur lors de la préparation du vote: $e');
    }
  }

  Future<void> _processVote(Post post, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final challengeRef = _firestore.collection('Challenges').doc(_challenge!.id!);
        final challengeDoc = await transaction.get(challengeRef);

        if (!challengeDoc.exists) throw Exception('Challenge non trouvé');

        final currentChallenge = Challenge.fromJson(challengeDoc.data()!);
        if (!currentChallenge.isEnCours || currentChallenge.aVote(userId)) {
          throw Exception('Vote non autorisé');
        }

        final postRef = _firestore.collection('Posts').doc(post.id!);
        final postDoc = await transaction.get(postRef);

        if (!postDoc.exists) throw Exception('Post non trouvé');

        if (!_challenge!.voteGratuit!) {
          await _debiterUtilisateur(userId, _challenge!.prixVote!, 'Vote pour le challenge ${_challenge!.titre}');
        }

        transaction.update(postRef, {
          'votes_challenge': FieldValue.increment(1),
          'users_votes_ids': FieldValue.arrayUnion([userId])
        });

        transaction.update(challengeRef, {
          'users_votants_ids': FieldValue.arrayUnion([userId]),
          'total_votes': FieldValue.increment(1),
          'updated_at': DateTime.now().microsecondsSinceEpoch
        });
      });

      _showSuccess('VOTE ENREGISTRÉ !\nMerci d\'avoir participé à l\'élection du gagnant.');
      await _loadPosts();
      _envoyerNotificationVote(userVotant:  authProvider.loginUserData!, userVote:post!.user!);

    } catch (e) {
      _showError('ERREUR LORS DU VOTE: $e\nVeuillez réessayer.');
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
  // Méthodes utilitaires
  Color _getStatusColor() {
    switch (_challenge!.statut) {
      case 'en_attente': return Colors.orange;
      case 'en_cours': return Colors.green;
      case 'termine': return Colors.blue;
      case 'annule': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.yellow;
    if (index == 1) return Colors.grey[400]!;
    if (index == 2) return Colors.orange.shade300;
    return Colors.grey[700]!;
  }

  String _getStatusText(String statut) {
    switch (statut) {
      case 'en_attente': return 'INSCRIPTIONS OUVERTES';
      case 'en_cours': return 'VOTE EN COURS';
      case 'termine': return 'CHALLENGE TERMINÉ';
      case 'annule': return 'CHALLENGE ANNULÉ';
      default: return statut.toUpperCase();
    }
  }

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
    await _firestore.collection('TransactionSoldes').add({
      'user_id': userId,
      'montant': montant,
      'type': TypeTransaction.DEPENSE.name,
      'description': raison,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'statut': StatutTransaction.VALIDER.name,
    });

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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
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
              'Rechargez votre compte pour soutenir votre participant préféré !',
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen(),));
              _showSuccess('Redirection vers la page de recharge...');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('RECHARGER MAINTENANT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}