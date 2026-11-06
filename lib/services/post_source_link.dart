/// Origine du média du post en cours de création (parcours « Créer un post ») : envoyée avec la publication, une seule fois.
///
/// - [captured] : filmé, photographié ou enregistré avec l'application (caméra, micro) : badge « Fait sur Afrolook », avantage dans le fil, aucun délai.
/// - [imported] : choisi dans la galerie : au plus 2 par jour ; le reste de la journée, il faut filmer ou enregistrer dans l'application.
///
/// Même principe que `StudioSoundLink` : le parcours le pose avant d'ouvrir le formulaire, la création du post le consomme, et la fermeture du formulaire
/// l'efface (un parcours abandonné ne doit pas étiqueter un autre post).
class PostSourceLink {
  PostSourceLink._();

  static const String captured = 'captured';
  static const String imported = 'imported';

  /// Média de la galerie retouché dans le Studio d'Afrolook : mention « Fait sur Afrolook », mais compté dans la limite d'imports du jour.
  static const String edited = 'edited';

  static String? _value;

  static void set(String? source) => _value = (source == captured || source == imported || source == edited) ? source : null;

  static void clear() => _value = null;

  /// Valeur en attente, sans l'effacer (affichage).
  static String? get pending => _value;

  /// À appeler à la création du post : rend l'origine en attente et l'efface.
  static String? take() {
    final v = _value;
    _value = null;
    return v;
  }
}

/// Effet de voix choisi par la personne pour l'audio du post en cours de création (écran « Choisis ta voix ») : envoyé avec la publication, une seule fois.
/// Le fil affiche alors « Voix modifiée » : on ne cache jamais qu'une voix a été transformée.
class PostVoiceLink {
  PostVoiceLink._();

  static String? _effect;

  static void set(String? effect) => _effect = (effect == null || effect.isEmpty) ? null : effect;

  static void clear() => _effect = null;

  static String? get pending => _effect;

  static String? take() {
    final v = _effect;
    _effect = null;
    return v;
  }
}

/// Publication à laquelle le post en cours de création répond (« Répondre en vidéo ») : envoyée avec la publication, une seule fois.
/// Vidéos épinglées dans le montage : posées par le Studio, consommées une seule fois à la création du post (le serveur les garde avec la publication,
/// pour qu'un toucher sur la vidéo épinglée ouvre l'original).
class PostPinLink {
  PostPinLink._();

  static List<Map<String, dynamic>>? _pins;

  static void set(List<Map<String, dynamic>>? pins) => _pins = (pins == null || pins.isEmpty) ? null : pins;

  static void clear() => _pins = null;

  static List<Map<String, dynamic>>? take() {
    final v = _pins;
    _pins = null;
    return v;
  }
}

class PostReplyLink {
  PostReplyLink._();

  static String? _postId;

  static void set(String? postId) => _postId = (postId == null || postId.isEmpty) ? null : postId;

  static void clear() => _postId = null;

  static String? get pending => _postId;

  static String? take() {
    final v = _postId;
    _postId = null;
    return v;
  }
}

/// Repère posé par l'examen pour la publication en cours : « C'est ma vidéo » envoie la vidéo à la modération avant publication (une seule fois, comme PostSourceLink).
class PostExternalLink {
  PostExternalLink._();

  static String? _mark;
  static bool _own = false;
  static bool _notice = false;

  static void set(String? mark, {bool own = false}) {
    _mark = mark;
    _own = own && mark != null;
  }

  static void clear() {
    _mark = null;
    _own = false;
  }

  /// À la création du post : (marque, « c'est ma vidéo »), puis effacé.
  static (String, bool)? take() {
    final m = _mark;
    final o = _own;
    clear();
    return m == null ? null : (m, o);
  }

  /// La publication attend la modération : l'écran de création le dit une fois.
  static void markPending() => _notice = true;

  static bool takeNotice() {
    final n = _notice;
    _notice = false;
    return n;
  }
}
