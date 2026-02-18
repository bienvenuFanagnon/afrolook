// lib/services/video_preloader_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';


class VideoPreloaderService {
  // Singleton
  static final VideoPreloaderService _instance = VideoPreloaderService._internal();
  factory VideoPreloaderService() => _instance;
  VideoPreloaderService._internal();

  // Dépendances
  late UserAuthProvider _authProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 🔥 CONFIGURATION OPTIMALE
  static const int MAX_PREPARED_VIDEOS = 30;      // Nombre max de vidéos préparées en mémoire
  static const int MAX_CACHED_VIDEOS = 20;        // Nombre max de vidéos en cache disque
  static const int MAX_CACHE_SIZE_MB = 500;       // Taille max du cache en MB
  static const int PRECACHE_BATCH_SIZE = 5;       // Taille des lots de préchargement
  static const int VIDEOS_PER_PAGE = 10;          // Nombre de vidéos par page de pagination
  static const int MAX_FAILED_RETRIES = 3;         // Nombre max de tentatives pour les vidéos en échec

  // 🔥 ÉTATS INTERNES
  bool _isInitialized = false;
  bool _isPreparing = false;
  int _preparationProgress = 0;
  int _currentPage = 0;
  bool _hasMoreVideos = true;
  bool _isLoadingMore = false;

  // 🔥 STOCKAGE DES VIDÉOS
  final List<Post> _allVideos = [];                    // Toutes les vidéos chargées
  final List<String> _preparedVideoIds = [];            // IDs des vidéos préparées
  final Map<String, String> _cachedVideoPaths = {};     // ID -> chemin local
  final Map<String, Uint8List> _memoryCache = {};       // Cache mémoire pour le web
  final Map<String, int> _failedAttempts = {};          // Nombre de tentatives échouées
  final Set<String> _currentlyPreparing = {};           // Vidéos en cours de préparation
  final List<String> _preparationQueue = [];            // File d'attente de préparation

  // 🔥 STATISTIQUES
  int _totalHits = 0;
  int _totalMisses = 0;
  DateTime? _lastCacheCleanup;
  final List<Map<String, dynamic>> _preparationLog = [];

  // 🔥 GETTERS
  bool get isReady => _preparedVideoIds.isNotEmpty;
  int get preparedCount => _preparedVideoIds.length;
  int get cachedCount => _cachedVideoPaths.length;
  int get totalVideos => _allVideos.length;
  bool get hasMore => _hasMoreVideos;
  double get hitRate => _totalHits + _totalMisses > 0
      ? _totalHits / (_totalHits + _totalMisses)
      : 0.0;

  // ==================== INITIALISATION ====================

  Future<void> initialize(UserAuthProvider authProvider) async {
    if (_isInitialized) return;

    _authProvider = authProvider;
    print('🚀 [VideoPreloader] Initialisation du service...');

    try {
      // Charger les métadonnées du cache
      await _loadCacheMetadata();

      // Nettoyer l'ancien cache
      await _cleanupOldCache();

      // Charger la première page de vidéos
      await _loadVideosPage();

      // Démarrer la préparation en arrière-plan
      _startBackgroundPreparation();

      _isInitialized = true;

      print('✅ [VideoPreloader] Initialisé - ${_allVideos.length} vidéos, ${_cachedVideoPaths.length} en cache');
    } catch (e) {
      print('❌ [VideoPreloader] Erreur initialisation: $e');
    }
  }

  // ==================== CHARGEMENT DES VIDÉOS AVEC PAGINATION ====================

  Future<void> _loadVideosPage({bool loadMore = false}) async {
    if (_isLoadingMore) return;

    _isLoadingMore = true;

    try {
      print('📥 [VideoPreloader] Chargement page $_currentPage...');

      Query query = _firestore
          .collection('Posts')
          .where('dataType', isEqualTo: 'VIDEO')
          // .where('status', isEqualTo: 'VALIDE')
          .orderBy('created_at', descending: true);

      // Appliquer la pagination
      if (loadMore && _allVideos.isNotEmpty) {
        final lastVideo = _allVideos.last;
        query = query.startAfter([lastVideo.createdAt]).limit(VIDEOS_PER_PAGE);
      } else {
        query = query.limit(VIDEOS_PER_PAGE);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        _hasMoreVideos = false;
        print('📭 [VideoPreloader] Plus de vidéos disponibles');
        return;
      }

      // Convertir les documents en objets Post
      final newVideos = snapshot.docs.map((doc) {
        try {
          return Post.fromJson(doc.data() as Map<String, dynamic>);
        } catch (e) {
          print('❌ [VideoPreloader] Erreur parsing vidéo ${doc.id}: $e');
          return null;
        }
      }).whereType<Post>().toList();

      if (loadMore) {
        _allVideos.addAll(newVideos);
        _currentPage++;
      } else {
        _allVideos.clear();
        _allVideos.addAll(newVideos);
        _currentPage = 1;
      }

      _hasMoreVideos = newVideos.length == VIDEOS_PER_PAGE;

      print('✅ [VideoPreloader] ${newVideos.length} vidéos chargées - Total: ${_allVideos.length}');

    } catch (e) {
      print('❌ [VideoPreloader] Erreur chargement vidéos: $e');
      _hasMoreVideos = false;
    } finally {
      _isLoadingMore = false;
    }
  }

  // ==================== PRÉPARATION EN ARRIÈRE-PLAN ====================

  void _startBackgroundPreparation() {
    if (_isPreparing) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareVideosInBackground();
    });
  }

  Future<void> _prepareVideosInBackground() async {
    if (_isPreparing || _allVideos.isEmpty) return;

    _isPreparing = true;
    _preparationProgress = 0;

    print('🔄 [VideoPreloader] Début préparation vidéos...');

    try {
      // Remplir la file d'attente avec les vidéos non préparées
      _buildPreparationQueue();

      int preparedCount = 0;

      while (_preparationQueue.isNotEmpty && preparedCount < MAX_PREPARED_VIDEOS) {
        final batch = _preparationQueue.take(PRECACHE_BATCH_SIZE).toList();

        // Préparer le lot en parallèle
        await Future.wait(batch.map((videoId) => _prepareSingleVideo(videoId)));

        preparedCount += batch.length;
        _preparationProgress = ((preparedCount / MAX_PREPARED_VIDEOS) * 100).toInt();

        // Retirer les vidéos traitées de la file
        _preparationQueue.removeWhere((id) => batch.contains(id));

        // Petite pause pour ne pas saturer
        await Future.delayed(Duration(milliseconds: 200));

        print('📊 [VideoPreloader] Progression: $_preparationProgress% ($preparedCount/${MAX_PREPARED_VIDEOS})');
      }

      print('✅ [VideoPreloader] Préparation terminée - $_preparedVideoIds.length vidéos prêtes');

    } catch (e) {
      print('❌ [VideoPreloader] Erreur préparation: $e');
    } finally {
      _isPreparing = false;
    }
  }

  void _buildPreparationQueue() {
    _preparationQueue.clear();

    // Priorité 1: Vidéos récentes non préparées
    for (var video in _allVideos) {
      if (video.id != null &&
          !_preparedVideoIds.contains(video.id) &&
          !_failedAttempts.containsKey(video.id) &&
          !_currentlyPreparing.contains(video.id)) {
        _preparationQueue.add(video.id!);
      }
    }

    print('📋 [VideoPreloader] File d\'attente: ${_preparationQueue.length} vidéos');
  }

  // ==================== PRÉPARATION D'UNE VIDÉO ====================

  Future<void> _prepareSingleVideo(String videoId) async {
    if (_currentlyPreparing.contains(videoId)) return;

    _currentlyPreparing.add(videoId);

    try {
      // Récupérer la vidéo depuis la liste
      final video = _allVideos.firstWhere((v) => v.id == videoId);

      if (video.url_media == null || video.url_media!.isEmpty) {
        throw Exception('URL vidéo invalide');
      }

      // Vérifier si déjà en cache
      if (_cachedVideoPaths.containsKey(videoId)) {
        if (!_preparedVideoIds.contains(videoId)) {
          _preparedVideoIds.add(videoId);
        }
        _totalHits++;
        _preparationLog.add({
          'id': videoId,
          'status': 'cached',
          'time': DateTime.now().toIso8601String(),
        });
        return;
      }

      // Télécharger et mettre en cache
      print('📥 [VideoPreloader] Préparation vidéo $videoId...');

      final stopwatch = Stopwatch()..start();
      final cachedPath = await _downloadAndCacheVideo(videoId, video.url_media!);
      stopwatch.stop();

      if (cachedPath != null) {
        _cachedVideoPaths[videoId] = cachedPath;
        _preparedVideoIds.add(videoId);
        _failedAttempts.remove(videoId);

        print('✅ [VideoPreloader] Vidéo $videoId préparée en ${stopwatch.elapsedMilliseconds}ms');

        _preparationLog.add({
          'id': videoId,
          'status': 'success',
          'time': DateTime.now().toIso8601String(),
          'duration': stopwatch.elapsedMilliseconds,
        });
      } else {
        throw Exception('Échec téléchargement');
      }

      // Nettoyer si nécessaire
      if (_cachedVideoPaths.length > MAX_CACHED_VIDEOS) {
        await _cleanupExcessCache();
      }

    } catch (e) {
      print('❌ [VideoPreloader] Erreur préparation vidéo $videoId: $e');

      _totalMisses++;
      _failedAttempts[videoId] = (_failedAttempts[videoId] ?? 0) + 1;

      // Réessayer plus tard si pas trop d'échecs
      if (_failedAttempts[videoId]! < MAX_FAILED_RETRIES) {
        Future.delayed(Duration(seconds: 30), () {
          if (!_preparedVideoIds.contains(videoId)) {
            _preparationQueue.add(videoId);
          }
        });
      }

      _preparationLog.add({
        'id': videoId,
        'status': 'failed',
        'error': e.toString(),
        'time': DateTime.now().toIso8601String(),
      });
    } finally {
      _currentlyPreparing.remove(videoId);
    }
  }

  // ==================== TÉLÉCHARGEMENT OPTIMISÉ ====================

  Future<String?> _downloadAndCacheVideo(String videoId, String videoUrl) async {
    try {
      // Pour le web
      if (kIsWeb) {
        return await _cacheForWeb(videoId, videoUrl);
      }

      // Pour mobile/desktop
      return await _cacheForMobile(videoId, videoUrl);

    } catch (e) {
      print('❌ [VideoPreloader] Erreur téléchargement: $e');
      return null;
    }
  }

  Future<String?> _cacheForMobile(String videoId, String videoUrl) async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'video_${videoId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File('${dir.path}/$fileName');

      // Si le fichier existe déjà d'une version précédente, le supprimer
      if (await file.exists()) {
        await file.delete();
      }

      // Téléchargement depuis Firebase Storage ou URL directe
      if (videoUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final storageRef = _storage.refFromURL(videoUrl);
          final maxSize = MAX_CACHE_SIZE_MB * 1024 * 1024;
          final data = await storageRef.getData(maxSize);

          if (data != null) {
            await file.writeAsBytes(data);
            final fileSize = await file.length();
            print('📊 [VideoPreloader] Taille vidéo $videoId: ${fileSize / 1024 / 1024} MB');
            return file.path;
          }
        } catch (e) {
          print('⚠️ [VideoPreloader] Erreur Firebase Storage, fallback HTTP: $e');
        }
      }

      // Fallback HTTP
      final response = await http.get(Uri.parse(videoUrl)).timeout(
        Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);

        // Vérifier la taille
        final fileSize = await file.length();
        if (fileSize > MAX_CACHE_SIZE_MB * 1024 * 1024) {
          await file.delete();
          throw Exception('Fichier trop volumineux (${fileSize / 1024 / 1024} MB)');
        }

        return file.path;
      }

      throw Exception('HTTP ${response.statusCode}');

    } catch (e) {
      print('❌ [VideoPreloader] Erreur cache mobile: $e');
      return null;
    }
  }

  Future<String?> _cacheForWeb(String videoId, String videoUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Stocker l'URL et le timestamp
      await prefs.setString('cached_video_url_$videoId', videoUrl);
      await prefs.setInt('cached_video_time_$videoId', DateTime.now().millisecondsSinceEpoch);

      // Garder en mémoire pour un accès plus rapide
      if (_memoryCache.length < MAX_PREPARED_VIDEOS) {
        final response = await http.get(Uri.parse(videoUrl)).timeout(
          Duration(seconds: 15),
        );
        if (response.statusCode == 200 && response.bodyBytes.length < 50 * 1024 * 1024) {
          _memoryCache[videoId] = response.bodyBytes;
        }
      }

      // Sauvegarder la liste des IDs en cache
      final cachedIds = prefs.getStringList('cached_video_ids') ?? [];
      if (!cachedIds.contains(videoId)) {
        cachedIds.add(videoId);
        await prefs.setStringList('cached_video_ids', cachedIds);
      }

      return videoUrl;

    } catch (e) {
      print('❌ [VideoPreloader] Erreur cache web: $e');
      return null;
    }
  }

  // ==================== API PUBLIQUE ====================

  /// Récupère le chemin/local URL pour la lecture d'une vidéo
  Future<String?> getVideoPath(String videoId, {String? fallbackUrl}) async {
    // Vérifier le cache mémoire (web)
    if (_memoryCache.containsKey(videoId)) {
      _totalHits++;
      return fallbackUrl; // Pour le web, on retourne l'URL directe
    }

    // Vérifier le cache disque (mobile)
    if (_cachedVideoPaths.containsKey(videoId)) {
      final path = _cachedVideoPaths[videoId];
      if (path != null && File(path).existsSync()) {
        _totalHits++;
        return path;
      } else {
        _cachedVideoPaths.remove(videoId);
      }
    }

    // Pas en cache, mais on prépare en arrière-plan
    _totalMisses++;

    if (!_failedAttempts.containsKey(videoId) &&
        !_currentlyPreparing.contains(videoId) &&
        !_isPreparing) {
      _prepareSingleVideo(videoId);
    }

    return fallbackUrl;
  }

  /// Récupère la prochaine page de vidéos
  Future<List<Post>> getNextPage() async {
    if (!_hasMoreVideos) return [];

    await _loadVideosPage(loadMore: true);

    // Ajouter les nouvelles vidéos à la file de préparation
    if (_allVideos.isNotEmpty) {
      _buildPreparationQueue();
    }

    return _allVideos;
  }

  /// Récupère toutes les vidéos disponibles
  List<Post> getAllVideos() {
    return List.unmodifiable(_allVideos);
  }

  /// Récupère la vidéo à un index spécifique
  Post? getVideoAt(int index) {
    if (index >= 0 && index < _allVideos.length) {
      return _allVideos[index];
    }
    return null;
  }

  /// Vérifie si une vidéo est prête
  bool isVideoReady(String videoId) {
    return _preparedVideoIds.contains(videoId) ||
        _cachedVideoPaths.containsKey(videoId) ||
        _memoryCache.containsKey(videoId);
  }

  /// Récupère la prochaine vidéo préparée (pour rotation)
  String? getNextPreparedVideo() {
    if (_preparedVideoIds.isEmpty) return null;

    // Retirer la première et la remettre à la fin (rotation)
    final nextId = _preparedVideoIds.removeAt(0);
    _preparedVideoIds.add(nextId);

    return nextId;
  }

  /// Force le préchargement d'une vidéo spécifique
  Future<void> precacheVideo(String videoId) async {
    if (!_currentlyPreparing.contains(videoId) &&
        !_preparedVideoIds.contains(videoId)) {
      await _prepareSingleVideo(videoId);
    }
  }

  // ==================== GESTION DU CACHE ====================

  Future<void> _cleanupOldCache() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final cachedIds = prefs.getStringList('cached_video_ids') ?? [];
        final now = DateTime.now().millisecondsSinceEpoch;

        for (var id in cachedIds) {
          final time = prefs.getInt('cached_video_time_$id') ?? 0;
          // Supprimer après 7 jours
          if (now - time > 7 * 24 * 60 * 60 * 1000) {
            await prefs.remove('cached_video_url_$id');
            await prefs.remove('cached_video_time_$id');
          }
        }

        // Mettre à jour la liste
        final newIds = cachedIds.where((id) =>
            prefs.containsKey('cached_video_url_$id')).toList();
        await prefs.setStringList('cached_video_ids', newIds);

        return;
      }

      // Pour mobile/desktop
      final dir = await getTemporaryDirectory();
      final files = dir.listSync().whereType<File>().toList();

      // Trier par date de modification (plus récent d'abord)
      files.sort((a, b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync())
      );

      // Garder seulement les plus récents
      if (files.length > MAX_CACHED_VIDEOS) {
        for (int i = MAX_CACHED_VIDEOS; i < files.length; i++) {
          final file = files[i];
          if (file.path.contains('video_')) {
            await file.delete();
          }
        }
      }

      _lastCacheCleanup = DateTime.now();
      print('🧹 [VideoPreloader] Nettoyage cache terminé');

    } catch (e) {
      print('❌ [VideoPreloader] Erreur nettoyage cache: $e');
    }
  }

  Future<void> _cleanupExcessCache() async {
    if (_cachedVideoPaths.length <= MAX_CACHED_VIDEOS) return;

    // Trier les vidéos par date d'ajout (les plus anciennes d'abord)
    final entries = _cachedVideoPaths.entries.toList();
    final toRemove = entries.take(entries.length - MAX_CACHED_VIDEOS);

    for (var entry in toRemove) {
      if (!kIsWeb) {
        final file = File(entry.value);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _cachedVideoPaths.remove(entry.key);
      _preparedVideoIds.remove(entry.key);
    }

    print('🧹 [VideoPreloader] Nettoyage cache: ${toRemove.length} vidéos supprimées');
  }

  Future<void> _loadCacheMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (kIsWeb) {
        final cachedIds = prefs.getStringList('cached_video_ids') ?? [];
        for (var id in cachedIds) {
          final url = prefs.getString('cached_video_url_$id');
          if (url != null) {
            _cachedVideoPaths[id] = url;
          }
        }
      } else {
        final dir = await getTemporaryDirectory();
        final files = dir.listSync().whereType<File>().toList();

        for (var file in files) {
          if (file.path.contains('video_')) {
            final fileName = file.path.split('/').last;
            final id = fileName.split('_')[1];
            if (id.length >= 8) {
              _cachedVideoPaths[id] = file.path;
            }
          }
        }
      }

      print('📚 [VideoPreloader] Métadonnées chargées: ${_cachedVideoPaths.length} vidéos en cache');

    } catch (e) {
      print('❌ [VideoPreloader] Erreur chargement métadonnées: $e');
    }
  }

  // ==================== STATISTIQUES ET DEBUG ====================

  Map<String, dynamic> getStats() {
    return {
      'initialized': _isInitialized,
      'totalVideos': _allVideos.length,
      'preparedCount': _preparedVideoIds.length,
      'cachedCount': _cachedVideoPaths.length,
      'memoryCacheCount': _memoryCache.length,
      'failedCount': _failedAttempts.length,
      'queueSize': _preparationQueue.length,
      'currentlyPreparing': _currentlyPreparing.length,
      'hitRate': hitRate,
      'totalHits': _totalHits,
      'totalMisses': _totalMisses,
      'isPreparing': _isPreparing,
      'progress': _preparationProgress,
      'currentPage': _currentPage,
      'hasMore': _hasMoreVideos,
      'lastCleanup': _lastCacheCleanup?.toIso8601String(),
    };
  }

  List<Map<String, dynamic>> getPreparationLog({int limit = 50}) {
    return _preparationLog.reversed.take(limit).toList();
  }

  // ==================== RÉINITIALISATION ====================

  Future<void> reset() async {
    _allVideos.clear();
    _preparedVideoIds.clear();
    _cachedVideoPaths.clear();
    _memoryCache.clear();
    _failedAttempts.clear();
    _currentlyPreparing.clear();
    _preparationQueue.clear();
    _preparationLog.clear();
    _currentPage = 0;
    _hasMoreVideos = true;
    _isPreparing = false;
    _preparationProgress = 0;

    await _cleanupOldCache();
    await _loadVideosPage();
    _startBackgroundPreparation();

    print('🔄 [VideoPreloader] Service réinitialisé');
  }

  Future<void> clearCache() async {
    _preparedVideoIds.clear();
    _cachedVideoPaths.clear();
    _memoryCache.clear();

    if (!kIsWeb) {
      final dir = await getTemporaryDirectory();
      final files = dir.listSync().whereType<File>().toList();
      for (var file in files) {
        if (file.path.contains('video_')) {
          await file.delete();
        }
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (var key in keys) {
        if (key.startsWith('cached_video_')) {
          await prefs.remove(key);
        }
      }
    }

    print('🧹 [VideoPreloader] Cache vidéo vidé');
  }
}