/// Ce que chaque TYPE de live peut montrer et utiliser. Une seule règle, lue par l'écran du live, le menu des jeux et le placement des blocs :
/// un bloc qui n'a pas sa place dans un type de live n'est ni proposé ni affiché, donc il ne peut jamais en recouvrir un autre.
///
/// Types : `talk` (discussion), `shopping` (vente en direct), `market` (marché : des vendeurs louent un étal), `duel`, `challenge`, `story`, `quiz`.
class LiveCaps {
  const LiveCaps._(this.type, this.audioOnly, this.noCamera);

  factory LiveCaps.of(String? type, {bool audioOnly = false, bool noCamera = false}) => LiveCaps._((type == null || type.isEmpty) ? 'talk' : type, audioOnly, noCamera);

  final String type;
  final bool audioOnly;
  final bool noCamera;

  /// Vitrine d'articles épinglés (bouton « Ouvrir ma vitrine », produits qui défilent) : ventes en direct et marchés seulement.
  bool get showcase => !audioOnly && (type == 'shopping' || type == 'market');

  /// Panneau des étals (location, tours des vendeurs) : marchés seulement.
  bool get marketPanel => type == 'market';

  /// Bande vidéo des personnes sur scène : pas dans un salon audio, pas dans un live sans caméra.
  bool get videoStage => !audioOnly && !noCamera;

  /// Jeux du menu « Jeux du live » (clés du menu).
  /// - ventes et marchés : seulement ce qui ne prend pas de place à l'écran (objectif, tirage au sort, questions du public, clips) ;
  ///   les jeux à grande carte (sondage, conte, quiz, duel, défi) laissent la place à la vitrine et aux étals ;
  /// - duel, défi, conte, quiz : leur jeu, plus les mêmes aides légères (un autre jeu à grande carte arrêterait celui qui tourne) ;
  /// - discussion : tous les jeux (duel et défi demandent de la vidéo).
  Set<String> get games {
    const light = {'goal', 'draw', 'questions', 'clips'};
    switch (type) {
      case 'shopping':
      case 'market':
        return light;
      case 'duel':
        return {...light, 'duel'};
      case 'challenge':
        return {...light, 'challenge'};
      case 'story':
        return {...light, 'story'};
      case 'quiz':
        return {...light, 'quiz'};
      default:
        return {...light, 'poll', 'story', 'quiz', if (videoStage) 'duel', if (videoStage) 'challenge'};
    }
  }

  bool allows(String game) => game == 'end' || games.contains(game);
}
