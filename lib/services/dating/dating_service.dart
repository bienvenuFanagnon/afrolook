// lib/services/dating_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/dating_data.dart';
import '../../models/enums.dart';
import '../../models/model_data.dart';
import 'coin_service.dart';

class DatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CoinService _coinService = CoinService();

  // Migration initiale des profils
  // Future<void> migrateInitialProfiles() async {
  //   try {
  //     // Récupérer tous les utilisateurs dont le genre est "femme"
  //     final usersSnapshot = await _firestore
  //         .collection('users')
  //         .where('genre', isEqualTo: 'femme')
  //         .get();
  //
  //     for (var userDoc in usersSnapshot.docs) {
  //       final userData = UserData.fromJson(userDoc.data());
  //
  //       // Vérifier si un profil dating existe déjà
  //       final existingProfile = await _firestore
  //           .collection('dating_profiles')
  //           .where('userId', isEqualTo: userData.id)
  //           .limit(1)
  //           .get();
  //
  //       if (existingProfile.docs.isEmpty) {
  //         // Créer un profil dating minimal
  //         final profileId = _firestore.collection('dating_profiles').doc().id;
  //         final now = DateTime.now().millisecondsSinceEpoch;
  //
  //         final datingProfile = DatingProfile(
  //           id: profileId,
  //           userId: userData.id ?? '',
  //           pseudo: userData.pseudo ?? '',
  //           imageUrl: userData.imageUrl ?? '',
  //           photosUrls: [userData.imageUrl ?? ''],
  //           bio: userData.apropos ?? '',
  //           age: _calculateAge(userData),
  //           sexe: userData.genre ?? '',
  //           ville: userData.adresse?.split(',')[0] ?? '',
  //           pays: userData.userPays?.name ?? '',
  //           profession: null,
  //           centresInteret: [],
  //           rechercheSexe: 'homme',
  //           rechercheAgeMin: 18,
  //           rechercheAgeMax: 50,
  //           recherchePays: '',
  //           isVerified: false,
  //           isActive: true,
  //           isProfileComplete: false,
  //           completionPercentage: _calculateCompletionPercentage(userData),
  //           createdByMigration: true,
  //           likesCount: 0,
  //           coupsDeCoeurCount: 0,
  //           connexionsCount: 0,
  //           visitorsCount: 0,
  //           createdAt: now,
  //           updatedAt: now,
  //         );
  //
  //         await _firestore
  //             .collection('dating_profiles')
  //             .doc(profileId)
  //             .set(datingProfile.toJson());
  //       }
  //     }
  //   } catch (e) {
  //     print('Erreur lors de la migration: $e');
  //   }
  // }

  // lib/services/dating/dating_service.dart

  /// Met à jour le score de popularité d'un profil
  Future<void> updatePopularityScore(String userId) async {
    try {
      print('📊 Mise à jour du score de popularité pour $userId');

      // Récupérer tous les compteurs en parallèle pour optimiser
      final futures = await Future.wait([
        _getLikesCountForUser(userId),
        _getCoupsDeCoeurCountForUser(userId),
        _getConnectionsCountForUser(userId),
      ]);

      final likesCount = futures[0];
      final coupsCount = futures[1];
      final connectionsCount = futures[2];

      // Formule du score:
      // - 1 point par like
      // - 2 points par coup de cœur
      // - 3 points par connexion
      final score = (likesCount * 1) + (coupsCount * 2) + (connectionsCount * 3);

      print('📊 Nouveau score: $score (likes: $likesCount, coups: $coupsCount, connexions: $connectionsCount)');

      // Mettre à jour dans Firestore
      final profileSnapshot = await _firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (profileSnapshot.docs.isNotEmpty) {
        await profileSnapshot.docs.first.reference.update({
          'popularityScore': score,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ Score mis à jour avec succès');
      } else {
        print('⚠️ Profil non trouvé pour $userId');
      }

    } catch (e) {
      print('❌ Erreur lors de la mise à jour du score: $e');
    }
  }

  /// Récupère le nombre de likes reçus par un utilisateur
  Future<int> _getLikesCountForUser(String userId) async {
    final snapshot = await _firestore
        .collection('dating_likes')
        .where('toUserId', isEqualTo: userId)
        .count()
        .get();
    return snapshot.count!;
  }

  /// Récupère le nombre de coups de cœur reçus par un utilisateur
  Future<int> _getCoupsDeCoeurCountForUser(String userId) async {
    final snapshot = await _firestore
        .collection('dating_coup_de_coeurs')
        .where('toUserId', isEqualTo: userId)
        .count()
        .get();
    return snapshot.count!;
  }

  /// Récupère le nombre de connexions d'un utilisateur
  Future<int> _getConnectionsCountForUser(String userId) async {
    final snapshot = await _firestore
        .collection('dating_connections')
        .where('userId1', isEqualTo: userId)
        .count()
        .get();
    return snapshot.count!;
  }

  /// Met à jour le score après un like
  Future<void> onUserLiked(String likedUserId) async {
    print('❤️ Like reçu par $likedUserId - mise à jour du score');
    await updatePopularityScore(likedUserId);
  }

  /// Met à jour le score après un coup de cœur
  Future<void> onUserCoupDeCoeur(String targetUserId) async {
    print('⭐ Coup de cœur reçu par $targetUserId - mise à jour du score');
    await updatePopularityScore(targetUserId);
  }

  /// Met à jour le score après une connexion (match)
  Future<void> onUserConnected(String userId1, String userId2) async {
    print('💑 Nouvelle connexion entre $userId1 et $userId2 - mise à jour des scores');
    await Future.wait([
      updatePopularityScore(userId1),
      updatePopularityScore(userId2),
    ]);
  }

  /// Récupère les profils les plus populaires
  Future<List<DatingProfile>> getMostPopularProfiles({
    required String currentUserId,
    int limit = 20,
    String? sexeFilter,
    int minAge = 18,
    int maxAge = 99,
  }) async {
    try {
      Query query = _firestore
          .collection('dating_profiles')
          .where('isActive', isEqualTo: true)
          .where('userId', isNotEqualTo: currentUserId)
          .orderBy('popularityScore', descending: true)
          .orderBy('createdAt', descending: true);

      if (sexeFilter != null && sexeFilter != 'tous') {
        query = query.where('sexe', isEqualTo: sexeFilter);
      }

      query = query.where('age', isGreaterThanOrEqualTo: minAge)
          .where('age', isLessThanOrEqualTo: maxAge);

      final snapshot = await query.limit(limit).get();

      return snapshot.docs
          .map((doc) => DatingProfile.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

    } catch (e) {
      print('❌ Erreur récupération profils populaires: $e');
      return [];
    }
  }

  /// Récupère les profils les moins populaires (pour le recyclage)
  Future<List<DatingProfile>> getLeastPopularProfiles({
    required String currentUserId,
    int limit = 20,
    String? sexeFilter,
    int minAge = 18,
    int maxAge = 99,
  }) async {
    try {
      Query query = _firestore
          .collection('dating_profiles')
          .where('isActive', isEqualTo: true)
          .where('userId', isNotEqualTo: currentUserId)
          .orderBy('popularityScore', descending: false)
          .orderBy('createdAt', descending: true);

      if (sexeFilter != null && sexeFilter != 'tous') {
        query = query.where('sexe', isEqualTo: sexeFilter);
      }

      query = query.where('age', isGreaterThanOrEqualTo: minAge)
          .where('age', isLessThanOrEqualTo: maxAge);

      final snapshot = await query.limit(limit).get();

      return snapshot.docs
          .map((doc) => DatingProfile.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

    } catch (e) {
      print('❌ Erreur récupération profils moins populaires: $e');
      return [];
    }
  }

  /// Mélange les profils populaires et moins populaires
  Future<List<DatingProfile>> getMixedProfiles({
    required String currentUserId,
    int limit = 30,
    String? sexeFilter,
    int minAge = 18,
    int maxAge = 99,
    double popularRatio = 0.6, // 60% populaires, 40% moins populaires
  }) async {
    print('🎯 Génération de profils mélangés (ratio populaires: ${(popularRatio * 100).toInt()}%)');

    final popularCount = (limit * popularRatio).toInt();
    final lessPopularCount = limit - popularCount;

    final futures = await Future.wait([
      getMostPopularProfiles(
        currentUserId: currentUserId,
        limit: popularCount,
        sexeFilter: sexeFilter,
        minAge: minAge,
        maxAge: maxAge,
      ),
      getLeastPopularProfiles(
        currentUserId: currentUserId,
        limit: lessPopularCount,
        sexeFilter: sexeFilter,
        minAge: minAge,
        maxAge: maxAge,
      ),
    ]);

    List<DatingProfile> populars = futures[0];
    List<DatingProfile> lessPopulars = futures[1];

    // Mélanger chaque liste
    populars.shuffle();
    lessPopulars.shuffle();

    // Alterner: 3 populaires, 2 moins populaires
    List<DatingProfile> mixed = [];
    int popularIndex = 0, lessIndex = 0;

    while (popularIndex < populars.length || lessIndex < lessPopulars.length) {
      // Ajouter 3 populaires
      for (int i = 0; i < 3 && popularIndex < populars.length; i++) {
        mixed.add(populars[popularIndex++]);
      }
      // Ajouter 2 moins populaires
      for (int i = 0; i < 2 && lessIndex < lessPopulars.length; i++) {
        mixed.add(lessPopulars[lessIndex++]);
      }
    }

    print('📊 Mélange généré: ${mixed.length} profils');
    return mixed;
  }
  // Vérifier l'état du profil dating
  Future<DatingProfile?> checkDatingProfileStatus(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null; // Aucun profil
      }

      final profile = DatingProfile.fromJson(snapshot.docs.first.data());
      if (!profile.isProfileComplete) {
        return profile; // Profil incomplet
      }

      return profile; // Profil complet
    } catch (e) {
      print('Erreur lors de la vérification du profil: $e');
      return null;
    }
  }

  // Créer ou mettre à jour un profil dating
  Future<bool> saveDatingProfile(DatingProfile profile) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updatedProfile = profile.copyWith(
        updatedAt: now,
        isProfileComplete: _isProfileComplete(profile),
        completionPercentage: _calculateProfileCompletionPercentage(profile),
      );

      await _firestore
          .collection('dating_profiles')
          .doc(profile.id)
          .set(updatedProfile.toJson());

      return true;
    } catch (e) {
      print('Erreur lors de la sauvegarde du profil: $e');
      return false;
    }
  }

  // Liker un profil
  Future<bool> likeProfile(String fromUserId, String toUserId) async {
    try {
      // Vérifier si le like existe déjà
      final existingLike = await _firestore
          .collection('dating_likes')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .limit(1)
          .get();

      if (existingLike.docs.isNotEmpty) {
        return true; // Like déjà existant
      }

      return await _firestore.runTransaction((transaction) async {
        // Créer le like
        final likeId = _firestore.collection('dating_likes').doc().id;
        final now = DateTime.now().millisecondsSinceEpoch;
        final like = DatingLike(
          id: likeId,
          fromUserId: fromUserId,
          toUserId: toUserId,
          createdAt: now,
        );
        transaction.set(
          _firestore.collection('dating_likes').doc(likeId),
          like.toJson(),
        );

        // Incrémenter le compteur de likes du profil cible
        final targetProfileQuery = await _firestore
            .collection('dating_profiles')
            .where('userId', isEqualTo: toUserId)
            .limit(1)
            .get();

        if (targetProfileQuery.docs.isNotEmpty) {
          transaction.update(
            targetProfileQuery.docs.first.reference,
            {'likesCount': FieldValue.increment(1)},
          );
        }

        // Vérifier si c'est un match (l'autre utilisateur a aussi liké)
        final mutualLike = await _firestore
            .collection('dating_likes')
            .where('fromUserId', isEqualTo: toUserId)
            .where('toUserId', isEqualTo: fromUserId)
            .limit(1)
            .get();

        if (mutualLike.docs.isNotEmpty) {
          // Créer une connexion (match)
          await _createConnection(fromUserId, toUserId);
        }

        return true;
      });
    } catch (e) {
      print('Erreur lors du like: $e');
      return false;
    }
  }

  // Créer une connexion (match)
  Future<bool> _createConnection(String userId1, String userId2) async {
    try {
      // Vérifier si la connexion existe déjà
      final existingConnection = await _firestore
          .collection('dating_connections')
          .where('userId1', isEqualTo: userId1)
          .where('userId2', isEqualTo: userId2)
          .limit(1)
          .get();

      if (existingConnection.docs.isNotEmpty) {
        return true;
      }

      final connectionId = _firestore.collection('dating_connections').doc().id;
      final now = DateTime.now().millisecondsSinceEpoch;
      final connection = DatingConnection(
        id: connectionId,
        userId1: userId1,
        userId2: userId2,
        createdAt: now,
        isActive: true,
      );

      await _firestore
          .collection('dating_connections')
          .doc(connectionId)
          .set(connection.toJson());

      // Incrémenter le compteur de connexions des deux profils
      await _incrementConnectionCount(userId1);
      await _incrementConnectionCount(userId2);

      // Créer la conversation
      await _createConversation(connectionId, userId1, userId2);

      return true;
    } catch (e) {
      print('Erreur lors de la création de la connexion: $e');
      return false;
    }
  }

  // Créer une conversation
  Future<bool> _createConversation(String connectionId, String userId1, String userId2) async {
    try {
      final conversationId = _firestore.collection('dating_conversations').doc().id;
      final now = DateTime.now().millisecondsSinceEpoch;
      final conversation = DatingConversation(
        id: conversationId,
        connectionId: connectionId,
        userId1: userId1,
        userId2: userId2,
        unreadCountUser1: 0,
        unreadCountUser2: 0,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection('dating_conversations')
          .doc(conversationId)
          .set(conversation.toJson());

      return true;
    } catch (e) {
      print('Erreur lors de la création de la conversation: $e');
      return false;
    }
  }

  // Envoyer un message
  Future<bool> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required MessageType type,
    String? text,
    String? mediaUrl,
    String? replyToMessageId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final now = DateTime.now().millisecondsSinceEpoch;

        // Créer le message
        final messageId = _firestore.collection('dating_messages').doc().id;
        final message = DatingMessage(
          id: messageId,
          conversationId: conversationId,
          senderUserId: senderId,
          receiverUserId: receiverId,
          type: type,
          text: text,
          mediaUrl: mediaUrl,
          replyToMessageId: replyToMessageId,
          isRead: false,
          createdAt: now,
          updatedAt: now,
        );
        transaction.set(
          _firestore.collection('dating_messages').doc(messageId),
          message.toJson(),
        );

        // Mettre à jour la conversation
        final conversationRef = _firestore.collection('dating_conversations').doc(conversationId);
        final conversationDoc = await transaction.get(conversationRef);
        final conversation = DatingConversation.fromJson(conversationDoc.data() ?? {});

        final unreadCount = senderId == conversation.userId1
            ? conversation.unreadCountUser2 + 1
            : conversation.unreadCountUser1 + 1;

        transaction.update(conversationRef, {
          'lastMessage': text ?? mediaUrl ?? '',
          'lastMessageType': type.value,
          'lastMessageSenderId': senderId,
          'lastMessageAt': now,
          if (senderId == conversation.userId1)
            'unreadCountUser2': unreadCount
          else
            'unreadCountUser1': unreadCount,
          'updatedAt': now,
        });

        // Mettre à jour la connexion
        final connectionRef = _firestore.collection('dating_connections').doc(conversation.connectionId);
        transaction.update(connectionRef, {
          'lastMessageAt': now,
        });

        return true;
      });
    } catch (e) {
      print('Erreur lors de l\'envoi du message: $e');
      return false;
    }
  }

  // Obtenir les profils recommandés
  Stream<List<DatingProfile>> getRecommendedProfiles(String currentUserId) {
    return _firestore
        .collection('dating_profiles')
        .where('userId', isNotEqualTo: currentUserId)
        .where('isActive', isEqualTo: true)
        .where('isProfileComplete', isEqualTo: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => DatingProfile.fromJson(doc.data()))
        .toList());
  }

  // Méthodes utilitaires
  int _calculateAge(UserData userData) {
    if (userData.createdAt == null) return 0;
    final birthDate = DateTime.fromMillisecondsSinceEpoch(userData.createdAt!);
    final now = DateTime.now();
    return now.year - birthDate.year;
  }

  double _calculateCompletionPercentage(UserData userData) {
    int completedFields = 0;
    int totalFields = 6;

    if (userData.pseudo?.isNotEmpty ?? false) completedFields++;
    if (userData.imageUrl?.isNotEmpty ?? false) completedFields++;
    if (userData.apropos?.isNotEmpty ?? false) completedFields++;
    if (userData.genre?.isNotEmpty ?? false) completedFields++;
    if (userData.adresse?.isNotEmpty ?? false) completedFields++;
    if (userData.userPays != null) completedFields++;

    return (completedFields / totalFields) * 100;
  }

  bool _isProfileComplete(DatingProfile profile) {
    return profile.pseudo.isNotEmpty &&
        profile.imageUrl.isNotEmpty &&
        profile.photosUrls.isNotEmpty &&
        profile.bio.isNotEmpty &&
        profile.age > 0 &&
        profile.sexe.isNotEmpty &&
        (profile.ville.isNotEmpty || profile.pays.isNotEmpty) &&
        profile.rechercheSexe.isNotEmpty;
  }

  double _calculateProfileCompletionPercentage(DatingProfile profile) {
    int completedFields = 0;
    int totalFields = 11;

    if (profile.pseudo.isNotEmpty) completedFields++;
    if (profile.imageUrl.isNotEmpty) completedFields++;
    if (profile.photosUrls.isNotEmpty) completedFields++;
    if (profile.bio.isNotEmpty) completedFields++;
    if (profile.age > 0) completedFields++;
    if (profile.sexe.isNotEmpty) completedFields++;
    if (profile.ville.isNotEmpty) completedFields++;
    if (profile.pays.isNotEmpty) completedFields++;
    if (profile.profession?.isNotEmpty ?? false) completedFields++;
    if (profile.centresInteret.isNotEmpty) completedFields++;
    if (profile.rechercheSexe.isNotEmpty) completedFields++;

    return (completedFields / totalFields) * 100;
  }

  Future<void> _incrementConnectionCount(String userId) async {
    final profileQuery = await _firestore
        .collection('dating_profiles')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (profileQuery.docs.isNotEmpty) {
      await profileQuery.docs.first.reference.update({
        'connexionsCount': FieldValue.increment(1),
      });
    }
  }
}