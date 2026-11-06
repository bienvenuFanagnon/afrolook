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
