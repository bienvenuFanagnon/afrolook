// providers/chronique_provider.dart

import 'dart:io';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'dart:async';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/chroniques_api.dart';
import 'package:afrotok/services/api/chroniques_mapper.dart';
import 'package:afrotok/services/read_meter.dart';
// Les COMMENTAIRES des chroniques (`chronique_messages`) restent sur Firebase (messages en temps réel) : seul Firestore pour cela.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../pages/chronique/chronique_music.dart';
import '../pages/chronique/chroniqueform.dart';
import '../services/chronique_first_page.dart';
import '../services/media_shrink.dart';
import '../services/video_poster.dart';

/// Chroniques : tout passe par l'API (liste, création, vues, j'aime / j'adore, suppression) sauf les commentaires (Firebase).
class ChroniqueProvider with ChangeNotifier {
  /// Longueur maximale d'un commentaire public.
  static const int maxCommentLength = 120;
  static const int commentsPageSize = 20;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // commentaires seulement

  String? get _myId => ChroniquesApi.myId;

  // Publier une chronique — retourne l'URL du média envoyé (null pour texte)
  Future<String?> publishChronique({
    required String userId,
    required String userPseudo,
    required String userImageUrl,
    required ChroniqueType type,
    String? textContent,
    File? mediaFile,
    File? coverImageFile,
    String? backgroundColor,
    String? templateId,
    int? audioStartMs,
    int? audioEndMs,
    ChroniqueMusic? music,
    double? textX,
    double? textY,
    String? idempotencyKey,
    required Function(double) onProgress,
  }) async {
    try {
      String? mediaUploadId;
      String? coverUploadId;
      String? posterUploadId;
      int duration = 0;

      // Envoi du média principal (URL signée, dépôt direct, confirmation)
      if (mediaFile != null) {
        mediaUploadId = await ChroniquesApi.upload(await MediaShrink.file(mediaFile), onProgress: (p) => onProgress(p * 0.8));

        if (type == ChroniqueType.VIDEO) {
          duration = await _getVideoDuration(mediaFile);
          // Aperçu tiré de la vidéo encore sur le téléphone : tout le monde l'affiche tout de suite (quelques Ko), sans toucher à la vidéo
          posterUploadId = await _uploadPoster(mediaFile);
        } else if (type == ChroniqueType.IMAGE) {
          duration = 5;
          // Miniature de 480 px : les rangées et les cartes ne téléchargent plus l'image entière
          posterUploadId = await _uploadImageThumb(mediaFile);
        } else if (type == ChroniqueType.AUDIO) {
          duration = await _getAudioDuration(mediaFile);
        }
      } else if (type == ChroniqueType.TEXT) {
        duration = 10;
      }

      // Pochette / image de fond si fournie
      if (coverImageFile != null) {
        coverUploadId = await ChroniquesApi.upload(await MediaShrink.file(coverImageFile), onProgress: (p) => onProgress(0.8 + p * 0.2));
      }

      // Musique : ma voix (envoyée avec la chronique, gratuite), musique gratuite d'Afrolook (adresse), ou son d'artiste (utilisation payée une fois)
      Map<String, dynamic>? musicBody;
      if (music != null) {
        musicBody = {
          'kind': music.isVoice ? 'voice' : (music.isArtist ? 'artist' : 'free'),
          'title': music.title,
          'artist': music.isVoice ? 'Ma voix' : music.artist,
          'start_ms': music.startMs,
          'end_ms': music.endMs,
          'volume': music.volume,
          'keep_video_sound': music.keepVideoSound,
        };
        if (music.isVoice && music.localPath != null) {
          musicBody['upload_id'] = await ChroniquesApi.upload(File(music.localPath!));
        } else if (music.isArtist && type != ChroniqueType.AUDIO) {
          musicBody['sound_id'] = music.id;
          musicBody['job_id'] = await _payArtistMusic(music);
        } else if (music.url.isNotEmpty) {
          musicBody['library_url'] = music.url;
        }
      }

      final hasText = (textContent ?? '').trim().isNotEmpty;
      final body = <String, dynamic>{
        'type': chroniqueTypeToApi(type),
        if (hasText) 'text': textContent!.trim(),
        if (backgroundColor != null) 'background_color': backgroundColor,
        if (templateId != null) 'template_id': templateId,
        if (mediaUploadId != null) 'media_upload_id': mediaUploadId,
        if (coverUploadId != null) 'cover_upload_id': coverUploadId,
        if (posterUploadId != null) 'poster_upload_id': posterUploadId,
        if (duration > 0) 'duration_sec': duration.clamp(1, 300),
        if (audioStartMs != null) 'audio_start_ms': audioStartMs,
        if (audioEndMs != null) 'audio_end_ms': audioEndMs,
        if ((type == ChroniqueType.IMAGE || type == ChroniqueType.VIDEO) && hasText && textX != null && textY != null) ...{'text_x': textX.clamp(0.0, 1.0), 'text_y': textY.clamp(0.0, 1.0)},
        if (musicBody != null) 'music': musicBody,
      };

      final created = await ChroniquesApi.create(body, myId: userId, idempotencyKey: idempotencyKey);
      if (music != null) _musicJobs.remove(music.id); // le montage est consommé : la prochaine publication paiera de nouveau
      ChroniqueFirstPage.clear();
      return created.mediaUrl;
    } on ApiException catch (error) {
      throw Exception(error.code == 'payment_required' || error.isInsufficientCoins ? 'Solde de pièces insuffisant pour cette musique.' : ChroniquesApi.message(error));
    } catch (error) {
      throw Exception('Erreur lors de la publication: $error');
    }
  }

  // ── Musique d'artiste : une utilisation payée par chronique (identifiant de montage + clé d'idempotence conservés jusqu'au succès) ──
  static final Map<String, ({String job, String key})> _musicJobs = {};

  Future<String> _payArtistMusic(ChroniqueMusic music) async {
    final job = _musicJobs.putIfAbsent(music.id, () => (job: ApiClient.newIdempotencyKey().replaceAll('-', ''), key: ApiClient.newIdempotencyKey()));
    if (music.coins <= 0) return job.job; // titre gratuit ou à moi : aucun achat
    try {
      await ApiGateway.instance.client.pay('/purchases', body: {'kind': 'music_use', 'ref_id': music.id, 'job_id': job.job}, idempotencyKey: job.key);
    } on ApiException catch (e) {
      if (e.code != 'music_job_used' && e.code != 'free') rethrow; // déjà payé pour ce montage : on continue sans débiter
    }
    return job.job;
  }

  Future<int> getLikesCount(String chroniqueId) async {
    try {
      final c = await ChroniquesApi.get(chroniqueId, myId: _myId);
      return c == null ? 0 : c.likeCount + c.loveCount;
    } catch (e) {
      printVm('Erreur lors de la récupération du nombre de likes: $e');
      return 0;
    }
  }

  /// Aperçu de la vidéo envoyé en même temps qu'elle ; sans aperçu, la chronique se publie quand même (les appareils le tireront eux-mêmes).
  Future<String?> _uploadPoster(File video) async {
    try {
      final poster = await VideoPoster.fromFile(video);
      if (poster == null) return null;
      return await ChroniquesApi.upload(poster);
    } catch (e) {
      printVm('Aperçu chronique non envoyé: $e');
      return null;
    }
  }

  /// Miniature d'une image envoyée en même temps qu'elle ; sans miniature, la chronique se publie quand même (l'image entière sert d'aperçu).
  Future<String?> _uploadImageThumb(File image) async {
    try {
      final thumb = await MediaShrink.thumbnail(image);
      if (thumb == null) return null;
      return await ChroniquesApi.upload(thumb);
    } catch (e) {
      printVm('Miniature chronique non envoyée: $e');
      return null;
    }
  }

  Future<int> _getVideoDuration(File file) async {
    try {
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      final duration = controller.value.duration.inSeconds;
      await controller.dispose();
      return duration;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getAudioDuration(File file) async {
    // Estimation par taille : ~128kbps → 16 Ko/s
    try {
      final sizeKb = (await file.stat()).size / 1024;
      return (sizeKb / 16).round().clamp(1, 300);
    } catch (_) {
      return 0;
    }
  }

  /// Nombre de chroniques actives de la personne (l'API les compte : plus de compteur stocké sur le profil).
  Future<int> getUserActiveChroniquesCount(String userId) async {
    try {
      final page = await ChroniquesApi.list(userId: userId, limit: 50, myId: _myId);
      return page.items.length;
    } catch (error) {
      throw Exception('Erreur comptage chroniques: ${ChroniquesApi.message(error)}');
    }
  }

  /// Chroniques actives d'une personne (une lecture, plus d'écoute en direct : relue après chaque publication ou suppression).
  Stream<List<Chronique>> getUserChroniques(String userId) {
    late StreamController<List<Chronique>> ctl;
    Future<void> load() async {
      try {
        final page = await ChroniquesApi.list(userId: userId, limit: 50, myId: _myId);
        if (!ctl.isClosed) ctl.add(page.items);
      } catch (e) {
        if (!ctl.isClosed) ctl.addError(e);
      }
    }

    void onChange() => load();
    ctl = StreamController<List<Chronique>>(
      onListen: () {
        load();
        ChroniqueFirstPage.changes.addListener(onChange);
      },
      onCancel: () {
        ChroniqueFirstPage.changes.removeListener(onChange);
        ctl.close();
      },
    );
    return ctl.stream;
  }

  /// Une page de chroniques actives, les plus récentes d'abord. [cursor] : `next` de la page précédente.
  Future<({List<Chronique> items, String? next})> getActiveChroniquesBatch({required int limit, String? cursor}) async {
    final page = await ChroniquesApi.list(limit: limit, cursor: cursor, myId: _myId);
    return (items: page.items, next: page.next);
  }

  /// Une page de chroniques actives avec le curseur de la page suivante. [after] : `next` de la page précédente (tout autre type est ignoré).
  Future<({List<Chronique> items, String? last, bool hasMore})> getChroniquesPage({required int limit, Object? after}) async {
    final page = await ChroniquesApi.list(limit: limit, cursor: after is String ? after : null, myId: _myId);
    return (items: page.items, last: page.next, hasMore: page.next != null);
  }

  /// Obtenir une chronique par son identifiant (null si elle a expiré).
  Future<Chronique?> getChroniqueById(String chroniqueId) async {
    try {
      return await ChroniquesApi.get(chroniqueId, myId: _myId);
    } catch (error) {
      printVm('Erreur getChroniqueById: $error');
      return null;
    }
  }

  Future<void> markAsViewed(String chroniqueId, String userId) async {
    try {
      await ChroniquesApi.view(chroniqueId);
    } catch (error) {
      throw Exception('Erreur marquer comme vue: ${ChroniquesApi.message(error)}');
    }
  }

  Future<void> addLike(String chroniqueId, String userId) async {
    try {
      await ChroniquesApi.react(chroniqueId, 'like');
    } catch (error) {
      throw Exception('Erreur ajout like: ${ChroniquesApi.message(error)}');
    }
  }

  Future<void> removeLike(String chroniqueId, String userId) async {
    try {
      await ChroniquesApi.unreact(chroniqueId, 'like');
    } catch (error) {
      throw Exception('Erreur retrait like: ${ChroniquesApi.message(error)}');
    }
  }

  Future<void> addLove(String chroniqueId, String userId) async {
    try {
      await ChroniquesApi.react(chroniqueId, 'love');
    } catch (error) {
      throw Exception('Erreur ajout love: ${ChroniquesApi.message(error)}');
    }
  }

  Future<void> removeLove(String chroniqueId, String userId) async {
    try {
      await ChroniquesApi.unreact(chroniqueId, 'love');
    } catch (error) {
      throw Exception('Erreur retrait love: ${ChroniquesApi.message(error)}');
    }
  }

  /// Supprime la chronique (l'API efface aussi ses fichiers) et ses commentaires (Firebase, 200 au plus).
  Future<void> deleteChronique(String chroniqueId, String mediaUrl, {String? userId, String? posterUrl, String? voiceUrl}) async {
    try {
      await ChroniquesApi.delete(chroniqueId);
      try {
        final msgs = await _firestore.collection('chronique_messages').where('chroniqueId', isEqualTo: chroniqueId).limit(200).getM('chroniqueProvider.dart:deleteMessages');
        if (msgs.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (final d in msgs.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
        }
      } catch (e) {
        printVm('Erreur suppression commentaires: $e');
      }
      ChroniqueFirstPage.clear();
    } catch (error) {
      throw Exception('Erreur suppression chronique: ${ChroniquesApi.message(error)}');
    }
  }

  Future<bool> hasLiked(String chroniqueId, String userId) async {
    try {
      final c = await ChroniquesApi.get(chroniqueId, myId: userId);
      return c?.likers.contains(userId) == true;
    } catch (error) {
      throw Exception('Erreur vérification like: ${ChroniquesApi.message(error)}');
    }
  }

  Future<bool> hasLoved(String chroniqueId, String userId) async {
    try {
      final c = await ChroniquesApi.get(chroniqueId, myId: userId);
      return c?.lovers.contains(userId) == true;
    } catch (error) {
      throw Exception('Erreur vérification love: ${ChroniquesApi.message(error)}');
    }
  }

  /// Le nettoyage des chroniques expirées (et de leurs fichiers) est fait toutes les heures par le serveur.
  Future<void> cleanupExpiredChroniques() async {}

  Future<Map<String, dynamic>> getChroniqueStats(String userId) async {
    try {
      final page = await ChroniquesApi.list(userId: userId, limit: 50, myId: _myId);
      var views = 0, likes = 0, loves = 0;
      for (final c in page.items) {
        views += c.viewCount;
        likes += c.likeCount;
        loves += c.loveCount;
      }
      return {'totalChroniques': page.items.length, 'totalViews': views, 'totalLikes': likes, 'totalLoves': loves};
    } catch (error) {
      throw Exception('Erreur statistiques: ${ChroniquesApi.message(error)}');
    }
  }

  // ═══ COMMENTAIRES (restent sur Firebase) ═══

  /// Nombre de commentaires et dernier commentaire d'une chronique, lus sur Firebase (l'API ne les porte pas) et reportés dans [c].
  Future<void> loadCommentInfo(Chronique c) async {
    if (c.id == null) return;
    try {
      final q = _firestore.collection('chronique_messages').where('chroniqueId', isEqualTo: c.id);
      final count = await q.count().get();
      c.commentCount = count.count ?? 0;
      if (c.commentCount > 0) {
        final last = await q.orderBy('createdAt', descending: true).limit(1).getM('chroniqueProvider.dart:lastComment');
        if (last.docs.isNotEmpty) {
          final m = last.docs.first.data();
          c.lastCommentPseudo = m['userPseudo'] as String?;
          c.lastCommentText = m['message'] as String?;
        }
      }
    } catch (e) {
      printVm('Commentaires de la chronique: $e');
    }
  }

  /// Une page de commentaires (du plus récent au plus ancien), lue à la demande : plus d'écoute en direct de toute la liste.
  Future<({List<ChroniqueMessage> items, DocumentSnapshot? last, bool hasMore})> getMessagesPage(String chroniqueId, {DocumentSnapshot? after}) async {
    Query<Map<String, dynamic>> q = _firestore
        .collection('chronique_messages')
        .where('chroniqueId', isEqualTo: chroniqueId)
        .orderBy('createdAt', descending: true)
        .limit(commentsPageSize);
    if (after != null) q = q.startAfterDocument(after);
    final snap = await q.getM('chroniqueProvider.dart:454');
    return (
      items: [for (final d in snap.docs) ChroniqueMessage.fromMap(d.data(), d.id)],
      last: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length >= commentsPageSize,
    );
  }

  Future<void> deleteMessage(String chroniqueId, String messageId) async {
    try {
      await _firestore.collection('chronique_messages').doc(messageId).delete();
      notifyListeners();
    } catch (error) {
      throw Exception('Erreur suppression message: $error');
    }
  }

  Future<void> likeMessage(String messageId, String userId) async {
    try {
      final messageRef = _firestore.collection('chronique_messages').doc(messageId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(messageRef);
        if (doc.exists) {
          final data = doc.data()!;
          List<String> likers = List<String>.from(data['likers'] ?? []);
          int likeCount = data['likeCount'] ?? 0;

          if (!likers.contains(userId)) {
            likers.add(userId);
            likeCount++;

            transaction.update(messageRef, {
              'likers': likers,
              'likeCount': likeCount,
            });
          }
        }
      });
      notifyListeners();
    } catch (e) {
      printVm('Erreur lors du like du message: $e');
      rethrow;
    }
  }

  Future<bool> hasLikedMessage(String messageId, String userId) async {
    try {
      final doc = await _firestore.collection('chronique_messages').doc(messageId).getM('chroniqueProvider.dart:584');
      if (doc.exists) {
        final data = doc.data()!;
        List<String> likers = List<String>.from(data['likers'] ?? []);
        return likers.contains(userId);
      }
      return false;
    } catch (e) {
      printVm('Erreur lors de la vérification du like message: $e');
      return false;
    }
  }

  Future<void> addMessage({
    required String chroniqueId,
    required String userId,
    required String userPseudo,
    required String userImageUrl,
    required String message,
  }) async {
    try {
      if (message.length > maxCommentLength) {
        throw Exception('Le commentaire ne doit pas dépasser $maxCommentLength caractères');
      }

      final chroniqueMessage = ChroniqueMessage(
        chroniqueId: chroniqueId,
        userId: userId,
        userPseudo: userPseudo,
        userImageUrl: userImageUrl,
        message: message,
        createdAt: Timestamp.now(),
        likeCount: 0,
        likers: [],
      );

      // Le nombre et le dernier commentaire ne sont plus recopiés dans la chronique (elle est dans l'API) : ils se lisent sur les commentaires.
      await _firestore.collection('chronique_messages').add(chroniqueMessage.toMap());
    } catch (error) {
      throw Exception('Erreur ajout message: $error');
    }
  }

  Stream<List<ChroniqueMessage>> getChroniqueMessages(String chroniqueId) {
    return _firestore
        .collection('chronique_messages')
        .where('chroniqueId', isEqualTo: chroniqueId)
        .orderBy('createdAt', descending: true)
        .snapshotsM('chroniqueProvider.dart:642')
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChroniqueMessage.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // Chargement par lot groupé par utilisateur (pour la page d'accueil)
  Future<Map<String, List<Chronique>>> getGroupedChroniquesBatch({
    required int limit,
    String? cursor,
  }) async {
    final chroniques = (await getActiveChroniquesBatch(limit: limit, cursor: cursor)).items;

    final Map<String, List<Chronique>> grouped = {};
    for (var chronique in chroniques) {
      grouped.putIfAbsent(chronique.userId, () => []).add(chronique);
    }

    grouped.forEach((userId, userChroniques) {
      userChroniques.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });

    return grouped;
  }
}
