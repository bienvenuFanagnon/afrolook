// Modèles « histoire » (09/11/2026) : une vidéo qui défile TOUTE SEULE, acte après acte (« De la galère au triomphe », « Le film de mon année »…), faite de 2 à 5 images
// composées sur le téléphone (photo de la personne + texte) puis assemblées par le diaporama du serveur, avec des durées par image et des transitions.
// Chaque acte reste modifiable par la personne (texte, photo, durée) ; le rythme proposé laisse le temps de lire.

/// Ambiance d'un acte : couleur du voile posé sur la photo et couleur de la petite ligne du haut.
enum StoryTone { dark, gold, light, rose, night }

class StoryAct {
  const StoryAct({required this.text, this.kick = '', this.seconds = 3.2, this.tone = StoryTone.dark, this.photo = 0});

  /// Phrase affichée en grand.
  final String text;

  /// Petite ligne au-dessus (« Janvier », « Générique »…).
  final String kick;

  /// Temps affiché : ~3 s pour une phrase courte, plus pour une phrase longue (voir [StoryScript.readSeconds]).
  final double seconds;
  final StoryTone tone;

  /// Numéro de la photo de la personne utilisée (retombe sur les photos choisies : 0 si une seule).
  final int photo;

  StoryAct copyWith({String? text, String? kick, double? seconds, StoryTone? tone, int? photo}) =>
      StoryAct(text: text ?? this.text, kick: kick ?? this.kick, seconds: seconds ?? this.seconds, tone: tone ?? this.tone, photo: photo ?? this.photo);
}

class StoryScript {
  const StoryScript({required this.acts, this.transition = 'fade'});
  final List<StoryAct> acts;

  /// Transition du diaporama : fade, slide, zoom ou none.
  final String transition;

  /// Durée de lecture confortable d'une phrase : 2,2 s + 0,055 s par caractère, entre 2,5 et 6 s.
  static double readSeconds(String text) => (2.2 + text.runes.length * 0.055).clamp(2.5, 6.0).toDouble();

  double get total => acts.fold(0.0, (a, b) => a + b.seconds);
}

int _nextYear() => DateTime.now().month >= 9 ? DateTime.now().year + 1 : DateTime.now().year;

/// Scripts des modèles-histoires, par identifiant de modèle du catalogue. Calculés au moment de l'ouverture (les années s'adaptent à l'année qui finit).
StoryScript? storyScriptFor(String templateId) {
  final next = _nextYear();
  final end = next - 1;
  StoryAct a(String text, {String kick = '', StoryTone tone = StoryTone.dark, int photo = 0, double? seconds}) =>
      StoryAct(text: text, kick: kick, tone: tone, photo: photo, seconds: seconds ?? StoryScript.readSeconds(text));
  switch (templateId) {
    case 'fa_film':
      return StoryScript(acts: [
        a('MON ANNÉE $end', kick: 'Générique', photo: 0, seconds: 3.2),
        a('Avec ma famille, mes amis, mes galères et mes victoires', photo: 1),
        a('Il y a eu des rires. Il y a eu des larmes.', photo: 2),
        a('Et je suis toujours debout.', tone: StoryTone.gold, photo: 3),
        a('MERCI · FIN', kick: 'Merci d’avoir regardé', tone: StoryTone.night, photo: 4, seconds: 3.4),
      ]);
    case 'fa_triomphe':
      return StoryScript(acts: [
        a('Rien ne marchait, j’ai failli abandonner.', kick: 'Janvier · les galères', tone: StoryTone.night, photo: 0, seconds: 3.8),
        a('J’ai tenu, j’ai appris, j’ai changé.', kick: 'Juin · le déclic', tone: StoryTone.dark, photo: 1, seconds: 3.6),
        a('Regardez où je suis arrivé(e). 🏆', kick: 'Décembre · le triomphe', tone: StoryTone.gold, photo: 2, seconds: 4.2),
      ]);
    case 'fa_merci':
      return StoryScript(acts: [
        a('Merci $end', kick: 'Une belle année, une belle histoire', tone: StoryTone.rose, photo: 0, seconds: 3.2),
        a('Merci à ceux qui en ont fait partie ❤️', tone: StoryTone.rose, photo: 1),
        a('Merci pour tout ce que tu m’as appris 🙏', tone: StoryTone.rose, photo: 2),
        a('Santé · famille · réussite', kick: 'Pour $next', tone: StoryTone.gold, photo: 3, seconds: 3.4),
      ]);
    case 'fa_page':
      return StoryScript(acts: [
        a('$end a été dure.', kick: '$end → $next', tone: StoryTone.night, photo: 0, seconds: 3.0),
        a('J’ai perdu. J’ai pleuré. J’ai appris.', tone: StoryTone.night, photo: 1),
        a('Ce qui m’a fait mal ne me définit pas.', tone: StoryTone.dark, photo: 2),
        a('Je tourne la page 🌅', kick: '$next', tone: StoryTone.gold, photo: 3, seconds: 3.6),
      ]);
    case 'fa_change':
      return StoryScript(acts: [
        a('$end s’en va.', kick: 'Minuit approche', tone: StoryTone.night, photo: 0, seconds: 3.0),
        a('Merci pour les leçons.', tone: StoryTone.dark, photo: 1, seconds: 3.0),
        a('$next arrive 🎆', tone: StoryTone.gold, photo: 2, seconds: 3.2),
        a('Bonne année $next ! Santé, paix et réussite', tone: StoryTone.gold, photo: 3, seconds: 4.0),
      ]);
    case 'fa_bilan':
      return StoryScript(acts: [
        a('Mon bilan $end', kick: 'Bilan', photo: 0, seconds: 3.0),
        a('Ce que j’ai gagné', kick: 'Gagné', tone: StoryTone.gold, photo: 1),
        a('Ce que j’ai perdu', kick: 'Perdu', tone: StoryTone.night, photo: 2),
        a('Ce que j’ai appris', kick: 'Appris', tone: StoryTone.light, photo: 3),
        a('Mon plus beau moment de $end', kick: 'Le meilleur', tone: StoryTone.gold, photo: 4, seconds: 4.0),
      ]);
    case 'fa_lecons':
      return StoryScript(acts: [
        a('Les leçons de $end', kick: 'Ce que l’année m’a appris', photo: 0, seconds: 3.4),
        a('Les gens passent, les leçons restent', kick: 'Mars', tone: StoryTone.light, photo: 1),
        a('Ne pas tout dire, ne pas tout donner', kick: 'Juin', tone: StoryTone.dark, photo: 2),
        a('Choisir mes combats', kick: 'Septembre', tone: StoryTone.night, photo: 3),
        a('Je ne regrette rien, j’ai appris', kick: 'Décembre', tone: StoryTone.gold, photo: 4),
      ]);
    case 'fa_resolutions':
      return StoryScript(acts: [
        a('Mes résolutions $next', kick: 'Nouvelle année', tone: StoryTone.gold, photo: 0, seconds: 3.2),
        a('Plus de sport 💪', kick: 'Objectif 1', photo: 1, seconds: 3.0),
        a('Plus de sourire 😊', kick: 'Objectif 2', tone: StoryTone.light, photo: 2, seconds: 3.0),
        a('Moins de stress 🧘', kick: 'Objectif 3', photo: 3, seconds: 3.0),
        a('Rendez-vous en décembre $next 🎯', kick: 'Le bilan', tone: StoryTone.gold, photo: 4, seconds: 3.6),
      ]);
    case 'vie_devenu':
      return StoryScript(acts: [
        a('Avant : doute et peur', kick: 'Avant', tone: StoryTone.night, photo: 0, seconds: 3.0),
        a('Personne n’a vu les nuits où j’ai failli abandonner', kick: 'Les nuits', photo: 1),
        a('Pas à pas, j’ai continué', kick: 'Pas à pas', tone: StoryTone.light, photo: 2, seconds: 3.0),
        a('Aujourd’hui : fier(e) et debout 👑', kick: 'Aujourd’hui', tone: StoryTone.gold, photo: 3, seconds: 4.0),
      ]);
    case 'vie_objectifs':
      return StoryScript(acts: [
        a('Jour 1 : je commence', kick: 'Départ', photo: 0, seconds: 3.0),
        a('Jour 30 : je tiens', kick: 'Un mois', tone: StoryTone.light, photo: 1, seconds: 3.0),
        a('Jour 100 : vous verrez 🎯', kick: 'Cent jours', tone: StoryTone.gold, photo: 2, seconds: 3.6),
        a('Pas de miracle, juste de la discipline', kick: 'Le secret', photo: 3),
      ]);
  }
  return null;
}

/// Identifiants des modèles du catalogue qui sont des histoires.
const kStoryTemplateIds = {'fa_triomphe', 'fa_merci', 'fa_bilan', 'fa_lecons', 'fa_resolutions', 'vie_devenu', 'vie_objectifs'};

/// Modèles « générique de fin de film » : le texte monte lentement sur des photos qui changent (voir `credits_page.dart`).
const kCreditsTemplateIds = {'fa_film', 'gen_journee', 'gen_weekend', 'gen_histoire', 'gen_anniv', 'gen_voyage', 'gen_soiree', 'gen_mariage', 'gen_business', 'gen_famille'};
