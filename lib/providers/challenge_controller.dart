// challenge_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/model_data.dart';

class ChallengeController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Noms des collections
  static const String challengesCollection = 'Challenges';
  static const String postsCollection = 'Posts';
  static const String usersCollection = 'Users';

  // Variables pour les soldes
  static const String soldeUtilisateur = 'votre_solde_principal';
  static const String soldeApplication = 'solde_gain';

  // Stream pour les challenges actifs
  Stream<List<Challenge>> getChallengesActifs() {
    return _firestore
        .collection(challengesCollection)
        .where('disponible', isEqualTo: true)
        .where('isAprouved', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Challenge.fromJson(doc.data()..['id'] = doc.id))
        .toList());
  }

  // Récupérer un challenge spécifique
  Future<Challenge?> getChallenge(String challengeId) async {
    try {
      final doc = await _firestore.collection(challengesCollection).doc(challengeId).get();
      if (doc.exists) {
        return Challenge.fromJson(doc.data()!..['id'] = doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Erreur lors de la récupération du challenge: $e');
    }
  }

  // Vérifier et mettre à jour le statut des challenges
  Future<void> verifierStatutsChallenges() async {
    final now = DateTime.now().microsecondsSinceEpoch;

    try {
      final challenges = await _firestore
          .collection(challengesCollection)
          .where('statut', whereIn: ['en_attente', 'en_cours'])
          .get();

      final batch = _firestore.batch();

      for (final doc in challenges.docs) {
        final challenge = Challenge.fromJson(doc.data());
        String nouveauStatut = challenge.statut!;

        if (challenge.isEnAttente) {
          // Vérifier si on doit démarrer le challenge
          if (now >= (challenge.endInscriptionAt ?? 0)) {
            // Vérifier le nombre de participants
            final postsSnapshot = await _firestore
                .collection(postsCollection)
                .where('challenge_id', isEqualTo: challenge.id)
                .get();

            if (postsSnapshot.docs.length >= 1) {
              nouveauStatut = 'en_cours';
            } else {
              nouveauStatut = 'annule';
            }
          }
        } else if (challenge.isEnCours) {
          // Vérifier si le challenge doit se terminer
          if (now >= (challenge.finishedAt ?? 0)) {
            nouveauStatut = 'termine';
            // Déterminer le gagnant
            await _determinerGagnant(challenge.id!);
          }
        }

        if (nouveauStatut != challenge.statut) {
          batch.update(doc.reference, {
            'statut': nouveauStatut,
            'updated_at': now
          });
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Erreur lors de la vérification des statuts: $e');
    }
  }

  // Inscription à un challenge
  Future<void> inscrireAuChallenge(
      String challengeId,
      String description,
      List<String> mediaUrls,
      String typeMedia
      ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final challenge = await getChallenge(challengeId);
    if (challenge == null) throw Exception('Challenge non trouvé');

    // Vérifications
    if (!challenge.inscriptionsOuvertes) {
      throw Exception('Les inscriptions sont fermées pour ce challenge');
    }

    if (challenge.isInscrit(user.uid)) {
      throw Exception('Vous êtes déjà inscrit à ce challenge');
    }

    // Vérifier le type de contenu
    if (!_verifierTypeContenu(challenge.typeContenu, typeMedia)) {
      throw Exception('Type de média non autorisé pour ce challenge');
    }

    // Vérifier le solde si participation payante
    if (!challenge.participationGratuite!) {
      final solde = await _getSoldeUtilisateur(user.uid);
      if (solde < challenge.prixParticipation!) {
        throw Exception('Solde insuffisant');
      }
    }

    // Transaction Firebase pour garantir l'intégrité
    await _firestore.runTransaction((transaction) async {
      // Mettre à jour le challenge
      final challengeRef = _firestore.collection(challengesCollection).doc(challengeId);
      final challengeDoc = await transaction.get(challengeRef);

      if (!challengeDoc.exists) throw Exception('Challenge non trouvé');

      final currentChallenge = Challenge.fromJson(challengeDoc.data()!);
      if (!currentChallenge.inscriptionsOuvertes || currentChallenge.isInscrit(user.uid)) {
        throw Exception('Inscription non autorisée');
      }

      // Déduire le prix si participation payante
      if (!challenge.participationGratuite!) {
        await _debiterUtilisateur(
            user.uid,
            challenge.prixParticipation!,
            'Participation au challenge: ${challenge.titre}'
        );
        await _crediterApplication(challenge.prixParticipation!);
      }

      // Créer le post
      final postRef = _firestore.collection(postsCollection).doc();
      final now = DateTime.now().microsecondsSinceEpoch;

      final nouveauPost = Post(
        id: postRef.id,
        user_id: user.uid,
        challenge_id: challengeId,
        type: 'challenge',
        description: description,
        url_media: mediaUrls.isNotEmpty ? mediaUrls.first : null,
        images: mediaUrls,
        createdAt: now,
        updatedAt: now,
        status: 'active',
        dataType: typeMedia,
        votesChallenge: 0,
        usersVotesIds: [],
      );

      transaction.set(postRef, nouveauPost.toJson());

      // Mettre à jour le challenge
      transaction.update(challengeRef, {
        'users_inscrits_ids': FieldValue.arrayUnion([user.uid]),
        'posts_ids': FieldValue.arrayUnion([postRef.id]),
        'total_participants': FieldValue.increment(1),
        'updated_at': now
      });
    });
  }

  // Voter pour un post
  Future<void> voterPourPost(String challengeId, String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final challenge = await getChallenge(challengeId);
    if (challenge == null) throw Exception('Challenge non trouvé');

    // Vérifications
    if (!challenge.isEnCours) {
      throw Exception('Le vote n\'est possible que pour les challenges en cours');
    }

    if (challenge.aVote(user.uid)) {
      throw Exception('Vous avez déjà voté pour ce challenge');
    }

    // Vérifier le solde si vote payant
    if (!challenge.voteGratuit!) {
      final solde = await _getSoldeUtilisateur(user.uid);
      if (solde < challenge.prixVote!) {
        throw Exception('Solde insuffisant');
      }
    }

    await _firestore.runTransaction((transaction) async {
      // Vérifications supplémentaires
      final challengeRef = _firestore.collection(challengesCollection).doc(challengeId);
      final challengeDoc = await transaction.get(challengeRef);

      if (!challengeDoc.exists) throw Exception('Challenge non trouvé');

      final currentChallenge = Challenge.fromJson(challengeDoc.data()!);
      if (!currentChallenge.isEnCours || currentChallenge.aVote(user.uid)) {
        throw Exception('Vote non autorisé');
      }

      final postRef = _firestore.collection(postsCollection).doc(postId);
      final postDoc = await transaction.get(postRef);

      if (!postDoc.exists || postDoc.data()!['challenge_id'] != challengeId) {
        throw Exception('Post non trouvé');
      }

      // Déduire le prix si vote payant
      if (!challenge.voteGratuit!) {
        await _debiterUtilisateur(
            user.uid,
            challenge.prixVote!,
            'Vote pour le challenge: ${challenge.titre}'
        );
        await _crediterApplication(challenge.prixVote!);
      }

      // Mettre à jour le post
      transaction.update(postRef, {
        'votes_challenge': FieldValue.increment(1),
        'users_votes_ids': FieldValue.arrayUnion([user.uid])
      });

      // Mettre à jour le challenge
      transaction.update(challengeRef, {
        'users_votants_ids': FieldValue.arrayUnion([user.uid]),
        'total_votes': FieldValue.increment(1),
        'updated_at': DateTime.now().microsecondsSinceEpoch
      });
    });
  }

  // Méthodes privées
  bool _verifierTypeContenu(String? typeContenuChallenge, String typeMediaPost) {
    switch (typeContenuChallenge) {
      case 'image':
        return typeMediaPost == 'image';
      case 'video':
        return typeMediaPost == 'video';
      case 'les_deux':
        return typeMediaPost == 'image' || typeMediaPost == 'video';
      default:
        return true;
    }
  }

  Future<double> _getSoldeUtilisateur(String userId) async {
    final doc = await _firestore.collection(usersCollection).doc(userId).get();
    return (doc.data()?[soldeUtilisateur] ?? 0).toDouble();
  }

  Future<void> _debiterUtilisateur(String userId, int montant, String raison) async {
    await _firestore.collection(usersCollection).doc(userId).update({
      soldeUtilisateur: FieldValue.increment(-montant)
    });

    // Log de transaction
    await _firestore.collection('transactions').add({
      'user_id': userId,
      'type': 'debit',
      'montant': montant,
      'raison': raison,
      'created_at': DateTime.now().microsecondsSinceEpoch
    });
  }

  Future<void> _crediterApplication(int montant) async {
    final appDataRef = _firestore.collection('app_default_data').doc('solde');
    await appDataRef.set({
      soldeApplication: FieldValue.increment(montant)
    }, SetOptions(merge: true));
  }

  Future<void> _determinerGagnant(String challengeId) async {
    try {
      // Récupérer tous les posts du challenge triés par votes
      final postsSnapshot = await _firestore
          .collection(postsCollection)
          .where('challenge_id', isEqualTo: challengeId)
          .orderBy('votes_challenge', descending: true)
          .limit(1)
          .get();

      if (postsSnapshot.docs.isNotEmpty) {
        final postGagnant = postsSnapshot.docs.first;
        final challengeRef = _firestore.collection(challengesCollection).doc(challengeId);

        await challengeRef.update({
          'posts_winner_ids': FieldValue.arrayUnion([postGagnant.id]),
          'updated_at': DateTime.now().microsecondsSinceEpoch
        });
      }
    } catch (e) {
      throw Exception('Erreur lors de la détermination du gagnant: $e');
    }
  }

  // Récupérer les posts d'un challenge
  Stream<List<Post>> getPostsChallenge(String challengeId) {
    return _firestore
        .collection(postsCollection)
        .where('challenge_id', isEqualTo: challengeId)
        .orderBy('votes_challenge', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Post.fromJson(doc.data()..['id'] = doc.id))
        .toList());
  }

  // Récupérer les challenges d'un utilisateur
  Stream<List<Challenge>> getMesChallenges() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    return _firestore
        .collection(challengesCollection)
        .where('user_id', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Challenge.fromJson(doc.data()..['id'] = doc.id))
        .toList());
  }
}