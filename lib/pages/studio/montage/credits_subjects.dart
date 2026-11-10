import 'credits_render.dart';

/// Les sujets du générique de fin de film (10/11/2026) : « Mon année », « Ma journée », « Mon week-end »… Un modèle par sujet dans la galerie ; chaque sujet apporte ses lignes de générique,
/// ses chapitres et sa musique de fin de film, et la personne choisit ensuite le STYLE du générique (classique, version longue par chapitres…). Tout reste modifiable.
enum CreditsStyle { classique, chapitres }

extension CreditsStyleX on CreditsStyle {
  String get label => switch (this) {
        CreditsStyle.classique => 'Classique',
        CreditsStyle.chapitres => 'Version longue',
      };

  String get hint => switch (this) {
        CreditsStyle.classique => 'Le générique de fin de film : les rôles montent lentement, puis FIN.',
        CreditsStyle.chapitres => 'Plus long : un chapitre après l’autre, puis le générique.',
      };

  /// Durée d'office (secondes) : la version longue a plus de lignes à faire défiler.
  double get seconds => this == CreditsStyle.classique ? 24 : 40;
}

class CreditsSubject {
  const CreditsSubject({required this.templateId, required this.name, required this.big, required this.credits, required this.chapters, required this.bigChapters, required this.music, this.withYear = false});

  /// Identifiant du modèle du catalogue (`fa_film` pour « Mon année »).
  final String templateId;
  final String name;
  final String big;
  final List<(String, String)> credits;
  final List<(String, String)> chapters;
  final String bigChapters;
  final String music;

  /// « Mon année » : l'année qui finit est ajoutée au grand titre.
  final bool withYear;

  static int get _endYear => DateTime.now().month >= 9 ? DateTime.now().year : DateTime.now().year - 1;

  String get title => withYear ? '$big $_endYear' : big;

  /// Les lignes du générique (format de `CreditsRender` : « # Titre », « Rôle · Nom », ligne vide).
  List<String> lines(CreditsStyle style) {
    final tail = ['', 'Merci d’avoir regardé', '', '# FIN'];
    if (style == CreditsStyle.classique) {
      return ['# $title', '', for (final c in credits) '${c.$1} · ${c.$2}', ...tail];
    }
    return [
      '# $bigChapters',
      '',
      for (final c in chapters) ...['${c.$1} · ${c.$2}', ''],
      '# $title',
      '',
      for (final c in credits) '${c.$1} · ${c.$2}',
      ...tail,
    ];
  }
}

const List<CreditsSubject> kCreditsSubjects = [
  CreditsSubject(templateId: 'fa_film', name: 'Mon année', big: 'MON ANNÉE', music: 'eternal_hope', withYear: true,
      credits: [('Un film de', 'Moi'), ('Avec', 'Ma famille'), ('Scénario', 'Mes galères'), ('Musique', 'Mes playlists')],
      chapters: [('Janvier', 'Rien ne marchait'), ('Mars', 'J\'ai failli tout arrêter'), ('Juin', 'Le déclic'), ('Septembre', 'Je me suis relevé'), ('Décembre', 'Regardez où j\'en suis')], bigChapters: 'MON ANNÉE EN 12 MOIS'),
  CreditsSubject(templateId: 'gen_journee', name: 'Ma journée', big: 'MA JOURNÉE', music: 'morning',
      credits: [('Un film de', 'Moi'), ('Avec', 'Mon café'), ('Scénario', 'Mes imprévus'), ('Musique', 'Ma playlist du matin')],
      chapters: [('Matin', 'Un réveil difficile'), ('Midi', 'Le déjeuner qui sauve'), ('Après-midi', 'Le coup de fatigue'), ('Soir', 'Enfin la maison'), ('Nuit', 'Dodo')], bigChapters: 'MA JOURNÉE EN 5 TEMPS'),
  CreditsSubject(templateId: 'gen_weekend', name: 'Mon week-end', big: 'MON WEEK-END', music: 'carefree',
      credits: [('Un film de', 'Moi'), ('Avec', 'Mes amis'), ('Lieu de tournage', 'Partout'), ('Musique', 'Le son du samedi')],
      chapters: [('Vendredi', 'On sort'), ('Samedi', 'La grande soirée'), ('Dimanche', 'Le repos'), ('Lundi', 'Déjà…')], bigChapters: 'MON WEEK-END EN 3 JOURS'),
  CreditsSubject(templateId: 'gen_histoire', name: 'Mon histoire', big: 'MON HISTOIRE', music: 'long_road_ahead',
      credits: [('Une histoire de', 'Moi'), ('Avec', 'Ceux qui m\'ont porté'), ('Obstacle principal', 'Moi-même'), ('Musique', 'Mon courage')],
      chapters: [('Début', 'Tout recommence'), ('Épreuve', 'Rien n\'allait'), ('Tournant', 'Le déclic'), ('Aujourd\'hui', 'Debout')], bigChapters: 'MON HISTOIRE EN 4 CHAPITRES'),
  CreditsSubject(templateId: 'gen_anniv', name: 'Mon anniversaire', big: 'MON ANNIVERSAIRE', music: 'celebration',
      credits: [('Un film de', 'Moi, un an de plus'), ('Avec', 'Ma famille'), ('Cadeau principal', 'Votre amour'), ('Musique', 'La chanson des bougies')],
      chapters: [('Le matin', 'Les premiers messages'), ('Midi', 'Les appels'), ('Le soir', 'Le gâteau'), ('La nuit', 'Les souvenirs')], bigChapters: 'MON ANNIVERSAIRE EN 4 TEMPS'),
  CreditsSubject(templateId: 'gen_voyage', name: 'Mon voyage', big: 'MON VOYAGE', music: 'inspired',
      credits: [('Un film de', 'Moi'), ('Lieu de tournage', 'Le monde'), ('Avec', 'Ma valise'), ('Musique', 'La route')],
      chapters: [('Départ', 'Valises prêtes'), ('Route', 'En chemin'), ('Arrivée', 'On y est'), ('Retour', 'Déjà fini ?')], bigChapters: 'MON VOYAGE EN 4 ÉTAPES'),
  CreditsSubject(templateId: 'gen_soiree', name: 'Ma soirée', big: 'MA SOIRÉE', music: 'disco_con_tutti',
      credits: [('Un film de', 'Moi'), ('Avec', 'Mes amis'), ('Éclairage', 'Les lumières de la piste'), ('Musique', 'Le DJ')],
      chapters: [('Avant', 'La tenue'), ('Arrivée', 'L\'entrée'), ('Minuit', 'La piste'), ('Après', 'Le retour')], bigChapters: 'MA SOIRÉE EN 4 TEMPS'),
  CreditsSubject(templateId: 'gen_mariage', name: 'Mon mariage', big: 'NOTRE MARIAGE', music: 'canon_in_d_for_two_harps',
      credits: [('Un film de', 'Nous deux'), ('Avec', 'Nos familles'), ('Témoins', 'Nos amis'), ('Musique', 'Notre première danse')],
      chapters: [('La mairie', 'Le oui'), ('La cérémonie', 'Les promesses'), ('La fête', 'La première danse'), ('Le soir', 'Pour la vie')], bigChapters: 'NOTRE MARIAGE EN 4 TEMPS'),
  CreditsSubject(templateId: 'gen_business', name: 'Mon business', big: 'MON BUSINESS', music: 'motivator',
      credits: [('Un film de', 'Mon équipe'), ('Avec', 'Mes clients'), ('Direction de la persévérance', 'Moi'), ('Musique', 'Le bruit de la caisse')],
      chapters: [('Idée', 'Un rêve'), ('Lancement', 'Le premier client'), ('Croissance', 'On grandit'), ('Aujourd\'hui', 'Merci')], bigChapters: 'MON BUSINESS EN 4 ÉTAPES'),
  CreditsSubject(templateId: 'gen_famille', name: 'Ma famille', big: 'MA FAMILLE', music: 'fireflies_and_stardust',
      credits: [('Un film de', 'Ma famille'), ('Avec', 'Mes parents'), ('Mes alliés', 'Mes frères et sœurs'), ('Musique', 'Les rires de la maison')],
      chapters: [('Matin', 'Le petit-déjeuner'), ('Fêtes', 'Tout le monde'), ('Photos', 'Les souvenirs'), ('Soir', 'Ensemble')], bigChapters: 'MA FAMILLE EN 4 MOMENTS'),
];

/// Le sujet d'un modèle du catalogue (null si ce n'est pas un modèle de générique).
CreditsSubject? creditsSubjectFor(String templateId) {
  for (final s in kCreditsSubjects) {
    if (s.templateId == templateId) return s;
  }
  return null;
}

/// Les lignes d'office d'un modèle de générique (aperçu de la galerie et page de création).
List<String> creditsDefaultLinesFor(String templateId, {CreditsStyle style = CreditsStyle.classique}) =>
    creditsSubjectFor(templateId)?.lines(style) ?? CreditsRender.defaultLines();
