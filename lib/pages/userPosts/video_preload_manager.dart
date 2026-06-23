import 'package:video_player/video_player.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

/// Gestionnaire global de préchargement des vidéos du feed Home/Sport.
///
/// Reproduit le pattern de `_preloadedControllers` / `_preloadRadius` /
/// `_preloadVideoAtIndex` déjà utilisé dans `lib/pages/vibe/vibesPage.dart`,
/// mais sous forme statique afin d'être partagé entre toutes les
/// `YouTubeVideoCard` du feed (qui sont chacune leur propre State).
///
/// Stocke les `VideoPlayerController` initialisés (mais pas en lecture)
/// pour les posts voisins de la position actuellement visible, indexés
/// par `postId`.
class VideoPreloadManager {
  VideoPreloadManager._();

  /// Rayon de préchargement (comme `_preloadRadius` dans vibesPage.dart).
  static const int preloadRadius = 2;

  /// Contrôleurs préchargés (initialisés, non joués) par postId.
  static final Map<String, VideoPlayerController> _preloadedControllers = {};

  /// PostIds en cours de préchargement (pour éviter les doublons).
  static final Set<String> _preloadingIds = {};

  /// Fonction permettant de résoudre l'URL CDN optimisée à partir de l'URL
  /// brute du média. Doit être fournie par l'appelant (dépend de
  /// `UserAuthProvider.convertToCdnUrl`).
  static String Function(String rawUrl)? urlResolver;

  /// Retourne le contrôleur préchargé pour [postId] s'il existe et est
  /// initialisé, sinon `null`.
  static VideoPlayerController? takeController(String postId) {
    final controller = _preloadedControllers[postId];
    if (controller != null && controller.value.isInitialized) {
      return controller;
    }
    return null;
  }

  /// Retire (sans disposer) le contrôleur préchargé pour [postId] : utilisé
  /// quand une carte vidéo prend possession du contrôleur pour l'afficher.
  static VideoPlayerController? claimController(String postId) {
    final controller = takeController(postId);
    if (controller != null) {
      _preloadedControllers.remove(postId);
    }
    return controller;
  }

  static bool isPreloaded(String postId) =>
      _preloadedControllers.containsKey(postId);

  /// Précharge (initialise sans jouer) la vidéo du post [postId] si elle
  /// n'est pas déjà préchargée ou en cours de préchargement.
  static Future<void> preload(String postId, String? urlMedia) async {
    if (urlMedia == null || urlMedia.isEmpty) return;
    if (_preloadedControllers.containsKey(postId)) return;
    if (_preloadingIds.contains(postId)) return;

    _preloadingIds.add(postId);
    try {
      final url = urlResolver != null ? urlResolver!(urlMedia) : urlMedia;
      final controller = VideoPlayerController.network(url);
      await controller.initialize();
      // Couper le son par défaut tant que la vidéo n'est pas active :
      // le volume définitif sera appliqué via MediaPlaybackManager
      // au moment du `.play()`.
      await controller.setVolume(0.0);
      if (_preloadingIds.contains(postId)) {
        // Toujours pertinent (pas annulé / nettoyé pendant l'await)
        _preloadedControllers[postId] = controller;
      } else {
        controller.dispose();
      }
    } catch (e) {
      // ignore: avoid_print
      printVm('❌ VideoPreloadManager: erreur préchargement $postId: $e');
    } finally {
      _preloadingIds.remove(postId);
    }
  }

  /// Précharge les vidéos voisines de [currentIndex] dans [posts]
  /// (rayon `preloadRadius`). [posts] doit être la liste ordonnée des
  /// items du feed (peut contenir des éléments non-Post, ignorés via
  /// [idAndUrlAt]).
  static void preloadNeighborhood(
    int currentIndex,
    int length,
    String? Function(int index) idAt,
    String? Function(int index) urlAt,
  ) {
    final start = (currentIndex - preloadRadius).clamp(0, length - 1);
    final end = (currentIndex + preloadRadius).clamp(0, length - 1);
    for (int i = start; i <= end; i++) {
      if (i == currentIndex) continue;
      final id = idAt(i);
      final url = urlAt(i);
      if (id != null) preload(id, url);
    }
  }

  /// Supprime/dispose les contrôleurs préchargés dont l'index est en dehors
  /// de `[currentIndex - preloadRadius, currentIndex + preloadRadius]`.
  /// [idAt] doit retourner le postId pour un index donné (ou null).
  static void cleanupOutOfRange(
    int currentIndex,
    int length,
    String? Function(int index) idAt,
  ) {
    final minKeep = currentIndex - preloadRadius;
    final maxKeep = currentIndex + preloadRadius;
    final keepIds = <String>{};
    for (int i = minKeep.clamp(0, length - 1); i <= maxKeep.clamp(0, length - 1); i++) {
      final id = idAt(i);
      if (id != null) keepIds.add(id);
    }

    final toRemove = <String>[];
    _preloadedControllers.forEach((postId, controller) {
      if (!keepIds.contains(postId)) {
        controller.dispose();
        toRemove.add(postId);
      }
    });
    for (final id in toRemove) {
      _preloadedControllers.remove(id);
    }
  }

  /// Retire et dispose explicitement le contrôleur préchargé pour [postId]
  /// (par exemple si une carte vidéo se dispose et que le contrôleur
  /// préchargé ne lui a jamais été réclamé).
  static void discard(String postId) {
    final controller = _preloadedControllers.remove(postId);
    controller?.dispose();
    _preloadingIds.remove(postId);
  }

  /// Nettoyage complet (ex: fermeture du feed).
  static void disposeAll() {
    for (final controller in _preloadedControllers.values) {
      controller.dispose();
    }
    _preloadedControllers.clear();
    _preloadingIds.clear();
  }
}
