// providers/chronique_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../pages/chronique/chroniqueform.dart';

class ChroniqueProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Publier une chronique
  Future<void> publishChronique({
    required String userId,
    required String userPseudo,
    required String userImageUrl,
    required ChroniqueType type,
    String? textContent,
    File? mediaFile,
    String? backgroundColor,
    required Function(double) onProgress,
  }) async {
    try {
      String? mediaUrl;
      double? fileSize;
      int duration = 0;

      // Upload du média si nécessaire
      if (mediaFile != null) {
        mediaUrl = await _uploadMedia(mediaFile, onProgress);
        fileSize = await _getFileSize(mediaFile);

        // Calculer la durée pour les vidéos
        if (type == ChroniqueType.VIDEO) {
          duration = await _getVideoDuration(mediaFile);
        } else if (type == ChroniqueType.IMAGE) {
          duration = 5; // 5 secondes pour les images
        }
      } else if (type == ChroniqueType.TEXT) {
        duration = 10; // 10 secondes pour le texte
      }

      // Créer l'objet Chronique
      final chronique = Chronique(
        userId: userId,
        userPseudo: userPseudo,
        userImageUrl: userImageUrl,
        type: type,
        textContent: textContent,
        mediaUrl: mediaUrl,
        backgroundColor: backgroundColor,
        duration: duration,
        viewCount: 0,
        likeCount: 0,
        loveCount: 0,
        viewers: [],
        likers: [],
        lovers: [],
        createdAt: Timestamp.now(),
        expiresAt: Timestamp.fromDate(DateTime.now().add(Duration(hours: 24))),
        fileSize: fileSize,
      );

      // Sauvegarder dans Firestore
      await _firestore
          .collection('chroniques')
          .add(chronique.toMap());

      // Mettre à jour le compteur de chroniques utilisateur
      await _updateUserChroniqueCount(userId);

    } catch (error) {
      throw Exception('Erreur lors de la publication: $error');
    }
  }

  // Upload média vers Firebase Storage
  Future<String> _uploadMedia(File file, Function(double) onProgress) async {
    try {
      String fileName = 'chroniques/${DateTime.now().millisecondsSinceEpoch}';
      Reference storageRef = _storage.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(file);

      // Suivre la progression
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (error) {
      throw Exception('Erreur upload média: $error');
    }
  }

  // Obtenir la taille du fichier
  Future<double> _getFileSize(File file) async {
    final stat = await file.stat();
    return stat.size / (1024 * 1024); // Convertir en MB
  }

  // Obtenir la durée de la vidéo
  Future<int> _getVideoDuration(File file) async {
    // Pour une implémentation réelle, vous aurez besoin d'un package vidéo
    // Pour l'instant, on retourne une valeur par défaut
    return 10;
  }

  // Mettre à jour le compteur de chroniques utilisateur
  Future<void> _updateUserChroniqueCount(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists) {
      int currentCount = userDoc.data()?['activeChroniquesCount'] ?? 0;
      await _firestore.collection('users').doc(userId).update({
        'activeChroniquesCount': currentCount + 1,
        'lastChroniqueAt': Timestamp.now(),
      });
    }
  }

  // Obtenir le nombre de chroniques actives d'un utilisateur
  Future<int> getUserActiveChroniquesCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chroniques')
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .get();

      return snapshot.docs.length;
    } catch (error) {
      throw Exception('Erreur comptage chroniques: $error');
    }
  }

  // Stream des chroniques actives (non expirées)
  Stream<List<Chronique>> getActiveChroniques() {
    return _firestore
        .collection('chroniques')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Chronique.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Stream des chroniques d'un utilisateur spécifique
  Stream<List<Chronique>> getUserChroniques(String userId) {
    return _firestore
        .collection('chroniques')
        .where('userId', isEqualTo: userId)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Chronique.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Marquer une chronique comme vue
  Future<void> markAsViewed(String chroniqueId, String userId) async {
    try {
      await _firestore.collection('chroniques').doc(chroniqueId).update({
        'viewers': FieldValue.arrayUnion([userId]),
        'viewCount': FieldValue.increment(1),
      });
    } catch (error) {
      throw Exception('Erreur marquer comme vue: $error');
    }
  }

  // Ajouter un like (pouce)
  Future<void> addLike(String chroniqueId, String userId) async {
    try {
      await _firestore.collection('chroniques').doc(chroniqueId).update({
        'likers': FieldValue.arrayUnion([userId]),
        'likeCount': FieldValue.increment(1),
      });
    } catch (error) {
      throw Exception('Erreur ajout like: $error');
    }
  }

  // Retirer un like
  Future<void> removeLike(String chroniqueId, String userId) async {
    try {
      await _firestore.collection('chroniques').doc(chroniqueId).update({
        'likers': FieldValue.arrayRemove([userId]),
        'likeCount': FieldValue.increment(-1),
      });
    } catch (error) {
      throw Exception('Erreur retrait like: $error');
    }
  }

  // Ajouter un love (coeur)
  Future<void> addLove(String chroniqueId, String userId) async {
    try {
      await _firestore.collection('chroniques').doc(chroniqueId).update({
        'lovers': FieldValue.arrayUnion([userId]),
        'loveCount': FieldValue.increment(1),
      });
    } catch (error) {
      throw Exception('Erreur ajout love: $error');
    }
  }

  // Retirer un love
  Future<void> removeLove(String chroniqueId, String userId) async {
    try {
      await _firestore.collection('chroniques').doc(chroniqueId).update({
        'lovers': FieldValue.arrayRemove([userId]),
        'loveCount': FieldValue.increment(-1),
      });
    } catch (error) {
      throw Exception('Erreur retrait love: $error');
    }
  }

  // Supprimer une chronique
  Future<void> deleteChronique(String chroniqueId, String mediaUrl) async {
    try {
      // Supprimer le média du storage si il existe
      // if (mediaUrl.isNotEmpty) {
      //   await _storage.refFromURL(mediaUrl).delete();
      // }

      // Supprimer le document Firestore
      await _firestore.collection('chroniques').doc(chroniqueId).delete();
    } catch (error) {
      throw Exception('Erreur suppression chronique: $error');
    }
  }

  // Vérifier si l'utilisateur a déjà liké
  Future<bool> hasLiked(String chroniqueId, String userId) async {
    try {
      final doc = await _firestore.collection('chroniques').doc(chroniqueId).get();
      if (doc.exists) {
        List<String> likers = List<String>.from(doc.data()?['likers'] ?? []);
        return likers.contains(userId);
      }
      return false;
    } catch (error) {
      throw Exception('Erreur vérification like: $error');
    }
  }

  // Vérifier si l'utilisateur a déjà loved
  Future<bool> hasLoved(String chroniqueId, String userId) async {
    try {
      final doc = await _firestore.collection('chroniques').doc(chroniqueId).get();
      if (doc.exists) {
        List<String> lovers = List<String>.from(doc.data()?['lovers'] ?? []);
        return lovers.contains(userId);
      }
      return false;
    } catch (error) {
      throw Exception('Erreur vérification love: $error');
    }
  }

  // Nettoyer les chroniques expirées
  Future<void> cleanupExpiredChroniques() async {
    try {
      final snapshot = await _firestore
          .collection('chroniques')
          .where('expiresAt', isLessThan: Timestamp.now())
          .get();

      for (var doc in snapshot.docs) {
        final chronique = Chronique.fromMap(doc.data(), doc.id);

        // Supprimer le média si il existe
        if (chronique.mediaUrl != null && chronique.mediaUrl!.isNotEmpty) {
          await _storage.refFromURL(chronique.mediaUrl!).delete();
        }

        // Supprimer le document
        await doc.reference.delete();

        // Mettre à jour le compteur utilisateur
        await _decrementUserChroniqueCount(chronique.userId);
      }
    } catch (error) {
      throw Exception('Erreur nettoyage chroniques: $error');
    }
  }

  // Décrémenter le compteur de chroniques utilisateur
  Future<void> _decrementUserChroniqueCount(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        int currentCount = userDoc.data()?['activeChroniquesCount'] ?? 0;
        if (currentCount > 0) {
          await _firestore.collection('users').doc(userId).update({
            'activeChroniquesCount': currentCount - 1,
          });
        }
      }
    } catch (error) {
      print('Erreur décrémentation compteur: $error');
    }
  }

  // Obtenir les statistiques des chroniques
  Future<Map<String, dynamic>> getChroniqueStats(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chroniques')
          .where('userId', isEqualTo: userId)
          .get();

      int totalChroniques = snapshot.docs.length;
      int totalViews = 0;
      int totalLikes = 0;
      int totalLoves = 0;

      for (var doc in snapshot.docs) {
        totalViews += doc.data()['viewCount'] as int ?? 0;
        totalLikes += doc.data()['likeCount'] as int ?? 0;
        totalLoves += doc.data()['loveCount'] as int ?? 0;
      }

      return {
        'totalChroniques': totalChroniques,
        'totalViews': totalViews,
        'totalLikes': totalLikes,
        'totalLoves': totalLoves,
      };
    } catch (error) {
      throw Exception('Erreur statistiques: $error');
    }
  }

  // MESSAGES
  Future<void> addMessage({
    required String chroniqueId,
    required String userId,
    required String userPseudo,
    required String userImageUrl,
    required String message,
  }) async {
    try {
      if (message.length > 20) {
        throw Exception('Le message ne doit pas dépasser 20 caractères');
      }

      final chroniqueMessage = ChroniqueMessage(
        chroniqueId: chroniqueId,
        userId: userId,
        userPseudo: userPseudo,
        userImageUrl: userImageUrl,
        message: message,
        createdAt: Timestamp.now(),
      );

      await _firestore
          .collection('chronique_messages')
          .add(chroniqueMessage.toMap());
    } catch (error) {
      throw Exception('Erreur ajout message: $error');
    }
  }

  Stream<List<ChroniqueMessage>> getChroniqueMessages(String chroniqueId) {
    return _firestore
        .collection('chronique_messages')
        .where('chroniqueId', isEqualTo: chroniqueId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ChroniqueMessage.fromMap(doc.data(), doc.id))
        .toList());
  }

  // CHARGEMENT PAR LOT
  Future<List<Chronique>> getChroniquesBatch({
    required int limit,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection('chroniques')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt', descending: false)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) return [];

      return snapshot.docs
          .map((doc) => Chronique.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (error) {
      throw Exception('Erreur chargement batch: $error');
    }
  }

  Future<Map<String, List<Chronique>>> getGroupedChroniquesBatch({
    required int limit,
    DocumentSnapshot? lastDocument,
  }) async {
    final chroniques = await getChroniquesBatch(
      limit: limit,
      lastDocument: lastDocument,
    );

    final Map<String, List<Chronique>> grouped = {};
    for (var chronique in chroniques) {
      if (!grouped.containsKey(chronique.userId)) {
        grouped[chronique.userId] = [];
      }
      grouped[chronique.userId]!.add(chronique);
    }

    // Trier chaque groupe par date
    grouped.forEach((userId, userChroniques) {
      userChroniques.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });

    return grouped;
  }
}