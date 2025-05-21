// models/user_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';
// models/tiktok_video.dart
class UserProfile {
  final String id;
  final String tiktokPseudo;
  final String tiktokProfileUrl;

  UserProfile({
    required this.id,
    required this.tiktokPseudo,
    required this.tiktokProfileUrl,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      id: doc.id,
      tiktokPseudo: data['tiktokPseudo'] ?? '',
      tiktokProfileUrl: data['tiktokProfileUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tiktokPseudo': tiktokPseudo,
      'tiktokProfileUrl': tiktokProfileUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}



class TikTokVideo {
  final String id;
  final String videoUrl;
  final String userId;
  final String thumbnailUrl;
  final Timestamp timestamp;

  TikTokVideo({
    required this.id,
    required this.videoUrl,
    required this.userId,
    required this.thumbnailUrl,
    required this.timestamp,
  });

  factory TikTokVideo.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return TikTokVideo(
      id: doc.id,
      videoUrl: data['videoUrl'],
      userId: data['userId'],
      thumbnailUrl: data['thumbnailUrl'],
      timestamp: data['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoUrl': videoUrl,
      'userId': userId,
      'thumbnailUrl': thumbnailUrl,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}