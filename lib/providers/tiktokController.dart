// controllers/user_profile_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// controllers/tiktok_video_controller.dart
import 'package:get/get.dart';

import '../models/tiktokModel.dart';

class UserProfileController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createUserProfile(String pseudo, String profileUrl) async {
    try {
      final userId = _auth.currentUser!.uid;
      await _firestore.collection('userProfiles').doc(userId).set({
        'tiktokPseudo': pseudo,
        'tiktokProfileUrl': profileUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
      Get.snackbar('Succès', 'Profil créé avec succès');
    } catch (e) {
      Get.snackbar('Erreur', e.toString());
    }
  }

  Stream<UserProfile?> get userProfile {
    final userId = _auth.currentUser!.uid;
    return _firestore
        .collection('userProfiles')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return UserProfile.fromFirestore(snapshot);
      }
      return null;
    });
  }
}



class TikTokVideoController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> uploadVideo(String videoUrl) async {
    try {
      final userId = _auth.currentUser!.uid;
      final videoId = _extractVideoId(videoUrl);
      final thumbnailUrl = 'https://www.tiktok.com/api/img/?itemId=$videoId';

      await _firestore.collection('tiktokVideos').add({
        'videoUrl': videoUrl,
        'userId': userId,
        'thumbnailUrl': thumbnailUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
      Get.snackbar('Succès', 'Vidéo enregistrée avec succès');
    } catch (e) {
      Get.snackbar('Erreur', e.toString());
    }
  }

  String _extractVideoId(String url) {
    final regex = RegExp(
        r'(https?://)?(www\.)?tiktok\.com/@[^/]+/video/(\d+)(\?.*)?');
    final match = regex.firstMatch(url);
    if (match != null && match.groupCount >= 3) {
      return match.group(3)!;
    }
    throw 'Lien TikTok invalide';
  }

  Stream<List<TikTokVideo>> get userVideos {
    final userId = _auth.currentUser!.uid;
    return _firestore
        .collection('tiktokVideos')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => TikTokVideo.fromFirestore(doc)).toList());
  }
}