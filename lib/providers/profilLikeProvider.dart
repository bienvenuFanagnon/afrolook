// providers/profile_like_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// models/profile_like_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/model_data.dart';
import 'authProvider.dart';

class ProfileLike {
  String? id;
  String likedUserId; // Utilisateur qui est liké
  String likerUserId; // Utilisateur qui like
  Timestamp createdAt;

  ProfileLike({
    this.id,
    required this.likedUserId,
    required this.likerUserId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'likedUserId': likedUserId,
      'likerUserId': likerUserId,
      'createdAt': createdAt,
    };
  }

  factory ProfileLike.fromMap(Map<String, dynamic> map, String id) {
    return ProfileLike(
      id: id,
      likedUserId: map['likedUserId'] ?? '',
      likerUserId: map['likerUserId'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }
}
class ProfileLikeProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Like un profil
  Future<void> likeProfile(String likedUserId, String likerUserId) async {
    try {
      // Vérifier si le like existe déjà
      final existingLike = await _firestore
          .collection('profile_likes')
          .where('likedUserId', isEqualTo: likedUserId)
          .where('likerUserId', isEqualTo: likerUserId)
          .get();

      if (existingLike.docs.isEmpty) {
        final like = ProfileLike(
          likedUserId: likedUserId,
          likerUserId: likerUserId,
          createdAt: Timestamp.now(),
        );

        await _firestore.collection('profile_likes').add(like.toMap());

        // Mettre à jour le compteur de likes du profil
        await _incrementProfileLikes(likedUserId);
      }
    } catch (error) {
      throw Exception('Erreur like profil: $error');
    }
  }

  // Unlike un profil
  Future<void> unlikeProfile(String likedUserId, String likerUserId) async {
    try {
      final likeQuery = await _firestore
          .collection('profile_likes')
          .where('likedUserId', isEqualTo: likedUserId)
          .where('likerUserId', isEqualTo: likerUserId)
          .get();

      for (var doc in likeQuery.docs) {
        await doc.reference.delete();
      }

      // Mettre à jour le compteur de likes du profil
      await _decrementProfileLikes(likedUserId);
    } catch (error) {
      throw Exception('Erreur unlike profil: $error');
    }
  }

  // Vérifier si l'utilisateur a déjà liké le profil
  Future<bool> hasLikedProfile(String likedUserId, String likerUserId) async {
    try {
      final likeQuery = await _firestore
          .collection('profile_likes')
          .where('likedUserId', isEqualTo: likedUserId)
          .where('likerUserId', isEqualTo: likerUserId)
          .get();

      return likeQuery.docs.isNotEmpty;
    } catch (error) {
      throw Exception('Erreur vérification like: $error');
    }
  }

  // Obtenir le nombre de likes d'un profil
  Future<int> getProfileLikesCount(String userId) async {
    try {
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      return userDoc.data()?['profileLikesCount'] ?? 0;
    } catch (error) {
      throw Exception('Erreur comptage likes: $error');
    }
  }

  // Incrémenter le compteur de likes
  Future<void> _incrementProfileLikes(String userId) async {
    await _firestore.collection('Users').doc(userId).update({
      'profileLikesCount': FieldValue.increment(1),
    });
    addPointsForAction(UserAction.likeProfil);
  }

  // Décrémenter le compteur de likes
  Future<void> _decrementProfileLikes(String userId) async {
    await _firestore.collection('Users').doc(userId).update({
      'profileLikesCount': FieldValue.increment(-1),
    });
  }

  // Stream du nombre de likes d'un profil
  Stream<int> getProfileLikesStream(String userId) {
    return _firestore
        .collection('Users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['profileLikesCount'] ?? 0);
  }
}